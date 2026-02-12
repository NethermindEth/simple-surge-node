# This script deploys the Surge protocol on L1
set -e

# Parameterize broadcasting
export BROADCAST_ARG=""
if [ "$BROADCAST" = "true" ]; then
    BROADCAST_ARG="--broadcast"
    GAS_ESTIMATE_MULTIPLIER_ARG="--gas-estimate-multiplier 500"
fi

# Parameterize verification
export VERIFY_ARG=""
if [ "$VERIFY" = "true" ]; then
    VERIFY_ARG="--verify"
fi

# Parameterize slow mode
export SLOW_ARG=""
if [ "$SLOW" = "true" ]; then
    SLOW_ARG="--slow"
fi

forge script ./script/layer1/surge/DeploySurgeL1.s.sol:DeploySurgeL1 \
    $GAS_ESTIMATE_MULTIPLIER_ARG \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    $SLOW_ARG \
    --ffi \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT

# https://demerzelsolutions.slack.com/archives/D07BYJK5V40/p1770888108456519


# Copy deployment results to /deployment
cp ./deployments/deploy_l1.json /deployment/deploy_l1.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge L1 SCs deployment completed successfully            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
