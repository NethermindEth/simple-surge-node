#!/bin/bash
# helpers.sh — shared utility functions for deploy-surge-full.sh
#
# SOURCE this file; do not execute directly.
# All functions rely on the readonly constants defined in deploy-surge-full.sh
# being present in the calling shell before this file is sourced.
#
# Usage:  source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Guard against double-sourcing
[[ -n "${_SURGE_HELPERS_LOADED:-}" ]] && return 0
readonly _SURGE_HELPERS_LOADED=1

# ─── Colours ────────────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ─── Logging ────────────────────────────────────────────────────────────────
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

# ─── Progress spinner ────────────────────────────────────────────────────────
# Usage: show_progress <pid> <message>
show_progress() {
    local pid="$1"
    local message="$2"
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    printf "%s " "$message"
    while kill -0 "$pid" 2>/dev/null; do
        printf "\b%s" "${spinner:i++%${#spinner}:1}"
        sleep 0.1
    done
    printf "\b\n"
}

# ─── Prerequisites ───────────────────────────────────────────────────────────
validate_prerequisites() {
    log_info "Validating prerequisites..."

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        log_error "Please start Docker and ensure your user has docker permissions"
        return 1
    fi

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

    for dir in "$DEPLOYMENT_DIR" "$CONFIGS_DIR"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating $dir directory..."
            mkdir -p "$dir"
        fi
    done

    log_success "Prerequisites validation passed"
    return 0
}

# ─── Git submodules ──────────────────────────────────────────────────────────
# By default all submodules are checked out at the pinned SHA recorded in the
# parent repo (reproducible). When the global $update_submodules flag is "true"
# (set by --update-submodules in the parent script), the submodules listed in
# UPDATABLE_SUBMODULES are fast-forwarded to the tip of their tracked branch.
# ethereum-package is intentionally excluded — it must stay on a known-good SHA
# because Kurtosis Starlark code on its main branch can break devnet bring-up.
UPDATABLE_SUBMODULES=(surge-taiko-mono)

initialize_submodules() {
    log_info "Initializing git submodules..."

    if git submodule sync >/dev/null 2>&1; then
        log_info "Synced submodule URLs"
    fi

    # Always init at pinned SHAs first (covers ethereum-package etc.)
    if git submodule update --init --recursive >/dev/null 2>&1; then
        log_success "Git submodules initialized at pinned SHAs"
    else
        log_warning "Failed to initialize git submodules with --recursive, trying without..."
        if git submodule update --init >/dev/null 2>&1; then
            log_success "Git submodules initialized (non-recursive)"
        else
            log_warning "Failed to initialize git submodules, but continuing..."
        fi
    fi

    # Then, if requested, fast-forward only the allow-listed submodules.
    if [[ "${update_submodules:-}" == "true" ]]; then
        for sub in "${UPDATABLE_SUBMODULES[@]}"; do
            if [[ ! -d "$sub" ]]; then
                log_warning "Skipping submodule fast-forward: $sub not present"
                continue
            fi
            log_info "Fast-forwarding submodule '$sub' to tip of tracked branch"
            if git submodule update --remote --merge --recursive -- "$sub" >/dev/null 2>&1; then
                local sha
                sha=$(git -C "$sub" rev-parse --short HEAD 2>/dev/null || echo "?")
                log_success "Submodule '$sub' now at $sha"
            else
                log_warning "Failed to fast-forward submodule '$sub' — keeping pinned SHA"
            fi
        done
    fi
}

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

# ─── Private key helpers ─────────────────────────────────────────────────────
validate_private_key_format() {
    local private_key="$1"

    if [[ ! "$private_key" =~ ^0x ]]; then
        log_error "Private key must start with 0x"
        return 1
    fi

    if [[ ${#private_key} -ne 66 ]]; then
        log_error "Private key must be 66 characters (0x + 64 hex digits)"
        log_error "Got ${#private_key} characters"
        return 1
    fi

    if [[ ! "$private_key" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        log_error "Private key must be valid hexadecimal"
        return 1
    fi

    return 0
}

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

derive_address_from_key() {
    local private_key="$1"
    local address=""

    if address=$(derive_address_from_key_cast "$private_key"); then
        echo "$address"
        return 0
    fi

    # Fallback: derive via the same protocol image used to deploy contracts.
    # PROTOCOL_IMAGE comes from .env (which check_env_file sources before this
    # function runs); avoids pinning a second SHA that drifts from .env.devnet.
    local protocol_image="${PROTOCOL_IMAGE:-nethermind/surge-protocol:latest}"
    if address=$(docker run --rm "$protocol_image" cast wallet address "$private_key" 2>/dev/null | head -n1); then
        if [[ -n "$address" ]]; then
            echo "$address"
            return 0
        fi
    fi

    log_error "Unable to derive address from private key"
    log_error "Please install Foundry (cast) and ensure it is in your PATH"
    return 1
}

# ─── RPC helpers ─────────────────────────────────────────────────────────────
# test_rpc_connection <url>  → 0 if reachable, 1 otherwise
test_rpc_connection() {
    local rpc_url="$1"

    local response
    if ! response=$(curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","id":0,"method":"eth_blockNumber","params":[]}' \
        "$rpc_url" 2>/dev/null); then
        return 1
    fi

    if echo "$response" | jq -e '.result' >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# get_chain_id <url>  → prints decimal chain ID, returns 1 on failure
get_chain_id() {
    local rpc_url="$1"

    local response
    response=$(curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","id":0,"method":"eth_chainId","params":[]}' \
        "$rpc_url" 2>/dev/null)

    if echo "$response" | jq -e '.result' >/dev/null 2>&1; then
        local chain_id_hex
        chain_id_hex=$(echo "$response" | jq -r '.result')
        printf "%d" "$chain_id_hex"
        return 0
    fi

    return 1
}

# verify_private_key_on_chain <key> <rpc_url> <chain_name>
# Exports DEPLOYMENT_ADDRESS and DEPLOYMENT_BALANCE on success.
verify_private_key_on_chain() {
    local private_key="$1"
    local rpc_url="$2"
    local chain_name="$3"

    log_info "Verifying private key on $chain_name..."

    log_info "Validating private key format..."
    if ! validate_private_key_format "$private_key"; then
        log_error "Invalid private key format"
        return 1
    fi
    log_success "Private key format validated"

    log_info "Deriving address from private key..."
    local address
    if ! address=$(derive_address_from_key "$private_key"); then
        log_error "Failed to derive address from private key"
        return 1
    fi
    log_info "Address used for deployment: $address"

    log_info "Testing RPC connection..."
    if ! test_rpc_connection "$rpc_url"; then
        log_error "Cannot connect to RPC endpoint: $rpc_url"
        log_error "Please verify the URL is correct and the RPC server is running"
        return 1
    fi
    log_success "RPC connection successful"

    log_info "Querying account balance..."
    local balance
    if ! balance=$(cast balance -e "$address" --rpc-url "$rpc_url" 2>/dev/null); then
        log_error "Failed to query account balance"
        return 1
    fi
    if [[ -z "$balance" ]]; then
        log_error "Received empty balance response"
        return 1
    fi
    log_info "Account balance: $balance ETH"

    log_info "Verifying chain ID..."
    local chain_id
    if ! chain_id=$(cast chain-id --rpc-url "$rpc_url" 2>/dev/null); then
        log_error "Failed to get chain ID"
        return 1
    fi
    log_info "Chain ID: $chain_id"

    local min_balance="0.01"
    if (( $(echo "$balance < $min_balance" | bc -l) )); then
        log_warning "Account balance is low. Deployment may fail."
        log_warning "Current balance: $balance ETH"
        log_warning "Recommended: >= 0.01 ETH"

        if [[ "${force:-}" != "true" ]]; then
            echo
            read -p "Continue anyway? (yes/no) [no]: " continue_choice
            continue_choice=${continue_choice:-no}
            if [[ "$continue_choice" != "yes" && "$continue_choice" != "y" ]]; then
                log_error "Aborted by user"
                return 1
            fi
        fi
    fi

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

    # Export for later use in the calling script
    export DEPLOYMENT_ADDRESS="$address"
    export DEPLOYMENT_BALANCE="$balance"

    return 0
}

# ─── .env file helpers ───────────────────────────────────────────────────────
# Strip Windows CRLF and auto-quote unquoted values containing whitespace.
#
# `bash` interprets `KEY=Test DEX` in a sourced file as: assign KEY=Test, then
# run command DEX (which fails). Users hit this when they put display names
# like `L1_DEX_NAME=Test DEX` without quotes. We auto-fix in place and warn,
# rather than letting `source .env` blow up with a cryptic error.
_sanitize_env_file() {
    local file="$1"

    # 1. CRLF → LF
    if grep -qP '\r' "$file" 2>/dev/null || (file "$file" 2>/dev/null | grep -q CRLF); then
        log_warning "$file has Windows CRLF line endings — converting to LF"
        sed -i.bak 's/\r//' "$file"
        rm -f "${file}.bak"
    fi

    # 2. Auto-quote unquoted values with whitespace.
    #    Skips: comments, blank lines, already-quoted values (single or double),
    #    and values that look like ${VAR} expansions only.
    local tmp="${file}.tmp.$$"
    local fixed_lines=()
    awk '
        BEGIN { fixed = 0 }
        # Pass through comments and blank lines unchanged
        /^[[:space:]]*(#|$)/ { print; next }
        # Match KEY=... lines
        /^[A-Za-z_][A-Za-z0-9_]*=/ {
            eq = index($0, "=")
            key = substr($0, 1, eq - 1)
            val = substr($0, eq + 1)

            # Already quoted (starts AND ends with same quote char)?
            if (val ~ /^".*"$/ || val ~ /^'\''.*'\''$/) { print; next }

            # Contains whitespace but no leading quote → wrap in double quotes.
            # Escape any embedded double quotes in the value first.
            if (val ~ /[ \t]/ && val !~ /^["'\'']/) {
                gsub(/"/, "\\\"", val)
                print key "=\"" val "\""
                printf "FIXED:%s\n", key > "/dev/stderr"
                fixed++
                next
            }

            print
            next
        }
        { print }
    ' "$file" > "$tmp" 2> "${tmp}.fixed"

    if [[ -s "${tmp}.fixed" ]]; then
        while IFS= read -r line; do
            fixed_lines+=("${line#FIXED:}")
        done < "${tmp}.fixed"
        log_warning "$file had unquoted values with whitespace — auto-quoted: ${fixed_lines[*]}"
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
    fi
    rm -f "${tmp}.fixed"
}

# check_env_file <env_name>  — loads .env or .env.<env_name>
check_env_file() {
    local env_name="$1"

    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading environment variables from $ENV_FILE..."
        _sanitize_env_file "$ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
        log_success "Environment variables loaded successfully"
    else
        local env_file_name=".env.$env_name"
        log_info ".env file not found, loading from $env_file_name..."

        if [[ -f "$env_file_name" ]]; then
            cp "$env_file_name" "$ENV_FILE"
            _sanitize_env_file "$ENV_FILE"
            set -a
            source "$ENV_FILE"
            set +a
            log_success "Successfully loaded $env_name environment variables"
        else
            log_error "Neither .env nor $env_file_name file found"
            log_error "Please create a .env file with required configuration"
            return 1
        fi
    fi

    return 0
}

# update_env_var <file> <VAR_NAME> <value>
# Updates or appends a KEY=VALUE line in an env file.
update_env_var() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"

    if grep -q "^${var_name}=" "$env_file"; then
        sed -i.bak "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file" && rm -f "$env_file.bak"
    else
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# _jq_required <file> <jq_field> <label>
# Extracts a required jq field; logs an error and returns 1 on null/empty.
_jq_required() {
    local file="$1" field="$2" label="$3"
    local val
    val=$(jq -r "$field" "$file" 2>/dev/null)
    if [[ -z "$val" || "$val" == "null" ]]; then
        log_error "Missing or null field '$field' in $file (for $label)"
        return 1
    fi
    echo "$val"
}

# ─── Contract verification ───────────────────────────────────────────────────
# is_contract_deployed <address> <rpc_url> [label]
# Returns 0 (true) if the address has deployed bytecode, 1 otherwise.
# Uses: cast codesize — returns 0 for EOA/empty, >0 for deployed contract.
is_contract_deployed() {
    local address="$1"
    local rpc_url="$2"
    local label="${3:-$address}"

    if [[ -z "$address" || "$address" == "0x0000000000000000000000000000000000000000" ]]; then
        log_error "is_contract_deployed: zero/empty address for '$label'"
        return 1
    fi

    local size
    size=$(cast codesize "$address" --rpc-url "$rpc_url" 2>/dev/null)

    if [[ -z "$size" ]]; then
        log_error "is_contract_deployed: RPC call failed for '$label' ($address) at $rpc_url"
        return 1
    fi

    if [[ "$size" -gt 0 ]]; then
        log_success "Contract verified: $label ($address) — codesize $size"
        return 0
    else
        log_error "Contract NOT deployed: $label ($address) — codesize 0"
        return 1
    fi
}

# verify_contracts <rpc_url> <label:address>...
# Verifies multiple contracts in one call. Returns 1 if any fail.
# Usage: verify_contracts "$L1_RPC" "SurgeInbox:$REALTIME_INBOX" "Bridge:$REALTIME_BRIDGE"
verify_contracts() {
    local rpc_url="$1"
    shift
    local all_ok=true

    for entry in "$@"; do
        local label="${entry%%:*}"
        local address="${entry##*:}"
        if ! is_contract_deployed "$address" "$rpc_url" "$label"; then
            all_ok=false
        fi
    done

    [[ "$all_ok" == true ]]
}

# ─── Network / IP helpers ────────────────────────────────────────────────────
# get_machine_ip — returns the primary non-loopback IPv4 of this host
get_machine_ip() {
    local ip=""

    # Linux: use 'ip route' (awk replaces grep -oP for portability)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null \
            | awk '/src/ {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' \
            | head -n1)
    fi

    # macOS / Linux fallback: hostname -I
    if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    # Last resort: ip addr show
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip=$(ip addr show 2>/dev/null \
            | grep 'inet ' \
            | grep -v '127.0.0.1' \
            | head -n1 \
            | awk '{print $2}' \
            | cut -d'/' -f1)
    fi

    echo "$ip"
}

# ─── URL / endpoint helpers ──────────────────────────────────────────────────
# is_external_endpoint <url>
# Returns 0 (true) if the host is public/external (do NOT rewrite).
# Returns 1 (false) if the host is local/private (safe to rewrite).
is_external_endpoint() {
    local endpoint="$1"
    local host
    host=$(echo "$endpoint" | sed -E 's#https?://([^:/]+).*#\1#')

    case "$host" in
        localhost|127.0.0.1|host.docker.internal|0.0.0.0) return 1 ;;
        10.*)                                              return 1 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[0-1].*)          return 1 ;;
        192.168.*)                                         return 1 ;;
    esac

    # A hostname containing a dot is likely a real domain
    if echo "$host" | grep -q '\.'; then
        return 0  # external — do NOT rewrite
    fi

    # No dot → container/service name (e.g. "el-1-nethermind")
    return 1  # local — safe to rewrite
}

# to_docker_internal <url>
# Converts a local URL so containers can reach it via host.docker.internal.
# External URLs are returned as-is.
to_docker_internal() {
    local endpoint="$1"
    if is_external_endpoint "$endpoint"; then
        echo "$endpoint"
        return
    fi
    echo "$endpoint" | sed -E 's#(https?://)([^:/]+)(.*)#\1host.docker.internal\3#'
}

# to_localhost <url>
# Replaces host.docker.internal with localhost (for use from the host machine).
to_localhost() {
    local endpoint="$1"
    echo "$endpoint" | sed -E 's#(https?://)host\.docker\.internal(.*)#\1localhost\2#'
}

# format_endpoint_for_context <url> <deployment_type> <machine_ip>
# deployment_type: "local"|"0"  → host.docker.internal
#                  "remote"|"1" → machine_ip
# External URLs are always returned as-is.
format_endpoint_for_context() {
    local endpoint="$1"
    local deployment_type="$2"
    local machine_ip="$3"

    if is_external_endpoint "$endpoint"; then
        echo "$endpoint"
        return
    fi

    if [[ "$deployment_type" == "remote" || "$deployment_type" == "1" ]] && [[ -n "$machine_ip" ]]; then
        echo "$endpoint" | sed -E "s#(https?://)([^:/]+)(.*)#\1${machine_ip}\3#"
    elif [[ "$deployment_type" == "local" || "$deployment_type" == "0" ]]; then
        echo "$endpoint" | sed -E 's#(https?://)([^:/]+)(.*)#\1host.docker.internal\3#'
    else
        echo "$endpoint"
    fi
}

# extract_port <url>  → prints the port number, or empty string if absent
extract_port() {
    local endpoint="$1"
    echo "$endpoint" | sed -E 's/.*:([0-9]+)$/\1/' | grep -E '^[0-9]+$' || echo ""
}

# build_endpoint <protocol> <host> <port>
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

# ─── Ethereum-package config helpers ─────────────────────────────────────────
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
        sed -i.tmp "s/else \"localhost:{0}\"/else \"${machine_ip}:{0}\"/g" "$BLOCKSCOUT_FILE"
        rm -f "${BLOCKSCOUT_FILE}.tmp"
    fi

    update_env_var "$ENV_FILE" "BLOCKSCOUT_API_HOST" "$machine_ip"

    log_success "Blockscout configured for remote access"
}

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

# configure_environment_urls <env_choice> <deployment_choice> <machine_ip>
#
# Sets and exports the three canonical URL families:
#   L{1,2}_ENDPOINT_HTTP           — base URL (set from .env or devnet defaults)
#   L{1,2}_ENDPOINT_HTTP_DOCKER    — for containers  → host.docker.internal
#   L{1,2}_ENDPOINT_HTTP_EXTERNAL  — for host/browser:
#                                      local  → localhost
#                                      remote → machine_ip
#
# Also sets explorer / relayer / catalyst / DEX UI endpoints for devnet.
configure_environment_urls() {
    local env_choice="$1"
    local deployment_choice="$2"
    local machine_ip="$3"

    # Helper: is this a remote deployment?
    _is_remote() {
        [[ "$deployment_choice" == "1" || "$deployment_choice" == "remote" ]]
    }

    case "$env_choice" in
        1|"devnet")
            log_info "Using Devnet Environment"

            if ! docker network ls | grep -q "surge-network"; then
                log_info "Create surge-network: $(docker network create surge-network)"
            fi

            # ── Base endpoints (respect existing .env values) ──────────────
            if [[ -z "${L1_ENDPOINT_HTTP:-}" ]]; then
                export L1_ENDPOINT_HTTP="http://localhost:32003"
            fi
            if [[ -z "${L1_BEACON_HTTP:-}" ]]; then
                export L1_BEACON_HTTP="http://localhost:33001"
            fi
            if [[ -z "${L2_ENDPOINT_HTTP:-}" ]]; then
                export L2_ENDPOINT_HTTP="http://localhost:${L2_HTTP_PORT:-8547}"
            fi

            # ── DOCKER variants (containers → host services) ───────────────
            # Remote Linux VMs: host.docker.internal doesn't resolve; use machine IP.
            # Local (macOS/Docker Desktop): host.docker.internal works fine.
            if _is_remote; then
                export L1_ENDPOINT_HTTP_DOCKER
                L1_ENDPOINT_HTTP_DOCKER=$(format_endpoint_for_context "$L1_ENDPOINT_HTTP" "remote" "$machine_ip")
                export L1_BEACON_HTTP_DOCKER
                L1_BEACON_HTTP_DOCKER=$(format_endpoint_for_context "$L1_BEACON_HTTP" "remote" "$machine_ip")
                export L2_ENDPOINT_HTTP_DOCKER
                L2_ENDPOINT_HTTP_DOCKER=$(format_endpoint_for_context "$L2_ENDPOINT_HTTP" "remote" "$machine_ip")
            else
                export L1_ENDPOINT_HTTP_DOCKER
                L1_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L1_ENDPOINT_HTTP")
                export L1_BEACON_HTTP_DOCKER
                L1_BEACON_HTTP_DOCKER=$(to_docker_internal "$L1_BEACON_HTTP")
                export L2_ENDPOINT_HTTP_DOCKER
                L2_ENDPOINT_HTTP_DOCKER=$(to_docker_internal "$L2_ENDPOINT_HTTP")
            fi

            # ── EXTERNAL variants (host/browser access) ────────────────────
            if _is_remote; then
                export L1_ENDPOINT_HTTP_EXTERNAL
                L1_ENDPOINT_HTTP_EXTERNAL=$(format_endpoint_for_context "$L1_ENDPOINT_HTTP" "remote" "$machine_ip")
                export L1_BEACON_HTTP_EXTERNAL
                L1_BEACON_HTTP_EXTERNAL=$(format_endpoint_for_context "$L1_BEACON_HTTP" "remote" "$machine_ip")
                export L2_ENDPOINT_HTTP_EXTERNAL
                L2_ENDPOINT_HTTP_EXTERNAL=$(format_endpoint_for_context "$L2_ENDPOINT_HTTP" "remote" "$machine_ip")
            else
                export L1_ENDPOINT_HTTP_EXTERNAL
                L1_ENDPOINT_HTTP_EXTERNAL=$(to_localhost "$L1_ENDPOINT_HTTP")
                export L1_BEACON_HTTP_EXTERNAL
                L1_BEACON_HTTP_EXTERNAL=$(to_localhost "$L1_BEACON_HTTP")
                export L2_ENDPOINT_HTTP_EXTERNAL
                L2_ENDPOINT_HTTP_EXTERNAL=$(to_localhost "$L2_ENDPOINT_HTTP")
            fi

            # ── Service endpoints (browser-facing; respect .env overrides) ─
            local _host
            if _is_remote; then _host="$machine_ip"; else _host="localhost"; fi

            if [[ -z "${L1_EXPLORER:-}" ]]; then
                export L1_EXPLORER="http://${_host}:36002"
            fi
            if [[ -z "${L2_EXPLORER:-}" ]]; then
                export L2_EXPLORER="http://${_host}:${BLOCKSCOUT_FRONTEND_PORT:-3001}"
            fi
            if [[ -z "${L1_RELAYER:-}" ]]; then
                export L1_RELAYER="http://${_host}:4102"
            fi
            if [[ -z "${L2_RELAYER:-}" ]]; then
                export L2_RELAYER="http://${_host}:4103"
            fi
            if [[ -z "${L2_CATALYST:-}" ]]; then
                export L2_CATALYST="http://${_host}:4545"
            fi
            if [[ -z "${L2_DEX_UI:-}" ]]; then
                export L2_DEX_UI="http://${_host}:5173"
            fi
            ;;

        *)
            log_error "Invalid environment choice: $env_choice"
            return 1
            ;;
    esac

    return 0
}

# ─── Health check ────────────────────────────────────────────────────────────
# check_l1_health <rpc_url> [beacon_url]
check_l1_health() {
    local rpc_url="$1"
    local beacon_url="${2:-}"

    log_info "Checking L1 network health..."

    local el_healthy=false

    if curl -s --max-time 10 "$rpc_url" -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","id":0,"method":"eth_syncing","params":[]}' \
        | jq -r '.result == false' >/dev/null 2>&1; then
        log_success "Execution Layer is synced"
        el_healthy=true
    else
        log_warning "Execution Layer is not synced or unreachable"
    fi

    if [[ -n "$beacon_url" ]]; then
        if curl -s --max-time 10 "$beacon_url/lighthouse/syncing" \
            | jq -r '.data == "Synced"' >/dev/null 2>&1; then
            log_success "Beacon Node is synced"
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

# ─── Prompt helpers ──────────────────────────────────────────────────────────
prompt_environment_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Select .env preset to load (Surge config defaults):       " >&2
    echo "║  Note: this is the config preset, not the target L1 chain.   ║" >&2
    echo "║  To target Sepolia / Gnosis / mainnet, edit .env and pick    ║" >&2
    echo "║  'Use existing chain' at the next prompt.                    ║" >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  1 for Devnet (.env.devnet)                                  ║" >&2
    echo "║ [default: Devnet]                                            ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [1]: " choice
    choice=${choice:-1}
    echo "$choice"
}

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
    echo "$choice"
}

prompt_l1_deployment_mode() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "  ⚠️  Deploy new devnet or use existing L1?                     " >&2
    echo "║══════════════════════════════════════════════════════════════║" >&2
    echo "║  0 for Deploy new devnet                                     ║" >&2
    echo "║  1 for Use existing chain.                                   ║" >&2
    echo "║ [default: Deploy new devnet]                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [0]: " choice
    choice=${choice:-0}
    echo "$choice"
}

prompt_stack_option_selection() {
    echo >&2
    echo "╔══════════════════════════════════════════════════════════════╗" >&2
    echo "║ Enter L2 stack option:                                       ║" >&2
    echo "║ 0 for none (verify external L2 RPC only, dev-only)           ║" >&2
    echo "║ 1 for driver only                                            ║" >&2
    echo "║ 2 for driver + catalyst                                      ║" >&2
    echo "║ 3 for driver + catalyst + spammer                            ║" >&2
    echo "║ [default: 2]                                                 ║" >&2
    echo "╚══════════════════════════════════════════════════════════════╝" >&2
    echo >&2
    read -p "Enter choice [2]: " choice
    choice=${choice:-2}
    echo "$choice"
}

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
    echo "$choice"
}

# ─── Prover helpers ──────────────────────────────────────────────────────────
# generate_prover_chain_spec — writes chain_spec_list.json + config.json
# Uses: L1_CHAIN_ID, L2_CHAIN_ID, L1_BEACON_HTTP_EXTERNAL,
#       L1_ENDPOINT_HTTP_DOCKER, L1_BEACON_HTTP_DOCKER, L2_ENDPOINT_HTTP_DOCKER,
#       REALTIME_INBOX, TAIKO_ANCHOR, REALTIME_SURGE_VERIFIER,
#       REALTIME_ZISK_VERIFIER, REALTIME_BRIDGE
generate_prover_chain_spec() {
    log_info "Generating prover chain spec list json..."

    local genesis_time
    local beacon_endpoint="${L1_BEACON_HTTP_EXTERNAL:-${L1_BEACON_HTTP:-http://localhost:33001}}"
    if ! genesis_time=$(curl -s --max-time 10 "${beacon_endpoint}/eth/v1/beacon/genesis" \
            | jq -r '.data.genesis_time' 2>/dev/null); then
        log_warning "Failed to retrieve genesis time, using default value 0"
        genesis_time=0
    fi

    # Use docker-internal endpoints (consumed by containers, not browsers)
    local l1_rpc_docker="${L1_ENDPOINT_HTTP_DOCKER:-http://host.docker.internal:32003}"
    local l1_beacon_docker="${L1_BEACON_HTTP_DOCKER:-http://host.docker.internal:33001}"
    local l2_rpc_docker="${L2_ENDPOINT_HTTP_DOCKER:-http://host.docker.internal:8547}"

    cat > "$CONFIGS_DIR/chain_spec_list.json" << EOF
[
  {
    "name": "surge_dev_l1",
    "chain_id": $L1_CHAIN_ID,
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
    "hard_forks": {
        "ONTAKE": { "Block": 1 },
        "PACAYA": { "Block": 1 },
        "REALTIME": { "Block": 1 }
    },
    "eip_1559_constants": {
        "base_fee_change_denominator": "0x8",
        "base_fee_max_increase_denominator": "0x8",
        "base_fee_max_decrease_denominator": "0x8",
        "elasticity_multiplier": "0x2"
    },
    "l1_contract": {
        "REALTIME": "$REALTIME_INBOX"
    },
    "l2_contract": "$TAIKO_ANCHOR",
    "rpc": "$l2_rpc_docker",
    "beacon_rpc": null,
    "verifier_address_forks": {
        "REALTIME": { "ZISK": "$REALTIME_ZISK_VERIFIER" }
    },
    "genesis_time": 0,
    "seconds_per_slot": 1,
    "is_taiko": true
  }
]
EOF

    cat > "$CONFIGS_DIR/config.json" << EOF
{
	"address": "0.0.0.0:8080",
	"network": "surge_dev",
	"concurrency_limit": 1,
	"l1_network": "surge_dev_l1",
	"cache_path": "/tmp/raiko/",
	"prover": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
	"graffiti": "8008500000000000000000000000000000000000000000000000000000000000",
	"proof_type": "zisk",
	"blob_proof_type": "proof_of_equivalence",
	"use_cache": false,
	"redis_url": "redis://redis-zk:6379",
	"redis_ttl": 3600,
	"enable_redis_pool": false,
	"zisk": {
		"batch_snark": true
	},
	"queue_limit": 1000,
	"api_keys": "",
	"ballot_zk": "{}"
}
EOF

    log_success "Prover chain spec list json and config json generated successfully"
    log_info "Saved to: $CONFIGS_DIR/chain_spec_list.json and $CONFIGS_DIR/config.json"
    log_info "Please copy the json files above to set up the prover"
}

# retrieve_guest_data
# Populates ZISK_BATCH_VKEY from RAIKO_HOST_ZKVM.
retrieve_guest_data() {
    if [[ -n "${RAIKO_HOST_ZKVM:-}" ]]; then
        log_info "Retrieving guest data for ZISK - $RAIKO_HOST_ZKVM"
        export ZISK_BATCH_VKEY
        ZISK_BATCH_VKEY=$(curl -s --max-time 10 "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.zisk.batch_vkey')
    fi
}

# ─── RPC endpoint verification ───────────────────────────────────────────────
verify_rpc_endpoints() {
    log_info "Verifying RPC endpoints..."

    local all_healthy=true

    # Always verify from the host, so use _EXTERNAL variants first
    local l1_endpoint="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-}}"
    if [[ -n "$l1_endpoint" ]]; then
        if test_rpc_connection "$l1_endpoint"; then
            log_success "L1 RPC endpoint is accessible: $l1_endpoint"
        else
            log_error "L1 RPC endpoint is not accessible: $l1_endpoint"
            all_healthy=false
        fi
    fi

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

# prepare_dex_ui_configs — writes nginx.conf and .env for the DEX front-end.
# L1/L2 RPC URLs use _EXTERNAL variants (browser → server).
# L2_CATALYST is also browser-facing (injected via nginx envsubst at runtime).
prepare_dex_ui_configs() {
    # Use external (browser-reachable) endpoints
    local l1_endpoint="${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-}}"
    local l2_endpoint="${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-}}"

    log_info "Preparing DEX UI configs..."

    cp "Dockerfile.dex" "$DEX_DOCKERFILE"

    cat > "$DEX_NGINX_CONF" << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    absolute_redirect off;

    location /api/builder/ {
        resolver          1.1.1.1 8.8.8.8 valid=30s ipv6=off;
        set $builder_upstream ${BUILDER_URL};
        proxy_pass              $builder_upstream/;
        proxy_ssl_server_name   on;
        proxy_redirect          off;
        proxy_set_header        Host              catalyst.realtime.surge.wtf;
        proxy_set_header        X-Real-IP         $remote_addr;
        proxy_set_header        X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto $scheme;
    }

    location ~* \.(js|css|png|svg|ico|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF

    cat > "$DEX_ENV" << EOF
# L1 RPC URL — browser-reachable (balances, smart wallet creation)
VITE_L1_RPC_URL=${l1_endpoint}

# L2 RPC URL — browser-reachable (DEX reserves)
VITE_L2_RPC_URL=${l2_endpoint}

# Builder + Catalyst RPC URLs.
#
# In dev mode (current default — Dockerfile target: dev), userOp.ts hardcodes
# /api/builder and lets Vite's dev-server proxy forward to Catalyst. The proxy
# target is read from VITE_BUILDER_API_URL (note: _API_, not _RPC_) inside
# vite.config.ts and runs *inside the dex container*, so it must use a
# container-reachable address — host.docker.internal works because the dex
# service has extra_hosts mapping it to host-gateway. localhost/127.0.0.1 would
# point at the dex container's own loopback and fail with 500.
#
# VITE_BUILDER_RPC_URL / VITE_CATALYST_RPC_URL are browser-facing; they're only
# read by code paths that run outside dev mode (e.g., production runtime
# build). They use ${L2_CATALYST} which is host-aware (localhost / VM IP).
VITE_BUILDER_API_URL=http://host.docker.internal:4545
VITE_BUILDER_RPC_URL=${L2_CATALYST:-http://localhost:4545}
VITE_CATALYST_RPC_URL=${L2_CATALYST:-http://localhost:4545}

# Chain IDs
VITE_CHAIN_ID=${L1_CHAIN_ID}
VITE_L2_CHAIN_ID=${L2_CHAIN_ID}

# L1 chain display config
VITE_L1_CHAIN_NAME=Surge Devnet
VITE_L1_NATIVE_SYMBOL=ETH
VITE_L1_NATIVE_NAME=Ether
VITE_L1_NATIVE_LOGO=/eth-logo.svg

# L1 block explorer (Blockscout running alongside the L2 stack on the L1 host)
VITE_EXPLORER_URL=${L1_EXPLORER:-}

# Safe contract addresses (same on both chains, deterministic CREATE2)
VITE_SAFE_PROXY_FACTORY=0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67
VITE_SAFE_SINGLETON=0x29fcB43b46531BcA003ddC8FCB67FFE91900C762
VITE_SAFE_MULTISEND=0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526
VITE_SAFE_FALLBACK_HANDLER=0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99

# L1 contracts (from deployment/cross-chain-dex-l1.json + deploy_l1.json)
VITE_L1_VAULT=${L1_VAULT}
VITE_USDC_TOKEN=${L1_TOKEN}
VITE_USDC_DECIMALS=${TOKEN_DECIMALS}
VITE_L1_BRIDGE=${REALTIME_BRIDGE}
VITE_L1_ROUTER=${L1_ROUTER:-0x0000000000000000000000000000000000000000}
VITE_L1_DEX_WETH=${L1_WETH:-0x0000000000000000000000000000000000000000}
# Display name shown in the swap UI ("Test DEX" for fresh deploys, "Uniswap V2"
# when L1_DEX_ROUTER points at a live router in .env)
VITE_L1_DEX_NAME=${L1_DEX_NAME:-Test DEX}

# L2 contracts (from deployment/cross-chain-dex-l2.json)
VITE_SIMPLE_DEX=${L2_DEX}
VITE_L2_VAULT=${L2_VAULT}
VITE_L2_USDC_TOKEN=${L2_TOKEN}

# WalletConnect Project ID (https://cloud.walletconnect.com)
VITE_WALLETCONNECT_PROJECT_ID=${WALLETCONNECT_PROJECT_ID}
EOF
}

# ─── Deployment summary ──────────────────────────────────────────────────────
display_deployment_summary() {
    log_info "Deployment Summary:"
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Surge Full Stack deployment completed successfully!         ║"
    echo "║                                                              ║"
    echo "║  Key Service Endpoints:                                      ║"
    echo "   • L1 RPC:        ${L1_ENDPOINT_HTTP_EXTERNAL:-${L1_ENDPOINT_HTTP:-N/A}}"
    echo "   • L2 RPC:        ${L2_ENDPOINT_HTTP_EXTERNAL:-${L2_ENDPOINT_HTTP:-N/A}}"
    echo "   • L2 Catalyst:   ${L2_CATALYST:-N/A}"
    echo "   • L2 Explorer:   ${L2_EXPLORER:-N/A}"
    echo "   • L2 Dex UI:     ${L2_DEX_UI:-N/A}"

    if [[ -n "${DEPLOYMENT_ADDRESS:-}" ]]; then
        echo "║                                                              ║"
        echo "║  Deployment Account:                                         ║"
        printf "   • Address:      %-42s \n" "$DEPLOYMENT_ADDRESS"
        printf "   • Balance:       %-20s ETH\n" "${DEPLOYMENT_BALANCE:-0}"
    fi

    echo "╚══════════════════════════════════════════════════════════════╝"
}
