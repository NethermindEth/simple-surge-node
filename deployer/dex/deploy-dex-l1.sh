#!/bin/bash
# Deploy Cross-Chain DEX L1 contracts (SwapToken + CrossChainSwapVaultL1).
# Outputs: /deployment/cross-chain-dex-l1.json
# No lock files or verification — that's handled by the host orchestrator.
set -e

DEPLOYMENT_DIR="${DEPLOYMENT_DIR:-/deployment}"
L1_DEPLOY_JSON="$DEPLOYMENT_DIR/cross-chain-dex-l1.json"

if [[ -f "$L1_DEPLOY_JSON" ]]; then
    echo "L1 DEX contracts already deployed — skipping"
    exit 0
fi

echo "============================================="
echo " Deploying DEX L1 contracts"
echo "============================================="

SENDER=$(cast wallet address --private-key "$PRIVATE_KEY")
echo "  Deployer:  $SENDER"
echo "  L1 RPC:    $L1_RPC"
echo ""

export FOUNDRY_PROFILE="layer1"

forge script ./script/layer1/surge/cross-chain-dex/DeployCrossChainDexL1.s.sol:DeployCrossChainDexL1 \
    --fork-url "$L1_RPC" \
    --broadcast \
    ${LOG_LEVEL:--vv} \
    --private-key "$PRIVATE_KEY"

cp deployments/cross-chain-dex-l1.json "$L1_DEPLOY_JSON"

echo ""
echo "  L1 Vault:  $(jq -r '.CrossChainSwapVaultL1' "$L1_DEPLOY_JSON")"
echo "  L1 Token:  $(jq -r '.SwapToken' "$L1_DEPLOY_JSON")"
echo ""
echo "============================================="
echo " DEX L1 contracts deployed"
echo "============================================="
