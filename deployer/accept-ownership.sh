#!/bin/sh

# This script accepts ownership of multiple contracts using the AcceptOwnership script.
set -e

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

echo "Contract addresses to accept ownership:"
echo "$CONTRACT_ADDRESSES"
echo ""
if [ "$INTERMEDIATE_CONTRACT" != "0x0000000000000000000000000000000000000000" ]; then
    echo "Intermediate contract: $INTERMEDIATE_CONTRACT"
    echo ""
fi

if [ "$BROADCAST" = "true" ]; then
    echo "Running in BROADCAST mode - transactions will be executed"
else
    echo "Running in SIMULATION mode - set BROADCAST=true to execute transactions"
fi
echo ""

forge script ./script/layer1/surge/AcceptOwnership.s.sol:AcceptOwnership \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY

touch /deployment/accept_ownership.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge accepting ownership completed successfully          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
