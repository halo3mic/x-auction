import { HardhatRuntimeEnvironment as HRE } from 'hardhat/types'
import { task, types } from 'hardhat/config'
import { ethers } from 'ethers'

import { SuaveContract, SuaveJsonRpcProvider, SuaveWallet } from 'ethers-suave'
import * as utils from './utils'


task('create-auction', 'Create an auction')
    .addPositionalParam('token', 'Token being auctioned')
    .addPositionalParam('payoutAddress', 'Address to send the payout to')
	.addOptionalParam('duration', 'Duation of the auction [s].', 86400, types.int)
	.addOptionalParam('payoutCollectionDuration', 'Amount of time funds are locked after auction settles. [s]', 3600, types.int)
    .addOptionalParam('auctionContract', 'Address of the auction contract')
	.setAction(async function (taskArgs: any, hre: HRE) {
        const config = await getConfig(hre, taskArgs)
        await createAuction(config)
	})

async function createAuction(c: IConfig) {
    const confidentialInputs = ethers.AbiCoder.defaultAbiCoder().encode(['string'], [c.token])
    const response = c.AuctionContract.createAuction.sendCCR([
        c.duration,
        c.payoutCollectionDuration,
        c.payoutAddress,
    ], { confidentialInputs })
    await utils.prettyPromise(response, c.AuctionContract.interface, 'CreateAuction')
        .then(utils.handleResult)
}

// Config

interface IConfig {
    AuctionContract: SuaveContract,
    token: string,
    payoutAddress: string,
    duration: number,
    payoutCollectionDuration: number,
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
    const token = taskArgs.token
    const payoutAddress = taskArgs.payoutAddress
    const duration = taskArgs.duration
    const payoutCollectionDuration = taskArgs.payoutCollectionDuration
    const AuctionContract = await utils.getContract(
        hre, 'TokenAuction', taskArgs.auctionContract
    )

    return {
        payoutCollectionDuration,
        AuctionContract,
        payoutAddress,
        duration,
        token,
    }

}