# simple-surge-node

`simple-surge-node` is a lightweight tool for setting up and managing a node on the Surge network. **This repository is intended for development purposes only and is not recommended for production use.**

This repository is ideal for easy set up operating Layer 2 (L2) solutions, simplifying the process of running Surge node.

## Prerequisites

### Docker and Docker Compose

Docker Engine and Docker Compose v2.1+ are required. Install Docker Desktop or Docker Engine following the [official docs](https://docs.docker.com/engine/install/).

Verify:

```bash
docker --version
docker compose version   # must be >= 2.1
```

### Foundry (cast)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Node.js (using nvm - recommended)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc  # or ~/.zshrc if using zsh
nvm install --lts
```

Or using apt on Ubuntu/Debian:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

After installation, restart your terminal or run `source ~/.bashrc` or `source ~/.zshrc` to ensure the tools are available in your PATH.

## Quick Start

### Deploy Complete Devnet

```bash
# Copy devnet environment (first time only)
cp .env.devnet .env

# Deploy everything (non-interactive, defaults to devnet + new L1)
./deploy-surge-full.sh --force

# Or specify options explicitly
./deploy-surge-full.sh --environment devnet --deploy-devnet true --force
```

Without `--force` the script prompts interactively for environment, deployment mode, and L1 options.

**Options:**
- `--environment ENV` - Surge environment: `devnet`, `staging`, `testnet` (defaults to `devnet` with `--force`)
- `--deploy-devnet true` - Deploy a new L1 devnet (default with `--force`)
- `--deploy-devnet false` - Skip L1 deployment, use existing chain
- `--deployment local|remote` - Local or remote deployment (defaults to `local` with `--force`)

### Remove Stack

```bash
# Remove L2 stack, relayers, configs (keeps L1 devnet running)
./remove-surge-full.sh --force

# Remove everything including L1 devnet
./remove-surge-full.sh --remove-l1-devnet true --force
```

For detailed deployment and removal instructions, see [DEPLOYMENT.md](./DEPLOYMENT.md).

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
