import "lib/suave-std/src/protocols/EthJsonRPC.sol";
import "contracts/interface/ISettlementVault.sol";
import "contracts/utils/AuctionUtils.sol";


abstract contract AuctionCommon {
    address public vault;
    address public auctionMaster;
    Auction[] public auctions;

    bool public isInitialized;
    ISettlementVault vaultRemote;
    Suave.DataId internal pkDataId;
    Suave.DataId internal bidCountDataId;

    modifier onlyInitialized() {
        require(isInitialized, "Not initialized");
        _;
    }

}
