#!/bin/sh

set -eou pipefail

ARGS="--l1.ws ${L1_ENDPOINT_WS} \
    --l2.ws ws://l2-nethermind-execution-client:"${L2_WS_PORT}" \
    --l1.beacon ${L1_BEACON_HTTP} \
    --l2.auth http://l2-nethermind-execution-client:${L2_ENGINE_API_PORT} \
    --taikoInbox ${TAIKO_INBOX_ADDRESS} \
    --taikoAnchor ${TAIKO_ANCHOR_ADDRESS} \
    --preconfirmation.whitelist ${PRECONFIRMATION_WHITELIST} \
    --preconfirmation.serverPort 9871 \
    --jwtSecret /tmp/jwt/jwtsecret \
    --p2p.bootnodes ${P2P_BOOTNODES} \
    --p2p.listen.ip 0.0.0.0 \
    --p2p.useragent taiko \
    --p2p.listen.tcp ${P2P_LISTEN_TCP_PORT} \
    --metrics true \
    --metrics.port 6060"

if [ "$DISABLE_P2P_SYNC" = "false" ]; then
    ARGS="${ARGS} --p2p.sync \
    --p2p.checkPointSyncUrl ${P2P_SYNC_URL}"
fi

if [ -n "$PUBLIC_IP" ]; then
    ARGS="${ARGS} --p2p.advertise.ip ${PUBLIC_IP}"
else
    ARGS="${ARGS} --p2p.nat"
fi

exec taiko-client driver ${ARGS}
