# Agent prompt — mock prover, single VM

Spins up a complete Surge devnet on one host using the mock prover. No GPU needed, no Raiko host build, no proving keys. The mock raiko signs an ECDSA proof on whatever it receives — useful for local dev, CI, and validating the deploy scripts themselves. Add `PRIVACY_MODE=true` in the parameters block to also exercise the encrypt/decrypt path end-to-end.

Reference doc (operator-facing source of truth): [docs.surge.wtf/guides/running-surge/deploy-surge](https://docs.surge.wtf/guides/running-surge/deploy-surge).

## Before you launch

### Fill these in

Substitute every `<placeholder>` in the prompt below before pasting it into your LLM model.

| Placeholder | What it is | Example |
|---|---|---|
| `<host-target>` | Where to run the deploy. `local` = the same machine you're driving your LLM model from; otherwise an SSH target. | `local` or `ubuntu@10.0.0.5` |
| `<ssh-key-path>` | Absolute path to the private key used for `<host-target>`. Omit if `<host-target>` is `local`. | `~/.ssh/id_ed25519` |
| `<simple-surge-node-branch>` | Branch to clone. Use `main` unless you're testing a feature branch. | `main` |
| `<deployment-mode>` | `local` if you'll only browse on the deploy host, `remote` if any browser/RPC client lives elsewhere. | `remote` |
| `<privacy-mode>` | `true` to encrypt blobs end-to-end, `false` otherwise. | `false` |

### Local pre-flight (~30 s)

Run these from your laptop before launching the agent. Each must succeed.

```bash
# 1. SSH reachability + Docker on the host (skip if <host-target>=local)
ssh -i <ssh-key-path> <host-target> 'echo ok; docker info | head -3'

# 2. Repo branch is reachable
git ls-remote https://github.com/NethermindEth/simple-surge-node \
  refs/heads/<simple-surge-node-branch> | awk '{print $1}'
```

## The prompt

````
ROLE
You're deploying a complete Surge devnet on a single host using the MOCK
prover. End-to-end as a one-shot. No commits, no pushes, no destructive
actions outside the working directory below.

REFERENCE
Operator-facing source of truth:
  https://docs.surge.wtf/guides/running-surge/deploy-surge
Deviations from this prompt should be cross-checked against that page before
executing.

PARAMETERS
  Host:                 <host-target>      # `local` or `user@host`
  SSH key:              <ssh-key-path>     # ignore if Host = local
  Branch:               <simple-surge-node-branch>
  Deployment mode:      <deployment-mode>  # `local` or `remote`
  Privacy mode:         <privacy-mode>     # `true` or `false`

SSH HELPER
If Host != `local`, prefix every shell step with:
  ssh -i <ssh-key-path> <host-target> '<command>'
If Host = `local`, run commands directly.

PRE-FLIGHT
  a. Verify Docker is up:                docker info | head -3
  b. Verify Docker Compose v2 present:   docker compose version
  c. Verify git is installed:            git --version
  d. Verify port 8547 (L2 RPC) is free:  ss -ltn '( sport = :8547 )' || true
If (a)–(c) fail, STOP and report which prerequisite is missing. Do not try
to apt-install on the operator's host without explicit permission.

CLONE
  git clone -b <simple-surge-node-branch> \
    https://github.com/NethermindEth/simple-surge-node.git
  cd simple-surge-node

ORDERED PLAN

  Phase 1 — Prepare env
    1. cp .env.devnet .env
    2. If <privacy-mode> = false, no edits needed.
       If <privacy-mode> = true, the --privacy-mode CLI flag (Phase 2) will
       flip SURGE_PRIVACY_MODE=true in .env automatically.
    3. Confirm Kurtosis is installed and the engine is running:
         kurtosis engine status || kurtosis engine start
       If `kurtosis` isn't on PATH, STOP and report — installation is the
       operator's call.

  Phase 2 — Deploy
    4. Run (note: include --privacy-mode only if <privacy-mode> = true):
         ./deploy-surge-full.sh \
           --environment devnet \
           --deploy-devnet true \
           --deployment <deployment-mode> \
           --stack-option 2 \
           --mock-prover \
           [--privacy-mode] \
           --mode silence \
           --force
    5. Expect ~15-25 min wall time on first deploy (Kurtosis L1 bring-up
       dominates). Don't kill / retry inside that window.

  Phase 3 — Verification
    6. docker ps    # all l2-* containers Up (l2-catalyst-node, l2-driver,
                    # l2-execution-engine, l2-raiko-mock-client, etc.)
    7. eth_blockNumber should advance past 1:
         curl -s http://localhost:8547 -X POST \
           -H 'Content-Type: application/json' \
           -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
    8. Catalyst is proposing:
         docker logs l2-catalyst-node 2>&1 | grep "Submission completed" | tail -3
       Expected: at least one "Submission completed. New last finalized block …"
    9. If <privacy-mode> = true, also verify the privacy banner:
         docker logs l2-catalyst-node 2>&1 | grep "Proposal blob privacy mode"
       Expected: "Proposal blob privacy mode: enabled (AES-256-GCM, scheme 0x01)"
       And confirm `.privacy.env` exists with chmod 600:
         ls -la .privacy.env

  Phase 4 — Drive a test transaction (optional but recommended)
   10. Send a self-transfer to confirm the propose/finalize loop:
         cast send 0x3e95dFbBaF6B348396E6674C7871546dCC568e56 \
           --value 1wei \
           --private-key 0x94eb3102993b41ec55c241060f47daa0f6372e2e3ad7e91612ae36c364042e44 \
           --rpc-url http://localhost:8547 --legacy
       (The privkey above is the well-known devnet faucet account — public
       knowledge, fine to use on a fresh devnet.)
   11. Watch the submission:
         docker logs -f l2-catalyst-node 2>&1 \
           | grep -E "Submission completed|panicked|reverted" | head -5
       Within ~30 s expect another "Submission completed" line with an
       incremented finalized block.

GOTCHAS
  - Don't pass RAIKO_HOST_ZKVM inline to deploy-surge-full.sh — the script
    sources .env on every run and inline exports get overridden.
  - Don't pass SURGE_PRIVACY_MODE inline either; use --privacy-mode. The flag
    persists into .env so any re-source picks it up.
  - Foundry is needed for the cast command in Phase 4. If `cast: command not
    found`, prepend ~/.foundry/bin to PATH.
  - Stack-option 2 is the full stack (L1 + L2 + DEX + Blockscout). Use 0 or
    1 if you only need a subset, but they aren't covered by this prompt.

REPORT BACK
After each Phase, write one sentence: what completed, what you observed
(block height, latest "Submission completed" line, container counts). If a
step takes >5 min without log progress AND it's not a documented cold-start
wait, STOP and ask before retrying.
````

## Provenance

Last updated: 2026-05-28. Covers `simple-surge-node` `main` after the `deploy-prover.sh` / `deploy-surge-full.sh` split. The `--privacy-mode` CLI flag is the canonical opt-in for privacy; if the flag is removed or renamed in a future release, update this prompt and bump the date here.
