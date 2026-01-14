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
    --shastaInbox ${SHASTA_SURGE_INBOX} \
    --pacayaInbox ${PACAYA_TAIKO} \
    --taikoAnchor ${TAIKO_ANCHOR} \
    --preconfirmation.whitelist ${SHASTA_PRECONF_WHITELIST} \
    --preconfirmation.serverPort ${PRECONF_SERVER_PORT} \
    --jwtSecret /tmp/jwt/jwtsecret \
    --p2p.sequencer.key=${OPERATOR_PRIVATE_KEY} \
    --p2p.listen.tcp=9000 \
    --p2p.listen.udp=9000 \
    --p2p.useragent=taiko \
    --p2p.disable=false \
    --metrics true \
    --metrics.port 6060"

echo "Starting Driver with args: ${ARGS}"
exec taiko-client driver ${ARGS}
