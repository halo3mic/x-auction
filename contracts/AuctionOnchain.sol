// import "contracts/utils/AuctionUtils.sol";
import { Suave } from "lib/suave-std/src/suavelib/Suave.sol";
import "lib/suave-std/src/Gateway.sol";
import "./AuctionCommon.sol";


contract AuctionOnchain is AuctionCommon {
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

    constructor(address _vault, string memory _settlementChainRpc) {
        vault = _vault;
        address gateway = address(new Gateway(_settlementChainRpc, _vault));
        vaultRemote = ISettlementVault(gateway);
    }

    function confidentialConstructorCallback(
        Suave.DataId _pkDataId,
        Suave.DataId _bidCountDataId,
        address pkAddress, 
        bytes memory ccontrolInitCallback
    ) public onlyOwner {
        require(!isInitialized, "Already initialized");
        bidCountDataId = _bidCountDataId;
        pkDataId = _pkDataId;
        auctionMaster = pkAddress;
        isInitialized = true;
        
        (bool s,) = address(this).delegatecall(ccontrolInitCallback);
        require(s, "Initialization of ConfidentialControl failed");
    }

    function createAuctionCallback(
        NewAuctionArgs memory auctionArgs,
        bytes32 tokenHash,
        address auctioneer, 
        Suave.DataId tokenDataId,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
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
        address bidder,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
        auctions[auctionId].bids++;
        emit BidPlaced(auctionId, bidId, bidder);
    }

    function settleAuctionCallback(
        uint16 auctionId,
        uint32 winningBidId,
        address winningBidder,
        AuctionPayout memory payout,
        bytes memory payoutSig,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
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

    fallback() external {}

}
