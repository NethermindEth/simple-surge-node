# Simple Surge Node — Claude Code Instructions

Claude can one-shot deploy a full Surge devnet (L1 + L2 + prover) with `deploy-surge-full.sh`. **Always pass `--force`** — without it the script blocks on `read -p` prompts that Claude can't answer.

This file only documents what's specific to driving the deploy script *as an agent*. For the full guide (prerequisites, prover setup, two-VM splits, troubleshooting, hardware requirements), read [docs.surge.wtf/guides/running-surge](https://docs.surge.wtf/guides/running-surge) first.

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

Requires Raiko already running. **Don't pass `RAIKO_HOST_ZKVM` inline** — `deploy-surge-full.sh` sources `.env` on every run and overrides any inline export. Edit `.env` first:

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

For two-VM and single-VM real-prover setup, follow [docs.surge.wtf/guides/running-surge/provers](https://docs.surge.wtf/guides/running-surge/provers).

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
