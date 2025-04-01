#!/bin/sh

set -eou pipefail

if [ "$DISABLE_P2P_SYNC" = "false" ]; then
    exec taiko-client driver \
        --l1.ws "${L1_ENDPOINT_WS}" \
        --l2.ws ws://l2-nethermind-execution-client-extra:"${L2_WS_PORT_EXTRA}" \
        --l1.beacon "${L1_BEACON_HTTP}" \
        --l2.auth http://l2-nethermind-execution-client-extra:"${L2_ENGINE_API_PORT_EXTRA}" \
        --taikoL1 "${TAIKO_L1_ADDRESS_EXTRA}" \
        --taikoL2 "${TAIKO_L2_ADDRESS}" \
        --jwtSecret /tmp/jwt/jwtsecret \
        --metrics true \
        --p2p.sync \
        --p2p.checkPointSyncUrl "${P2P_SYNC_URL}"
else
    exec taiko-client driver \
        --l1.ws "${L1_ENDPOINT_WS}" \
        --l2.ws ws://l2-nethermind-execution-client-extra:"${L2_WS_PORT_EXTRA}" \
        --l1.beacon "${L1_BEACON_HTTP}" \
        --l2.auth http://l2-nethermind-execution-client-extra:"${L2_ENGINE_API_PORT_EXTRA}" \
        --taikoL1 "${TAIKO_L1_ADDRESS_EXTRA}" \
        --taikoL2 "${TAIKO_L2_ADDRESS}" \
        --jwtSecret /tmp/jwt/jwtsecret \
        --metrics true
fi
