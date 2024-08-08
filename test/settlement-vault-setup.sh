#!/bin/bash

port=$1
bid_eth=$2

bid=$(cast from-fixed-point 18 $bid_eth)

deploy_cost=1000000000000000000
private_key1=0x1111111111111111111111111111111111111111111111111111111111111111
private_key2=0x1111111111111111111111111111111111111111111111111111111111111112
needed_bal_wei=$((deploy_cost + bid))
spender1_address=$(cast wallet address $private_key1)
spender2_address=$(cast wallet address $private_key2)

anvil -p $port > log.txt 2>&1 &
pid=$!

echo "Anvil started on port $port with pid $pid with spender $spender1_address and $spender2_address and needed balance $needed_bal_wei"

sleep 2

cast rpc anvil_setBalance $spender1_address $needed_bal_wei --rpc-url http://localhost:$port
cast rpc anvil_setBalance $spender2_address $needed_bal_wei --rpc-url http://localhost:$port
echo "Anvil balance set"

out=$(forge create --rpc-url http://localhost:$port --private-key $private_key1 contracts/SettlementVault.sol:Vault)
deployed_address=$(echo "$out" | tail -n 2 | grep "Deployed to:" | awk '{print $3}')

echo "Vault contract created at $deployed_address"

cast send $deployed_address "lock()" --value $bid  --rpc-url http://localhost:$port --private-key $private_key1
cast send $deployed_address "lock()" --value $bid  --rpc-url http://localhost:$port --private-key $private_key2

echo "Funds sent to vault"

read -r