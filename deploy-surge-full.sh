#!/bin/bash
set -euo pipefail

# Load shared helper functions (logging, URL utils, config helpers, etc.)
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Directories
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEPLOYMENT_DIR="deployment"
readonly ETHEREUM_PACKAGE_DIR="ethereum-package"
readonly CONFIGS_DIR="configs"
readonly DEX_NGINX_CONF="surge-taiko-mono/packages/cross-chain-dex-ui/nginx.conf"
readonly DEX_ENV="surge-taiko-mono/packages/cross-chain-dex-ui/.env"
readonly DEX_DOCKERFILE="surge-taiko-mono/packages/cross-chain-dex-ui/Dockerfile.dex"

# L1 Devnet
readonly NETWORK_PARAMS="./configs/network_params.yaml"
readonly ENCLAVE_NAME="surge-devnet"
readonly BLOCKSCOUT_FILE="$ETHEREUM_PACKAGE_DIR/src/blockscout/blockscout_launcher.star"
readonly BLOCKSCOUT_CONFIG_FILE="$CONFIGS_DIR/blockscout_launcher.star"
readonly SHARED_UTILS_FILE="$ETHEREUM_PACKAGE_DIR/src/shared_utils/shared_utils.star"
readonly SHARED_UTILS_CONFIG_FILE="$CONFIGS_DIR/shared_utils.star"
readonly INPUT_PARSER_FILE="$ETHEREUM_PACKAGE_DIR/src/package_io/input_parser.star"
readonly INPUT_PARSER_CONFIG_FILE="$CONFIGS_DIR/input_parser.star"
readonly SPAMOOR_FILE="$ETHEREUM_PACKAGE_DIR/src/spamoor/spamoor.star"
readonly SPAMOOR_CONFIG_FILE="$CONFIGS_DIR/spamoor.star"
readonly MAIN_FILE="$ETHEREUM_PACKAGE_DIR/main.star"
readonly MAIN_CONFIG_FILE="$CONFIGS_DIR/main.star"
# L2 Deployment
readonly ENV_FILE=".env"
readonly L1_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/deploy_l1.json"
readonly L1_LOCK_FILE="$DEPLOYMENT_DIR/deploy_l1.lock"
readonly SURGE_GENESIS_FILE="$DEPLOYMENT_DIR/surge_genesis.json"
readonly L2_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/setup_l2.json"
readonly COMPOSABILITY_MULTICALL_FILE="$DEPLOYMENT_DIR/composability_multicall.json"
readonly COMPOSABILITY_USEROPS_SUBMITTER_FILE="$DEPLOYMENT_DIR/composability_userops_submitter.json"
readonly CROSS_CHAIN_DEX_L1_FILE="$DEPLOYMENT_DIR/cross-chain-dex-l1.json"
readonly CROSS_CHAIN_DEX_L2_FILE="$DEPLOYMENT_DIR/cross-chain-dex-l2.json"

# Default values for command line arguments
environment=""
deploy_devnet=""
deployment=""
l1_rpc_url=""
l1_beacon_rpc_url=""
l1_explorer_url=""
deployment_key=""
stack_option=""
running_provers=""
mock_prover=""
mode=""
force=""
update_submodules=""
privacy_mode=""


# Show usage help
show_help() {
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo
    echo "Description:"
    echo "  Deploy complete Surge stack with L1 (optional devnet) and L2 components"
    echo
    echo "Options:"
    echo "  --environment ENV        Config preset name — loads .env.<ENV> defaults (currently only 'devnet' ships) [REQUIRED]"
    echo "  --deploy-devnet BOOL     true = spin up fresh Kurtosis L1; false = deploy against existing L1 (Sepolia/Gnosis/mainnet/etc. configured in .env)"
    echo "  --deployment TYPE        Deployment type (local|remote)"
    echo "  --deployment-key KEY     Private key for contract deployment (will be verified)"
    echo "  --stack-option NUM       L2 stack option (0-3, see details below)"
    echo "  --running-provers BOOL   Setup provers (devnet only, true|false)"
    echo "  --mock-prover            Use mock prover (no GPU required)"
    echo "  --mode MODE              Execution mode (silence|debug)"
    echo "  -f, --force              Skip prompts; defaults to real prover unless --mock-prover is set"
    echo "  --update-submodules      Fast-forward submodules to the tip of their tracked branch instead of the pinned SHA"
    echo "  --privacy-mode           Enable Surge privacy mode (overrides SURGE_PRIVACY_MODE in .env; persists the change)"
    echo "  -h, --help               Show this help message"
    echo
    echo "Stack Options:"
    echo "  0 - None (skip L2 stack, verify external L2 RPC only — dev-only)"
    echo "  1 - Driver only"
    echo "  2 - Driver + Catalyst"
    echo "  3 - Driver + Catalyst + Spammer"
    echo
    echo "Execution Modes:"
    echo "  silence - Silent mode with progress indicators (default)"
    echo "  debug   - Debug mode with full output"
    echo
    echo "Examples:"
    echo "  # Mock prover, fresh local Kurtosis L1 — no GPU required"
    echo "  $0 --environment devnet --deploy-devnet true --mock-prover --mode silence --stack-option 2 --force"
    echo ""
    echo "  # Real prover — point at a running Raiko instance"
    echo "  $0 --environment devnet --deploy-devnet true --mode silence --stack-option 2 --force"
    echo ""
    echo "  # Deploy against an existing L1 (Sepolia/Gnosis/mainnet/etc. — edit .env first)"
    echo "  $0 --environment devnet --deploy-devnet false --mode silence --stack-option 2 --force"
    echo ""
    echo "  # Mock prover with privacy mode (no .env edit needed)"
    echo "  $0 --environment devnet --deploy-devnet true --mock-prover --privacy-mode --mode silence --stack-option 2 --force"
    echo ""
    echo "  # Interactive (prompts for each step)"
    echo "  $0 --environment devnet --deploy-devnet true"
    exit 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                environment="$2"
                shift 2
                ;;
            --deploy-devnet)
                deploy_devnet="$2"
                shift 2
                ;;
            --deployment)
                deployment="$2"
                shift 2
                ;;
            --deployment-key)
                deployment_key="$2"
                shift 2
                ;;
            --stack-option)
                stack_option="$2"
                shift 2
                ;;
            --running-provers)
                running_provers="$2"
                shift 2
                ;;
            --mock-prover)
                mock_prover="true"
                shift
                ;;
            --mode)
                mode="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            --update-submodules)
                update_submodules="true"
                shift
                ;;
            --privacy-mode)
                privacy_mode="true"
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done
}



# Run kurtosis with different settings
run_kurtosis() {
    local environment="$1"
    local mode="$2"
    
    if [[ "$mode" == "0" || "$mode" == "silence" ]]; then
        mode="silence"
    else
        mode="debug"
    fi

    log_info "Starting Surge DevNet L1 ($environment environment) in $mode mode..."
    echo 
    
    local exit_status=0
    local temp_output="/tmp/surge_devnet_l1_output_$$"
    
    # Run kurtosis based on mode
    if [[ "$mode" == "debug" ]]; then
        # Debug mode: run in foreground, capture output for error detection
        kurtosis run --enclave "$ENCLAVE_NAME" "$ETHEREUM_PACKAGE_DIR" --args-file "$NETWORK_PARAMS" --production --image-download always --verbosity brief 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        # Silent mode: run in background with progress indicator
        kurtosis run --enclave "$ENCLAVE_NAME" "$ETHEREUM_PACKAGE_DIR" --args-file "$NETWORK_PARAMS" --production --image-download always >"$temp_output" 2>&1 &
        local kurtosis_pid=$!
        show_progress $kurtosis_pid "Initializing Surge DevNet L1..."
        
        # Wait for completion and check status
        wait $kurtosis_pid
        exit_status=$?
    fi
    
    # Check for specific error patterns in the output
    local has_errors=false
    if [[ -f "$temp_output" ]]; then
        if grep -q "Error encountered running Starlark code" "$temp_output"; then
            has_errors=true
            log_error "Starlark execution failed"
        fi
    fi
    
    # Check the actual exit status and error patterns
    if [[ $exit_status -eq 0 && "$has_errors" == "false" ]]; then
        log_success "Surge DevNet L1 started successfully in $environment environment"
        return 0
    else
        log_error "Failed to start Surge DevNet L1 (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        log_error "Common issues:"
        log_error "  • Check if Docker images exist and are accessible"
        log_error "  • Verify network_params.yaml configuration"
        log_error "  • Ensure sufficient system resources"
        log_error "Contact Surge team for help if the problem persists"
        log_error "The output of the deployment is saved in $temp_output"
        log_error "Please share the output with the Surge team"
        return 1
    fi
}

# Deploy L1 devnet (Option A)
deploy_l1_devnet() {
    local deployment_choice="$1"
    local mode="$2"
    
    log_info "Deploying new L1 devnet..."
    
    # Ensure ethereum-package is available
    if ! ensure_ethereum_package; then
        log_error "Cannot deploy devnet without ethereum-package submodule"
        return 1
    fi
    
    # Check for Kurtosis
    if ! command -v kurtosis >/dev/null 2>&1; then
        log_error "Kurtosis is not installed or not in PATH"
        log_error "Please install Kurtosis: https://docs.kurtosis.com/install"
        return 1
    fi
    
    # Determine environment name for kurtosis
    local env_name="local"
    if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
        env_name="remote"
    fi
    
    # Configure all components
    if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
        local machine_ip
        machine_ip=$(get_machine_ip)
        
        if [[ -z "$machine_ip" ]]; then
            log_error "Could not determine machine IP address"
            return 1
        fi
        
        configure_remote_blockscout "$machine_ip"
    else
        configure_remote_blockscout "localhost"
    fi
    
    # Always configure shared_utils, input_parser, and spamoor
    configure_shared_utils
    configure_input_parser
    configure_spamoor

    # Run Kurtosis
    if ! run_kurtosis "$env_name" "$mode"; then
        log_error "Devnet deployment failed"
        return 1
    fi
    
    # Wait a bit for services to start
    log_info "Waiting for services to initialize..."
    sleep 10
    
    # Check health using the external endpoints (accessible from host)
    check_l1_health "$L1_ENDPOINT_HTTP_EXTERNAL" "$L1_BEACON_HTTP_EXTERNAL"
    
    log_success "L1 devnet deployed successfully"
    return 0
}

# Cleanup function
_cleanup() {
    # Clean up backup files
    if [[ -f "$ENV_FILE.bak" ]]; then
        rm -f "$ENV_FILE.bak"
    fi

    # Restore ethereum-package files if it's a git repository
    if [[ -d "$ETHEREUM_PACKAGE_DIR/.git" ]]; then
        log_info "Restoring ethereum-package git files..."
        cd "$ETHEREUM_PACKAGE_DIR"
        git restore . >/dev/null 2>&1 || true
        cd ..
        log_success "ethereum-package files restored"
    fi
}

# INT/TERM gets converted to a normal exit so the EXIT trap runs once.
# Without the explicit exit on signal, bash unwinds without firing EXIT.
# Two traps both calling _cleanup would have it fire twice on Ctrl-C.
trap 'exit 130' INT TERM
trap _cleanup EXIT

# Deploy L1 smart contracts (devnet only)
deploy_l1_contracts() {
    local mode="$1"
    local broadcast="$2"
    local mock_proof="$3"
    local slow_mode="$4"

    if [[ "$slow_mode" != "true" ]]; then
        slow_mode=false
    fi
    
    if [[ "$mock_proof" == "0" ]]; then
        mock_proof="true"
    else
        mock_proof="false"
    fi
    
    # Check if Surge L1 is already deployed (only skip if both files exist AND we're broadcasting)
    if [[ -f "$L1_DEPLOYMENT_FILE" && -f "$L1_LOCK_FILE" ]]; then

        local _inbox _l1_rpc _inbox_codesize
        _inbox=$(jq -r '.real_time_inbox // empty' "$L1_DEPLOYMENT_FILE" 2>/dev/null)
        _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
        if [[ -n "$_inbox" && "$_inbox" != "0x0000000000000000000000000000000000000000" ]]; then
            _inbox_codesize=$(cast codesize "$_inbox" --rpc-url "$_l1_rpc" 2>/dev/null || echo "")
            if [[ -z "$_inbox_codesize" || "$_inbox_codesize" == "0" ]]; then
                log_warning "Stale deployment lock detected."
                log_warning "  deploy_l1.lock + deploy_l1.json exist, but RealTimeInbox ($_inbox)"
                log_warning "  has NO code on the current L1 ($_l1_rpc) — the chain was wiped/recreated"
                log_warning "  while the lock files survived. Clearing stale artifacts and redeploying."
                rm -f "$DEPLOYMENT_DIR"/*.lock 2>/dev/null || true
                rm -f "$L1_DEPLOYMENT_FILE" "$COMPOSABILITY_MULTICALL_FILE" \
                      "$COMPOSABILITY_USEROPS_SUBMITTER_FILE" 2>/dev/null || true
            fi
        fi
    fi

    # Re-test after the stale-lock guard may have removed the files.
    if [[ -f "$L1_DEPLOYMENT_FILE" && -f "$L1_LOCK_FILE" ]]; then
        log_info "Surge L1 already deployed..."

        local choice
        if [[ "${force:-}" == "true" ]]; then
            log_info "--force set → using existing deployment (run remove-surge-full.sh first to redeploy)"
            choice=0
        else
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "  ⚠️  Start a new deployment?                                   "
            echo "║══════════════════════════════════════════════════════════════║"
            echo "║  0 for Use existing deployment                               ║"
            echo "║  1 for Redeployment                                          ║"
            echo "║ [default: 0]                                                 ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            read -p "Enter choice [0]: " choice
            choice=${choice:-0}
        fi

        if [[ "$choice" == "1" ]]; then
            log_info "Starting a redeployment..."
            if command -v ./remove-surge-full.sh >/dev/null 2>&1; then
                ./remove-surge-full.sh --remove-configs true --remove-l2-stack true --remove-data false --force
            fi
        else
            log_info "Using existing deployment..."
            return 0
        fi
    fi

    log_info "Preparing Surge L1 SCs deployment..."

    log_info "Deploying Surge L1 SCs... BROADCAST: $broadcast SLOW: $slow_mode MOCK_PROVER: $mock_proof"
    
    local exit_status=0
    local temp_output="/tmp/surge_l1_deploy_output_$$"

    source .env
    
    # Deploy L1 contracts based on mode
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=$broadcast VERIFY=false MOCK_PROOF_MODE=$mock_proof SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile l1-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=$broadcast VERIFY=false MOCK_PROOF_MODE=$mock_proof SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile l1-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying L1 smart contracts..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "L1 smart contracts deployed successfully"
        # Only create lock file after successful broadcast deployment
        if [[ "$broadcast" == "true" ]]; then
            local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
            local _inbox _bridge _resolver _signal
            _inbox=$(jq -r '.real_time_inbox // empty' "$L1_DEPLOYMENT_FILE")
            _bridge=$(jq -r '.bridge // empty' "$L1_DEPLOYMENT_FILE")
            _resolver=$(jq -r '.shared_resolver // empty' "$L1_DEPLOYMENT_FILE")
            _signal=$(jq -r '.signal_service // empty' "$L1_DEPLOYMENT_FILE")

            local _verifier_pair
            if [[ "$mock_proof" == "true" ]]; then
                local _dummy
                _dummy=$(jq -r '.proof_verifier_dummy // empty' "$L1_DEPLOYMENT_FILE")
                if [[ -z "$_dummy" || "$_dummy" == "0x0000000000000000000000000000000000000000" ]]; then
                    log_error "Mock mode but proof_verifier_dummy missing/zero in $L1_DEPLOYMENT_FILE"
                    return 1
                fi
                _verifier_pair="ProofVerifierDummy:$_dummy"
            else
                local _verifier
                _verifier=$(jq -r '.surge_verifier // empty' "$L1_DEPLOYMENT_FILE")
                _verifier_pair="SurgeVerifier:$_verifier"
            fi

            if verify_contracts "$_l1_rpc" \
                "RealTimeInbox:$_inbox" \
                "Bridge:$_bridge" \
                "SharedResolver:$_resolver" \
                "SignalService:$_signal" \
                "$_verifier_pair"; then
                touch "$L1_LOCK_FILE"
            else
                log_error "Contract verification failed — not creating lock file"
                return 1
            fi
        fi
        return 0
    else
        log_error "Failed to deploy L1 smart contracts (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
}

deploy_multicall_contract() {
    local mode="$1"
    local slow_mode="$2"
    
    if [[ "$slow_mode" != "true" ]]; then
        slow_mode=false
    fi

    if [[ -f "$L1_DEPLOYMENT_FILE" && -f "$L1_LOCK_FILE" && -f "$COMPOSABILITY_MULTICALL_FILE" ]]; then
        log_info "Multicall contract already deployed..."
        return 0
    fi

    log_info "Deploying Multicall contract..."

    local exit_status=0
    local temp_output="/tmp/multicall_deploy_output_$$"
    
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=true VERIFY=false SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile multicall-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=true VERIFY=false SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile multicall-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying Multicall contract..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "Multicall contract deployed successfully"
        local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
        local _multicall
        _multicall=$(jq -r '.multicall // empty' "$COMPOSABILITY_MULTICALL_FILE")
        if ! is_contract_deployed "$_multicall" "$_l1_rpc" "Multicall"; then
            log_error "Multicall contract verification failed"
            return 1
        fi
        return 0
    else
        log_error "Failed to deploy Multicall contract (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
}

deploy_userops_submitter_contract() {
    local mode="$1"
    local slow_mode="$2"
    
    if [[ "$slow_mode" != "true" ]]; then
        slow_mode=false
    fi

    if [[ -f "$L1_DEPLOYMENT_FILE" && -f "$L1_LOCK_FILE" && -f "$COMPOSABILITY_USEROPS_SUBMITTER_FILE" ]]; then
        log_info "UserOpsSubmitter contract already deployed..."
        return 0
    fi

    log_info "Deploying UserOpsSubmitter contract..."

    local exit_status=0
    local temp_output="/tmp/userops_submitter_deploy_output_$$"
    
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=true VERIFY=false SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile userops-submitter-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=true VERIFY=false SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile userops-submitter-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying UserOpsSubmitter contract..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "UserOpsSubmitter contract deployed successfully"
        local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
        local _factory
        _factory=$(jq -r '.userops_submitter_factory // empty' "$COMPOSABILITY_USEROPS_SUBMITTER_FILE")
        if ! is_contract_deployed "$_factory" "$_l1_rpc" "UserOpsSubmitterFactory"; then
            log_error "UserOpsSubmitter contract verification failed"
            return 1
        fi
        return 0
    else
        log_error "Failed to deploy UserOpsSubmitter contract (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
}


# Deploy DEX L1 contracts (SwapToken + CrossChainSwapVaultL1)
deploy_dex_l1() {
    local mode="$1"

    if [[ -f "$CROSS_CHAIN_DEX_L1_FILE" ]]; then
        log_info "DEX L1 contracts already deployed, skipping..."
        return 0
    fi

    log_info "Deploying DEX L1 contracts..."

    local exit_status=0
    local temp_output="/tmp/dex_l1_deploy_output_$$"

    if [[ "$mode" == "debug" ]]; then
        docker compose -f docker-compose-protocol.yml --profile dex-l1-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        docker compose -f docker-compose-protocol.yml --profile dex-l1-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        show_progress $deploy_pid "Deploying DEX L1 contracts..."
        wait $deploy_pid
        exit_status=$?
    fi

    if [[ $exit_status -eq 0 && -f "$CROSS_CHAIN_DEX_L1_FILE" ]]; then
        local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
        local _l1_vault _l1_token _l1_router _l1_weth
        _l1_vault=$(jq -r '.CrossChainSwapVaultL1 // empty' "$CROSS_CHAIN_DEX_L1_FILE")
        _l1_token=$(jq -r '.SwapToken // empty' "$CROSS_CHAIN_DEX_L1_FILE")
        _l1_router=$(jq -r '.L1Router // empty' "$CROSS_CHAIN_DEX_L1_FILE")
        _l1_weth=$(jq -r '.WETH // empty' "$CROSS_CHAIN_DEX_L1_FILE")

        # Verify core DEX contracts
        if ! verify_contracts "$_l1_rpc" \
                "CrossChainSwapVaultL1:$_l1_vault" \
                "SwapToken:$_l1_token"; then
            log_error "DEX L1 contract verification failed"
            return 1
        fi

        # Verify L1 Router + WETH (present in both test and live modes)
        if [[ -n "$_l1_router" ]] && ! is_contract_deployed "$_l1_router" "$_l1_rpc" "L1Router"; then
            log_error "L1 Router not deployed at $_l1_router"
            return 1
        fi
        if [[ -n "$_l1_weth" ]] && ! is_contract_deployed "$_l1_weth" "$_l1_rpc" "WETH"; then
            log_error "WETH not deployed at $_l1_weth"
            return 1
        fi

        log_success "DEX L1 contracts deployed (vault=$_l1_vault, router=$_l1_router, weth=$_l1_weth)"
        return 0
    else
        log_error "Failed to deploy DEX L1 contracts (exit code: $exit_status)"
        [[ "$mode" == "silence" ]] && log_error "Run with debug mode for more details: --mode debug"
        return 1
    fi
}

# Deploy DEX L2 contracts (SwapTokenL2, SimpleDEX, CrossChainSwapVaultL2)
deploy_dex_l2() {
    local mode="$1"

    if [[ -f "$CROSS_CHAIN_DEX_L2_FILE" ]]; then
        log_info "DEX L2 contracts already deployed, skipping..."
        return 0
    fi

    log_info "Deploying DEX L2 contracts..."

    local exit_status=0
    local temp_output="/tmp/dex_l2_deploy_output_$$"

    if [[ "$mode" == "debug" ]]; then
        docker compose -f docker-compose-protocol.yml --profile dex-l2-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        docker compose -f docker-compose-protocol.yml --profile dex-l2-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        show_progress $deploy_pid "Deploying DEX L2 contracts..."
        wait $deploy_pid
        exit_status=$?
    fi

    if [[ $exit_status -eq 0 && -f "$CROSS_CHAIN_DEX_L2_FILE" ]]; then
        local _l2_rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
        local _l2_vault _l2_dex _l2_token
        _l2_vault=$(jq -r '.CrossChainSwapVaultL2 // empty' "$CROSS_CHAIN_DEX_L2_FILE")
        _l2_dex=$(jq -r '.SimpleDEX // empty' "$CROSS_CHAIN_DEX_L2_FILE")
        _l2_token=$(jq -r '.SwapTokenL2 // empty' "$CROSS_CHAIN_DEX_L2_FILE")
        if ! verify_contracts "$_l2_rpc" \
                "CrossChainSwapVaultL2:$_l2_vault" \
                "SimpleDEX:$_l2_dex" \
                "SwapTokenL2:$_l2_token"; then
            log_error "DEX L2 contract verification failed"
            return 1
        fi
        log_success "DEX L2 contracts deployed"
        return 0
    else
        log_error "Failed to deploy DEX L2 contracts (exit code: $exit_status)"
        [[ "$mode" == "silence" ]] && log_error "Run with debug mode for more details: --mode debug"
        return 1
    fi
}

# Link DEX vaults (L1 ↔ L2) and verify the linkage
link_dex_vaults() {
    if [[ -f "$DEPLOYMENT_DIR/link_vaults_l1.lock" && -f "$DEPLOYMENT_DIR/link_vaults_l2.lock" && -f "$DEPLOYMENT_DIR/cross_chain_dex.lock" ]]; then
        log_info "DEX vaults already linked, skipping..."
        return 0
    fi

    local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
    local _l2_rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
    local _l1_vault _l1_token _l1_router _l1_weth _l2_vault _l2_dex _l2_token
    _l1_vault=$(jq -r '.CrossChainSwapVaultL1' "$CROSS_CHAIN_DEX_L1_FILE")
    _l1_token=$(jq -r '.SwapToken' "$CROSS_CHAIN_DEX_L1_FILE")
    _l1_router=$(jq -r '.L1Router // empty' "$CROSS_CHAIN_DEX_L1_FILE")
    _l1_weth=$(jq -r '.WETH // empty' "$CROSS_CHAIN_DEX_L1_FILE")
    _l2_vault=$(jq -r '.CrossChainSwapVaultL2' "$CROSS_CHAIN_DEX_L2_FILE")
    _l2_dex=$(jq -r '.SimpleDEX' "$CROSS_CHAIN_DEX_L2_FILE")
    _l2_token=$(jq -r '.SwapTokenL2' "$CROSS_CHAIN_DEX_L2_FILE")

    # Link L1 → L2
    if [[ ! -f "$DEPLOYMENT_DIR/link_vaults_l1.lock" ]]; then
        log_info "Setting L2 vault on L1 vault..."
        cast send "$_l1_vault" "setL2Vault(address)" "$_l2_vault" \
            --private-key "$PRIVATE_KEY" \
            --rpc-url "$_l1_rpc" > /dev/null
        touch "$DEPLOYMENT_DIR/link_vaults_l1.lock"
    fi

    # Link L2 → L1
    if [[ ! -f "$DEPLOYMENT_DIR/link_vaults_l2.lock" ]]; then
        log_info "Setting L1 vault on L2 vault..."
        cast send "$_l2_vault" "setL1Vault(address)" "$_l1_vault" \
            --private-key "$PRIVATE_KEY" \
            --rpc-url "$_l2_rpc" > /dev/null
        touch "$DEPLOYMENT_DIR/link_vaults_l2.lock"
    fi

    # Verify linkage
    log_info "Verifying DEX vault linkage..."
    local _errors=0

    local _actual
    _actual=$(cast call "$_l1_vault" "l2Vault()(address)" --rpc-url "$_l1_rpc" 2>/dev/null)
    if [[ "$_actual" != "$_l2_vault" ]]; then
        log_error "L1Vault.l2Vault() = $_actual, expected $_l2_vault"
        _errors=$((_errors + 1))
    fi

    _actual=$(cast call "$_l2_vault" "l1Vault()(address)" --rpc-url "$_l2_rpc" 2>/dev/null)
    if [[ "$_actual" != "$_l1_vault" ]]; then
        log_error "L2Vault.l1Vault() = $_actual, expected $_l1_vault"
        _errors=$((_errors + 1))
    fi

    _actual=$(cast call "$_l2_token" "minter()(address)" --rpc-url "$_l2_rpc" 2>/dev/null)
    if [[ "$_actual" != "$_l2_vault" ]]; then
        log_error "SwapTokenL2.minter() = $_actual, expected $_l2_vault"
        _errors=$((_errors + 1))
    fi

    _actual=$(cast call "$_l2_dex" "liquidityProvider()(address)" --rpc-url "$_l2_rpc" 2>/dev/null)
    if [[ "$_actual" != "$_l2_vault" ]]; then
        log_error "SimpleDEX.liquidityProvider() = $_actual, expected $_l2_vault"
        _errors=$((_errors + 1))
    fi

    # Verify L1 Vault's L1 DEX wiring (router + weth).
    # Use `tr` for lowercase conversion so this works on macOS bash 3.2 too.
    if [[ -n "$_l1_router" ]]; then
        _actual=$(cast call "$_l1_vault" "l1Router()(address)" --rpc-url "$_l1_rpc" 2>/dev/null)
        if [[ "$(echo "$_actual" | tr '[:upper:]' '[:lower:]')" != "$(echo "$_l1_router" | tr '[:upper:]' '[:lower:]')" ]]; then
            log_error "L1Vault.l1Router() = $_actual, expected $_l1_router"
            _errors=$((_errors + 1))
        fi
    fi
    if [[ -n "$_l1_weth" ]]; then
        _actual=$(cast call "$_l1_vault" "weth()(address)" --rpc-url "$_l1_rpc" 2>/dev/null)
        if [[ "$(echo "$_actual" | tr '[:upper:]' '[:lower:]')" != "$(echo "$_l1_weth" | tr '[:upper:]' '[:lower:]')" ]]; then
            log_error "L1Vault.weth() = $_actual, expected $_l1_weth"
            _errors=$((_errors + 1))
        fi
    fi

    # Verify L1 Vault inventory is seeded (required for L2→L1→L2 token→ETH swaps)
    local _vault_token_bal _vault_eth_bal
    _vault_token_bal=$(cast call "$_l1_token" "balanceOf(address)(uint256)" "$_l1_vault" --rpc-url "$_l1_rpc" 2>/dev/null | awk '{print $1}')
    _vault_eth_bal=$(cast balance "$_l1_vault" --rpc-url "$_l1_rpc" 2>/dev/null)
    if [[ "${L1_VAULT_SEED_TOKEN:-0}" != "0" && "${_vault_token_bal:-0}" == "0" ]]; then
        log_error "L1 Vault token inventory = 0 (expected >= $L1_VAULT_SEED_TOKEN)"
        _errors=$((_errors + 1))
    fi
    if [[ "${L1_VAULT_SEED_ETH:-0}" != "0" && "${_vault_eth_bal:-0}" == "0" ]]; then
        log_error "L1 Vault ETH inventory = 0 (expected >= $L1_VAULT_SEED_ETH)"
        _errors=$((_errors + 1))
    fi

    if [[ $_errors -gt 0 ]]; then
        log_error "DEX vault verification failed ($_errors errors)"
        return 1
    fi

    touch "$DEPLOYMENT_DIR/cross_chain_dex.lock"
    log_success "DEX vaults linked and verified (vault token=$_vault_token_bal, vault ETH=$_vault_eth_bal)"
    return 0
}

# Register L1 Bridge and Signal Service on L2 Shared Resolver (for cross-chain DEX).
# Uses L2 pre-deployed resolver (L2_SHARED_RESOLVER), NOT the L1 REALTIME_SHARED_RESOLVER.
setup_dex_resolver() {
    if [[ -f "$DEPLOYMENT_DIR/setup_l2.lock" ]]; then
        log_info "L2 resolver already configured, skipping..."
        return 0
    fi

    local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
    local _l2_rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
    local _l2_resolver="${L2_SHARED_RESOLVER:-0x7633740000000000000000000000000000000006}"
    local _l1_chain_id
    _l1_chain_id=$(cast chain-id --rpc-url "$_l1_rpc")

    # Wait for L2 to be ready before sending transactions
    log_info "Waiting for L2 RPC to accept transactions..."
    local _retries=0
    while ! cast chain-id --rpc-url "$_l2_rpc" > /dev/null 2>&1; do
        _retries=$((_retries + 1))
        if [[ $_retries -gt 30 ]]; then
            log_error "L2 RPC not ready after 30 attempts"
            return 1
        fi
        sleep 2
    done

    log_info "Registering L1 Bridge on L2 resolver ($_l2_resolver)..."
    if ! cast send "$_l2_resolver" \
        "registerAddress(uint256,bytes32,address)" \
        "$_l1_chain_id" \
        "$(cast format-bytes32-string "bridge")" \
        "$REALTIME_BRIDGE" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$_l2_rpc" > /dev/null 2>&1; then
        log_error "Failed to register bridge on L2 resolver"
        return 1
    fi

    log_info "Registering L1 Signal Service on L2 resolver ($_l2_resolver)..."
    if ! cast send "$_l2_resolver" \
        "registerAddress(uint256,bytes32,address)" \
        "$_l1_chain_id" \
        "$(cast format-bytes32-string "signal_service")" \
        "$REALTIME_SIGNAL_SERVICE" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$_l2_rpc" > /dev/null 2>&1; then
        log_error "Failed to register signal_service on L2 resolver"
        return 1
    fi

    # Verify registrations via the public resolve() function
    log_info "Verifying resolver registrations..."
    local _errors=0

    local _actual
    _actual=$(cast call "$_l2_resolver" \
        "resolve(uint256,bytes32,bool)(address)" \
        "$_l1_chain_id" \
        "$(cast format-bytes32-string "bridge")" \
        true \
        --rpc-url "$_l2_rpc" 2>/dev/null)
    if [[ "$_actual" != "$REALTIME_BRIDGE" ]]; then
        log_error "Resolver bridge = $_actual, expected $REALTIME_BRIDGE"
        _errors=$((_errors + 1))
    fi

    _actual=$(cast call "$_l2_resolver" \
        "resolve(uint256,bytes32,bool)(address)" \
        "$_l1_chain_id" \
        "$(cast format-bytes32-string "signal_service")" \
        true \
        --rpc-url "$_l2_rpc" 2>/dev/null)
    if [[ "$_actual" != "$REALTIME_SIGNAL_SERVICE" ]]; then
        log_error "Resolver signal_service = $_actual, expected $REALTIME_SIGNAL_SERVICE"
        _errors=$((_errors + 1))
    fi

    if [[ $_errors -gt 0 ]]; then
        log_error "Resolver verification failed ($_errors errors)"
        return 1
    fi

    touch "$DEPLOYMENT_DIR/setup_l2.lock"
    log_success "L2 resolver configured and verified"
    return 0
}

# Extract L1 deployment results from JSON file
extract_l1_deployment_results() {
    log_info "Extracting Surge L1 SCs deployment results..."

    if [[ ! -f "$L1_DEPLOYMENT_FILE" ]]; then
        log_error "L1 deployment file not found: $L1_DEPLOYMENT_FILE"
        return 1
    fi

    # Extract L1 deployment results from deploy_l1.json
    export REALTIME_BRIDGE; REALTIME_BRIDGE=$(_jq_required "$L1_DEPLOYMENT_FILE" '.bridge' "REALTIME_BRIDGE") || return 1
    export REALTIME_EMPTY_IMPL; REALTIME_EMPTY_IMPL=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.empty_impl')
    export REALTIME_ERC1155_VAULT; REALTIME_ERC1155_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc1155_vault')
    export REALTIME_ERC20_VAULT; REALTIME_ERC20_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc20_vault')
    export REALTIME_ERC721_VAULT; REALTIME_ERC721_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc721_vault')
    export REALTIME_SHARED_RESOLVER; REALTIME_SHARED_RESOLVER=$(_jq_required "$L1_DEPLOYMENT_FILE" '.shared_resolver' "REALTIME_SHARED_RESOLVER") || return 1
    export REALTIME_SIGNAL_SERVICE; REALTIME_SIGNAL_SERVICE=$(_jq_required "$L1_DEPLOYMENT_FILE" '.signal_service' "REALTIME_SIGNAL_SERVICE") || return 1
    export REALTIME_SURGE_VERIFIER
    REALTIME_SURGE_VERIFIER=$(jq -r '.surge_verifier // "0x0000000000000000000000000000000000000000"' "$L1_DEPLOYMENT_FILE")
    export REALTIME_INBOX; REALTIME_INBOX=$(_jq_required "$L1_DEPLOYMENT_FILE" '.real_time_inbox' "REALTIME_INBOX") || return 1
    export REALTIME_PROOF_VERIFIER_DUMMY; REALTIME_PROOF_VERIFIER_DUMMY=$(jq -r '.proof_verifier_dummy // empty' "$L1_DEPLOYMENT_FILE")

    echo
    echo ">>>>>>"
    echo " REALTIME_INBOX: $REALTIME_INBOX "
    echo " REALTIME_BRIDGE: $REALTIME_BRIDGE "
    echo " REALTIME_SIGNAL_SERVICE: $REALTIME_SIGNAL_SERVICE "
    echo ">>>>>>"

    log_info "Updating .env with extracted values..."

    update_env_var "$ENV_FILE" "REALTIME_BRIDGE" "$REALTIME_BRIDGE"
    update_env_var "$ENV_FILE" "REALTIME_EMPTY_IMPL" "$REALTIME_EMPTY_IMPL"
    update_env_var "$ENV_FILE" "REALTIME_ERC1155_VAULT" "$REALTIME_ERC1155_VAULT"
    update_env_var "$ENV_FILE" "REALTIME_ERC20_VAULT" "$REALTIME_ERC20_VAULT"
    update_env_var "$ENV_FILE" "REALTIME_ERC721_VAULT" "$REALTIME_ERC721_VAULT"
    update_env_var "$ENV_FILE" "REALTIME_SIGNAL_SERVICE" "$REALTIME_SIGNAL_SERVICE"
    update_env_var "$ENV_FILE" "REALTIME_PROOF_VERIFIER_DUMMY" "$REALTIME_PROOF_VERIFIER_DUMMY"
    update_env_var "$ENV_FILE" "REALTIME_SHARED_RESOLVER" "$REALTIME_SHARED_RESOLVER"
    update_env_var "$ENV_FILE" "REALTIME_INBOX" "$REALTIME_INBOX"
    update_env_var "$ENV_FILE" "REALTIME_SURGE_VERIFIER" "$REALTIME_SURGE_VERIFIER"

    # POC
    if [[ -f "$COMPOSABILITY_MULTICALL_FILE" ]]; then
        export MULTICALL_ADDRESS; MULTICALL_ADDRESS=$(cat "$COMPOSABILITY_MULTICALL_FILE" | jq -r '.multicall')
        update_env_var "$ENV_FILE" "MULTICALL_ADDRESS" "$MULTICALL_ADDRESS"
    fi
    if [[ -f "$COMPOSABILITY_USEROPS_SUBMITTER_FILE" ]]; then
        export USEROPS_SUBMITTER_FACTORY_ADDRESS; USEROPS_SUBMITTER_FACTORY_ADDRESS=$(cat "$COMPOSABILITY_USEROPS_SUBMITTER_FILE" | jq -r '.userops_submitter_factory')
        update_env_var "$ENV_FILE" "USEROPS_SUBMITTER_FACTORY_ADDRESS" "$USEROPS_SUBMITTER_FACTORY_ADDRESS"
    fi

    # Derive GENESIS_L1_HEIGHT from the block where RealTimeInbox was activated (activation block + 1).
    # `cast logs --from-block 0` is fine on a fresh Kurtosis devnet (handful of
    # blocks) but expensive/likely rejected on Sepolia/mainnet for an
    # --deploy-devnet false flow. Skip if already set in this run, or if the
    # value already lives in .env from a previous run.
    # TODO(#18): when the L1 deployer Forge script can persist the activation
    # block into deploy_l1.json, switch to reading it directly and drop the
    # cast logs call entirely.
    local _existing_genesis_height
    _existing_genesis_height="${GENESIS_L1_HEIGHT:-}"
    if [[ -z "$_existing_genesis_height" || "$_existing_genesis_height" == "0" ]]; then
        _existing_genesis_height=$(grep -E '^GENESIS_L1_HEIGHT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2-)
    fi

    if [[ -n "$_existing_genesis_height" && "$_existing_genesis_height" != "0" ]]; then
        log_info "GENESIS_L1_HEIGHT already set ($_existing_genesis_height) — skipping cast logs lookup"
        export GENESIS_L1_HEIGHT="$_existing_genesis_height"
    elif [[ -f "$L1_DEPLOYMENT_FILE" && -f "$L1_LOCK_FILE" ]]; then
        local l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
        local activation_block
        activation_block=$(cast logs --from-block 0 --to-block latest \
            --address "$REALTIME_INBOX" \
            "Activated(bytes32)" \
            --rpc-url "$l1_rpc" \
            --json 2>/dev/null | jq -r '.[0].blockNumber // empty')
        if [[ -n "$activation_block" && "$activation_block" != "null" ]]; then
            export GENESIS_L1_HEIGHT; GENESIS_L1_HEIGHT=$(( $(cast --to-dec "$activation_block") + 1 ))
            update_env_var "$ENV_FILE" "GENESIS_L1_HEIGHT" "$GENESIS_L1_HEIGHT"
            log_info "GENESIS_L1_HEIGHT set to $GENESIS_L1_HEIGHT (activation block $activation_block + 1)"
        else
            log_warning "Activated(bytes32) event not found on RealTimeInbox — GENESIS_L1_HEIGHT not updated"
        fi
    fi

    export REALTIME_ZISK_VERIFIER; REALTIME_ZISK_VERIFIER=$(jq -r '.zisk_verifier // empty' "$L1_DEPLOYMENT_FILE")
    if [[ -z "$REALTIME_ZISK_VERIFIER" ]]; then
        REALTIME_ZISK_VERIFIER="$REALTIME_PROOF_VERIFIER_DUMMY"
    fi
    update_env_var "$ENV_FILE" "REALTIME_ZISK_VERIFIER" "$REALTIME_ZISK_VERIFIER"

    export REALTIME_ZISK_PLONK_VERIFIER; REALTIME_ZISK_PLONK_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.zisk_plonk_verifier')
    update_env_var "$ENV_FILE" "REALTIME_ZISK_PLONK_VERIFIER" "$REALTIME_ZISK_PLONK_VERIFIER"

    if [[ -f "$CROSS_CHAIN_DEX_L1_FILE" ]]; then
        export L1_VAULT; L1_VAULT=$(jq -r '.CrossChainSwapVaultL1' "$CROSS_CHAIN_DEX_L1_FILE")
        update_env_var "$ENV_FILE" "L1_VAULT" "$L1_VAULT"
        export L1_TOKEN; L1_TOKEN=$(jq -r '.SwapToken' "$CROSS_CHAIN_DEX_L1_FILE")
        update_env_var "$ENV_FILE" "L1_TOKEN" "$L1_TOKEN"
        export L1_ROUTER; L1_ROUTER=$(jq -r '.L1Router // empty' "$CROSS_CHAIN_DEX_L1_FILE")
        [[ -n "$L1_ROUTER" ]] && update_env_var "$ENV_FILE" "L1_ROUTER" "$L1_ROUTER"
        export L1_WETH; L1_WETH=$(jq -r '.WETH // empty' "$CROSS_CHAIN_DEX_L1_FILE")
        [[ -n "$L1_WETH" ]] && update_env_var "$ENV_FILE" "L1_WETH" "$L1_WETH"
    fi

    if [[ -f "$CROSS_CHAIN_DEX_L2_FILE" ]]; then
        export L2_TOKEN; L2_TOKEN=$(jq -r '.SwapTokenL2' "$CROSS_CHAIN_DEX_L2_FILE")
        update_env_var "$ENV_FILE" "L2_TOKEN" "$L2_TOKEN"
        export L2_DEX; L2_DEX=$(jq -r '.SimpleDEX' "$CROSS_CHAIN_DEX_L2_FILE")
        update_env_var "$ENV_FILE" "L2_DEX" "$L2_DEX"
        export L2_VAULT; L2_VAULT=$(jq -r '.CrossChainSwapVaultL2' "$CROSS_CHAIN_DEX_L2_FILE")
        update_env_var "$ENV_FILE" "L2_VAULT" "$L2_VAULT"
    fi

    log_success "L1 deployment results extracted and updated in .env"
}

# Generate L2 Genesis
generate_l2_genesis() {
    local mode="$1"
       
    # Check if Surge genesis is already generated
    if [[ -f "$SURGE_GENESIS_FILE" ]]; then
        log_info "Surge genesis already generated..."
        return 0
    fi

    log_info "Generating Surge genesis..."

    # Extract signal service from L1 deployment results needed for genesis generation
    export REALTIME_SIGNAL_SERVICE; REALTIME_SIGNAL_SERVICE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.signal_service')
    update_env_var "$ENV_FILE" "REALTIME_SIGNAL_SERVICE" "$REALTIME_SIGNAL_SERVICE"
    
    local exit_status=0
    local temp_output="/tmp/surge_genesis_output_$$"
    
    if [[ "$mode" == "debug" ]]; then
        docker compose -f docker-compose-protocol.yml --profile genesis-generator up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        docker compose -f docker-compose-protocol.yml --profile genesis-generator up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Generating Surge genesis..."
        
        wait $deploy_pid
        exit_status=$?
    fi

    # Calculate timestamp: current time + 60 seconds
    NEW_TIMESTAMP=$(($(date +%s) + 60))

    update_env_var "$ENV_FILE" "REALTIME_TIMESTAMP_SEC" "$NEW_TIMESTAMP"

    HEX_TIMESTAMP=$(printf "0x%X" "$NEW_TIMESTAMP")

    log_info "HEX_TIMESTAMP: $HEX_TIMESTAMP"

    update_env_var "$ENV_FILE" "REALTIME_TIMESTAMP" "$HEX_TIMESTAMP"

    local gen2spec_url="${SURGE_GEN2SPEC_URL:-https://raw.githubusercontent.com/NethermindEth/core-scripts/refs/heads/surge-poc/gen2spec/gen2spec.jq}"
    local gen2spec_file
    gen2spec_file=$(mktemp /tmp/gen2spec.XXXXXX) || {
        log_error "mktemp failed to create a tempfile for gen2spec.jq"
        return 1
    }

    log_info "Fetching gen2spec.jq from: $gen2spec_url"
    local curl_err
    curl_err=$(curl -sSf --max-time 30 "$gen2spec_url" -o "$gen2spec_file" 2>&1)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch gen2spec.jq from: $gen2spec_url"
        log_error "curl: ${curl_err:-(no error output)}"
        log_error "Set SURGE_GEN2SPEC_URL to override the URL, or check network connectivity"
        rm -f "$gen2spec_file"
        return 1
    fi

    if [[ ! -s "$gen2spec_file" ]]; then
        log_error "gen2spec.jq downloaded but is empty — check the URL or network connectivity"
        rm -f "$gen2spec_file"
        return 1
    fi

    cat "$SURGE_GENESIS_FILE" \
        | jq --arg hex_timestamp "$HEX_TIMESTAMP" \
            '. * {difficulty: 0, config: {taiko: true, londonBlock: 0, ontakeBlock: 0, pacayaBlock: 1, shastaTimestamp: $hex_timestamp, feeCollector: "0x0000000000000000000000000000000000000000", shanghaiTime: 0}} | del(.config.clique)' \
        | jq --from-file "$gen2spec_file" \
        | jq --arg hex_timestamp "$HEX_TIMESTAMP" '.engine.Taiko.shastaTimestamp = $hex_timestamp' \
        | jq '.engine.Taiko.rip7728TransitionTimestamp = "0x0"' \
        | jq '.engine.Taiko.l1StaticCallTransitionTimestamp = "0x0"' \
        > "$DEPLOYMENT_DIR/surge_chainspec.json"

    rm -f "$gen2spec_file"
    
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Surge chainspec generation completed successfully          "
    echo "╚══════════════════════════════════════════════════════════════╝"

    log_info "Fetching genesis hash..."
    # Clean up any leftover container from a previous run
    docker rm -f nethermind-genesis-hash 2>/dev/null || true
    # Get genesis hash first by running Nethermind with the chainspec
    docker run -d --name nethermind-genesis-hash -v ./deployment/surge_chainspec.json:/chainspec.json "${NETHERMIND_CLIENT_IMAGE:-nethermindeth/nethermind:master}" --config=none --Init.ChainSpecPath=/chainspec.json --Surge.L1EthApiEndpoint="${L1_ENDPOINT_HTTP:-http://localhost:32003}"
    
    log_info "Waiting for Nethermind to output genesis hash (up to 60s)..."
    local waited=0
    while ! docker logs nethermind-genesis-hash 2>&1 | grep -q "Genesis hash"; do
        if (( waited >= 60 )); then
            log_error "Timed out waiting for genesis hash after ${waited}s"
            docker logs nethermind-genesis-hash 2>&1 | tail -20
            docker stop nethermind-genesis-hash 2>/dev/null || true
            docker rm nethermind-genesis-hash 2>/dev/null || true
            return 1
        fi
        sleep 2
        (( waited += 2 ))
    done
    log_info "Genesis hash found after ${waited}s"

    # Same as the wait loop above — banner goes to stderr, so combine streams.
    local genesis_hash
    genesis_hash=$(docker logs nethermind-genesis-hash 2>&1 \
        | grep "Genesis hash" \
        | head -n 1 \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | sed 's/.*Genesis hash : *\(0x[0-9a-fA-F]*\).*/\1/' \
        | tr -d '\r\n ')

    if [[ -z "$genesis_hash" ]]; then
        log_error "Failed to extract genesis hash from Nethermind logs"
        docker logs nethermind-genesis-hash 2>&1 | tail -20
        docker stop nethermind-genesis-hash 2>/dev/null || true
        docker rm nethermind-genesis-hash 2>/dev/null || true
        return 1
    fi

    update_env_var "$ENV_FILE" "L2_GENESIS_HASH" "$genesis_hash"

    log_info "Genesis hash: $genesis_hash"

    docker stop nethermind-genesis-hash 2>/dev/null || true
    docker rm nethermind-genesis-hash 2>/dev/null || true

    if [[ $exit_status -eq 0 ]]; then
        log_success "Surge genesis generated successfully"
        return 0
    else
        log_error "Failed to generate Surge genesis (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Generation output saved in: $temp_output"
        fi
        return 1
    fi
}

# Deploy and configure provers (devnet only)
deploy_provers() {
    local mock_proof="$1"
    local should_run_provers
    
    if [[ "$mock_proof" == "0" ]]; then
        generate_prover_chain_spec
        log_info "Skipping provers deployment...using mock prover"
        return 0
    fi

    if [[ -n "${running_provers:-}" ]]; then
        should_run_provers=$running_provers
    elif [[ "$force" == "true" ]]; then
        should_run_provers=0
        log_info "Deploying provers (--force, default 0)"
    else
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "  ⚠️  Running provers?                                          "
        echo "║══════════════════════════════════════════════════════════════║"
        echo "║  0 for Deploy provers                                        ║"
        echo "║  1 for Skip provers                                          ║"
        echo "║ [default: 0]                                                 ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        read -p "Enter choice [0]: " should_run_provers
        should_run_provers=${should_run_provers:-0}
    fi

    if [[ "$should_run_provers" == "0" || "$should_run_provers" == "true" ]]; then
        generate_prover_chain_spec

        if [[ "$mock_proof" == "1" ]]; then
            if [[ ! -f "$DEPLOYMENT_DIR/zisk_setup.lock" ]]; then
                local running_zisk
                if [[ "$force" == "true" ]]; then
                    running_zisk=0
                    log_info "Deploying ZISK (--force, default 0)"
                else
                    echo
                    echo "╔══════════════════════════════════════════════════════════════╗"
                    echo "  ⚠️  Running ZISK?                                             "
                    echo "║══════════════════════════════════════════════════════════════║"
                    echo "║  0 for Deploy ZISK                                           ║"
                    echo "║  1 for Skip ZISK                                             ║"
                    echo "║ [default: 0]                                                 ║"
                    echo "╚══════════════════════════════════════════════════════════════╝"
                    echo
                    read -p "Enter choice [0]: " running_zisk
                    running_zisk=${running_zisk:-0}
                fi

                if [[ "$running_zisk" == "0" ]]; then
                    retrieve_guest_data
                    
                    if [[ -z "${ZISK_BATCH_VKEY:-}" ]]; then
                        log_error "ZISK guest data is missing"
                        return 1
                    fi

                    BROADCAST=true docker compose -f docker-compose-protocol.yml --profile zisk-setup up
                    local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
                    local _trusted
                    _trusted=$(cast call "${REALTIME_ZISK_VERIFIER}" \
                        "isProgramTrusted(bytes32)(bool)" "${ZISK_BATCH_VKEY}" \
                        --rpc-url "$_l1_rpc" 2>/dev/null)
                    if [[ "$_trusted" == "true" ]]; then
                        touch "$DEPLOYMENT_DIR/zisk_setup.lock"
                        log_success "Zisk VKEY trusted successfully"
                    else
                        log_error "ZiskVerifier: isProgramTrusted returned false for VKEY $ZISK_BATCH_VKEY — not creating zisk_setup.lock"
                        return 1
                    fi
                fi
            fi
        fi
    fi
}

# Verify Raiko is reachable and ready to serve proof requests.
#
# Two flavours of checks based on prover mode:
#   - Mock prover (is_mock=true): only `GET /health` — `surge-raiko-mock` returns
#     `{}` for /guest_data (no real ZisK setup) and rejects the realtime probe
#     payload, so the deeper checks would loop forever. Mock proofs are
#     instant; nothing else needs warmup.
#   - Real prover (is_mock=false): full three-stage check:
#       1. GET /health     — server is up
#       2. GET /guest_data — vkey is computed (loads guest binary; ~4-5 min cold)
#       3. POST /v3/proof/batch/realtime with sources=[] — proof endpoint alive
#          (Raiko treats sources=[] as a status poll; no actual proof generation)
#
# The real-prover check does NOT fully warm the ZisK proofman pipeline. The
# first real proof request from Catalyst will still trigger proofman init
# (~16 min on a single GPU). Multi-GPU setups overlap proofman init with the
# checks above, so by the time L2 starts producing blocks the prover is hot.
#
# Usage: wait_for_raiko_ready <raiko_url> <is_mock:true|false> [timeout_seconds]
wait_for_raiko_ready() {
    local raiko_url="$1"
    local is_mock="${2:-false}"
    local timeout_seconds="${3:-1800}"  # 30 min default — first cold start can take ~16 min on 1x L40
    # Real-prover liveness budget. If /health doesn't respond fast, Raiko isn't
    # actually running on the prover VM (port closed, container down, configs not
    # synced + restarted). No point waiting the full warmup window — fail in
    # ~90 seconds with an actionable hint instead of 30 minutes of silence.
    local health_timeout_seconds=90
    local start_time
    start_time=$(date +%s)
    local poll_interval=10

    if [[ -z "$raiko_url" ]]; then
        log_error "wait_for_raiko_ready: raiko_url is empty (RAIKO_HOST_ZKVM not set)"
        return 1
    fi

    local total_steps=3
    if [[ "$is_mock" == "true" ]]; then
        total_steps=1
        log_info "Verifying mock Raiko at $raiko_url is reachable (mock prover, single liveness check only)..."
    else
        log_info "Verifying real Raiko at $raiko_url is ready (3 checks, may take 4-5 min on cold start)..."
    fi

    # ── Check 1/N: /health ──
    # Mock prover keeps the full timeout (Raiko comes up alongside the L2 stack
    # so a slow Docker pull can legitimately push it past 60s). Real prover uses
    # the shorter health budget — Raiko should already be up on the prover VM.
    local _step1_budget=$timeout_seconds
    if [[ "$is_mock" != "true" ]]; then
        _step1_budget=$health_timeout_seconds
    fi
    log_info " [1/$total_steps] Polling $raiko_url/health (basic liveness, ${_step1_budget}s budget)..."
    while true; do
        local now elapsed
        now=$(date +%s); elapsed=$(( now - start_time ))
        if [[ $elapsed -ge $_step1_budget ]]; then
            log_error "Raiko /health did not respond within $_step1_budget seconds"
            if [[ "$is_mock" != "true" ]]; then
                log_error "Real prover failure-mode checklist:"
                log_error "  • Is the Raiko container running on the prover VM?"
                log_error "      docker compose -f docker/docker-compose-zk.yml ps"
                log_error "  • Is TCP/8080 open on the prover VM and reachable from this host?"
                log_error "      curl -m 5 $raiko_url/guest_data"
                log_error "  • Did you scp simple-surge-node/configs/{chain_spec_list,config}.json"
                log_error "    to the prover VM and run 'docker compose ... up -d --force-recreate'?"
            fi
            return 1
        fi
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$raiko_url/health" 2>/dev/null || echo "000")
        if [[ "$code" == "200" ]]; then
            log_success "  [1/$total_steps] Raiko /health → 200"
            break
        fi
        sleep "$poll_interval"
    done

    # Mock prover: skip the rest. /guest_data and the realtime probe both
    # require real ZisK state that the mock image doesn't have.
    if [[ "$is_mock" == "true" ]]; then
        local elapsed_total=$(( $(date +%s) - start_time ))
        log_success "Mock Raiko is ready (${elapsed_total}s)"
        return 0
    fi

    # ── Check 2/3: /guest_data ──
    # Distinguishes three real-prover failure modes:
    #   1. Empty body / connection error  → Raiko not serving (already covered above)
    #   2. Body present but no zisk.batch_vkey  → Raiko started against the default
    #      chain spec and never picked up the one simple-surge-node generated.
    #      User skipped step 6 (scp configs + force-recreate raiko-zk).
    #   3. Body present with vkey → ready.
    log_info " [2/3] Polling $raiko_url/guest_data (this takes 4-5 min on first cold start)..."
    local _saw_empty_guest_data=0
    while true; do
        local now elapsed
        now=$(date +%s); elapsed=$(( now - start_time ))
        if [[ $elapsed -ge $timeout_seconds ]]; then
            log_error "Raiko /guest_data did not return vkey within $timeout_seconds seconds"
            if [[ "$_saw_empty_guest_data" == "1" ]]; then
                log_error "Raiko answered /guest_data but never returned a zisk.batch_vkey."
                log_error "Most common cause: the Raiko on the prover VM is still running"
                log_error "against the default chain spec. Sync configs and restart:"
                log_error "  scp configs/{chain_spec_list,config}.json <prover-host>:~/raiko/host/config/devnet/"
                log_error "  ssh <prover-host> 'cd ~/raiko && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate'"
            fi
            return 1
        fi
        local body
        body=$(curl -s --max-time 30 "$raiko_url/guest_data" 2>/dev/null || echo "")
        if [[ -n "$body" ]] && echo "$body" | jq -e '.zisk.batch_vkey' >/dev/null 2>&1; then
            local vkey
            vkey=$(echo "$body" | jq -r '.zisk.batch_vkey')
            log_success "  [2/3] Raiko /guest_data ready (zisk.batch_vkey=$vkey)"
            break
        fi
        # Track whether we ever saw a non-empty body so the timeout error can
        # distinguish "Raiko unreachable" from "Raiko up but on wrong chain spec".
        if [[ -n "$body" ]]; then
            _saw_empty_guest_data=1
        fi
        sleep "$poll_interval"
    done

    # ── Check 3/3: POST /v3/proof/batch/realtime with sources=[] (status poll) ──
    # Raiko treats sources=[] as a status query — no proof generation kicks off.
    # We just want to confirm the proof endpoint's request handler responds.
    log_info " [3/3] Probing $raiko_url/v3/proof/batch/realtime (status-poll mode)..."
    local probe_payload='{"l2_block_numbers":[1],"max_anchor_block_number":1,"basefee_sharing_pctg":75,"last_finalized_block_hash":"0x0000000000000000000000000000000000000000000000000000000000000000","sources":[],"blobs":[],"signal_slots":[],"proof_type":"zisk","blob_proof_type":"proof_of_equivalence"}'
    while true; do
        local now elapsed
        now=$(date +%s); elapsed=$(( now - start_time ))
        if [[ $elapsed -ge $timeout_seconds ]]; then
            log_error "Raiko proof endpoint did not respond within $timeout_seconds seconds"
            return 1
        fi
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 \
            -X POST -H "Content-Type: application/json" \
            -d "$probe_payload" \
            "$raiko_url/v3/proof/batch/realtime" 2>/dev/null || echo "000")
        # 2xx = success, 4xx = endpoint up but rejected our probe (expected for status-poll on a non-existent request key)
        if [[ "$code" =~ ^[24][0-9][0-9]$ ]]; then
            log_success "  [3/3] Raiko proof endpoint responding (HTTP $code)"
            break
        fi
        sleep "$poll_interval"
    done

    local elapsed_total=$(( $(date +%s) - start_time ))
    log_success "Raiko is ready (warmed up in ${elapsed_total}s)"
    return 0
}

# verify_prover_chain_spec_match <mock_proof>
#
# Confirms that the prover's loaded chain_spec_list.json matches the one
# simple-surge-node just generated in configs/. Without this, raiko's
# /health and /guest_data probes pass even when raiko is still on a stale
# chain spec (default-shipped or previous deploy) — its vkey is a property
# of the guest binary, not the L1 addresses, so /guest_data returns SOMETHING
# regardless of config drift. The downstream symptom is silent: catalyst
# sends proof requests against the new RealTimeInbox, raiko proves against
# the old one, L1 submissions revert / drop, L2 stuck → DEX vault linkage
# times out 30+ minutes later with no useful error.
#
# Cases handled:
#   - mock_proof=0          → simple-surge-node's own raiko service mounts
#                              the same configs/ directory; trivially in sync.
#   - host.docker.internal  → same-VM real prover; compare two local files.
#   - remote host           → two-VM real prover; SSH in, sha256sum, compare.
#   - SSH unreachable       → warn and proceed (today's lenient default).
#   - hash mismatch / file missing → exit 1 with exact recovery commands.
#
# Reads PROVER_SSH_USER, PROVER_SSH_KEY, PROVER_RAIKO_DIR from env (.env).
verify_prover_chain_spec_match() {
    local mock_proof="$1"

    if [[ "$mock_proof" == "0" ]]; then
        log_info "Mock prover — chain spec verification skipped (raiko mounts simple-surge-node/configs/ directly)"
        return 0
    fi

    local local_spec="${CONFIGS_DIR:-configs}/chain_spec_list.json"
    if [[ ! -f "$local_spec" ]]; then
        log_warning "$local_spec not found — can't verify prover chain spec match. Proceeding."
        return 0
    fi

    local local_hash
    local_hash=$(sha256sum "$local_spec" | awk '{print $1}')

    # Derive prover host from RAIKO_HOST_ZKVM (e.g. http://185.216.20.7:8080 → 185.216.20.7).
    local raiko_host
    raiko_host=$(echo "${RAIKO_HOST_ZKVM:-}" | sed -E 's|^https?://||; s|:.*||; s|/.*||')

    if [[ -z "$raiko_host" ]]; then
        log_warning "RAIKO_HOST_ZKVM not set — skipping prover chain spec verification"
        return 0
    fi

    # Same-VM real prover: raiko's submodule path is local.
    if [[ "$raiko_host" == "host.docker.internal" || "$raiko_host" == "localhost" || "$raiko_host" == "127.0.0.1" ]]; then
        local local_remote_spec="./raiko/host/config/devnet/chain_spec_list.json"
        if [[ ! -f "$local_remote_spec" ]]; then
            log_error "Same-VM real prover: chain spec missing at $local_remote_spec"
            log_error "Sync configs and force-recreate raiko-zk:"
            log_error "  mkdir -p \$(dirname $local_remote_spec)"
            log_error "  cp $local_spec $local_remote_spec"
            log_error "  cp ${CONFIGS_DIR:-configs}/config.json ./raiko/host/config/devnet/config.json"
            log_error "  cd raiko && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk"
            return 1
        fi
        local remote_hash
        remote_hash=$(sha256sum "$local_remote_spec" | awk '{print $1}')
        if [[ "$local_hash" != "$remote_hash" ]]; then
            log_error "Chain spec mismatch (same-VM):"
            log_error "  local : $local_hash  ($local_spec)"
            log_error "  raiko : $remote_hash  ($local_remote_spec)"
            log_error "Fix:"
            log_error "  cp $local_spec $local_remote_spec"
            log_error "  cp ${CONFIGS_DIR:-configs}/config.json ./raiko/host/config/devnet/config.json"
            log_error "  cd raiko && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk"
            return 1
        fi
        log_success "Chain spec matches (same-VM): $local_hash"
        return 0
    fi

    # Two-VM real prover: SSH to the prover, sha256sum its chain spec.
    local ssh_user="${PROVER_SSH_USER:-ubuntu}"
    local ssh_key="${PROVER_SSH_KEY:-}"
    local raiko_dir_raw="${PROVER_RAIKO_DIR:-\$HOME/simple-surge-node/raiko}"
    local ssh_target="${ssh_user}@${raiko_host}"
    local ssh_opts=(-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
    [[ -n "$ssh_key" ]] && ssh_opts+=(-i "$ssh_key")

    # Remote-side script: expand $HOME inside the prover's shell, sha256sum the file, exit cleanly.
    # Sent via stdin (bash -s) so the $HOME-expansion happens server-side.
    log_info "Verifying prover chain spec via ssh ${ssh_target} ..."
    local remote_out
    if ! remote_out=$(ssh "${ssh_opts[@]}" "$ssh_target" \
            "RAIKO_DIR=\"$raiko_dir_raw\" bash -s" <<'REMOTE' 2>&1
        set -eu
        eval "RAIKO_DIR=\"$RAIKO_DIR\""
        SPEC="$RAIKO_DIR/host/config/devnet/chain_spec_list.json"
        if [[ ! -f "$SPEC" ]]; then
            echo "MISSING:$SPEC"
            exit 0
        fi
        printf 'HASH:'
        sha256sum "$SPEC" | awk '{print $1}'
REMOTE
        ); then
        log_warning "SSH to prover (${ssh_target}) failed — can't verify chain spec match. Proceeding."
        log_warning "  → if you DO have SSH, verify manually:"
        log_warning "     ssh ${ssh_target} 'sha256sum ${raiko_dir_raw}/host/config/devnet/chain_spec_list.json'"
        log_warning "     expected (local): $local_hash"
        return 0
    fi

    if [[ "$remote_out" == MISSING:* ]]; then
        local missing_path="${remote_out#MISSING:}"
        log_error "Prover chain spec missing at $missing_path"
        log_error "scp configs + force-recreate raiko-zk on the prover:"
        log_error "  scp $local_spec ${ssh_target}:${raiko_dir_raw}/host/config/devnet/chain_spec_list.json"
        log_error "  scp ${CONFIGS_DIR:-configs}/config.json ${ssh_target}:${raiko_dir_raw}/host/config/devnet/config.json"
        log_error "  ssh ${ssh_target} 'cd ${raiko_dir_raw} && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk'"
        return 1
    fi

    local remote_hash
    remote_hash=$(echo "$remote_out" | grep -E '^HASH:[a-f0-9]{64}$' | head -n1 | cut -d: -f2)
    if [[ -z "$remote_hash" ]]; then
        log_warning "Couldn't parse remote sha256 from prover. Raw output:"
        echo "$remote_out" | sed 's/^/    /' >&2
        log_warning "Proceeding without verification."
        return 0
    fi

    if [[ "$local_hash" != "$remote_hash" ]]; then
        log_error "Chain spec mismatch (two-VM):"
        log_error "  local  ($local_spec):           $local_hash"
        log_error "  prover (${ssh_target}:.../devnet/chain_spec_list.json): $remote_hash"
        log_error "Sync from this host:"
        log_error "  scp $local_spec ${ssh_target}:${raiko_dir_raw}/host/config/devnet/chain_spec_list.json"
        log_error "  scp ${CONFIGS_DIR:-configs}/config.json ${ssh_target}:${raiko_dir_raw}/host/config/devnet/config.json"
        log_error "Then force-recreate raiko-zk on the prover:"
        log_error "  ssh ${ssh_target} 'cd ${raiko_dir_raw} && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk'"
        log_error "Cold start: ~16 min single-GPU, much faster multi-GPU. Re-run deploy-surge-full.sh after."
        return 1
    fi

    log_success "Chain spec matches (two-VM ${ssh_target}): $local_hash"
    return 0
}

start_l2_stack() {
    local stack_option="$1"
    local mock_proof="${2:-1}"

    local compose_cmd="docker compose"
    local exit_status=0
    local temp_output="/tmp/surge_l2_stack_output_$$"

    if [[ "$stack_option" == "0" ]]; then
        local _l2_rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
        log_info "Stack option 0: skipping L2 stack startup (dev mode)"
        log_info "Verifying external L2 RPC at $_l2_rpc..."
        if ! test_rpc_connection "$_l2_rpc"; then
            log_error "External L2 RPC at $_l2_rpc is not responding to eth_blockNumber"
            log_error "Start your own L2 node and retry, or pick a different --stack-option"
            return 1
        fi
        local _l2_chain_id
        if _l2_chain_id=$(get_chain_id "$_l2_rpc") && [[ -n "${L2_CHAIN_ID:-}" ]]; then
            if [[ "$_l2_chain_id" != "$L2_CHAIN_ID" ]]; then
                log_error "External L2 chain ID mismatch: got $_l2_chain_id, .env L2_CHAIN_ID=$L2_CHAIN_ID"
                return 1
            fi
        fi
        log_success "External L2 RPC healthy (chain_id=$_l2_chain_id) — skipping stack startup"
        return 0
    fi

    log_info "Starting L2 stack..."

    local prover_profiles=""
    local mock_mode=""
    if [[ "$mock_proof" == "0" ]]; then
        log_info "Mock proof selected — including Raiko prover"
        prover_profiles="--profile prover"
        mock_mode=true
    else
        log_info "Proceed with real Zisk prover, please make sure prover endpoint is accessible"
        mock_mode=false
    fi

    update_env_var "$ENV_FILE" "MOCK_MODE" "$mock_mode"

    mkdir -p ./driver-data
    chmod -R 777 ./driver-data 2>/dev/null || true

    case "$stack_option" in
        1)
            log_info "Starting driver only"
            MOCK_MODE=$mock_mode $compose_cmd --profile driver --profile blockscout $prover_profiles up -d >"$temp_output" 2>&1 &
            ;;
        2)
            log_info "Starting driver + catalyst"
            MOCK_MODE=$mock_mode $compose_cmd --profile catalyst --profile blockscout $prover_profiles up -d >"$temp_output" 2>&1 &
            ;;
        3)
            log_info "Starting driver + catalyst + spammer"
            MOCK_MODE=$mock_mode $compose_cmd --profile catalyst --profile spammer --profile blockscout $prover_profiles up -d >"$temp_output" 2>&1 &
            ;;
        *)
            log_error "Unknown stack option: $stack_option (expected 0/1/2/3)"
            return 1
            ;;
    esac
    
    local docker_pid=$!
    show_progress $docker_pid "Starting L2 stack components..."
    
    wait $docker_pid
    exit_status=$?
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "L2 stack started successfully"
        if [[ "$stack_option" == "3" ]]; then
            log_info "Waiting for L2 to produce blocks..."
            sleep 60
            log_info "L2 at block $(cast block-number --rpc-url "${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}")"
        fi
        return 0
    else
        log_error "Failed to start L2 stack (exit code: $exit_status)"
        if [[ -f "$temp_output" ]]; then
            log_error "Docker output saved in: $temp_output"
        fi
        return 1
    fi
}

main() {
    # Show help if requested
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
    fi

    # Parse arguments
    parse_arguments "$@"
    
    log_info "Starting $SCRIPT_NAME..."

    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit 1
    fi

    # Initialize submodules
    initialize_submodules
    
    # Step 1: Environment Selection
    local env_choice
    if [[ -z "${environment:-}" ]]; then
        env_choice=$(prompt_environment_selection)
    else
        case "$environment" in
            1|"devnet") env_choice=1 ;;
            *)
                log_error "Invalid --environment: '$environment' (only 'devnet' preset ships today)"
                log_error "Note: --environment sets the .env preset, not the target L1 chain."
                log_error "To deploy against an existing L1 (Sepolia/Gnosis/mainnet/etc.) use --deploy-devnet false."
                exit 1
                ;;
        esac
    fi

    # Map env_choice to name
    local env_name
    case "$env_choice" in
        1|"devnet") env_name="devnet" ;;
        *) log_error "Invalid environment choice: $env_choice"; exit 1 ;;
    esac

    # Load environment file
    if ! check_env_file $env_name; then
        log_error "Failed to load environment file, please ensure the .env file is present"
        exit 1
    fi

    if [[ "${privacy_mode:-}" == "true" ]]; then
        if [[ "${SURGE_PRIVACY_MODE:-false}" != "true" ]]; then
            log_info "--privacy-mode: enabling SURGE_PRIVACY_MODE in .env"
            update_env_var "$ENV_FILE" SURGE_PRIVACY_MODE true
        fi
        export SURGE_PRIVACY_MODE=true
    fi

    # Get deployment choice (local/remote)
    local deployment_choice
    if [[ -z "${deployment:-}" ]]; then
        deployment_choice=$(prompt_deployment_selection)
    else
        case "$deployment" in
            0|"local") deployment_choice=0 ;;
            1|"remote") deployment_choice=1 ;;
            *) log_error "Invalid deployment: $deployment"; exit 1 ;;
        esac
    fi
    
    # Configure environment URLs (base configuration)
    local machine_ip=""
    if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
        machine_ip=$(get_machine_ip)
        if [[ -z "$machine_ip" ]]; then
            log_error "Could not determine machine IP address"
            exit 1
        fi
        # Export machine IP for later use
        export MACHINE_IP="$machine_ip"
    fi
    
    if ! configure_environment_urls "$env_choice" "$deployment_choice" "$machine_ip"; then
        log_error "Failed to configure environment URLs"
        exit 1
    fi
    
    # Step 2: L1 Infrastructure Decision
    local deploy_devnet_choice
    local slow_mode
    if [[ "$env_choice" == "1" || "$env_choice" == "devnet" ]]; then
        # Devnet: prompt for deploy devnet or use existing
        if [[ -z "${deploy_devnet:-}" ]]; then
            deploy_devnet_choice=$(prompt_l1_deployment_mode)
        else
            case "$deploy_devnet" in
                true|"true"|"0"|0) deploy_devnet_choice=0 ;;
                false|"false"|"1"|1) deploy_devnet_choice=1 ;;
                *) log_error "Invalid deploy-devnet: $deploy_devnet"; exit 1 ;;
            esac
        fi
        
        if [[ "$deploy_devnet_choice" == "0" ]]; then
            # Option A: Deploy new L1 devnet
            local mode_choice
            if [[ -z "${mode:-}" ]]; then
                mode_choice=$(prompt_mode_selection)
            else
                case "$mode" in
                    0|"silence"|"silent") mode_choice="silence" ;;
                    1|"debug") mode_choice="debug" ;;
                    *) mode_choice="$mode" ;;
                esac
            fi
            
            if ! deploy_l1_devnet "$deployment_choice" "$mode_choice"; then
                log_error "Failed to deploy L1 devnet"
                exit 1
            fi

            slow_mode=false

            # Verify L1 RPC endpoints
            if [[ -n "${L1_ENDPOINT_HTTP_EXTERNAL:-}" ]]; then
                if ! check_l1_health "$L1_ENDPOINT_HTTP_EXTERNAL" "${L1_BEACON_HTTP_EXTERNAL:-}"; then
                    log_warning "L1 health check failed, please retry..."
                    exit 1
                fi
            fi
        else
            # Option B: Use existing chain
            local mode_choice
            if [[ -z "${mode:-}" ]]; then
                mode_choice=$(prompt_mode_selection)
            else
                case "$mode" in
                    0|"silence"|"silent") mode_choice="silence" ;;
                    1|"debug") mode_choice="debug" ;;
                    *) mode_choice="$mode" ;;
                esac
            fi

            slow_mode=false

            # Verify L1 RPC endpoints (use external endpoint for health check from host)
            if [[ -n "${L1_ENDPOINT_HTTP:-}" ]]; then
                # For existing chain, endpoints should already be set in .env
                # Create external versions if not already done
                if [[ -z "${L1_ENDPOINT_HTTP_EXTERNAL:-}" ]]; then
                    export L1_ENDPOINT_HTTP_EXTERNAL="$L1_ENDPOINT_HTTP"
                    export L1_BEACON_HTTP_EXTERNAL="${L1_BEACON_HTTP:-}"
                fi
                
                if ! check_l1_health "$L1_ENDPOINT_HTTP_EXTERNAL" "${L1_BEACON_HTTP_EXTERNAL:-}"; then
                    log_warning "L1 health check failed, please retry..."
                    exit 1
                fi
            fi

            if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                local machine_ip
                machine_ip=$(get_machine_ip)
                
                if [[ -z "$machine_ip" ]]; then
                    log_error "Could not determine machine IP address"
                    return 1
                fi
                
                configure_remote_blockscout "$machine_ip"
            else
                configure_remote_blockscout "localhost"
            fi

            # log_warning "Using existing chain is still a work in progress"
            # exit 0
        fi
    fi
    
    # Step 3: L1 Protocol Deployment (ONLY for devnet)
    local mock_proof="1"  # default: real prover (no raiko)
    if [[ "$env_choice" == "1" || "$env_choice" == "devnet" ]]; then

        if [[ "$mock_prover" == "true" || "${MOCK_PROOF_MODE:-}" == "true" ]]; then
            mock_proof="0"
            log_info "Using mock prover (--mock-prover or MOCK_PROOF_MODE=true)"
        elif [[ -n "$mock_prover" ]]; then
            mock_proof="1"
            log_info "Using real prover (--mock-prover=$mock_prover)"
        elif [[ "$force" == "true" ]]; then
            mock_proof="1"
            log_info "Using real prover (--force without --mock-prover defaults to real)"
        else
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "  ⚠️  Using mock prover?                                        "
            echo "║══════════════════════════════════════════════════════════════║"
            echo "║  0 for Using mock prover                                     ║"
            echo "║  1 for Using real prover                                     ║"
            echo "║ [default: 0]                                                 ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo
            read -p "Enter choice [0]: " mock_proof
            mock_proof=${mock_proof:-0}
        fi
        
        # Run L1 contracts simulation
        if ! deploy_l1_contracts "$mode_choice" false $mock_proof false; then
            log_error "Failed to deploy L1 smart contracts"
            exit 1
        fi

        # Extract L1 deployment results
        if ! extract_l1_deployment_results; then
            log_error "Failed to extract L1 deployment results"
            exit 1
        fi

        # Generate L2 Genesis
        if ! generate_l2_genesis "$mode_choice"; then
            log_error "Failed to generate L2 genesis"
            exit 1
        fi

        # Deploy L1 contracts
        if ! deploy_l1_contracts "$mode_choice" true $mock_proof $slow_mode; then
            log_error "Failed to deploy L1 smart contracts"
            exit 1
        fi

        # Deploy Provers (optional)
        if ! deploy_provers $mock_proof; then
            log_warning "Prover deployment had issues, but continuing..."
        fi

        # Deploy Multicall contract
        if ! deploy_multicall_contract "$mode_choice" $slow_mode; then
            log_error "Failed to deploy Multicall smart contracts"
            exit 1
        fi

        # Deploy UserOpsSubmitter contract
        if ! deploy_userops_submitter_contract "$mode_choice" $slow_mode; then
            log_error "Failed to deploy UserOpsSubmitter smart contracts"
            exit 1
        fi

        # Extract L1 deployment results
        if ! extract_l1_deployment_results; then
            log_error "Failed to extract L1 deployment results"
            exit 1
        fi
    fi

    if ! generate_privacy_bundle; then
        log_error "Failed to generate privacy bundle"
        exit 1
    fi

    # Step 4: L2 Stack Deployment (ALL environments)
    local stack_choice
    if [[ -z "${stack_option:-}" ]]; then
        stack_choice=$(prompt_stack_option_selection)
    else
        stack_choice=$stack_option
    fi

    if ! start_l2_stack "$stack_choice" "$mock_proof"; then
        log_error "Failed to start L2 stack"
        exit 1
    fi

    if [[ "$stack_choice" != "0" ]]; then
        if ! verify_prover_chain_spec_match "$mock_proof"; then
            log_error "Chain spec verification failed — aborting before Raiko readiness check"
            log_error "(See the scp + force-recreate commands above. Re-run this script after.)"
            exit 1
        fi

        local raiko_check_url=""
        local is_mock_raiko="false"
        if [[ "$mock_proof" == "0" ]]; then
            raiko_check_url="http://localhost:8082"
            is_mock_raiko="true"
        elif [[ -n "${RAIKO_HOST_ZKVM:-}" ]]; then
            raiko_check_url=$(echo "$RAIKO_HOST_ZKVM" | sed 's|host\.docker\.internal|localhost|g')
        fi

        if [[ -z "$raiko_check_url" ]]; then
            log_warning "RAIKO_HOST_ZKVM not set — skipping Raiko readiness check"
            log_warning "Catalyst's first proof request may time out if Raiko isn't warm yet"
        else
            if ! wait_for_raiko_ready "$raiko_check_url" "$is_mock_raiko"; then
                log_error "Raiko is not ready — aborting before any DEX/L2 transactions hit Catalyst"
                if [[ "$mock_proof" == "0" ]]; then
                    log_error "Mock prover diagnostics: docker compose logs -f l2-raiko-zk-client"
                else
                    log_error "Real prover (two-VM): on the prover VM, verify"
                    log_error "  cd ~/raiko && docker compose -f docker/docker-compose-zk.yml ps"
                    log_error "  curl -m 5 localhost:8080/guest_data    # must return zisk.batch_vkey"
                    log_error "If Raiko is up but the vkey is missing/wrong, sync configs and restart:"
                    log_error "  scp configs/{chain_spec_list,config}.json <prover-host>:~/raiko/host/config/devnet/"
                    log_error "  ssh <prover-host> 'cd ~/raiko && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate'"
                fi
                exit 1
            fi
        fi
    fi

    if [[ ! -f "$L1_DEPLOYMENT_FILE" ]]; then
        log_error "DEX setup requires $L1_DEPLOYMENT_FILE but it's missing."
        log_error "Likely cause: --deploy-devnet false against an L1 that wasn't"
        log_error "deployed by simple-surge-node. The DEX deployers expect the"
        log_error "L1 contract addresses produced by deploy_l1_contracts."
        log_error "Either run with --deploy-devnet true (fresh L1) or pre-populate"
        log_error "$L1_DEPLOYMENT_FILE with the existing L1's contract addresses."
        exit 1
    fi

    # If SWAP_TOKEN is unset, the L1 deployer will deploy a fresh SwapToken.
    # On existing chains, set SWAP_TOKEN in .env to use a real USDC/ERC20.
    if ! deploy_dex_l1 "$mode_choice"; then
        log_error "Failed to deploy DEX L1 contracts"
        exit 1
    fi

    if ! deploy_dex_l2 "$mode_choice"; then
        log_error "Failed to deploy DEX L2 contracts"
        exit 1
    fi

    if ! link_dex_vaults; then
        log_error "Failed to link DEX vaults"
        exit 1
    fi

    if ! setup_dex_resolver; then
        log_error "Failed to configure L2 resolver for DEX"
        exit 1
    fi

    # Extract L1 deployment results
    if ! extract_l1_deployment_results; then
        log_error "Failed to extract L1 deployment results"
        exit 1
    fi

    # Start DEX UI
    prepare_dex_ui_configs
    log_info "Starting DEX UI..."
    local dex_ui_output="/tmp/surge_dex_ui_output_$$"
    if ! docker compose -f docker-compose.yml --profile dex up -d --build >"$dex_ui_output" 2>&1; then
        log_warning "Failed to start DEX UI"
        log_warning "Build/start output saved in: $dex_ui_output"
        log_warning "Tail of output:"
        tail -n 20 "$dex_ui_output" 2>/dev/null | sed 's/^/    /' || true
    else
        log_success "DEX UI started successfully"
        rm -f "$dex_ui_output"
    fi
    
    # Step 6: Verification
    verify_rpc_endpoints
    
    # Step 7: Display Summary
    display_deployment_summary
    
    log_success "Surge Full Stack deployment complete!"
}

# Run main function
main "$@"

