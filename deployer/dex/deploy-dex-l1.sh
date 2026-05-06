#!/bin/bash
# Deploy Cross-Chain DEX L1 contracts.
#
# Deploys:
#   - SwapToken (if SWAP_TOKEN is empty)
#   - CrossChainSwapVaultL1
#   - L1 DEX: fresh WETH9Stub + SimpleDEXL1 (test mode) OR
#             points at existing Uniswap V2 router (live mode, set L1_DEX_ROUTER + L1_DEX_WETH)
#   - Seeds L1 Vault with token + ETH inventory (for L2→L1→L2 swaps)
#
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
echo "  Deployer:       $SENDER"
echo "  L1 RPC:         $L1_RPC"
echo "  L1 Bridge:      ${L1_BRIDGE:-n/a}"
echo "  L2 Chain ID:    ${L2_CHAIN_ID:-n/a}"

if [ -n "${SWAP_TOKEN:-}" ]; then
    echo "  Swap Token:     $SWAP_TOKEN (existing)"
else
    echo "  Swap Token:     (new token will be deployed)"
    echo "  Token Supply:   ${INITIAL_TOKEN_SUPPLY:-1000000000000}"
fi
echo "  Token Decimals: ${TOKEN_DECIMALS:-6}"

if [ -n "${L1_DEX_ROUTER:-}" ]; then
    echo "  L1 DEX Mode:    Live (router=$L1_DEX_ROUTER, weth=${L1_DEX_WETH:-})"
    if [ -z "${L1_DEX_WETH:-}" ]; then
        echo "ERROR: L1_DEX_WETH must be set when L1_DEX_ROUTER is set"
        exit 1
    fi
else
    echo "  L1 DEX Mode:    Test (fresh WETH9Stub + SimpleDEXL1)"
    echo "    Seed ETH:     ${L1_DEX_SEED_ETH:-10000000000000000000}"
    echo "    Seed Tokens:  ${L1_DEX_SEED_TOKEN:-20000000000}"
fi
echo "  Vault Seed ETH: ${L1_VAULT_SEED_ETH:-10000000000000000000}"
echo "  Vault Seed Tok: ${L1_VAULT_SEED_TOKEN:-50000000000}"
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
echo "  L1 Router: $(jq -r '.L1Router // "n/a"' "$L1_DEPLOY_JSON")"
echo "  L1 WETH:   $(jq -r '.WETH // "n/a"' "$L1_DEPLOY_JSON")"
echo ""
echo "============================================="
echo " DEX L1 contracts deployed"
echo "============================================="
