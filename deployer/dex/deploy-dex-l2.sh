#!/bin/bash
# Deploy Cross-Chain DEX L2 contracts (SwapTokenL2, SimpleDEX, CrossChainSwapVaultL2).
# Outputs: /deployment/cross-chain-dex-l2.json
# No lock files or verification — that's handled by the host orchestrator.
set -e

DEPLOYMENT_DIR="${DEPLOYMENT_DIR:-/deployment}"
L2_DEPLOY_JSON="$DEPLOYMENT_DIR/cross-chain-dex-l2.json"

if [[ -f "$L2_DEPLOY_JSON" ]]; then
    echo "L2 DEX contracts already deployed — skipping"
    exit 0
fi

echo "============================================="
echo " Deploying DEX L2 contracts"
echo "============================================="

SENDER=$(cast wallet address --private-key "$PRIVATE_KEY")
echo "  Deployer:  $SENDER"
echo "  L2 RPC:    $L2_RPC"
echo ""

export FOUNDRY_PROFILE="layer2"

forge script ./script/layer2/surge/cross-chain-dex/DeployCrossChainDexL2.s.sol:DeployCrossChainDexL2 \
    --fork-url "$L2_RPC" \
    --broadcast \
    ${LOG_LEVEL:--vv} \
    --private-key "$PRIVATE_KEY"

cp deployments/cross-chain-dex-l2.json "$L2_DEPLOY_JSON"

echo ""
echo "  L2 Vault:  $(jq -r '.CrossChainSwapVaultL2' "$L2_DEPLOY_JSON")"
echo "  L2 DEX:    $(jq -r '.SimpleDEX' "$L2_DEPLOY_JSON")"
echo "  L2 Token:  $(jq -r '.SwapTokenL2' "$L2_DEPLOY_JSON")"
echo ""
echo "============================================="
echo " DEX L2 contracts deployed"
echo "============================================="
