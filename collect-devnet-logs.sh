#!/bin/bash
# collect-devnet-logs.sh — snapshot logs from all Surge devnet containers
#
# L1:  kurtosis enclave dump (captures all L1 devnet service logs + artifacts)
# L2:  docker compose logs per service from docker-compose.yml
#
# Usage:
#   ./collect-devnet-logs.sh                  # snapshot everything
#   ./collect-devnet-logs.sh --l1-only        # L1 enclave dump only
#   ./collect-devnet-logs.sh --l2-only        # L2 docker logs only
#   ./collect-devnet-logs.sh --since 1h       # L2 logs from last hour
#   ./collect-devnet-logs.sh -o /tmp/mylogs   # custom output directory
#   ./collect-devnet-logs.sh -h               # help

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ENCLAVE_NAME="surge-devnet"

# ─── Colours ────────────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info()    { echo -e "\n${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "\n${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "\n${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "\n${RED}[ERROR]${NC} $1" >&2; }

# ─── Help ───────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Collect a diagnostic snapshot of all Surge devnet container logs.

Options:
  -o, --output DIR     Output directory (default: ./logs/snapshot-YYYYMMDD-HHMMSS)
  --l1-only            Only dump L1 enclave logs (skip L2 docker logs)
  --l2-only            Only collect L2 docker logs (skip L1 enclave dump)
  --since DURATION     L2 docker logs since duration (e.g. 1h, 30m, 2h30m)
  -h, --help           Show this help

Examples:
  $(basename "$0")                     # full snapshot
  $(basename "$0") --since 30m         # last 30 minutes of L2 logs only
  $(basename "$0") --l1-only           # only kurtosis enclave dump
  $(basename "$0") -o /tmp/surge-logs  # custom output path
EOF
}

# ─── Parse args ─────────────────────────────────────────────────────────────
output_dir=""
collect_l1=true
collect_l2=true
since_flag=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)     output_dir="$2";   shift 2 ;;
        --l1-only)       collect_l2=false;  shift   ;;
        --l2-only)       collect_l1=false;  shift   ;;
        --since)         since_flag="$2";   shift 2 ;;
        -h|--help)       usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ─── Output directory ────────────────────────────────────────────────────────
if [[ -z "$output_dir" ]]; then
    output_dir="$SCRIPT_DIR/logs/snapshot-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$output_dir"
log_info "Saving snapshot to: $output_dir"

# ─── L1: kurtosis enclave dump ───────────────────────────────────────────────
collect_l1_logs() {
    local l1_dir="$output_dir/l1"

    if ! command -v kurtosis &>/dev/null; then
        log_warning "kurtosis not found — skipping L1 enclave dump"
        mkdir -p "$l1_dir"
        echo "kurtosis not installed" > "$l1_dir/SKIPPED"
        return 0
    fi

    if ! kurtosis enclave ls 2>/dev/null | grep -q "$ENCLAVE_NAME"; then
        log_warning "Enclave '$ENCLAVE_NAME' not found — skipping L1 enclave dump"
        mkdir -p "$l1_dir"
        echo "enclave '$ENCLAVE_NAME' not running" > "$l1_dir/SKIPPED"
        return 0
    fi

    # kurtosis enclave dump creates the output directory itself — do not pre-create it
    log_info "Dumping L1 enclave '$ENCLAVE_NAME'..."
    if kurtosis enclave dump "$ENCLAVE_NAME" "$l1_dir" 2>&1; then
        log_success "L1 enclave dump saved to $l1_dir"
    else
        log_error "kurtosis enclave dump failed (exit $?)"
        return 1
    fi
}

# ─── L2: docker compose logs ─────────────────────────────────────────────────
collect_l2_logs() {
    local l2_dir="$output_dir/l2"
    mkdir -p "$l2_dir"

    if ! command -v docker &>/dev/null; then
        log_warning "docker not found — skipping L2 log collection"
        echo "docker not installed" > "$l2_dir/SKIPPED"
        return 0
    fi

    # All L2 containers defined in docker-compose.yml
    local containers=(
        l2-nethermind-execution-client
        l2-taiko-consensus-client
        web3signer-l1
        web3signer-l2
        l2-catalyst-node
        l2-raiko-zk-client
        l2-tx-spammer
        l2-blockscout-postgres
        l2-blockscout-verif
        l2-blockscout
        l2-blockscout-frontend
        dex
    )

    # Build docker logs flags (docker logs has no --no-color flag)
    local logs_flags=(--timestamps)
    if [[ -n "$since_flag" ]]; then
        logs_flags+=(--since "$since_flag")
    fi

    log_info "Collecting L2 container logs..."

    local collected=0
    local skipped=0

    for container in "${containers[@]}"; do
        local running
        # Strip whitespace/newlines — docker inspect can emit a blank line before
        # the error message on some versions, poisoning the variable with a leading \n
        running=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || true)
        running="${running//[$'\t\r\n ']/}"
        running="${running:-not_found}"

        if [[ "$running" == "not_found" ]]; then
            skipped=$(( skipped + 1 ))
            continue
        fi

        local log_file="$l2_dir/${container}.log"
        log_info "  → $container ($running)"

        if docker logs "${logs_flags[@]}" "$container" >"$log_file" 2>&1; then
            collected=$(( collected + 1 ))
        else
            log_warning "  Failed to collect logs for $container"
            echo "[docker logs failed]" >> "$log_file"
        fi
    done

    log_success "L2 logs: $collected collected, $skipped not running"

    # Also save docker compose ps output for reference
    if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
        docker compose -f "$SCRIPT_DIR/docker-compose.yml" ps --no-trunc \
            > "$l2_dir/_docker-compose-ps.txt" 2>&1 || true
    fi
}

# ─── System info ────────────────────────────────────────────────────────────
collect_system_info() {
    local info_file="$output_dir/system-info.txt"
    {
        echo "=== Surge Devnet Log Snapshot ==="
        echo "Timestamp : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "Host      : $(hostname)"
        echo ""
        echo "=== Docker ==="
        docker version --format 'Client: {{.Client.Version}}  Server: {{.Server.Version}}' 2>/dev/null || echo "docker not available"
        echo ""
        echo "=== Docker Compose ==="
        docker compose version 2>/dev/null || echo "docker compose not available"
        echo ""
        echo "=== Kurtosis ==="
        kurtosis version 2>/dev/null || echo "kurtosis not available"
        echo ""
        echo "=== Kurtosis Enclaves ==="
        kurtosis enclave ls 2>/dev/null || echo "kurtosis not available"
        echo ""
        echo "=== Docker Containers (surge-network) ==="
        docker ps --filter network=surge-network --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null || echo "none"
    } > "$info_file" 2>&1
}

# ─── Main ────────────────────────────────────────────────────────────────────
collect_system_info

if [[ "$collect_l1" == "true" ]]; then
    collect_l1_logs
fi

if [[ "$collect_l2" == "true" ]]; then
    collect_l2_logs
fi

log_success "Surge Devnet Log Snapshot Complete"
log_info "Output: $output_dir"
