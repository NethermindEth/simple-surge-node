# This script deploys UserOpsSubmitterFactory and optionally creates a UserOpsSubmitter via the factory.
# If OWNER_ADDRESS is set, it will create a submitter for that owner.
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

forge script ./script/shared/surge/DeployUserOpsSubmitter.s.sol:DeployUserOpsSubmitter \
    --fork-url $FORK_URL \
    $BROADCAST_ARG \
    $VERIFY_ARG \
    $SLOW_ARG \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY


# Copy deployment results to /deployment
cp ./deployments/composability.json /deployment/composability_userops_submitter.json

echo
echo "============================================="
echo " ✅ User Ops Submitter deployment completed successfully"
echo "============================================="
echo
