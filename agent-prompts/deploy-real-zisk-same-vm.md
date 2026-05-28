# Agent prompt — real ZisK prover, single VM

Deploys the full Surge devnet plus a real ZisK prover on **one** GPU host. Realistic with 4× L40 or stronger — single-GPU works but cold-starts add ~16 min per Raiko restart. Privacy mode is an orthogonal opt-in.

Reference doc (operator-facing source of truth): [docs.surge.wtf/guides/running-surge/provers](https://docs.surge.wtf/guides/running-surge/provers) (same-VM tab) and [docs.surge.wtf/guides/running-surge/privacy-mode](https://docs.surge.wtf/guides/running-surge/privacy-mode).

## Before you launch

### Fill these in

| Placeholder | What it is | Example |
|---|---|---|
| `<host-target>` | `local`, or SSH target for the GPU box. | `ubuntu@10.0.0.5` |
| `<ssh-key-path>` | Path to the private key. Omit if `<host-target>` is `local`. | `~/.ssh/id_ed25519` |
| `<simple-surge-node-branch>` | Branch to clone. `main` for releases. | `main` |
| `<privacy-mode>` | `true` to encrypt blobs end-to-end, `false` otherwise. | `false` |

### Local pre-flight (~30 s)

```bash
# 1. SSH reachability + GPU on the host (skip the `ssh` if local)
ssh -i <ssh-key-path> <host-target> 'echo ok; nvidia-smi | head -3'

# 2. Both raiko images are reachable from the host
ssh -i <ssh-key-path> <host-target> \
  'docker manifest inspect docker.io/nethermind/surge-raiko-zk:latest | head -3 && \
   docker manifest inspect docker.io/nethermind/surge-raiko-zk-toolchain:latest | head -3'

# 3. Repo branch is reachable
git ls-remote https://github.com/NethermindEth/simple-surge-node \
  refs/heads/<simple-surge-node-branch> | awk '{print $1}'
```

All three must pass. If the toolchain image inspect fails and you intend to turn privacy ON, STOP — the prover needs that image to bake new key hashes into the ZisK guest ELFs.

## The prompt

````
ROLE
You're deploying a complete Surge devnet on a single GPU host with the REAL
ZisK prover. End-to-end as a one-shot. No commits, no pushes, no destructive
actions outside the working directory below.

REFERENCE
Operator-facing source of truth:
  https://docs.surge.wtf/guides/running-surge/provers (same-VM tab)
  https://docs.surge.wtf/guides/running-surge/privacy-mode (only if privacy ON)
Deviations from this prompt should be cross-checked against those pages.

PARAMETERS
  Host:               <host-target>      # `local` or `user@host` (GPU box)
  SSH key:            <ssh-key-path>     # ignore if Host = local
  Branch:             <simple-surge-node-branch>
  Privacy mode:       <privacy-mode>     # `true` or `false`

SSH HELPER
If Host != `local`, prefix every shell step with:
  ssh -i <ssh-key-path> <host-target> '<command>'
If Host = `local`, run commands directly.

IMAGES (canonical tags, both on docker.io)
  nethermind/surge-raiko-zk:latest             (CUDA runtime host)
  nethermind/surge-raiko-zk-toolchain:latest   (Rust + ZisK + source, used
                                                only when privacy = true)

PRE-FLIGHT (do BEFORE Phase 1)
  a. NVIDIA stack reachable:    nvidia-smi | head -3
  b. Docker daemon reachable:   docker info | head -3
  c. Both raiko images pullable:
       docker manifest inspect docker.io/nethermind/surge-raiko-zk:latest
       docker manifest inspect docker.io/nethermind/surge-raiko-zk-toolchain:latest
     The toolchain image is only required if Privacy mode = true, but the
     check is cheap — run both.
  d. Free RAM ≥ 64 GiB:         free -g | awk '/^Mem:/ {print $2}'
     The deploy script enforces 128 GiB at install time but 64 GiB is the
     documented floor for a single-GPU dev run. Below 64 GiB, STOP.
  e. Free disk on $HOME ≥ 200 GiB (ZisK proving keys land in ~/.zisk and
     are ~150 GB):
       df -BG --output=avail "$HOME" | tail -1

If any check fails, STOP and report — installation is the operator's call.

CLONE
  git clone -b <simple-surge-node-branch> \
    https://github.com/NethermindEth/simple-surge-node.git
  cd simple-surge-node
  git submodule update --init --recursive

  Verify the raiko submodule landed (build script exists, image vars present):
    ls raiko/Dockerfile.zk raiko/script/build-guest-with-hashes.sh
    grep -nE 'RAIKO_ZK_TOOLCHAIN_IMAGE|RAIKO_ZK_IMAGE' \
      raiko/script/build-guest-with-hashes.sh

ORDERED PLAN

  Phase 1 — Bring up the prover
    1. ./deploy-prover.sh --force
       This does, in order:
         - NVIDIA + Docker pre-flight
         - raiko submodule init (idempotent)
         - apt deps + Rust + CUDA via raiko/script/install-zisk-deps.sh
         - TARGET=zisk make install — downloads ZisK proving keys to ~/.zisk
           (~150 GB, 5-30 min)
         - Populates raiko/docker/guest-elfs/ with default empty-hash ELFs
           (privacy off-baseline; rebuilt in Phase 4 if privacy = true)
         - docker compose up -d for raiko-zk via docker-compose-zk.yml
         - Polls localhost:8080/guest_data until the vkey returns
       SINGLE-GPU COLD START ≈ 16 MIN on this poll. Don't kill / retry.
    2. Confirm the vkey is reachable:
         curl -s -m 10 http://localhost:8080/guest_data | jq
       Expected: {"zisk":{"batch_vkey":"<64hex>"}}

  Phase 2 — L2 stack
    3. cp .env.devnet .env
    4. Point Catalyst at the local prover (container reaches host via the
       Docker gateway, NOT plain `localhost`):
         sed -i 's|^RAIKO_HOST_ZKVM=.*|RAIKO_HOST_ZKVM=http://host.docker.internal:8080|' .env
         grep -E '^RAIKO_HOST_ZKVM=' .env
       On Linux without the built-in host.docker.internal DNS entry, also
       add `--add-host=host.docker.internal:host-gateway` semantics by
       confirming docker-compose.yml already wires this (it does on the
       supported branches).
    5. Deploy (include --privacy-mode only if Privacy mode = true):
         ./deploy-surge-full.sh \
           --environment devnet \
           --deploy-devnet true \
           --deployment local \
           --stack-option 2 \
           [--privacy-mode] \
           --mode silence \
           --force
       If --privacy-mode is set, the script runs generate_privacy_bundle and
       writes .privacy.env (chmod 600).
    6. Confirm post-deploy:
         grep -E '^SURGE_PRIVACY_MODE=' .env
         ls configs/{chain_spec_list,config}.json
         if Privacy mode = true: ls -la .privacy.env

  Phase 3 — Sync chain spec to local raiko (proof gate)
    7. cp configs/chain_spec_list.json configs/config.json \
         raiko/host/config/devnet/
    8. cd raiko && docker compose -f docker/docker-compose-zk.yml \
         up -d --force-recreate raiko-zk && cd ..
    9. Wait for the vkey to come back — another ~16 min cold start on
       single-GPU:
         while ! curl -s -m 5 http://localhost:8080/guest_data | \
                  grep -q batch_vkey; do sleep 30; done

  Phase 4 — (Privacy ON only) sync keys + rebuild guest
   10. If Privacy mode = false, SKIP this phase entirely.
   11. ./script/sync-privacy-to-prover.sh --local --rebuild
       Pushes .privacy.env into raiko/docker/.env, sets SURGE_PRIVACY_MODE=true
       there, runs build-guest-with-hashes.sh against the toolchain image to
       rebuild the three ZisK guest ELFs with matching key hashes (~30 s on
       warm cache, ~5 min cold), and recreates raiko-zk.
       Wait for /guest_data to return the new vkey before continuing.
   12. The script also auto-registers the new vkey on the L1 verifier. If it
       didn't (look for `setProgramTrusted` in the script output), run:
         ./script/sync-privacy-to-prover.sh --local --refresh-vkey
   13. Recreate Catalyst so it sees the new privacy env:
         docker compose -f docker-compose.yml --profile catalyst \
           up -d --force-recreate catalyst

  Phase 5 — Verification
   14. docker ps    # all l2-* + raiko-zk containers Up
   15. eth_blockNumber advancing:
         curl -s http://localhost:8547 -X POST \
           -H 'Content-Type: application/json' \
           -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   16. If Privacy mode = true:
         docker logs l2-catalyst-node 2>&1 | grep "Proposal blob privacy mode"
         # Expected: "Proposal blob privacy mode: enabled (AES-256-GCM, scheme 0x01)"
         docker logs l2-raiko-zk-client 2>&1 \
           | grep -E "privacy_mode|symmetric_key" | head
         # Expected: privacy_mode: true, privacy_symmetric_key: Some(...)
   17. Drive a propose cycle with a devnet self-transfer:
         cast send 0x3e95dFbBaF6B348396E6674C7871546dCC568e56 \
           --value 1wei \
           --private-key 0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44 \
           --rpc-url http://localhost:8547 --legacy
   18. Watch the submission outcome:
         docker logs -f l2-catalyst-node 2>&1 \
           | grep -E "Submission completed|panicked|reverted|privacy dispatch" \
           | head -5
       Within ~30 s expect "Submission completed. New last finalized block …"
       on a warm prover, or up to ~3 min if this is the first proof after
       the Phase 3/4 restart.

CONTINGENCY (only when Phase 5 step 18 panics)
If you see "privacy dispatch failed: Truncated" in raiko logs, the runtime
keys don't match the guest's baked-in hashes. Re-run Phase 4 step 11 — it
re-derives the hashes from .privacy.env and rebuilds the guest. If the
panic persists, STOP and report:
  - The failing tx hash from the cast send
  - 20 lines of l2-catalyst-node logs around the proposal attempt
  - 20 lines of l2-raiko-zk-client logs around the panic
  - eth_blockNumber on http://localhost:8547

GOTCHAS
  - Don't pass RAIKO_HOST_ZKVM inline to deploy-surge-full.sh — .env is
    sourced on every run and inline exports get overridden.
  - Don't pass SURGE_PRIVACY_MODE inline; use --privacy-mode.
  - Single-GPU cold start is ~16 min EACH time raiko-zk is recreated.
    Phase 1, Phase 3, and (if privacy = true) Phase 4 each trigger one.
    Total cold-start budget: ~35-50 min.
  - .privacy.env is chmod 600 and gitignored. Don't paste its contents into
    PR descriptions, commit messages, or your report.

REPORT BACK
After each Phase, write one sentence: what completed, what you observed
(block height, latest "Submission completed", vkey hash, container counts).
If a step takes >5 min without log progress AND it's not one of the
documented cold-start waits, STOP and ask before retrying.
````

## Provenance

Last updated: 2026-05-28. Covers `simple-surge-node` `main` after the `deploy-prover.sh` / `deploy-surge-full.sh` split. Uses the `docker.io/nethermind/surge-raiko-zk:latest` and `docker.io/nethermind/surge-raiko-zk-toolchain:latest` image tags. If those tags change, update both the pre-flight and the prompt's IMAGES section.
