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
readonly NETHERMIND_LAUNCHER_FILE="$ETHEREUM_PACKAGE_DIR/src/el/nethermind/nethermind_launcher.star"
readonly NETHERMIND_LAUNCHER_CONFIG_FILE="$CONFIGS_DIR/nethermind_launcher.star"

# L2 Deployment
readonly ENV_FILE=".env"
readonly L1_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/deploy_l1.json"
readonly L1_LOCK_FILE="$DEPLOYMENT_DIR/deploy_l1.lock"
readonly SURGE_GENESIS_FILE="$DEPLOYMENT_DIR/surge_genesis.json"
readonly L2_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/setup_l2.json"
readonly SURGE_PROTOCOL_IMAGE="nethermind/surge-protocol:sha-91d3867"
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
mode=""
force=""
# verify_key_only=""


# Show usage help
show_help() {
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo
    echo "Description:"
    echo "  Deploy complete Surge stack with L1 (optional devnet) and L2 components"
    echo
    echo "Options:"
    echo "  --environment ENV        Surge environment (devnet) [REQUIRED]"
    echo "  --deploy-devnet BOOL     Deploy new devnet or use existing chain (devnet only, true|false)"
    echo "  --deployment TYPE        Deployment type (local|remote)"
    echo "  --deployment-key KEY     Private key for contract deployment (will be verified)"
    echo "  --stack-option NUM       L2 stack option (1-6, see details below)"
    echo "  --running-provers BOOL   Setup provers (devnet only, true|false)"
    echo "  --mode MODE              Execution mode (silence|debug)"
    # echo "  --verify-key-only        Only verify private key, don't deploy"
    echo "  -f, --force              Skip confirmation prompts"
    echo "  -h, --help               Show this help message"
    echo
    echo "Stack Options:"
    echo "  1 - Driver only"
    echo "  2 - Driver + Catalyst"
    echo "  3 - Driver + Catalyst + Spammer"
    echo
    echo "Execution Modes:"
    echo "  silence - Silent mode with progress indicators (default)"
    echo "  debug   - Debug mode with full output"
    echo
    echo "Examples:"
    echo "  $0 --environment devnet --deploy-devnet true --mode debug"
    echo "  $0 --environment devnet --deploy-devnet true --stack-option 2"
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
            --mode)
                mode="$2"
                shift 2
                ;;
            # --verify-key-only)
            #     verify_key_only="true"
            #     shift
            #     ;;
            -f|--force)
                force="true"
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


# Validate environment for devnet deployment
validate_environment_for_devnet() {
    log_info "Validating environment for devnet deployment..."
    
    # Check if enclave already exists
    if kurtosis enclave ls 2>/dev/null | grep -q "$ENCLAVE_NAME"; then
        log_warning "Enclave '$ENCLAVE_NAME' already exists"
        
        if [[ "$force" != "true" ]]; then
            read -p "Remove existing enclave? (yes/no) [yes]: " remove_choice
            remove_choice=${remove_choice:-no}
            if [[ "$remove_choice" == "yes" || "$remove_choice" == "y" ]]; then
                log_info "Removing existing enclave..."
                kurtosis enclave rm "$ENCLAVE_NAME" --force >/dev/null 2>&1 || true
            fi
        else
            log_info "Removing existing enclave..."
            kurtosis enclave rm "$ENCLAVE_NAME" --force >/dev/null 2>&1 || true
        fi
    fi
    
    # Check for Kurtosis
    if ! command -v kurtosis >/dev/null 2>&1; then
        log_error "Kurtosis is not installed or not in PATH"
        log_error "Please install Kurtosis: https://docs.kurtosis.com/install"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
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
    
    # Validate environment
    if ! validate_environment_for_devnet; then
        log_error "Environment validation failed"
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
    # configure_nethermind_launcher

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

trap '_cleanup; exit 130' INT TERM
trap '_cleanup' EXIT

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
        log_info "Surge L1 already deployed..."
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
            local _inbox _bridge _resolver _signal _verifier
            _inbox=$(jq -r '.real_time_inbox // empty' "$L1_DEPLOYMENT_FILE")
            _bridge=$(jq -r '.bridge // empty' "$L1_DEPLOYMENT_FILE")
            _resolver=$(jq -r '.shared_resolver // empty' "$L1_DEPLOYMENT_FILE")
            _signal=$(jq -r '.signal_service // empty' "$L1_DEPLOYMENT_FILE")
            _verifier=$(jq -r '.surge_verifier // empty' "$L1_DEPLOYMENT_FILE")
            if verify_contracts "$_l1_rpc" \
                "RealTimeInbox:$_inbox" \
                "Bridge:$_bridge" \
                "SharedResolver:$_resolver" \
                "SignalService:$_signal" \
                "SurgeVerifier:$_verifier"; then
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


# Deploy TestToken ERC20 on a single chain (L1 or L2)
# Usage: deploy_test_token <mode> <chain> [initial_mint_wei]
#   chain: "l1" or "l2"
deploy_test_token() {
    local mode="$1"
    local chain="$2"
    local initial_mint="${3:-}"

    local profile result_file rpc_var
    case "$chain" in
        l1)
            profile="test-token-l1-deployer"
            result_file="$DEPLOYMENT_DIR/test-token-l1.json"
            ;;
        l2)
            profile="test-token-l2-deployer"
            result_file="$DEPLOYMENT_DIR/test-token-l2.json"
            ;;
        *)
            log_error "deploy_test_token: unknown chain '$chain' (use 'l1' or 'l2')"
            return 1
            ;;
    esac

    if [[ -f "$result_file" ]]; then
        log_info "TestToken already deployed on $chain ($result_file exists), skipping..."
        return 0
    fi

    log_info "Deploying TestToken on $chain..."

    local exit_status=0
    local temp_output="/tmp/surge_test_token_${chain}_deploy_output_$$"

    local mint_env=""
    if [[ -n "$initial_mint" ]]; then
        mint_env="INITIAL_MINT=$initial_mint"
    fi

    if [[ "$mode" == "debug" ]]; then
        env ${mint_env:+"$mint_env"} docker compose -f docker-compose-protocol.yml --profile "$profile" up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        env ${mint_env:+"$mint_env"} docker compose -f docker-compose-protocol.yml --profile "$profile" up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        show_progress $deploy_pid "Deploying TestToken on $chain..."
        wait $deploy_pid
        exit_status=$?
    fi

    if [[ $exit_status -eq 0 ]]; then
        log_success "TestToken deployed on $chain successfully"
        local _token_address
        _token_address=$(jq -r '.test_token // empty' "$result_file" 2>/dev/null)
        local _rpc
        case "$chain" in
            l1) _rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}" ;;
            l2) _rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}" ;;
        esac
        if ! is_contract_deployed "$_token_address" "$_rpc" "TestToken($chain)"; then
            log_error "TestToken verification failed on $chain"
            return 1
        fi
        return 0
    else
        log_error "Failed to deploy TestToken on $chain (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
}

# Deploy Cross-Chain DEX contracts on L1 and L2
deploy_cross_chain_dex() {
    local mode="$1"

    if [[ -f "$CROSS_CHAIN_DEX_L1_FILE" && -f "$CROSS_CHAIN_DEX_L2_FILE" && -f "$DEPLOYMENT_DIR/cross_chain_dex.lock" && -f "$DEPLOYMENT_DIR/link_vaults_l1.lock" && -f "$DEPLOYMENT_DIR/link_vaults_l2.lock" && -f "$DEPLOYMENT_DIR/setup_l2.lock" ]]; then
        log_info "CrossChainDex contracts already deployed..."
        return 0
    fi

    log_info "Deploying CrossChainDex contracts..."

    local exit_status=0
    local temp_output="/tmp/cross_chain_dex_deploy_output_$$"

    if [[ "$mode" == "debug" ]]; then
        docker compose -f docker-compose-protocol.yml --profile cross-chain-dex-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        docker compose -f docker-compose-protocol.yml --profile cross-chain-dex-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        show_progress $deploy_pid "Deploying CrossChainDex contracts..."
        wait $deploy_pid
        exit_status=$?
    fi

    if [[ $exit_status -eq 0 ]]; then
        log_success "CrossChainDex contracts deployed successfully"
        local _l1_rpc="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
        local _l2_rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
        local _l1_vault _l2_vault _l2_dex
        _l1_vault=$(jq -r '.CrossChainSwapVaultL1 // empty' "$CROSS_CHAIN_DEX_L1_FILE" 2>/dev/null)
        _l2_vault=$(jq -r '.CrossChainSwapVaultL2 // empty' "$CROSS_CHAIN_DEX_L2_FILE" 2>/dev/null)
        _l2_dex=$(jq -r '.SimpleDEX // empty' "$CROSS_CHAIN_DEX_L2_FILE" 2>/dev/null)
        local _dex_ok=true
        [[ -n "$_l1_vault" ]] && ! is_contract_deployed "$_l1_vault" "$_l1_rpc" "L1Vault" && _dex_ok=false
        [[ -n "$_l2_vault" ]] && ! is_contract_deployed "$_l2_vault" "$_l2_rpc" "L2Vault" && _dex_ok=false
        [[ -n "$_l2_dex"   ]] && ! is_contract_deployed "$_l2_dex"   "$_l2_rpc" "SimpleDEX" && _dex_ok=false
        if [[ "$_dex_ok" == false ]]; then
            log_error "DEX contract verification failed"
            return 1
        fi
        return 0
    else
        log_error "Failed to deploy CrossChainDex contracts (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
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
    export REALTIME_SURGE_VERIFIER; REALTIME_SURGE_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.surge_verifier')
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

    # Derive GENESIS_L1_HEIGHT from the block where RealTimeInbox was activated (activation block + 1)
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

    export REALTIME_ZISK_VERIFIER; REALTIME_ZISK_VERIFIER=$(jq -r '.zisk_verifier // empty' "$L1_DEPLOYMENT_FILE")
    if [[ -z "$REALTIME_ZISK_VERIFIER" ]]; then
        REALTIME_ZISK_VERIFIER="$REALTIME_PROOF_VERIFIER_DUMMY"
    fi
    update_env_var "$ENV_FILE" "REALTIME_ZISK_VERIFIER" "$REALTIME_ZISK_VERIFIER"

    export REALTIME_ZISK_PLONK_VERIFIER; REALTIME_ZISK_PLONK_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.zisk_plonk_verifier')
    update_env_var "$ENV_FILE" "REALTIME_ZISK_PLONK_VERIFIER" "$REALTIME_ZISK_PLONK_VERIFIER"

    if [[ -f "$DEPLOYMENT_DIR/deployment_relay.lock" ]]; then
        export CROSS_CHAIN_RELAY; CROSS_CHAIN_RELAY=$(cat "$DEPLOYMENT_DIR/deployment_relay.json" | jq -r '.cross_chain_relay')
        update_env_var "$ENV_FILE" "CROSS_CHAIN_RELAY" "$CROSS_CHAIN_RELAY"
    fi

    if [[ -f "$CROSS_CHAIN_DEX_L1_FILE" ]]; then
        export L1_VAULT; L1_VAULT=$(jq -r '.CrossChainSwapVaultL1' "$CROSS_CHAIN_DEX_L1_FILE")
        update_env_var "$ENV_FILE" "L1_VAULT" "$L1_VAULT"
        export L1_TOKEN; L1_TOKEN=$(jq -r '.SwapToken' "$CROSS_CHAIN_DEX_L1_FILE")
        update_env_var "$ENV_FILE" "L1_TOKEN" "$L1_TOKEN"
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
    gen2spec_file=$(mktemp /tmp/gen2spec.XXXXXX.jq)

    log_info "Fetching gen2spec.jq from: $gen2spec_url"
    if ! curl -sf --max-time 30 "$gen2spec_url" -o "$gen2spec_file" 2>/dev/null; then
        log_error "Failed to fetch gen2spec.jq from: $gen2spec_url"
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
    docker run -d --name nethermind-genesis-hash -v ./deployment/surge_chainspec.json:/chainspec.json nethermindeth/nethermind:taiko-shasta-changes --config=none --Init.ChainSpecPath=/chainspec.json
    
    log_info "Waiting for Nethermind to output genesis hash (up to 60s)..."
    local waited=0
    while ! docker logs nethermind-genesis-hash 2>/dev/null | grep -q "Genesis hash"; do
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

    local genesis_hash
    genesis_hash=$(docker logs nethermind-genesis-hash 2>/dev/null \
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

    if [[ -z "${running_provers:-}" ]]; then
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
    else
        should_run_provers=$running_provers
    fi

    if [[ "$should_run_provers" == "0" || "$should_run_provers" == "true" ]]; then
        generate_prover_chain_spec

        if [[ "$mock_proof" == "1" ]]; then
            if [[ ! -f "$DEPLOYMENT_DIR/zisk_setup.lock" ]]; then
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

# Start L2 stack with specified configuration
# Usage: start_l2_stack <stack_option> [mock_proof]
#   mock_proof: "0" = mock prover selected → also start raiko; "1" = real prover (default)
start_l2_stack() {
    local stack_option="$1"
    local mock_proof="${2:-1}"

    log_info "Starting L2 stack..."

    local compose_cmd="docker compose"
    local exit_status=0
    local temp_output="/tmp/surge_l2_stack_output_$$"

    # Include raiko + redis-zk when mock proof mode is selected
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

    mkdir -p ./driver-data
    chmod -R 777 ./driver-data

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
            *) log_error "Invalid environment: $environment (only 'devnet' is supported)"; exit 1 ;;
        esac
    fi

    # Map env_choice to name
    local env_name
    case "$env_choice" in
        1|"devnet") env_name="devnet" ;;
        *) log_error "Invalid environment choice: $env_choice (only 'devnet' is supported)"; exit 1 ;;
    esac

    # Load environment file
    if ! check_env_file $env_name; then
        log_error "Failed to load environment file, please ensure the .env file is present"
        exit 1
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

        # Deploy L1 contracts

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

    # Deploy TestToken ERC20 on L1 (optional, skipped if already done)
    if [[ -f "$DEPLOYMENT_DIR/test-token-l1.json" ]]; then
        log_info "TestToken already deployed on L1, skipping..."
    else
        local token_l1_choice
        if [[ -z "${test_token_l1_option:-}" ]]; then
            echo >&2
            echo "╔══════════════════════════════════════════════════════════════╗" >&2
            echo "║ Do you want to deploy TestToken ERC20 on L1?                 ║" >&2
            echo "║ 0 for Yes                                                    ║" >&2
            echo "║ 1 for No                                                     ║" >&2
            echo "╚══════════════════════════════════════════════════════════════╝" >&2
            echo >&2
            read -p "Enter choice [0]: " token_l1_choice
            token_l1_choice=${token_l1_choice:-0}
        else
            token_l1_choice=$test_token_l1_option
        fi

        if [[ "$token_l1_choice" == "0" ]]; then
            if ! deploy_test_token "$mode_choice" "l1"; then
                log_warning "TestToken deployment on L1 failed, continuing..."
            fi
        else
            log_info "Skipping TestToken deployment on L1"
        fi
    fi

    # Deploy TestToken ERC20 on L2 (optional, skipped if already done)
    if [[ -f "$DEPLOYMENT_DIR/test-token-l2.json" ]]; then
        log_info "TestToken already deployed on L2, skipping..."
    else
        local token_l2_choice
        if [[ -z "${test_token_l2_option:-}" ]]; then
            echo >&2
            echo "╔══════════════════════════════════════════════════════════════╗" >&2
            echo "║ Do you want to deploy TestToken ERC20 on L2?                 ║" >&2
            echo "║ 0 for Yes                                                    ║" >&2
            echo "║ 1 for No                                                     ║" >&2
            echo "╚══════════════════════════════════════════════════════════════╝" >&2
            echo >&2
            read -p "Enter choice [0]: " token_l2_choice
            token_l2_choice=${token_l2_choice:-0}
        else
            token_l2_choice=$test_token_l2_option
        fi

        if [[ "$token_l2_choice" == "0" ]]; then
            if ! deploy_test_token "$mode_choice" "l2"; then
                log_warning "TestToken deployment on L2 failed, continuing..."
            fi
        else
            log_info "Skipping TestToken deployment on L2"
        fi
    fi

    # Deploy Cross Chain Dex Contracts on L1 and L2
    if ! deploy_cross_chain_dex "$mode_choice"; then
        log_error "Failed to deploy Cross Chain Dex Contracts on L1 and L2"
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
    if ! docker compose -f docker-compose.yml --profile dex up -d --build >/dev/null 2>&1; then
        log_warning "Failed to start DEX UI"
    else
        log_success "DEX UI started successfully"
    fi
    
    # Step 6: Verification
    verify_rpc_endpoints
    
    # Step 7: Display Summary
    display_deployment_summary
    
    log_success "Surge Full Stack deployment complete!"
}

# Run main function
main "$@"

