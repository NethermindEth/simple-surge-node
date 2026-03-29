#!/bin/sh
# This script deploys the CrossChainRelay on L2 only.
# The relay forwards bridge messages to arbitrary targets.
set -e

export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
fi

export VERIFY_ARG=""
if [ "$VERIFY" = "true" ]; then
    VERIFY_ARG="--verify"
fi

export SLOW_ARG=""
if [ "$SLOW" = "true" ]; then
    SLOW_ARG="--slow"
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Deploying CrossChainRelay on L2                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"

FOUNDRY_PROFILE=shared forge script ./script/shared/surge/DeployCrossChainRelay.s.sol:DeployCrossChainRelay \
    --fork-url $FORK_URL \
    --evm-version paris \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    $SLOW_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ CrossChainRelay deployed on L2                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
