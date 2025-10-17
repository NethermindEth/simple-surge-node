#!/bin/bash

set -e

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Preparing SGX assets...                                      ║"
echo "║ Downloading TCB info...                                      ║"
echo "║ Downloading QE identity...                                   ║"
echo "║ Converting TCB info to lowercase...                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

mkdir -p /app/test/sgx-assets

curl ${TCB_LINK} -o /app/test/sgx-assets/temp.json 

curl ${QE_IDENTITY_LINK} -o /app/test/sgx-assets/qe_identity.json 

jq '.tcbInfo.fmspc |= ascii_downcase' /app/test/sgx-assets/temp.json > /app/test/sgx-assets/tcb_info.json 

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ SGX assets prepared successfully                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Starting to setup SGX verifier...                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

./script/layer1/surge/setup_sgx_verifier.sh

cp /app/deployments/sgx_instances.json /deployment/sgx_instances.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ SGX verifier setup successfully                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

touch /deployment/sgx_reth_verifier_setup.lock
