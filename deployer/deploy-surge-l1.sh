#!/bin/sh

set -e

deploy_l1() {
    export FORK_URL=${L1_ENDPOINT_HTTP}
    
    echo "Deploying Surge L1 SCs..."
    ./script/layer1/surge/deploy_surge_l1.sh

    echo "Copying deployment results to /deployment..."

    cp /app/deployments/deploy_l1.json /deployment/deploy_l1.json
    
    if [ "$SHOULD_SETUP_VERIFIERS" = "true" ]; then
        cp /app/deployments/sgx_instances.json /deployment/sgx_instances.json
    fi

    echo "Deployment completed successfully"
}

deploy_l1
