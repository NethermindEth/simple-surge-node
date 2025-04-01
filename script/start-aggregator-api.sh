#!/bin/sh
# Wait for RabbitMQ
until timeout 2 bash -c "cat < /dev/null > /dev/tcp/rabbitmq/5672"; do
  sleep 2
done

# Ensure the queue exists before consuming
QUEUE_NAME=${RABBITMQ_QUEUE_NAME:-"blob_aggregator_queue"}

blob-aggregator api \
    --queue.username "${RABBITMQ_USER}" \
    --queue.password "${RABBITMQ_PASSWORD}" \
    --queue.host "${RABBITMQ_HOST}" \
    --queue.port "${RABBITMQ_PORT}" \
    --http.port "${AGGREGATOR_PORT}"
