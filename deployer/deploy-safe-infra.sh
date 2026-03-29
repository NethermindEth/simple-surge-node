#!/bin/sh
# This script deploys Safe infrastructure (SafeL2, SafeProxyFactory, MultiSend, 
# MultiSendCallOnly, CompatibilityFallbackHandler) on BOTH L1 and L2.
# Must be run from a fresh deployer EOA with nonce 0 on both chains for address matching.
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

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Safe Infrastructure on L1 and L2                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo
echo "=== L1 Deployment ==="
FOUNDRY_PROFILE=shared forge script ./script/shared/surge/DeploySafeInfra.s.sol:DeploySafeInfra \
    --fork-url $L1_FORK_URL \
    --evm-version paris \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    $SLOW_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY

echo
echo "=== L2 Deployment ==="
FOUNDRY_PROFILE=shared forge script ./script/shared/surge/DeploySafeInfra.s.sol:DeploySafeInfra \
    --fork-url $L2_FORK_URL \
    --evm-version paris \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    $SLOW_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY

# Copy deployment results
cp ./deployments/safe-infra.json /deployment/safe-infra.json 2>/dev/null || true

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Safe infrastructure deployed on L1 and L2                 ║"
echo "║    Verify addresses match on both chains!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
