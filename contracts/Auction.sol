// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./AuctionOffchain.sol";
import "./AuctionOnchain.sol";

// todo instead of timelock on the vault release the funds with a signature (MEVM checks funds are not used)
// todo: accounting systems that prevents users to use their funds multiple times accross different auctions
// todo: restrict access to callback methods 

contract TokenAuction is AuctionOnchain, AuctionOffchain {
    constructor(address _vault, string memory _settlementChainRpc) 
        AuctionOnchain(_vault, _settlementChainRpc) {}
}
