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
