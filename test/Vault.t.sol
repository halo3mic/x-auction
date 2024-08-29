pragma solidity ^0.8.9;

import "lib/forge-std/src/Test.sol";

import "contracts/SettlementVault.sol";
import "contracts/utils/SigUtils.sol";

interface ICheats {
    function startPrank(address target) external;

    function deal(address who, uint256 newBalance) external;

    function etch(address who, bytes calldata code) external;
}

interface IVault {
    function takeFunds(address account, uint192 amount, bytes calldata sig) external;

    function registerAuctionMaster(address _auctionMaster) external;

    function lock() external payable;
}

contract VaultTest is Test {
    ICheats cheats = ICheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function test_takeFunds() public {
        SettlementVault _vaultTemp = new SettlementVault();
        IVault vault = IVault(0xcbD195DBae10AbE7Dec2dd5e7723677Cfc3DC7cE);
        cheats.etch(address(vault), address(_vaultTemp).code);
        vault.registerAuctionMaster(0x5f152Cbf639a28a9Bb4D365349a8561d806f000f);

        address paymentAccount = 0xc06d73162E9BffbCfBF1DA59C511002A8F9155E5;
        cheats.deal(paymentAccount, 100);
        cheats.startPrank(paymentAccount);
        vault.lock{value: 100}();

        address takerAccount = address(1);
        cheats.startPrank(takerAccount);
        bytes
            memory sig = hex"8b7646d2ff2ba0f86a59c990825f2947fc35a56433ea9e1e5e69dfb4d6754c895edad23d9730233035f2271372b0dc236864fba53d79f3ba88463eb822b9f80c00";
        vault.takeFunds(paymentAccount, 100, sig);
        assertEq(takerAccount.balance, 100);
    }
}
