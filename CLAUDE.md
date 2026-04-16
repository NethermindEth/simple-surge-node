# Simple Surge Node — Claude Code Instructions

  ## Deploying a Surge Devnet

  Claude can one-shot deploy a full Surge devnet (L1 + L2 + mock prover) on a local machine or remote VM. Always use `--force` to skip all interactive prompts — without it, the script blocks on `read -p`
  prompts that Claude can't answer.

  ### Choosing `--deployment local` vs `--deployment remote`

  This is the most common mistake. Get it wrong and services (Blockscout, DEX UI) point at `localhost` instead of the VM's public IP — they'll work on the VM itself but break for anyone connecting from a
  browser.

  | Flag | What it does | When to use |
  |------|-------------|-------------|
  | `--deployment local` | Configs use `localhost` for all service URLs | Deploying **and** browsing on the same machine |
  | `--deployment remote` | Auto-detects the machine's public IP and writes it into Blockscout/DEX UI configs | Deploying on a VM, accessing services from a different machine |

  **Rule of thumb:** If you're SSH-ing into the machine to deploy, use `--deployment remote`.

  ### Prerequisites (fresh VM)

  Install these before running the deploy script — it won't install them for you:

  ```bash
  # Docker Engine + Compose plugin
  curl -fsSL https://get.docker.com | sh

  # Foundry (cast, forge, anvil)
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  foundryup

  # Kurtosis CLI (Ubuntu/Debian)
  echo "deb [trusted=yes] https://apt.fury.io/kurtosis-tech/ /" | tee /etc/apt/sources.list.d/kurtosis.list
  apt-get update && apt-get install -y kurtosis-cli
  kurtosis engine start

  # Standard tools (usually pre-installed)
  apt install -y jq curl bc

  Clone and prepare

  git clone https://github.com/NethermindEth/simple-surge-node.git
  cd simple-surge-node
  git submodule update --init --recursive
  cp .env.devnet .env

  One-shot deploy (mock prover)

  # Local machine
  ./deploy-surge-full.sh \
    --environment devnet \
    --deploy-devnet true \
    --deployment local \
    --stack-option 2 \
    --mock-prover \
    --mode silence \
    --force

  # Remote VM
  ./deploy-surge-full.sh \
    --environment devnet \
    --deploy-devnet true \
    --deployment remote \
    --stack-option 2 \
    --mock-prover \
    --mode silence \
    --force

  One-shot deploy (real prover)

  Requires a running Raiko instance. Verify it's up first:

  curl http://<prover-ip>:<prover-port>/guest_data

  Then deploy:

  RAIKO_HOST_ZKVM=http://<prover-ip>:<prover-port> ./deploy-surge-full.sh \
    --environment devnet \
    --deploy-devnet true \
    --deployment remote \
    --stack-option 2 \
    --mode silence \
    --force

  Post-deployment

  Always report service endpoints to the user. Replace <IP> with localhost (local) or the VM's public IP (remote):

  ┌──────────────────────────┬───────────────────┐
  │         Service          │        URL        │
  ├──────────────────────────┼───────────────────┤
  │ L1 RPC                   │ http://<IP>:32003 │
  ├──────────────────────────┼───────────────────┤
  │ L2 RPC                   │ http://<IP>:8547  │
  ├──────────────────────────┼───────────────────┤
  │ L2 WebSocket             │ ws://<IP>:8548    │
  ├──────────────────────────┼───────────────────┤
  │ L2 Catalyst              │ http://<IP>:4545  │
  ├──────────────────────────┼───────────────────┤
  │ L2 Explorer (Blockscout) │ http://<IP>:3001  │
  ├──────────────────────────┼───────────────────┤
  │ DEX UI                   │ http://<IP>:8080  │
  ├──────────────────────────┼───────────────────┤
  │ Raiko (mock prover)      │ http://<IP>:8082  │
  └──────────────────────────┴───────────────────┘

  Verify the deployment:

  # All containers running
  docker compose ps

  # L2 RPC responds
  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://localhost:8547

  Check Catalyst logs for Batches: N (N > 0) to confirm blocks are being proposed.

  Teardown and redeploy

  # Full teardown
  ./remove-surge-full.sh --force

  # Fresh deploy
  cp .env.devnet .env
  ./deploy-surge-full.sh --environment devnet --deploy-devnet true --deployment remote --stack-option 2 --mock-prover --mode silence --force

  Common pitfalls

  - Wrong --deployment flag: local on a remote VM means DEX UI and Blockscout make browser requests to localhost, which fails. Use remote for VMs.
  - Missing --force: Without it, the script blocks on interactive prompts (test token deploy, prover selection, redeployment confirmation) that can't be answered over a non-interactive SSH session.
  - Foundry not in PATH: After installing, cast lives at ~/.foundry/bin/cast. Either source ~/.bashrc or prepend PATH="$HOME/.foundry/bin:$PATH" before running the deploy script.
  - Kurtosis engine not started: Run kurtosis engine start after installing the CLI — the deploy script assumes it's already running.
  - Stale .env: Always re-copy .env.devnet to .env before a fresh deployment. A leftover .env from a previous run has stale contract addresses and block heights.