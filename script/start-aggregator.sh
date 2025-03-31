#!/bin/sh

set -eou pipefail

exec api \
    --queue.username "${RABBITMQ_USER}" \
    --queue.password "${RABBITMQ_PASSWORD}" \
    --queue.host "${RABBITMQ_HOST}" \
    --queue.port "${RABBITMQ_PORT}" \
    --l1.proposerPrivKey "${L1_PROPOSER_PRIVATE_KEY}" \
    --l1.rpcUrl "${L1_RPC_URL}" \
    --MinAggregatedBlobs "${MIN_AGGREGATED_BLOBS}" \
    --minBlobsFillupPercentage "${MIN_BLOBS_FILLUP_PERCENTAGE}"
