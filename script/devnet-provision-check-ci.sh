#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$SCRIPT_DIR/util/common.sh"

# Configuration with defaults
L1_PACKAGE_DIR="${L1_PACKAGE_DIR:-$PROJECT_ROOT/../surge-ethereum-package}"
L1_ENVIRONMENT="${L1_ENVIRONMENT:-local}"
L1_MODE="${L1_MODE:-silence}"
L1_RPC_URL="${L1_RPC_URL:-http://localhost:32003}"
L1_STABILIZE_WAIT="${L1_STABILIZE_WAIT:-20}"
ENABLE_PROVER="${ENABLE_PROVER:-false}"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env.devnet}"

echo "Starting CI Devnet Provision Check (No Provers)"
echo

# Step 1: Deploy L1 Devnet
echo "Step 1: Deploy L1 Devnet"
deploy_l1 "$L1_PACKAGE_DIR" "$L1_ENVIRONMENT" "$L1_MODE"
echo

# Step 2: Verify L1 is ready
echo "Step 2: Verify L1 is ready"
print_info "Waiting ${L1_STABILIZE_WAIT} seconds for L1 to stabilize..."
sleep "$L1_STABILIZE_WAIT"

wait_for_rpc "$L1_RPC_URL"
echo

# Step 3: Configure environment for no-prover testing
if [ "$ENABLE_PROVER" = "false" ]; then
    echo "Step 3: Configure environment for no-prover testing"
    configure_env_no_provers "$ENV_FILE"
    echo
fi

# Step 4: Run L2 Devnet Provision Check
echo "Step 4: Run L2 Devnet Provision Check"
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/devnet-provision-check.sh"
