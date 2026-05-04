# Simple Surge Node — Claude Code Instructions

One-shot deploy a full Surge devnet (L1 + L2 + prover) on local, single-VM, or two-VM split. **Always pass `--force`** — without it the deploy script blocks on `read -p` prompts that Claude can't answer.

## `--deployment local` vs `--deployment remote`

The most common mistake. Get it wrong and DEX UI / Blockscout configs point at `localhost` instead of the VM's IP — they work on the VM but fail in any browser elsewhere.

| Flag | What it does | Use when |
|------|--------------|----------|
| `--deployment local` | Service URLs use `localhost` | Deploying **and** browsing on the same machine |
| `--deployment remote` | Auto-detects the machine's public IP and writes it into Blockscout/DEX UI configs | Deploying on a VM, accessing services from elsewhere |

If you SSH'd in to deploy → `--deployment remote`.

## Prerequisites (fresh VM)

```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Foundry (cast, forge, anvil)
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Kurtosis CLI
echo "deb [trusted=yes] https://apt.fury.io/kurtosis-tech/ /" | sudo tee /etc/apt/sources.list.d/kurtosis.list
sudo apt-get update && sudo apt-get install -y kurtosis-cli
kurtosis engine start

# Standard tools
sudo apt install -y jq curl bc
```

## Clone and prepare

```bash
git clone https://github.com/NethermindEth/simple-surge-node.git
cd simple-surge-node
git submodule update --init --recursive
cp .env.devnet .env
```

---

## Mock prover (no GPU)

Fastest path. No external prover required.

```bash
# Local machine
./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment local --stack-option 2 \
  --mock-prover --mode silence --force

# Remote VM
./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment remote --stack-option 2 \
  --mock-prover --mode silence --force
```

---

## Real ZisK prover (two-VM, recommended)

Minimum: 1x L40 or 1x RTX 5090. Single-GPU configs **must** be split across two VMs — a single GPU + L2 stack on one machine cannot keep up with Catalyst's preconf reorg window. For same-VM, use 4x L40 or 8x RTX 5090 minimum.

### Step 1 — Prover VM (has GPU)

```bash
git clone https://github.com/NethermindEth/raiko.git
cd raiko

# Installs apt deps, Rust, CUDA 12.x. Detects and purges legacy CUDA 11.x
# leftovers that cause "undefined symbol: cudaGetDeviceProperties_v2".
./script/install-zisk-deps.sh

# Install ZisK SDK + proving keys (~150 GB to ~/.zisk)
TARGET=zisk make install

# Start Raiko
cp docker/.env.sample.zk docker/.env
docker compose -f docker/docker-compose-zk.yml up -d

# Wait for the vkey (4–5 min multi-GPU; ~16 min single-GPU cold start)
curl localhost:8080/guest_data
# {"zisk":{"batch_vkey":"<64 hex>"}}
```

Open TCP/8080 to the L2 stack VM, verify reachability from there:

```bash
# From the L2 stack VM
curl http://<prover-ip>:8080/guest_data
```

### Step 2 — L2 stack VM

```bash
git clone https://github.com/NethermindEth/simple-surge-node.git
cd simple-surge-node
git submodule update --init --recursive
cp .env.devnet .env
```

**Edit `.env`** (don't pass it inline — `deploy-surge-full.sh` sources `.env` and overrides inline exports):

```bash
RAIKO_HOST_ZKVM=http://<prover-ip>:8080
```

Deploy:

```bash
./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment remote --stack-option 2 \
  --mode silence --force
```

The script auto-fetches the ZisK vkey from `<prover-ip>:8080/guest_data`, registers it on the verifier, and generates `configs/chain_spec_list.json` + `configs/config.json`.

### Step 3 — Sync configs back to the Prover VM

Raiko started with the default chain spec; replace it and restart:

```bash
# From the L2 stack VM
scp configs/chain_spec_list.json <prover-host>:~/raiko/host/config/devnet/chain_spec_list.json
scp configs/config.json         <prover-host>:~/raiko/host/config/devnet/config.json

# On the Prover VM
cd ~/raiko
docker compose -f docker/docker-compose-zk.yml up -d --force-recreate
```

The first proof after `--force-recreate` triggers another ~16 min cold start on single-GPU configs. Multi-GPU is faster.

---

## Real ZisK prover (single VM, 4x L40 / 8x RTX 5090 only)

In `simple-surge-node/.env`:

```bash
RAIKO_HOST_ZKVM=http://host.docker.internal:8080
```

(`localhost` won't work — Catalyst is in a container.) Run `./deploy-surge-full.sh --deployment local` (or `remote`). No scp/restart step — configs are local.

---

## Post-deployment

Always report endpoints. Replace `<IP>` with `localhost` (local) or the VM's public IP (remote):

| Service | URL |
|---------|-----|
| L1 RPC | `http://<IP>:32003` |
| L2 RPC | `http://<IP>:8547` |
| L2 WebSocket | `ws://<IP>:8548` |
| L2 Catalyst | `http://<IP>:4545` |
| L2 Blockscout | `http://<IP>:3001` |
| DEX UI | `http://<IP>:5173` |
| Raiko (mock) | `http://<IP>:8082` |
| Raiko (zisk, two-VM) | `http://<prover-ip>:8080` |

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
./remove-surge-full.sh --force   # full teardown
cp .env.devnet .env              # always re-copy before fresh deploy
./deploy-surge-full.sh --environment devnet --deploy-devnet true \
  --deployment remote --stack-option 2 --mock-prover --mode silence --force
```

For real-prover redeploys: also scp configs back to the Prover VM and `docker compose -f docker/docker-compose-zk.yml up -d --force-recreate`.

## Common pitfalls

- **Wrong `--deployment` flag.** `local` on a remote VM means DEX UI / Blockscout reach `localhost` from a browser elsewhere. Use `remote` for VMs.
- **Missing `--force`.** Script blocks on interactive prompts over a non-interactive SSH session.
- **Foundry not in PATH.** `cast` lives at `~/.foundry/bin/cast`. Source `~/.bashrc` or prepend `PATH="$HOME/.foundry/bin:$PATH"`.
- **Kurtosis engine not started.** Run `kurtosis engine start` after installing the CLI.
- **Stale `.env`.** Always re-copy `.env.devnet` before a fresh deploy. Stale contract addresses + block heights from a previous run silently break things.
- **Real prover: `RAIKO_HOST_ZKVM` set inline.** Gets overridden when `.env` is sourced. Edit `.env` directly.
- **Real prover: `localhost` for `RAIKO_HOST_ZKVM`.** Catalyst is in a container; `localhost` is the container's loopback. Use `host.docker.internal:8080` (same-VM) or `<prover-ip>:8080` (two-VM).
- **Real prover: TCP/8080 not open on the prover VM.** Catalyst can't reach Raiko. Open the port and verify with `docker exec l2-catalyst-node curl -m 5 $RAIKO_HOST_ZKVM/guest_data`.
- **Real prover: `Batches: 0` and `currOperator=0x0` in driver logs.** `currOperator=0x0` is harmless legacy noise; the realtime fork doesn't use the preconf whitelist. Real cause is usually proof timeout (single-GPU cold start) or Raiko unreachable from Catalyst's container.
