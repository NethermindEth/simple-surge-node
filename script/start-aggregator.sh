#!/bin/sh
# Wait for RabbitMQ
until timeout 2 bash -c "cat < /dev/null > /dev/tcp/rabbitmq/5672"; do
  sleep 2
done

# Ensure the queue exists before consuming
QUEUE_NAME=${RABBITMQ_QUEUE_NAME:-"blob_aggregator_queue"}

blob-aggregator aggregator \
    --queue.username "${RABBITMQ_USER}" \
    --queue.password "${RABBITMQ_PASSWORD}" \
    --queue.host "${RABBITMQ_HOST}" \
    --queue.port "${RABBITMQ_PORT}" \
    --l1.aggregatorPrivKey "${L1_AGGREGATOR_PRIVATE_KEY}" \
    --l1.rpcUrl "${L1_ENDPOINT_HTTP}" \
    --minAggregatedBlobs "${MIN_AGGREGATED_BLOBS}" \
    --minBlobsFillupPercentage "${MIN_BLOBS_FILLUP_PERCENTAGE}"
