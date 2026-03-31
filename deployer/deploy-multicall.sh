# This script deploys the Multicall contract.
set -e

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

# Parameterize slow mode
export SLOW_ARG=""
if [ "$SLOW" = "true" ]; then
    SLOW_ARG="--slow"
fi

forge script ./script/shared/surge/DeployMulticall.s.sol:DeployMulticall \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    $SLOW_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY


# Copy deployment results to /deployment
cp ./deployments/composability.json /deployment/composability_multicall.json

echo
echo "============================================="
echo " ✅ Multicall contract deployment completed successfully"
echo "============================================="
echo
