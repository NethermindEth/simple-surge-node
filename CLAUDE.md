# Simple Surge Node — Claude Code Instructions

Two top-level scripts, by role:

| Script | Role | Needs |
|--------|------|-------|
| `deploy-prover.sh` | Raiko ZisK prover (real proofs) | NVIDIA GPU on host |
| `deploy-surge-full.sh` | L2 stack (Kurtosis L1 + contracts + Catalyst + driver) | no GPU; mock proofs by default |

Pick based on what role the host should play. **Always pass `--force`** — without it both scripts block on interactive prompts agents can't answer.

- **Same beefy box (one VM)**: run `deploy-prover.sh` first (raiko up), then `deploy-surge-full.sh` (L2 stack). Prover-first ordering avoids `deploy-surge-full.sh`'s Raiko-readiness check timing out.
- **Two VMs (recommended for non-trivial GPU configs)**: prover VM runs `deploy-prover.sh`; L2 stack VM runs `deploy-surge-full.sh` with `RAIKO_HOST_ZKVM=http://<prover-ip>:8080` in `.env`. Post-deploy, `scp configs/{chain_spec_list,config}.json` from the L2 VM to the prover and `docker compose -f docker/docker-compose-zk.yml up -d --force-recreate` there.
- **No GPU anywhere**: just `deploy-surge-full.sh --mock-prover`. Catalyst signs mock proofs; no Raiko build needed.

Privacy mode is an orthogonal opt-in — see the dedicated section below. Mock vs real ZisK doesn't change the keygen/distribution flow, only the real-ZisK side additionally needs the guest rebuilt with matching hashes.

This file only documents what's specific to driving the scripts *as an agent*. For the full guide (prerequisites, two-VM splits, troubleshooting, hardware requirements), read [docs.surge.wtf/guides/running-surge](https://docs.surge.wtf/guides/running-surge) first.

## `--deployment local` vs `--deployment remote`

The most common mistake. Get it wrong and DEX UI / Blockscout configs point at `localhost` instead of the VM's IP — they work on the VM but fail in any browser elsewhere.

| Flag | What it does | Use when |
|------|--------------|----------|
| `--deployment local` | Service URLs use `localhost` | Deploying **and** browsing on the same machine |
| `--deployment remote` | Auto-detects the machine's public IP and writes it into Blockscout/DEX UI configs | Deploying on a VM, accessing services from elsewhere |

If you SSH'd in to deploy → `--deployment remote`.

## One-shot deploys

### Mock prover (no GPU)

```bash
# Local
./deploy-surge-full.sh --environment devnet --deploy-devnet true \
  --deployment local --stack-option 2 --mock-prover --mode silence --force

# Remote VM
./deploy-surge-full.sh --environment devnet --deploy-devnet true \
  --deployment remote --stack-option 2 --mock-prover --mode silence --force
```

### Real ZisK prover

Set up Raiko first via `deploy-prover.sh`:

```bash
# On the prover VM (or same-VM run before deploy-surge-full.sh):
./deploy-prover.sh --force
```

That handles: NVIDIA + Docker pre-flight, raiko submodule init, apt+Rust+CUDA install, ZisK SDK install (~150 GB to `~/.zisk`), `docker compose up -d` for raiko-zk, and a poll on `/guest_data` until the vkey returns.

Then on the L2 VM, **don't pass `RAIKO_HOST_ZKVM` inline** — `deploy-surge-full.sh` sources `.env` on every run and overrides any inline export. Edit `.env` first:

```bash
RAIKO_HOST_ZKVM=http://host.docker.internal:8080    # same VM
# or
RAIKO_HOST_ZKVM=http://<prover-ip>:8080              # two VMs
```

Then deploy:

```bash
./deploy-surge-full.sh --environment devnet --deploy-devnet true \
  --deployment remote --stack-option 2 --mode silence --force
```

For two-VM splits and the prover hardware matrix, see [docs.surge.wtf/guides/running-surge/provers](https://docs.surge.wtf/guides/running-surge/provers).

### Privacy mode

Privacy mode is opt-in via `SURGE_PRIVACY_MODE=true` in `.env`. It's orthogonal to the prover type — applies to both mock and real ZisK runs. Components that consume the keys at runtime:

| Component | Needs keys? |
|-----------|-------------|
| Catalyst | yes (encrypts blob bytes) |
| Driver | yes (decrypts to rebuild L2 blocks) |
| Real ZisK raiko host | yes (decrypts → builds witness for the guest) |
| Real ZisK raiko guest | yes at runtime, **also needs matching hashes baked in at compile time** |
| Mock raiko | no (bypasses the proof, signs ECDSA on whatever it receives) |

Workflow (same regardless of prover):

```bash
# 1. Edit .env on the L2 VM
sed -i 's|^SURGE_PRIVACY_MODE=.*|SURGE_PRIVACY_MODE=true|' .env

# 2. Run / re-run deploy-surge-full.sh — generate_privacy_bundle is gated on
#    SURGE_PRIVACY_MODE=true; it runs only when the flag is set, writes
#    .privacy.env, and Catalyst+Driver pick up the keys via Compose interpolation.
./deploy-surge-full.sh ... --force

# 3. Sync to the real ZisK prover (skip if using mock — mock doesn't participate).
#    Same-VM:
./script/sync-privacy-to-prover.sh --local --rebuild
#    Two-VM (from L2 VM):
./script/sync-privacy-to-prover.sh --rebuild user@<prover-host>

# 4. Recreate catalyst so the new env reaches the running container.
docker compose -f docker-compose.yml --profile catalyst up -d --force-recreate catalyst
```

`--rebuild` rebuilds only the ZisK guest ELFs (~30 s on warm cache) and recreates raiko-zk — the prebuilt host image stays. Use `./script/sync-privacy-to-prover.sh --print` to dump values without applying. Flipping privacy on with mismatched hashes on the real ZisK side panics raiko with `privacy dispatch failed: Truncated`.

Alternative on the prover VM (skips the SSH dance): `./deploy-prover.sh --privacy-mode --privacy-env /path/to/.privacy.env`.

## Built-in Raiko readiness check

After the L2 stack is up but before any DEX/L2 transaction, the script verifies Raiko is reachable. If it fails, the script aborts immediately with an actionable hint (real prover: `scp` configs + `docker compose ... up -d --force-recreate` on the prover VM). No DEX deploy, no Catalyst proof requests against an unready prover. Single-GPU configs typically need the two-VM step-3 sync described in the prover guide.

## Post-deployment

Always print endpoints. Replace `<IP>` with `localhost` (local) or the VM's public IP (remote):

| Service | URL |
|---------|-----|
| L1 RPC | `http://<IP>:32003` |
| L2 RPC | `http://<IP>:8547` |
| L2 WebSocket | `ws://<IP>:8548` |
| L2 Catalyst | `http://<IP>:4545` |
| L2 Blockscout | `http://<IP>:3001` |
| DEX UI | `http://<IP>:5173` |
| Raiko (mock) | `http://<IP>:8082` |
| Raiko (real, two-VM) | `http://<prover-ip>:8080` |

Verify:

```bash
docker compose ps
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8547
docker logs l2-catalyst-node | grep Batches    # Batches: N (N>0) confirms blocks landing
```

## Teardown and redeploy

```bash
./remove-surge-full.sh --force          # full teardown (keeps .env)
cp .env.devnet .env                     # always re-copy before fresh deploy
./deploy-surge-full.sh --environment devnet --deploy-devnet true \
  --deployment remote --stack-option 2 --mock-prover --mode silence --force
```

For real-prover redeploys, also `scp` the regenerated configs back to the Prover VM and `docker compose -f docker/docker-compose-zk.yml up -d --force-recreate` (see prover guide).

## Common pitfalls when driving the script

- **Wrong `--deployment` flag.** See above. `local` on a remote VM means DEX UI / Blockscout reach `localhost` from a browser elsewhere.
- **Missing `--force`.** Script blocks on interactive prompts over a non-interactive SSH session.
- **Foundry not in PATH.** `cast` lives at `~/.foundry/bin/cast`. Source `~/.bashrc` or prepend `PATH="$HOME/.foundry/bin:$PATH"`.
- **Kurtosis engine not started.** Run `kurtosis engine start` after installing the CLI.
- **Stale `.env`.** Always re-copy `.env.devnet` before a fresh deploy. Stale contract addresses + block heights silently break things.
- **Real prover: `RAIKO_HOST_ZKVM` set inline.** Gets overridden when `.env` is sourced. Edit `.env` directly.
- **Real prover: `localhost` for `RAIKO_HOST_ZKVM`.** Catalyst is in a container; `localhost` is the container's loopback. Use `host.docker.internal:8080` (same-VM) or `<prover-ip>:8080` (two-VM).
- **Real prover: `Batches: 0` and `currOperator=0x0` in driver logs.** `currOperator=0x0` is harmless legacy noise; the realtime fork doesn't use the preconf whitelist. Real cause is usually proof timeout (single-GPU cold start) or Raiko unreachable from Catalyst's container.
