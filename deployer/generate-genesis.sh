# This script deploys the Surge protocol on L1
set -e

export SEED_ADDRESS=${PUBLIC_KEY},${OPERATOR_PUBLIC_KEY},${SUBMITTER_PUBLIC_KEY}
export SEED_AMOUNT=1000

echo "SEED_ADDRESS: $SEED_ADDRESS"

echo
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
