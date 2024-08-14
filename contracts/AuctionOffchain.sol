// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "lib/suave-std/src/suavelib/Suave.sol";
import "lib/suave-std/src/Context.sol";

import "contracts/utils/SuaveContract.sol";
import "contracts/utils/AuctionUtils.sol";
import "contracts/utils/SigUtils.sol";
import "./AuctionCommon.sol";
import "./AuctionOnchain.sol";


contract AuctionOffchain is SuaveContract, AuctionCommon {

    AuctionConfidentialStore immutable cstore = new AuctionConfidentialStore();

    function confidentialConstructor() external returns (bytes memory) {
        crequire(!isInitialized, "Already initialized");
        string memory pk = Suave.privateKeyGen(Suave.CryptoSignature.SECP256);
        address pkAddress = getAddressForPk(pk);
        Suave.DataId _pkDataId = cstore.storePK(bytes(pk));
        Suave.DataId _bidCountDataId = cstore.storeBidCount(0);

        return
            abi.encodeWithSelector(
                AuctionOnchain.confidentialConstructorCallback.selector,
                _pkDataId,
                _bidCountDataId,
                pkAddress
            );
    }

    function createAuction(
        NewAuctionArgs memory auctionArgs
    ) external onlyConfidential onlyInitialized returns (bytes memory) {
        bytes memory tokenBytes = Context.confidentialInputs();
        bytes32 tokenHash = keccak256(tokenBytes);
        Suave.DataId tokenDataId = cstore.storeToken(tokenBytes);
        return
            abi.encodeWithSelector(
                AuctionOnchain.createAuctionCallback.selector,
                auctionArgs,
                tokenHash,
                msg.sender,
                tokenDataId
            );
    }

    function submitBid(
        uint16 auctionId
    ) external onlyConfidential onlyInitialized returns (bytes memory) {
        uint bidAmount = abi.decode(Context.confidentialInputs(), (uint));
        address bidder = msg.sender;

        checkBidValidity(auctionId, bidder, bidAmount);
        uint32 bidId = BidUtils.getBidId(
            auctionId,
            incrementBidCount() 
        );
        Bid memory bid = Bid(bidId, bidder, bidAmount);
        cstore.storeBid(bid, auctionId);

        return
            abi.encodeWithSelector(
                AuctionOnchain.submitBidCallback.selector,
                auctionId,
                bidId,
                bidder
            );
    }

    function settleAuction(
        uint16 auctionId
    ) external onlyConfidential onlyInitialized returns (bytes memory) {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        require(block.timestamp > auction.until, "Auction has not ended");
        require(auction.bids > 0, "No bids");

        (Bid memory winningBid, uint scndBidAmount) = settleVickeryAuction(auctionId);
        AuctionPayout memory payout = AuctionPayout(
            vault,
            auction.payoutAddress,
            vaultRemote.accountToPaymentNonce(auction.payoutAddress),
            winningBid.bidder,
            scndBidAmount
        );
        bytes memory payoutSig = signPayout(payout);

        return
            abi.encodeWithSelector(
                AuctionOnchain.settleAuctionCallback.selector,
                auctionId,
                winningBid.id,
                winningBid.bidder,
                payout,
                payoutSig
            );
    }

    function claimToken(
        uint16 auctionId
    ) external onlyConfidential onlyInitialized returns (bytes memory) {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.SETTLED, "Auction is not settled");
        require(auction.winner == msg.sender, "Only winner can claim token");
        bytes memory tokenBytes = cstore.retrieveToken(auction.tokenDataId);
        bytes memory key = Context.confidentialInputs();
        require(key.length == 32, "invalid key length");
        return Suave.aesEncrypt(key, abi.encode(tokenBytes));
    }

    function checkBidValidity(uint16 auctionId, address bidder, uint bidAmount) public {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        require(block.timestamp <= auction.until, "Auction has ended");
        require(bidAmount > 0, "Bid amount should be greater than zero");

        bool hasBidderFunds = hasUserSufficientFunds(
            bidder,
            bidAmount,
            auction.until + auction.payoutCollectionDuration
        );
        require(hasBidderFunds, "Insufficient funds");
    }

    function hasUserSufficientFunds(
        address user,
        uint amount,
        uint auctionEndPlusClaimTime
    ) public returns (bool) {
        (uint balance, uint64 lockedUntil) = vaultRemote.getBalance(user);
        return balance >= amount && lockedUntil >= auctionEndPlusClaimTime;
    }

    function signPayout(
        AuctionPayout memory payout
    ) internal returns (bytes memory sig) {
        string memory pk = cstore.retreivePK(pkDataId);
        bytes32 digest = keccak256(abi.encode(payout));
        sig = Suave.signMessage(
            abi.encodePacked(digest),
            Suave.CryptoSignature.SECP256,
            pk
        );
    }

    function incrementBidCount() internal returns (uint16 bidCount) {
        bidCount = cstore.retrieveBidCount(bidCountDataId);
        cstore.updateBidCount(bidCountDataId, bidCount+1);
    }

    function settleVickeryAuction(
        uint16 auctionId
    ) internal returns (Bid memory winningBid, uint scndBestBidAmount) {
        Bid[] memory bids = cstore.fetchBids(auctionId);
        (winningBid, scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
    }

}

contract AuctionConfidentialStore {
    string constant PK_NAMESPACE = "auction:v0:pksecret";
    string constant BID_NAMESPACE = "auction:v0:bids";
    string constant BIDCOUNT_NAMESPACE = "auction:v0:bidcount";
    string constant TOKEN_NAMESPACE = "auction:v0:token";

    address[] public genericPeekers = [
        0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829
    ]; // todo: update after suave update (this exposes storage to everyone)


    function storeBid(Bid memory bid, uint16 auctionId) external {
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, auctionId));
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
        peekers[1] = Suave.FETCH_DATA_RECORDS;
        peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
        Suave.DataRecord memory secretBid = Suave.newDataRecord(
            0,
            genericPeekers,
            genericPeekers,
            namespace
        );
        Suave.confidentialStore(secretBid.id, namespace, abi.encode(bid));
    }

    function fetchBids(uint16 auctionId) external returns (Bid[] memory) {
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, auctionId));
        Suave.DataRecord[] memory dataRecords = Suave.fetchDataRecords(
            0,
            namespace
        );
        Bid[] memory bids = new Bid[](dataRecords.length);
        for (uint i = 0; i < dataRecords.length; i++) {
            bytes memory bidBytes = Suave.confidentialRetrieve(
                dataRecords[i].id,
                namespace
            );
            Bid memory bid = abi.decode(bidBytes, (Bid));
            bids[i] = bid;
        }
        return bids;
    }

    function storeBidCount(uint16 bidCount) external returns (Suave.DataId) {
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
        peekers[1] = Suave.FETCH_DATA_RECORDS;
        peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
        
        Suave.DataRecord memory dataRec = Suave.newDataRecord(
            0,
            peekers,
            peekers,
            BIDCOUNT_NAMESPACE
        );
        Suave.confidentialStore(dataRec.id, BIDCOUNT_NAMESPACE, abi.encode(bidCount));
        return dataRec.id;
    }

    function updateBidCount(Suave.DataId bidCountDataId, uint16 bidCount) external {
        Suave.confidentialStore(bidCountDataId, BIDCOUNT_NAMESPACE, abi.encode(bidCount));
    }

    function retrieveBidCount(Suave.DataId bidCountDataId) public returns (uint16) {
        bytes memory bidCountBytes = Suave.confidentialRetrieve(
            bidCountDataId,
            BIDCOUNT_NAMESPACE
        );
        return abi.decode(bidCountBytes, (uint16));
    }

    function storeToken(bytes memory tokenBytes) external returns (Suave.DataId) {
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
        peekers[1] = Suave.FETCH_DATA_RECORDS;
        peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
        Suave.DataRecord memory secretBid = Suave.newDataRecord(
            0,
            genericPeekers,
            genericPeekers,
            TOKEN_NAMESPACE
        );
        Suave.confidentialStore(secretBid.id, TOKEN_NAMESPACE, tokenBytes);
        return secretBid.id;
    }

    function retrieveToken(Suave.DataId tokenDataId) external returns (bytes memory tokenBytes) {
        tokenBytes = Suave.confidentialRetrieve(tokenDataId, TOKEN_NAMESPACE);
    }

    function storePK(bytes memory pk) external returns (Suave.DataId) {
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
        peekers[1] = Suave.FETCH_DATA_RECORDS;
        peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
        Suave.DataRecord memory secretBid = Suave.newDataRecord(
            0,
            genericPeekers,
            genericPeekers,
            PK_NAMESPACE
        );
        Suave.confidentialStore(secretBid.id, PK_NAMESPACE, pk);
        return secretBid.id;
    }

    function retreivePK(Suave.DataId pkDataId) external returns (string memory) {
        bytes memory pkBytes = Suave.confidentialRetrieve(
            pkDataId,
            PK_NAMESPACE
        );
        return string(pkBytes);
    }

}
