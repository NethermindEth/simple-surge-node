#!/bin/bash
set -euo pipefail

L1_RPC="${L1_RPC:-http://localhost:32003}"
L2_RPC="${L2_RPC:-http://localhost:8547}"
MAX_RETRIES="${CI_HEALTH_MAX_RETRIES:-30}"
RETRY_INTERVAL="${CI_HEALTH_RETRY_INTERVAL:-10}"

# Source .env for deployment variables (contract addresses, chain config)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

log() { echo "[E2E] $(date '+%H:%M:%S') $1"; }

dump_bridge_logs() {
    echo "[E2E] === All container logs ===" >&2
    docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null >&2 || true
    while IFS= read -r container; do
        [[ -z "$container" ]] && continue
        echo "[E2E] --- $container (last 50 lines) ---" >&2
        docker logs --tail 50 "$container" 2>&1 >&2 || true
    done < <(docker ps --format "{{.Names}}" 2>/dev/null)
    echo "[E2E] === End container logs ===" >&2
}

fail() { echo "[E2E] FAIL: $1" >&2; exit 1; }

check_rpc() {
    local name="$1" url="$2"
    local result
    result=$(curl -sf -X POST "$url" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null) || return 1
    echo "$result" | jq -e '.result' >/dev/null 2>&1 || return 1
    local block_hex
    block_hex=$(echo "$result" | jq -r '.result')
    local block_num=$((block_hex))
    log "$name block number: $block_num"
    return 0
}

wait_for_l2_blocks() {
    local attempt=0
    log "Waiting for L2 to produce blocks..."
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        if check_rpc "L2" "$L2_RPC"; then
            local result
            result=$(curl -sf -X POST "$L2_RPC" \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
            local block_hex
            block_hex=$(echo "$result" | jq -r '.result')
            local block_num=$((block_hex))
            if [[ $block_num -gt 0 ]]; then
                log "L2 is producing blocks (block $block_num)."
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        log "Attempt $attempt/$MAX_RETRIES - L2 not ready yet, waiting ${RETRY_INTERVAL}s..."
        sleep "$RETRY_INTERVAL"
    done
    fail "L2 did not produce blocks within $((MAX_RETRIES * RETRY_INTERVAL))s"
}

# Step 1: Check L1
log "Checking L1 RPC ($L1_RPC)..."
check_rpc "L1" "$L1_RPC" || fail "L1 RPC not responding"

# Step 2: Check L2 blocks
log "Checking L2 RPC ($L2_RPC)..."
wait_for_l2_blocks

# Step 3: Check critical containers
log "Checking container health..."
for container in l2-nethermind-execution-client l2-taiko-consensus-client l2-catalyst-node; do
    status=$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || echo "not found")
    if [[ "$status" != "running" ]]; then
        fail "Container $container is not running (status: $status)"
    fi
    log "Container $container: running"
done

# Step 4: Verify L2 chain ID
log "Verifying L2 chain ID..."
chain_result=$(curl -sf -X POST "$L2_RPC" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}')
chain_id_hex=$(echo "$chain_result" | jq -r '.result')
chain_id=$((chain_id_hex))
expected_chain_id="${L2_CHAIN_ID:-}"
if [[ -n "$expected_chain_id" && "$chain_id" != "$expected_chain_id" ]]; then
    fail "L2 chain ID mismatch: got $chain_id, expected $expected_chain_id"
fi
log "L2 chain ID: $chain_id (expected: ${expected_chain_id:-not set})"

# Step 5: Verify deployment artifacts
log "Checking deployment artifacts..."
for artifact in deployment/deploy_l1.json deployment/deploy_l1_pacaya.json deployment/surge_genesis.json deployment/surge_chainspec.json; do
    if [[ ! -f "$artifact" ]]; then
        fail "Missing deployment artifact: $artifact"
    fi
    log "Artifact $artifact: present"
done

# Step 6: Verify Shasta fork activation
log "Checking Shasta fork activation..."
if [[ -n "${SHASTA_SURGE_INBOX:-}" && -n "${L1_RPC:-}" ]]; then
    activation_ts=$(cast call "$SHASTA_SURGE_INBOX" "activationTimestamp()(uint48)" --rpc-url "$L1_RPC" 2>/dev/null || echo "")
    if [[ -z "$activation_ts" || "$activation_ts" == "0" ]]; then
        fail "Shasta fork not activated (activationTimestamp is 0 or empty on SurgeInbox $SHASTA_SURGE_INBOX)"
    fi
    log "Shasta fork activated at timestamp: $activation_ts"
else
    log "Skipping fork activation check (SHASTA_SURGE_INBOX or L1_RPC not set)"
fi

# Step 7: Check relayer containers
log "Checking relayer containers..."
for container in relayer-l1-processor relayer-l1-indexer relayer-l1-api relayer-l2-processor relayer-l2-indexer relayer-l2-api; do
    status=$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || echo "not found")
    if [[ "$status" == "running" ]]; then
        log "Container $container: running"
    else
        log "Container $container: $status (non-critical)"
    fi
done

# Step 8: L1->L2 bridge delivery verification
log "Verifying L1->L2 bridge delivery..."
if [[ -n "${SHASTA_BRIDGE:-}" && -n "${PUBLIC_KEY:-}" && -n "${PRIVATE_KEY:-}" && -n "${L2_CHAIN_ID:-}" ]]; then
    BRIDGE_AMOUNT_WEI="10000000000000000"
    BRIDGE_FEE_WEI="10000000000000000"
    BRIDGE_GAS_LIMIT="1000000"
    BRIDGE_TOTAL_WEI=$(echo "$BRIDGE_AMOUNT_WEI + $BRIDGE_FEE_WEI" | bc)
    BRIDGE_ZERO="0x0000000000000000000000000000000000000000"

    # Use a fresh recipient address so balance check is not affected by other
    # activity on the deployer key (relayer, prover, etc.)
    l2_recipient=$(cast wallet new --json 2>/dev/null | jq -r '.[0].address')
    log "L1->L2 recipient: $l2_recipient"

    # Debug: log sender and recipient balances before submission
    sender_l1_bal=$(cast balance "$PUBLIC_KEY" --rpc-url "$L1_RPC" 2>/dev/null || echo "N/A")
    recipient_l2_bal=$(cast balance "$l2_recipient" --rpc-url "$L2_RPC" 2>/dev/null || echo "N/A")
    log "Before L1->L2 bridge: sender L1 balance=$sender_l1_bal wei, recipient L2 balance=$recipient_l2_bal wei"

    # Send L1->L2 bridge tx (with retries for nonce races)
    log "Sending L1->L2 bridge tx (0.01 ETH) to $l2_recipient..."
    bridge_sent=false
    for attempt in 1 2 3 4 5; do
        if cast send "$SHASTA_BRIDGE" \
            "sendMessage((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes))" \
            "(0,$BRIDGE_FEE_WEI,$BRIDGE_GAS_LIMIT,$BRIDGE_ZERO,0,$l2_recipient,$L2_CHAIN_ID,$l2_recipient,$l2_recipient,$BRIDGE_AMOUNT_WEI,0x)" \
            --value "$BRIDGE_TOTAL_WEI" \
            --rpc-url "$L1_RPC" \
            --private-key "$PRIVATE_KEY"; then
            bridge_sent=true
            break
        fi
        log "L1->L2 bridge tx attempt $attempt failed, retrying in 5s..."
        sleep 5
    done
    if [[ "$bridge_sent" != "true" ]]; then
        fail "L1->L2 bridge delivery tx failed to submit after 5 attempts"
    fi
    log "Bridge tx submitted, waiting for delivery on L2..."

    # Poll fresh recipient L2 balance until it becomes > 0
    delivery_timeout="${CI_BRIDGE_DELIVERY_TIMEOUT:-1200}"
    delivery_interval=5
    delivery_elapsed=0
    delivered=false

    while [[ $delivery_elapsed -lt $delivery_timeout ]]; do
        sleep "$delivery_interval"
        delivery_elapsed=$((delivery_elapsed + delivery_interval))
        l2_balance=$(cast balance "$l2_recipient" --rpc-url "$L2_RPC" 2>/dev/null || echo "")

        # Skip if RPC unavailable
        if [[ -z "$l2_balance" ]]; then
            log "Waiting for L1->L2 delivery... ${delivery_elapsed}/${delivery_timeout}s (L2 RPC unavailable)"
            continue
        fi

        if [[ "$l2_balance" != "0" ]]; then
            log "L1->L2 bridge delivered after ${delivery_elapsed}s (recipient balance: $l2_balance wei)"
            delivered=true
            break
        fi
        if (( delivery_elapsed % 60 == 0 )); then
            sender_l1_now=$(cast balance "$PUBLIC_KEY" --rpc-url "$L1_RPC" 2>/dev/null || echo "N/A")
            recipient_l2_now=$(cast balance "$l2_recipient" --rpc-url "$L2_RPC" 2>/dev/null || echo "N/A")
            log "Waiting for L1->L2 delivery... ${delivery_elapsed}/${delivery_timeout}s (sender L1 bal=$sender_l1_now, recipient L2 bal=$recipient_l2_now)"
        else
            log "Waiting for L1->L2 delivery... ${delivery_elapsed}/${delivery_timeout}s"
        fi
    done

    if [[ "$delivered" != "true" ]]; then
        dump_bridge_logs
        fail "L1->L2 bridge delivery not confirmed within ${delivery_timeout}s (recipient balance still 0)"
    fi
else
    log "Skipping L1->L2 delivery check (missing SHASTA_BRIDGE, PUBLIC_KEY, PRIVATE_KEY, or L2_CHAIN_ID)"
fi

# Step 9: L2->L1 bridge delivery verification
log "Verifying L2->L1 bridge delivery..."
if [[ -n "${L2_BRIDGE:-}" && -n "${PUBLIC_KEY:-}" && -n "${PRIVATE_KEY:-}" && -n "${L1_CHAIN_ID:-}" ]]; then
    L2L1_BRIDGE_AMOUNT_WEI="10000000000000000"
    L2L1_BRIDGE_FEE_WEI="10000000000000000"
    L2L1_BRIDGE_GAS_LIMIT="1000000"
    L2L1_BRIDGE_TOTAL_WEI=$(echo "$L2L1_BRIDGE_AMOUNT_WEI + $L2L1_BRIDGE_FEE_WEI" | bc)
    L2L1_BRIDGE_ZERO="0x0000000000000000000000000000000000000000"

    # Use a fresh recipient address so balance check is not affected by other
    # activity on the deployer key (prover gas spending, etc.)
    l1_recipient=$(cast wallet new --json 2>/dev/null | jq -r '.[0].address')
    log "L2->L1 recipient: $l1_recipient"

    # Debug: log sender and recipient balances before submission
    sender_l2_bal=$(cast balance "$PUBLIC_KEY" --rpc-url "$L2_RPC" 2>/dev/null || echo "N/A")
    recipient_l1_bal=$(cast balance "$l1_recipient" --rpc-url "$L1_RPC" 2>/dev/null || echo "N/A")
    log "Before L2->L1 bridge: sender L2 balance=$sender_l2_bal wei, recipient L1 balance=$recipient_l1_bal wei"

    # Send L2->L1 bridge tx (with retries for nonce races)
    log "Sending L2->L1 bridge tx (0.01 ETH) to $l1_recipient..."
    l2l1_bridge_sent=false
    for attempt in 1 2 3 4 5; do
        if cast send "$L2_BRIDGE" \
            "sendMessage((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes))" \
            "(0,$L2L1_BRIDGE_FEE_WEI,$L2L1_BRIDGE_GAS_LIMIT,$L2L1_BRIDGE_ZERO,0,$l1_recipient,$L1_CHAIN_ID,$l1_recipient,$l1_recipient,$L2L1_BRIDGE_AMOUNT_WEI,0x)" \
            --value "$L2L1_BRIDGE_TOTAL_WEI" \
            --rpc-url "$L2_RPC" \
            --private-key "$PRIVATE_KEY"; then
            l2l1_bridge_sent=true
            break
        fi
        log "L2->L1 bridge tx attempt $attempt failed, retrying in 5s..."
        sleep 5
    done
    if [[ "$l2l1_bridge_sent" != "true" ]]; then
        fail "L2->L1 bridge delivery tx failed to submit after 5 attempts"
    fi
    log "L2->L1 bridge tx submitted, waiting for delivery on L1..."

    # Poll fresh recipient L1 balance until it becomes > 0
    l2l1_delivery_timeout="${CI_BRIDGE_DELIVERY_TIMEOUT:-1200}"
    l2l1_delivery_interval=5
    l2l1_delivery_elapsed=0
    l2l1_delivered=false

    while [[ $l2l1_delivery_elapsed -lt $l2l1_delivery_timeout ]]; do
        sleep "$l2l1_delivery_interval"
        l2l1_delivery_elapsed=$((l2l1_delivery_elapsed + l2l1_delivery_interval))
        l1_balance=$(cast balance "$l1_recipient" --rpc-url "$L1_RPC" 2>/dev/null || echo "")

        # Skip if RPC unavailable
        if [[ -z "$l1_balance" ]]; then
            log "Waiting for L2->L1 delivery... ${l2l1_delivery_elapsed}/${l2l1_delivery_timeout}s (L1 RPC unavailable)"
            continue
        fi

        if [[ "$l1_balance" != "0" ]]; then
            log "L2->L1 bridge delivered after ${l2l1_delivery_elapsed}s (recipient balance: $l1_balance wei)"
            l2l1_delivered=true
            break
        fi
        # Debug: log sender and recipient balances every 60s
        if (( l2l1_delivery_elapsed % 60 == 0 )); then
            sender_l2_now=$(cast balance "$PUBLIC_KEY" --rpc-url "$L2_RPC" 2>/dev/null || echo "N/A")
            recipient_l1_now=$(cast balance "$l1_recipient" --rpc-url "$L1_RPC" 2>/dev/null || echo "N/A")
            log "Waiting for L2->L1 delivery... ${l2l1_delivery_elapsed}/${l2l1_delivery_timeout}s (sender L2 bal=$sender_l2_now, recipient L1 bal=$recipient_l1_now)"
        else
            log "Waiting for L2->L1 delivery... ${l2l1_delivery_elapsed}/${l2l1_delivery_timeout}s"
        fi
    done

    if [[ "$l2l1_delivered" != "true" ]]; then
        dump_bridge_logs
        fail "L2->L1 bridge delivery not confirmed within ${l2l1_delivery_timeout}s (recipient balance still 0)"
    fi
else
    log "Skipping L2->L1 delivery check (missing L2_BRIDGE, PUBLIC_KEY, PRIVATE_KEY, or L1_CHAIN_ID)"
fi

log "All health checks passed."
