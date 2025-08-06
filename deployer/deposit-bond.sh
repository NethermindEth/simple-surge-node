#!/bin/sh

set -e

# TODO: check if bond needs to be deposited to both

cast send ${SURGE_PROPOSER_WRAPPER} 'depositBond(uint256)' ${BOND_AMOUNT} --value ${BOND_AMOUNT} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}

# cast send ${TAIKO_INBOX} 'depositBond(uint256)' ${BOND_AMOUNT} --value ${BOND_AMOUNT} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}
