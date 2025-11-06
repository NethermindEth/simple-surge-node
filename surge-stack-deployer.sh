#!/bin/bash

set -e

git submodule update --init --recursive

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
    if [ $1 ]; then
      cp .env.$1 .env
    else
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  ❌ Error: .env file not found                                 "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      exit 1
    fi
  fi
}

prepare_blockscout_for_remote() {
  # Get the machine's public IP address using ifconfig.me
  export MACHINE_IP=$(curl -4 -s ifconfig.me 2>/dev/null)

  # Fallback to ip route method if curl fails
  if [ -z "$MACHINE_IP" ]; then
    echo "  ⚠️  Warning: Could not get public IP from ifconfig.me, using local IP..."
    MACHINE_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' | head -n1)
  fi

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

# Select deployment type
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "  ⚠️ Select deployment type:                                    "
echo "║══════════════════════════════════════════════════════════════║"
echo "║  0 - Local devnet at localhost                              ║"
echo "║  1 - Local devnet at VM with public IP                     ║"
echo "║  2 - Remote existing devnet                                  ║"
echo "║  [default: Local]                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
read -r remote_or_local

REMOTE_OR_LOCAL=${remote_or_local:-0}

if [ "$REMOTE_OR_LOCAL" = "1" ]; then
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Setting up VM with public IP for bridge-ui...                ║"
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

  if [ "$REMOTE_OR_LOCAL" = "0" ]; then
    # Option 0: Local deployment - surge stack on localhost
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  🚀 Local deployment (localhost)                              "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    export L1_RPC="http://localhost:32003"
    export L1_BEACON_RPC="http://localhost:33001"
    export L1_EXPLORER="http://localhost:36005"
    export L2_RPC="http://localhost:${L2_HTTP_PORT:-8547}"
    export L2_EXPLORER="http://localhost:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
    export L1_RELAYER="http://localhost:4102"
    export L2_RELAYER="http://localhost:4103"
  elif [ "$REMOTE_OR_LOCAL" = "1" ]; then
    # Option 1: VM with public IP - for bridge-ui remote access
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  🚀 Local devnet with public IP                               "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    export L1_RPC="http://localhost:32003"
    export L1_BEACON_RPC="http://localhost:33001"
    export L1_EXPLORER="http://localhost:36005"
    export L2_RPC="http://localhost:${L2_HTTP_PORT:-8547}"
    export L2_EXPLORER="http://localhost:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
    export L1_RELAYER="http://localhost:4102"
    export L2_RELAYER="http://localhost:4103"
  elif [ "$REMOTE_OR_LOCAL" = "2" ]; then
    # Option 2: Remote deployment - connect to existing devnet infrastructure
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Select which devnet to use:                               "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ 1 - Devnet 1 (devnet-one.surge.wtf)                         ║"
    echo "║ 2 - Devnet 2 (devnet-two.surge.wtf)                         ║"
    echo "║ [default: Other VM with public IP]                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r devnet_machine

    DEVNET_MACHINE=${devnet_machine:-3}

    if [ "$devnet_machine" = "1" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  🚀 Using Devnet 1 (devnet-one.surge.wtf)                     "
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
      echo "  🚀 Using Devnet 2 (devnet-two.surge.wtf)                     "
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
      # Get public IP for "others" option
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Detecting public IP for remote VM...                         ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo

      export MACHINE_IP=$(curl -4 -s ifconfig.me 2>/dev/null)

      if [ -z "$MACHINE_IP" ]; then
        echo "  ⚠️  Warning: Could not get public IP from ifconfig.me, using local IP..."
        MACHINE_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' | head -n1)
      fi

      if [ -z "$MACHINE_IP" ]; then
        MACHINE_IP=$(hostname -I | awk '{print $1}')
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
      echo "║ Using VM with IP: $MACHINE_IP                                ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo

      export L1_RPC="http://$MACHINE_IP:32003"
      export L1_BEACON_RPC="http://$MACHINE_IP:33001"
      export L1_EXPLORER="http://$MACHINE_IP:36005"
      export L2_RPC="http://$MACHINE_IP:${L2_HTTP_PORT:-8547}"
      export L2_EXPLORER="http://$MACHINE_IP:${BLOCKSCOUT_FRONTEND_PORT:-3000}"
      export L1_RELAYER="http://$MACHINE_IP:4102"
      export L2_RELAYER="http://$MACHINE_IP:4103"

      # Update .env file with machine IP for blockscout
      sed -i.bak 's/^BLOCKSCOUT_API_HOST=.*/BLOCKSCOUT_API_HOST='$MACHINE_IP'/g' .env
      sed -i.bak 's/^BLOCKSCOUT_L2_HOST=.*/BLOCKSCOUT_L2_HOST='$MACHINE_IP'/g' .env
    fi
  fi

elif [ "$SURGE_ENVIRONMENT" = "2" ]; then
  if ! docker network ls | grep -q "surge-network"; then
    docker network create surge-network
  fi
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🚀 Using Staging Environment                                  "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  check_env_file staging
elif [ "$SURGE_ENVIRONMENT" = "3" ]; then
  if ! docker network ls | grep -q "surge-network"; then
    docker network create surge-network
  fi
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🚀 Using Testnet Environment                                  "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  check_env_file hoodi
fi

start_l2_stack() {
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Starting L2 stack...                                         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

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
  # Prompt user for START_RELAYERS
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Start relayers? (true/false) [default: true]                 ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  read -r start_relayers

  START_RELAYERS=${start_relayers:-true}

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

  # Replace localhost with MACHINE_IP in URLs if MACHINE_IP is set (remote deployment)
  if [ -n "$MACHINE_IP" ]; then
    L1_RPC=$(echo "$L1_RPC" | sed "s/localhost/$MACHINE_IP/g")
    L2_RPC=$(echo "$L2_RPC" | sed "s/localhost/$MACHINE_IP/g")
    L1_EXPLORER=$(echo "$L1_EXPLORER" | sed "s/localhost/$MACHINE_IP/g")
    L2_EXPLORER=$(echo "$L2_EXPLORER" | sed "s/localhost/$MACHINE_IP/g")
    L1_RELAYER=$(echo "$L1_RELAYER" | sed "s/localhost/$MACHINE_IP/g")
    L2_RELAYER=$(echo "$L2_RELAYER" | sed "s/localhost/$MACHINE_IP/g")
  fi

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
  # Determine Bridge UI URL
  if [ -n "$MACHINE_IP" ]; then
    BRIDGE_UI_URL="http://$MACHINE_IP:3002"
  else
    BRIDGE_UI_URL="http://localhost:3002"
  fi

  echo "╔══════════════════════════════════════════════════════════════╗"
  echo " 🌐 Bridge UI Configuration:                                    "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║  Bridge UI: $BRIDGE_UI_URL"
  echo "║  L1 RPC: $L1_RPC"
  echo "║  L2 RPC: $L2_RPC"
  echo "║  L1 Relayer: $L1_RELAYER"
  echo "║  L2 Relayer: $L2_RELAYER"
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
