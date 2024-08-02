// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "lib/suave-std/src/Test.sol";
import "forge-std/console2.sol";

import {TokenAuction} from "contracts/Auction.sol";
import {NewAuctionArgs, AuctionStatus, Auction} from "contracts/utils/AuctionUtils.sol";
import {Vault} from "contracts/SettlementVault.sol";

library ConfRequest {
    /// Sends a confidential request; calls offchain function and onchain callback.
    function sendConfRequest(
        address to,
        bytes memory data
    ) internal returns (ConfStatus, bytes memory callbackResult) {
        // offchain execution
        (bool success, bytes memory suaveCalldata) = to.call(data);
        if (!success) {
            return (ConfStatus.FAILURE_OFFCHAIN, suaveCalldata);
        }
        suaveCalldata = abi.decode(suaveCalldata, (bytes));
        // onchain callback
        (success, callbackResult) = to.call(suaveCalldata);
        if (!success) {
            return (ConfStatus.FAILURE_ONCHAIN, callbackResult);
        }
        return (ConfStatus.SUCCESS, callbackResult);
    }
}

enum ConfStatus {
    SUCCESS,
    FAILURE_OFFCHAIN,
    FAILURE_ONCHAIN
}
// =================================================================

contract AuctionTest is Test, SuaveEnabled {
    using ConfRequest for address;

    string settlementChainRpc = "http://localhost:8555";
    // deployed vault on localhost:8555 (anvil)
    Vault vault = Vault(0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35);

    function sig(
        bytes memory callData
    ) internal pure returns (bytes4 selector) {
        assembly {
            selector := mload(add(callData, 0x20))
        }
    }

    function newAuction() internal returns (TokenAuction, bytes memory) {
        TokenAuction auction = new TokenAuction(
            address(vault),
            settlementChainRpc
        );
        NewAuctionArgs memory auctionArgs = NewAuctionArgs({
            auctionDuration: uint64(block.timestamp + 1),
            payoutCollectionDuration: 1 ether,
            payoutAddress: address(this)
        });
        bytes memory suaveCalldata = auction.createAuction(auctionArgs);
        return (auction, suaveCalldata);
    }

    function test_createAuction() public {
        // test offchain component
        (TokenAuction auction, bytes memory suaveCalldata) = newAuction();
        assertEq(sig(suaveCalldata), auction.createAuctionCallback.selector);

        // we can't check the length of an array on another contract, but we can check for the first element
        // it doesn't exist, reading it should trigger a revert
        vm.expectRevert();
        (AuctionStatus status, , , , , , ) = auction.auctions(0);

        // trigger onchain callback
        (bool ok, ) = address(auction).call{gas: 400000, value: 0}(
            suaveCalldata
        );
        assertTrue(ok);

        // state check shouldn't revert now
        (status, , , , , , ) = auction.auctions(0);
        assertEq(uint(status), uint(AuctionStatus.LIVE));
    }

    function test_cancelAuction() public {
        (TokenAuction auction, bytes memory suaveCalldata) = newAuction();
        // create auction onchain immediately
        (bool ok, ) = address(auction).call{gas: 400000, value: 0}(
            suaveCalldata
        );
        assertTrue(ok);

        // cancel auction
        uint auctionId = 0;
        (ConfStatus s, ) = address(auction).sendConfRequest(
            abi.encodeWithSelector(auction.cancelAuction.selector, auctionId)
        );
        assertEq(uint(s), uint(ConfStatus.SUCCESS));
        (AuctionStatus status, , , , , , ) = auction.auctions(0);
        assertEq(uint(status), uint(AuctionStatus.CANCELLED));
    }

    function test_bid() public {
        (TokenAuction auction, bytes memory suaveCalldata) = newAuction();
        // create auction onchain immediately
        (bool ok, ) = address(auction).call{gas: 400000, value: 0}(
            suaveCalldata
        );
        assertTrue(ok);

        // bid
        uint auctionId = 0;
        uint256 bidAmount = 100;
        // anvil funded account
        vm.startPrank(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
        ctx.setConfidentialInputs(abi.encode(bidAmount));
        (ConfStatus s, ) = address(auction).sendConfRequest(
            abi.encodeWithSelector(auction.submitBid.selector, auctionId)
        );
        assertEq(uint(s), uint(ConfStatus.SUCCESS));
        Auction memory auctionData = auction._getAuction(0);
        assertEq(auctionData.bids, 1);
    }

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
