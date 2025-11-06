#!/bin/bash
set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly ENV_FILE=".env"
readonly DEPLOYMENT_DIR="deployment"
readonly CONFIGS_DIR="configs"
readonly L1_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/deploy_l1.json"
readonly L1_LOCK_FILE="$DEPLOYMENT_DIR/deploy_l1.lock"
readonly PROPOSER_WRAPPER_FILE="$DEPLOYMENT_DIR/proposer_wrappers.json"
readonly L2_DEPLOYMENT_FILE="$DEPLOYMENT_DIR/setup_l2.json"
readonly BLOCKSCOUT_FILE="src/blockscout/blockscout_launcher.star"
readonly BACKUP_FILE="${BLOCKSCOUT_FILE}.bak"
readonly NETWORK_PARAMS="network_params.yaml"
readonly ENCLAVE_NAME="surge-devnet"
readonly SURGE_ETHEREUM_PACKAGE_DIR="surge-ethereum-package"

# Default values for command line arguments
environment=""
deploy_devnet=""
deployment=""
l1_rpc_url=""
l1_beacon_rpc_url=""
l1_explorer_url=""
deployment_key=""
stack_option=""
timelocked_owner=""
running_provers=""
deposit_bond=""
bond_amount=""
start_relayers=""
mode=""
force=""
verify_key_only=""

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
    echo "  --environment ENV       Surge environment (devnet|staging|testnet) [REQUIRED]"
    echo "  --deploy-devnet BOOL     Deploy new devnet or use existing chain (devnet only, true|false)"
    echo "  --deployment TYPE        Deployment type (local|remote)"
    echo "  --l1-rpc-url URL        L1 RPC URL (for existing chain)"
    echo "  --l1-beacon-rpc-url URL L1 Beacon RPC URL (for existing chain)"
    echo "  --l1-explorer-url URL   L1 Explorer URL (optional)"
    echo "  --deployment-key KEY    Private key for contract deployment (will be verified)"
    echo "  --stack-option NUM      L2 stack option (1-6, see details below)"
    echo "  --timelocked-owner BOOL Use timelocked owner (devnet only, true|false)"
    echo "  --running-provers BOOL  Setup provers (devnet only, true|false)"
    echo "  --deposit-bond BOOL     Deposit bond (devnet only, true|false)"
    echo "  --bond-amount NUM       Bond amount in ETH (default: 1000)"
    echo "  --start-relayers BOOL   Start relayers (true|false)"
    echo "  --mode MODE             Execution mode (silence|debug)"
    echo "  --verify-key-only       Only verify private key, don't deploy"
    echo "  -f, --force            Skip confirmation prompts"
    echo "  -h, --help             Show this help message"
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
    echo "  $0 --environment testnet --l1-rpc-url https://... --deployment-key 0x..."
    echo "  $0 --environment devnet --deploy-devnet false --l1-rpc-url http://localhost:8545"
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
            --l1-rpc-url)
                l1_rpc_url="$2"
                shift 2
                ;;
            --l1-beacon-rpc-url)
                l1_beacon_rpc_url="$2"
                shift 2
                ;;
            --l1-explorer-url)
                l1_explorer_url="$2"
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
            --timelocked-owner)
                timelocked_owner="$2"
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
            --verify-key-only)
                verify_key_only="true"
                shift
                ;;
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
    local required_cmds=("docker" "git" "jq" "curl" "bc")
    local missing_cmds=()
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    
    # Check for cast (Foundry) or node for address derivation
    local has_cast=false
    local has_node=false
    if command -v cast >/dev/null 2>&1; then
        has_cast=true
    fi
    if command -v node >/dev/null 2>&1; then
        has_node=true
    fi
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        log_error "Please install them first"
        return 1
    fi
    
    if [[ "$has_cast" == false && "$has_node" == false ]]; then
        log_warning "Neither 'cast' (Foundry) nor 'node' found"
        log_warning "Private key address derivation may not work"
        log_warning "Install Foundry (cast) or Node.js for full functionality"
    fi
    
    # Create required directories
    for dir in "$DEPLOYMENT_DIR" "$CONFIGS_DIR"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating $dir directory..."
            mkdir -p "$dir"
        fi
    done
    
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
    
    # Specifically check and initialize surge-ethereum-package if needed
    # Note: The submodule name in .gitmodules is "surge-ethereum-packages" but path is "surge-ethereum-package"
    if [[ ! -d "$SURGE_ETHEREUM_PACKAGE_DIR" ]]; then
        log_info "Attempting to initialize surge-ethereum-package submodule..."
        # Try with the path
        if git submodule update --init "$SURGE_ETHEREUM_PACKAGE_DIR" >/dev/null 2>&1; then
            log_success "surge-ethereum-package submodule initialized"
        else
            # Try with the actual submodule name from .gitmodules
            if git submodule update --init surge-ethereum-packages >/dev/null 2>&1; then
                log_success "surge-ethereum-package submodule initialized (via name)"
            else
                log_warning "Could not initialize surge-ethereum-package submodule"
                log_info "Will attempt to use current directory if Kurtosis files are present"
            fi
        fi
    fi
}

# Ensure surge-ethereum-package submodule exists or use current directory
ensure_surge_ethereum_package() {
    log_info "Checking surge-ethereum-package submodule..."
    
    if [[ ! -d "$SURGE_ETHEREUM_PACKAGE_DIR" ]]; then
        log_warning "surge-ethereum-package submodule not found, checking current directory..."
        # Fall back to current directory approach (like original deploy-surge-devnet-l1.sh)
        if [[ -f "main.star" ]] || [[ -f "network_params.yaml" ]]; then
            log_info "Using current directory for Kurtosis setup"
            export SURGE_ETHEREUM_PACKAGE_DIR="."
            return 0
        fi
        log_error "surge-ethereum-package submodule not found and no Kurtosis files in current directory"
        log_error "Please run: git submodule update --init --recursive"
        log_error "Or ensure Kurtosis setup files are in the current directory"
        return 1
    fi
    
    if [[ ! -f "$SURGE_ETHEREUM_PACKAGE_DIR/main.star" ]] && [[ "$SURGE_ETHEREUM_PACKAGE_DIR" != "." ]]; then
        log_error "Invalid surge-ethereum-package directory"
        log_error "Expected Kurtosis main.star file not found"
        return 1
    fi
    
    log_success "surge-ethereum-package verified"
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

# Derive address from private key using node
derive_address_from_key_node() {
    local private_key="$1"
    
    if ! command -v node >/dev/null 2>&1; then
        return 1
    fi
    
    local script="const { ethers } = require('ethers'); const wallet = new ethers.Wallet('$private_key'); console.log(wallet.address);"
    
    # Try to use ethers if available
    local address
    if address=$(node -e "$script" 2>/dev/null); then
        echo "$address"
        return 0
    fi
    
    # Fallback: try using crypto built-in
    local fallback_script="
    const crypto = require('crypto');
    const privateKey = '$private_key';
    if (!privateKey.startsWith('0x')) { process.exit(1); }
    const privKey = Buffer.from(privateKey.slice(2), 'hex');
    const secp256k1 = require('secp256k1');
    const pubKey = secp256k1.publicKeyCreate(privKey, false).slice(1);
    const hash = crypto.createHash('sha256').update(pubKey).digest();
    const ripemd160 = require('ripemd160');
    const address = '0x' + crypto.createHash('sha256').update(hash).digest().slice(12).toString('hex');
    console.log(address);
    "
    
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
    
    # Try node with ethers
    if address=$(derive_address_from_key_node "$private_key"); then
        echo "$address"
        return 0
    fi
    
    # Last resort: use docker with foundry
    if docker run --rm -i foundry:latest cast wallet address "$private_key" 2>/dev/null | head -n1; then
        return 0
    fi
    
    log_error "Unable to derive address from private key"
    log_error "Please install Foundry (cast) or ensure Node.js with ethers is available"
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

# Get account balance
get_account_balance() {
    local address="$1"
    local rpc_url="$2"
    
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"eth_getBalance\",\"params\":[\"$address\",\"latest\"]}" \
        "$rpc_url" 2>/dev/null)
    
    if echo "$response" | jq -e '.result' >/dev/null 2>&1; then
        echo "$response" | jq -r '.result'
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

# Convert wei to ETH
wei_to_eth() {
    local wei="$1"
    
    # Remove 0x prefix if present
    wei="${wei#0x}"
    
    # Use Python or bc for precision
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "print('{:.5f}'.format(int('$wei', 16) / 1000000000000000000))" 2>/dev/null || echo "0"
    elif command -v bc >/dev/null 2>&1; then
        # Convert hex to decimal using printf if it's hex
        local wei_decimal
        if [[ "$wei" =~ ^[0-9a-fA-F]+$ ]] && [[ ${#wei} -gt 10 ]]; then
            wei_decimal=$(printf "%d" "0x$wei" 2>/dev/null || echo "$wei")
        else
            wei_decimal="$wei"
        fi
        echo "scale=5; $wei_decimal / 1000000000000000000" | bc -l 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Check sufficient balance
check_sufficient_balance() {
    local balance="$1"
    local min_balance="$2"
    
    # Remove 0x prefix if present
    balance="${balance#0x}"
    min_balance="${min_balance#0x}"
    
    # Compare hex values directly
    if [[ $(printf "%d" "0x${balance^^}") -ge $(printf "%d" "0x${min_balance^^}") ]]; then
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
    if ! validate_private_key_format "$private_key"; then
        log_error "Invalid private key format"
        return 1
    fi
    
    # 2. Derive address from private key
    log_info "Deriving address from private key..."
    local address
    if ! address=$(derive_address_from_key "$private_key"); then
        log_error "Failed to derive address from private key"
        return 1
    fi
    
    log_info "Derived address: $address"
    
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
    if ! balance=$(get_account_balance "$address" "$rpc_url"); then
        log_error "Failed to query account balance"
        return 1
    fi
    
    local balance_eth
    balance_eth=$(wei_to_eth "$balance")
    log_info "Account balance: $balance_eth ETH"
    
    # 5. Verify chain ID
    log_info "Verifying chain ID..."
    local chain_id
    if ! chain_id=$(get_chain_id "$rpc_url"); then
        log_error "Failed to get chain ID"
        return 1
    fi
    log_info "Chain ID: $chain_id"
    
    # 6. Check sufficient balance
    local min_balance="0xde0b6b3a7640000"  # 1 ETH in hex
    local has_sufficient_balance=false
    if check_sufficient_balance "$balance" "$min_balance"; then
        has_sufficient_balance=true
    fi
    
    # 7. Display verification summary
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Private Key Verification Summary                           ║"
    echo "║══════════════════════════════════════════════════════════════║"
    printf "║  Address:      %-42s ║\n" "$address"
    printf "║  Balance:      %-20s ETH                        ║\n" "$balance_eth"
    printf "║  Chain ID:     %-42s ║\n" "$chain_id"
    echo "║  RPC Status:   ✓ Connected                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    
    if [[ "$has_sufficient_balance" == false ]]; then
        log_warning "Account balance is low. Deployment may fail."
        log_warning "Current balance: $balance_eth ETH"
        log_warning "Recommended: >= 1 ETH"
        
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
    
    log_success "Private key verified successfully"
    
    # Export address for later use
    export DEPLOYMENT_ADDRESS="$address"
    export DEPLOYMENT_BALANCE="$balance_eth"
    export DEPLOYMENT_CHAIN_ID="$chain_id"
    
    return 0
}

# Prompt for environment selection
prompt_environment_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select which Surge environment to use:                    " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║ 1 for Devnet                                                 ║" >&2
    echo "║ 2 for Staging                                                ║" >&2
    echo "║ 3 for Testnet                                                ║" >&2
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
    echo "║  1 for Use existing chain                                    ║" >&2
    echo "║ [default: Deploy new devnet]                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo $choice
}

# Prompt for existing chain configuration
prompt_for_existing_chain_config() {
    local chain_type="$1"  # "L1" or "chain"
    
    echo
    log_info "Please provide $chain_type configuration:"
    
    # L1 RPC URL
    if [[ -z "$l1_rpc_url" ]]; then
        read -p "Enter L1 RPC URL: " l1_rpc_url_input
        l1_rpc_url="$l1_rpc_url_input"
    fi
    
    if [[ -z "$l1_rpc_url" ]]; then
        log_error "L1 RPC URL is required"
        return 1
    fi
    
    # L1 Beacon RPC URL
    if [[ -z "$l1_beacon_rpc_url" ]]; then
        read -p "Enter L1 Beacon RPC URL (optional, press Enter to skip): " l1_beacon_rpc_url_input
        l1_beacon_rpc_url="$l1_beacon_rpc_url_input"
    fi
    
    # L1 Explorer URL
    if [[ -z "$l1_explorer_url" ]]; then
        read -p "Enter L1 Explorer URL (optional, press Enter to skip): " l1_explorer_url_input
        l1_explorer_url="$l1_explorer_url_input"
    fi
    
    # Deployment private key
    if [[ -z "$deployment_key" ]]; then
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "  ⚠️  Enter private key for contract deployment                 "
        echo "║══════════════════════════════════════════════════════════════║"
        echo "║  This key will be verified on the provided chain             ║"
        echo "║  Format: 0x followed by 64 hexadecimal characters            ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo
        read -sp "Enter private key: " deployment_key_input
        echo
        deployment_key="$deployment_key_input"
    fi
    
    if [[ -z "$deployment_key" ]]; then
        log_error "Deployment private key is required"
        return 1
    fi
    
    # Verify private key on chain
    log_info "Verifying private key on provided chain..."
    if ! verify_private_key_on_chain "$deployment_key" "$l1_rpc_url" "$chain_type"; then
        log_error "Private key verification failed"
        return 1
    fi
    
    # Update environment variables
    export L1_RPC="$l1_rpc_url"
    export L1_BEACON_RPC="$l1_beacon_rpc_url"
    export L1_EXPLORER="$l1_explorer_url"
    export PRIVATE_KEY="$deployment_key"
    export PUBLIC_KEY="$DEPLOYMENT_ADDRESS"
    
    log_success "Chain configuration complete"
    return 0
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

# Configure blockscout for remote access
configure_remote_blockscout() {
    local machine_ip="$1"
    
    if [[ ! -f "$BLOCKSCOUT_FILE" ]]; then
        log_warning "Blockscout configuration file not found: $BLOCKSCOUT_FILE"
        return 0
    fi
    
    log_info "Backing up blockscout configuration..."
    cp "$BLOCKSCOUT_FILE" "$BACKUP_FILE"
    
    log_info "Configuring blockscout for remote access (IP: $machine_ip)..."
    sed -i.tmp "s/else \"localhost:{0}\"/else \"$machine_ip:{0}\"/g" "$BLOCKSCOUT_FILE"
    rm -f "${BLOCKSCOUT_FILE}.tmp"
    
    log_success "Blockscout configured for remote access"
}

# Configure environment URLs
configure_environment_urls() {
    local env_choice="$1"
    local deployment_choice="$2"
    local machine_ip="$3"
    
    case "$env_choice" in
        1|"devnet")
            log_info "Using Devnet Environment"
            
            if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
                if [[ -z "$machine_ip" ]]; then
                    log_error "Could not determine machine IP address"
                    return 1
                fi
                
                export L1_RPC="http://$machine_ip:32003"
                export L1_BEACON_RPC="http://$machine_ip:33001"
                export L1_EXPLORER="http://$machine_ip:36005"
                export L2_RPC="http://$machine_ip:${L2_HTTP_PORT:-8547}"
                export L2_EXPLORER="http://$machine_ip:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
                export L1_RELAYER="http://$machine_ip:4102"
                export L2_RELAYER="http://$machine_ip:4103"
            else
                export L1_RPC="http://localhost:32003"
                export L1_BEACON_RPC="http://localhost:33001"
                export L1_EXPLORER="http://localhost:36005"
                export L2_RPC="http://localhost:${L2_HTTP_PORT:-8547}"
                export L2_EXPLORER="http://localhost:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
                export L1_RELAYER="http://localhost:4102"
                export L2_RELAYER="http://localhost:4103"
            fi
            ;;
        2|"staging")
            log_info "Using Staging Environment"
            # Create docker network if it doesn't exist
            if ! docker network ls | grep -q "surge-network"; then
                docker network create surge-network
            fi
            # URLs should be set from .env file or user input
            ;;
        3|"testnet")
            log_info "Using Testnet Environment"
            # Create docker network if it doesn't exist
            if ! docker network ls | grep -q "surge-network"; then
                docker network create surge-network
            fi
            # URLs should be set from .env file or user input
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
    
    # Check network params file exists (in surge-ethereum-package directory)
    local network_params_path="$SURGE_ETHEREUM_PACKAGE_DIR/$NETWORK_PARAMS"
    if [[ ! -f "$network_params_path" ]] && [[ ! -f "$NETWORK_PARAMS" ]]; then
        log_error "Network parameters file not found: $network_params_path or $NETWORK_PARAMS"
        log_error "Please ensure network_params.yaml exists"
        return 1
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
    local mode="$1"
    
    if [[ "$mode" == "0" || "$mode" == "silence" ]]; then
        mode="silence"
    else
        mode="debug"
    fi

    echo
    log_info "Starting Surge DevNet L1 in $mode mode..."
    echo 
    
    local exit_status=0
    local temp_output="/tmp/surge_devnet_l1_output_$$"
    
    # Determine network params file path
    local network_params_path="$NETWORK_PARAMS"
    if [[ ! -f "$network_params_path" ]] && [[ -f "$SURGE_ETHEREUM_PACKAGE_DIR/$NETWORK_PARAMS" ]]; then
        network_params_path="$SURGE_ETHEREUM_PACKAGE_DIR/$NETWORK_PARAMS"
    fi
    
    # Run kurtosis based on mode
    if [[ "$mode" == "debug" ]]; then
        # Debug mode: run in foreground, capture output for error detection
        kurtosis run --enclave "$ENCLAVE_NAME" "$SURGE_ETHEREUM_PACKAGE_DIR" --args-file "$network_params_path" --production --image-download always --verbosity brief 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        # Silent mode: run in background with progress indicator
        kurtosis run --enclave "$ENCLAVE_NAME" "$SURGE_ETHEREUM_PACKAGE_DIR" --args-file "$network_params_path" --production --image-download always >"$temp_output" 2>&1 &
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
        log_success "Surge DevNet L1 started successfully"
        return 0
    else
        log_error "Failed to start Surge DevNet L1 (exit code: $exit_status)"
        if [[ "$mode" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        log_error "Output saved in: $temp_output"
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
    
    # Ensure surge-ethereum-package is available
    if ! ensure_surge_ethereum_package; then
        log_error "Cannot deploy devnet without surge-ethereum-package submodule"
        return 1
    fi
    
    # Validate environment
    if ! validate_environment_for_devnet; then
        log_error "Environment validation failed"
        return 1
    fi
    
    # Configure blockscout for remote if needed
    if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
        local machine_ip
        machine_ip=$(get_machine_ip)
        
        if [[ -z "$machine_ip" ]]; then
            log_error "Could not determine machine IP address"
            return 1
        fi
        
        configure_remote_blockscout "$machine_ip"
    fi
    
    # Run Kurtosis
    if ! run_kurtosis "$mode"; then
        log_error "Devnet deployment failed"
        return 1
    fi
    
    # Wait a bit for services to start
    log_info "Waiting for services to initialize..."
    sleep 10
    
    # Check health
    local rpc_url="http://localhost:32003"
    local beacon_url="http://localhost:33001"
    if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
        local machine_ip
        machine_ip=$(get_machine_ip)
        rpc_url="http://$machine_ip:32003"
        beacon_url="http://$machine_ip:33001"
    fi
    
    check_l1_health "$rpc_url" "$beacon_url"
    
    # Update environment variables
    export L1_RPC="$rpc_url"
    export L1_BEACON_RPC="$beacon_url"
    export L1_EXPLORER="http://localhost:36005"
    if [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]; then
        local machine_ip
        machine_ip=$(get_machine_ip)
        export L1_EXPLORER="http://$machine_ip:36005"
    fi
    
    log_success "L1 devnet deployed successfully"
    return 0
}

# Cleanup function
cleanup() {
    # Remove lock file if it exists
    if [[ -f "$L1_LOCK_FILE" ]]; then
        log_info "Cleaning up lock file..."
        rm -f "$L1_LOCK_FILE"
    fi
    
    # Clean up backup files
    if [[ -f "$ENV_FILE.bak" ]]; then
        rm -f "$ENV_FILE.bak"
    fi
    
    # Restore blockscout config if backup exists
    if [[ -f "$BACKUP_FILE" ]]; then
        log_info "Restoring original blockscout configuration..."
        mv "$BACKUP_FILE" "$BLOCKSCOUT_FILE"
        log_success "Original configuration restored"
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Generate prover chain spec list JSON
generate_prover_chain_spec() {
    log_info "Generating prover chain spec list json..."

    local genesis_time
    if ! genesis_time=$(curl -s "${L1_BEACON_RPC:-http://localhost:33001}/eth/v1/beacon/genesis" | jq -r '.data.genesis_time' 2>/dev/null); then
        log_warning "Failed to retrieve genesis time, using default value 0"
        genesis_time=0
    fi

    # Generate chain spec list
    cat > "$CONFIGS_DIR/chain_spec_list_default.json" << EOF
[
  {
    "name": "surge_dev_l1",
    "chain_id": $L1_CHAINID,
    "max_spec_id": "CANCUN",
    "hard_forks": {},
    "eip_1559_constants": {
      "base_fee_change_denominator": "0x8",
      "base_fee_max_increase_denominator": "0x8",
      "base_fee_max_decrease_denominator": "0x8",
      "elasticity_multiplier": "0x2"
    },
    "l1_contract": null,
    "l2_contract": null,
    "rpc": "$L1_RPC",
    "beacon_rpc": "$L1_BEACON_RPC",
    "verifier_address_forks": {},
    "genesis_time": $genesis_time,
    "seconds_per_slot": 12,
    "is_taiko": false
  },
  {
    "name": "surge_dev",
    "chain_id": $L2_CHAINID,
    "max_spec_id": "PACAYA",
    "hard_forks": {
        "ONTAKE": {
            "Block": 1
        },
        "PACAYA": {
            "Block": 1
        }
    },
    "eip_1559_constants": {
      "base_fee_change_denominator": "0x8",
      "base_fee_max_increase_denominator": "0x8",
      "base_fee_max_decrease_denominator": "0x8",
      "elasticity_multiplier": "0x2"
    },
    "l1_contract": "$TAIKO_INBOX",
    "l2_contract": "$TAIKO_ANCHOR",
    "rpc": "$L2_RPC",
    "beacon_rpc": null,
    "verifier_address_forks": {
      "ONTAKE": {
        "SGX": "$SGX_RETH_VERIFIER",
        "SGXGETH": "$SGX_GETH_VERIFIER",
        "SP1": "$SP1_RETH_VERIFIER",
        "RISC0": "$RISC0_RETH_VERIFIER"
      }
    },
    "genesis_time": 0,
    "seconds_per_slot": 1,
    "is_taiko": true
  }
]
EOF

    log_success "Prover chain spec list json generated successfully"
    log_info "Saved to: $CONFIGS_DIR/chain_spec_list_default.json"
}

# Generate prover environment variables
generate_prover_env_vars() {
    log_info "Generating prover env vars..."

    # Set SGX_INSTANCE_ID from the JSON file
    local sgx_instance_id="0"
    if [[ -f "$DEPLOYMENT_DIR/sgx_instances.json" ]]; then
        sgx_instance_id=$(cat "$DEPLOYMENT_DIR/sgx_instances.json" | jq -r '.sgx_instance_id // "0"')
    fi

    export SGX_INSTANCE_ID="$sgx_instance_id"

    echo
    echo ">>>>>>"
    echo "export SGX_INSTANCE_ID=$SGX_INSTANCE_ID"
    echo "export SGX_ONTAKE_INSTANCE_ID=${SGX_INSTANCE_ID}"
    echo "export SGX_PACAYA_INSTANCE_ID=${SGX_INSTANCE_ID}"
    echo "export GROTH16_VERIFIER_ADDRESS=$RISC0_GROTH16_VERIFIER"
    echo "export SP1_VERIFIER_ADDRESS=$SUCCINCT_VERIFIER"
    echo ">>>>>>"
    echo

    log_success "Prover env vars generated successfully"
    log_info "Please copy and paste them when you start the provers"
}

# Retrieve guest data from prover endpoints
retrieve_guest_data() {
    local prover_type="$1"
    
    case "$prover_type" in
        sgx_reth)
            if [[ -n "${SGX_RAIKO_HOST:-}" ]]; then
                log_info "Retrieving guest data for SGX RETH - $SGX_RAIKO_HOST"
                export MR_ENCLAVE=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_reth.mr_enclave')
                export MR_SIGNER=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_reth.mr_signer')
                export V3_QUOTE_BYTES=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_reth.quote')
            fi
            ;;
        sgx_geth)
            if [[ -n "${SGX_RAIKO_HOST:-}" ]]; then
                log_info "Retrieving guest data for SGX GETH - $SGX_RAIKO_HOST"
                export MR_ENCLAVE_GETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_geth.mr_enclave')
                export MR_SIGNER_GETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_geth.mr_signer')
                export V3_QUOTE_BYTES_GETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_geth.quote')
            fi
            ;;
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

# Deploy L1 smart contracts (devnet only)
deploy_l1_contracts() {
    local mode="$1"
    
    # Ensure deployment directory exists
    if [[ ! -d "$DEPLOYMENT_DIR" ]]; then
        mkdir -p "$DEPLOYMENT_DIR"
    fi

    # Check if deployment is already completed
    if [[ -f "$L1_DEPLOYMENT_FILE" ]]; then
        local start_new_deployment
        if [[ "$force" == "true" ]]; then
            start_new_deployment="false"
        else
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "  ⚠️  Surge L1 deployment already completed                     "
            echo "  ($L1_DEPLOYMENT_FILE exists)                                  "
            echo "║══════════════════════════════════════════════════════════════║"
            echo "║ Start a new deployment? (true/false) [default: false]        ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo
            read -p "Enter choice [false]: " start_new_deployment
        fi
        start_new_deployment=${start_new_deployment:-false}

        if [[ "$start_new_deployment" == "true" ]]; then
            log_info "Starting a new deployment..."
            rm -f "$DEPLOYMENT_DIR"/*.json
            if command -v ./surge-remover.sh >/dev/null 2>&1; then
                ./surge-remover.sh
            fi
        else
            log_info "Using existing deployment..."
            return 0
        fi
    fi

    # Check if deployment is currently running
    if [[ -f "$L1_LOCK_FILE" ]]; then
        log_error "Surge L1 deployment is already running ($L1_LOCK_FILE exists)"
        log_error "Please wait for it to complete or remove the lock file if the previous deployment failed."
        return 1
    fi

    # Create lock file to indicate deployment is starting
    touch "$L1_LOCK_FILE"

    log_info "Preparing Surge L1 SCs deployment..."

    # Get timelocked owner choice
    local use_timelocked_owner
    if [[ -z "${timelocked_owner:-}" ]]; then
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║ Use timelocked owner? (true/false) [default: false]          ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo
        read -p "Enter choice [false]: " use_timelocked_owner
        use_timelocked_owner=${use_timelocked_owner:-false}
    else
        use_timelocked_owner=$timelocked_owner
    fi

    export USE_TIMELOCKED_OWNER="$use_timelocked_owner"
    update_env_var "$ENV_FILE" "USE_TIMELOCKED_OWNER" "$USE_TIMELOCKED_OWNER"

    log_info "Deploying Surge L1 SCs..."
    
    local exit_status=0
    local temp_output="/tmp/surge_l1_deploy_output_$$"
    
    # Deploy L1 contracts based on mode
    if [[ "$mode" == "debug" ]]; then
        BROADCAST=true USE_TIMELOCKED_OWNER="$USE_TIMELOCKED_OWNER" VERIFY=false docker compose -f docker-compose-protocol.yml --profile l1-deployer up 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        BROADCAST=true USE_TIMELOCKED_OWNER="$USE_TIMELOCKED_OWNER" VERIFY=false docker compose -f docker-compose-protocol.yml --profile l1-deployer up >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying L1 smart contracts..."
        
        wait $deploy_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "L1 smart contracts deployed successfully"
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
    log_info "Extracting Surge L1 SCs deployment results..."
    
    if [[ ! -f "$L1_DEPLOYMENT_FILE" ]]; then
        log_error "L1 deployment file not found: $L1_DEPLOYMENT_FILE"
        return 1
    fi
    
    # Extract L1 deployment results
    export TAIKO_INBOX=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.taiko')
    export TAIKO_WRAPPER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.taiko_wrapper')
    export AUTOMATA_DCAP_ATTESTATION_GETH=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.automata_dcap_attestation_geth')
    export AUTOMATA_DCAP_ATTESTATION_RETH=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.automata_dcap_attestation_reth')
    export BRIDGE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.bridge')
    export ERC1155_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc1155_vault')
    export ERC20_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc20_vault')
    export ERC721_VAULT=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.erc721_vault')
    export FORCED_INCLUSION_STORE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.forced_inclusion_store')
    export L1_OWNER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.l1_owner // "0x0000000000000000000000000000000000000000"')
    export PEM_CERT_CHAIN_LIB=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.pem_cert_chain_lib')
    export PROOF_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.proof_verifier')
    export RISC0_GROTH16_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.risc0_groth16_verifier')
    export RISC0_RETH_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.risc0_reth_verifier')
    export SGX_GETH_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.sgx_geth_verifier')
    export SGX_RETH_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.sgx_reth_verifier')
    export SHARED_RESOLVER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.shared_resolver')
    export SIG_VERIFY_LIB=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.sig_verify_lib')
    export SIGNAL_SERVICE=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.signal_service')
    export SP1_RETH_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.sp1_reth_verifier')
    export SUCCINCT_VERIFIER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.succinct_verifier')
    export SURGE_TIMELOCK_CONTROLLER=$(cat "$L1_DEPLOYMENT_FILE" | jq -r '.surge_timelock_controller // "0x0000000000000000000000000000000000000000"')

    echo
    echo ">>>>>>"
    echo " TAIKO_INBOX: $TAIKO_INBOX "
    echo " BRIDGE: $BRIDGE "
    echo " SIGNAL_SERVICE: $SIGNAL_SERVICE "
    echo " L1_OWNER: $L1_OWNER "
    echo ">>>>>>"
    echo

    log_info "Updating .env with extracted values..."
    update_env_var "$ENV_FILE" "TAIKO_INBOX" "$TAIKO_INBOX"
    update_env_var "$ENV_FILE" "BRIDGE" "$BRIDGE"
    update_env_var "$ENV_FILE" "SIGNAL_SERVICE" "$SIGNAL_SERVICE"
    update_env_var "$ENV_FILE" "L1_OWNER" "$L1_OWNER"
    # Add more as needed...

    log_success "L1 deployment results extracted and updated in .env"
}

# Deploy proposer wrapper (devnet only)
deploy_proposer_wrapper() {
    local mode="$1"
    
    # Check if deployment is already completed
    if [[ -f "$PROPOSER_WRAPPER_FILE" ]]; then
        log_warning "Proposer Wrapper deployment already completed ($PROPOSER_WRAPPER_FILE exists)"
        log_info "Deployment will be skipped..."
        return 0
    else
        log_info "Deploying Surge Proposer Wrapper..."
        
        local exit_status=0
        local temp_output="/tmp/surge_proposer_wrapper_output_$$"
        
        if [[ "$mode" == "debug" ]]; then
            BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile proposer-wrapper-deployer up 2>&1 | tee "$temp_output"
            exit_status=${PIPESTATUS[0]}
        else
            BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile proposer-wrapper-deployer up >"$temp_output" 2>&1 &
            local deploy_pid=$!
            
            show_progress $deploy_pid "Deploying proposer wrapper..."
            
            wait $deploy_pid
            exit_status=$?
        fi
        
        if [[ $exit_status -eq 0 ]]; then
            log_success "Proposer wrapper deployed successfully"
            return 0
        else
            log_error "Failed to deploy proposer wrapper (exit code: $exit_status)"
            if [[ -f "$temp_output" ]]; then
                log_error "Deployment output saved in: $temp_output"
            fi
            return 1
        fi
    fi
}

# Extract proposer wrapper address
extract_surge_proposer_wrapper() {
    if [[ ! -f "$PROPOSER_WRAPPER_FILE" ]]; then
        log_error "Proposer wrapper file not found: $PROPOSER_WRAPPER_FILE"
        return 1
    fi
    
    export SURGE_PROPOSER_WRAPPER=$(cat "$PROPOSER_WRAPPER_FILE" | jq -r '.proposer_wrapper')

    log_info "Updating .env with proposer wrapper address..."
    update_env_var "$ENV_FILE" "SURGE_PROPOSER_WRAPPER" "$SURGE_PROPOSER_WRAPPER"
    
    log_success "Proposer wrapper address extracted and updated"
}

# Deploy and configure provers (devnet only)
deploy_provers() {
    local should_run_provers
    if [[ -z "${running_provers:-}" ]]; then
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║ Running provers? (true/false) [default: false]               ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo
        read -p "Enter choice [false]: " should_run_provers
        should_run_provers=${should_run_provers:-false}
    else
        should_run_provers=$running_provers
    fi

    if [[ "$should_run_provers" == "true" ]]; then
        generate_prover_chain_spec

        if [[ ! -f "$DEPLOYMENT_DIR/sgx_reth_verifier_setup.lock" ]]; then
            setup_sgx_verifier "sgx_reth" "SGX Raiko" "$SGX_RETH_VERIFIER" "$AUTOMATA_DCAP_ATTESTATION_RETH"
        fi

        if [[ ! -f "$DEPLOYMENT_DIR/sgx_geth_verifier_setup.lock" ]]; then
            setup_sgx_verifier "sgx_geth" "SGX Gaiko" "$SGX_GETH_VERIFIER" "$AUTOMATA_DCAP_ATTESTATION_GETH"
        fi

        if [[ ! -f "$DEPLOYMENT_DIR/sp1_verifier_setup.lock" ]]; then
            setup_sp1_verifier
        fi

        if [[ ! -f "$DEPLOYMENT_DIR/risc0_verifier_setup.lock" ]]; then
            setup_risc0_verifier
        fi

        generate_prover_env_vars
    fi
}

# Setup SGX verifier (common function for both RETH and GETH)
setup_sgx_verifier() {
    local verifier_type="$1"
    local verifier_name="$2"
    local verifier_address="$3"
    local automata_address="$4"
    
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Running $verifier_name? (true/false) [default: false]        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -p "Enter choice [false]: " running_sgx
    running_sgx=${running_sgx:-false}

    if [[ "$running_sgx" == "true" ]]; then
        retrieve_guest_data "$verifier_type"
        
        if [[ "$verifier_type" == "sgx_reth" ]]; then
            if [[ -z "${MR_ENCLAVE:-}" ]] || [[ -z "${MR_SIGNER:-}" ]] || [[ -z "${V3_QUOTE_BYTES:-}" ]]; then
                log_error "SGX RETH guest data is missing"
                return 1
            fi
            
            SGX_VERIFIER_ADDRESS="$verifier_address" AUTOMATA_PROXY_ADDRESS="$automata_address" BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile sgx-reth-verifier-setup up
        else
            if [[ -z "${MR_ENCLAVE_GETH:-}" ]] || [[ -z "${MR_SIGNER_GETH:-}" ]] || [[ -z "${V3_QUOTE_BYTES_GETH:-}" ]]; then
                log_error "SGX GETH guest data is missing"
                return 1
            fi
            
            SGX_VERIFIER_ADDRESS="$verifier_address" AUTOMATA_PROXY_ADDRESS="$automata_address" BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile sgx-geth-verifier-setup up
        fi
    fi
}

# Setup SP1 verifier
setup_sp1_verifier() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Running SP1? (true/false) [default: false]                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -p "Enter choice [false]: " running_sp1
    running_sp1=${running_sp1:-false}

    if [[ "$running_sp1" == "true" ]]; then
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
    echo "║ Running RISC0? (true/false) [default: false]                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -p "Enter choice [false]: " running_risc0
    running_risc0=${running_risc0:-false}

    if [[ "$running_risc0" == "true" ]]; then
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
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║ Deposit bond? (true/false) [default: true]                   ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo
        read -p "Enter choice [true]: " should_deposit_bond
        should_deposit_bond=${should_deposit_bond:-true}
    else
        should_deposit_bond=$deposit_bond
    fi

    if [[ "$should_deposit_bond" == "true" ]]; then
        local bond_amount_eth
        if [[ -z "${bond_amount:-}" ]]; then
            echo
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║ Enter bond amount (in ETH, default: 1000)                    ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo
            read -p "Enter amount [1000]: " bond_amount_eth
            bond_amount_eth=${bond_amount_eth:-1000}
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

# Deploy L2 smart contracts
deploy_l2() {
    # Check if deployment is already completed
    if [[ -f "$L2_DEPLOYMENT_FILE" ]]; then
        log_warning "Surge L2 deployment already completed ($L2_DEPLOYMENT_FILE exists)"
        log_info "Deployment will be skipped..."
        return 0
    else
        log_info "Deploying L2 smart contracts..."
        
        local exit_status=0
        local temp_output="/tmp/surge_l2_deploy_output_$$"
        
        # Deploy L2 contracts
        BROADCAST=true docker compose --profile l2-deployer up -d >"$temp_output" 2>&1 &
        local deploy_pid=$!
        
        show_progress $deploy_pid "Deploying L2 contracts..."
        
        wait $deploy_pid
        exit_status=$?
        
        if [[ $exit_status -eq 0 ]]; then
            log_success "L2 smart contracts deployed successfully"
            return 0
        else
            log_error "Failed to deploy L2 smart contracts (exit code: $exit_status)"
            if [[ -f "$temp_output" ]]; then
                log_error "Deployment output saved in: $temp_output"
            fi
            return 1
        fi
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
    echo "║ Start relayers? (true/false) [default: true]                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [true]: " choice
    choice=${choice:-true}
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
            $compose_cmd --profile driver --profile blockscout up -d --remove-orphans >"$temp_output" 2>&1 &
            ;;
        2)
            log_info "Starting driver + proposer"
            $compose_cmd --profile proposer --profile blockscout up -d --remove-orphans >"$temp_output" 2>&1 &
            ;;
        3)
            log_info "Starting driver + proposer + spammer"
            $compose_cmd --profile proposer --profile spammer --profile blockscout up -d --remove-orphans >"$temp_output" 2>&1 &
            ;;
        4)
            log_info "Starting driver + proposer + prover + spammer"
            $compose_cmd --profile prover --profile blockscout up -d --remove-orphans >"$temp_output" 2>&1 &
            ;;
        5)
            log_info "Starting all except spammer"
            $compose_cmd --profile driver --profile proposer --profile prover --profile blockscout up -d --remove-orphans >"$temp_output" 2>&1 &
            ;;
        *)
            log_info "Starting all components"
            $compose_cmd --profile driver --profile proposer --profile spammer --profile prover --profile blockscout up -d --remove-orphans >"$temp_output" 2>&1 &
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
    
    if [[ "$should_start_relayers" != "true" ]]; then
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
    
    # Generate configuredBridges.json
    cat > "$CONFIGS_DIR/configuredBridges.json" << EOF
{
  "configuredBridges": [
    {
      "source": "$L1_CHAINID",
      "destination": "$L2_CHAINID",
      "addresses": {
        "bridgeAddress": "$BRIDGE",
        "erc20VaultAddress": "$ERC20_VAULT",
        "erc721VaultAddress": "$ERC721_VAULT",
        "erc1155VaultAddress": "$ERC1155_VAULT",
        "crossChainSyncAddress": "",
        "signalServiceAddress": "$SIGNAL_SERVICE",
        "quotaManagerAddress": ""
      }
    },
    {
      "source": "$L2_CHAINID",
      "destination": "$L1_CHAINID",
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
      "$L1_CHAINID": {
        "name": "L1",
        "type": "L1",
        "icon": "https://cdn.worldvectorlogo.com/logos/ethereum-eth.svg",
        "rpcUrls": {
          "default": {
            "http": ["$L1_RPC"]
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
            "url": "$L1_EXPLORER"
          }
        }
      }
    },
    {
      "$L2_CHAINID": {
        "name": "Surge",
        "type": "L2",
        "icon": "https://cdn.worldvectorlogo.com/logos/ethereum-eth.svg",
        "rpcUrls": {
          "default": {
            "http": ["$L2_RPC"]
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
            "url": "$L2_EXPLORER"
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
      "chainIds": [$L1_CHAINID, $L2_CHAINID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAINID, $L1_CHAINID],
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
      "chainIds": [$L1_CHAINID, $L2_CHAINID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAINID, $L1_CHAINID],
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
    
    # Verify L1 RPC
    if [[ -n "${L1_RPC:-}" ]]; then
        if test_rpc_connection "$L1_RPC"; then
            log_success "L1 RPC endpoint is accessible: $L1_RPC"
        else
            log_error "L1 RPC endpoint is not accessible: $L1_RPC"
            all_healthy=false
        fi
    fi
    
    # Verify L2 RPC
    if [[ -n "${L2_RPC:-}" ]]; then
        if test_rpc_connection "$L2_RPC"; then
            log_success "L2 RPC endpoint is accessible: $L2_RPC"
        else
            log_error "L2 RPC endpoint is not accessible: $L2_RPC"
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
    echo "║  • L1 RPC:        ${L1_RPC:-N/A}                            ║"
    echo "║  • L1 Explorer:   ${L1_EXPLORER:-N/A}                       ║"
    echo "║  • L2 RPC:        ${L2_RPC:-N/A}                            ║"
    echo "║  • L2 Explorer:   ${L2_EXPLORER:-N/A}                       ║"
    echo "║  • L1 Relayer:    ${L1_RELAYER:-N/A}                        ║"
    echo "║  • L2 Relayer:    ${L2_RELAYER:-N/A}                        ║"
    
    if [[ -n "${DEPLOYMENT_ADDRESS:-}" ]]; then
        echo "║                                                              ║"
        echo "║  Deployment Account:                                        ║"
        printf "║  • Address:      %-42s ║\n" "$DEPLOYMENT_ADDRESS"
        printf "║  • Balance:       %-20s ETH                        ║\n" "${DEPLOYMENT_BALANCE:-0}"
    fi
    
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

# Main function
main() {
    # Show help if requested
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
    fi

    # Parse arguments
    parse_arguments "$@"
    
    log_info "Starting $SCRIPT_NAME..."

    # If verify-key-only is set, just verify the key and exit
    if [[ "$verify_key_only" == "true" ]]; then
        if [[ -z "$deployment_key" ]] || [[ -z "$l1_rpc_url" ]]; then
            log_error "Both --deployment-key and --l1-rpc-url are required for --verify-key-only"
            exit 1
        fi
        verify_private_key_on_chain "$deployment_key" "$l1_rpc_url" "provided chain"
        exit $?
    fi
    
    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit 1
    fi
    
    # Initialize submodules
    initialize_submodules
    
    # Step 1: Environment Selection (MOVED EARLY)
    local env_choice
    if [[ -z "${environment:-}" ]]; then
        env_choice=$(prompt_environment_selection)
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
        log_error "Failed to load environment file"
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
    fi
    
    if ! configure_environment_urls "$env_choice" "$deployment_choice" "$machine_ip"; then
        log_error "Failed to configure environment URLs"
        exit 1
    fi
    
    # Step 2: L1 Infrastructure Decision
    local deploy_devnet_choice
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
            # Option A: Deploy new devnet
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
        else
            # Option B: Use existing chain
            if ! prompt_for_existing_chain_config "L1"; then
                log_error "Failed to configure existing chain"
                exit 1
            fi
            update_env_var "$ENV_FILE" "PRIVATE_KEY" "$PRIVATE_KEY"
            update_env_var "$ENV_FILE" "PUBLIC_KEY" "$PUBLIC_KEY"
            update_env_var "$ENV_FILE" "L1_RPC" "$L1_RPC"
            update_env_var "$ENV_FILE" "L1_BEACON_RPC" "$L1_BEACON_RPC"
            update_env_var "$ENV_FILE" "L1_EXPLORER" "$L1_EXPLORER"
        fi
    else
        # Staging/Testnet: Always use existing chain
        if ! prompt_for_existing_chain_config "chain"; then
            log_error "Failed to configure existing chain"
            exit 1
        fi
        update_env_var "$ENV_FILE" "PRIVATE_KEY" "$PRIVATE_KEY"
        update_env_var "$ENV_FILE" "PUBLIC_KEY" "$PUBLIC_KEY"
        update_env_var "$ENV_FILE" "L1_RPC" "$L1_RPC"
        update_env_var "$ENV_FILE" "L1_BEACON_RPC" "$L1_BEACON_RPC"
        update_env_var "$ENV_FILE" "L1_EXPLORER" "$L1_EXPLORER"
    fi
    
    # Verify L1 RPC endpoints
    if [[ -n "${L1_RPC:-}" ]]; then
        if ! check_l1_health "$L1_RPC" "${L1_BEACON_RPC:-}"; then
            log_warning "L1 health check failed, but continuing..."
        fi
    fi
    
    # Step 3: L1 Protocol Deployment (ONLY for devnet)
    if [[ "$env_choice" == "1" || "$env_choice" == "devnet" ]]; then
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
        
        # Deploy L1 contracts
        if ! deploy_l1_contracts "$mode_choice"; then
            log_error "Failed to deploy L1 smart contracts"
            exit 1
        fi

        # Extract L1 deployment results
        if ! extract_l1_deployment_results; then
            log_error "Failed to extract L1 deployment results"
            exit 1
        fi

        # Deploy Proposer Wrapper
        if ! deploy_proposer_wrapper "$mode_choice"; then
            log_error "Failed to deploy proposer wrapper"
            exit 1
        fi

        # Extract Proposer Wrapper address
        if ! extract_surge_proposer_wrapper; then
            log_error "Failed to extract proposer wrapper address"
            exit 1
        fi

        # Deploy Provers (optional)
        if ! deploy_provers; then
            log_warning "Prover deployment had issues, but continuing..."
        fi

        # Deposit bond (optional)
        if ! deposit_bond "$mode_choice"; then
            log_warning "Bond deposit had issues, but continuing..."
        fi
    fi
    
    # Step 4: L2 Stack Deployment (ALL environments)
    local stack_choice
    if [[ -z "${stack_option:-}" ]]; then
        stack_choice=$(prompt_stack_option_selection)
    else
        stack_choice=$stack_option
    fi
    
    if ! start_l2_stack "$stack_choice"; then
        log_error "Failed to start L2 stack"
        exit 1
    fi
    
    # Step 5: Start Relayers (optional)
    local relayers_choice
    if [[ -z "${start_relayers:-}" ]]; then
        relayers_choice=$(prompt_relayers_selection)
    else
        relayers_choice=$start_relayers
    fi
    
    if ! start_relayers "$relayers_choice" "$env_choice"; then
        log_warning "Relayer startup had issues, but continuing..."
    fi
    
    # Step 6: Verification
    verify_rpc_endpoints
    
    # Step 7: Display Summary
    display_deployment_summary
    
    log_success "Surge Full Stack deployment complete!"
}

# Run main function
main "$@"

