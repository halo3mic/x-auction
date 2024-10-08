// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {AuctionPayout} from "./utils/AuctionUtils.sol";
import "./utils/SigUtils.sol";

contract SettlementVault {
    event Locked(address indexed account, uint192 amount, uint64 unlockTimestamp);
    event ScheduledUnlock(address indexed account, uint64 unlockTimestamp);
    event Withdrawn(address indexed account, uint192 amount);
    event FundsTaken(address indexed account, uint192 amount, address indexed to);

    struct AccountBalance {
        uint64 unlockTimestamp;
        uint192 balance;
    }

    uint64 immutable withdrawPeriod = 1 days; // todo: set at deployment?
    mapping(address => AccountBalance) internal _balances;
    address immutable owner = msg.sender;
    address public auctionMaster;
    mapping(address => uint16) public accountToPaymentNonce;

    function registerAuctionMaster(address _auctionMaster) external {
        // require(auctionMaster == address(0), "Auction master already set");
        require(msg.sender == owner, "Unauthorized");
        auctionMaster = _auctionMaster;
    }

    function getBalance(address account) external view returns (uint256, uint64) {
        return (_balances[account].balance, _balances[account].unlockTimestamp);
    }

    function lock() external payable {
        require(msg.value > 0, "Value must be greater than 0");
        _balances[msg.sender] = AccountBalance(type(uint64).max, uint192(msg.value));
        emit Locked(msg.sender, uint192(msg.value), type(uint64).max);
    }

    function scheduleUnlock() external {
        require(_balances[msg.sender].unlockTimestamp > 0, "No funds locked");
        uint64 newUnlockTimestamp = uint64(block.timestamp) + withdrawPeriod;
        _balances[msg.sender].unlockTimestamp = newUnlockTimestamp;
        emit ScheduledUnlock(msg.sender, newUnlockTimestamp);
    }

    function withdraw() external {
        AccountBalance memory bal = _balances[msg.sender];
        require(bal.unlockTimestamp <= block.timestamp, "Funds are still locked");
        _balances[msg.sender] = AccountBalance(0, 0);
        uint192 amount = bal.balance;
        _nativeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function takeFunds(address account, uint192 amount, bytes memory payoutSignature) external {
        address taker = msg.sender;
        AuctionPayout memory payout = AuctionPayout(
            address(this),
            taker,
            accountToPaymentNonce[taker],
            account,
            amount
        );
        _verifySignature(payout, payoutSignature);
        require(_balances[account].balance >= amount, "Insufficient funds");
        unchecked {
            _balances[account].balance -= amount;
        }
        accountToPaymentNonce[taker]++;
        _nativeTransfer(msg.sender, amount);
        emit FundsTaken(account, amount, account);
    }

    function _nativeTransfer(address to, uint192 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function _verifySignature(AuctionPayout memory payout, bytes memory signature) internal view {
        bytes32 digest = keccak256(abi.encode(payout));
        address signer = recoverSigner(digest, signature);
        require(signer == auctionMaster, "Invalid signature");
    }
}
