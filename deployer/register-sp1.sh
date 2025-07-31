#!/bin/sh

set -eu

echo "Starting to set up SP1 trusted program vkey..."

cast send ${SP1_RETH_VERIFIER} 'setProgramTrusted(bytes32,bool)' ${SP1_BLOCK_PROVING_PROGRAM_VKEY} true --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}
cast send ${SP1_RETH_VERIFIER} 'setProgramTrusted(bytes32,bool)' ${SP1_AGGREGATION_PROGRAM_VKEY} true --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}

echo "SP1 trusted program vkey set successfully"
