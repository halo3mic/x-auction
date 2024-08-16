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
        const config = await getConfig<ITaskArgsCreate>(hre, taskArgs)
        await createAuction(config)
	})

task('submit-bid', 'Submit a bid to an auction')
    .addPositionalParam('auctionId', 'Auction ID to bid on.')
    .addPositionalParam('bidAmount', 'Amount to bid in ETH.', null, types.string)
    .addOptionalParam('auctionContract', 'Address of the auction contract')
	.setAction(async function (taskArgs: any, hre: HRE) {
        const config = await getConfig<ITaskArgsBid>(hre, taskArgs)
        await submitBid(config)
	})

task('settle-auction', 'Settle auction')
    .addPositionalParam('auctionId', 'Auction ID', null, types.string)
    .addOptionalParam('auctionContract', 'Address of the auction contract')
	.setAction(async function (taskArgs: any, hre: HRE) {
        const config = await getConfig<ITaskArgsSimple>(hre, taskArgs)
        await settleAuction(config)
	})

task('claim-token', 'Claim token from auction')
    .addPositionalParam('auctionId', 'Auction ID', null, types.string)
    .addOptionalParam('auctionContract', 'Address of the auction contract')
    .setAction(async function (taskArgs: any, hre: HRE) {
        const config = await getConfig<ITaskArgsSimple>(hre, taskArgs)
        await claimToken(config)
    })

async function createAuction(c: IConfig<ITaskArgsCreate>) {
    const { token, duration, payoutCollectionDuration, payoutAddress } = c.taskArgs
    const confidentialInputs = ethers.AbiCoder.defaultAbiCoder().encode(['string'], [token])
    const response = c.AuctionContract.createAuction.sendCCR([
        duration,
        payoutCollectionDuration,
        payoutAddress,
    ], { confidentialInputs })
    await utils.prettyPromise(response, c.AuctionContract.interface, 'CreateAuction')
        .then(utils.handleResult)
}

async function submitBid(c: IConfig<ITaskArgsBid>) {
    const { auctionId, bidAmount } = c.taskArgs
    console.log(`Submitting bid of ${ethers.formatEther(bidAmount)} to auction ${auctionId}`)
    const confidentialInputs = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [bidAmount])
    const response = c.AuctionContract.submitBid.sendCCR(auctionId, { confidentialInputs })
    await utils.prettyPromise(response, c.AuctionContract.interface, 'SubmitBid')
        .then(utils.handleResult)
}

async function settleAuction(c: IConfig<ITaskArgsSimple>) {
    const response = c.AuctionContract.settleAuction.sendCCR(c.taskArgs.auctionId)
    await utils.prettyPromise(response, c.AuctionContract.interface, 'SettleAuction')
        .then(utils.handleResult)
}

async function claimToken(c: IConfig<ITaskArgsSimple>) {
    const key = ethers.id('pshhh')
    const confidentialInputs = ethers.AbiCoder.defaultAbiCoder().encode(['bytes32'], [key])

    const response = c.AuctionContract.claimToken.sendCCR(c.taskArgs.auctionId, { confidentialInputs })
        .then(r => {
            const defAbiCoder = ethers.AbiCoder.defaultAbiCoder()
            const encryptedResult = defAbiCoder.decode(['bytes'], r.confidentialComputeResult).toString()
            const decryptedResult = utils.aesDecryptStr(key, encryptedResult)
            const decoded = defAbiCoder.decode(['string'], Buffer.from(decryptedResult, 'utf-8'))
            console.log(`\n🤐 Claimed secret: ${decoded}\n`)
            return r
        })
    await utils.prettyPromise(response, c.AuctionContract.interface, 'ClaimToken')
        .then(utils.handleResult)
}

// Config

interface ITaskArgsCreate {
    token: string,
    payoutAddress: string,
    duration: number,
    payoutCollectionDuration: number,
}
interface ITaskArgsSimple {
    auctionId: string,
}
interface ITaskArgsBid extends ITaskArgsSimple {
    bidAmount: bigint,
}
interface IConfig<T> {
    AuctionContract: SuaveContract,
    taskArgs: T
}

async function getConfig<T>(hre: HRE, taskArgsRaw: any): Promise<IConfig<T>> {
    const taskArgs = parseTaskArgs<T>(taskArgsRaw)
    const { suaveWallet } = getEnvConfig(hre)
    const AuctionContract = await getSuaveAuctionContract(hre, suaveWallet, taskArgsRaw.auctionContract)
    return {
        AuctionContract,
        taskArgs,
    }
}

function getEnvConfig(hre: HRE) {
    const networkConfig = hre.network.config
    const suaveProvider = new SuaveJsonRpcProvider((networkConfig as any).url)
    const suaveWallet = new SuaveWallet((networkConfig as any).accounts[0], suaveProvider)
    return { suaveWallet }
}

function parseTaskArgs<T>(taskArgs: any): T {
    if ('duration' in taskArgs) {
        return parseTaskArgsCreate(taskArgs) as T
    } else if ('bidAmount' in taskArgs) {
        return parseTaskArgsBid(taskArgs) as T
    } else {
        return parseTaskArgsSimple(taskArgs) as T
    }
}

function parseTaskArgsCreate(taskArgs: any): ITaskArgsCreate {
    return {
        payoutCollectionDuration: taskArgs.payoutCollectionDuration as number,
        payoutAddress: taskArgs.payoutAddress as string,
        duration: taskArgs.duration as number,
        token: taskArgs.token as string,
    } as ITaskArgsCreate
}

function parseTaskArgsSimple(taskArgs: any): ITaskArgsSimple {
    return {
        auctionId: taskArgs.auctionId as string,
    } as ITaskArgsSimple
}

function parseTaskArgsBid(taskArgs: any): ITaskArgsBid {
    return {
        ...parseTaskArgsSimple(taskArgs),
        bidAmount: ethers.parseEther(taskArgs.bidAmount as string),
    } as ITaskArgsBid
}

async function getSuaveAuctionContract(
    hre: HRE, 
    swallet: SuaveWallet, 
    taAuction?: string
): Promise<SuaveContract> {
    const ac = await utils.getContract(hre, 'TokenAuction', taAuction)
    return new SuaveContract(
        ac.target as string,
        ac.interface, 
        swallet
    )
}