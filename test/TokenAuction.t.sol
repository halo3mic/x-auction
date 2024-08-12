// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "lib/suave-std/src/Test.sol";
import "lib/suave-std/src/suavelib/Suave.sol";
import "lib/suave-std/src/forge/ContextConnector.sol";
import "lib/forge-std/src/console2.sol";
import { VmSafe as VmOrg } from "lib/forge-std/src/Vm.sol";
import "lib/solady/src/utils/LibString.sol";

import "../contracts/Auction.sol";
import "../contracts/utils/AuctionUtils.sol";

library ConfRequest {

    enum Status {
        SUCCESS,
        FAILURE_OFFCHAIN,
        FAILURE_ONCHAIN
    }

    function sendConfRequest(
        ContextConnector ctx,
        address to,
        bytes memory data
    ) internal returns (Status, bytes memory callbackResult) {
        return sendConfRequest(ctx, to, data, "");
    }

    /// Sends a confidential request; calls offchain function and onchain callback.
    function sendConfRequest(
        ContextConnector ctx,
        address to,
        bytes memory data, 
        bytes memory confidentialInputs
    ) internal returns (Status, bytes memory callbackResult) {
        if (confidentialInputs.length > 0) {
            ctx.setConfidentialInputs(confidentialInputs);
        }
        // offchain execution
        (bool success, bytes memory suaveCalldata) = to.call(data);
        if (!success) {
            return (Status.FAILURE_OFFCHAIN, suaveCalldata);
        }
        suaveCalldata = abi.decode(suaveCalldata, (bytes));
        // onchain callback
        (success, callbackResult) = to.call(suaveCalldata);
        if (!success) {
            return (Status.FAILURE_ONCHAIN, callbackResult);
        }
        return (Status.SUCCESS, callbackResult);
    }

}


// =================================================================

interface ICheats {
    function startPrank(address target) external;
    function stopPrank() external;
    function warp(uint256) external;
    function expectRevert(bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (VmOrg.Log[] memory);
    function envAddress(string calldata) external returns (address);
    function envString(string calldata) external returns (string memory);
}

contract AuctionTest is Test, SuaveEnabled {
    using ConfRequest for address;

    address vault;
    address bidderA;
    address bidderB;
    string settlementChainRpc;

    ICheats cheats = ICheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function _setup() public {
        vault = cheats.envAddress("FORGE_AUCTION_VAULT");
        bidderA = cheats.envAddress("FORGE_AUCTION_BIDDER_A");
        bidderB = cheats.envAddress("FORGE_AUCTION_BIDDER_B");
        settlementChainRpc = cheats.envString("FORGE_AUCTION_SETTLEMENT_CHAIN_RPC");
    }

    function newAuction(
        string memory secret,
        address payoutAddress, 
        uint64 auctionDuration
    ) internal returns (TokenAuction) {
        TokenAuction auction = new TokenAuction(vault, settlementChainRpc);
        NewAuctionArgs memory auctionArgs = NewAuctionArgs({
            auctionDuration: auctionDuration,
            payoutCollectionDuration: 60,
            payoutAddress: payoutAddress
        });

        (ConfRequest.Status sInit, bytes memory resInit) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction), 
                abi.encodeWithSelector(auction.confidentialConstructor.selector) 
            );
        require(sInit == ConfRequest.Status.SUCCESS, string(resInit));

        (ConfRequest.Status sCreate, bytes memory resCreate) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction), 
                abi.encodeWithSelector(auction.createAuction.selector, auctionArgs), 
                abi.encode(secret)
            );
        require(sCreate == ConfRequest.Status.SUCCESS, string(resCreate));

        return auction;
    }

    function test_createAuction() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);
        (
            address payoutAddress, 
            AuctionStatus status, 
            ,
            bytes32 hashedToken, 
            ,
            ,
            ,
            address auctioneer
            ,
        ) = auction.auctions(0);

        assertEq(uint(status), uint(AuctionStatus.LIVE));
        assertEq(payoutAddress, payoutAddressOrg);
        assertEq(auctioneer, address(this));
        assertEq(hashedToken, keccak256(abi.encode(secret)));
    }

    function test_cancelAuction() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);
        auction.cancelAuction(0);
        (,AuctionStatus status,,,,,,,) = auction.auctions(0);

        assertEq(uint(status), uint(AuctionStatus.CANCELLED));
    }

    function test_submitBid() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint256 bidAmount = 100;
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);

        cheats.startPrank(bidderA);
        (ConfRequest.Status status, bytes memory resData) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction),
                abi.encodeWithSelector(auction.submitBid.selector, 0),
                abi.encode(bidAmount)
            );
        require(status == ConfRequest.Status.SUCCESS, string(resData));

        (,,,,uint128 bids,,,,) = auction.auctions(0);
        assertEq(bids, 1);
    }

    function test_settleAuction() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);

        // Bid 1
        uint256 bidAmount = 100;
        cheats.startPrank(bidderA);
        (ConfRequest.Status status1, bytes memory resData1) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction),
                abi.encodeWithSelector(auction.submitBid.selector, 0),
                abi.encode(bidAmount)
            );
        require(status1 == ConfRequest.Status.SUCCESS, string(resData1));

        // Bid 2
        bidAmount = 120;
        cheats.startPrank(bidderB);
        (ConfRequest.Status status2, bytes memory resData2) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction),
                abi.encodeWithSelector(auction.submitBid.selector, 0),
                abi.encode(bidAmount)
            );
        require(status2 == ConfRequest.Status.SUCCESS, string(resData2));

        // Settle auction
        cheats.recordLogs();
        cheats.stopPrank();
        cheats.warp(block.timestamp + auctionDuration + 1);
        (ConfRequest.Status status3, bytes memory resData3) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction),
                abi.encodeWithSelector(auction.settleAuction.selector, 0)
            );
        require(status3 == ConfRequest.Status.SUCCESS, string(resData3));

        // Check we got correct winner
        (,,,,,,,,address winner) = auction.auctions(0);
        assertEq(winner, bidderB);

        // Check the winner can claim the secret
        bytes memory claimSecretKey = Suave.randomBytes(32);
        cheats.startPrank(bidderB);
        (ConfRequest.Status status4, bytes memory resData4) = 
            ConfRequest.sendConfRequest(
                ctx,
                address(auction),
                abi.encodeWithSelector(auction.claimToken.selector, 0), 
                claimSecretKey
            );
        require(status4 == ConfRequest.Status.SUCCESS, "claim the secret failed");
        bytes memory claimedTokenDecoded = Suave.aesDecrypt(claimSecretKey, resData4);

        console2.log(string(claimedTokenDecoded));

        assertEq(keccak256(abi.encode(secret)), keccak256(claimedSecretDecoded));
    }

    function test_checkBidValidity_auctionDeadline() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint256 bidAmount = 100;
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);

        cheats.expectRevert(bytes("Auction has ended"));
        cheats.warp(block.timestamp + auctionDuration + 1);
        auction.checkBidValidity(0, bidderA, bidAmount);
    }

    function test_checkBidValidity_nonSufficientFunds() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint256 bidAmount = 100_000 ether;
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);

        cheats.expectRevert(bytes("Insufficient funds"));
        auction.checkBidValidity(0, bidderA, bidAmount);
    }

    function test_checkBidValidity_sufficientFunds() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "xx";
        uint256 bidAmount = 100;
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);
        auction.checkBidValidity(0, bidderA, bidAmount);
    }

    function test_checkBidValidity_zeroBid() public {
        _setup();
        address payoutAddressOrg = address(1);
        string memory secret = "my secret";
        uint256 bidAmount = 0;
        uint64 auctionDuration = 3600;

        TokenAuction auction = newAuction(secret, payoutAddressOrg, auctionDuration);

        cheats.expectRevert(bytes("Bid amount should be greater than zero"));
        auction.checkBidValidity(0, bidderA, bidAmount);
    }

    function test_settleVickeryAuction_singleBid() public view {
        Bid[] memory bids = new Bid[](1);
        bids[0] = Bid({
            id: 11,
            bidder: bidderA,
            amount: 100
        });

        (Bid memory winningBid, uint scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
        assertEq(winningBid.id, bids[0].id);
        assertEq(scndBestBidAmount, bids[0].amount);
    }

    function test_settleVickeryAuction_twoEqualBidsFIFO() public view {
        Bid[] memory bids = new Bid[](2);
        bids[0] = Bid({
            id: 11,
            bidder: bidderA,
            amount: 100
        });
        bids[1] = Bid({
            id: 12,
            bidder: bidderA,
            amount: 100
        });
        (Bid memory winningBid, uint scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
        
        assertEq(winningBid.id, bids[0].id);
        assertEq(scndBestBidAmount, bids[0].amount);
    }


    function test_settleVickeryAuction_twoEqualOneUniqueBid() public view {
        Bid[] memory bids = new Bid[](3);
        bids[0] = Bid({
            id: 0,
            bidder: bidderA,
            amount: 100
        });
        bids[1] = Bid({
            id: 1,
            bidder: address(2),
            amount: 100
        });
        bids[2] = Bid({
            id: 2,
            bidder: address(3),
            amount: 90
        });
        (Bid memory winningBid, uint scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
        
        assertEq(winningBid.id, bids[0].id);
        assertEq(scndBestBidAmount, bids[0].amount);
    }

    function test_settleVickeryAuction_twoUniqueBids() public view {
        Bid[] memory bids = new Bid[](2);
        bids[0] = Bid({
            id: 0,
            bidder: bidderA,
            amount: 90
        });
        bids[1] = Bid({
            id: 1,
            bidder: address(2),
            amount: 100
        });
        (Bid memory winningBid, uint scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
        
        assertEq(winningBid.id, bids[1].id);
        assertEq(scndBestBidAmount, bids[0].amount);
    }

    function test_settleVickeryAuction_threeUniqueBids() public view {
        Bid[] memory bids = new Bid[](3);
        bids[0] = Bid({
            id: 0,
            bidder: bidderA,
            amount: 90
        });
        bids[1] = Bid({
            id: 1,
            bidder: address(2),
            amount: 100
        });
        bids[2] = Bid({
            id: 2,
            bidder: address(3),
            amount: 110
        });
        (Bid memory winningBid, uint scndBestBidAmount) = BidUtils.settleVickeryAuction(bids);
        
        assertEq(winningBid.id, bids[2].id);
        assertEq(scndBestBidAmount, bids[1].amount);
    }

}
