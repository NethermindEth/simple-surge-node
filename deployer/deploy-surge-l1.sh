#!/bin/bash

set -e

./script/layer1/surge/deploy_surge_l1.sh

# Copy deployment results to /deployment
cp /app/deployments/deploy_l1.json /deployment/deploy_l1.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge L1 SCs deployment completed successfully            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
