# ZisK Prover Setup

Run a real-time ZisK prover for your Surge devnet. Proofs finalize L2 blocks on L1 in ~10–17 seconds (steady state, multi-GPU).

## When do you need this?

| Mode | GPU? | Use case |
|------|------|----------|
| Mock prover (`--mock-prover`) | No | Local dev, testing |
| Real ZisK prover (this guide) | Yes (32 GB+ VRAM) | Staging, production |

## Hardware

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | 1x L40 or 1x RTX 5090 | 4x L40 or 8x RTX 5090 |
| RAM | 128 GB | 256 GB |
| CPU | 32 cores | 64 cores |
| Disk | 150 GB SSD | 300 GB NVMe |
| OS | Ubuntu 22.04+ (Docker) | Ubuntu 24.04 (bare metal needs GLIBC ≥ 2.36) |

> **Single-GPU configs require two VMs.** Catalyst's preconf reorg window is ~30s; a single L40 is ~27s steady-state and ~16 min cold-start. Sharing a VM with the L2 stack means proofs miss the window and the chain can't advance past block 1. For one VM, use 4x L40 or 8x RTX 5090. Anything smaller, split the prover from the L2 stack across two VMs.

## Performance

| GPU config | Steady-state proof time |
|------------|-------------------------|
| 1x L40 | ~27s |
| 4x L40 | ~15s |
| 8x L40 | ~13–14s |
| 8x RTX 5090 | ~10–11s |

> **Cold start is much longer than steady state.** Single-GPU first proof is ~16 minutes (proofman init + SNARK setup), not 70s. Subsequent proofs settle to ~3 min. Multi-GPU configs hit steady state much sooner. The L2 chain looks stuck at block 1 until the first proof lands.

## Two-VM deployment (recommended)

One VM for Raiko + GPU, another for the L2 stack.

### 1. On the Prover VM

```bash
# Clone raiko
git clone https://github.com/NethermindEth/raiko.git
cd raiko

# Install system dependencies (apt packages, Rust, CUDA 12.x with linker pinning).
# Also detects and purges legacy CUDA 11.x leftovers that cause
# "undefined symbol: cudaGetDeviceProperties_v2" on Hopper/Blackwell GPUs.
./script/install-zisk-deps.sh

# Install ZisK SDK + proving keys (~150 GB to ~/.zisk)
TARGET=zisk make install
# Or, if ~/.zisk is on a small disk:
# ZISK_DIR=/path/to/large/disk TARGET=zisk make install

# Start Raiko
cp docker/.env.sample.zk docker/.env
docker compose -f docker/docker-compose-zk.yml up -d

# Wait for the vkey (~4–5 min multi-GPU; ~16 min single-GPU cold start)
curl localhost:8080/guest_data
```

Expected response:

```json
{"zisk":{"batch_vkey":"2ccafa601f5e29e4d61fc2d96474c98c3b752999b97af38c4c988c0fee24f0a0"}}
```

Open TCP/8080 to the L2 stack VM and verify reachability from there:

```bash
# From the L2 stack VM
curl http://<prover-ip>:8080/guest_data
```

### 2. On the L2 stack VM

```bash
git clone https://github.com/NethermindEth/simple-surge-node.git
cd simple-surge-node
git submodule update --init --recursive
cp .env.devnet .env
```

Edit `.env`:

```bash
RAIKO_HOST_ZKVM=http://<prover-ip>:8080
```

> Don't pass `RAIKO_HOST_ZKVM` inline — `deploy-surge-full.sh` sources `.env` on every run and inline exports get overridden.

Deploy with the real prover:

```bash
./deploy-surge-full.sh \
  --environment devnet \
  --deploy-devnet true \
  --deployment remote \
  --stack-option 2 \
  --mode silence \
  --force
```

The deploy script automatically:
- Fetches the ZisK batch vkey from `<prover-ip>:8080/guest_data`
- Registers it on the on-chain ZisK verifier
- Generates `configs/chain_spec_list.json` and `configs/config.json`
- Starts Catalyst pointed at the prover

### 3. Sync configs back to the Prover VM

Raiko started with the default chain spec; replace it with the real one and restart:

```bash
# From the L2 stack VM
scp configs/chain_spec_list.json <prover-host>:~/raiko/host/config/devnet/chain_spec_list.json
scp configs/config.json         <prover-host>:~/raiko/host/config/devnet/config.json

# On the Prover VM
cd ~/raiko
docker compose -f docker/docker-compose-zk.yml up -d --force-recreate
```

`--force-recreate` is needed so the container picks up the remounted config files. The first proof after the restart triggers another cold start (~16 min on single-GPU; quicker on multi-GPU).

## Same-VM deployment

Realistic only with 4x L40 or stronger. Catalyst's container reaches Raiko via the host gateway:

```bash
# In simple-surge-node/.env
RAIKO_HOST_ZKVM=http://host.docker.internal:8080
```

A bare `localhost` won't work — Catalyst is in a container.

The rest of the flow matches two-VM, minus the scp + restart step (configs are local).

## Switching from mock to real prover

The on-chain verifier changes (`ProofVerifierDummy` → `SurgeVerifier`), so L1 contracts must redeploy:

```bash
# On the L2 stack VM, keep the L1 enclave alive but wipe everything else
./remove-surge-full.sh \
  --remove-l1-devnet false \
  --remove-l2-stack true \
  --remove-data true \
  --remove-configs true \
  --force

# Set RAIKO_HOST_ZKVM in .env first, then:
./deploy-surge-full.sh \
  --environment devnet \
  --deploy-devnet false \
  --deployment remote \
  --stack-option 2 \
  --mode silence \
  --force
```

Then sync the new configs to the Prover VM and `--force-recreate` Raiko.

## Troubleshooting

**`Batches: 0` in Catalyst logs.** Test reachability from inside the catalyst container:
```bash
docker exec l2-catalyst-node curl -m 5 $RAIKO_HOST_ZKVM/guest_data
```
If that fails, the endpoint is wrong. Same-VM uses `host.docker.internal:8080`. Two-VM uses the prover's public/LAN IP.

**Driver logs show `currOperator=0x0`.** Harmless legacy log line. The realtime fork doesn't use the preconf whitelist; proposing flows through `RealTimeInbox.propose()` permissionlessly. Catalyst already considers itself the operator.

**L2 stuck at block 1 for 15+ minutes.** Single-GPU cold start. Watch `nvidia-smi -l 5` on the prover — proofman + SNARK init are burning ~50% GPU. Wait for the first proof; subsequent proofs are ~5x faster.

**TCP/8080 not reachable from the L2 stack VM.** Open the port:
```bash
sudo ufw allow 8080/tcp
# or your provider's security group
```

**`lib-float` build failure on RTX 5090 / Blackwell.** `install-zisk-deps.sh` already passes `CARGO_BUILD_JOBS=1` to `make install`. If invoking `make install` outside the script:
```bash
CARGO_BUILD_JOBS=1 TARGET=zisk make install
```

**`undefined symbol: cudaGetDeviceProperties_v2`.** Apt's old `nvidia-cuda-toolkit` (CUDA 11.5) leftovers on the linker path. Re-run `install-zisk-deps.sh` — it detects this state ("cleanup-only" mode) and offers to purge.

**GPU memory errors on heavy blocks.** Bridge-heavy transactions need more VRAM. Spot-check with `nvidia-smi -l 1`; don't run continuously, since `nvidia-smi` briefly locks the GPU and slows proving.

**VKey changes after guest code update.** Re-fetch and redeploy:
```bash
curl localhost:8080/guest_data
# Use the new vkey when redeploying simple-surge-node
```
