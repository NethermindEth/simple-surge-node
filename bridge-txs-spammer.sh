#!/bin/bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly ENV_FILE=".env"

# Default values for command line arguments
num_txs=""
direction=""
amount_eth=""
force=""

# Constants
readonly FEE_WEI="10000000000000000"
readonly GAS_LIMIT="1000000"
readonly ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
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

log_tx() {
    echo -e "${CYAN}[TX]${NC} $1"
}

# Show usage help
show_help() {
    echo "Usage:"
    echo "  $SCRIPT_NAME [OPTIONS]"
    echo
    echo "Description:"
    echo "  Spam bridge transactions between L1 and L2 chains"
    echo
    echo "Options:"
    echo "  --num-txs NUM          Number of bridge transactions to send [REQUIRED]"
    echo "  --direction DIR        Destination chain direction (l1|l2|both) [REQUIRED]"
    echo "  --amount-eth NUM       Amount of ETH to bridge per transaction (default: 0.1)"
    echo "  -f, --force            Skip confirmation prompts"
    echo "  -h, --help             Show this help message"
    echo
    echo "Direction Options:"
    echo "  l1   - Send bridge transactions from L2 -> L1 only"
    echo "  l2   - Send bridge transactions from L1 -> L2 only"
    echo "  both - Send bridge transactions in both directions"
    echo
    echo "Examples:"
    echo "  $SCRIPT_NAME --num-txs 10 --direction l2"
    echo "  $SCRIPT_NAME --num-txs 50 --direction both --amount-eth 0.05"
    echo "  $SCRIPT_NAME --num-txs 100 --direction l1 --force"
    exit 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --num-txs)
                num_txs="$2"
                shift 2
                ;;
            --direction)
                direction="$2"
                shift 2
                ;;
            --amount-eth)
                amount_eth="$2"
                shift 2
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

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    local required_cmds=("cast" "bc")
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

    log_success "Prerequisites validated"
    return 0
}

# Load environment file
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading environment variables from $ENV_FILE..."
        set -a
        source "$ENV_FILE"
        set +a
        log_success "Environment variables loaded"
    else
        log_error ".env file not found. Please run deploy-surge-full.sh first."
        return 1
    fi

    # Validate required env vars
    local required_vars=(
        "SHASTA_BRIDGE" "L2_BRIDGE"
        "L1_CHAIN_ID" "L2_CHAIN_ID"
        "PUBLIC_KEY" "PRIVATE_KEY"
        "L1_ENDPOINT_HTTP" "L2_ENDPOINT_HTTP"
    )
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please ensure your .env file is properly configured"
        return 1
    fi

    return 0
}

# Prompt for number of transactions
prompt_num_txs() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║  How many bridge transactions to send?                       ║" >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  Enter a number (e.g. 10, 50, 100)                           ║" >&2
    echo "║ [default: 10]                                                ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter number of transactions [10]: " choice
    choice=${choice:-10}
    echo "$choice"
}

# Prompt for direction selection
prompt_direction_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select bridge direction:                                  " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  1 for L1 → L2 only                                          ║" >&2
    echo "║  2 for L2 → L1 only                                          ║" >&2
    echo "║  3 for Both directions                                       ║" >&2
    echo "║ [default: L1 → L2]                                           ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [1]: " choice
    choice=${choice:-1}
    echo "$choice"
}

# Prompt for ETH amount
prompt_amount_eth() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║  Enter ETH amount per bridge transaction:                    ║" >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  e.g. 0.01, 0.1, 1                                           ║" >&2
    echo "║ [default: 0.1]                                               ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter amount [0.1]: " choice
    choice=${choice:-0.1}
    echo "$choice"
}

# Send a single bridge transaction
send_bridge_tx() {
    local bridge_address="$1"
    local rpc_url="$2"
    local dest_chain_id="$3"
    local amount_wei="$4"
    local total_value_wei="$5"
    local label="$6"
    local tx_num="$7"
    local total="$8"

    log_tx "[$tx_num/$total] Sending $label bridge tx..."

    if cast send "$bridge_address" \
        "sendMessage((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes))" \
        "(0,$FEE_WEI,$GAS_LIMIT,$ZERO_ADDRESS,0,$PUBLIC_KEY,$dest_chain_id,$PUBLIC_KEY,$PUBLIC_KEY,$amount_wei,0x)" \
        --value "$total_value_wei" \
        --rpc-url "$rpc_url" \
        --private-key "$PRIVATE_KEY" >/dev/null 2>&1; then
        log_tx "[$tx_num/$total] $label bridge tx sent successfully ✓"
        return 0
    else
        log_error "[$tx_num/$total] $label bridge tx failed ✗"
        return 1
    fi
}

# Run bridge spam for a specific direction
run_bridge_spam() {
    local direction_label="$1"
    local bridge_address="$2"
    local rpc_url="$3"
    local dest_chain_id="$4"
    local amount_wei="$5"
    local total_value_wei="$6"
    local count="$7"

    log_info "Starting $direction_label bridge spam ($count transactions)..."
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    printf "║  Direction:      %-46s║\n" "$direction_label"
    printf "║  Bridge Address: %-44s║\n" "$bridge_address"
    printf "║  RPC URL:        %-44s║\n" "$rpc_url"
    printf "║  Dest Chain ID:  %-44s║\n" "$dest_chain_id"
    printf "║  Transactions:   %-44s║\n" "$count"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    local success_count=0
    local fail_count=0

    for ((i = 1; i <= count; i++)); do
        if send_bridge_tx "$bridge_address" "$rpc_url" "$dest_chain_id" \
            "$amount_wei" "$total_value_wei" "$direction_label" "$i" "$count"; then
            ((success_count++)) || true
        else
            ((fail_count++)) || true
        fi
    done

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    printf "║  %s Results: %-43s║\n" "$direction_label"
    echo "║══════════════════════════════════════════════════════════════║"
    printf "║  Successful: %-48s║\n" "$success_count / $count"
    printf "║  Failed:     %-48s║\n" "$fail_count / $count"
    echo "╚══════════════════════════════════════════════════════════════╝"

    if [[ $fail_count -gt 0 ]]; then
        log_warning "$fail_count transactions failed for $direction_label"
    else
        log_success "All $direction_label transactions completed successfully"
    fi
}

# Display configuration summary and confirm
confirm_execution() {
    local tx_count="$1"
    local dir_label="$2"
    local eth_amount="$3"

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Bridge Transaction Spammer - Configuration Summary          ║"
    echo "║══════════════════════════════════════════════════════════════║"
    printf "║  Transactions:   %-44s║\n" "$tx_count"
    printf "║  Direction:      %-44s║\n" "$dir_label"
    printf "║  Amount per TX:  %-44s║\n" "$eth_amount ETH"
    printf "║  Fee per TX:     %-44s║\n" "0.01 ETH"
    printf "║  Sender:         %-44s║\n" "$PUBLIC_KEY"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    if [[ "$force" != "true" ]]; then
        read -p "Proceed with sending transactions? (yes/no) [yes]: " confirm
        confirm=${confirm:-yes}
        if [[ "$confirm" != "yes" && "$confirm" != "y" ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi
}

main() {
    # Show help if requested
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
    fi

    # Parse arguments
    parse_arguments "$@"

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          Surge Bridge Transaction Spammer                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites validation failed"
        exit 1
    fi

    # Load environment
    if ! load_env; then
        log_error "Failed to load environment"
        exit 1
    fi

    # Step 1: Get number of transactions
    local tx_count
    if [[ -z "${num_txs:-}" ]]; then
        tx_count=$(prompt_num_txs)
    else
        tx_count="$num_txs"
    fi

    # Validate tx_count is a positive integer
    if ! [[ "$tx_count" =~ ^[1-9][0-9]*$ ]]; then
        log_error "Invalid number of transactions: $tx_count (must be a positive integer)"
        exit 1
    fi

    # Step 2: Get direction
    local dir_choice
    if [[ -z "${direction:-}" ]]; then
        dir_choice=$(prompt_direction_selection)
    else
        case "$direction" in
            1|"l2"|"L2"|"l1-to-l2") dir_choice=1 ;;
            2|"l1"|"L1"|"l2-to-l1") dir_choice=2 ;;
            3|"both"|"BOTH")         dir_choice=3 ;;
            *) log_error "Invalid direction: $direction"; exit 1 ;;
        esac
    fi

    # Step 3: Get ETH amount
    local eth_amount
    if [[ -z "${amount_eth:-}" ]]; then
        eth_amount=$(prompt_amount_eth)
    else
        eth_amount="$amount_eth"
    fi

    # Calculate amounts
    local amount_wei
    local total_value_wei
    amount_wei=$(echo "$eth_amount * 1000000000000000000" | bc | cut -d'.' -f1)
    total_value_wei=$(echo "$amount_wei + $FEE_WEI" | bc)

    # Resolve RPC URLs (use localhost versions for host-based calls)
    local l1_rpc="${L1_ENDPOINT_HTTP:-http://localhost:32003}"
    local l2_rpc="${L2_ENDPOINT_HTTP:-http://localhost:8547}"

    # Replace host.docker.internal with localhost for host-based execution
    l1_rpc=$(echo "$l1_rpc" | sed 's/host\.docker\.internal/localhost/g')
    l2_rpc=$(echo "$l2_rpc" | sed 's/host\.docker\.internal/localhost/g')

    # Map direction to label
    local dir_label
    case "$dir_choice" in
        1) dir_label="L1 → L2" ;;
        2) dir_label="L2 → L1" ;;
        3) dir_label="Both (${tx_count} each direction, $((tx_count * 2)) total)" ;;
    esac

    # Confirm execution
    confirm_execution "$tx_count" "$dir_label" "$eth_amount"

    # Execute bridge spam
    local total_success=0
    local total_fail=0

    case "$dir_choice" in
        1)
            # L1 -> L2: call L1 bridge, dest = L2 chain
            run_bridge_spam "L1 → L2" "$SHASTA_BRIDGE" "$l1_rpc" "$L2_CHAIN_ID" \
                "$amount_wei" "$total_value_wei" "$tx_count"
            ;;
        2)
            # L2 -> L1: call L2 bridge, dest = L1 chain
            run_bridge_spam "L2 → L1" "$L2_BRIDGE" "$l2_rpc" "$L1_CHAIN_ID" \
                "$amount_wei" "$total_value_wei" "$tx_count"
            ;;
        3)
            # Both directions: send full count in each direction
            log_info "Sending $tx_count transactions in each direction ($((tx_count * 2)) total)"

            # L1 -> L2
            run_bridge_spam "L1 → L2" "$SHASTA_BRIDGE" "$l1_rpc" "$L2_CHAIN_ID" \
                "$amount_wei" "$total_value_wei" "$tx_count"

            # L2 -> L1
            run_bridge_spam "L2 → L1" "$L2_BRIDGE" "$l2_rpc" "$L1_CHAIN_ID" \
                "$amount_wei" "$total_value_wei" "$tx_count"
            ;;
    esac

    # Final summary
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Bridge Transaction Spammer - Complete!                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    log_success "Bridge transaction spamming complete!"
}

# Run main function
main "$@"
