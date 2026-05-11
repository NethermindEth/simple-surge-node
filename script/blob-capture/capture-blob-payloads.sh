#!/bin/bash
#
# capture-blob-payloads.sh — drops a transparent HTTP recording proxy between
# Catalyst and Raiko, points Catalyst at it, then tails Catalyst + Raiko logs
# in parallel. Captures the full request/response body bytes (base64-safe) so
# you can compare what Catalyst sent vs what Raiko received.
#
# Usage:
#   ./script/blob-capture/capture-blob-payloads.sh start      # set up + start
#   ./script/blob-capture/capture-blob-payloads.sh stop       # tear down + restore
#   ./script/blob-capture/capture-blob-payloads.sh status     # show running state
#   ./script/blob-capture/capture-blob-payloads.sh tail       # follow exchanges.jsonl
#
# Output goes to ./logs/blob-capture-YYYYMMDD-HHMMSS/:
#   exchanges.jsonl   — one JSON record per Catalyst→Raiko HTTP exchange
#   catalyst.log      — full container stderr+stdout
#   raiko.log         — full container stderr+stdout
#   summary.txt       — one-liner per exchange (method/path/status/sizes)
#
# Implementation notes:
# - Uses python:3-alpine to run blob_proxy.py — no host python deps needed.
# - The proxy listens on host port 18080 and forwards to whatever Catalyst's
#   original RAIKO_HOST_ZKVM was set to (read from .env once at start).
# - Catalyst is recreated with RAIKO_HOST_ZKVM=http://host.docker.internal:18080
#   for the duration of the capture; `stop` restores the original value.
# - Idempotent: re-running `start` while already running picks up where it is.

set -euo pipefail

cd "$(dirname "$0")/../.."
HERE="$(pwd)"

ENV_FILE="${HERE}/.env"
SCRIPT_DIR="${HERE}/script/blob-capture"
PROXY_NAME="surge-blob-proxy"
PROXY_LISTEN_PORT=18080
STATE_FILE="${HERE}/.blob-capture.state"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
log()    { printf '[blob-capture] %s\n' "$*"; }

require_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        red "$ENV_FILE not found — run from the simple-surge-node root after a deploy."
        exit 1
    fi
}

read_env_var() {
    grep -E "^${1}=" "$ENV_FILE" | tail -n1 | cut -d= -f2-
}

write_env_var() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i.bak "s|^${key}=.*|${key}=${val}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
}

start() {
    require_env

    if [[ -f "$STATE_FILE" ]]; then
        yellow "Capture already running. Stop it first or run \`status\`."
        cat "$STATE_FILE"
        exit 1
    fi

    local original_url
    original_url="$(read_env_var RAIKO_HOST_ZKVM)"
    if [[ -z "$original_url" ]]; then
        red "RAIKO_HOST_ZKVM is empty in .env — nothing to proxy to."
        exit 1
    fi
    if [[ "$original_url" == *":${PROXY_LISTEN_PORT}"* ]]; then
        red "RAIKO_HOST_ZKVM already points at the proxy port. Did a previous capture leave state behind? Run stop, then start."
        exit 1
    fi

    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local out_dir="${HERE}/logs/blob-capture-${ts}"
    mkdir -p "$out_dir"

    log "Capturing into ${out_dir/${HERE}\//}"
    log "Original RAIKO_HOST_ZKVM: ${original_url}"

    # 1. Start the proxy container.
    docker rm -f "$PROXY_NAME" >/dev/null 2>&1 || true
    docker run -d \
        --name "$PROXY_NAME" \
        --network surge-network \
        -p "${PROXY_LISTEN_PORT}:${PROXY_LISTEN_PORT}" \
        -e LISTEN="0.0.0.0:${PROXY_LISTEN_PORT}" \
        -e UPSTREAM="${original_url}" \
        -e OUT="/captures/exchanges.jsonl" \
        -v "${SCRIPT_DIR}/blob_proxy.py:/app/blob_proxy.py:ro" \
        -v "${out_dir}:/captures" \
        --add-host=host.docker.internal:host-gateway \
        python:3-alpine \
        python3 /app/blob_proxy.py >/dev/null
    sleep 1
    if ! docker ps --format '{{.Names}}' | grep -q "^${PROXY_NAME}$"; then
        red "Proxy failed to start. Logs:"
        docker logs "$PROXY_NAME" 2>&1 | tail -20
        exit 1
    fi
    green "Proxy up: ${PROXY_NAME} on host port ${PROXY_LISTEN_PORT} → ${original_url}"

    # 2. Repoint Catalyst at the proxy and recreate.
    write_env_var RAIKO_HOST_ZKVM "http://host.docker.internal:${PROXY_LISTEN_PORT}"
    log "Recreating catalyst with new RAIKO_HOST_ZKVM..."
    set -a; source "$ENV_FILE"; [[ -f "${HERE}/.privacy.env" ]] && source "${HERE}/.privacy.env"; set +a
    docker compose -f "${HERE}/docker-compose.yml" --profile catalyst up -d --force-recreate catalyst >/dev/null

    # 3. Tail container logs in the background.
    docker logs -f l2-catalyst-node     > "${out_dir}/catalyst.log" 2>&1 &
    local cat_pid=$!
    docker logs -f l2-raiko-zk-client   > "${out_dir}/raiko.log"    2>&1 &
    local rai_pid=$!

    cat > "$STATE_FILE" <<EOF
out_dir=${out_dir}
original_raiko=${original_url}
catalyst_log_pid=${cat_pid}
raiko_log_pid=${rai_pid}
proxy_container=${PROXY_NAME}
EOF

    green "Capture started."
    log "  exchanges:  tail -f ${out_dir/${HERE}\//}/exchanges.jsonl"
    log "  catalyst:   tail -f ${out_dir/${HERE}\//}/catalyst.log"
    log "  raiko:      tail -f ${out_dir/${HERE}\//}/raiko.log"
    log "  stop:       $0 stop"
}

stop() {
    if [[ ! -f "$STATE_FILE" ]]; then
        yellow "No active capture state at $STATE_FILE."
        exit 0
    fi
    # shellcheck disable=SC1090
    source "$STATE_FILE"

    log "Stopping log tails..."
    kill "${catalyst_log_pid}" 2>/dev/null || true
    kill "${raiko_log_pid}"    2>/dev/null || true

    log "Restoring RAIKO_HOST_ZKVM=${original_raiko}"
    write_env_var RAIKO_HOST_ZKVM "${original_raiko}"

    log "Recreating catalyst with restored URL..."
    set -a; source "$ENV_FILE"; [[ -f "${HERE}/.privacy.env" ]] && source "${HERE}/.privacy.env"; set +a
    docker compose -f "${HERE}/docker-compose.yml" --profile catalyst up -d --force-recreate catalyst >/dev/null

    log "Stopping proxy container ${proxy_container}..."
    docker rm -f "${proxy_container}" >/dev/null 2>&1 || true

    rm -f "$STATE_FILE"
    green "Capture stopped. Output: ${out_dir/${HERE}\//}"
}

status() {
    if [[ ! -f "$STATE_FILE" ]]; then
        yellow "No active capture."
        exit 0
    fi
    log "State:"
    sed 's/^/  /' "$STATE_FILE"
    log "Proxy container:"
    docker ps --filter "name=${PROXY_NAME}" --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

tail_exchanges() {
    if [[ ! -f "$STATE_FILE" ]]; then
        red "No active capture."; exit 1
    fi
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    exec tail -f "${out_dir}/exchanges.jsonl"
}

case "${1:-start}" in
    start)  start ;;
    stop)   stop ;;
    status) status ;;
    tail)   tail_exchanges ;;
    *)
        echo "Usage: $0 {start|stop|status|tail}"
        exit 2
        ;;
esac