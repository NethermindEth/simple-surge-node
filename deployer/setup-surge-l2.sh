#!/bin/sh

set -e

./script/layer2/surge/setup_surge_l2.sh

# Copy deployment results to /deployment
cp /app/deployments/setup_l2.json /deployment/setup_l2.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge L2 SCs deployment completed successfully            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
