pragma solidity ^0.8.8;

import {Suave} from "lib/suave-std/src/suavelib/Suave.sol";

enum AuctionStatus {
    LIVE,
    CANCELLED,
    SETTLED
}

struct Auction {
    address payoutAddress;
    AuctionStatus status;
    Suave.DataId tokenDataId;
    bytes32 hashedToken;
    uint32 bids;
    uint64 until;
    uint64 payoutCollectionDuration;
    address auctioneer;
    address winner;
}
struct Bid {
    uint32 id;
    address bidder;
    uint256 amount;
}
struct NewAuctionArgs {
    uint64 auctionDuration;
    uint64 payoutCollectionDuration;
    address payoutAddress;
}
struct AuctionPayout {
    address vault;
    address taker;
    uint16 paymentNonce;
    address account;
    uint256 amount;
}

library BidUtils {
    function getBidId(uint16 auctionId, uint16 bidIndex) internal pure returns (uint32) {
        return uint32((auctionId << 16) | bidIndex);
    }

    function unpackBidId(uint32 bidId) internal pure returns (uint16 auctionId, uint16 bidIndex) {
        auctionId = uint16(bidId >> 16);
        bidIndex = uint16(bidId);
    }

    function settleVickeryAuction(
        Bid[] memory bids
    ) internal pure returns (Bid memory winningBid, uint256 scndBestBidAmount) {
        for (uint256 i = 0; i < bids.length; ++i) {
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
