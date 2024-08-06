// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Suave } from "lib/suave-std/src/suavelib/Suave.sol"; // todo fix remapping
import { EthJsonRPC } from "lib/suave-std/src/protocols/EthJsonRPC.sol"; // todo fix remapping
import {Context} from "lib/suave-std/src/Context.sol";
import {Suapp} from "lib/suave-std/src/Suapp.sol";
import { SuaveContract } from "./utils/SuaveContract.sol"; // todo fix remapping

import {SuaveContract} from "contracts/utils/SuaveContract.sol";
import {Auction, AuctionPayout, AuctionStatus, Bid, BidId, BidUtils, NewAuctionArgs} from "contracts/utils/AuctionUtils.sol";
import {getAddressForPk} from "contracts/utils/SigUtils.sol";

// todo: add cancel bid
// todo instead of timelock on the vault release the funds with a signature (MEVM checks funds are not used)

contract TokenAuction is SuaveContract, Suapp {
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
        uint indexed auctionId,
        BidId winningBidId,
        AuctionPayout payout,
        bytes payoutSig
    );
    event BidPlaced(
        uint indexed auctionId,
        BidId indexed bidId,
        address indexed bidder
    );
    // event BidCancelled(BidId indexed bidId);

    string constant PK_NAMESPACE = "auction:v0:pksecret";
    string constant BID_NAMESPACE = "auction:v0:bids";
    address[] public genericPeekers = [
        0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829
    ]; // todo: update after suave update (this exposes storage to everyone)
    address public immutable vault;
    Suave.DataId internal pkDataId;
    address public auctionMaster;
    Auction[] public auctions;
    bool public isInitialized;
    EthJsonRPC settlementRpc;

    function _getAuction(
        uint auctionId
    ) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    constructor(address _vault, string memory _settlementChainRpc) {
        settlementRpc = new EthJsonRPC(_settlementChainRpc);
        vault = _vault;
    }

    function confidentialConstructorCallback(
        Suave.DataId _pkDataId,
        address pkAddress
    ) public {
        crequire(!isInitialized, "Already initialized");
        pkDataId = _pkDataId;
        auctionMaster = pkAddress;
        isInitialized = true;
    }

    function createAuctionCallback(
        NewAuctionArgs memory auctionArgs,
        bytes32 tokenHash,
        address auctioneer
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

        emit AuctionCreated(
            auctions.length - 1,
            auctioneer,
            tokenHash,
            auctionArgs.payoutAddress,
            until,
            auctionArgs.payoutCollectionDuration
        );
    }

    function cancelAuctionCallback(uint auctionId) external {
        auctions[auctionId].status = AuctionStatus.CANCELLED;
        emit AuctionCancelled(auctionId);
    }

    function submitBidCallback(
        uint auctionId,
        BidId bidId,
        address bidder
    ) external emitOffchainLogs {
        auctions[auctionId].bids++;
        emit BidPlaced(auctionId, bidId, bidder);
    }

    function settleAuctionCallback(
        uint auctionId,
        BidId winningBidId,
        AuctionPayout memory payout,
        bytes memory payoutSig
    ) external {
        Auction storage auction = auctions[auctionId];
        auction.status = AuctionStatus.SETTLED;
        emit AuctionSettled(auctionId, winningBidId, payout, payoutSig);
    }

    // 🤐 MEVM Methods

    function confidentialConstructor() external returns (bytes memory) {
        crequire(!isInitialized, "Already initialized");
        string memory pk = Suave.privateKeyGen(Suave.CryptoSignature.SECP256);
        address pkAddress = getAddressForPk(pk);
        Suave.DataId _pkDataId = storePK(bytes(pk));

        return
            abi.encodeWithSelector(
                this.confidentialConstructorCallback.selector,
                _pkDataId,
                pkAddress
            );
    }

    function createAuction(
        NewAuctionArgs memory auctionArgs
    ) external onlyConfidential returns (bytes memory) {
        string memory token = string(Context.confidentialInputs());
        bytes32 tokenHash = keccak256(abi.encode(token));
        address auctioneer = msg.sender;

        return
            abi.encodeWithSelector(
                this.createAuctionCallback.selector,
                auctionArgs,
                tokenHash,
                auctionMaster
            );
    }

    function cancelAuction(
        uint256 auctionId
    ) external onlyConfidential returns (bytes memory) {
        Auction storage auction = auctions[auctionId];
        require(auction.auctioneer == msg.sender, "Only auction master can cancel");
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        return
            abi.encodeWithSelector(
                this.cancelAuctionCallback.selector,
                auctionId
            );
    }

    function submitBid(
        uint auctionId
    ) external onlyConfidential returns (bytes memory) {
        uint bidAmount = abi.decode(Context.confidentialInputs(), (uint));
        address bidder = msg.sender;

        checkBidValidity(auctionId, bidder, bidAmount);
        BidId bidId = BidUtils.getBidId(
            uint128(auctionId),
            auctions[auctionId].bids
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
        uint auctionId
    ) external onlyConfidential returns (bytes memory) {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        require(block.timestamp >= auction.until, "Auction has not ended");
        require(auction.bids > 0, "No bids");

        (Bid memory winningBid, uint scndBidAmount) = settleVickeryAuction(
            auctionId
        );
        AuctionPayout memory payout = AuctionPayout(
            auction.payoutAddress,
            scndBidAmount
        ); // todo: can be return from _vickreyWinnerAndBid
        bytes memory payoutSig = signPayout(payout);

        return
            abi.encodeWithSelector(
                this.settleAuctionCallback.selector,
                auctionId,
                winningBid.id,
                payout,
                payoutSig
            );
    }

    function checkBidValidity(
        uint auctionId,
        address bidder,
        uint bidAmount
    ) internal {
        Auction memory auction = auctions[auctionId];
        require(auction.status == AuctionStatus.LIVE, "Auction is not live");
        require(block.timestamp < auction.until, "Auction has ended");
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

    function storeBid(Bid memory bid, uint auctionId) internal {
        string memory namespace = string(abi.encodePacked(auctionId));
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

    function fetchBids(uint auctionId) internal returns (Bid[] memory) {
        string memory namespace = string(
            abi.encodePacked(BID_NAMESPACE, auctionId)
        );
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
    ) internal returns (bool) {
        bytes memory balanceRes = settlementRpc.call(
            vault,
            abi.encodeWithSignature("getBalance(address)", user)
        );
        (uint balance, uint64 lockedUntil) = abi.decode(
            balanceRes,
            (uint256, uint64)
        );
        return balance >= amount && lockedUntil <= auctionEndPlusClaimTime;
    }

    // todo: what if multiple bidders bid the same? - store time for FIFO
    // Assumes auction status is checked on a higher lvl
    function settleVickeryAuction(
        uint auctionId
    ) internal returns (Bid memory winningBid, uint scndBestBidAmount) {
        Bid[] memory bids = fetchBids(auctionId);
        for (uint i = 0; i < bids.length; ++i) {
            Bid memory bid = bids[i];
            if (bid.amount > winningBid.amount) {
                scndBestBidAmount = winningBid.amount;
                winningBid = bid;
            } else if (bid.amount > scndBestBidAmount) {
                scndBestBidAmount = bid.amount;
            }
        }
        if (scndBestBidAmount == 0) {
            scndBestBidAmount = winningBid.amount;
        }
    }
}
