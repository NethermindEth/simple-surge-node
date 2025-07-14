#!/bin/sh

set -e

setup_l2() {

    echo "Deploying Surge L2 SCs..."
    ./script/layer2/surge/setup_surge_l2.sh

    echo "Copying deployment results to /deployment..."

    cp /app/deployments/setup_l2.json /deployment/setup_l2.json

    echo "Deployment completed successfully"
}

setup_l2
