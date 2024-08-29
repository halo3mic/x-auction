# X-Auction

## Setup

### Dependencies

Install the project dependencies:

```
yarn install
```

### Env

Setup `.env` file according to `.env.sample`.

### Sufficient funds

Make sure that you have sufficient native funds on Holesky and SUAVE networks (either Toliman testnet or local devnet). For Toliman testnet, you can get testnet gas token through its [faucet](https://faucet.toliman.suave.flashbots.net/). For local devnet, you need to manually transfer the gas token from the pre-funded account to your own account specified in the `.env` file.

## Usage

### HH Tasks

#### Lock funds into vault

Locks funds in the SettlementVault contract on the Holesky network.

```
$ npx hardhat lock-funds <lock amount in eth> --network holesky
```

Options:

- `<lock amount in eth>`: Amount to lock in ETH (required)
- `--vault`: Address of the vault contract (optional)

#### Create auction

Creates a new auction on the SUAVE network.

```
$ npx hardhat create-auction <your secret> <payment address> --duration <duration in sec> --network <suave network>
```

Options:

- `<your secret>`: Secret to be auctioned (required)
- `<payment address>`: Address to send the payout to (required)
- `--duration`: Duration of the auction in seconds (optional, default: 86400)
- `--payoutCollectionDuration`: Amount of time funds are locked after auction settles, in seconds (optional, default: 3600)
- `--auctionContract`: Address of the auction contract (optional)
- `--network`: Network to create the auction on (required, values: "toliman" or "suave")

#### Submit Bid

Submits a bid to an existing auction on the SUAVE network.

```
$ npx hardhat submit-bid <auction id> <bid amount in eth> --network <suave network>
```

Options:

- `<auction id>`: Auction ID to bid on (required)
- `<bid amount in eth>`: Amount to bid in ETH (required)
- `--auctionContract`: Address of the auction contract (optional)
- `--network`: Network to submit the bid on (required, values: "toliman" or "suave")

#### Settle Auction

Settles an auction on the SUAVE network.

```
$ npx hardhat settle-auction <auction id> --network <suave network>
```

Options:

- `<auction id>`: Auction ID to settle (required)
- `--auctionContract`: Address of the auction contract (optional)
- `--network`: Network to settle the auction on (required, values: "toliman" or "suave")

#### Claim token

Claims the token from a settled auction on the SUAVE network.

```
$ npx hardhat claim-token <auction id> --network <suave network>
```

Options:

- `<auction id>`: Auction ID to claim the token from (required)
- `--auctionContract`: Address of the auction contract (optional)
- `--network`: Network to claim the token on (required, values: "toliman" or "suave")

### Testing

```
yarn test
```

### Deployment

First deploy the settlement vault to Holesky

```
$ npx hardhat deploy --tags settlement-vault --network holesky
```

Only then deploy auction contract to chosen SUAVE network.

```
$ npx hardhat deploy --tags token-auction --network <suave network>
```

## Additional Information

- The project uses ethers-suave for interacting with Suave contracts.
- Confidential inputs are used for certain operations like creating auctions and submitting bids.
