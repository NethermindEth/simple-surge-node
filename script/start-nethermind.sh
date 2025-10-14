#!/bin/bash

set -eou pipefail

if [ "$ENABLE_P2P_SYNC" = "true" ]; then
    ARGS="--Discovery.Bootnodes=${BOOT_NODES}"
    # Use base port + 100 to avoid conflicts with bootnode
    P2P_PORT=$((L2_NETWORK_DISCOVERY_PORT + 100))
else
    ARGS=""
    # Use original port when P2P sync is disabled
    P2P_PORT=${L2_NETWORK_DISCOVERY_PORT}
fi

ARGS="${ARGS} \
    --config=none \
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
    --Network.DiscoveryPort=${P2P_PORT} \
    --Network.P2PPort=${P2P_PORT} \
    --Network.MaxActivePeers=${MAXPEERS} \
    --Sync.FastSync=false \
    --Sync.SnapSync=false \
    --HealthChecks.Enabled=true \
    --Pruning.PruningBoundary=1000 \
    --Surge.L1EthApiEndpoint=${L1_ENDPOINT_HTTP} \
    --Surge.TaikoInboxAddress=${TAIKO_INBOX} \
    --log=${EL_LOG_LEVEL} \
    --logger-config=/nethermind/NLog.config"

echo "Starting Nethermind Execution Client with args: ${ARGS}"
exec ./Nethermind.Runner ${ARGS}
