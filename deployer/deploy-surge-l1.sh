#!/bin/sh

set -eou

mkdir -p /sgx-assets && curl ${TCB_LINK} -o /sgx-assets/temp.json && curl ${QE_IDENTITY_LINK} -o /sgx-assets/qe_identity.json && jq '.tcbInfo.fmspc |= ascii_downcase' /sgx-assets/temp.json > /sgx-assets/tcb_info.json && ./script/layer1/surge/deploy_surge_l1.sh
