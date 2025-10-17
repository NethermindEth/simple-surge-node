#!/bin/sh

set -eou pipefail

if [ "$ENABLE_P2P_SYNC" = "true" ]; then
    ARGS="--p2p.sync --p2p.checkPointSyncUrl ${P2P_SYNC_URL}"
else
    ARGS="--p2p.disable"
fi

ARGS="${ARGS} \
    --verbosity 4 \
    --l1.ws ${L1_ENDPOINT_WS} \
    --l2.ws ws://l2-nethermind-execution-client:"${L2_WS_PORT}" \
    --l1.beacon ${L1_BEACON_HTTP} \
    --l2.auth http://l2-nethermind-execution-client:${L2_ENGINE_API_PORT} \
    --taikoInbox ${TAIKO_INBOX} \
    --taikoAnchor ${TAIKO_ANCHOR} \
    --jwtSecret /tmp/jwt/jwtsecret \
    --metrics true \
    --metrics.port 6060"

echo "Starting Driver with args: ${ARGS}"
exec taiko-client driver ${ARGS}
