import { Contract, ethers, JsonRpcProvider, Wallet } from "ethers";
import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment as HRE } from "hardhat/types";

import * as utils from "./utils";

task("lock-funds", "Lock funds in the vault")
  .addPositionalParam("lockAmount", "Amount to lock in ETH.", null, types.string)
  .addOptionalParam("vault", "Address of the vault contract")
  .setAction(async function (taskArgs: any, hre: HRE) {
    // todo; check network is holesky/mainnet
    const config = await getConfig(hre, taskArgs);
    await lockFunds(config);
  });

async function lockFunds(c: IConfig) {
  const response = c.VaultContract.lock({ value: c.lockAmount });
  await utils
    .prettyPromise(response, c.VaultContract.interface, "LockFunds")
    .then(utils.handleResult);
}

// Config

interface IConfig {
  VaultContract: Contract;
  lockAmount: bigint;
}

async function getConfig(hre: HRE, taskArgs: any): Promise<IConfig> {
  const { wallet } = getEnvConfig(hre);
  const { VaultContract: vc, ...taskConfig } = await getTaskConfig(hre, taskArgs);
  const VaultContract = new Contract(vc.target as string, vc.interface, wallet);
  return {
    VaultContract,
    ...taskConfig,
  };
}

function getEnvConfig(hre: HRE) {
  const networkConfig = hre.network.config;
  const provider = new JsonRpcProvider((networkConfig as any).url);
  const wallet = new Wallet((networkConfig as any).accounts[0], provider);
  return { wallet };
}

async function getTaskConfig(hre: HRE, taskArgs: any) {
  const lockAmount = ethers.parseEther(taskArgs.lockAmount);
  const VaultContract = await utils.getContract(hre, "SettlementVault", taskArgs.auctionContract);
  return {
    VaultContract,
    lockAmount,
  };
}
