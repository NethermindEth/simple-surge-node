#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$SCRIPT_DIR/util/common.sh"

# Configuration with defaults
L1_PACKAGE_DIR="${L1_PACKAGE_DIR:-../surge-ethereum-package}"
L1_ENVIRONMENT="${L1_ENVIRONMENT:-local}"
L1_MODE="${L1_MODE:-silence}"
L1_RPC_URL="${L1_RPC_URL:-http://localhost:32003}"
L1_STABILIZE_WAIT="${L1_STABILIZE_WAIT:-20}"
ENABLE_PROVER="${ENABLE_PROVER:-false}"
ENV_FILE="${ENV_FILE:-.env.devnet}"

echo "Starting CI Devnet Provision Check (No Provers)"
echo

# Navigate to project root
cd "$PROJECT_ROOT"

# Step 0: Deploy L1 Devnet
echo "Step 0: Deploy L1 Devnet"
deploy_l1 "$L1_PACKAGE_DIR" "$L1_ENVIRONMENT" "$L1_MODE"
echo

# Step 0.5: Wait for L1 to be ready
echo "Step 0.5: Verify L1 is ready"
print_info "Waiting ${L1_STABILIZE_WAIT} seconds for L1 to stabilize..."
sleep "$L1_STABILIZE_WAIT"

wait_for_rpc "$L1_RPC_URL"
echo

# Step 0.6: Configure environment for no-prover testing
if [ "$ENABLE_PROVER" = "false" ]; then
    echo "Step 0.6: Configure environment for no-prover testing"
    configure_env_no_provers "$ENV_FILE"
    echo
fi

# Run the actual provision check
echo "Running Devnet Provision Check"
"$SCRIPT_DIR/devnet-e2e-provision-check.sh"
