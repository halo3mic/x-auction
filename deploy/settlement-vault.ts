import { makeDeployCallback, DeployOptions } from './deploy-utils'

const deployOptions: DeployOptions = {
	name: 'SettlementVault', 
	contractName: 'SettlementVault', 
	args: [], 
	tags: [ 'settlement-vault' ]
}

module.exports = makeDeployCallback(deployOptions)
