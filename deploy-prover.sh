#!/bin/bash
#
# deploy-prover.sh — set up a Raiko ZisK prover on a GPU host.
#
# Companion to deploy-surge-full.sh. Roles are explicit:
#   - deploy-surge-full.sh  : Kurtosis L1 + L2 contracts + Catalyst + Driver
#   - deploy-prover.sh      : Raiko ZisK prover (this script)
#
# Same-VM (single beefy machine): run both in sequence — prover first so
# Catalyst's readiness check at the end of deploy-surge-full.sh passes.
# Two-VM: each VM runs the relevant one; this script tells you which env vars
# the L2-side VM needs and prints the post-deploy `scp` for the chain spec.
#
# What this does:
#   1. Verify NVIDIA GPU + Docker present (real prover requires both).
#   2. raiko/script/install-zisk-deps.sh — apt deps, Rust, CUDA 12.x.
#      Idempotent: detects what's already present.
#   3. TARGET=zisk make install — download ZisK proving keys to ~/.zisk
#      (~150 GB; ZISK_DIR env override supported).
#   4. Copy docker/.env.sample.zk → docker/.env (skipped if .env exists).
#   5. (Optional, --privacy-mode) apply the L2-side privacy bundle to
#      docker/.env and run raiko/script/build-guest-with-hashes.sh so the
#      guest ELFs bake the hashes in. NEVER generates a bundle here — the
#      L2 stack VM is canonical (its deploy-surge-full.sh runs the keygen).
#      Bundle must already exist at ./.privacy.env (same-VM) or be passed
#      via --privacy-env <path> (two-VM, scp'd from L2 VM). Without
#      --privacy-mode the prebuilt image's empty-hash defaults are used
#      (privacy bypass).
#   6. docker compose -f docker/docker-compose-zk.yml up -d
#   7. Poll http://localhost:8080/guest_data until the vkey returns or the
#      timeout expires.

set -euo pipefail

cd "$(dirname "$0")"
HERE="$(pwd)"

# shellcheck source=helpers.sh
source "${HERE}/helpers.sh"

# ─── Flags ──────────────────────────────────────────────────────────────────
force=""
skip_install=""
skip_zisk_sdk=""
privacy_mode=""
privacy_env_path=""
raiko_dir="${HERE}/raiko"

show_help() {
    cat <<'EOF'
Usage:
  ./deploy-prover.sh [OPTIONS]

Sets up a Raiko ZisK prover on this host. Designed to be the prover-side
counterpart to deploy-surge-full.sh.

Options:
  -f, --force               Skip interactive prompts (CI / non-interactive).
  --skip-install            Skip apt + Rust + CUDA install (raiko's
                            install-zisk-deps.sh). Useful for re-runs.
  --skip-zisk-sdk           Skip `TARGET=zisk make install` (the 150 GB
                            proving-key download). Useful for re-runs.
  --privacy-mode            Enable Surge privacy mode using a bundle from the
                            L2 stack VM. Requires .privacy.env to exist —
                            either at ./.privacy.env (same-VM, written there
                            by deploy-surge-full.sh) or via --privacy-env
                            (two-VM, scp'd from the L2 stack VM). This
                            script never runs the keygen itself — both VMs
                            must consume the same bundle, otherwise the
                            guest's hash check rejects Catalyst's runtime
                            key with "privacy dispatch failed: Truncated".
  --privacy-env <path>      Path to an existing .privacy.env (e.g. scp'd from
                            the L2 stack VM). Implies --privacy-mode.
  --raiko-dir <path>        Override the raiko clone location. Default:
                            ./raiko (a submodule of this repo).
  -h, --help                Show this message.

Same-VM flow:
  ./deploy-prover.sh --force
  ./deploy-surge-full.sh --environment devnet --deploy-devnet true \
      --deployment local --stack-option 2 --mode silence --force

Two-VM flow (this is the prover VM):
  ./deploy-prover.sh --force
  # Then on the L2 stack VM:
  #   set RAIKO_HOST_ZKVM=http://<this-host-ip>:8080 in .env
  #   ./deploy-surge-full.sh ... --deployment remote ...
  # After that finishes, scp simple-surge-node/configs/*.json onto this VM and
  # restart raiko-zk with --force-recreate. The script will print the exact
  # commands when it completes.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)         force="true"; shift ;;
        --skip-install)     skip_install="true"; shift ;;
        --skip-zisk-sdk)    skip_zisk_sdk="true"; shift ;;
        --privacy-mode)     privacy_mode="true"; shift ;;
        --privacy-env)      privacy_env_path="$2"; privacy_mode="true"; shift 2 ;;
        --raiko-dir)        raiko_dir="$2"; shift 2 ;;
        -h|--help)          show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; show_help; exit 2 ;;
    esac
done

# ─── Pre-flight ─────────────────────────────────────────────────────────────
require_command() {
    local cmd="$1"
    local hint="${2:-}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required tool missing: $cmd"
        [[ -n "$hint" ]] && log_error "  → $hint"
        return 1
    fi
}

preflight() {
    local fail=0
    require_command docker "install Docker Engine: https://docs.docker.com/engine/install/" || fail=1
    if ! docker info >/dev/null 2>&1; then
        log_error "docker info failed — daemon not running or permissions issue"
        log_error "  → start docker (systemctl start docker) and/or add your user to the docker group"
        fail=1
    fi
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        log_error "nvidia-smi not found — real ZisK prover needs an NVIDIA GPU."
        log_error "  → install the NVIDIA driver first, then re-run."
        log_error "  → for a non-GPU host that just runs the L2 stack with mock proofs,"
        log_error "    skip this script and use deploy-surge-full.sh --mock-prover instead."
        fail=1
    elif ! nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1; then
        log_error "nvidia-smi is installed but can't talk to the driver."
        log_error "  → check 'sudo dmesg | grep -i nvidia' for driver errors."
        fail=1
    fi
    if ! command -v git >/dev/null 2>&1; then
        log_error "git not found — needed for submodule update"
        fail=1
    fi
    if [[ $fail -ne 0 ]]; then
        exit 1
    fi
    log_success "Pre-flight passed (docker, NVIDIA driver, git)"
}

# ─── Submodule ──────────────────────────────────────────────────────────────
ensure_raiko_submodule() {
    if [[ ! -d "$raiko_dir" || ! -f "$raiko_dir/makefile" ]]; then
        log_info "raiko submodule missing — initializing..."
        git submodule update --init --recursive raiko || {
            log_error "Failed to init raiko submodule. If you cloned without --recurse-submodules,"
            log_error "run: git submodule update --init --recursive"
            exit 1
        }
    fi
    if [[ ! -x "$raiko_dir/script/install-zisk-deps.sh" ]]; then
        log_error "raiko clone exists at $raiko_dir but script/install-zisk-deps.sh is missing"
        log_error "  → the submodule may be on an older commit. Bump via --update-submodules"
        log_error "    on the deploy-surge-full.sh side, or `git submodule update --remote raiko`."
        exit 1
    fi
    log_success "raiko submodule ready at $raiko_dir"
}

# ─── Steps ──────────────────────────────────────────────────────────────────

confirm_or_force() {
    local prompt="$1"
    if [[ "$force" == "true" ]]; then
        log_info "$prompt [auto-yes via --force]"
        return 0
    fi
    read -r -p "$prompt [y/N] " ans
    [[ "$ans" =~ ^[yY] ]]
}

install_deps() {
    if [[ "$skip_install" == "true" ]]; then
        log_info "--skip-install → skipping raiko/script/install-zisk-deps.sh"
        return 0
    fi
    log_info "Step 2/7: install apt deps + Rust + CUDA (raiko/script/install-zisk-deps.sh)"
    log_info "  This is idempotent — already-installed pieces are detected and skipped."
    local flag=""
    [[ "$force" == "true" ]] && flag="--yes"
    (cd "$raiko_dir" && bash script/install-zisk-deps.sh $flag) || {
        log_error "install-zisk-deps.sh failed — see above for the specific package/step."
        exit 1
    }
    log_success "Deps installed."
}

install_zisk_sdk() {
    if [[ "$skip_zisk_sdk" == "true" ]]; then
        log_info "--skip-zisk-sdk → skipping TARGET=zisk make install"
        return 0
    fi
    if [[ -d "${ZISK_DIR:-$HOME/.zisk}/provingKey" ]]; then
        log_info "ZisK proving keys already present at ${ZISK_DIR:-$HOME/.zisk}/provingKey — skipping download."
        return 0
    fi
    log_info "Step 3/7: TARGET=zisk make install (downloads ~150 GB of proving keys to ${ZISK_DIR:-$HOME/.zisk})"
    if [[ "$force" != "true" ]]; then
        if ! confirm_or_force "This downloads ~150 GB. Continue?"; then
            log_warning "Skipped by user. Re-run without --force to be prompted again, or with --skip-zisk-sdk to skip on re-runs."
            return 1
        fi
    fi
    # Make sure cargo is on PATH (rustup writes ~/.cargo/env but a fresh shell may not have sourced it).
    if [[ -f "$HOME/.cargo/env" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.cargo/env"
    fi
    # ZisK install needs zisk-toolchain bins on PATH for the post-install check.
    export PATH="$HOME/.zisk/bin:$HOME/.sp1/bin:$PATH"
    (cd "$raiko_dir" && TARGET=zisk make install) || {
        log_error "TARGET=zisk make install failed."
        exit 1
    }
    log_success "ZisK SDK installed."
}

prepare_raiko_env() {
    log_info "Step 4/7: prepare raiko docker/.env"
    if [[ ! -f "$raiko_dir/docker/.env" ]]; then
        if [[ ! -f "$raiko_dir/docker/.env.sample.zk" ]]; then
            log_error "raiko/docker/.env.sample.zk missing — submodule looks broken."
            exit 1
        fi
        cp "$raiko_dir/docker/.env.sample.zk" "$raiko_dir/docker/.env"
        log_success "Copied .env.sample.zk → docker/.env"
    else
        log_info "raiko/docker/.env already exists — leaving in place. Edit manually if you need to change values."
    fi
}

# Apply hashes from an existing .privacy.env. Never generates one here — the
# L2 stack VM is canonical (its deploy-surge-full.sh runs the keygen) and the
# prover must consume the *same* bundle. Generating a fresh one here would
# produce keys whose hashes don't match Catalyst's runtime symmetric key, so
# the guest's assertion would fail on every proof with "privacy dispatch
# failed: Truncated".
configure_privacy() {
    [[ "$privacy_mode" != "true" ]] && return 0

    log_info "Step 5/7: configure Surge privacy mode"

    # Resolution order for the bundle:
    #   1. Explicit --privacy-env <path>
    #   2. ./.privacy.env (same-VM: deploy-surge-full.sh wrote it here)
    local source_bundle="$privacy_env_path"
    if [[ -z "$source_bundle" && -f "${HERE}/.privacy.env" ]]; then
        source_bundle="${HERE}/.privacy.env"
        log_info "Using local bundle at $source_bundle (same-VM)."
    fi

    if [[ -z "$source_bundle" || ! -f "$source_bundle" ]]; then
        log_error "Privacy bundle not found."
        log_error ""
        log_error "The bundle is generated by deploy-surge-full.sh on the L2 stack VM"
        log_error "(via surge-taiko-mono/.../surge-privacy-keygen.sh). It MUST be the same"
        log_error "bundle on both VMs — generating a fresh one here would give different"
        log_error "keys whose hashes don't match Catalyst's runtime symmetric key."
        log_error ""
        log_error "Get the bundle here:"
        log_error "  Same-VM:  run ./deploy-surge-full.sh first (it writes .privacy.env"
        log_error "            next to this script), then re-run with --privacy-mode."
        log_error "  Two-VM:   on the L2 stack VM, scp the bundle over:"
        log_error "              scp simple-surge-node/.privacy.env <this-host>:/tmp/.privacy.env"
        log_error "            then re-run with --privacy-mode --privacy-env /tmp/.privacy.env"
        log_error ""
        log_error "Tear down with: ./script/sync-privacy-to-prover.sh --local (also works"
        log_error "as the alternate path after deploy-surge-full.sh finishes)."
        exit 1
    fi

    # Mirror the four lines into raiko/docker/.env (replace-or-append per key).
    log_info "Applying SURGE_PRIVACY_* values from $source_bundle → $raiko_dir/docker/.env"
    local key val
    while IFS= read -r line; do
        case "$line" in
            SURGE_PRIVACY_SYMMETRIC_KEY=*|SURGE_PRIVACY_SYMMETRIC_KEY_HASH=*|\
            SURGE_PRIVACY_FI_PRIVKEY=*|SURGE_PRIVACY_FI_PRIVKEY_HASH=*)
                key="${line%%=*}"
                val="${line#*=}"
                if grep -qE "^${key}=" "$raiko_dir/docker/.env"; then
                    sed -i.bak -E "s|^${key}=.*|${key}=${val}|" "$raiko_dir/docker/.env"
                    rm -f "$raiko_dir/docker/.env.bak"
                else
                    echo "${key}=${val}" >> "$raiko_dir/docker/.env"
                fi
                ;;
        esac
    done < "$source_bundle"

    # Flip the master switch.
    if grep -qE '^SURGE_PRIVACY_MODE=' "$raiko_dir/docker/.env"; then
        sed -i.bak -E 's|^SURGE_PRIVACY_MODE=.*|SURGE_PRIVACY_MODE=true|' "$raiko_dir/docker/.env"
        rm -f "$raiko_dir/docker/.env.bak"
    else
        echo "SURGE_PRIVACY_MODE=true" >> "$raiko_dir/docker/.env"
    fi
    log_success "Privacy values applied; SURGE_PRIVACY_MODE=true on prover side."

    # Rebuild the guest ELFs so the new hashes are baked in.
    if [[ ! -x "$raiko_dir/script/build-guest-with-hashes.sh" ]]; then
        log_warning "raiko/script/build-guest-with-hashes.sh missing — submodule may be too old."
        log_warning "Skipping guest rebuild. Privacy mode will not work end-to-end until you bump raiko."
        return 0
    fi
    log_info "Rebuilding ZisK guest ELFs with the new hashes (one-off, ~30 s on warm caches)"
    (cd "$raiko_dir" && ./script/build-guest-with-hashes.sh) || {
        log_error "Guest rebuild failed."
        exit 1
    }
    log_success "Guest ELFs rebuilt; raiko-zk will bind-mount them via docker-compose-zk.yml."
}

start_raiko() {
    log_info "Step 6/7: docker compose up -d (raiko-zk)"
    # Source the .env so any ${VAR} substitutions in compose work.
    set -a
    # shellcheck disable=SC1090
    source "$raiko_dir/docker/.env"
    set +a
    (cd "$raiko_dir" && docker compose -f docker/docker-compose-zk.yml up -d) || {
        log_error "docker compose up failed."
        exit 1
    }
    log_success "raiko-zk started."
}

wait_for_vkey() {
    log_info "Step 7/7: wait for /guest_data to return vkey"
    log_info "  Cold start can take 4-5 min (multi-GPU) or ~16 min (single L40/3090)."
    log_info "  This script polls every 10 s for up to 30 min; Ctrl-C is safe."

    local timeout=1800
    local start_time elapsed
    start_time=$(date +%s)
    while true; do
        elapsed=$(( $(date +%s) - start_time ))
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Timed out after ${timeout}s waiting for /guest_data."
            log_error "  → check: docker compose -f docker/docker-compose-zk.yml logs raiko-zk"
            return 1
        fi
        local body
        body=$(curl -s --max-time 10 http://localhost:8080/guest_data 2>/dev/null || echo "")
        if [[ -n "$body" ]] && echo "$body" | jq -e '.zisk.batch_vkey' >/dev/null 2>&1; then
            local vkey
            vkey=$(echo "$body" | jq -r '.zisk.batch_vkey')
            log_success "Raiko ready — zisk.batch_vkey=$vkey  (warmed up in ${elapsed}s)"
            return 0
        fi
        sleep 10
    done
}

post_deploy_summary() {
    local prover_ip
    prover_ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "<this-host-ip>")
    cat <<EOF

==============================================================================
Raiko ZisK prover is up.
==============================================================================

Next steps:

  • Same-VM:
      On THIS host, run:
        ./deploy-surge-full.sh --environment devnet --deploy-devnet true \\
          --deployment local --stack-option 2 --mode silence --force
      (deploy-surge-full.sh sees RAIKO_HOST_ZKVM=http://host.docker.internal:8082
      in .env.devnet by default; matches the host port mapping above.)

  • Two-VM:
      On the L2 stack VM (not this one), edit simple-surge-node/.env:
        RAIKO_HOST_ZKVM=http://${prover_ip}:8080
      then run deploy-surge-full.sh with --deployment remote.

      Once that L2-side deploy finishes, copy the generated chain spec back
      so this raiko-zk has the right contract addresses:
        # From the L2 stack VM:
        scp simple-surge-node/configs/chain_spec_list.json $(whoami)@${prover_ip}:${raiko_dir}/host/config/devnet/chain_spec_list.json
        scp simple-surge-node/configs/config.json         $(whoami)@${prover_ip}:${raiko_dir}/host/config/devnet/config.json

      Then on THIS host:
        cd ${raiko_dir}
        docker compose -f docker/docker-compose-zk.yml up -d --force-recreate

  • Privacy mode:
EOF
    if [[ "$privacy_mode" == "true" ]]; then
        echo "      Already enabled here using the L2 VM's .privacy.env."
        echo "      On the L2 VM, set SURGE_PRIVACY_MODE=true in .env and run:"
        echo "        docker compose -f docker-compose.yml --profile catalyst up -d --force-recreate catalyst"
    else
        echo "      Off. To turn on later: deploy-surge-full.sh on the L2 VM generates"
        echo "      .privacy.env first, then either:"
        echo "        Same-VM: ./script/sync-privacy-to-prover.sh --local --rebuild"
        echo "        Two-VM:  scp .privacy.env here, then"
        echo "                 ./deploy-prover.sh --privacy-mode --privacy-env /path/to/.privacy.env"
        echo "                 --skip-install --skip-zisk-sdk"
    fi
    echo "=============================================================================="
}

# ─── Main ───────────────────────────────────────────────────────────────────

log_info "Step 1/7: pre-flight (Docker, NVIDIA driver, git)"
preflight
ensure_raiko_submodule
install_deps
install_zisk_sdk
prepare_raiko_env
configure_privacy
start_raiko
if ! wait_for_vkey; then
    log_warning "Skipping post-deploy summary — Raiko isn't ready yet."
    exit 1
fi
post_deploy_summary