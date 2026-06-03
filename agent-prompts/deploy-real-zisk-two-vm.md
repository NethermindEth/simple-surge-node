# Agent prompt — real ZisK prover, two VMs

Deploys the full Surge devnet across two hosts: one GPU box for Raiko, one host for the L2 stack (Kurtosis L1 + Catalyst + Driver + DEX). Privacy mode is an orthogonal opt-in. This is the recommended topology for staging / production — it isolates the GPU workload from the L2 control plane.

Designed to be run in **foreground** so you can watch progress. Expect ~45-60 minutes total wall time on a single-GPU prover; less on multi-GPU.

Reference docs (operator-facing source of truth):
- [docs.surge.wtf/guides/running-surge/provers](https://docs.surge.wtf/guides/running-surge/provers) (two-VM tab)
- [docs.surge.wtf/guides/running-surge/privacy-mode](https://docs.surge.wtf/guides/running-surge/privacy-mode) (only if privacy ON)

## Before you launch

### Fill these in

| Placeholder | What it is | Example |
|---|---|---|
| `<prover-host>` | SSH target for the GPU box. | `ubuntu@10.0.0.5` |
| `<l2-host>` | SSH target for the L2 stack host. | `ubuntu@10.0.0.6` |
| `<ssh-key-path>` | Path on **your laptop** to the private key trusted by both hosts. | `~/.ssh/id_ed25519` |
| `<remote-ssh-key-path>` | Path on the **L2 host** where the prompt should place the same key so the L2 host can ssh into the prover. | `/home/ubuntu/.ssh/surge_deploy_ed25519` |
| `<prover-ip-or-host>` | The address the L2 host should use to reach the prover (IP or DNS name). Often the same as the user@host part of `<prover-host>`. | `10.0.0.5` |
| `<simple-surge-node-branch>` | Branch to clone on both hosts. `main` for releases. | `main` |
| `<privacy-mode>` | `true` to encrypt blobs end-to-end, `false` otherwise. | `false` |

### Local pre-flight (~30 s)

Run these from your laptop before launching the agent.

```bash
# 1. Both raiko images are published and pullable
docker manifest inspect docker.io/nethermind/surge-raiko-zk:latest | head -3
docker manifest inspect docker.io/nethermind/surge-raiko-zk-toolchain:latest | head -3

# 2. SSH + GPU on the prover
ssh -i <ssh-key-path> <prover-host> 'echo ok; nvidia-smi | head -3'

# 3. SSH + Docker on the L2 host
ssh -i <ssh-key-path> <l2-host> 'echo ok; docker info | head -3'

# 4. The L2 host can reach the prover on TCP/8080 (the agent will check
#    this again from inside; pre-checking now saves you the round trip):
ssh -i <ssh-key-path> <l2-host> \
  'curl -sS -m 5 http://<prover-ip-or-host>:8080/healthz || echo "NOT REACHABLE YET — that's fine if raiko-zk isn't up yet"'

# 5. simple-surge-node branch is reachable
git ls-remote https://github.com/NethermindEth/simple-surge-node \
  refs/heads/<simple-surge-node-branch> | awk '{print $1}'
```

All five must pass (the curl on (4) is allowed to 404/connect-refuse — the agent brings raiko up itself). If the toolchain image inspect fails, STOP — privacy mode needs it to rebuild guest ELFs.

### Security note

The prompt below scp's `<ssh-key-path>` onto `<l2-host>` so the L2 host can SSH outbound to the prover during the privacy sync step. **This is a one-deploy trust window.** After verification finishes, rotate the key on both hosts (regenerate, re-authorise the new public key, remove the old one). The prompt ends with a mandatory reminder line to make sure the operator doesn't forget.

## The prompt

````
ROLE
You're deploying a complete Surge devnet across two hosts with the REAL
ZisK prover. End-to-end as a one-shot. No commits, no pushes, no destructive
actions outside the working directories below.

REFERENCE
Operator-facing source of truth:
  https://docs.surge.wtf/guides/running-surge/provers (two-VM tab)
  https://docs.surge.wtf/guides/running-surge/privacy-mode (only if privacy ON)
Deviations from this prompt should be cross-checked against those pages.

PARAMETERS
  Prover host:         <prover-host>            # SSH target (GPU box)
  L2 host:             <l2-host>                # SSH target (L2 stack)
  SSH key (local):     <ssh-key-path>           # private key on your laptop
  SSH key (remote):    <remote-ssh-key-path>    # path to place same key on L2 host
  Prover address:      <prover-ip-or-host>      # what L2 host uses to reach prover
  Branch:              <simple-surge-node-branch>
  Privacy mode:        <privacy-mode>           # `true` or `false`

Inbound TCP/8080 on the prover host must be reachable from the L2 host.

KEY DISTRIBUTION (do BEFORE Phase 1, only if Privacy mode = true)
The L2 host needs outbound SSH to the prover so it can run
sync-privacy-to-prover.sh in Phase 4. Copy the key with strict perms:

  scp -i <ssh-key-path> <ssh-key-path> <l2-host>:<remote-ssh-key-path>
  ssh -i <ssh-key-path> <l2-host> \
    "chmod 600 <remote-ssh-key-path> && \
     install -d -m 700 \$(dirname <remote-ssh-key-path>) && \
     touch \$(dirname <remote-ssh-key-path>)/config && \
     chmod 600 \$(dirname <remote-ssh-key-path>)/config && \
     grep -q '<prover-ip-or-host>' \$(dirname <remote-ssh-key-path>)/config || \
       printf 'Host <prover-ip-or-host>\n  IdentityFile <remote-ssh-key-path>\n  StrictHostKeyChecking accept-new\n' \
         >> \$(dirname <remote-ssh-key-path>)/config"

If Privacy mode = false, skip this section — the L2 host only needs to
reach the prover via HTTP (port 8080), not SSH.

IMAGES (canonical tags, both on docker.io)
  nethermind/surge-raiko-zk:latest             (CUDA runtime host)
  nethermind/surge-raiko-zk-toolchain:latest   (Rust + ZisK + source, used
                                                only when privacy = true)

PRE-FLIGHT (do BEFORE Phase 1)
  a. Both raiko images pullable from each host:
       ssh -i <ssh-key-path> <prover-host> \
         'docker manifest inspect docker.io/nethermind/surge-raiko-zk:latest && \
          docker manifest inspect docker.io/nethermind/surge-raiko-zk-toolchain:latest'
       ssh -i <ssh-key-path> <l2-host> \
         'docker manifest inspect docker.io/nethermind/surge-raiko-zk:latest'
  b. NVIDIA + Docker on the prover:
       ssh -i <ssh-key-path> <prover-host> 'nvidia-smi | head -3 && docker info | head -3'
  c. Free RAM ≥ 128 GiB on the prover (deploy-prover.sh enforces this):
       ssh -i <ssh-key-path> <prover-host> "free -g | awk '/^Mem:/ {print \$2}'"
     If under 128 GiB, STOP and report. (The operator can override with
     SURGE_SKIP_RAM_PRECHECK=true but they should make that call.)
  d. Free disk ≥ 200 GiB on the prover's $HOME (ZisK keys land in ~/.zisk):
       ssh -i <ssh-key-path> <prover-host> "df -BG --output=avail \"\$HOME\" | tail -1"
  e. Docker on the L2 host:
       ssh -i <ssh-key-path> <l2-host> 'docker info | head -3'

If any check fails, STOP — installation/sizing is the operator's call.

CLONE COMMANDS
  Prover host:
    ssh -i <ssh-key-path> <prover-host> \
      'git clone -b <simple-surge-node-branch> \
         https://github.com/NethermindEth/simple-surge-node.git && \
       cd simple-surge-node && git submodule update --init --recursive'

  L2 host:
    ssh -i <ssh-key-path> <l2-host> \
      'git clone -b <simple-surge-node-branch> \
         https://github.com/NethermindEth/simple-surge-node.git && \
       cd simple-surge-node && git submodule update --init --recursive'

  Verify after clone (both hosts):
    ls simple-surge-node/raiko/Dockerfile.zk
    ls simple-surge-node/raiko/script/build-guest-with-hashes.sh

ORDERED PLAN

  Phase 1 — Prover host (<prover-host>)
    1. Clone repo + submodules (see above).
    2. ssh ... '<l2-host>'... actually: SSH into <prover-host> and run:
         cd simple-surge-node && ./deploy-prover.sh --force
       This does, in order:
         - NVIDIA + Docker + RAM pre-flight (will exit if <128 GiB free)
         - raiko submodule init (idempotent)
         - apt deps + Rust + CUDA via install-zisk-deps.sh
         - TARGET=zisk make install — ZisK proving keys to ~/.zisk (~150 GB,
           5-30 min)
         - Populates raiko/docker/guest-elfs/ (docker-cp out of the runtime
           image — fast path, since privacy hashes are off until Phase 4)
         - docker compose up -d for raiko-zk via docker-compose-zk.yml
         - Polls localhost:8080/guest_data until the vkey returns
       SINGLE-GPU COLD START ≈ 16 MIN on this poll. Don't kill / retry.
    3. From the L2 host, confirm reachability:
         ssh -i <ssh-key-path> <l2-host> \
           'curl -s -m 10 http://<prover-ip-or-host>:8080/guest_data | jq'
       Expected: {"zisk":{"batch_vkey":"<64hex>"}}
       If unreachable, open TCP/8080 on the prover's firewall / security group.

  Phase 2 — L2 host (<l2-host>)
    4. Clone repo + submodules.
    5. cd simple-surge-node && cp .env.devnet .env
    6. Point Catalyst at the prover (privacy mode is the CLI flag in step 7,
       not here):
         sed -i 's|^RAIKO_HOST_ZKVM=.*|RAIKO_HOST_ZKVM=http://<prover-ip-or-host>:8080|' .env
         grep -E '^RAIKO_HOST_ZKVM=' .env
    7. Deploy (include --privacy-mode only if Privacy mode = true):
         ./deploy-surge-full.sh \
           --environment devnet \
           --deploy-devnet true \
           --deployment remote \
           --stack-option 2 \
           [--privacy-mode] \
           --mode silence \
           --force
       If --privacy-mode is set, the script runs generate_privacy_bundle and
       writes .privacy.env (chmod 600).
       The script also runs a Raiko readiness check before any DEX/L2 tx;
       on a still-cold single-GPU prover this can abort with a "sync configs
       + force-recreate" hint. Phase 3 is exactly that recovery — proceed to
       it on either outcome (clean pass OR the documented abort).
    8. Confirm post-deploy:
         grep -E '^SURGE_PRIVACY_MODE=' .env
         ls configs/{chain_spec_list,config}.json
         if Privacy mode = true: ls -la .privacy.env

  Phase 3 — Sync chain spec to the prover
    9. scp -i <ssh-key-path> \
         configs/chain_spec_list.json configs/config.json \
         <prover-host>:~/simple-surge-node/raiko/host/config/devnet/
   10. ssh -i <ssh-key-path> <prover-host> \
         'cd ~/simple-surge-node/raiko && docker compose \
          -f docker/docker-compose-zk.yml up -d --force-recreate raiko-zk'
       Another ~16 min cold start on single-GPU. Wait for /guest_data to
       come back with a vkey before continuing.
   11. If Phase 2 step 7 aborted at the readiness check, re-run with
       --deploy-devnet false to resume (skips L1 redeploy):
         ./deploy-surge-full.sh \
           --environment devnet --deploy-devnet false \
           --deployment remote --stack-option 2 \
           [--privacy-mode] --mode silence --force

  Phase 4 — (Privacy ON only) sync keys + rebuild guest
   12. If Privacy mode = false, SKIP this phase entirely.
   13. On the L2 host:
         cd ~/simple-surge-node && \
         ./script/sync-privacy-to-prover.sh --rebuild <prover-host>
       This:
         - scp's the four SURGE_PRIVACY_* values from .privacy.env into the
           prover's raiko/docker/.env
         - Sets SURGE_PRIVACY_MODE=true on the prover
         - Runs raiko/script/build-guest-with-hashes.sh on the prover
           (pulls nethermind/surge-raiko-zk-toolchain:latest, rebuilds the
           3 ZisK guest ELFs with the matching hashes baked in — ~5 min
           warm cache, ~10-15 min cold)
         - Recreates raiko-zk with the new bind-mounted ELFs
         - Polls /guest_data for the new vkey and registers it on L1 via
           cast send setProgramTrusted (auto)
       Wait for the script to print "vkey trusted" before continuing.
   14. On the L2 host, recreate catalyst so it picks up the privacy env:
         docker compose -f docker-compose.yml --profile catalyst \
           up -d --force-recreate catalyst

  Phase 5 — Verification (L2 host)
   15. docker ps    # all l2-* containers Up
   16. eth_blockNumber advancing:
         curl -s http://localhost:8547 -X POST \
           -H 'Content-Type: application/json' \
           -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   17. If Privacy mode = true:
         docker logs l2-catalyst-node 2>&1 | grep "Proposal blob privacy mode"
         # Expected: "Proposal blob privacy mode: enabled (AES-256-GCM, scheme 0x01)"
         ssh -i <remote-ssh-key-path> <prover-host> \
           'docker logs l2-raiko-zk-client 2>&1 \
            | grep -E "privacy_mode|symmetric_key"' | head
         # Expected: privacy_mode: true, privacy_symmetric_key: Some(...)
   18. Drive a propose cycle:
         cast send 0x3e95dFbBaF6B348396E6674C7871546dCC568e56 \
           --value 1wei \
           --private-key 0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44 \
           --rpc-url http://localhost:8547 --legacy
   19. Watch the submission:
         docker logs -f l2-catalyst-node 2>&1 \
           | grep -E "Submission completed|panicked|reverted|privacy dispatch" \
           | head -5
       Within ~30 s (warm) or ~3 min (first proof after Phase 3/4 restart)
       expect "Submission completed. New last finalized block …".

CONTINGENCY (only when Phase 5 step 19 panics)
"privacy dispatch failed: Truncated" → guest's baked-in hashes don't match
the runtime keys. Re-run Phase 4 step 13. If the panic persists, STOP and
report:
  - Failing tx hash from cast send
  - 20 lines of l2-catalyst-node logs around the proposal attempt
  - 20 lines of l2-raiko-zk-client logs around the panic (via SSH to prover)
  - eth_blockNumber on http://localhost:8547
  - The raiko submodule SHA on both hosts:
      cat ~/simple-surge-node/raiko/.git
  - The four SURGE_PRIVACY_*_HASH lines from BOTH the L2 host's .privacy.env
    AND the prover's raiko/docker/.env — they must match exactly. (Don't
    paste the non-HASH key values into your report.)

GOTCHAS
  - Don't pass RAIKO_HOST_ZKVM inline to deploy-surge-full.sh — .env is
    sourced on every run and inline exports get overridden.
  - Don't pass SURGE_PRIVACY_MODE inline either; use --privacy-mode.
  - Single-GPU cold start is ~16 min EACH time raiko-zk is recreated
    (Phase 1, Phase 3, and Phase 4 each trigger one). Total cold-start
    budget: ~45-50 min.
  - .privacy.env is chmod 600 and gitignored. Don't paste its contents into
    PR descriptions, commit messages, or your report.

REPORT BACK
After each Phase, write one sentence: what completed, what you observed
(block height, latest "Submission completed", vkey hash, container counts).
If a step takes >5 min without log progress AND it's not one of the
documented cold-start waits, STOP and ask before retrying.

POST-DEPLOY REMINDER (mandatory final line of your report, only if Privacy
mode = true OR you placed an SSH key on the L2 host)
If the operator authorised placing <ssh-key-path> on <l2-host>:<remote-ssh-key-path>
for this deploy, your final message MUST include:
"REMINDER: rotate the SSH key — the private key at <ssh-key-path> was
copied to <l2-host>:<remote-ssh-key-path> during this deploy."
````

## Provenance

Last updated: 2026-05-28. Covers `simple-surge-node` `main` after the `deploy-prover.sh` / `deploy-surge-full.sh` split. The `--privacy-mode` flag is canonical; the Phase 3 chain-spec sync + Phase 4 privacy sync ordering is locked in by the Raiko readiness check. If the readiness check is moved or the auto vkey registration in `sync-privacy-to-prover.sh` changes, update this prompt and bump the date.
