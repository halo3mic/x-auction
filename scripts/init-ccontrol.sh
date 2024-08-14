#!/bin/bash

network=$1
npx hardhat init-ccontrol --network $network

mkdir -p ~/.log
echo "BlockAd init executed on $(date)" >> ~/.log/suave-reinit.log