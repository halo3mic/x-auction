pragma solidity ^0.8.9;

import "../lib/suave-std/src/Test.sol";
import "forge-std/console2.sol";

import {TokenAuction} from "../contracts/Auction.sol";
import {NewAuctionArgs, AuctionStatus} from "../contracts/lib/AuctionUtils.sol";

library TUtil {
    function sig(
        bytes memory callData
    ) internal pure returns (bytes4 selector) {
        assembly {
            selector := mload(add(callData, 0x20))
        }
    }
}

contract AuctionTest is Test, SuaveEnabled {
    address vault = address(0x0);
    string settlementChainRpc = "http://localhost:8545";

    function newAuction() internal returns (TokenAuction, bytes memory) {
        TokenAuction auction = new TokenAuction(vault, settlementChainRpc);
        NewAuctionArgs memory auctionArgs = NewAuctionArgs({
            auctionDuration: 10,
            payoutCollectionDuration: 10,
            payoutAddress: address(this)
        });
        bytes memory suaveCalldata = auction.createAuction(auctionArgs);
        return (auction, suaveCalldata);
    }

    function loadAuctions(TokenAuction auction) public {}

    function test_createAuction() public {
        // test offchain component
        (TokenAuction auction, bytes memory suaveCalldata) = newAuction();
        assertEq(
            TUtil.sig(suaveCalldata),
            auction.createAuctionCallback.selector
        );

        // we can't check the length of an array on another contract
        // so we have to check for the first element, which not existing yet, should trigger a revert
        vm.expectRevert();
        (AuctionStatus status, , , , , , ) = auction.auctions(0);

        // trigger onchain callback
        (bool ok, ) = address(auction).call{gas: 400000, value: 0}(
            suaveCalldata
        );
        assertTrue(ok); // doesn't return anything

        // state check shouldn't revert now
        (status, , , , , , ) = auction.auctions(0);
        assertEq(uint(status), uint(AuctionStatus.LIVE));
    }

    function test_cancelAuction() public {}
    function test_bid() public {}

    function test_checkBidValidity_auctionStatus() public {}
    function test_checkBidValidity_auctionDeadline() public {}
    function test_checkBidValidity_nonSufficientFunds() public {}
    function test_checkBidValidity_zeroBid() public {}
    function test_checkBidValidity_sufficientFunds() public {}

    function test_settleVickeryAuction_singleBid() public {}
    function test_settleVickeryAuction_twoEqualBids() public {}
    function test_settleVickeryAuction_twoEqualOneUniqueBid() public {}
    function test_settleVickeryAuction_twoUniqueBids() public {}
    function test_settleVickeryAuction_threeUniqueBids() public {}
}
