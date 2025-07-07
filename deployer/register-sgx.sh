#!/bin/sh

set -eu

export FORK_URL=${L1_ENDPOINT_HTTP}

echo "Starting to register SGX instance..."
./script/layer1/surge/register_sgx_instance.sh

echo "SGX instance registered successfully"
