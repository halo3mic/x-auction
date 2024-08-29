interface ISettlementVault {
    function getBalance(address user) external returns (uint256, uint64);
    function accountToPaymentNonce(address account) external returns (uint16);
}
