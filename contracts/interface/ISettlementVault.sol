


interface ISettlementVault {
    function getBalance(address user) external returns (uint, uint64);
    function accountToPaymentNonce(address account) external returns (uint16);
}