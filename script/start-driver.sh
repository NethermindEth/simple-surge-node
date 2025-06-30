#!/bin/sh

set -eou pipefail

ARGS="--l1.ws ${L1_ENDPOINT_WS} \
    --l2.ws ws://l2-nethermind-execution-client:"${L2_WS_PORT}" \
    --l1.beacon ${L1_BEACON_HTTP} \
    --l2.auth http://l2-nethermind-execution-client:${L2_ENGINE_API_PORT} \
    --taikoInbox ${TAIKO_INBOX} \
    --taikoAnchor ${TAIKO_ANCHOR} \
    --jwtSecret /tmp/jwt/jwtsecret \
    --p2p.disable \
    --metrics true \
    --metrics.port 6060"

exec taiko-client driver ${ARGS}
