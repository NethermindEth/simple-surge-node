#!/bin/sh

set -eu

export FORK_URL=${L1_ENDPOINT_HTTP}

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

prepare_sgx_assets

echo "Starting to register SGX instance..."
./script/layer1/surge/register_sgx_instance.sh

echo "SGX instance registered successfully"
