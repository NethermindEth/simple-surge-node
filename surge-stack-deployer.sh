#!/bin/bash

set -e

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a  # automatically export all variables
  source .env
  set +a  # disable automatic export
fi

prepare_blockscout_for_remote() {
  # Get the machine's IP address using ip command (works on Ubuntu)
  export MACHINE_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' | head -n1)

  # Fallback to hostname -I if ip route doesn't work
  if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(hostname -I | awk '{print $1}')
  fi

  # Final fallback to parsing ip addr output
  if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | awk '{print $2}' | cut -d'/' -f1)
  fi

  if [ -z "$MACHINE_IP" ]; then
    echo "Error: Could not determine machine IP address"
    exit 1
  fi

  echo "Setting Blockscout to use machine IP: $MACHINE_IP"

  # Replace localhost with machine IP for blockscout
  sed -i.bak 's/^BLOCKSCOUT_API_HOST=.*/BLOCKSCOUT_API_HOST='$MACHINE_IP'/g' .env
  sed -i.bak 's/^BLOCKSCOUT_L2_HOST=.*/BLOCKSCOUT_L2_HOST='$MACHINE_IP'/g' .env

  echo "Successfully updated blockscout launcher to use machine IP: $MACHINE_IP"
}

start_l2_stack() {
  echo "Starting L2 stack..."

  # Prompt user for L2_STACK_OPTION
  echo "Enter L2 stack option (1 for driver only, 2 for proposer only, 3 for proposer and spammer, 4 for prover relayer only, 5 for all except spammer, default: all): "
  read -r l2_stack_option

  echo "L2 stack option: $l2_stack_option"

  if [ "$l2_stack_option" = "1" ]; then
    docker compose --profile driver --profile blockscout up -d
  elif [ "$l2_stack_option" = "2" ]; then
    docker compose --profile proposer --profile blockscout up -d
  elif [ "$l2_stack_option" = "3" ]; then
    docker compose --profile proposer --profile spammer --profile blockscout up -d
  elif [ "$l2_stack_option" = "4" ]; then
    docker compose --profile prover --profile blockscout up -d
  elif [ "$l2_stack_option" = "5" ]; then
    docker compose --profile driver --profile proposer --profile prover --profile blockscout up -d
  else
    docker compose --profile driver --profile proposer --profile spammer --profile prover --profile blockscout up -d
  fi
}

deploy_l2() {
  # Check if deployment is already completed
  if [ -f "deployment/setup_l2.json" ]; then
    echo "L2 deployment already completed (setup_l2.json exists), deployment will be skipped"
    return 0
  else
    echo "Deploying L2 SCs..."

    if [ "$L1_TIMELOCK_CONTROLLER" != "0x0000000000000000000000000000000000000000" ]; then
      echo "Surge timelock controller is set. Starting deployment."
      L1_OWNER=$L1_TIMELOCK_CONTROLLER
      BROADCAST=true docker compose --profile l2-deployer up -d
    else
      echo "Surge timelock controller is not set. Use L1 owner for timelock controller."
      BROADCAST=true docker compose --profile l2-deployer up -d
    fi

    echo "L2 deployment completed successfully"
  fi
}

start_relayers() {
  # Prompt user for START_RELAYERS
  echo "Start relayers? (true/false) [default: true]: "
  read -r start_relayers

  START_RELAYERS=${start_relayers:-true}

  if [ "$START_RELAYERS" = "true" ]; then
    if [ "$SURGE_ENVIRONMENT" = "1" ]; then
      # Deploy L2 SCs first
      deploy_l2
    fi

    echo "Starting relayers..."

    echo "Starting init to prepare DB and queues..."
    docker compose --profile relayer-init up -d

    # Wait for services to initialize
    sleep 20

    # Execute migrations
    echo "Executing migrations..."
    docker compose --profile relayer-migrations up

    docker compose --profile relayer-l1 --profile relayer-l2 --profile relayer-api up -d
    echo "Relayers started successfully"

    # Prepare Bridge UI Configs only if relayers are needed
    prepare_bridge_ui_configs
  else
    return 0
  fi
}

prepare_bridge_ui_configs() {
  echo "Preparing Bridge UI configs..."

  # Get chain IDs from environment or use defaults
  L1_CHAIN_ID=${L1_CHAINID:-3151908}
  L2_CHAIN_ID=${L2_CHAINID:-763374}

  # Generate configuredBridges.json
  cat > configs/configuredBridges.json << EOF
{
  "configuredBridges": [
    {
      "source": "$L1_CHAIN_ID",
      "destination": "$L2_CHAIN_ID",
      "addresses": {
        "bridgeAddress": "$L1_BRIDGE",
        "erc20VaultAddress": "$L1_ERC20_VAULT",
        "erc721VaultAddress": "$L1_ERC721_VAULT",
        "erc1155VaultAddress": "$L1_ERC1155_VAULT",
        "crossChainSyncAddress": "",
        "signalServiceAddress": "$L1_SIGNAL_SERVICE",
        "quotaManagerAddress": ""
      }
    },
    {
      "source": "$L2_CHAIN_ID",
      "destination": "$L1_CHAIN_ID",
      "addresses": {
        "bridgeAddress": "$L2_BRIDGE",
        "erc20VaultAddress": "$L2_ERC20_VAULT",
        "erc721VaultAddress": "$L2_ERC721_VAULT",
        "erc1155VaultAddress": "$L2_ERC1155_VAULT",
        "crossChainSyncAddress": "",
        "signalServiceAddress": "$L2_SIGNAL_SERVICE",
        "quotaManagerAddress": ""
      }
    }
  ]
}
EOF

  # Generate configuredChains.json
  cat > configs/configuredChains.json << EOF
{
  "configuredChains": [
    {
      "$L1_CHAIN_ID": {
        "name": "L1 Devnet",
        "type": "L1",
        "icon": "https://cdn.worldvectorlogo.com/logos/ethereum-eth.svg",
        "rpcUrls": {
          "default": {
            "http": ["$L1_RPC"]
          }
        },
        "nativeCurrency": {
          "name": "ETH",
          "symbol": "ETH",
          "decimals": 18
        },
        "blockExplorers": {
          "default": {
            "name": "L1 Devnet Explorer",
            "url": "$L1_EXPLORER"
          }
        }
      }
    },
    {
      "$L2_CHAIN_ID": {
        "name": "Surge Devnet",
        "type": "L2",
        "icon": "https://cdn.worldvectorlogo.com/logos/ethereum-eth.svg",
        "rpcUrls": {
          "default": {
            "http": ["$L2_RPC"]
          }
        },
        "nativeCurrency": {
          "name": "ETH",
          "symbol": "ETH",
          "decimals": 18
        },
        "blockExplorers": {
          "default": {
            "name": "Surge Explorer",
            "url": "$L2_EXPLORER"
          }
        }
      }
    }
  ]
}
EOF

  # Generate configuredRelayer.json
  cat > configs/configuredRelayer.json << EOF
{
  "configuredRelayer": [
    {
      "chainIds": [$L1_CHAIN_ID, $L2_CHAIN_ID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAIN_ID, $L1_CHAIN_ID],
      "url": "$L2_RELAYER"
    }
  ]
}
EOF

  # Generate configuredEventIndexer.json
  cat > configs/configuredEventIndexer.json << EOF
{
  "configuredEventIndexer": [
    {
      "chainIds": [$L1_CHAIN_ID, $L2_CHAIN_ID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAIN_ID, $L1_CHAIN_ID],
      "url": "$L2_RELAYER"
    }
  ]
}
EOF

  # Generate configuredCustomTokens.json (empty array for now)
  cat > configs/configuredCustomTokens.json << EOF
[]
EOF

  echo "Bridge UI configs generated successfully!"
  echo "Generated files:"
  echo "  - configs/configuredBridges.json"
  echo "  - configs/configuredChains.json"
  echo "  - configs/configuredRelayer.json"
  echo "  - configs/configuredEventIndexer.json"
  echo "  - configs/configuredCustomTokens.json"
}

deploy_surge_stack() {
  # Select which Surge environment to use
  echo "Select which Surge environment to use (1 for Devnet, 2 for Staging, 3 for Testnet (default: Devnet)): "
  read -r surge_environment

  export SURGE_ENVIRONMENT=${surge_environment:-1}

  if [ "$SURGE_ENVIRONMENT" = "2" ]; then
    echo "Using Staging Environment..."
    return 0
  elif [ "$SURGE_ENVIRONMENT" = "3" ]; then
    echo "Using Testnet Environment..."
    return 0
  fi

  # Select remote or local
  echo "Select remote or local (0 for local, 1 for remote) [default: local]: "
  read -r remote_or_local

  REMOTE_OR_LOCAL=${remote_or_local:-0}

  if [ "$REMOTE_OR_LOCAL" = "1" ]; then
    echo "Using remote environment"

    # Select which devnet machine to use
    echo "Select which devnet machine to use (1 for Devnet 1 (prover), 2 for Devnet 2 (taiko-client), return to skip for others (default: others)): "
    read -r devnet_machine

    DEVNET_MACHINE=${devnet_machine:-3}

    if [ "$devnet_machine" = "1" ]; then
      echo "Using Devnet 1 (prover)"
      export L1_RPC="https://devnet-one.surge.wtf/l1-rpc"
      export L1_BEACON_RPC="https://devnet-one.surge.wtf/l1-beacon"
      export L1_EXPLORER="https://devnet-one.surge.wtf/l1-block-explorer"
      export L2_RPC="https://devnet-one.surge.wtf/l2-rpc"
      export L2_EXPLORER="https://devnet-one.surge.wtf/l2-block-explorer"
      export L1_RELAYER="https://devnet-one.surge.wtf/l1-relayer"
      export L2_RELAYER="https://devnet-one.surge.wtf/l2-relayer"
    elif [ "$devnet_machine" = "2" ]; then
      echo "Using Devnet 2 (taiko-client)"
      export L1_RPC="https://devnet-two.surge.wtf/l1-rpc"
      export L1_BEACON_RPC="https://devnet-two.surge.wtf/l1-beacon"
      export L1_EXPLORER="https://devnet-two.surge.wtf/l1-block-explorer"
      export L2_RPC="https://devnet-two.surge.wtf/l2-rpc"
      export L2_EXPLORER="https://devnet-two.surge.wtf/l2-block-explorer"
      export L1_RELAYER="https://devnet-two.surge.wtf/l1-relayer"
      export L2_RELAYER="https://devnet-two.surge.wtf/l2-relayer"
    else
      echo "Using others"
      export L1_RPC="http://$MACHINE_IP:32003"
      export L1_BEACON_RPC="http://$MACHINE_IP:33001"
      export L1_EXPLORER="http://$MACHINE_IP:36005"
      export L2_RPC="http://$MACHINE_IP:${L2_HTTP_PORT:-8547}"
      export L2_EXPLORER="http://$MACHINE_IP:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
      export L1_RELAYER="http://$MACHINE_IP:4102"
      export L2_RELAYER="http://$MACHINE_IP:4103"
    fi
  else
    echo "Using local environment"
    export L1_RPC="http://localhost:32003"
    export L1_BEACON_RPC="http://localhost:33001"
    export L1_EXPLORER="http://localhost:36005"
    export L2_RPC="http://localhost:${L2_HTTP_PORT:-8547}"
    export L2_EXPLORER="http://localhost:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
    export L1_RELAYER="http://localhost:4102"
    export L2_RELAYER="http://localhost:4103"
  fi

  # Start L2 Stack
  start_l2_stack

  # Start Relayers
  start_relayers
}

deploy_surge_stack
