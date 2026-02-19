#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

NO_CLEANUP="${NO_CLEANUP:-false}"

log() { echo "[CI-E2E] $(date '+%H:%M:%S') $1"; }

cleanup() {
    local exit_code=$?
    if [[ "$NO_CLEANUP" == "true" && $exit_code -ne 0 ]]; then
        log "Skipping teardown (NO_CLEANUP=true, exit_code=$exit_code)"
        exit $exit_code
    fi

    log "Teardown starting (exit_code=$exit_code)..."

    ./remove-surge-full.sh \
        --remove-l1-devnet true \
        --remove-l2-stack true \
        --remove-relayers true \
        --remove-data true \
        --remove-configs true \
        --remove-env true \
        --mode debug \
        --force || true

    docker network rm surge-network 2>/dev/null || true

    if command -v kurtosis &>/dev/null; then
        kurtosis enclave rm surge-devnet --force 2>/dev/null || true
        kurtosis clean -a 2>/dev/null || true
    fi

    docker system prune -af --volumes 2>/dev/null || true

    log "Teardown complete."
    exit $exit_code
}
trap cleanup EXIT

# --- Pre-flight ---
log "Pre-flight checks..."
for cmd in docker git jq curl bc cast kurtosis; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Missing required tool: $cmd" >&2
        exit 1
    fi
done

# Verify docker compose v2.1+ (required for --profile support)
compose_version=$(docker compose version --short 2>/dev/null || echo "0.0.0")
compose_major=$(echo "$compose_version" | cut -d. -f1)
compose_minor=$(echo "$compose_version" | cut -d. -f2)
if [[ "$compose_major" -lt 2 ]] || [[ "$compose_major" -eq 2 && "$compose_minor" -lt 1 ]]; then
    echo "docker compose >= 2.1 required (found: $compose_version)" >&2
    exit 1
fi
log "docker compose version: $compose_version"

# Clean any leftover state from previous runs
log "Cleaning leftover state..."
./remove-surge-full.sh \
    --remove-l1-devnet true \
    --remove-l2-stack true \
    --remove-relayers true \
    --remove-data true \
    --remove-configs true \
    --remove-env true \
    --mode silence \
    --force 2>/dev/null || true

docker network rm surge-network 2>/dev/null || true
kurtosis enclave rm surge-devnet --force 2>/dev/null || true
kurtosis clean -a 2>/dev/null || true

# Create fresh network
docker network create surge-network 2>/dev/null || true

# --- Deploy ---
log "Deploying full stack..."
./deploy-surge-full.sh \
    --environment devnet \
    --deploy-devnet true \
    --deployment local \
    --start-relayers true \
    --force

log "Deploy completed successfully."

# --- Health checks ---
log "Running health checks..."
"$SCRIPT_DIR/ci-health-check.sh"

log "E2E pipeline passed."
