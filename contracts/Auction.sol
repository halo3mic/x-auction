// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Suave } from "lib/suave-std/src/suavelib/Suave.sol"; // todo fix remapping
import { EthJsonRPC } from "lib/suave-std/src/protocols/EthJsonRPC.sol"; // todo fix remapping
import {Context} from "lib/suave-std/src/Context.sol";
import { SuaveContract } from "./utils/SuaveContract.sol"; // todo fix remapping

import {SuaveContract} from "contracts/utils/SuaveContract.sol";
import {Auction, AuctionPayout, AuctionStatus, Bid, BidUtils, NewAuctionArgs} from "contracts/utils/AuctionUtils.sol";
import {getAddressForPk} from "contracts/utils/SigUtils.sol";
import "lib/suave-std/src/Gateway.sol";

interface ISettlementVault {
    function getBalance(address user) external returns (uint, uint64);
    function accountToPaymentNonce(address account) external returns (uint16);
}

// todo instead of timelock on the vault release the funds with a signature (MEVM checks funds are not used)
// todo: accounting systems that prevents users to use their funds multiple times accross different auctions
// todo: restrict access to callback methods 

contract TokenAuction is SuaveContract {
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed auctioneer,
        bytes32 indexed hashedToken,
        address payoutAddress,
        uint64 until,
        uint64 payoutCollectionDuration
    );
    event AuctionCancelled(uint indexed auctionId);
    event AuctionSettled(
        uint16 indexed auctionId,
        uint32 winningBidId,
        AuctionPayout payout,
        bytes payoutSig
    );
    event BidPlaced(
        uint16 indexed auctionId,
        uint32 indexed bidId,
        address indexed bidder
    );

    modifier onlyInitialized() {
        require(isInitialized, "Not initialized");
        _;
    }

    string constant PK_NAMESPACE = "auction:v0:pksecret";
    string constant BID_NAMESPACE = "auction:v0:bids";
    string constant BIDCOUNT_NAMESPACE = "auction:v0:bidcount";
    string constant TOKEN_NAMESPACE = "auction:v0:token";
    address[] public genericPeekers = [
        0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829
    ]; // todo: update after suave update (this exposes storage to everyone)
    address public immutable vault;
    Suave.DataId internal pkDataId;
    Suave.DataId public bidCountDataId;
    address public auctionMaster;
    Auction[] public auctions;
    bool public isInitialized;
    ISettlementVault vaultRemote;
    EthJsonRPC settlementRpc;

    constructor(address _vault, string memory _settlementChainRpc) {
        settlementRpc = new EthJsonRPC(_settlementChainRpc);
        vault = _vault;
        address gateway = address(new Gateway(_settlementChainRpc, _vault));
        vaultRemote = ISettlementVault(gateway);
    }

    function confidentialConstructorCallback(
        Suave.DataId _pkDataId,
        Suave.DataId _bidCountDataId,
        address pkAddress
    ) public {
        crequire(!isInitialized, "Already initialized");
        bidCountDataId = _bidCountDataId;
        pkDataId = _pkDataId;
        auctionMaster = pkAddress;
        isInitialized = true;
    }

    function createAuctionCallback(
        NewAuctionArgs memory auctionArgs,
        bytes32 tokenHash,
        address auctioneer, 
        Suave.DataId tokenDataId
    ) external {
        uint64 until = uint64(block.timestamp) + auctionArgs.auctionDuration;
        Auction storage newAuction = auctions.push();
        newAuction.status = AuctionStatus.LIVE;
        newAuction.payoutAddress = auctionArgs.payoutAddress;
        newAuction.hashedToken = tokenHash;
        newAuction.until = until;
        newAuction.payoutCollectionDuration = auctionArgs
            .payoutCollectionDuration;
        newAuction.auctioneer = auctioneer;
        newAuction.tokenDataId = tokenDataId;

        emit AuctionCreated(
            auctions.length - 1,
            auctioneer,
            tokenHash,
            auctionArgs.payoutAddress,
            until,
            auctionArgs.payoutCollectionDuration
        );
    }

    function submitBidCallback(
        uint16 auctionId,
        uint32 bidId,
        address bidder
    ) external {
        auctions[auctionId].bids++;
        emit BidPlaced(auctionId, bidId, bidder);
    }

    function settleAuctionCallback(
        uint16 auctionId,
        uint32 winningBidId,
        address winningBidder,
        AuctionPayout memory payout,
        bytes memory payoutSig
    ) external {
        Auction storage auction = auctions[auctionId];
        auction.status = AuctionStatus.SETTLED;
        auction.winner = winningBidder;
        emit AuctionSettled(auctionId, winningBidId, payout, payoutSig);
    }

    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(auction.auctioneer == msg.sender, "Only auction master can cancel");
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        auctions[auctionId].status = AuctionStatus.CANCELLED;
        emit AuctionCancelled(auctionId);
    }

    // 🤐 MEVM Methods

    function confidentialConstructor() external returns (bytes memory) {
        crequire(!isInitialized, "Already initialized");
        string memory pk = Suave.privateKeyGen(Suave.CryptoSignature.SECP256);
        address pkAddress = getAddressForPk(pk);
        Suave.DataId _pkDataId = storePK(bytes(pk));
        Suave.DataId _bidCountDataId = storeBidCount(0);

        return
            abi.encodeWithSelector(
                this.confidentialConstructorCallback.selector,
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
        Suave.DataId tokenDataId = storeToken(tokenBytes);
        return
            abi.encodeWithSelector(
                this.createAuctionCallback.selector,
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
        storeBid(bid, auctionId);

        return
            abi.encodeWithSelector(
                this.submitBidCallback.selector,
                auctionId,
                0, // bid.id,
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
        ); // todo: can be return from _vickreyWinnerAndBid
        bytes memory payoutSig = signPayout(payout);

        return
            abi.encodeWithSelector(
                this.settleAuctionCallback.selector,
                auctionId,
                winningBid.id,
                winningBid.bidder,
                payout,
                payoutSig
            );
    }

    function claimToken(uint16 auctionId) external onlyConfidential onlyInitialized {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.SETTLED, "Auction is not settled");
        require(auction.winner == msg.sender, "Only winner can claim token");
        // todo: instead of revert let the user pass encryption key
        revert(abi.decode(retrieveToken(auction.tokenDataId), (string)));
    }

    function checkBidValidity(uint16 auctionId, address bidder, uint bidAmount) public {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        require(block.timestamp <= auction.until, "Auction has ended");
        require(bidAmount > 0, "Bid amount should be greater than zero");

        bool bidderHasFunds = userHasSufficientFunds(
            bidder,
            bidAmount,
            auction.until + auction.payoutCollectionDuration
        );
        require(bidderHasFunds, "Insufficient funds");
    }

    function signPayout(
        AuctionPayout memory payout
    ) internal returns (bytes memory sig) {
        string memory pk = retreivePK();
        bytes32 digest = keccak256(abi.encode(payout));
        sig = Suave.signMessage(
            abi.encodePacked(digest),
            Suave.CryptoSignature.SECP256,
            pk
        );
    }

    function incrementBidCount() internal returns (uint16 bidCount) {
        bidCount = retrieveBidCount(bidCountDataId);
        updateBidCount(bidCount+1);
    }

    function storeBid(Bid memory bid, uint16 auctionId) internal {
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

    function fetchBids(uint16 auctionId) internal returns (Bid[] memory) {
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

    function storeBidCount(uint16 bidCount) internal returns (Suave.DataId) {
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

    function updateBidCount(uint16 bidCount) internal {
        Suave.confidentialStore(bidCountDataId, BIDCOUNT_NAMESPACE, abi.encode(bidCount));
    }

    function retrieveBidCount(Suave.DataId bidCountDataId) public returns (uint16) {
        bytes memory bidCountBytes = Suave.confidentialRetrieve(
            bidCountDataId,
            BIDCOUNT_NAMESPACE
        );
        return abi.decode(bidCountBytes, (uint16));
    }

    function storeToken(bytes memory tokenBytes) internal returns (Suave.DataId) {
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

    function retrieveToken(Suave.DataId tokenDataId) internal returns (bytes memory tokenBytes) {
        tokenBytes = Suave.confidentialRetrieve(tokenDataId, TOKEN_NAMESPACE);
    }

    function storePK(bytes memory pk) internal returns (Suave.DataId) {
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

    function retreivePK() internal returns (string memory) {
        bytes memory pkBytes = Suave.confidentialRetrieve(
            pkDataId,
            PK_NAMESPACE
        );
        return string(pkBytes);
    }

    function userHasSufficientFunds(
        address user,
        uint amount,
        uint auctionEndPlusClaimTime
    ) public returns (bool) {
        (uint balance, uint64 lockedUntil) = vaultRemote.getBalance(user);
        return balance >= amount && lockedUntil >= auctionEndPlusClaimTime;
    }

    function settleVickeryAuction(
        uint16 auctionId
    ) internal returns (Bid memory winningBid, uint scndBestBidAmount) {
        Bid[] memory bids = fetchBids(auctionId);
        (winningBid, scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
    }

    fallback() external {}

}
