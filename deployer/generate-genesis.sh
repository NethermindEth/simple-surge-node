# This script deploys the Surge protocol on L1
set -e

# Bond configuration
# ---------------------------------------------------------------
# Liveness bond amount in wei (default: 128 ETH)
export LIVENESS_BOND=${LIVENESS_BOND:-"128000000000000000000"}

# Withdrawal delay in seconds (default: 1 hour)
export WITHDRAWAL_DELAY=${WITHDRAWAL_DELAY:-3600}

# Minimum bond amount in wei (default: 0)
export MIN_BOND=${MIN_BOND:-0}

# Bond token address (default: zero address for native ETH)
export BOND_TOKEN=${BOND_TOKEN:-"0x0000000000000000000000000000000000000000"}

echo "=== Genesis Configuration ==="
echo "CONTRACT_OWNER: $CONTRACT_OWNER"
echo "CHAIN_ID: $CHAIN_ID"
echo "L1_CHAIN_ID: $L1_CHAIN_ID"
echo "LIVENESS_BOND: $LIVENESS_BOND"
echo "WITHDRAWAL_DELAY: $WITHDRAWAL_DELAY"
echo "MIN_BOND: $MIN_BOND"
echo "BOND_TOKEN: $BOND_TOKEN"
echo "REMOTE_SIGNAL_SERVICE: $REMOTE_SIGNAL_SERVICE"
echo "============================="

# Run genesis generation
pnpm genesis:gen

cp /app/test/genesis/data/genesis.json /deployment/surge_genesis.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge L2 genesis generation completed successfully        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
