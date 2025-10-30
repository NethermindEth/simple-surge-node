#!/bin/bash

set -e

git submodule update --init --recursive

NON_INTERACTIVE=false
if [ "$1" = "--devnet-non-interactive" ]; then
  NON_INTERACTIVE=true
fi

# Export DOCKER_USER for local development to avoid permission issues with database containers
# In CI (NON_INTERACTIVE=true), this remains unset so containers run as root for proper initialization
if [ "$NON_INTERACTIVE" = "false" ] && [ -z "$DOCKER_USER" ]; then
  export DOCKER_USER="$(id -u):$(id -g)"
fi

check_env_file() {
  if [ -f .env ]; then
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Loading environment variables from .env file...            "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    echo ""
    set -a  # automatically export all variables
    source .env
    set +a  # disable automatic export
  else
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ❌ Error: .env file not found                                 "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    exit 1
  fi
}

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
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ❌ Error: Could not determine machine IP address              "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    exit 1
  fi

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Setting Blockscout to use machine IP: $MACHINE_IP            ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  # Replace localhost with machine IP for blockscout
  sed -i.bak 's/^BLOCKSCOUT_API_HOST=.*/BLOCKSCOUT_API_HOST='$MACHINE_IP'/g' .env
  sed -i.bak 's/^BLOCKSCOUT_L2_HOST=.*/BLOCKSCOUT_L2_HOST='$MACHINE_IP'/g' .env
}

if [ "$NON_INTERACTIVE" = "true" ]; then
  SURGE_ENVIRONMENT=1
  REMOTE_OR_LOCAL=0
else
  # Select which Surge environment to use
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ⚠️ Select which Surge environment to use:                     "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ 1 for Devnet                                                 ║"
  echo "║ 2 for Staging                                                ║"
  echo "║ 3 for Testnet                                                ║"
  echo "║ [default: Devnet]                                            ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  read -r surge_environment

  SURGE_ENVIRONMENT=${surge_environment:-1}

  # Select remote or local
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ⚠️ Select remote or local:                                    "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║  0 for local                                                 ║"
  echo "║  1 for remote                                                ║"
  echo "║ [default: local]                                             ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  read -r remote_or_local

  REMOTE_OR_LOCAL=${remote_or_local:-0}
fi

if [ "$REMOTE_OR_LOCAL" = "1" ]; then
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Setting up remote environment...                             ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  prepare_blockscout_for_remote
fi

if [ "$SURGE_ENVIRONMENT" = "1" ]; then
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🚀 Using Devnet Environment                                   "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  check_env_file

  if [ "$REMOTE_OR_LOCAL" = "1" ]; then
    # Select which devnet machine to use
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Select which devnet machine to use:                        "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ 1 for Devnet 1 (prover)                                     ║"
    echo "║ 2 for Devnet 2 (taiko-client)                               ║"
    echo "║ [default: others]                                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r devnet_machine

    DEVNET_MACHINE=${devnet_machine:-3}

    if [ "$devnet_machine" = "1" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  🚀 Using Devnet 1 (prover)                                    "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export L1_RPC="https://devnet-one.surge.wtf/l1-rpc"
      export L1_BEACON_RPC="https://devnet-one.surge.wtf/l1-beacon"
      export L1_EXPLORER="https://devnet-one.surge.wtf/l1-block-explorer"
      export L2_RPC="https://devnet-one.surge.wtf/l2-rpc"
      export L2_EXPLORER="https://devnet-one.surge.wtf/l2-block-explorer"
      export L1_RELAYER="https://devnet-one.surge.wtf/l1-relayer"
      export L2_RELAYER="https://devnet-one.surge.wtf/l2-relayer"
    elif [ "$devnet_machine" = "2" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  🚀 Using Devnet 2 (taiko-client)                             "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export L1_RPC="https://devnet-two.surge.wtf/l1-rpc"
      export L1_BEACON_RPC="https://devnet-two.surge.wtf/l1-beacon"
      export L1_EXPLORER="https://devnet-two.surge.wtf/l1-block-explorer"
      export L2_RPC="https://devnet-two.surge.wtf/l2-rpc"
      export L2_EXPLORER="https://devnet-two.surge.wtf/l2-block-explorer"
      export L1_RELAYER="https://devnet-two.surge.wtf/l1-relayer"
      export L2_RELAYER="https://devnet-two.surge.wtf/l2-relayer"
    else
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  🚀 Using others                                              "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export L1_RPC="http://$MACHINE_IP:32003"
      export L1_BEACON_RPC="http://$MACHINE_IP:33001"
      export L1_EXPLORER="http://$MACHINE_IP:36005"
      export L2_RPC="http://$MACHINE_IP:${L2_HTTP_PORT:-8547}"
      export L2_EXPLORER="http://$MACHINE_IP:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
      export L1_RELAYER="http://$MACHINE_IP:4102"
      export L2_RELAYER="http://$MACHINE_IP:4103"
    fi
  else
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  🚀 Using local environment                                    "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    export L1_RPC="http://localhost:32003"
    export L1_BEACON_RPC="http://localhost:33001"
    export L1_EXPLORER="http://localhost:36005"
    export L2_RPC="http://localhost:${L2_HTTP_PORT:-8547}"
    export L2_EXPLORER="http://localhost:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
    export L1_RELAYER="http://localhost:4102"
    export L2_RELAYER="http://localhost:4103"
  fi

elif [ "$SURGE_ENVIRONMENT" = "2" ]; then
  if [ ! docker network ls | grep -q "surge-network" ]; then
    docker network create surge-network
  fi
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🚀 Using Staging Environment                                  "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  check_env_file
elif [ "$SURGE_ENVIRONMENT" = "3" ]; then
  if [ ! docker network ls | grep -q "surge-network" ]; then
    docker network create surge-network
  fi
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🚀 Using Testnet Environment                                  "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  check_env_file
fi

start_l2_stack() {
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Starting L2 stack...                                         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  if [ "$NON_INTERACTIVE" = "true" ]; then
    l2_stack_option=""
  else
    # Prompt user for L2_STACK_OPTION
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Enter L2 stack option:                                       ║"
    echo "║ 1 for driver only                                            ║"
    echo "║ 2 for driver + proposer                                      ║"
    echo "║ 3 for driver + proposer + spammer                            ║"
    echo "║ 4 for driver + proposer + prover + spammer                   ║"
    echo "║ 5 for all except spammer                                     ║"
    echo "║ [default: all]                                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r l2_stack_option
  fi

  if [ "$l2_stack_option" = "1" ]; then
    docker compose --profile driver --profile blockscout up -d --remove-orphans
  elif [ "$l2_stack_option" = "2" ]; then
    docker compose --profile proposer --profile blockscout up -d --remove-orphans
  elif [ "$l2_stack_option" = "3" ]; then
    docker compose --profile proposer --profile spammer --profile blockscout up -d --remove-orphans
  elif [ "$l2_stack_option" = "4" ]; then
    docker compose --profile prover --profile blockscout up -d --remove-orphans
  elif [ "$l2_stack_option" = "5" ]; then
    docker compose --profile driver --profile proposer --profile prover --profile blockscout up -d --remove-orphans
  else
    docker compose --profile driver --profile proposer --profile spammer --profile prover --profile blockscout up -d --remove-orphans
  fi
}

deploy_l2() {
  # Check if deployment is already completed
  if [ -f "deployment/setup_l2.json" ]; then
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Surge L2 deployment already completed                     "
    echo "  (setup_l2.json exists)                                        "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ Deployment will be skipped...                                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    return 0
  else
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Deploying L2 SCs...                                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    BROADCAST=true docker compose --profile l2-deployer up -d
  fi
}

start_relayers() {
  if [ "$NON_INTERACTIVE" = "true" ]; then
    START_RELAYERS=true
  else
    # Prompt user for START_RELAYERS
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Start relayers? (true/false) [default: true]                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r start_relayers

    START_RELAYERS=${start_relayers:-true}
  fi

  if [ "$START_RELAYERS" = "true" ]; then
    if [ "$SURGE_ENVIRONMENT" = "1" ]; then
      # Deploy L2 SCs first
      deploy_l2
    fi

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Starting relayers...                                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Starting init to prepare DB and queues...                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    docker compose -f docker-compose-relayer.yml --profile relayer-init up -d

    # Wait for services to initialize
    sleep 20

    # Execute migrations
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Executing DB migrations...                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    docker compose -f docker-compose-relayer.yml --profile relayer-migrations up
    docker compose -f docker-compose-relayer.yml --profile relayer-l1 --profile relayer-l2 --profile relayer-api up -d

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Relayers started successfully                              "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Prepare Bridge UI Configs only if relayers are needed
    prepare_bridge_ui_configs

    docker compose -f docker-compose-relayer.yml --profile bridge-ui up -d --build
  else
    return 0
  fi
}

prepare_bridge_ui_configs() {
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Preparing Bridge UI configs...                               ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  
  # Generate configuredBridges.json
  cat > configs/configuredBridges.json << EOF
{
  "configuredBridges": [
    {
      "source": "$L1_CHAINID",
      "destination": "$L2_CHAINID",
      "addresses": {
        "bridgeAddress": "$BRIDGE",
        "erc20VaultAddress": "$ERC20_VAULT",
        "erc721VaultAddress": "$ERC721_VAULT",
        "erc1155VaultAddress": "$ERC1155_VAULT",
        "crossChainSyncAddress": "",
        "signalServiceAddress": "$SIGNAL_SERVICE",
        "quotaManagerAddress": ""
      }
    },
    {
      "source": "$L2_CHAINID",
      "destination": "$L1_CHAINID",
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
      "$L1_CHAINID": {
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
      "$L2_CHAINID": {
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
      "chainIds": [$L1_CHAINID, $L2_CHAINID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAINID, $L1_CHAINID],
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
      "chainIds": [$L1_CHAINID, $L2_CHAINID],
      "url": "$L1_RELAYER"
    },
    {
      "chainIds": [$L2_CHAINID, $L1_CHAINID],
      "url": "$L2_RELAYER"
    }
  ]
}
EOF

  # Generate configuredCustomTokens.json (empty array for now)
  cat > configs/configuredCustomTokens.json << EOF
[]
EOF

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ✅ Bridge UI configs generated successfully                   "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo " 💡 Generated files:                                            "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║  - configs/configuredBridges.json                            ║"
  echo "║  - configs/configuredChains.json                             ║"
  echo "║  - configs/configuredRelayer.json                            ║"
  echo "║  - configs/configuredEventIndexer.json                       ║"
  echo "║  - configs/configuredCustomTokens.json                       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
}

deploy_surge_stack() {
  # Start L2 Stack
  start_l2_stack

  # Start Relayers
  start_relayers
}

deploy_surge_stack
