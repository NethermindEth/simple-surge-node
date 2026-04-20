# simple-surge-node

Tools for deploying and managing a full Surge stack: L1 devnet, L1 protocol contracts, L2 execution client, and optional DEX.

> **Dev/testing only.** Not intended for production use.

## Prerequisites

### System requirements

- Docker Desktop (or Docker Engine + Compose plugin) — running with sufficient resources
  - Recommended: 16 GB RAM, 4 CPU cores, 50 GB free disk
- Git
- [Kurtosis CLI](https://docs.kurtosis.com/install) — for the L1 devnet
- `jq`, `curl`, `bc` — standard Unix tools
- `cast` — part of [Foundry](https://book.getfoundry.sh/getting-started/installation)

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install Kurtosis:
```bash
brew install kurtosis-tech/tap/kurtosis-cli   # macOS
# or follow https://docs.kurtosis.com/install for Linux
```

### Accounts

| Key | Used for | Devnet default |
|-----|----------|----------------|
| `PRIVATE_KEY` | Deploying L1 contracts | Pre-funded in devnet |
| `OPERATOR_PRIVATE_KEY` | L2 Driver/Catalyst operator | Pre-funded in devnet |
| `SUBMITTER_PRIVATE_KEY` | Transaction submitter | Pre-funded in devnet |

`.env.devnet` ships with pre-funded keys — no wallet setup needed for local devnet.

### Prover

There are two proving modes:

**Mock prover** (default for local testing)
- No GPU or external prover required
- Deploys a `ProofVerifierDummy` contract that accepts any signed proof
- Select `0` at the prover prompt, or set `MOCK_PROOF_MODE=true` in `.env`
- The L2 stack includes an embedded Raiko instance (`l2-raiko-zk-client`) when mock mode is active

**Real prover (ZisK)**
- Requires a separate machine with an NVIDIA GPU (RTX 5090 or L40 class, 32 GB+ VRAM)
- Set `RAIKO_HOST_ZKVM=http://<prover-ip>:8082` in `.env` before deploying
- Select `1` at the prover prompt
- After L1 deployment the script registers the ZisK program vkey on-chain via `setup-zisk.sh` and verifies it with `isProgramTrusted` before locking

See [Prover Setup](https://docs.surge.wtf/guides/running-surge/provers) for full GPU requirements and Raiko configuration.

## Setup

```bash
git clone https://github.com/NethermindEth/simple-surge-node.git
cd simple-surge-node
git submodule update --init --recursive
```

Copy the environment template:

```bash
cp .env.devnet .env
```

## Deploy

```bash
./deploy-surge-full.sh
```

The script runs interactively. You can also pass flags to skip prompts:

```bash
# Mock prover — no GPU required (fastest for local testing)
./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment local --stack-option 2 --mock-prover --mode silence --force

# Real prover — point at a running Raiko instance
RAIKO_HOST_ZKVM=http://<prover-ip>:8082 ./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment local --stack-option 2 --mode silence --force
```

### Interactive prompts (in order)

| Step | Prompt | Options |
|------|--------|---------|
| 1 | Environment | `devnet` |
| 2 | Deployment type | `local` (same machine) / `remote` (VM) |
| 3 | L1 devnet | Deploy new / Use existing (devnet only) |
| 4 | Execution mode | `silence` (progress bar) / `debug` (full output) |
| 5 | Mock or real prover | `0` mock / `1` real (devnet only) |
| 6 | L2 stack option | See table below |

### L2 stack options

| Option | Components |
|--------|------------|
| 1 | Driver only |
| 2 | Driver + Catalyst (default) |
| 3 | Driver + Catalyst + Spammer |

### CLI flags

| Flag | Values | Default |
|------|--------|---------|
| `--environment` | `devnet` | interactive |
| `--deploy-devnet` | `true` \| `false` | interactive |
| `--deployment` | `local` \| `remote` | interactive |
| `--stack-option` | `1`–`3` | interactive |
| `--mock-prover` | — | use mock prover (no GPU) |
| `--mode` | `silence` \| `debug` | interactive |
| `--running-provers` | `true` \| `false` | interactive |
| `-f`, `--force` | — | skip all prompts (defaults: deploy tokens, silence mode) |
| `-h`, `--help` | — | show help |

### What gets deployed

```
L1 devnet (Kurtosis / ethereum-package)
  └── Execution client + beacon chain

L1 protocol contracts
  ├── RealTimeInbox (SurgeInbox)
  ├── SurgeVerifier
  ├── Bridge + SignalService
  ├── ERC20/721/1155 vaults
  ├── Multicall
  └── UserOpsSubmitter

L2 genesis + chainspec

L2 stack (Docker Compose)
  ├── l2-nethermind-execution-client
  ├── l2-taiko-consensus-client (Driver)
  ├── web3signer-l1, web3signer-l2
  └── l2-catalyst-node (Catalyst, option 2+)

Cross-chain DEX (optional)
  ├── L1_VAULT + L2_VAULT
  ├── L2_DEX + L2_TOKEN
  └── DEX UI (Nginx container)
```

## Service endpoints

After deployment, the summary table prints all endpoints. Defaults for a local devnet:

| Service | URL |
|---------|-----|
| L1 RPC | `http://localhost:32003` |
| L1 WebSocket | `ws://localhost:32004` |
| L1 Beacon | `http://localhost:33001` |
| L1 Blockscout | `http://localhost:36005` |
| L2 RPC | `http://localhost:8547` |
| L2 WebSocket | `ws://localhost:8548` |
| L2 Blockscout | `http://localhost:3001` |
| DEX UI | `http://localhost:3002` |

> On a remote VM, replace `localhost` with the machine's public IP. The script detects this automatically when you choose `remote` at the deployment type prompt.

## Remove

```bash
# Interactive — choose what to remove
./remove-surge-full.sh

# Remove everything except .env
./remove-surge-full.sh --force

# Remove everything including .env
./remove-surge-full.sh --force --remove-env true
```

`--force` removes: L1 devnet, L2 stack, data directories, and config files — no prompts.

## Restart L2 stack

Restart Nethermind, the Taiko driver, Catalyst, and any other L2 containers **without redeploying anything** — L1 devnet, L1 contracts, and chain data are all preserved.

```bash
# 1. Stop L2 containers only
./remove-surge-full.sh \
  --remove-l1-devnet false \
  --remove-l2-stack true \
  --remove-data false \
  --remove-configs false \
  --force

# 2. Start L2 stack against the existing deployment
./deploy-surge-full.sh \
  --environment devnet \
  --deploy-devnet false \
  --deployment local \
  --stack-option 2 \
  --force
```

## Redeploy L2 stack

Keep the L1 Kurtosis enclave running but wipe and redeploy everything else — L1 contracts, L2 genesis, and the full L2 stack — from scratch.

```bash
# 1. Stop L2 containers, wipe data and all deployment artifacts (keep L1 enclave)
./remove-surge-full.sh \
  --remove-l1-devnet false \
  --remove-l2-stack true \
  --remove-data true \
  --remove-configs true \
  --force

# 2. Redeploy against the existing L1 enclave (skip Kurtosis spin-up)
./deploy-surge-full.sh \
  --environment devnet \
  --deploy-devnet false \
  --deployment local \
  --stack-option 2 \
  --force
```

Replace `--stack-option 2` with `1` (driver only) or `3` (driver + catalyst + spammer) to match your desired setup.

## Collect logs

`collect-devnet-logs.sh` takes a diagnostic snapshot of all running devnet containers — useful for sharing bug reports or investigating failures.

```bash
# Full snapshot (L1 enclave dump + all L2 container logs)
./collect-devnet-logs.sh

# Last 30 minutes of L2 logs only
./collect-devnet-logs.sh --since 30m

# L1 enclave dump only
./collect-devnet-logs.sh --l1-only

# L2 docker logs only
./collect-devnet-logs.sh --l2-only

# Custom output directory
./collect-devnet-logs.sh -o /tmp/surge-diag
```

Output is saved to `./logs/snapshot-YYYYMMDD-HHMMSS/` by default:

```
snapshot-20260414-120000/
├── system-info.txt          # docker/kurtosis versions, running containers
├── l1/                      # kurtosis enclave dump (L1 service logs + artifacts)
└── l2/
    ├── _docker-compose-ps.txt
    ├── l2-nethermind-execution-client.log
    ├── l2-taiko-consensus-client.log
    ├── l2-catalyst-node.log
    └── ...
```

**L1** uses `kurtosis enclave dump surge-devnet` — captures logs and artifacts for all L1 services.  
**L2** runs `docker logs --timestamps` per container from `docker-compose.yml`.

## Troubleshooting

**L1 health check fails after devnet start**
Kurtosis may still be assigning ports. Wait 15–30 seconds and rerun.

**`docker compose` can't reach L1 RPC (`host.docker.internal`)**
The `.env` uses `host.docker.internal` for container-to-host routing. From your shell, use `localhost` (or the machine IP for remote). The script handles the translation automatically.

**Containers still running after `--force` remove**
The script falls back to `docker kill + docker rm -f` by name. If a container is unkillable (kernel D-state), restart Docker Desktop.

**Mock prover: blocks propose but never finalize**
`ProofVerifierDummy` requires the proof to be signed by `MOCK_PROOF_SIGNER` (defaults to `PUBLIC_KEY`). Confirm that `MOCK_PROOF_MODE=true` was set during L1 deployment and that `MOCK_PROOF_SIGNER` matches the key the Raiko mock instance is signing with.

**Real prover: `ZISK guest data is missing`**
Raiko must be running and reachable at `RAIKO_HOST_ZKVM` before deployment. Check: `curl $RAIKO_HOST_ZKVM/guest_data`.

**`cast` not found**
Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`

**Kurtosis enclave already exists**
The script prompts to remove it. With `--force` it removes automatically. Manual: `kurtosis enclave rm surge-devnet --force`

## Contract error codes

Custom error selectors for the Surge devnet contracts — useful when decoding raw revert data from `cast run` or transaction receipts.

| Selector | Error | Contract |
|---|---|---|
| `0x8baa579f` | `InvalidSignature()` | ProofVerifierDummy |
| `0x815e1d64` | `InvalidSigner()` | ProofVerifierDummy |
| `0xef65161f` | `AlreadyActivated()` | RealTimeInbox |
| `0x5f22a971` | `MaxAnchorBlockTooOld()` | RealTimeInbox |
| `0xcd21cd43` | `InvalidGenesisBlockHash()` | RealTimeInbox |
| `0x037c597f` | `NotActivated()` | RealTimeInbox |
| `0x5353f567` | `SignalSlotNotSent(bytes32)` | RealTimeInbox |
| `0x1e1dc123` | `Surge_AlreadyMarkedForProposalId()` | SurgeVerifier |
| `0xcb47cd7d` | `Surge_CallerIsNotInbox()` | SurgeVerifier |
| `0x92570ec6` | `Surge_InstantUpgradeNotAllowed()` | SurgeVerifier |
| `0x50b89aa1` | `Surge_InvalidProofBitFlag()` | SurgeVerifier |
| `0x38f40518` | `Surge_NumProofsThresholdNotMet()` | SurgeVerifier |
| `0x7f1ebce8` | `ZISK_INVALID_PROGRAM_VKEY()` | ZiskVerifier |
| `0x3e68f163` | `ZISK_INVALID_CHAIN_ID()` | ZiskVerifier |
| `0x9a3c15ed` | `ZISK_INVALID_REMOTE_VERIFIER()` | ZiskVerifier |
| `0xf35598da` | `ZISK_INVALID_PARAMS()` | ZiskVerifier |
| `0x5f6b000c` | `ZISK_INVALID_PROOF()` | ZiskVerifier |
| `0x6bd71942` | `ZISK_INVALID_ROOT_CV()` | ZiskVerifier |

To decode a revert on-chain:
```bash
cast run <tx-hash> --rpc-url http://localhost:32003
```

## Directory layout

```
simple-surge-node/
├── deploy-surge-full.sh         # Main deploy script
├── remove-surge-full.sh         # Teardown script
├── helpers.sh                   # Shared functions (URL utils, prompts, config helpers)
├── docker-compose.yml           # L2 stack (driver, catalyst, web3signer, blockscout, dex)
├── docker-compose-protocol.yml  # L1 deployer containers
├── .env.devnet                  # Environment template for local devnet
│
├── deployer/                    # Shell scripts run inside protocol containers
│   ├── deploy-surge-l1.sh       # Deploys core L1 protocol contracts
│   ├── deploy-multicall.sh      # Deploys Multicall contract
│   ├── deploy-userops-submitter.sh
│   ├── generate-genesis.sh      # Generates L2 genesis from L1 state
│   ├── setup-zisk.sh            # Registers ZisK program vkey on ZiskVerifier
│   ├── deploy-cross-chain-relay.sh
│   └── dex/                     # Cross-Chain DEX deployment
│       ├── deploy-dex-l1.sh     # L1 vault + SwapToken + L1 DEX (test or live mode)
│       └── deploy-dex-l2.sh     # L2 vault + SwapTokenL2 + SimpleDEX
│
├── script/                      # Container entrypoint scripts
│   ├── start-nethermind.sh      # Launches L2 execution client
│   └── start-driver.sh          # Launches taiko-client driver
│
├── static/                      # Static config files mounted into containers
│   ├── jwtsecret                # Shared JWT secret for Engine API auth
│   └── spamoor/                 # Spamoor scenario configs
│
├── ethereum-package/            # Kurtosis ethereum-package submodule (L1 devnet)
│
├── surge-taiko-mono/            # Protocol monorepo submodule
│   └── packages/
│       ├── protocol/            # Solidity contracts (RealTimeInbox, verifiers, bridge)
│       ├── taiko-client/        # Driver / proposer / prover Go client
│       └── cross-chain-dex-ui/  # DEX front-end (Vite/React)
│
├── configs/                     # Generated at deploy time (chainspec, web3signer keys, etc.)
└── deployment/                  # Generated deployment artifacts (JSON address files, lock files)
```