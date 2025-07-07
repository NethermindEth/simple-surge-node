#!/bin/sh

set -e

prepare_sgx_assets() {
    echo "Preparing SGX assets..."
    mkdir -p /app/test/sgx-assets

    echo "Downloading TCB info..."
    curl ${TCB_LINK} -o /app/test/sgx-assets/temp.json 

    echo "Downloading QE identity..."
    curl ${QE_IDENTITY_LINK} -o /app/test/sgx-assets/qe_identity.json 

    echo "Converting TCB info to lowercase..."
    jq '.tcbInfo.fmspc |= ascii_downcase' /app/test/sgx-assets/temp.json > /app/test/sgx-assets/tcb_info.json 

    echo "SGX assets prepared successfully"
}

deploy_l1() {
    export FORK_URL=${L1_ENDPOINT_HTTP}

    echo "Deploying Surge L1 SCs..."
    ./script/layer1/surge/deploy_surge_l1.sh

    echo "Copying deployment results to /deployment..."
    cp /app/deployments/deploy_l1.json /deployment/deploy_l1.json

    echo "Deployment completed successfully"
}

prepare_sgx_assets && deploy_l1
