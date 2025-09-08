#!/bin/sh

set -e

cast send ${SURGE_PROPOSER_WRAPPER} 'depositBond(uint256)' ${BOND_AMOUNT} --value ${BOND_AMOUNT} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}
