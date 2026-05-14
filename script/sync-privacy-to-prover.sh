#!/bin/bash
#
# sync-privacy-to-prover.sh — copy the Surge privacy bundle from this L2 VM
# to the Raiko prover VM and (optionally) rebuild raiko-zk so the guest picks
# up the new SURGE_PRIVACY_*_HASH values.
#
# Why a script: the privacy mode needs four values consistent on both ends —
# two hashes baked into the guest ELF at compile time, two plaintext keys
# loaded by the host at runtime. Drifting any one of them silently breaks
# proof generation with "privacy dispatch failed: Truncated". This script
# keeps the four in lockstep.
#
# Usage:
#   ./script/sync-privacy-to-prover.sh user@prover-host       # two-VM
#   ./script/sync-privacy-to-prover.sh user@prover-host <raiko-dir>
#   ./script/sync-privacy-to-prover.sh --print                # dump only
#   ./script/sync-privacy-to-prover.sh --rebuild user@prover-host  # sync + rebuild
#   ./script/sync-privacy-to-prover.sh --local                # same-VM (raiko submodule)
#   ./script/sync-privacy-to-prover.sh --local --rebuild      # same-VM + rebuild
#
# Modes:
#   Two-VM: prover host accessed over SSH. Default. Assumes the prover VM has
#           raiko cloned at $PROVER_RAIKO_DIR (default ~/raiko) and you have
#           SSH key auth.
#   Same-VM (--local): raiko lives at ./raiko in this repo (a submodule).
#           No SSH; everything happens against the local raiko/docker/.env.
#           Use this after deploy-prover.sh has set up raiko on the same host.
#
# Idempotent: re-running refreshes the four lines in
# <raiko>/docker/.env (any other settings there are preserved).

set -euo pipefail

cd "$(dirname "$0")/.."
HERE="$(pwd)"

PRIVACY_ENV="${HERE}/.privacy.env"
# Default path on the prover VM. Matches deploy-prover.sh's layout: the user
# clones simple-surge-node and uses its raiko submodule, so raiko lives at
# $HOME/simple-surge-node/raiko, not the standalone $HOME/raiko clone the
# original two-VM docs assumed.
DEFAULT_RAIKO_DIR="\$HOME/simple-surge-node/raiko"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
log()    { printf '[sync-privacy] %s\n' "$*"; }

require_bundle() {
    if [[ ! -f "$PRIVACY_ENV" ]]; then
        red ".privacy.env not found at $PRIVACY_ENV"
        red "Run ./deploy-surge-full.sh first (or rerun with a fresh deploy)."
        exit 1
    fi
}

# Pull just the four lines we need (skip comments and SURGE_PRIVACY_MODE=true).
# The prover VM's .env owns the MODE flag because the user opts in there.
extract_lines() {
    grep -E '^SURGE_PRIVACY_(SYMMETRIC_KEY|FI_PRIVKEY)(_HASH)?=' "$PRIVACY_ENV" \
        | sort -u
}

print_only() {
    require_bundle
    log "Lines to paste into <prover-host>:~/raiko/docker/.env"
    echo "---"
    extract_lines
    echo "---"
    yellow "Don't forget to also set SURGE_PRIVACY_MODE=true on the prover."
}

# Build a small sed-driven replacement so we update lines in place if present,
# append otherwise. Run as a single ssh round-trip via a heredoc.
sync_to_prover() {
    local prover_host="$1"
    local raiko_dir="${2:-$DEFAULT_RAIKO_DIR}"
    require_bundle

    log "Target: ${prover_host}:${raiko_dir}/docker/.env"

    # Build the four lines locally so we can pass them inline to ssh.
    local -a lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done < <(extract_lines)
    if [[ ${#lines[@]} -eq 0 ]]; then
        red "No SURGE_PRIVACY_* lines found in $PRIVACY_ENV"
        exit 1
    fi

    # Serialise the lines as a newline-joined string and feed to ssh via stdin.
    # Why not via inline env var (LINES="$joined" ssh ... bash -s): embedded
    # newlines in $joined break ssh's command-line parsing — the remote shell
    # sees the first line of LINES as part of its argv, then fails before
    # bash -s reads the heredoc body with `RAIKO_DIR: unbound variable`.
    # Stdin is unambiguous: the remote bash reads the script from stdin and
    # the privacy lines come in via a temp env file on the remote side.
    local joined; joined=$(printf '%s\n' "${lines[@]}")

    # Use a tempfile on the prover so the remote shell reads the lines
    # independently of stdin (which carries the script body itself).
    local remote_tmp
    remote_tmp=$(ssh "$prover_host" "mktemp")
    if [[ -z "$remote_tmp" ]]; then
        red "Failed to create tempfile on $prover_host"; exit 1
    fi
    # shellcheck disable=SC2029
    printf '%s' "$joined" | ssh "$prover_host" "cat > $remote_tmp"

    # shellcheck disable=SC2029
    ssh "$prover_host" RAIKO_DIR="$raiko_dir" REMOTE_TMP="$remote_tmp" bash -s <<'REMOTE'
set -euo pipefail
cd "${RAIKO_DIR/#~/$HOME}"
if [[ ! -f docker/.env ]]; then
    if [[ -f docker/.env.sample.zk ]]; then
        cp docker/.env.sample.zk docker/.env
        echo "[prover] created docker/.env from sample"
    else
        echo "[prover] docker/.env.sample.zk missing — raiko clone might be stale; cannot bootstrap"
        rm -f "$REMOTE_TMP"
        exit 1
    fi
fi

# Replace-or-append each KEY=VALUE line. Read the lines from the tempfile we
# scp'd above — avoids the multi-line-env-var-via-ssh bug.
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    if grep -qE "^${key}=" docker/.env; then
        sed -i.bak -E "s|^${key}=.*|${line}|" docker/.env && rm -f docker/.env.bak
    else
        printf '%s\n' "$line" >> docker/.env
    fi
done < "$REMOTE_TMP"
rm -f "$REMOTE_TMP"

# Don't auto-flip SURGE_PRIVACY_MODE; let the operator opt in explicitly.
echo "[prover] privacy hashes + keys synced into $(pwd)/docker/.env"
echo "[prover] set SURGE_PRIVACY_MODE=true in that file when you're ready, then rebuild."
REMOTE

    green "Sync complete."
    yellow "Next on the prover VM:"
    yellow "  1. Edit ${raiko_dir}/docker/.env → set SURGE_PRIVACY_MODE=true"
    yellow "  2. Rebuild raiko-zk so the guest picks up the new hashes:"
    yellow "       cd ${raiko_dir}"
    yellow "       docker compose -f docker/docker-compose-zk.yml up -d --build"
    yellow "  (Or pass --rebuild here to do steps 1+2 over SSH.)"
}

# Optional one-step variant: flip MODE=true, rebuild guest ELFs (NOT the whole
# host image — that's prebuilt by CI), then recreate raiko-zk over SSH.
sync_and_rebuild() {
    local prover_host="$1"
    local raiko_dir="${2:-$DEFAULT_RAIKO_DIR}"
    sync_to_prover "$prover_host" "$raiko_dir"

    log "Flipping SURGE_PRIVACY_MODE=true and rebuilding guest ELFs on $prover_host ..."
    # shellcheck disable=SC2029
    ssh "$prover_host" RAIKO_DIR="$raiko_dir" bash -s <<'REMOTE'
set -euo pipefail
cd "${RAIKO_DIR/#~/$HOME}"

# 1. Flip SURGE_PRIVACY_MODE=true.
if grep -qE '^SURGE_PRIVACY_MODE=' docker/.env; then
    sed -i.bak -E 's|^SURGE_PRIVACY_MODE=.*|SURGE_PRIVACY_MODE=true|' docker/.env && rm -f docker/.env.bak
else
    echo 'SURGE_PRIVACY_MODE=true' >> docker/.env
fi
echo "[prover] SURGE_PRIVACY_MODE=true"

# 2. Recompile ONLY the guest ELFs with the new hashes. The host image is
#    pulled from CI — rotating keys doesn't need a host rebuild because the
#    host's hash check is a no-op when option_env!() is empty (which the CI
#    build always is). Saves ~5 minutes per rotation.
if [[ ! -x ./script/build-guest-with-hashes.sh ]]; then
    echo "[prover] ERROR: ./script/build-guest-with-hashes.sh missing — pull a newer raiko HEAD"
    exit 1
fi
echo "[prover] rebuilding guest ELFs (host image stays prebuilt) ..."
./script/build-guest-with-hashes.sh

# 3. Recreate raiko-zk so the bind-mounted ELFs are picked up.
echo "[prover] recreating raiko-zk ..."
set -a; source docker/.env; set +a
docker compose -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk
docker compose -f docker/docker-compose-zk.yml ps
REMOTE

    # Rebuilding the guest with new privacy hashes changes the ZisK batch
    # vkey. Catalyst attaches that vkey to every proof; ZiskVerifier on L1
    # checks _isTrustedProgram[vkey] and reverts with ZISK_INVALID_PROGRAM_VKEY()
    # (selector 0x7f1ebce8) when the new vkey isn't registered yet.
    # setup-zisk.sh only runs once during the initial deploy-surge-full.sh,
    # before privacy was enabled — so it trusts the pre-privacy vkey only.
    # Refresh the trust list here.
    refresh_zisk_vkey_trust "$prover_host"

    green "Prover ready with privacy mode enabled."
    yellow "Verify with: ssh $prover_host 'curl -s localhost:8080/guest_data | jq'"
}

# Poll the prover's /guest_data for the freshly-rebuilt batch vkey, then run
# setProgramTrusted(<new_vkey>, true) on L1's ZiskVerifier so on-chain
# verification accepts proofs from the rebuilt guest. Reads ZiskVerifier
# address, L1 RPC, and the deployer private key from the local .env (this
# script runs on the L2 stack VM, which has them).
refresh_zisk_vkey_trust() {
    local prover_host="$1"

    if [[ ! -f "${HERE}/.env" ]]; then
        yellow "${HERE}/.env not found — skipping on-chain vkey re-registration."
        yellow "Re-register manually:"
        yellow "  cast send <ZISK_VERIFIER> \"setProgramTrusted(bytes32,bool)\" <new_vkey> true \\"
        yellow "    --private-key \$PRIVATE_KEY --rpc-url \$L1_ENDPOINT_HTTP"
        return 0
    fi

    # Load .env values without polluting the calling shell beyond the function.
    local zisk_verifier private_key l1_rpc
    zisk_verifier=$(grep -E '^REALTIME_ZISK_VERIFIER=' "${HERE}/.env" | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")
    private_key=$(grep -E '^PRIVATE_KEY=' "${HERE}/.env" | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")
    l1_rpc=$(grep -E '^L1_ENDPOINT_HTTP_EXTERNAL=' "${HERE}/.env" | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")
    [[ -z "$l1_rpc" ]] && l1_rpc=$(grep -E '^L1_ENDPOINT_HTTP=' "${HERE}/.env" | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")

    if [[ -z "$zisk_verifier" || "$zisk_verifier" == "0x0000000000000000000000000000000000000000" ]]; then
        yellow "REALTIME_ZISK_VERIFIER is zero/empty in .env — mock-mode deploy, no vkey trust to update."
        return 0
    fi
    if [[ -z "$private_key" ]]; then
        red "PRIVATE_KEY missing in .env — can't update vkey trust on-chain."
        return 1
    fi
    if [[ -z "$l1_rpc" ]]; then
        red "L1_ENDPOINT_HTTP (and _EXTERNAL) missing in .env — can't reach L1 RPC."
        return 1
    fi
    if ! command -v cast >/dev/null 2>&1; then
        red "cast (Foundry) not on PATH — install Foundry or run the cast send below manually."
        return 1
    fi

    log "Polling $prover_host:8080/guest_data for the new vkey ..."
    # Poll because guest_data only returns the vkey after raiko-zk has warmed
    # up post-recreate (single-GPU: up to ~16 min; multi-GPU: ~1 min).
    local new_vkey="" elapsed=0 timeout=1800
    local start; start=$(date +%s)
    while (( elapsed < timeout )); do
        # shellcheck disable=SC2029
        local body; body=$(ssh "$prover_host" "curl -s --max-time 10 http://localhost:8080/guest_data" 2>/dev/null || echo "")
        if [[ -n "$body" ]] && echo "$body" | jq -e '.zisk.batch_vkey' >/dev/null 2>&1; then
            new_vkey=$(echo "$body" | jq -r '.zisk.batch_vkey')
            log "Got new vkey: $new_vkey"
            break
        fi
        sleep 10
        elapsed=$(( $(date +%s) - start ))
    done
    if [[ -z "$new_vkey" ]]; then
        red "Timed out (${timeout}s) waiting for prover's new vkey. Recover manually:"
        red "  ssh $prover_host 'curl -s localhost:8080/guest_data | jq -r .zisk.batch_vkey'"
        red "  cast send $zisk_verifier \"setProgramTrusted(bytes32,bool)\" <vkey> true \\"
        red "    --private-key \$PRIVATE_KEY --rpc-url $l1_rpc"
        return 1
    fi

    # Skip the broadcast if the vkey is already trusted (re-runs are common).
    local already
    if already=$(cast call "$zisk_verifier" "isProgramTrusted(bytes32)(bool)" "$new_vkey" --rpc-url "$l1_rpc" 2>/dev/null); then
        if [[ "$already" == "true" ]]; then
            log "vkey $new_vkey already trusted on $zisk_verifier — skipping setProgramTrusted"
            return 0
        fi
    fi

    log "Registering new vkey on ZiskVerifier ($zisk_verifier) ..."
    if ! cast send "$zisk_verifier" "setProgramTrusted(bytes32,bool)" "$new_vkey" true \
            --private-key "$private_key" --rpc-url "$l1_rpc" >/dev/null; then
        red "cast send setProgramTrusted failed. Run manually:"
        red "  cast send $zisk_verifier \"setProgramTrusted(bytes32,bool)\" $new_vkey true \\"
        red "    --private-key \$PRIVATE_KEY --rpc-url $l1_rpc"
        return 1
    fi
    green "Trusted new ZisK vkey on $zisk_verifier"
}

# ─── Same-VM (--local) path ──────────────────────────────────────────────────
# When raiko is a submodule of this repo (./raiko), there's no need for SSH or
# scp. Apply the lines directly to ./raiko/docker/.env and optionally run the
# guest rebuild + recreate locally.
sync_local() {
    require_bundle
    local raiko_dir="${HERE}/raiko"
    if [[ ! -f "${raiko_dir}/docker/.env" ]]; then
        if [[ -f "${raiko_dir}/docker/.env.sample.zk" ]]; then
            cp "${raiko_dir}/docker/.env.sample.zk" "${raiko_dir}/docker/.env"
            log "Created ${raiko_dir}/docker/.env from sample"
        else
            red "${raiko_dir} doesn't look like a real raiko clone."
            red "  → run ./deploy-prover.sh first, or `git submodule update --init raiko`."
            exit 1
        fi
    fi

    log "Target: ${raiko_dir}/docker/.env"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key="${line%%=*}"
        if grep -qE "^${key}=" "${raiko_dir}/docker/.env"; then
            sed -i.bak -E "s|^${key}=.*|${line}|" "${raiko_dir}/docker/.env" && rm -f "${raiko_dir}/docker/.env.bak"
        else
            printf '%s\n' "$line" >> "${raiko_dir}/docker/.env"
        fi
    done < <(extract_lines)
    green "Privacy hashes + keys synced into ${raiko_dir}/docker/.env"
    yellow "Don't auto-flip SURGE_PRIVACY_MODE — pass --rebuild to opt in, or edit by hand."
}

sync_local_and_rebuild() {
    sync_local
    local raiko_dir="${HERE}/raiko"
    log "Flipping SURGE_PRIVACY_MODE=true and rebuilding guest ELFs locally ..."
    if grep -qE '^SURGE_PRIVACY_MODE=' "${raiko_dir}/docker/.env"; then
        sed -i.bak -E 's|^SURGE_PRIVACY_MODE=.*|SURGE_PRIVACY_MODE=true|' "${raiko_dir}/docker/.env"
        rm -f "${raiko_dir}/docker/.env.bak"
    else
        echo "SURGE_PRIVACY_MODE=true" >> "${raiko_dir}/docker/.env"
    fi
    if [[ ! -x "${raiko_dir}/script/build-guest-with-hashes.sh" ]]; then
        red "raiko/script/build-guest-with-hashes.sh missing — bump the raiko submodule."
        exit 1
    fi
    (cd "${raiko_dir}" && ./script/build-guest-with-hashes.sh) || { red "Guest rebuild failed."; exit 1; }
    log "Recreating raiko-zk ..."
    set -a
    # shellcheck disable=SC1091
    source "${raiko_dir}/docker/.env"
    set +a
    (cd "${raiko_dir}" && docker compose -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk)
    green "Local raiko-zk ready with privacy mode enabled."
    yellow "Verify with: curl -s localhost:8080/guest_data | jq"
}

# ─── Flag dispatch ──────────────────────────────────────────────────────────
# Parse all flags in any order: --local --rebuild user@host ...
local_mode=""
rebuild_mode=""
print_mode=""
positional=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)    local_mode="true"; shift ;;
        --rebuild)  rebuild_mode="true"; shift ;;
        --print)    print_mode="true"; shift ;;
        *)          positional+=("$1"); shift ;;
    esac
done
set -- "${positional[@]}"

if [[ "$print_mode" == "true" ]]; then
    print_only
    exit 0
fi

if [[ "$local_mode" == "true" ]]; then
    if [[ "$rebuild_mode" == "true" ]]; then
        sync_local_and_rebuild
    else
        sync_local
    fi
    exit 0
fi

# Default: two-VM (SSH).
if [[ ${#positional[@]} -eq 0 ]]; then
    red "usage: $0 user@prover-host [raiko-dir]                   (two-VM)"
    red "       $0 --rebuild user@prover-host [raiko-dir]          (two-VM, rebuild)"
    red "       $0 --local                                          (same-VM)"
    red "       $0 --local --rebuild                                (same-VM, rebuild)"
    red "       $0 --print                                          (dump bundle lines)"
    exit 2
fi

if [[ "$rebuild_mode" == "true" ]]; then
    sync_and_rebuild "${positional[0]}" "${positional[1]:-$DEFAULT_RAIKO_DIR}"
else
    sync_to_prover  "${positional[0]}" "${positional[1]:-$DEFAULT_RAIKO_DIR}"
fi