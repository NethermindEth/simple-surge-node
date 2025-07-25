#!/bin/sh

set -e

deploy_proposer_wrapper() {
    export FORK_URL=${L1_ENDPOINT_HTTP}

    echo "Deploying Proposer Wrapper..."
    ./script/layer1/surge/deploy_proposer_wrapper.sh

    echo "Copying deployment results to /deployment..."

    cp /app/deployments/proposer_wrappers.json /deployment/proposer_wrappers.json

    extract_proposer_wrapper_address

    if [ "$BROADCAST" = "true" ]; then
        echo "Authorizing caller..."
        cast send ${SURGE_PROPOSER_WRAPPER} 'authorizeCaller(address)' ${ADMIN} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}
    fi

    echo "Deployment completed successfully"
}

extract_proposer_wrapper_address() {
    echo "Extracting Proposer Wrapper address..."
    export SURGE_PROPOSER_WRAPPER=$(cat /deployment/proposer_wrappers.json | jq -r '.proposer_wrapper')

    echo "Proposer Wrapper address: ${SURGE_PROPOSER_WRAPPER}"
}

deploy_proposer_wrapper
