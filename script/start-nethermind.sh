#!/bin/bash

set -eou pipefail

ARGS="--config=none \
    --datadir=/data/surge \
    --Init.ChainSpecPath=/chainspec.json \
    --Init.GenesisHash=${L2_GENESIS_HASH} \
    --Metrics.Enabled=true \
    --Metrics.ExposePort=${L2_METRICS_PORT} \
    --JsonRpc.Enabled=true \
    --JsonRpc.EnabledModules=[admin,debug,eth,net,web3,txpool,rpc,subscribe,trace,personal,proof,parity,health] \
    --JsonRpc.Host=0.0.0.0 \
    --JsonRpc.Port=${L2_HTTP_PORT} \
    --JsonRpc.WebSocketsPort=${L2_WS_PORT} \
    --JsonRpc.JwtSecretFile=/tmp/jwt/jwtsecret \
    --JsonRpc.EngineHost=0.0.0.0 \
    --JsonRpc.EnginePort=${L2_ENGINE_API_PORT} \
    --Network.DiscoveryPort=${L2_NETWORK_DISCOVERY_PORT} \
    --Network.P2PPort=${L2_NETWORK_DISCOVERY_PORT} \
    --Network.MaxActivePeers=${MAXPEERS} \
    --Sync.FastSync=false \
    --Sync.SnapSync=false \
    --HealthChecks.Enabled=true \
    --Surge.L1EthApiEndpoint=${L1_ENDPOINT_HTTP} \
    --Surge.TaikoInboxAddress=${TAIKO_INBOX} \
    --log=${NETHERMIND_LOG_LEVEL}"

# Choose appropriate logger config
if [ "${USE_CONSOLE_LOGGING:-false}" = "true" ]; then
    ARGS="${ARGS} --logger-config=/nethermind/NLog-console.config"
else
    ARGS="${ARGS} --logger-config=/nethermind/NLog.config"
fi

echo "Starting Nethermind Execution Client with args: ${ARGS}"
exec ./Nethermind.Runner ${ARGS}
