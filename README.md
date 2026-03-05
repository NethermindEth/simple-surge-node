# simple-surge-node

`simple-surge-node` is a lightweight tool for setting up and managing a node on the Surge network. **This repository is intended for development purposes only and is not recommended for production use.**

This repository is ideal for easy set up operating Layer 2 (L2) solutions, simplifying the process of running Surge node.

## Quick Start

### Deploy Complete Devnet

```bash
# Deploy everything with defaults
./deploy-surge-full.sh --environment devnet --deploy-devnet true --force
```

### Remove Everything

```bash
# Remove all components
./remove-surge-full.sh --force
```

For detailed deployment and removal instructions, see [DEPLOYMENT.md](./DEPLOYMENT.md).

## `deploy-surge-full.sh` Help

```bash
./deploy-surge-full.sh --help
```

### Usage

```text
./deploy-surge-full.sh [OPTIONS]
```

### Description

Deploy complete Surge stack with L1 (optional devnet) and L2 components.

### Options

- `--environment ENV` - Surge environment (`devnet|staging|testnet`) **[REQUIRED]**
- `--deploy-devnet BOOL` - Deploy new devnet or use existing chain (devnet only, `true|false`)
- `--deployment TYPE` - Deployment type (`local|remote`)
- `--deployment-key KEY` - Private key for contract deployment (will be verified)
- `--stack-option NUM` - L2 stack option (`1-6`, see details below)
- `--running-provers BOOL` - Setup provers (devnet only, `true|false`)
- `--deposit-bond BOOL` - Deposit bond (devnet only, `true|false`)
- `--bond-amount NUM` - Bond amount in ETH (default: `1000`)
- `--start-relayers BOOL` - Start relayers (`true|false`)
- `--mode MODE` - Execution mode (`silence|debug`)
- `-f, --force` - Skip confirmation prompts
- `-h, --help` - Show this help message

### Stack Options

- `1` - Driver only
- `2` - Driver + Proposer
- `3` - Driver + Proposer + Spammer
- `4` - Driver + Proposer + Prover + Spammer
- `5` - All except spammer
- `6` - All components (default)

### Execution Modes

- `silence` - Silent mode with progress indicators (default)
- `debug` - Debug mode with full output

### Examples

```bash
./deploy-surge-full.sh --environment devnet --deploy-devnet true --mode debug
./deploy-surge-full.sh --environment staging --stack-option 3 --start-relayers true
```

### Functional Steps (Execution Flow)

When you run `./deploy-surge-full.sh`, the script performs these steps in order:

1. Parse CLI args and show help if requested.
2. Validate prerequisites (`docker`, `git`, `jq`, `curl`, `bc`, `cast`) and create required folders.
3. Initialize git submodules.
4. Select/load environment (`devnet`, `staging`, `testnet`) and load `.env` settings.
5. Configure endpoint URLs for local/remote deployment context.
6. For `devnet`, choose L1 path:
   - Deploy new devnet, or
   - Use existing chain (WIP path).
7. For `devnet`, run protocol deployment flow:
   - simulate L1 deploy,
   - extract deployment outputs,
   - generate L2 genesis,
   - deploy L1 contracts,
   - deploy Pacaya contracts,
   - extract outputs again,
   - optionally deploy provers.
8. Start L2 stack based on selected `--stack-option`.
9. Switch fork configuration.
10. Optionally start relayers (and deploy L2 contracts first when needed).
11. Optionally start tx spammer (for stack options including spammer).
12. Verify RPC endpoints and print deployment summary.


#### Steps:
```bash
  preflight    - Validate deps, init submodules, load env, configure endpoints
  l1-infra     - Deploy/check L1 devnet infrastructure (devnet only)
  l1-contracts - Run L1 contracts flow up to broadcast (devnet only)
  pacaya       - Deploy Pacaya contracts + extract + optional provers (devnet only)
  l2-stack     - Start L2 stack
  switch-fork  - Switch fork profile
  l2-contracts - Deploy L2 contracts (devnet only)
  relayers     - Start relayers and bridge UI
  verify       - Verify RPC endpoints
  summary      - Print deployment summary
```

### Step-by-Step Usage

#### 1) Full devnet (recommended defaults)

```bash
./deploy-surge-full.sh --environment devnet --deploy-devnet true --force
```

#### 2) Use existing L1 chain for devnet flow

```bash
./deploy-surge-full.sh --environment devnet --deploy-devnet false --mode debug
```

#### 3) Staging with partial stack and relayers

```bash
./deploy-surge-full.sh \
  --environment staging \
  --deployment remote \
  --stack-option 3 \
  --start-relayers true \
  --mode debug
```

#### 4) Testnet with non-interactive prompts

```bash
./deploy-surge-full.sh --environment testnet --force
```

## Documentation

- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Complete guide for deploying and removing the Surge stack
- [Guides](https://docs.surge.wtf/docs/guides) - Official Surge documentation

## Scripts Overview

### Unified Scripts (Recommended)

- **`deploy-surge-full.sh`** - Unified deployment script for L1 devnet, L1 contracts, L2 stack, and relayers
- **`remove-surge-full.sh`** - Unified removal script for all Surge stack components

### Legacy Scripts

The following scripts are still available but superseded by the unified scripts:

- `deploy-surge-devnet-l1.sh` - L1 devnet deployment
- `deploy-surge-protocol.sh` - Protocol contract deployment
- `start-surge-stack.sh` - L2 stack startup
- `remove-surge-devnet-l1.sh` - L1 devnet removal
- `remove-surge-stack.sh` - L2 stack removal
