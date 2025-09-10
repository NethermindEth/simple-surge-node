#!/bin/bash

set -e

if [ -f "/deployment/authorize_caller.lock" ]; then
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Caller already authorized                                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
else
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Authorizing caller...                                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    cast send ${SURGE_PROPOSER_WRAPPER} 'authorizeCaller(address)' ${ADMIN} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP}

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ ✅ Caller authorized successfully                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    touch /deployment/authorize_caller.lock
fi

cast send ${SURGE_PROPOSER_WRAPPER} "depositBond(uint256)" ${BOND_AMOUNT} --value ${BOND_AMOUNT} --private-key ${PRIVATE_KEY} --rpc-url ${L1_ENDPOINT_HTTP}

BOND_BALANCE=$(cast call ${TAIKO_INBOX} "bondBalanceOf(address)" ${SURGE_PROPOSER_WRAPPER} --rpc-url ${L1_ENDPOINT_HTTP})
BALANCE_ETH=$(cast to-unit ${BOND_BALANCE} ether)

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ 💡 Bond balance: $BALANCE_ETH ETH                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Bond deposited successfully                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
