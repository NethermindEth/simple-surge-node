#!/bin/sh

set -eou

cast send ${TAIKO_INBOX} 'depositBond(uint256)' ${BOND_AMOUNT} --value ${BOND_AMOUNT} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP} --gas-limit ${GAS_LIMIT}
