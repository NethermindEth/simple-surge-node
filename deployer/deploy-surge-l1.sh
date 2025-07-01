#!/bin/sh

set -eou

export FORK_URL=${L1_ENDPOINT_HTTP}

mkdir -p /app/test/sgx-assets && curl ${TCB_LINK} -o /app/test/sgx-assets/temp.json && curl ${QE_IDENTITY_LINK} -o /app/test/sgx-assets/qe_identity.json && jq '.tcbInfo.fmspc |= ascii_downcase' /app/test/sgx-assets/temp.json > /app/test/sgx-assets/tcb_info.json && ./script/layer1/surge/deploy_surge_l1.sh
