#!/bin/bash
set -euo pipefail

# Directories
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEPLOYMENT_DIR="deployment"
readonly ETHEREUM_PACKAGE_DIR="ethereum-package"
readonly CONFIGS_DIR="configs"

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
readonly PACAYA_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/deploy_l1_pacaya.json"
readonly L1_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/deploy_l1.json"
readonly L1_LOCK_FILE="$DEPLOYMENT_DIR/deploy_l1.lock"
readonly SURGE_GENESIS_FILE="$DEPLOYMENT_DIR/surge_genesis.json"
readonly ACCEPT_OWNERSHIP_FILE="$DEPLOYMENT_DIR/accept_ownership.json"
readonly ACCEPT_OWNERSHIP_LOCK_FILE="$DEPLOYMENT_DIR/accept_ownership.lock"
readonly L2_LOCK_FILE="$DEPLOYMENT_DIR/setup_l2.lock"
readonly SURGE_PROTOCOL_IMAGE="nethermind/surge-protocol:sha-91d3867"


# Default values for command line arguments
environment=""
deploy_devnet=""
deployment=""
l1_rpc_url=""
l1_beacon_rpc_url=""
l1_explorer_url=""
deployment_key=""
stack_option=""
accept_ownership=""
running_provers=""
deposit_bond=""
bond_amount=""
start_relayers=""
mode=""
force=""
# verify_key_only=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "\n${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "\n${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "\n${RED}[ERROR]${NC} $1" >&2
}

# Show usage help
show_help() {
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo
    echo "Description:"
    echo "  Deploy complete Surge stack with L1 (optional devnet) and L2 components"
    echo
    echo "Options:"
    echo "  --environment ENV        Surge environment (devnet|staging|testnet) [REQUIRED]"
    echo "  --deploy-devnet BOOL     Deploy new devnet or use existing chain (devnet only, true|false)"
    echo "  --deployment TYPE        Deployment type (local|remote)"
    echo "  --deployment-key KEY     Private key for contract deployment (will be verified)"
    echo "  --stack-option NUM       L2 stack option (1-6, see details below)"
    # echo "  --accept-ownership BOOL  Accept ownership (devnet only, true|false)"
    echo "  --running-provers BOOL   Setup provers (devnet only, true|false)"
    echo "  --deposit-bond BOOL      Deposit bond (devnet only, true|false)"
    echo "  --bond-amount NUM        Bond amount in ETH (default: 1000)"
    echo "  --start-relayers BOOL    Start relayers (true|false)"
    echo "  --mode MODE              Execution mode (silence|debug)"
    # echo "  --verify-key-only        Only verify private key, don't deploy"
    echo "  -f, --force              Skip confirmation prompts"
    echo "  -h, --help               Show this help message"
    echo
    echo "Stack Options:"
    echo "  1 - Driver only"
    echo "  2 - Driver + Proposer"
    echo "  3 - Driver + Proposer + Spammer"
    echo "  4 - Driver + Proposer + Prover + Spammer"
    echo "  5 - All except spammer"
    echo "  6 - All components (default)"
    echo
    echo "Execution Modes:"
    echo "  silence - Silent mode with progress indicators (default)"
    echo "  debug   - Debug mode with full output"
    echo
    echo "Examples:"
    echo "  $0 --environment devnet --deploy-devnet true --mode debug"
    echo "  $0 --environment staging --stack-option 3 --start-relayers true"
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
            --accept-ownership)
                accept_ownership="$2"
                shift 2
                ;;
            --running-provers)
                running_provers="$2"
                shift 2
                ;;
            --deposit-bond)
                deposit_bond="$2"
                shift 2
                ;;
            --bond-amount)
                bond_amount="$2"
                shift 2
                ;;
            --start-relayers)
                start_relayers="$2"
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

# Simple progress indicator
show_progress() {
    local pid=$1
    local message="$2"
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    printf "%s " "$message"
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spinner:i++%${#spinner}:1}"
        sleep 0.1
    done
    printf "\b\n"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        log_error "Please start Docker and ensure your user has docker permissions"
        return 1
    fi
    
    # Check required commands
    local required_cmds=("docker" "git" "jq" "curl" "bc" "cast")
    local missing_cmds=()
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        log_error "Please install them first"
        return 1
    fi
    
    # Create required directories
    for dir in "$DEPLOYMENT_DIR" "$CONFIGS_DIR" "driver-data"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating $dir directory..."
            mkdir -p "$dir"
        fi
    done
    
    # Ensure driver-data is writable by containers (always apply, even if dir already exists)
    if [[ -d "driver-data" ]]; then
        chmod 777 "driver-data"
    fi
    
    log_success "Prerequisites validation passed"
    return 0
}

# Initialize git submodules
initialize_submodules() {
    log_info "Initializing git submodules..."
    
    # First, sync submodule URLs from .gitmodules
    if git submodule sync >/dev/null 2>&1; then
        log_info "Synced submodule URLs"
    fi
    
    # Initialize and update submodules recursively
    if git submodule update --init --recursive >/dev/null 2>&1; then
        log_success "Git submodules initialized"
    else
        log_warning "Failed to initialize git submodules with --recursive, trying without..."
        # Try without recursive flag in case some submodules have issues
        if git submodule update --init >/dev/null 2>&1; then
            log_success "Git submodules initialized (non-recursive)"
        else
            log_warning "Failed to initialize git submodules, but continuing..."
        fi
    fi
}

# Ensure ethereum-package submodule exists or use current directory
ensure_ethereum_package() {
    log_info "Checking ethereum-package submodule..."
    
    if [[ ! -f "$ETHEREUM_PACKAGE_DIR/main.star" ]] && [[ "$ETHEREUM_PACKAGE_DIR" != "." ]]; then
        log_error "Invalid ethereum-package directory"
        log_error "Expected Kurtosis main.star file not found"
        return 1
    fi
    
    log_success "ethereum-package verified"
    return 0
}

# Validate private key format
validate_private_key_format() {
    local private_key="$1"
    
    # Must start with 0x
    if [[ ! "$private_key" =~ ^0x ]]; then
        log_error "Private key must start with 0x"
        return 1
    fi
    
    # Must be 66 characters (0x + 64 hex chars)
    if [[ ${#private_key} -ne 66 ]]; then
        log_error "Private key must be 66 characters (0x + 64 hex digits)"
        log_error "Got ${#private_key} characters"
        return 1
    fi
    
    # Must be valid hexadecimal
    if [[ ! "$private_key" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        log_error "Private key must be valid hexadecimal"
        return 1
    fi
    
    return 0
}

# Derive address from private key using cast
derive_address_from_key_cast() {
    local private_key="$1"
    
    if ! command -v cast >/dev/null 2>&1; then
        return 1
    fi
    
    local address
    if address=$(cast wallet address "$private_key" 2>/dev/null); then
        echo "$address"
        return 0
    fi
    
    return 1
}

# Derive address from private key (try multiple methods)
derive_address_from_key() {
    local private_key="$1"
    local address=""
    
    # Try cast first (fastest)
    if address=$(derive_address_from_key_cast "$private_key"); then
        echo "$address"
        return 0
    fi
    
    # Last resort: use docker with foundry
   if address=$(docker run --rm $SURGE_PROTOCOL_IMAGE cast wallet address "$private_key" 2>/dev/null | head -n1); then
        if [ -n "$address" ]; then
            echo "$address"
            return 0
        fi
    fi
    
    log_error "Unable to derive address from private key"
    log_error "Please install Foundry (cast) and ensure it is in your PATH"
    return 1
}

# Test RPC connection
test_rpc_connection() {
    local rpc_url="$1"
    
    local response
    if ! response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","id":0,"method":"eth_blockNumber","params":[]}' \
        "$rpc_url" 2>/dev/null); then
        return 1
    fi
    
    if echo "$response" | jq -e '.result' >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Get chain ID
get_chain_id() {
    local rpc_url="$1"
    
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","id":0,"method":"eth_chainId","params":[]}' \
        "$rpc_url" 2>/dev/null)
    
    if echo "$response" | jq -e '.result' >/dev/null 2>&1; then
        local chain_id_hex
        chain_id_hex=$(echo "$response" | jq -r '.result')
        # Convert hex to decimal
        printf "%d" "$chain_id_hex"
        return 0
    fi
    
    return 1
}

# Verify private key on chain
verify_private_key_on_chain() {
    local private_key="$1"
    local rpc_url="$2"
    local chain_name="$3"
    
    log_info "Verifying private key on $chain_name..."
    
    # 1. Validate format
    log_info "Validating private key format..."
    if ! validate_private_key_format "$private_key"; then
        log_error "Invalid private key format"
        return 1
    fi
    log_success "Private key format validated"
    
    # 2. Derive address from private key
    log_info "Deriving address from private key..."
    local address
    if ! address=$(derive_address_from_key "$private_key"); then
        log_error "Failed to derive address from private key"
        return 1
    fi
    log_info "Address used for deployment: $address"
    
    # 3. Test RPC connection
    log_info "Testing RPC connection..."
    if ! test_rpc_connection "$rpc_url"; then
        log_error "Cannot connect to RPC endpoint: $rpc_url"
        log_error "Please verify the URL is correct and the RPC server is running"
        return 1
    fi
    log_success "RPC connection successful"
    
    # 4. Get account balance
    log_info "Querying account balance..."
    local balance
    if ! balance=$(cast balance -e "$address" --rpc-url "$rpc_url" 2>/dev/null); then
        log_error "Failed to query account balance"
        return 1
    fi
    # Validate balance is not empty
    if [ -z "$balance" ]; then
        log_error "Received empty balance response"
        return 1
    fi
    log_info "Account balance: $balance ETH"
    
    # 5. Verify chain ID
    log_info "Verifying chain ID..."
    local chain_id
    if ! chain_id=$(cast chain-id --rpc-url "$rpc_url" 2>/dev/null); then
        log_error "Failed to get chain ID"
        return 1
    fi
    log_info "Chain ID: $chain_id"
    
    # 6. Check sufficient balance

    local min_balance="0.01"  # 0.01 ETH
    if (( $(echo "$balance < $min_balance" | bc -l) )); then
        log_warning "Account balance is low. Deployment may fail."
        log_warning "Current balance: $balance ETH"
        log_warning "Recommended: >= 0.01 ETH"
        
        if [[ "$force" != "true" ]]; then
            echo
            read -p "Continue anyway? (yes/no) [no]: " continue_choice
            continue_choice=${continue_choice:-no}
            if [[ "$continue_choice" != "yes" && "$continue_choice" != "y" ]]; then
                log_error "Aborted by user"
                return 1
            fi
        fi
    fi
    
    # 7. Display verification summary
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Private Key Verification Summary                            ║"
    echo "║══════════════════════════════════════════════════════════════║"
    printf "   Address:      %-42s  \n" "$address"
    printf "   Balance:      %-20s ETH                         \n" "$balance"
    printf "   Chain ID:     %-42s  \n" "$chain_id"
    echo "║  RPC Status:   ✓ Connected                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    
    log_success "Private key verified successfully"
    
    # Export address for later use
    export DEPLOYMENT_ADDRESS="$address"
    export DEPLOYMENT_BALANCE="$balance"
    
    return 0
}

# Prompt for environment selection
prompt_environment_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select which Surge environment to use:                    " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  1 for Devnet                                                ║" >&2
    echo "║  2 for Staging                                               ║" >&2
    echo "║  3 for Testnet                                               ║" >&2
    echo "║ [default: Devnet]                                            ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [1]: " choice
    choice=${choice:-1}
    echo $choice
}

# Prompt for deployment type selection
prompt_deployment_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select deployment type:                                   " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  0 for local                                                 ║" >&2
    echo "║  1 for remote                                                ║" >&2
    echo "║ [default: local]                                             ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo $choice
}

# Prompt for L1 deployment mode (devnet only)
prompt_l1_deployment_mode() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Deploy new devnet or use existing L1?                     " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  0 for Deploy new devnet                                     ║" >&2
    echo "║  1 for Use existing chain (WIP)                              ║" >&2
    echo "║ [default: Deploy new devnet]                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo $choice
}

# Check and load environment file
check_env_file() {
    local env_name="$1"
    
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading environment variables from $ENV_FILE..."
        set -a  # automatically export all variables
        source "$ENV_FILE"
        set +a  # disable automatic export
        log_success "Environment variables loaded successfully"
    else
        local env_file_name=".env.$env_name"
        log_info ".env file not found, loading from $env_file_name..."
        
        if [[ -f "$env_file_name" ]]; then
            cp "$env_file_name" "$ENV_FILE"
            set -a  # automatically export all variables
            source "$ENV_FILE"
            set +a  # disable automatic export
            log_success "Successfully loaded $env_name environment variables"
        else
            log_error "Neither .env nor $env_file_name file found"
            log_error "Please create a .env file with required configuration"
            return 1
        fi
    fi
    
    return 0
}

# Get machine IP address
get_machine_ip() {
    local ip=""
    
    # Try multiple methods to get IP
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -n1)
    fi
    
    if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    
    echo "$ip"
}

# Convert endpoint to docker-internal format (for use inside containers)
to_docker_internal() {
    local endpoint="$1"
    # Replace hostname with host.docker.internal, preserving protocol and port
    echo "$endpoint" | sed -E 's#(https?://)([^:/]+)(.*)#\1host.docker.internal\3#'
}

# Convert docker-internal endpoint to localhost (for use from host machine)
to_localhost() {
    local endpoint="$1"
    # Replace host.docker.internal with localhost
    echo "$endpoint" | sed -E 's#(https?://)host\.docker\.internal(.*)#\1localhost\2#'
}

# Format endpoint based on deployment context
format_endpoint_for_context() {
    local endpoint="$1"
    local deployment_type="$2"  # local or remote
    local machine_ip="$3"
    
    if [[ "$deployment_type" == "remote" || "$deployment_type" == "1" ]] && [[ -n "$machine_ip" ]]; then
        # Replace hostname with machine IP for remote access
        echo "$endpoint" | sed -E "s#(https?://)([^:/]+)(.*)#\1$machine_ip\3#"
    elif [[ "$deployment_type" == "local" || "$deployment_type" == "0" ]]; then
        # Replace hostname with host.docker.internal for local docker access
        echo "$endpoint" | sed -E 's#(https?://)([^:/]+)(.*)#\1host.docker.internal\3#'
    else
        # Return as-is if no transformation needed
        echo "$endpoint"
    fi
}

# Extract port from endpoint URL
extract_port() {
    local endpoint="$1"
    echo "$endpoint" | grep -oP ':\K[0-9]+$' || echo ""
}

# Build endpoint URL from host and port
build_endpoint() {
    local protocol="${1:-http}"
    local host="$2"
    local port="$3"
    
    if [[ -n "$port" ]]; then
        echo "${protocol}://${host}:${port}"
    else
        echo "${protocol}://${host}"
    fi
}

# Configure blockscout for remote access
configure_remote_blockscout() {
    local machine_ip="$1"
    
    if [[ ! -f "$BLOCKSCOUT_CONFIG_FILE" ]]; then
        log_warning "Blockscout configuration file not found: $BLOCKSCOUT_CONFIG_FILE"
        return 0
    fi
    
    if [[ ! -d "$(dirname "$BLOCKSCOUT_FILE")" ]]; then
        log_warning "Blockscout target directory not found: $(dirname "$BLOCKSCOUT_FILE")"
        return 0
    fi
    
    log_info "Copy blockscout configuration..."
    cp "$BLOCKSCOUT_CONFIG_FILE" "$BLOCKSCOUT_FILE"
    
    log_info "Configuring blockscout for remote access (IP: $machine_ip)..."
    if [[ -f "$BLOCKSCOUT_FILE" ]]; then
        sed -i.tmp "s/else \"localhost:{0}\"/else \"$machine_ip:{0}\"/g" "$BLOCKSCOUT_FILE"
        rm -f "${BLOCKSCOUT_FILE}.tmp"
    fi
    
    log_success "Blockscout configured for remote access"
}

# Configure shared_utils for more ports
configure_shared_utils() {
    if [[ ! -f "$SHARED_UTILS_CONFIG_FILE" ]]; then
        log_warning "Shared utils configuration file not found: $SHARED_UTILS_CONFIG_FILE"
        return 0
    fi
    
    if [[ ! -d "$(dirname "$SHARED_UTILS_FILE")" ]]; then
        log_warning "Shared utils target directory not found: $(dirname "$SHARED_UTILS_FILE")"
        return 0
    fi
    
    log_info "Copy shared_utils configuration..."
    cp "$SHARED_UTILS_CONFIG_FILE" "$SHARED_UTILS_FILE"
    
    log_success "Configured shared_utils for more ports..."
}

# Configure input_parser for blockscout image
configure_input_parser() {
    if [[ ! -f "$INPUT_PARSER_CONFIG_FILE" ]]; then
        log_warning "Input parser configuration file not found: $INPUT_PARSER_CONFIG_FILE"
        return 0
    fi
    
    if [[ ! -d "$(dirname "$INPUT_PARSER_FILE")" ]]; then
        log_warning "Input parser target directory not found: $(dirname "$INPUT_PARSER_FILE")"
        return 0
    fi
    
    log_info "Copy input_parser configuration..."
    cp "$INPUT_PARSER_CONFIG_FILE" "$INPUT_PARSER_FILE"
    
    log_success "Configured input_parser for blockscout image..."
}

# Configure spamoor for fixed port
configure_spamoor() {
    if [[ ! -f "$SPAMOOR_CONFIG_FILE" ]] || [[ ! -f "$MAIN_CONFIG_FILE" ]]; then
        log_warning "Spamoor or main configuration file not found"
        return 0
    fi
    
    if [[ ! -d "$(dirname "$SPAMOOR_FILE")" ]]; then
        log_warning "Spamoor target directory not found: $(dirname "$SPAMOOR_FILE")"
        return 0
    fi
    
    log_info "Copy spamoor configuration..."
    cp "$SPAMOOR_CONFIG_FILE" "$SPAMOOR_FILE"
    cp "$MAIN_CONFIG_FILE" "$MAIN_FILE"
    
    log_success "Configured spamoor for fixed port..."
}

# Configure nethermind launcher for enabling proofs translation
configure_nethermind_launcher() {
    if [[ ! -f "$NETHERMIND_LAUNCHER_CONFIG_FILE" ]]; then
        log_warning "Nethermind launcher configuration file not found: $NETHERMIND_LAUNCHER_CONFIG_FILE"
        return 0
    fi
    
    if [[ ! -d "$(dirname "$NETHERMIND_LAUNCHER_FILE")" ]]; then
        log_warning "Nethermind launcher target directory not found: $(dirname "$NETHERMIND_LAUNCHER_FILE")"
        return 0
    fi
    
    log_info "Copy nethermind launcher configuration..."
    cp "$NETHERMIND_LAUNCHER_CONFIG_FILE" "$NETHERMIND_LAUNCHER_FILE"
    
    log_success "Configured nethermind launcher for enabling proofs translation..."
}

# Configure environment URLs
configure_environment_urls() {
    local env_choice="$1"
    local deployment_choice="$2"
    local machine_ip="$3"
    
    case "$env_choice" in
        1|"devnet")
            log_info "Using Devnet Environment"
            # Create docker network if it doesn't exist
            if ! docker network ls | grep -q "surge-network"; then
                docker network create surge-network
            fi

            # Set default endpoints for devnet if not already defined in .env
            # These can be overridden by pre-existing .env values
            if [[ -z "${L1_ENDPOINT_HTTP:-}" ]]; then
                export L1_ENDPOINT_HTTP="http://localhost:32003"
            fi
            if [[ -z "${L1_BEACON_HTTP:-}" ]]; then
                export L1_BEACON_HTTP="http://localhost:33001"
            fi
            if [[ -z "${L2_ENDPOINT_HTTP:-}" ]]; then
                export L2_ENDPOINT_HTTP="http://localhost:${L2_HTTP_PORT:-8547}"
            fi
            
            # Create context-specific endpoint versions
            # DOCKER versions: for containers to access host services (always use host.docker.internal)
            export L1_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L1_ENDPOINT_HTTP")
            export L1_BEACON_HTTP_DOCKER=$(to_docker_internal "$L1_BEACON_HTTP")
            export L2_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L2_ENDPOINT_HTTP")
            
            # EXTERNAL versions: for host/browser access (use actual IP for remote, localhost for local)
            if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                # Remote: replace hostname with machine IP for external access
                export L1_ENDPOINT_HTTP_EXTERNAL=$(format_endpoint_for_context "$L1_ENDPOINT_HTTP" "remote" "$machine_ip")
                export L1_BEACON_HTTP_EXTERNAL=$(format_endpoint_for_context "$L1_BEACON_HTTP" "remote" "$machine_ip")
                export L2_ENDPOINT_HTTP_EXTERNAL=$(format_endpoint_for_context "$L2_ENDPOINT_HTTP" "remote" "$machine_ip")
            else
                # Local: convert to localhost for host access (handles both localhost and host.docker.internal in .env)
                export L1_ENDPOINT_HTTP_EXTERNAL=$(to_localhost "$L1_ENDPOINT_HTTP")
                export L1_BEACON_HTTP_EXTERNAL=$(to_localhost "$L1_BEACON_HTTP")
                export L2_ENDPOINT_HTTP_EXTERNAL=$(to_localhost "$L2_ENDPOINT_HTTP")
            fi
            
            # Set explorer and relayer endpoints (for external/browser access)
            if [[ -z "${L1_EXPLORER:-}" ]]; then
                if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                    export L1_EXPLORER="http://$machine_ip:36005"
                else
                    export L1_EXPLORER="http://localhost:36005"
                fi
            fi
            if [[ -z "${L2_EXPLORER:-}" ]]; then
                if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                    export L2_EXPLORER="http://$machine_ip:${BLOCKSCOUT_FRONTEND_PORT:-3001}"
                else
                    export L2_EXPLORER="http://localhost:${BLOCKSCOUT_FRONTEND_PORT:-3001}"
                fi
            fi
            if [[ -z "${L1_RELAYER:-}" ]]; then
                if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                    export L1_RELAYER="http://$machine_ip:4102"
                else
                    export L1_RELAYER="http://localhost:4102"
                fi
            fi
            if [[ -z "${L2_RELAYER:-}" ]]; then
                if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                    export L2_RELAYER="http://$machine_ip:4103"
                else
                    export L2_RELAYER="http://localhost:4103"
                fi
            fi
            ;;
        2|"staging")
            log_info "Using Staging Environment"
            # Create docker network if it doesn't exist
            if ! docker network ls | grep -q "surge-network"; then
                docker network create surge-network
            fi
            
            # For staging/testnet, respect .env values
            # DOCKER versions: convert to host.docker.internal for container access
            # EXTERNAL versions: keep original for host/browser access
            if [[ -n "${L1_ENDPOINT_HTTP:-}" ]]; then
                export L1_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L1_ENDPOINT_HTTP")
                export L1_ENDPOINT_HTTP_EXTERNAL="$L1_ENDPOINT_HTTP"
            fi
            if [[ -n "${L1_BEACON_HTTP:-}" ]]; then
                export L1_BEACON_HTTP_DOCKER=$(to_docker_internal "$L1_BEACON_HTTP")
                export L1_BEACON_HTTP_EXTERNAL="$L1_BEACON_HTTP"
            fi
            if [[ -n "${L2_ENDPOINT_HTTP:-}" ]]; then
                export L2_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L2_ENDPOINT_HTTP")
                export L2_ENDPOINT_HTTP_EXTERNAL="$L2_ENDPOINT_HTTP"
            fi
            ;;
        3|"testnet")
            log_info "Using Testnet Environment"
            # Create docker network if it doesn't exist
            if ! docker network ls | grep -q "surge-network"; then
                docker network create surge-network
            fi
            
            # For staging/testnet, respect .env values
            # DOCKER versions: convert to host.docker.internal for container access
            # EXTERNAL versions: keep original for host/browser access
            if [[ -n "${L1_ENDPOINT_HTTP:-}" ]]; then
                export L1_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L1_ENDPOINT_HTTP")
                export L1_ENDPOINT_HTTP_EXTERNAL="$L1_ENDPOINT_HTTP"
            fi
            if [[ -n "${L1_BEACON_HTTP:-}" ]]; then
                export L1_BEACON_HTTP_DOCKER=$(to_docker_internal "$L1_BEACON_HTTP")
                export L1_BEACON_HTTP_EXTERNAL="$L1_BEACON_HTTP"
            fi
            if [[ -n "${L2_ENDPOINT_HTTP:-}" ]]; then
                export L2_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L2_ENDPOINT_HTTP")
                export L2_ENDPOINT_HTTP_EXTERNAL="$L2_ENDPOINT_HTTP"
            fi
            ;;
        *)
            log_error "Invalid environment choice: $env_choice"
            return 1
            ;;
    esac
    
    return 0
}

# Helper function to update environment variables in .env file
update_env_var() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"

    # Check if the variable exists in the file
    if grep -q "^${var_name}=" "$env_file"; then
        # Update existing variable (handle special characters)
        sed -i.bak "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file" && rm -f "$env_file.bak"
    else
        # Add new variable if it doesn't exist
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# Validate environment for devnet deployment
validate_environment_for_devnet() {
    log_info "Validating environment for devnet deployment..."
    
    # Check if enclave already exists
    if kurtosis enclave ls 2>/dev/null | grep -q "$ENCLAVE_NAME"; then
        log_warning "Enclave '$ENCLAVE_NAME' already exists"
        
        if [[ "$force" != "true" ]]; then
            read -p "Remove existing enclave? (yes/no) [yes]: " remove_choice
            remove_choice=${remove_choice:-yes}
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

    echo
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
        echo
        
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

# Check L1 network health
check_l1_health() {
    local rpc_url="$1"
    local beacon_url="${2:-}"
    
    log_info "Checking L1 network health..."
    
    local el_healthy=false
    local cl_healthy=false
    
    # Check Execution Layer
    if curl -s "$rpc_url" -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","id":0,"method":"eth_syncing","params":[]}' \
        | jq -r '.result == false' >/dev/null 2>&1; then
        log_success "Execution Layer is synced"
        el_healthy=true
    else
        log_warning "Execution Layer is not synced or unreachable"
    fi
    
    # Check Consensus Layer (if beacon URL provided)
    if [[ -n "$beacon_url" ]]; then
        if curl -s "$beacon_url/lighthouse/syncing" \
            | jq -r '.data == "Synced"' >/dev/null 2>&1; then
            log_success "Beacon Node is synced"
            cl_healthy=true
        else
            log_warning "Beacon Node is not synced or unreachable"
        fi
    fi
    
    if [[ "$el_healthy" == true ]]; then
        log_success "L1 network is healthy and ready"
        return 0
    else
        log_warning "L1 network may still be starting up. Check again in a few minutes."
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
cleanup() {
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

# Set trap for cleanup on exit
trap cleanup EXIT

# Generate prover chain spec list JSON
generate_prover_chain_spec() {
    log_info "Generating prover chain spec list json..."

    local genesis_time
    local beacon_endpoint="${L1_BEACON_HTTP_EXTERNAL:-${L1_BEACON_HTTP:-http://localhost:33001}}"
    if ! genesis_time=$(curl -s "${beacon_endpoint}/eth/v1/beacon/genesis" | jq -r '.data.genesis_time' 2>/dev/null); then
        log_warning "Failed to retrieve genesis time, using default value 0"
        genesis_time=0
    fi

    # Use docker-internal endpoints for chain spec (used by containers)
    local l1_rpc_docker="${L1_ENDPOINT_HTTP_DOCKER:-http://host.docker.internal:32003}"
    local l1_beacon_docker="${L1_BEACON_HTTP_DOCKER:-http://host.docker.internal:33001}"
    local l2_rpc_docker="${L2_ENDPOINT_HTTP_DOCKER:-http://host.docker.internal:8547}"

    # Generate chain spec list
    cat > "$CONFIGS_DIR/chain_spec_list_default.json" << EOF
[
  {
    "name": "surge_dev_l1",
    "chain_id": $L1_CHAIN_ID,
    "max_spec_id": "CANCUN",
    "hard_forks": {},
    "eip_1559_constants": {
      "base_fee_change_denominator": "0x8",
      "base_fee_max_increase_denominator": "0x8",
      "base_fee_max_decrease_denominator": "0x8",
      "elasticity_multiplier": "0x2"
    },
    "l1_contract": {},
    "l2_contract": null,
    "rpc": "$l1_rpc_docker",
    "beacon_rpc": "$l1_beacon_docker",
    "verifier_address_forks": {},
    "genesis_time": $genesis_time,
    "seconds_per_slot": 12,
    "is_taiko": false
  },
  {
    "name": "surge_dev",
    "chain_id": $L2_CHAIN_ID,
    "max_spec_id": "PACAYA",
    "hard_forks": {
        "ONTAKE": {
            "Block": 1
        },
        "PACAYA": {
            "Block": 1
        },
        "SHASTA": {
            "Timestamp": 1
        }
    },
    "eip_1559_constants": {
      "base_fee_change_denominator": "0x8",
      "base_fee_max_increase_denominator": "0x8",
      "base_fee_max_decrease_denominator": "0x8",
      "elasticity_multiplier": "0x2"
    },
    "l1_contract": {
      "SHASTA": "$SHASTA_SURGE_INBOX",
      "PACAYA": "$PACAYA_TAIKO"
    },
    "l2_contract": "$TAIKO_ANCHOR",
    "rpc": "$l2_rpc_docker",
    "beacon_rpc": null,
    "verifier_address_forks": {
      "ONTAKE": {
        "SP1": "$PACAYA_SP1_RETH_VERIFIER",
        "RISC0": "$PACAYA_RISC0_RETH_VERIFIER"
      },
      "PACAYA": {
        "SP1": "$PACAYA_SP1_RETH_VERIFIER",
        "RISC0": "$PACAYA_RISC0_RETH_VERIFIER"
      },
      "SHASTA": {
        "SP1": "$PACAYA_SP1_RETH_VERIFIER",
        "RISC0": "$PACAYA_RISC0_RETH_VERIFIER"
      }
    },
    "genesis_time": 0,
    "seconds_per_slot": 1,
    "is_taiko": true
  }
]
EOF

        # Generate config.json for raiko
    cat > "$CONFIGS_DIR/config.json" << EOF
{
	"address": "0.0.0.0:8080",
	"network": "surge_dev",
	"concurrency_limit": 1,
	"l1_network": "surge_dev_l1",
	"cache_path": "/tmp/raiko/",
	"prover": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
	"graffiti": "8008500000000000000000000000000000000000000000000000000000000000",
	"proof_type": "sp1",
	"blob_proof_type": "proof_of_equivalence",
	"redis_url": "redis://redis-zk:6379",
	"redis_ttl": 3600,
	"enable_redis_pool": false,
	"queue_limit": 1000,
	"api_keys": "",
	"ballot_zk": "{\"Sp1\":[1, 0]}",
	"ballot_sgx": "{\"Sgx\":[1, 0]}"
}
EOF

    log_success "Prover chain spec list json and config json generated successfully"
    log_info "Saved to: $CONFIGS_DIR/chain_spec_list_default.json and $CONFIGS_DIR/config.json"
}

# Retrieve guest data from prover endpoints
retrieve_guest_data() {
    local prover_type="$1"
    
    case "$prover_type" in
        sp1)
            if [[ -n "${RAIKO_HOST_ZKVM:-}" ]]; then
                log_info "Retrieving guest data for SP1 - $RAIKO_HOST_ZKVM"
                export SP1_BLOCK_PROVING_PROGRAM_VKEY=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.[0].sp1.block_program_hash')
                export SP1_AGGREGATION_PROGRAM_VKEY=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.[0].sp1.aggregation_program_hash')
            fi
            ;;
        risc0)
            if [[ -n "${RAIKO_HOST_ZKVM:-}" ]]; then
                log_info "Retrieving guest data for RISC0 - $RAIKO_HOST_ZKVM"
                export RISC0_AGGREGATION_IMAGE_ID=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.[0].risc0.aggregation_program_hash')
                export RISC0_BLOCK_PROVING_IMAGE_ID=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.[0].risc0.block_program_hash')
            fi
            ;;
    esac
}

# Deploy Pacaya smart contracts
deploy_pacaya_contracts() {
    local mode="$1"
    local slow_mode="$2"

    if [[ "$slow_mode" != "true" ]]; then
        slow_mode=false
    fi
    
    if [[ -f "$L1_DEPLOYMENT_FILE" && -f "$L1_LOCK_FILE" && -f "$PACAYA_DEPLOYMENT_FILE" ]]; then
        log_info "Pacaya smart contracts already deployed...skipping deployment"
        return 0
    fi

    log_info "Deploying Pacaya SCs... SLOW: $slow_mode"
    
    local exit_status=0
    local temp_output="/tmp/pacaya_deploy_output_$$"
    
    # Deploy L1 contracts based on mode
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=true VERIFY=false SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile pacaya-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=true VERIFY=false SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile pacaya-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying Pacaya smart contracts..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "Pacaya smart contracts deployed successfully"
        return 0
    else
        log_error "Failed to deploy Pacaya smart contracts (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
}

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
        local choice
        if [[ "$force" == "true" ]]; then
            choice=0  # default: use existing deployment
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
                ./remove-surge-full.sh --remove-configs true --remove-l2-stack true --remove-data false --remove-relayers true --force
            fi
        else
            log_info "Using existing deployment..."
            return 0
        fi
    fi

    log_info "Preparing Surge L1 SCs deployment..."

    log_info "Deploying Surge L1 SCs... BROADCAST: $broadcast SLOW: $slow_mode"
    
    local exit_status=0
    local temp_output="/tmp/surge_l1_deploy_output_$$"
    
    # Deploy L1 contracts based on mode
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=$broadcast VERIFY=false USE_DUMMY_VERIFIER=$mock_proof SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile l1-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=$broadcast VERIFY=false USE_DUMMY_VERIFIER=$mock_proof SLOW=$slow_mode docker compose -f docker-compose-protocol.yml --profile l1-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying L1 smart contracts..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "L1 smart contracts deployed successfully"
        # Only create lock file after successful broadcast deployment
        if [[ "$broadcast" == "true" ]]; then
            echo "broadcast: $broadcast"
            echo "touching lock file: $L1_LOCK_FILE"
            touch "$L1_LOCK_FILE"
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

# Extract L1 deployment results from JSON file
extract_l1_deployment_results() {
    log_info "Extracting Pacaya and Surge L1 SCs deployment results..."
    
    if [[ -f "$PACAYA_DEPLOYMENT_FILE" ]]; then
        # Extract L1 deployment results from deploy_l1_pacaya.json
        export PACAYA_AUTOMATA_DCAP_ATTESTATION=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.automata_dcap_attestation')
        export PACAYA_BRIDGE=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.bridge')
        export PACAYA_ERC1155_VAULT=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.erc1155_vault')
        export PACAYA_ERC20_VAULT=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.erc20_vault')
        export PACAYA_ERC721_VAULT=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.erc721_vault')
        export PACAYA_FORCED_INCLUSION_STORE=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.forced_inclusion_store')
        export PACAYA_MAINNET_TAIKO=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.mainnet_taiko')
        export PACAYA_OP_GETH_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.op_geth_verifier')
        export PACAYA_OP_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.op_verifier')
        export PACAYA_PRECONF_ROUTER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.preconf_router')
        export PACAYA_PRECONF_WHITELIST=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.preconf_whitelist')
        export PACAYA_PROOF_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.proof_verifier')
        export PACAYA_PROVER_SET=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.prover_set')
        export PACAYA_RISC0_RETH_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.risc0_reth_verifier')
        export PACAYA_ROLLUP_ADDRESS_RESOLVER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.rollup_address_resolver')
        export PACAYA_SGX_GETH_AUTOMATA=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.sgx_geth_automata')
        export PACAYA_SGX_GETH_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.sgx_geth_verifier')
        export PACAYA_SGX_RETH_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.sgx_reth_verifier')
        export PACAYA_SHARED_RESOLVER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.shared_resolver')
        export PACAYA_SIGNAL_SERVICE=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.signal_service')
        export PACAYA_SP1_RETH_VERIFIER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.sp1_reth_verifier')
        export PACAYA_TAIKO=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.taiko')
        export PACAYA_TAIKO_TOKEN=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.taiko_token')
        export PACAYA_TAIKO_WRAPPER=$(cat "$PACAYA_DEPLOYMENT_FILE" | jq -r '.taiko_wrapper')

        update_env_var "$ENV_FILE" "PACAYA_AUTOMATA_DCAP_ATTESTATION" "$PACAYA_AUTOMATA_DCAP_ATTESTATION"
        update_env_var "$ENV_FILE" "PACAYA_BRIDGE" "$PACAYA_BRIDGE"
        update_env_var "$ENV_FILE" "PACAYA_ERC1155_VAULT" "$PACAYA_ERC1155_VAULT"
        update_env_var "$ENV_FILE" "PACAYA_ERC20_VAULT" "$PACAYA_ERC20_VAULT"
        update_env_var "$ENV_FILE" "PACAYA_ERC721_VAULT" "$PACAYA_ERC721_VAULT"
        update_env_var "$ENV_FILE" "PACAYA_FORCED_INCLUSION_STORE" "$PACAYA_FORCED_INCLUSION_STORE"
        update_env_var "$ENV_FILE" "PACAYA_MAINNET_TAIKO" "$PACAYA_MAINNET_TAIKO"
        update_env_var "$ENV_FILE" "PACAYA_OP_GETH_VERIFIER" "$PACAYA_OP_GETH_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_OP_VERIFIER" "$PACAYA_OP_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_PRECONF_ROUTER" "$PACAYA_PRECONF_ROUTER"
        update_env_var "$ENV_FILE" "PACAYA_PRECONF_WHITELIST" "$PACAYA_PRECONF_WHITELIST"
        update_env_var "$ENV_FILE" "PACAYA_PROOF_VERIFIER" "$PACAYA_PROOF_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_PROVER_SET" "$PACAYA_PROVER_SET"
        update_env_var "$ENV_FILE" "PACAYA_RISC0_RETH_VERIFIER" "$PACAYA_RISC0_RETH_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_ROLLUP_ADDRESS_RESOLVER" "$PACAYA_ROLLUP_ADDRESS_RESOLVER"
        update_env_var "$ENV_FILE" "PACAYA_SGX_GETH_AUTOMATA" "$PACAYA_SGX_GETH_AUTOMATA"
        update_env_var "$ENV_FILE" "PACAYA_SGX_GETH_VERIFIER" "$PACAYA_SGX_GETH_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_SGX_RETH_VERIFIER" "$PACAYA_SGX_RETH_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_SHARED_RESOLVER" "$PACAYA_SHARED_RESOLVER"
        update_env_var "$ENV_FILE" "PACAYA_SIGNAL_SERVICE" "$PACAYA_SIGNAL_SERVICE"
        update_env_var "$ENV_FILE" "PACAYA_SP1_RETH_VERIFIER" "$PACAYA_SP1_RETH_VERIFIER"
        update_env_var "$ENV_FILE" "PACAYA_TAIKO" "$PACAYA_TAIKO"
        update_env_var "$ENV_FILE" "PACAYA_TAIKO_TOKEN" "$PACAYA_TAIKO_TOKEN"
        update_env_var "$ENV_FILE" "PACAYA_TAIKO_WRAPPER" "$PACAYA_TAIKO_WRAPPER"
    fi

    # if [[ ! -f "$L1_DEPLOYMENT_FILE" ]]; then
    #     log_error "L1 deployment file not found: $L1_DEPLOYMENT_FILE"
    #     return 1
    # fi

    # Extract L1 deployment results from deploy_l1.json
    export SHASTA_BRIDGE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.bridge')
    export SHASTA_BRIDGED_ERC1155=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.bridged_erc1155')
    export SHASTA_BRIDGED_ERC20=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.bridged_erc20')
    export SHASTA_BRIDGED_ERC721=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.bridged_erc721')
    export SHASTA_EMPTY_IMPL=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.empty_impl')
    export SHASTA_ERC1155_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc1155_vault')
    export SHASTA_ERC20_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc20_vault')
    export SHASTA_ERC721_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc721_vault')
    export SHASTA_PRECONF_WHITELIST=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.preconf_whitelist')
    export SHASTA_RISC0_GROTH16_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.risc0_groth16_verifier')
    export SHASTA_RISC0_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.risc0_verifier')
    export SHASTA_PROOF_VERIFIER_DUMMY=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.proof_verifier_dummy')
    export SHASTA_SHARED_RESOLVER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.shared_resolver')
    export SHASTA_SIGNAL_SERVICE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.signal_service')
    export SHASTA_SP1_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.sp1_verifier')
    export SHASTA_SUCCINCT_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.succinct_verifier')
    export SHASTA_SURGE_INBOX=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.surge_inbox')
    export SHASTA_SURGE_INBOX_IMPL=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.surge_inbox_impl')
    export SHASTA_SURGE_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.surge_verifier')

    echo
    echo ">>>>>>"
    echo " SURGE_INBOX: $SHASTA_SURGE_INBOX "
    echo " BRIDGE: $SHASTA_BRIDGE "
    echo " SIGNAL_SERVICE: $SHASTA_SIGNAL_SERVICE "
    echo " PRECONF_WHITELIST: $SHASTA_PRECONF_WHITELIST "
    echo ">>>>>>"
    echo

    log_info "Updating .env with extracted values..."

    update_env_var "$ENV_FILE" "SHASTA_BRIDGE" "$SHASTA_BRIDGE"
    update_env_var "$ENV_FILE" "SHASTA_BRIDGED_ERC1155" "$SHASTA_BRIDGED_ERC1155"
    update_env_var "$ENV_FILE" "SHASTA_BRIDGED_ERC20" "$SHASTA_BRIDGED_ERC20"
    update_env_var "$ENV_FILE" "SHASTA_BRIDGED_ERC721" "$SHASTA_BRIDGED_ERC721"
    update_env_var "$ENV_FILE" "SHASTA_EMPTY_IMPL" "$SHASTA_EMPTY_IMPL"
    update_env_var "$ENV_FILE" "SHASTA_ERC1155_VAULT" "$SHASTA_ERC1155_VAULT"
    update_env_var "$ENV_FILE" "SHASTA_ERC20_VAULT" "$SHASTA_ERC20_VAULT"
    update_env_var "$ENV_FILE" "SHASTA_ERC721_VAULT" "$SHASTA_ERC721_VAULT"
    update_env_var "$ENV_FILE" "SHASTA_RISC0_GROTH16_VERIFIER" "$SHASTA_RISC0_GROTH16_VERIFIER"
    update_env_var "$ENV_FILE" "SHASTA_RISC0_VERIFIER" "$SHASTA_RISC0_VERIFIER"
    update_env_var "$ENV_FILE" "SHASTA_SIGNAL_SERVICE" "$SHASTA_SIGNAL_SERVICE"
    update_env_var "$ENV_FILE" "SHASTA_SP1_VERIFIER" "$SHASTA_SP1_VERIFIER"
    update_env_var "$ENV_FILE" "SHASTA_SUCCINCT_VERIFIER" "$SHASTA_SUCCINCT_VERIFIER"
    update_env_var "$ENV_FILE" "SHASTA_PRECONF_WHITELIST" "$SHASTA_PRECONF_WHITELIST"
    update_env_var "$ENV_FILE" "SHASTA_PROOF_VERIFIER_DUMMY" "$SHASTA_PROOF_VERIFIER_DUMMY"
    update_env_var "$ENV_FILE" "SHASTA_SHARED_RESOLVER" "$SHASTA_SHARED_RESOLVER"
    update_env_var "$ENV_FILE" "SHASTA_SURGE_INBOX" "$SHASTA_SURGE_INBOX"
    update_env_var "$ENV_FILE" "SHASTA_SURGE_INBOX_IMPL" "$SHASTA_SURGE_INBOX_IMPL"
    update_env_var "$ENV_FILE" "SHASTA_SURGE_VERIFIER" "$SHASTA_SURGE_VERIFIER"
    # Add more as needed...

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
    export SHASTA_SIGNAL_SERVICE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.signal_service')
    update_env_var "$ENV_FILE" "SHASTA_SIGNAL_SERVICE" "$SHASTA_SIGNAL_SERVICE"
    
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

    update_env_var "$ENV_FILE" "SHASTA_TIMESTAMP_SEC" "$NEW_TIMESTAMP"

    HEX_TIMESTAMP=$(printf "0x%X" "$NEW_TIMESTAMP")

    echo "HEX_TIMESTAMP: $HEX_TIMESTAMP"

    update_env_var "$ENV_FILE" "SHASTA_TIMESTAMP" "$HEX_TIMESTAMP"

    cat "$SURGE_GENESIS_FILE" | jq --arg hex_timestamp "$HEX_TIMESTAMP" '. * {difficulty: 0, config: {taiko: true, londonBlock: 0, ontakeBlock: 0, pacayaBlock: 1, shastaTimestamp: $hex_timestamp, useSurgeGasPriceOracle: true, feeCollector: "0x0000000000000000000000000000000000000000", shanghaiTime: 0}} | del(.config.clique)' | jq --from-file <(curl -s https://raw.githubusercontent.com/NethermindEth/core-scripts/refs/heads/main/gen2spec/gen2spec.jq) | jq --arg hex_timestamp "$HEX_TIMESTAMP" '.engine.Taiko.shastaTimestamp = $hex_timestamp' > "$DEPLOYMENT_DIR/surge_chainspec.json"
    
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Surge chainspec generation completed successfully          "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    log_info "Fetching genesis hash..."
    # Get genesis hash first by running Nethermind with the chainspec
    docker run -d --name nethermind-genesis-hash -v ./deployment/surge_chainspec.json:/chainspec.json "${NETHERMIND_CLIENT_IMAGE}" --config=none --Init.ChainSpecPath=/chainspec.json
    
    sleep 30

    local genesis_hash=$(docker logs nethermind-genesis-hash 2>/dev/null | grep "Genesis hash" | head -n 1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/.*Genesis hash : *\(0x[0-9a-fA-F]*\).*/\1/' | tr -d '\r\n' | xargs)
    
    update_env_var "$ENV_FILE" "L2_GENESIS_HASH" "$genesis_hash"

    log_info "Genesis hash: $genesis_hash"

    docker stop nethermind-genesis-hash
    docker rm nethermind-genesis-hash

    if [[ $exit_status -eq 0 ]]; then
        log_success "Surge genesis generated successfully"
        return 0
    else
        log_error "Failed to generate Surge genesis (exit code: $exit_status)"
        return 1
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Generation output saved in: $temp_output"
        fi
        return 1
    fi
}

accept_ownership() {
    local mode="$1"

    # Check if deployment is already completed
    if [[ -f "$ACCEPT_OWNERSHIP_FILE" ]]; then
        log_info "Ownership already accepted..."
        return 0
    fi

    log_info "Accepting ownership..."
    
    local exit_status=0
    local temp_output="/tmp/accept_ownership_output_$$"
    
    export CONTRACT_ADDRESSES="$SHASTA_PROOF_VERIFIER_DUMMY,$SHASTA_SURGE_INBOX,$SHASTA_SHARED_RESOLVER"

    # Accept ownership based on mode
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile accept-ownership up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile accept-ownership up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Accepting ownership..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "Ownership accepted successfully"
        return 0
    else
        log_error "Failed to accept ownership (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Deployment output saved in: $temp_output"
        fi
        return 1
    fi
}

switch_fork() {
    local mode="$1"

    if [[ -f "$DEPLOYMENT_DIR/switch_fork.lock" ]]; then
        log_info "Fork already switched..."
        return 0
    fi

    log_info "Switching fork..."

    local exit_status=0
    local temp_output="/tmp/switch_fork_output_$$"
    
    if [[ "$mode" == "debug" ]]; then
        docker compose -f docker-compose-protocol.yml --profile switch-fork up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        docker compose -f docker-compose-protocol.yml --profile switch-fork up >"$temp_output" 2>&1 &
        local switch_fork_pid=$!

        show_progress $switch_fork_pid "Switching fork..."

        wait $switch_fork_pid
        exit_status=$?
    fi

    if [[ $exit_status -eq 0 ]]; then
        log_success "Fork switched successfully"
        touch "$DEPLOYMENT_DIR/switch_fork.lock"
        return 0
    else
        log_error "Failed to switch fork (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Switch fork output saved in: $temp_output"
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
        if [[ "$force" == "true" ]]; then
            should_run_provers=0  # default: deploy provers
        else
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "  ⚠️ Running provers?                                           "
            echo "║══════════════════════════════════════════════════════════════║"
            echo "║  0 for Deploy provers                                        ║"
            echo "║  1 for Skip provers                                          ║"
            echo "║ [default: 0]                                                 ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            read -p "Enter choice [0]: " should_run_provers
            should_run_provers=${should_run_provers:-0}
        fi
    else
        should_run_provers=$running_provers
    fi

    if [[ "$should_run_provers" == "0" || "$should_run_provers" == "true" ]]; then
        generate_prover_chain_spec

        if [[ "$mock_proof" == "1" ]]; then
            if [[ ! -f "$DEPLOYMENT_DIR/sp1_verifier_setup.lock" ]]; then
                local running_sp1
                if [[ "$force" == "true" ]]; then
                    running_sp1=0  # default: deploy SP1
                else
                    echo
                    echo "╔══════════════════════════════════════════════════════════════╗"
                    echo "  ⚠️ Running SP1?                                               "
                    echo "║══════════════════════════════════════════════════════════════║"
                    echo "║  0 for Deploy SP1                                            ║"
                    echo "║  1 for Skip SP1                                              ║"
                    echo "║ [default: 0]                                                 ║"
                    echo "╚══════════════════════════════════════════════════════════════╝"
                    echo
                    read -p "Enter choice [0]: " running_sp1
                    running_sp1=${running_sp1:-0}
                fi

                if [[ "$running_sp1" == "0" ]]; then
                    retrieve_guest_data sp1
                    
                    if [[ -z "${SP1_BLOCK_PROVING_PROGRAM_VKEY:-}" ]] || [[ -z "${SP1_AGGREGATION_PROGRAM_VKEY:-}" ]]; then
                        log_error "SP1 guest data is missing"
                        return 1
                    fi

                    BROADCAST=true docker compose -f docker-compose-protocol.yml --profile sp1-verifier-setup up
                    touch "$DEPLOYMENT_DIR/sp1_verifier_setup.lock"
                fi
            fi

            if [[ ! -f "$DEPLOYMENT_DIR/risc0_verifier_setup.lock" ]]; then
                local running_risc0
                if [[ "$force" == "true" ]]; then
                    running_risc0=0  # default: deploy RISC0
                else
                    echo
                    echo "╔══════════════════════════════════════════════════════════════╗"
                    echo "  ⚠️ Running RISC0?                                             "
                    echo "║══════════════════════════════════════════════════════════════║"
                    echo "║  0 for Deploy RISC0                                          ║"
                    echo "║  1 for Skip RISC0                                            ║"
                    echo "║ [default: 0]                                                 ║"
                    echo "╚══════════════════════════════════════════════════════════════╝"
                    echo
                    read -p "Enter choice [0]: " running_risc0
                    running_risc0=${running_risc0:-0}
                fi

                if [[ "$running_risc0" == "0" ]]; then
                    retrieve_guest_data risc0
                    
                    if [[ -z "${RISC0_BLOCK_PROVING_IMAGE_ID:-}" ]] || [[ -z "${RISC0_AGGREGATION_IMAGE_ID:-}" ]]; then
                        log_error "RISC0 guest data is missing"
                        return 1
                    fi

                    BROADCAST=true docker compose -f docker-compose-protocol.yml --profile risc0-verifier-setup up
                    touch "$DEPLOYMENT_DIR/risc0_verifier_setup.lock"
                fi
            fi

            log_info "Generating prover env vars..."
            echo
            echo ">>>>>>"
            echo "export GROTH16_VERIFIER_ADDRESS=$SHASTA_RISC0_GROTH16_VERIFIER"
            echo "export SP1_VERIFIER_ADDRESS=$SHASTA_SUCCINCT_VERIFIER"
            echo ">>>>>>"
            echo
            log_success "Prover env vars generated successfully"
            log_info "Please copy and paste them when you start the provers"
        fi
    fi
}

# Setup SP1 verifier
setup_sp1_verifier() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Running SP1?                                               "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║  0 for Deploy SP1                                            ║"
    echo "║  1 for Skip SP1                                              ║"
    echo "║ [default: 0]                                                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -p "Enter choice [0]: " running_sp1
    running_sp1=${running_sp1:-0}

    if [[ "$running_sp1" == "0" ]]; then
        retrieve_guest_data sp1
        
        if [[ -z "${SP1_BLOCK_PROVING_PROGRAM_VKEY:-}" ]] || [[ -z "${SP1_AGGREGATION_PROGRAM_VKEY:-}" ]]; then
            log_error "SP1 guest data is missing"
            return 1
        fi

        BROADCAST=true docker compose -f docker-compose-protocol.yml --profile sp1-verifier-setup up
    fi
}

# Setup RISC0 verifier
setup_risc0_verifier() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Running RISC0?                                             "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║  0 for Deploy RISC0                                          ║"
    echo "║  1 for Skip RISC0                                            ║"
    echo "║ [default: 0]                                                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -p "Enter choice [0]: " running_risc0
    running_risc0=${running_risc0:-0}

    if [[ "$running_risc0" == "0" ]]; then
        retrieve_guest_data risc0
        
        if [[ -z "${RISC0_BLOCK_PROVING_IMAGE_ID:-}" ]] || [[ -z "${RISC0_AGGREGATION_IMAGE_ID:-}" ]]; then
            log_error "RISC0 guest data is missing"
            return 1
        fi

        BROADCAST=true docker compose -f docker-compose-protocol.yml --profile risc0-verifier-setup up
    fi
}

# Deposit bond for proposer (devnet only)
deposit_bond() {
    local mode="$1"
    
    log_info "Depositing bond..."

    local should_deposit_bond
    if [[ -z "${deposit_bond:-}" ]]; then
        if [[ "$force" == "true" ]]; then
            should_deposit_bond=0  # default: deposit bond
        else
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "  ⚠️ Deposit bond?                                             "
            echo "║══════════════════════════════════════════════════════════════║"
            echo "║  0 for Deposit bond                                          ║"
            echo "║  1 for Skip bond                                             ║"
            echo "║ [default: 0]                                                 ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo
            read -p "Enter choice [true]: " should_deposit_bond
            should_deposit_bond=${should_deposit_bond:-0}
        fi
    else
        should_deposit_bond=$deposit_bond
    fi

    if [[ "$should_deposit_bond" == "0" || "$should_deposit_bond" == "true" ]]; then
        local bond_amount_eth
        if [[ -z "${bond_amount:-}" ]]; then
            if [[ "$force" == "true" ]]; then
                bond_amount_eth=1000  # default: 1000 ETH
            else
                echo
                echo "╔══════════════════════════════════════════════════════════════╗"
                echo "║ Enter bond amount (in ETH, default: 1000)                    ║"
                echo "╚══════════════════════════════════════════════════════════════╝"
                echo
                read -p "Enter amount [1000]: " bond_amount_eth
                bond_amount_eth=${bond_amount_eth:-1000}
            fi
        else
            bond_amount_eth=$bond_amount
        fi

        local bond_amount_wei
        bond_amount_wei=$(echo "$bond_amount_eth * 1000000000000000000" | bc | cut -d. -f1)
        export BOND_AMOUNT="$bond_amount_wei"

        log_info "Depositing bond of $bond_amount_eth ETH..."
        
        local exit_status=0
        local temp_output="/tmp/surge_bond_deposit_output_$$"
        
        if [[ "$mode" == "debug" ]]; then
            docker compose -f docker-compose-protocol.yml --profile bond-deposit up 2>&1 | tee "$temp_output"
            exit_status=${PIPESTATUS[0]}
        else
            docker compose -f docker-compose-protocol.yml --profile bond-deposit up >"$temp_output" 2>&1 &
            local deposit_pid=$!
            
            show_progress $deposit_pid "Depositing bond..."
            
            wait $deposit_pid
            exit_status=$?
        fi
        
        if [[ $exit_status -eq 0 ]]; then
            log_success "Bond deposited successfully"
            return 0
        else
            log_error "Failed to deposit bond (exit code: $exit_status)"
            if [[ -f "$temp_output" ]]; then
                log_error "Bond deposit output saved in: $temp_output"
            fi
            return 1
        fi
    else
        log_info "Skipping bond deposit"
        return 0
    fi
}

# Wait for L2 chain to start producing blocks
wait_for_l2_blocks() {
    log_info "Waiting for L2 chain to start producing blocks..."

    local l2_rpc="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
    # Ensure we use localhost for host-based calls
    l2_rpc=$(echo "$l2_rpc" | sed 's/host\.docker\.internal/localhost/g')

    local waited=0
    local max_wait=384  # Entire epoch duration
    while [[ $waited -lt $max_wait ]]; do
        local block_number
        block_number=$(cast block-number --rpc-url "$l2_rpc" 2>/dev/null || echo "0")
        if [[ "$block_number" -gt 0 ]]; then
            log_success "L2 is producing blocks (current block: $block_number)"
            return 0
        fi
        sleep 5
        waited=$((waited + 5))
        if (( waited % 30 == 0 )); then
            log_info "Still waiting for L2 blocks... (${waited}s elapsed)"
        fi
    done

    log_error "L2 did not start producing blocks within ${max_wait}s"
    return 1
}

# Deploy L2 smart contracts
deploy_l2() {
    # Check if deployment is already completed
    if [[ -f "$L2_LOCK_FILE" ]]; then
        log_warning "Surge L2 deployment already completed ($L2_LOCK_FILE exists)"
        log_info "Deployment will be skipped..."
        return 0
    else
        # Wait for L2 to be ready before deploying contracts
        if ! wait_for_l2_blocks; then
            log_error "Cannot deploy L2 contracts: L2 chain is not producing blocks"
            return 1
        fi

        log_info "Deploying L2 smart contracts..."

        local exit_status=0
        local temp_output="/tmp/surge_l2_deploy_output_$$"

        # Start L2 deployer in detached mode, then wait for it to finish
        BROADCAST=true docker compose --profile l2-deployer up -d >"$temp_output" 2>&1 &
        local deploy_pid=$!

        show_progress $deploy_pid "Deploying L2 contracts..."

        wait $deploy_pid
        exit_status=$?

        if [[ $exit_status -ne 0 ]]; then
            log_error "Failed to start L2 deployer container (exit code: $exit_status)"
            if [[ -f "$temp_output" ]]; then
                log_error "Output saved in: $temp_output"
            fi
            return 1
        fi

        # Wait for the deployer container to finish (up to 600s)
        # The deployer runs forge script --broadcast which needs L2 blocks to confirm txs
        log_info "Waiting for L2 deployer to complete..."
        local waited=0
        local max_wait=600
        while [[ $waited -lt $max_wait ]]; do
            # Check if the deployment artifact appeared on the host (most reliable signal)
            if [[ -f "$DEPLOYMENT_DIR/setup_l2.json" ]]; then
                log_success "L2 deployment artifact detected"
                break
            fi

            local status
            status=$(docker inspect surge-l2-deployer --format '{{.State.Status}}' 2>/dev/null || echo "not found")
            if [[ "$status" == "exited" ]]; then
                local code
                code=$(docker inspect surge-l2-deployer --format '{{.State.ExitCode}}' 2>/dev/null || echo "1")
                if [[ "$code" == "0" ]]; then
                    break
                else
                    log_error "L2 deployer exited with code $code"
                    docker logs surge-l2-deployer 2>&1 | tail -20 >&2
                    return 1
                fi
            fi
            sleep 5
            waited=$((waited + 5))
            if (( waited % 60 == 0 )); then
                log_info "Still waiting for L2 deployer... (${waited}s / ${max_wait}s)"
            fi
        done

        if [[ $waited -ge $max_wait ]]; then
            log_error "L2 deployer timed out after ${max_wait}s"
            log_error "Last deployer logs:"
            docker logs surge-l2-deployer 2>&1 | tail -20 >&2
            return 1
        fi

        # Verify the deployment artifact was produced
        if [[ -f "$DEPLOYMENT_DIR/setup_l2.json" ]]; then
            log_success "L2 smart contracts deployed successfully"
            touch "$L2_LOCK_FILE"
        else
            log_warning "L2 deployer exited 0 but setup_l2.json not found, continuing..."
        fi

        return 0
    fi
}

# Prompt for stack option selection
prompt_stack_option_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║ Enter L2 stack option:                                       ║" >&2
    echo "║ 1 for driver only                                            ║" >&2
    echo "║ 2 for driver + proposer                                      ║" >&2
    echo "║ 3 for driver + proposer + spammer                            ║" >&2
    echo "║ 4 for driver + proposer + prover + spammer                   ║" >&2
    echo "║ 5 for all except spammer                                     ║" >&2
    echo "║ 6 for all components                                         ║" >&2
    echo "║ [default: all]                                               ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [6]: " choice
    choice=${choice:-6}
    echo $choice
}

# Prompt for relayers selection
prompt_relayers_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️ Start relayers?                                            " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  0 for Deploy relayers                                       ║" >&2
    echo "║  1 for Skip relayers                                         ║" >&2
    echo "║ [default: 0]                                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo $choice
}

# Prompt for execution mode selection
prompt_mode_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select execution mode:                                     " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  0 for silence (default)                                     ║" >&2
    echo "║  1 for debug                                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo $choice
}

# Start L2 stack with specified configuration
start_l2_stack() {
    local stack_option="$1"
    
    log_info "Starting L2 stack..."
    
    local compose_cmd="docker compose"
    local exit_status=0
    local temp_output="/tmp/surge_l2_stack_output_$$"
    
    case "$stack_option" in
        1)
            log_info "Starting driver only"
            $compose_cmd --profile driver --profile blockscout up -d  >"$temp_output" 2>&1 &
            ;;
        2)
            log_info "Starting driver + proposer"
            $compose_cmd --profile catalyst --profile blockscout up -d  >"$temp_output" 2>&1 &
            ;;
        3)
            log_info "Starting driver + proposer + spammer"
            $compose_cmd --profile catalyst --profile spammer --profile blockscout up -d  >"$temp_output" 2>&1 &
            ;;
        4)
            log_info "Starting driver + proposer + prover (spammer deferred until after L2 deploy)"
            $compose_cmd --profile catalyst --profile prover --profile blockscout up -d  >"$temp_output" 2>&1 &
            ;;
        5)
            log_info "Starting all except spammer"
            $compose_cmd --profile driver --profile catalyst --profile prover --profile blockscout up -d  >"$temp_output" 2>&1 &
            ;;
        *)
            log_info "Starting all components (spammer deferred until after L2 deploy)"
            $compose_cmd --profile driver --profile catalyst --profile prover --profile blockscout up -d  >"$temp_output" 2>&1 &
            ;;
    esac
    
    local docker_pid=$!
    show_progress $docker_pid "Starting L2 stack components..."
    
    wait $docker_pid
    exit_status=$?
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "L2 stack started successfully"
        return 0
    else
        log_error "Failed to start L2 stack (exit code: $exit_status)"
        if [[ -f "$temp_output" ]]; then
            log_error "Docker output saved in: $temp_output"
        fi
        return 1
    fi
}

# Start relayers and related services
start_relayers() {
    local should_start_relayers="$1"
    local environment="$2"
    
    if [[ "$should_start_relayers" == "1" ]]; then
        log_info "Skipping relayers as requested"
        return 0
    fi
    
    # Deploy L2 SCs first for devnet environment
    if [[ "$environment" == "1" || "$environment" == "devnet" ]]; then
        if ! deploy_l2; then
            log_error "Failed to deploy L2 contracts, cannot start relayers"
            return 1
        fi
    fi
    
    log_info "Starting relayers..."
    
    # Start relayer initialization
    log_info "Starting init to prepare DB and queues..."
    if ! docker compose -f docker-compose-relayer.yml --profile relayer-init up -d >/dev/null 2>&1; then
        log_error "Failed to start relayer initialization"
        return 1
    fi
    
    # Wait for services to initialize
    log_info "Waiting for services to initialize..."
    sleep 20
    
    # Execute migrations
    log_info "Executing DB migrations..."
    if ! docker compose -f docker-compose-relayer.yml --profile relayer-migrations up >/dev/null 2>&1; then
        log_error "Failed to execute DB migrations"
        return 1
    fi
    
    # Start relayer services
    log_info "Starting relayer services..."
    if ! docker compose -f docker-compose-relayer.yml --profile relayer-l1 --profile relayer-l2 --profile relayer-api up -d >/dev/null 2>&1; then
        log_error "Failed to start relayer services"
        return 1
    fi
    
    log_success "Relayers started successfully"
    
    # Prepare Bridge UI Configs
    if ! prepare_bridge_ui_configs; then
        log_warning "Failed to prepare bridge UI configs"
    fi
    
    # Start Bridge UI
    log_info "Starting Bridge UI..."
    if ! docker compose -f docker-compose-relayer.yml --profile bridge-ui up -d --build >/dev/null 2>&1; then
        log_warning "Failed to start Bridge UI"
    else
        log_success "Bridge UI started successfully"
    fi
    
    return 0
}

# Prepare Bridge UI configuration files
prepare_bridge_ui_configs() {
    log_info "Preparing Bridge UI configs..."
    
    # Ensure configs directory exists
    if [[ ! -d "$CONFIGS_DIR" ]]; then
        mkdir -p "$CONFIGS_DIR"
    fi
    
    # Use external endpoints for UI (accessible from browser)
    local l1_rpc_ui="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-http://localhost:32003}}"
    local l2_rpc_ui="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-http://localhost:8547}}"
    local l1_explorer_ui="${L1_EXPLORER:-http://localhost:36005}"
    local l2_explorer_ui="${L2_EXPLORER:-http://localhost:3001}"
    
    # Generate configuredBridges.json
    cat > "$CONFIGS_DIR/configuredBridges.json" << EOF
{
  "configuredBridges": [
    {
      "source": "$L1_CHAIN_ID",
      "destination": "$L2_CHAIN_ID",
      "addresses": {
        "bridgeAddress": "$SHASTA_BRIDGE",
        "erc20VaultAddress": "$SHASTA_ERC20_VAULT",
        "erc721VaultAddress": "$SHASTA_ERC721_VAULT",
        "erc1155VaultAddress": "$SHASTA_ERC1155_VAULT",
        "crossChainSyncAddress": "",
        "signalServiceAddress": "$SHASTA_SIGNAL_SERVICE",
        "quotaManagerAddress": ""
      }
    },
    {
      "source": "$L2_CHAIN_ID",
      "destination": "$L1_CHAIN_ID",
      "addresses": {
        "bridgeAddress": "$L2_BRIDGE",
        "erc20VaultAddress": "$L2_ERC20_VAULT",
        "erc721VaultAddress": "$L2_ERC721_VAULT",
        "erc1155VaultAddress": "$L2_ERC1155_VAULT",
        "crossChainSyncAddress": "",
        "signalServiceAddress": "$L2_SIGNAL_SERVICE",
        "quotaManagerAddress": ""
      }
    }
  ]
}
EOF

    # Generate configuredChains.json
    cat > "$CONFIGS_DIR/configuredChains.json" << EOF
{
  "configuredChains": [
    {
      "$L1_CHAIN_ID": {
        "name": "L1",
        "type": "L1",
        "icon": "https://cdn.worldvectorlogo.com/logos/ethereum-eth.svg",
        "rpcUrls": {
          "default": {
            "http": ["$l1_rpc_ui"]
          }
        },
        "nativeCurrency": {
          "name": "ETH",
          "symbol": "ETH",
          "decimals": 18
        },
        "blockExplorers": {
          "default": {
            "name": "L1 Explorer",
            "url": "$l1_explorer_ui"
          }
        }
      }
    },
    {
      "$L2_CHAIN_ID": {
        "name": "Surge",
        "type": "L2",
        "icon": "https://cdn.worldvectorlogo.com/logos/ethereum-eth.svg",
        "rpcUrls": {
          "default": {
            "http": ["$l2_rpc_ui"]
          }
        },
        "nativeCurrency": {
          "name": "ETH",
          "symbol": "ETH",
          "decimals": 18
        },
        "blockExplorers": {
          "default": {
            "name": "Surge Explorer",
            "url": "$l2_explorer_ui"
          }
        }
      }
    }
  ]
}
EOF

    # Generate configuredRelayer.json
    cat > "$CONFIGS_DIR/configuredRelayer.json" << EOF
{
  "configuredRelayer": [
    {
      "chainIds": [$L1_CHAIN_ID, $L2_CHAIN_ID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAIN_ID, $L1_CHAIN_ID],
      "url": "$L2_RELAYER"
    }
  ]
}
EOF

    # Generate configuredEventIndexer.json
    cat > "$CONFIGS_DIR/configuredEventIndexer.json" << EOF
{
  "configuredEventIndexer": [
    {
      "chainIds": [$L1_CHAIN_ID, $L2_CHAIN_ID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAIN_ID, $L1_CHAIN_ID],
      "url": "$L2_RELAYER"
    }
  ]
}
EOF

    # Generate configuredCustomTokens.json (empty array for now)
    cat > "$CONFIGS_DIR/configuredCustomTokens.json" << EOF
[]
EOF

    log_success "Bridge UI configs generated successfully"
}

# Verify RPC endpoints
verify_rpc_endpoints() {
    log_info "Verifying RPC endpoints..."
    
    local all_healthy=true
    
    # Verify L1 RPC (use external endpoint for host-based verification)
    local l1_endpoint="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-}}"
    if [[ -n "$l1_endpoint" ]]; then
        if test_rpc_connection "$l1_endpoint"; then
            log_success "L1 RPC endpoint is accessible: $l1_endpoint"
        else
            log_error "L1 RPC endpoint is not accessible: $l1_endpoint"
            all_healthy=false
        fi
    fi
    
    # Verify L2 RPC (use external endpoint for host-based verification)
    local l2_endpoint="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-}}"
    if [[ -n "$l2_endpoint" ]]; then
        if test_rpc_connection "$l2_endpoint"; then
            log_success "L2 RPC endpoint is accessible: $l2_endpoint"
        else
            log_error "L2 RPC endpoint is not accessible: $l2_endpoint"
            all_healthy=false
        fi
    fi
    
    if [[ "$all_healthy" == true ]]; then
        log_success "All RPC endpoints verified successfully"
        return 0
    else
        log_warning "Some RPC endpoints are not accessible"
        return 1
    fi
}

# Display deployment summary
display_deployment_summary() {
    echo
    log_info "Deployment Summary:"
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Surge Full Stack deployment completed successfully!         ║"
    echo "║                                                              ║"
    echo "║  Key Service Endpoints:                                      ║"
    echo "   • L1 RPC:        ${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-N/A}}                              "
    echo "   • L1 Explorer:   ${L1_EXPLORER:-N/A}                         "
    echo "   • L2 RPC:        ${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-N/A}}                             "
    echo "   • L2 Explorer:   ${L2_EXPLORER:-N/A}                        "
    echo "   • L1 Relayer:    ${L1_RELAYER:-N/A}                         "
    echo "   • L2 Relayer:    ${L2_RELAYER:-N/A}                         "
    
    if [[ -n "${DEPLOYMENT_ADDRESS:-}" ]]; then
        echo "║                                                              ║"
        echo "║  Deployment Account:                                         ║"
        printf "   • Address:      %-42s \n" "$DEPLOYMENT_ADDRESS"
        printf "   • Balance:       %-20s ETH                         \n" "${DEPLOYMENT_BALANCE:-0}"
    fi
    
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
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

    # If verify-key-only is set, just verify the key and exit (WIP due to using existing chain)
    # if [[ "$verify_key_only" == "true" ]]; then
    #     if [[ -z "$deployment_key" ]] || [[ -z "$l1_rpc_url" ]]; then
    #         log_error "Both --deployment-key and --l1-rpc-url are required for --verify-key-only"
    #         exit 1
    #     fi
    #     verify_private_key_on_chain "$deployment_key" "$l1_rpc_url" "provided chain"
    #     exit $?
    # fi
    
    # Step 1: Environment Selection
    local env_choice
    if [[ -z "${environment:-}" ]]; then
        if [[ "$force" == "true" ]]; then
            env_choice=1  # default: devnet
        else
            env_choice=$(prompt_environment_selection)
        fi
    else
        case "$environment" in
            1|"devnet") env_choice=1 ;;
            2|"staging") env_choice=2 ;;
            3|"testnet") env_choice=3 ;;
            *) log_error "Invalid environment: $environment"; exit 1 ;;
        esac
    fi
    
    # Map env_choice to name
    local env_name
    case "$env_choice" in
        1|"devnet") env_name="devnet" ;;
        2|"staging") env_name="staging" ;;
        3|"testnet") env_name="testnet" ;;
        *) log_error "Invalid environment choice: $env_choice"; exit 1 ;;
    esac

    # Load environment file
    if ! check_env_file "$env_name"; then
        log_error "Failed to load environment file, please ensure the .env file is present"
        exit 1
    fi
    
    # Get deployment choice (local/remote)
    local deployment_choice
    if [[ -z "${deployment:-}" ]]; then
        if [[ "$force" == "true" ]]; then
            deployment_choice=0  # default: local
        else
            deployment_choice=$(prompt_deployment_selection)
        fi
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
            if [[ "$force" == "true" ]]; then
                deploy_devnet_choice=0  # default: deploy new devnet
            else
                deploy_devnet_choice=$(prompt_l1_deployment_mode)
            fi
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
                if [[ "$force" == "true" ]]; then
                    mode_choice="debug"  # default: debug for visibility
                else
                    mode_choice=$(prompt_mode_selection)
                fi
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
                if [[ "$force" == "true" ]]; then
                    mode_choice="debug"  # default: debug for visibility
                else
                    mode_choice=$(prompt_mode_selection)
                fi
            else
                case "$mode" in
                    0|"silence"|"silent") mode_choice="silence" ;;
                    1|"debug") mode_choice="debug" ;;
                    *) mode_choice="$mode" ;;
                esac
            fi

            slow_mode=true

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

            # log_warning "Using existing chain is still a work in progress"
            # exit 0
        fi
    fi
    
    # Step 3: L1 Protocol Deployment (ONLY for devnet)
    if [[ "$env_choice" == "1" || "$env_choice" == "devnet" ]]; then

        # Deploy L1 contracts
        local mock_proof
        if [[ "$force" == "true" ]]; then
            mock_proof=0  # default: mock prover
        else
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "  ⚠️ Using mock prover?                                         "
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

        # Deploy Pacaya contracts
        if ! deploy_pacaya_contracts "$mode_choice" $slow_mode; then
            log_error "Failed to deploy Pacaya smart contracts"
            exit 1
        fi

        # Extract L1 deployment results
        if ! extract_l1_deployment_results; then
            log_error "Failed to extract L1 deployment results"
            exit 1
        fi

        # Deploy Provers (optional) - must be after Pacaya contracts for PACAYA_TAIKO
        if ! deploy_provers $mock_proof; then
            log_warning "Prover deployment had issues, but continuing..."
        fi

        # Deposit bond (optional)
        # if ! deposit_bond "$mode_choice"; then
        #     log_warning "Bond deposit had issues, but continuing..."
        # fi

        # Accept ownership
        # if ! accept_ownership "$mode_choice"; then
        #     log_error "Failed to accept ownership"
        #     exit 1
        # fi


    fi
    
    # Step 4: L2 Stack Deployment (ALL environments)
    local stack_choice
    if [[ -z "${stack_option:-}" ]]; then
        if [[ "$force" == "true" ]]; then
            stack_choice=6  # default: all components
        else
            stack_choice=$(prompt_stack_option_selection)
        fi
    else
        stack_choice=$stack_option
    fi
    
    if ! start_l2_stack "$stack_choice"; then
        log_error "Failed to start L2 stack"
        exit 1
    fi

    # Switch fork
    if ! switch_fork "$mode_choice"; then
        log_error "Failed to switch fork"
        exit 1
    fi

    # Step 5: Start Relayers (optional)
    local relayers_choice
    if [[ -z "${start_relayers:-}" ]]; then
        if [[ "$force" == "true" ]]; then
            relayers_choice=0  # default: deploy relayers
        else
            relayers_choice=$(prompt_relayers_selection)
        fi
    else
        relayers_choice=$start_relayers
    fi
    
    if ! start_relayers "$relayers_choice" "$env_choice"; then
        log_warning "Relayer startup had issues, but continuing..."
    fi
    
    # Step 5b: Start spammer now that L2 deploy is done (if stack option included it)
    if [[ "$stack_choice" == "3" || "$stack_choice" == "4" || "$stack_choice" == "6" || -z "$stack_choice" ]]; then
        log_info "Starting tx spammer..."
        docker compose --profile spammer up -d tx-spammer >/dev/null 2>&1 || true
    fi
    
    # Step 6: Verification
    verify_rpc_endpoints
    
    # Step 7: Display Summary
    display_deployment_summary
    
    log_success "Surge Full Stack deployment complete!"
}

# Run main function
main "$@"

