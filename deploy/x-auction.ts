import { SuaveContract, SuaveJsonRpcProvider, SuaveWallet } from "ethers-suave";
import * as hh from "hardhat";
import { DeployOptions, makeDeployCallback } from "./deploy-utils";

// todo: choose between networks
// const settlementRpcEndpoint = 'holesky'
const settlementRpcEndpoint = "https://ethereum-holesky-rpc.publicnode.com";
const deployOptions: DeployOptions = {
  name: "TokenAuction",
  contractName: "TokenAuction",
  args: [],
  tags: ["token-auction"],
};

const beforeCallback = async () => {
  const SettlementVault = await hh.companionNetworks[
    "holesky"
  ].deployments.getOrNull("SettlementVault");
  if (!SettlementVault) {
    throw new Error("SettlementVault must be deployed first");
  }
  return [SettlementVault.address, settlementRpcEndpoint];
};

const afterCallback = async (deployments: any, deployResult: any) => {
  const suaveNetworkConfig: any = hh.network.config;
  const suaveProvider = new SuaveJsonRpcProvider(suaveNetworkConfig.url);
  const suaveWallet = new SuaveWallet(
    suaveNetworkConfig.accounts[0],
    suaveProvider
  );
  const AuctionContract = new SuaveContract(
    deployResult.address,
    deployResult.abi,
    suaveWallet
  );

  deployments.log("\t1.) Initalizing AuctionContract");
  const isInitiated = await AuctionContract.isInitialized();
  if (!isInitiated) {
    const receipt = await AuctionContract.confidentialConstructor
      .sendCCR()
      .then((tx) => tx.wait());
    if (receipt.status == 0)
      throw new Error("ConfidentialInit callback failed");
  }

  deployments.log("\t2.) Registering auction-master for SettlementVault");
  const auctionMaster = await AuctionContract.auctionMaster();
  const settlementVaultDeployment = await hh.companionNetworks[
    "holesky"
  ].deployments.get("SettlementVault");
  const holeskyNetworkConfig = hh.config.networks["holesky"] as any;
  const holeskyProvider = new hh.ethers.JsonRpcProvider(
    holeskyNetworkConfig.url
  );
  const holeskyWallet = new hh.ethers.Wallet(
    holeskyNetworkConfig.accounts[0],
    holeskyProvider
  );
  const SettlementVault = new hh.ethers.Contract(
    settlementVaultDeployment.address,
    settlementVaultDeployment.abi,
    holeskyWallet
  );

  const registerReceipt = await SettlementVault.registerAuctionMaster(
    auctionMaster
  ).then((tx) => tx.wait());
  if (registerReceipt.status == 0)
    throw new Error("Auction master registration failed");

  console.log(
    `AuctionContract: ${deployResult.address} | SettlementVaultContract: ${settlementVaultDeployment.address}`
  );
  console.log("Complete 🎉");
};

module.exports = makeDeployCallback(
  deployOptions,
  beforeCallback,
  afterCallback
);
