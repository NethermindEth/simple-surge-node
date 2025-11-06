#!/bin/bash
set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEPLOYMENT_DIR="deployment"
readonly CONFIGS_DIR="configs"
readonly ENCLAVE_NAME="surge-devnet"
readonly DATA_DIRS=("execution-data" "blockscout-postgres-data" "mysql-data" "rabbitmq")

# Default values for command line arguments
remove_l1_devnet=""
remove_l2_stack=""
remove_relayers=""
remove_data=""
remove_configs=""
remove_env=""
mode=""
force=""

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
    echo "  Remove Surge stack components including L1 devnet (if deployed) and L2 components"
    echo
    echo "Options:"
    echo "  --remove-l1-devnet BOOL  Remove L1 devnet enclave (true|false)"
    echo "  --remove-l2-stack BOOL   Remove L2 stack containers (true|false)"
    echo "  --remove-relayers BOOL   Remove relayer containers (true|false)"
    echo "  --remove-data BOOL       Remove persistent data (true|false)"
    echo "  --remove-configs BOOL   Remove configuration files (true|false)"
    echo "  --remove-env BOOL        Remove .env file (true|false)"
    echo "  --mode MODE              Execution mode (silence|debug)"
    echo "  -f, --force             Skip confirmation prompts"
    echo "  -h, --help              Show this help message"
    echo
    echo "Execution Modes:"
    echo "  silence - Silent mode with progress indicators (default)"
    echo "  debug   - Debug mode with full output"
    echo
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 --force --mode debug              # Remove all with debug output"
    echo "  $0 --remove-l1-devnet true --remove-l2-stack true"
    echo "  $0 --remove-l2-stack true --remove-data false  # Remove containers only"
    exit 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove-l1-devnet)
                remove_l1_devnet="$2"
                shift 2
                ;;
            --remove-l2-stack)
                remove_l2_stack="$2"
                shift 2
                ;;
            --remove-relayers)
                remove_relayers="$2"
                shift 2
                ;;
            --remove-data)
                remove_data="$2"
                shift 2
                ;;
            --remove-configs)
                remove_configs="$2"
                shift 2
                ;;
            --remove-env)
                remove_env="$2"
                shift 2
                ;;
            --mode)
                mode="$2"
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

# Simple progress indicator
show_progress() {
    local pid=$1
    local message="$2"
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    echo
    printf "%s " "$message"
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spinner:i++%${#spinner}:1}"
        sleep 0.1
    done
    printf "\b\n"
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    # Check Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        log_error "Please start Docker and ensure your user has docker permissions"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
}

# Check if Kurtosis is available
check_kurtosis_available() {
    if command -v kurtosis >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if L1 devnet enclave exists
check_l1_devnet_exists() {
    if ! check_kurtosis_available; then
        return 1
    fi
    
    if kurtosis enclave ls 2>/dev/null | grep -q "$ENCLAVE_NAME"; then
        return 0
    else
        return 1
    fi
}

# Get L1 devnet enclave status
get_l1_devnet_status() {
    if ! check_kurtosis_available; then
        echo "NOT_AVAILABLE"
        return
    fi
    
    local status
    status=$(kurtosis enclave ls 2>/dev/null | grep "$ENCLAVE_NAME" | awk '{print $3}' 2>/dev/null || echo "NOT_FOUND")
    echo "$status"
}

# Remove L1 devnet enclave
remove_l1_devnet() {
    local mode_choice="$1"
    
    if ! check_kurtosis_available; then
        log_warning "Kurtosis is not available, skipping L1 devnet removal"
        return 0
    fi
    
    if ! check_l1_devnet_exists; then
        log_info "L1 devnet enclave '$ENCLAVE_NAME' not found"
        log_info "Skipping L1 devnet removal"
        return 0
    fi
    
    log_info "Removing Surge DevNet L1 enclave..."
    
    local exit_status=0
    local temp_output="/tmp/surge_remove_l1_devnet_output_$$"
    
    if [[ "$mode_choice" == "debug" ]]; then
        # Debug mode: run in foreground with full output
        kurtosis enclave rm "$ENCLAVE_NAME" --force 2>&1 | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        # Silent mode: run in background with progress indicator
        kurtosis enclave rm "$ENCLAVE_NAME" --force >"$temp_output" 2>&1 &
        local remove_pid=$!
        
        show_progress $remove_pid "Stopping and removing services..."
        
        wait $remove_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "Enclave removed successfully"
        
        # Clean up unused Kurtosis resources (always attempt, even if removal had warnings)
        cleanup_kurtosis_resources "$mode_choice"
        
        return 0
    else
        log_error "Failed to remove L1 devnet enclave (exit code: $exit_status)"
        if [[ "$mode_choice" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Removal output saved in: $temp_output"
        fi
        return 1
    fi
}

# Clean up Kurtosis system resources
cleanup_kurtosis_resources() {
    local mode_choice="$1"
    
    log_info "Cleaning up system resources..."
    
    local exit_status=0
    
    if [[ "$mode_choice" == "debug" ]]; then
        # Debug mode: run in foreground with full output
        kurtosis clean -a 2>&1
        exit_status=$?
    else
        # Silent mode: run in background with progress indicator
        kurtosis clean -a >/dev/null 2>&1 &
        local cleanup_pid=$!
        
        show_progress $cleanup_pid "Cleaning up unused resources..."
        
        wait $cleanup_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "System cleanup completed"
        return 0
    else
        log_warning "System cleanup completed with warnings"
        return 0  # Don't fail the script for cleanup warnings
    fi
}

# Remove L2 stack containers
remove_l2_stack() {
    local mode_choice="$1"
    
    log_info "Removing L2 stack containers..."
    
    local exit_status=0
    local temp_output="/tmp/surge_remove_l2_output_$$"
    
    if [[ "$mode_choice" == "debug" ]]; then
        # Debug mode: run in foreground with full output
        {
            docker compose --profile driver --profile proposer --profile spammer --profile prover --profile blockscout down --remove-orphans 2>&1
            docker compose -f docker-compose-protocol.yml --profile l1-deployer --profile proposer-wrapper-deployer --profile sgx-reth-verifier-setup --profile sgx-geth-verifier-setup --profile sp1-verifier-setup --profile risc0-verifier-setup --profile bond-deposit --profile l2-deployer down --remove-orphans 2>&1
        } | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        # Silent mode: run in background with progress indicator
        {
            docker compose --profile driver --profile proposer --profile spammer --profile prover --profile blockscout down --remove-orphans 2>&1
            docker compose -f docker-compose-protocol.yml --profile l1-deployer --profile proposer-wrapper-deployer --profile sgx-reth-verifier-setup --profile sgx-geth-verifier-setup --profile sp1-verifier-setup --profile risc0-verifier-setup --profile bond-deposit --profile l2-deployer down --remove-orphans 2>&1
        } >"$temp_output" 2>&1 &
        local remove_pid=$!
        
        show_progress $remove_pid "Removing L2 stack containers..."
        
        wait $remove_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "L2 stack containers removed successfully"
        return 0
    else
        log_error "Failed to remove L2 stack containers (exit code: $exit_status)"
        if [[ "$mode_choice" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Removal output saved in: $temp_output"
        fi
        return 1
    fi
}

# Remove relayer containers
remove_relayers() {
    local mode_choice="$1"
    
    log_info "Removing relayer containers..."
    
    local exit_status=0
    local temp_output="/tmp/surge_remove_relayers_output_$$"
    
    if [[ "$mode_choice" == "debug" ]]; then
        # Debug mode: run in foreground with full output
        {
            docker compose -f docker-compose-relayer.yml --profile relayer-l1 --profile relayer-l2 --profile relayer-api --profile bridge-ui down --remove-orphans 2>&1
            docker compose -f docker-compose-relayer.yml --profile relayer-init --profile relayer-migrations down --remove-orphans 2>&1
        } | tee "$temp_output"
        exit_status=${PIPESTATUS[0]}
    else
        # Silent mode: run in background with progress indicator
        {
            docker compose -f docker-compose-relayer.yml --profile relayer-l1 --profile relayer-l2 --profile relayer-api --profile bridge-ui down --remove-orphans 2>&1
            docker compose -f docker-compose-relayer.yml --profile relayer-init --profile relayer-migrations down --remove-orphans 2>&1
        } >"$temp_output" 2>&1 &
        local remove_pid=$!
        
        show_progress $remove_pid "Removing relayer containers..."
        
        wait $remove_pid
        exit_status=$?
    fi
    
    if [[ $exit_status -eq 0 ]]; then
        log_success "Relayer containers removed successfully"
        return 0
    else
        log_error "Failed to remove relayer containers (exit code: $exit_status)"
        if [[ "$mode_choice" == "silence" ]]; then
            log_error "Run with debug mode for more details: --mode debug"
        fi
        if [[ -f "$temp_output" ]]; then
            log_error "Removal output saved in: $temp_output"
        fi
        return 1
    fi
}

# Remove persistent data directories
remove_data() {
    log_info "Removing persistent data directories..."
    
    local removed_dirs=()
    local failed_dirs=()
    
    for dir in "${DATA_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            if rm -rf "$dir" 2>/dev/null; then
                removed_dirs+=("$dir")
            else
                failed_dirs+=("$dir")
            fi
        fi
    done
    
    if [[ ${#removed_dirs[@]} -gt 0 ]]; then
        log_success "Removed data directories: ${removed_dirs[*]}"
    fi
    
    if [[ ${#failed_dirs[@]} -gt 0 ]]; then
        log_error "Failed to remove data directories: ${failed_dirs[*]}"
        return 1
    fi
    
    if [[ ${#removed_dirs[@]} -eq 0 ]]; then
        log_info "No data directories found to remove"
    fi
    
    return 0
}

# Remove configuration files
remove_configs() {
    log_info "Removing configuration files..."
    
    local removed_files=()
    local failed_files=()
    
    # Remove deployment files
    if [[ -d "$DEPLOYMENT_DIR" ]]; then
        # Use nullglob to handle case where no files match
        shopt -s nullglob
        local deployment_files=("$DEPLOYMENT_DIR"/*.json "$DEPLOYMENT_DIR"/*.lock)
        shopt -u nullglob
        
        # Check if array has elements before iterating
        if [[ ${#deployment_files[@]} -gt 0 ]]; then
            for file in "${deployment_files[@]}"; do
                if [[ -f "$file" ]]; then
                    if rm -f "$file" 2>/dev/null; then
                        removed_files+=("$file")
                    else
                        failed_files+=("$file")
                    fi
                fi
            done
        fi
    fi
    
    # Remove config files
    if [[ -d "$CONFIGS_DIR" ]]; then
        # Use nullglob to handle case where no files match
        shopt -s nullglob
        local config_files=("$CONFIGS_DIR"/*.json)
        shopt -u nullglob
        
        # Check if array has elements before iterating
        if [[ ${#config_files[@]} -gt 0 ]]; then
            for file in "${config_files[@]}"; do
                if [[ -f "$file" ]]; then
                    if rm -f "$file" 2>/dev/null; then
                        removed_files+=("$file")
                    else
                        failed_files+=("$file")
                    fi
                fi
            done
        fi
    fi
    
    if [[ ${#removed_files[@]} -gt 0 ]]; then
        log_success "Removed configuration files: ${#removed_files[@]} files"
    fi
    
    if [[ ${#failed_files[@]} -gt 0 ]]; then
        log_error "Failed to remove configuration files: ${failed_files[*]}"
        return 1
    fi
    
    if [[ ${#removed_files[@]} -eq 0 ]]; then
        log_info "No configuration files found to remove"
    fi
    
    return 0
}

# Remove environment file
remove_env_file() {
    log_info "Removing environment file..."
    
    if [[ -f ".env" ]]; then
        if rm -f .env 2>/dev/null; then
            log_success "Environment file removed successfully"
        else
            log_error "Failed to remove environment file"
            return 1
        fi
    else
        log_info "No environment file found to remove"
    fi
    
    return 0
}

# Remove Docker network
remove_network() {
    log_info "Removing Docker network..."
    
    if docker network ls | grep -q "surge-network"; then
        if docker network rm surge-network >/dev/null 2>&1; then
            log_success "Docker network 'surge-network' removed successfully"
        else
            log_warning "Failed to remove Docker network 'surge-network' (may be in use)"
        fi
    else
        log_info "Docker network 'surge-network' not found"
    fi
}

# Prompt for confirmation
prompt_confirmation() {
    local components="$1"
    
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Confirm Surge Stack Removal                               " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  This will remove the following components:                  ║" >&2
    echo "$components" >&2
    echo "║                                                              ║" >&2
    echo "║  Are you sure you want to continue?                          ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter 'yes' to confirm removal: " confirmation
    
    if [[ "$confirmation" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt for component selection
prompt_component_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select components to remove:                              " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  1. L1 devnet enclave (Kurtosis)                             ║" >&2
    echo "║  2. L2 stack containers                                      ║" >&2
    echo "║  3. Relayer containers and Bridge UI                         ║" >&2
    echo "║  4. Persistent data directories                              ║" >&2
    echo "║  5. Configuration files                                      ║" >&2
    echo "║  6. Environment file (.env)                                  ║" >&2
    echo "║ [default: Remove all except environment file]                ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter components to remove (1-6, comma-separated) [1,2,3,4,5]: " components
    components=${components:-"1,2,3,4,5"}
    echo $components
}

# Prompt for execution mode selection
prompt_mode_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select execution mode:                                    " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  0 for silence (default)                                     ║" >&2
    echo "║  1 for debug                                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo $choice
}

# Build confirmation message based on components to remove
build_confirmation_message() {
    local l1="$1"
    local l2="$2"
    local relayers="$3"
    local data="$4"
    local configs="$5"
    local env="$6"
    
    local msg=""
    
    if [[ "$l1" == "true" ]]; then
        msg+="║  • L1 devnet enclave (Kurtosis)                              ║\n"
    fi
    if [[ "$l2" == "true" ]]; then
        msg+="║  • L2 stack containers and services                          ║\n"
    fi
    if [[ "$relayers" == "true" ]]; then
        msg+="║  • Relayer containers and Bridge UI                          ║\n"
    fi
    if [[ "$data" == "true" ]]; then
        msg+="║  • Persistent data directories                               ║\n"
    fi
    if [[ "$configs" == "true" ]]; then
        msg+="║  • Configuration and deployment files                        ║\n"
    fi
    if [[ "$env" == "true" ]]; then
        msg+="║  • Environment file (.env)                                   ║\n"
    fi
    
    if [[ -z "$msg" ]]; then
        msg="║  • (No components selected)                                  ║\n"
    fi
    
    echo -e "$msg"
}

# Display removal summary
display_removal_summary() {
    local l1="$1"
    local l2="$2"
    local relayers="$3"
    local data="$4"
    local configs="$5"
    
    echo
    log_info "Removal Summary:"
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Surge Stack has been removed successfully!                  ║"
    echo "║                                                              ║"
    echo "║  Components removed:                                         ║"
    
    if [[ "$l1" == "true" ]]; then
        echo "║  • L1 devnet enclave                                         ║"
    fi
    if [[ "$l2" == "true" ]]; then
        echo "║  • L2 stack containers and services                          ║"
    fi
    if [[ "$relayers" == "true" ]]; then
        echo "║  • Relayer containers and Bridge UI                          ║"
    fi
    if [[ "$data" == "true" ]]; then
        echo "║  • Persistent data directories                               ║"
    fi
    if [[ "$configs" == "true" ]]; then
        echo "║  • Configuration and deployment files                        ║"
    fi
    
    echo "║                                                              ║"
    echo "║  To deploy a new instance, run:                              ║"
    echo "║  ./deploy-surge-full.sh                                      ║"
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

    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    # Check what exists
    local has_l1_devnet=false
    if check_l1_devnet_exists; then
        local l1_status
        l1_status=$(get_l1_devnet_status)
        log_info "Found L1 devnet enclave (Status: $l1_status)"
        has_l1_devnet=true
    else
        log_info "No L1 devnet enclave found"
    fi
    
    local has_l2_containers=false
    if docker ps --filter "name=taiko" --filter "name=nethermind" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        log_info "Found L2 stack containers"
        has_l2_containers=true
    fi
    
    local has_relayers=false
    if docker ps --filter "name=relayer" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        log_info "Found relayer containers"
        has_relayers=true
    fi
    
    # Get component selection if not specified
    local components_to_remove
    if [[ -z "${remove_l1_devnet:-}${remove_l2_stack:-}${remove_relayers:-}${remove_data:-}${remove_configs:-}${remove_env:-}" ]]; then
        components_to_remove=$(prompt_component_selection)
    fi
    
    # Parse component selection
    if [[ -n "${components_to_remove:-}" ]]; then
        local COMPONENTS=()
        IFS=',' read -ra COMPONENTS <<< "$components_to_remove"
        for component in "${COMPONENTS[@]}"; do
            case "$component" in
                1) remove_l1_devnet="true" ;;
                2) remove_l2_stack="true" ;;
                3) remove_relayers="true" ;;
                4) remove_data="true" ;;
                5) remove_configs="true" ;;
                6) remove_env="true" ;;
            esac
        done
    fi
    
    # Set defaults based on what exists
    if [[ "$has_l1_devnet" == true ]]; then
        remove_l1_devnet=${remove_l1_devnet:-"true"}
    else
        remove_l1_devnet=${remove_l1_devnet:-"false"}
    fi
    
    remove_l2_stack=${remove_l2_stack:-"true"}
    remove_relayers=${remove_relayers:-"true"}
    remove_data=${remove_data:-"true"}
    remove_configs=${remove_configs:-"true"}
    remove_env=${remove_env:-"false"}
    
    # Get mode choice
    local mode_choice
    if [[ -z "${mode:-}" ]]; then
        mode_choice=$(prompt_mode_selection)
    else
        mode_choice=$mode
    fi
    
    # Convert mode choice to string
    case "$mode_choice" in
        1|"debug")
            mode_choice="debug"
            ;;
        0|"silence"|"")
            mode_choice="silence"
            ;;
        *)
            log_error "Invalid mode choice: $mode_choice"
            exit 1
            ;;
    esac
    
    # Build confirmation message
    local confirmation_msg
    confirmation_msg=$(build_confirmation_message "$remove_l1_devnet" "$remove_l2_stack" "$remove_relayers" "$remove_data" "$remove_configs" "$remove_env")
    
    # Get confirmation unless force flag is used
    if [[ "$force" != "true" ]]; then
        if ! prompt_confirmation "$confirmation_msg"; then
            log_info "Removal cancelled by user"
            exit 0
        fi
    fi
    
    echo
    log_info "Beginning Surge Stack removal process..."
    
    # Remove components based on selection
    if [[ "$remove_l1_devnet" == "true" ]]; then
        if ! remove_l1_devnet "$mode_choice"; then
            log_error "Failed to remove L1 devnet"
            exit 1
        fi
    fi
    
    if [[ "$remove_l2_stack" == "true" ]]; then
        if ! remove_l2_stack "$mode_choice"; then
            log_error "Failed to remove L2 stack"
            exit 1
        fi
    fi
    
    if [[ "$remove_relayers" == "true" ]]; then
        if ! remove_relayers "$mode_choice"; then
            log_error "Failed to remove relayers"
            exit 1
        fi
    fi
    
    if [[ "$remove_data" == "true" ]]; then
        if ! remove_data; then
            log_warning "Failed to remove some data directories (continuing anyway)"
        fi
    fi
    
    if [[ "$remove_configs" == "true" ]]; then
        if ! remove_configs; then
            log_warning "Failed to remove some configuration files (continuing anyway)"
        fi
    fi
    
    if [[ "$remove_env" == "true" ]]; then
        if ! remove_env_file; then
            log_error "Failed to remove environment file"
            exit 1
        fi
    fi
    
    # Always try to remove network (non-critical)
    remove_network
    
    # Display summary
    display_removal_summary "$remove_l1_devnet" "$remove_l2_stack" "$remove_relayers" "$remove_data" "$remove_configs"
    
    log_success "Surge Stack removal complete!"
}

# Run main function
main "$@"

