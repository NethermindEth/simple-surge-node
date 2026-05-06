# simple-surge-node

Repo-specific tooling for spinning up a Surge devnet locally or on a VM. Wraps Kurtosis (L1), the Taiko monorepo (L2 contracts + clients), Catalyst, and Raiko into a single one-shot deploy.

> **Looking for the full Surge deployment guide?** Start at [docs.surge.wtf/guides/running-surge](https://docs.surge.wtf/guides/running-surge). That covers prerequisites, prover setup (mock and real ZisK), two-VM deploys, deploying against an existing L1, troubleshooting, contract error codes, and architecture.
>
> This README only documents what's specific to *this* repo: the deploy/remove scripts and how to operate them.

> **Dev/testing only.** Not intended for production use.

## Quickstart (mock prover)

No GPU required — fastest path for local development.

```bash
git clone https://github.com/NethermindEth/simple-surge-node.git
cd simple-surge-node
git submodule update --init --recursive
cp .env.devnet .env

./deploy-surge-full.sh \
  --environment devnet --deploy-devnet true \
  --deployment local --stack-option 2 \
  --mock-prover --mode silence --force
```

Use `--deployment remote` if you're SSH'd into a VM and accessing services from a different machine. For the real ZisK prover, two-VM splits, deploying against Sepolia/Gnosis/mainnet, hardware requirements, and any other deep topic — see [docs.surge.wtf](https://docs.surge.wtf/guides/running-surge).

## Scripts

### `deploy-surge-full.sh`

| Flag | Values | Default |
|------|--------|---------|
| `--environment` | `devnet` | interactive — `.env` preset name (not the target chain) |
| `--deploy-devnet` | `true` \| `false` | interactive — `true` spins up fresh Kurtosis L1; `false` uses the existing L1 in `.env` |
| `--deployment` | `local` \| `remote` | interactive — `remote` writes the VM's public IP into Blockscout/DEX UI configs |
| `--stack-option` | `0`–`3` | interactive |
| `--mock-prover` | — | use mock prover (no GPU) |
| `--mode` | `silence` \| `debug` | interactive |
| `--running-provers` | `true` \| `false` | interactive (devnet only) |
| `--update-submodules` | — | fast-forward `surge-taiko-mono` submodule to tip of tracked branch (not reproducible) |
| `-f`, `--force` | — | skip all prompts; defaults to **real prover** unless `--mock-prover` is set |
| `-h`, `--help` | — | show help |

**L2 stack options:**

| Option | Components |
|--------|------------|
| 0 | None — verify external L2 RPC only (dev-only) |
| 1 | Driver only |
| 2 | Driver + Catalyst (default) |
| 3 | Driver + Catalyst + Spammer |

Use option `0` when running your own L2 node externally (e.g. a custom Nethermind or Reth build). The script verifies `L2_ENDPOINT_HTTP` is reachable and skips the Docker Compose startup.

### `remove-surge-full.sh`

```bash
# Interactive — choose what to remove
./remove-surge-full.sh

# Remove everything except .env
./remove-surge-full.sh --force

# Remove everything including .env
./remove-surge-full.sh --force --remove-env true
```

### Restart L2 stack

Restart Nethermind, Driver, Catalyst, and friends **without redeploying anything** — L1 devnet, L1 contracts, and chain data are preserved.

```bash
./remove-surge-full.sh \
  --remove-l1-devnet false --remove-l2-stack true \
  --remove-data false --remove-configs false --force

./deploy-surge-full.sh \
  --environment devnet --deploy-devnet false \
  --deployment local --stack-option 2 --force
```

### Redeploy L2 stack

Keep the L1 Kurtosis enclave running, wipe and redeploy everything else (L1 contracts, L2 genesis, full L2 stack):

```bash
./remove-surge-full.sh \
  --remove-l1-devnet false --remove-l2-stack true \
  --remove-data true --remove-configs true --force

./deploy-surge-full.sh \
  --environment devnet --deploy-devnet false \
  --deployment local --stack-option 2 --force
```

### `collect-devnet-logs.sh`

Diagnostic snapshot of all running devnet containers — useful for bug reports.

```bash
./collect-devnet-logs.sh                    # full snapshot (L1 enclave dump + L2 logs)
./collect-devnet-logs.sh --since 30m        # last 30 min of L2 logs only
./collect-devnet-logs.sh --l1-only          # L1 enclave dump only
./collect-devnet-logs.sh --l2-only          # L2 docker logs only
./collect-devnet-logs.sh -o /tmp/surge-diag # custom output dir
```

Output goes to `./logs/snapshot-YYYYMMDD-HHMMSS/` by default. L1 uses `kurtosis enclave dump`; L2 runs `docker logs --timestamps` per container from `docker-compose.yml`.

## Directory layout

```
simple-surge-node/
├── deploy-surge-full.sh         # Main deploy script
├── remove-surge-full.sh         # Teardown script
├── collect-devnet-logs.sh       # Diagnostic snapshot
├── helpers.sh                   # Shared functions (URL utils, prompts, config helpers)
├── docker-compose.yml           # L2 stack (driver, catalyst, web3signer, blockscout, dex)
├── docker-compose-protocol.yml  # L1 deployer containers
├── .env.devnet                  # Environment template for local devnet
│
├── deployer/                    # Shell scripts run inside protocol containers
│   ├── deploy-surge-l1.sh
│   ├── deploy-multicall.sh
│   ├── deploy-userops-submitter.sh
│   ├── generate-genesis.sh
│   ├── setup-zisk.sh            # Registers ZisK program vkey on ZiskVerifier
│   ├── deploy-cross-chain-relay.sh
│   └── dex/
│       ├── deploy-dex-l1.sh
│       └── deploy-dex-l2.sh
│
├── script/                      # Container entrypoint scripts
│   ├── start-nethermind.sh
│   └── start-driver.sh
│
├── static/                      # Static config files mounted into containers
├── ethereum-package/            # Kurtosis ethereum-package submodule (L1 devnet)
│
├── surge-taiko-mono/            # Protocol monorepo submodule
│   └── packages/
│       ├── protocol/            # Solidity contracts (RealTimeInbox, verifiers, bridge)
│       ├── taiko-client/        # Driver / proposer / prover Go client
│       └── cross-chain-dex-ui/  # DEX front-end (Vite/React)
│
├── configs/                     # Generated at deploy time (chainspec, web3signer keys)
└── deployment/                  # Generated address files + lock files
```

## See also

- [docs.surge.wtf/guides/running-surge](https://docs.surge.wtf/guides/running-surge) — full deployment guide (prerequisites, prover setup, deploying against an existing L1)
- [docs.surge.wtf/guides/running-surge/provers](https://docs.surge.wtf/guides/running-surge/provers) — ZisK prover setup (two-VM and single-VM)
- [docs.surge.wtf/troubleshooting/common-devnet-issues](https://docs.surge.wtf/troubleshooting/common-devnet-issues) — devnet troubleshooting
- [docs.surge.wtf/troubleshooting/error-codes](https://docs.surge.wtf/troubleshooting/error-codes) — contract custom-error selectors
- [docs.surge.wtf/about/architecture](https://docs.surge.wtf/about/architecture) — what gets deployed and why
