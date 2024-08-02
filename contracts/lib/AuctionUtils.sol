pragma solidity ^0.8.8;


type BidId is uint256;

enum AuctionStatus {
    LIVE,
    CANCELLED,
    SETTLED
}

struct Auction {
    AuctionStatus status;
    uint128 bids;
    address payoutAddress;
    bytes32 hashedToken;
    uint64 until;
    uint64 payoutCollectionDuration;
    address auctioneer;
}
struct Bid {
    BidId id;
    address bidder;
    uint256 amount;
}
struct NewAuctionArgs {
    uint64 auctionDuration;
    uint64 payoutCollectionDuration;
    address payoutAddress;
}
struct AuctionPayout {
    address account;
    uint amount;
}

library BidUtils {

    function getBidId(uint128 auctionId, uint128 bidIndex) internal pure returns (BidId) {
        return BidId.wrap(uint(auctionId << 128 | bidIndex));
    }

    function unpackBidId(BidId bidId) internal pure returns (uint128 auctionId, uint128 bidIndex) {
        auctionId = uint128(BidId.unwrap(bidId)) >> 128;
        bidIndex = uint128(BidId.unwrap(bidId));
    }

}