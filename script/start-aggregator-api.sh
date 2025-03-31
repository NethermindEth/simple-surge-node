#!/bin/sh

set -eou pipefail

exec api \
    --queue.username "${RABBITMQ_USER}" \
    --queue.password "${RABBITMQ_PASSWORD}" \
    --queue.host "${RABBITMQ_HOST}" \
    --queue.port "${RABBITMQ_PORT}" \
    --http.port "${AGGREGATOR_PORT}"
