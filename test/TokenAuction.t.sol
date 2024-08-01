pragma solidity ^0.8.9;

import "../lib/suave-std/src/Test.sol";
import "forge-std/console2.sol";

import "../contracts/Auction.sol";


contract AuctionTest is Test, SuaveEnabled {

    function test_createAuction() public {}
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