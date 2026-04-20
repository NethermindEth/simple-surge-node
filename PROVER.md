# ZisK Prover Setup

Run a real-time ZK prover for your Surge devnet. The prover generates ZisK proofs that finalize L2 blocks on L1 in ~10-17 seconds.

## When do you need this?

- **Mock prover (`--mock-prover`)**: No GPU required. Blocks finalize instantly with dummy proofs. Good for local development and testing.
- **Real prover (this guide)**: Requires an NVIDIA GPU with 32 GB+ VRAM. Blocks finalize with actual ZK proofs. Required for production and staging.

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | CUDA-capable, 32 GB VRAM | NVIDIA RTX 5090 or L40 |
| RAM | 128 GB | 256 GB |
| CPU | 8 cores | 16 cores |
| Disk | 150 GB SSD | 300 GB NVMe |
| OS | Ubuntu 24.04 (GLIBC >= 2.36) | Ubuntu 24.04 |

## Performance

| GPU Config | Proof Time |
|------------|-----------|
| 1x L40 | ~27s |
| 2x L40 | ~20s |
| 4x L40 | ~15s |
| 8x L40 | ~13-14s |
| 8x RTX 5090 | ~10-11s |

## Option A: Docker (recommended)

### Prerequisites

- Docker + Docker Compose
- NVIDIA drivers installed (`nvidia-smi` should work)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

```bash
# Install NVIDIA Container Toolkit (Ubuntu/Debian)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

### Install ZisK proving keys on the host

The Docker container mounts `~/.zisk` from the host. Install the keys first:

```bash
git clone https://github.com/NethermindEth/raiko.git
cd raiko
TARGET=zisk make install
```

This takes a while and needs **150 GB+** of disk space. If your home directory lacks space:

```bash
ZISK_DIR=/path/to/large/disk TARGET=zisk make install
```

### Copy chain spec from your deployment

After running `deploy-surge-full.sh`, the chain spec is generated at `configs/chain_spec_list.json`:

```bash
cp /path/to/simple-surge-node/configs/chain_spec_list.json host/config/devnet/chain_spec_list.json
```

### Run

```bash
cd raiko/docker
docker compose -f docker-compose-zk.yml up -d
```

### Verify

```bash
# Check container
docker compose -f docker-compose-zk.yml ps

# Check logs
docker compose -f docker-compose-zk.yml logs -f

# Get batch verification key (takes 4-5 min on first run)
curl localhost:8080/guest_data
```

## Option B: Bare Metal

### System dependencies

```bash
sudo apt-get update && sudo apt-get install -y \
    build-essential cmake pkg-config git curl wget nasm \
    gcc-riscv64-unknown-elf \
    libgmp-dev libssl-dev libsodium-dev \
    libomp-dev libomp5 \
    libopenmpi-dev openmpi-bin \
    nlohmann-json3-dev protobuf-compiler \
    clang libclang-dev

# Symlink libomp as libiomp5 (required by zisk-distributed-worker linker)
sudo ln -sf /usr/lib/x86_64-linux-gnu/libomp.so.5 /usr/lib/x86_64-linux-gnu/libiomp5.so
sudo ldconfig
```

### Build

```bash
git clone https://github.com/NethermindEth/raiko.git
cd raiko

# Install ZisK backend + proving keys (~150 GB)
TARGET=zisk make install

# Compile guest program
TARGET=zisk make guest
```

### Copy chain spec

```bash
cp /path/to/simple-surge-node/configs/chain_spec_list.json host/config/devnet/chain_spec_list.json
```

### Run

```bash
nohup env RUST_LOG=info \
    cargo run --release --features zisk -- \
    --config-path=host/config/devnet/config.json \
    --chain-spec-path=host/config/devnet/chain_spec_list.json \
    > raiko.log 2>&1 &
```

## Connecting to your Surge devnet

Once Raiko is running and `curl localhost:8080/guest_data` returns a response, deploy (or redeploy) your Surge devnet pointing at the prover:

```bash
RAIKO_HOST_ZKVM=http://<prover-ip>:8080 ./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment local --stack-option 2 --mode silence --force
```

If the devnet is already running with mock prover and you want to switch to real prover, you need to redeploy L1 contracts (the verifier changes):

```bash
# Wipe everything except L1 enclave
./remove-surge-full.sh \
  --remove-l1-devnet false \
  --remove-l2-stack true \
  --remove-data true \
  --remove-configs true \
  --force

# Redeploy with real prover
RAIKO_HOST_ZKVM=http://<prover-ip>:8080 ./deploy-surge-full.sh \
  --environment devnet --deploy-devnet false \
  --deployment local --stack-option 2 --mode silence --force
```

If the prover is on a different machine than the L2 stack, replace `localhost:8080` with the prover machine's IP.

## Troubleshooting

**Cold start takes ~70s**: The first proof is slow due to ZisK and ELF initialization. Subsequent proofs run at ~10-17s.

**`lib-float` build failure on RTX 5090**: The `float.o` file can disappear mid-archive during parallel compilation. Fix with single-threaded build:

```bash
CARGO_BUILD_JOBS=1 TARGET=zisk make install
```

**GPU memory errors on heavy blocks**: Monitor with `nvidia-smi -l 1`. Blocks with many transactions need more VRAM.

**VKey changes after guest code update**: Re-fetch and re-register:

```bash
curl localhost:8080/guest_data
# Then redeploy with the new vkey
```
