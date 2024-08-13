# X-Auction

## Setup

### Dependencies

```sh
yarn install
```

### Env

Setup `.env` file according to `.env.sample`.

### Sufficient funds

Make sure that you have sufficient native funds on Holesky and Toliman.

## Usage

### HH Tasks

#### Deposit funds into vault

```sh
npx hardhat lock-funds <auction id> <bid amount in eth> --network holesky
```

#### Create auction

```sh
npx hardhat create-auction <your secret> <payment address> --duration <duration in sec> --network toliman
```

### Submit Bid

```sh
npx hardhat submit-bid <auction id> <bid value in eth> --network toliman
```

#### Settle Auction

```sh
npx hardhat settle-auction <auction id> --network toliman
```

#### Claim token ❌

```sh
npx hardhat claim-token <auction id> --network toliman
```

### Testing

```sh
yarn test
```

### Deployment

First deploy the settlement vault to Holesky

```sh
npx hardhat deploy --tags settlement-vault --network holesky
```

Only then deploy auction contract to Toliman

```sh
npx hardhat deploy --tags token-auction --network toliman
```
