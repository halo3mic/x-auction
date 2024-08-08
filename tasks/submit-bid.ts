import { HardhatRuntimeEnvironment as HRE } from 'hardhat/types'
import { task, types } from 'hardhat/config'
import { ethers } from 'ethers'

import { SuaveContract, SuaveJsonRpcProvider, SuaveWallet } from 'ethers-suave'
import * as utils from './utils'


task('submit-bid', 'Submit a bid to an auction')
    .addPositionalParam('auctionId', 'Auction ID to bid on.')
    .addPositionalParam('bidAmount', 'Amount to bid in ETH.', null, types.string)
    .addOptionalParam('auctionContract', 'Address of the auction contract')
	.setAction(async function (taskArgs: any, hre: HRE) {
        const config = await getConfig(hre, taskArgs)
        await submitBid(config)
	})

async function submitBid(c: IConfig) {
    const confidentialInputs = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [c.bidAmount])
    const response = c.AuctionContract.submitBid.sendCCR(c.auctionId, { confidentialInputs })
    await utils.prettyPromise(response, c.AuctionContract.interface, 'SubmitBid')
        .then(utils.handleResult)
}

// Config

interface IConfig {
    AuctionContract: SuaveContract,
    auctionId: bigint,
    bidAmount: bigint,
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
    const bidAmount = ethers.parseEther(taskArgs.bidAmount)
    const AuctionContract = await utils.getContract(
        hre, 
        'TokenAuction', 
        taskArgs.auctionContract
    )
    return {
        AuctionContract,
        auctionId,
        bidAmount,
    }

}