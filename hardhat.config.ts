import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import { config as dconfig } from "dotenv";
import "hardhat-deploy";

import "./tasks/auction-tasks";
import "./tasks/lock-funds";

dconfig();
const HOLESKY_RPC = getEnvValSafe("HOLESKY_RPC");
const HOLESKY_PK = getEnvValSafe("HOLESKY_PK");
const TOLIMAN_RPC = getEnvValSafe("TOLIMAN_RPC");
const TOLIMAN_PK = getEnvValSafe("TOLIMAN_PK");
const SUAVE_LOCAL_RPC = getEnvValSafe("SUAVE_LOCAL_RPC");
const SUAVE_LOCAL_PK = getEnvValSafe("SUAVE_LOCAL_PK");

const config = {
  solidity: "0.8.13",
  defaultNetwork: "toliman",
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    holesky: {
      chainId: 17000,
      url: HOLESKY_RPC,
      accounts: [HOLESKY_PK],
    },
    toliman: {
      chainId: 33626250,
      url: TOLIMAN_RPC,
      accounts: [TOLIMAN_PK],
      companionNetworks: {
        holesky: "holesky",
      },
    },
    suave: {
      chainId: 16813125,
      url: SUAVE_LOCAL_RPC,
      accounts: [SUAVE_LOCAL_PK],
      companionNetworks: {
        holesky: "holesky",
      },
    },
  },
};

export default config;

function getEnvValSafe(key: string): string {
  const endpoint = process.env[key];
  if (!endpoint) throw `Missing env var ${key}`;
  return endpoint;
}
