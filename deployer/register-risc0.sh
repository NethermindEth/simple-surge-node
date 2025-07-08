#!/bin/sh

set -eu

echo "Starting to set up RISC0 trusted image ids..."

cast send ${RISC0_GROTH16_VERIFIER} 'setImageIdTrusted(bytes32,bool)' ${RISC0_BLOCK_PROVING_IMAGE_ID} true --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}
cast send ${RISC0_GROTH16_VERIFIER} 'setImageIdTrusted(bytes32,bool)' ${RISC0_AGGREGATION_IMAGE_ID} true --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}

echo "RISC0 trusted image ids set successfully"
