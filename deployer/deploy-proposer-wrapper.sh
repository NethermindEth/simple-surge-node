#!/bin/sh

set -e

./script/layer1/surge/deploy_proposer_wrapper.sh

# Copy deployment results to /deployment
cp /app/deployments/proposer_wrappers.json /deployment/proposer_wrappers.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge Proposer Wrapper deployment completed successfully  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
