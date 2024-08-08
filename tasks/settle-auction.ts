import { HardhatRuntimeEnvironment as HRE } from 'hardhat/types'
import { task, types } from 'hardhat/config'
import { ethers } from 'ethers'

import { SuaveContract, SuaveJsonRpcProvider, SuaveWallet } from 'ethers-suave'
import * as utils from './utils'


task('settle-auction', 'Settle auction')
    .addPositionalParam('auctionId', 'Auction ID', null, types.string)
    .addOptionalParam('auctionContract', 'Address of the auction contract')
	.setAction(async function (taskArgs: any, hre: HRE) {
        const config = await getConfig(hre, taskArgs)
        await settleAuction(config)
	})

async function settleAuction(c: IConfig) {
    const response = c.AuctionContract.settleAuction.sendCCR(c.auctionId)
    await utils.prettyPromise(response, c.AuctionContract.interface, 'SettleAuction')
        .then(utils.handleResult)
}

// Config

interface IConfig {
    AuctionContract: SuaveContract,
    auctionId: bigint,
}

async function getConfig(hre: HRE, taskArgs: any): Promise<IConfig> {
    const { suaveWallet } = getEnvConfig(hre)
    const { AuctionContract: ac, ...taskConfig } = await getTaskConfig(hre, taskArgs)
    const AuctionContract = new SuaveContract(
        ac.target as string,
        ac.interface, 
        suaveWallet
    )
    return {
        AuctionContract,
        ...taskConfig,
    }
}

function getEnvConfig(hre: HRE) {
    const networkConfig = hre.network.config
    const suaveProvider = new SuaveJsonRpcProvider((networkConfig as any).url)
    const suaveWallet = new SuaveWallet((networkConfig as any).accounts[0], suaveProvider)
    return { suaveWallet }
}

async function getTaskConfig(hre: HRE, taskArgs: any) {
    const auctionId = BigInt(taskArgs.auctionId)
    const AuctionContract = await utils.getContract(
        hre, 
        'TokenAuction', 
        taskArgs.auctionContract
    )
    return {
        AuctionContract,
        auctionId,
    }

}