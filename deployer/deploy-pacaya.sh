#!/bin/bash

# Script to deploy the Pacaya protocol (Pacaya)
# Usage: ./script/pacaya-deployer.sh

set -e

export DEVNET_CHAIN_ID=${L1_CHAIN_ID}

# Fetch and validate DEVNET_BEACON_GENESIS
BEACON_GENESIS_RAW=$(curl -s "$L1_BEACON_HTTP/eth/v1/beacon/genesis" | jq -r '.data.genesis_time')
echo "Raw DEVNET_BEACON_GENESIS value: '$BEACON_GENESIS_RAW'"

# Check if jq returned "null" (as a string) or empty
if [ -z "$BEACON_GENESIS_RAW" ] || [ "$BEACON_GENESIS_RAW" = "null" ]; then
    echo "Error: DEVNET_BEACON_GENESIS is empty or null. Beacon service may not be ready."
    echo "Tried to fetch from: $L1_BEACON_HTTP/eth/v1/beacon/genesis"
    exit 1
fi

export DEVNET_BEACON_GENESIS="$BEACON_GENESIS_RAW"
export DEVNET_SECONDS_IN_SLOT=$(curl -s "$L1_BEACON_HTTP/eth/v1/config/spec" | jq -r '.data.SECONDS_PER_SLOT')
export DEVNET_OP_CHANGE_DELAY="0"
export DEVNET_RANDOMNESS_DELAY="0"

echo "DEVNET_SECONDS_IN_SLOT: $DEVNET_SECONDS_IN_SLOT"

export TAIKO_ANCHOR_ADDRESS="0x${L2_CHAIN_ID}0000000000000000000000000000010001"
export L2_SIGNAL_SERVICE="0x${L2_CHAIN_ID}0000000000000000000000000000000005"
export CONTRACT_OWNER=${CONTRACT_OWNER}
export L2_GENESIS_HASH="0x560214ec5cf2d01f8dbbeb8062c5f187cd8a356fa6e0faa577767566e2f570ad"
export DEPLOY_PRECONF_CONTRACTS="true"
export SHARED_RESOLVER="0x0000000000000000000000000000000000000000"
export TAIKO_TOKEN="0x0000000000000000000000000000000000000000"
export TAIKO_TOKEN_PREMINT_RECIPIENT=${CONTRACT_OWNER}
export OLD_FORK_TAIKO_INBOX="0x0000000000000000000000000000000000000000"
export PROVER_SET_ADMIN=${CONTRACT_OWNER}
export FOUNDRY_PROFILE="layer1"
export PRIVATE_KEY=${PRIVATE_KEY}
export PAUSE_BRIDGE="true"
export PRECONF_INBOX="false"
export PRECONF_ROUTER="false"
export DUMMY_VERIFIERS="true"
export INCLUSION_WINDOW="24"
export INCLUSION_FEE_IN_GWEI="100"

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

# Parameterize verification
export VERIFY_ARG=""
if [ "$VERIFY" = "true" ]; then
    VERIFY_ARG="--verify"
fi

# Verify the variable is set before calling setup.sh
echo "Verifying DEVNET_BEACON_GENESIS before setup.sh: $DEVNET_BEACON_GENESIS"

./setup.sh

forge script ./script/layer1/based/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT

cp ./deployments/deploy_l1.json /deployment/deploy_l1_pacaya.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Pacaya SCs deployment completed successfully              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
