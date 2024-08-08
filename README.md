# X-Auction 

## Setup 
#### Dependencies
```
yarn install
```

#### Env
Setup `.env` file according to `.env.sample`.

#### Sufficient funds
Make sure that you have sufficient native funds on Holesky and Toliman.

## Usage 
### HH Tasks

#### Deposit funds into vault
```
$ npx hardhat lock-funds <auction id> <bid amount in eth> --network holesky
```

#### Create auction
```
$ npx hardhat create-auction <your secret> <payment address> --duration <duration in sec> --network toliman
````

#### Submit Bid
```
$ npx hardhat submit-bid <auction id> <bid value in eth> --network toliman
```

#### Settle Auction
```
$ npx hardhat settle-auction <auction id> --network toliman
```

#### Claim token ❌
```
$ npx hardhat claim-token <auction id> --network toliman
```

## Testing 
```
yarn test
```

## Deployment

First deploy the settlement vault to Holesky
```
$ npx hardhat deploy --tags settlement-vault --network holesky
```
Only then deploy auction contract to Toliman
```
$ npx hardhat deploy --tags token-auction --network toliman
```
