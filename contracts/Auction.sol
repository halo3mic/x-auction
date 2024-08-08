// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./AuctionOffchain.sol";
import "./AuctionOnchain.sol";

// todo instead of timelock on the vault release the funds with a signature (MEVM checks funds are not used)
// todo: accounting systems that prevents users to use their funds multiple times accross different auctions
// todo: restrict access to callback methods
// todo: releasing funds only if user provides eip712 signature that specifies this (would prevent draining of funds if TEE pk is compromised) 
// todo: the same account can just reuse their funds even with the same auction

contract TokenAuction is AuctionOnchain, AuctionOffchain {
    constructor(address _vault, string memory _settlementChainRpc) 
        AuctionOnchain(_vault, _settlementChainRpc) {}
}
