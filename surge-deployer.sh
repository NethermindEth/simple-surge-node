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

deploy_l1() {
  # Verify if deployment is already running or it's already completed
  mkdir -p deployment
  
  # Check if deployment is already completed
  if [ -f "deployment/deploy_l1.json" ]; then
    # Prompt user for starting a new deployment if the deployment results are already present
    echo "L1 deployment already completed (deploy_l1.json exists). Start a new deployment? (true/false) [default: false]: "
    read -r start_new_deployment
    START_NEW_DEPLOYMENT=${start_new_deployment:-false}

    if [ "$START_NEW_DEPLOYMENT" = "true" ]; then
      echo "Starting a new deployment..."
      rm -f deployment/*.json
      ./surge-remover.sh
    else
      echo "Using existing deployment..."
      return 0
    fi 
  fi

  # Check if deployment is currently running
  if [ -f "deployment/deploy_l1.lock" ]; then
    echo "L1 deployment is already running (lock file exists). Please wait for it to complete or remove the lock file if the previous deployment failed."
    exit 1
  fi
  
  # Create lock file to indicate deployment is starting
  touch deployment/deploy_l1.lock
  
  # Ensure lock file is removed on script exit (success or failure)
  trap 'rm -f deployment/deploy_l1.lock' EXIT
  
  echo "Preparing Surge L1 SCs deployment..."

  # Prompt user for USE_TIMELOCKED_OWNER with default to false
  echo "Use timelocked owner? (true/false) [default: false]: "
  read -r timelocked_owner

  USE_TIMELOCKED_OWNER=${timelocked_owner:-false}

  echo "USE_TIMELOCKED_OWNER: $USE_TIMELOCKED_OWNER"

  # Prompt user for SHOULD_SETUP_VERIFIERS with default to false
  echo "Should setup prover verifiers? (true/false) [default: false]: "
  read -r should_setup_verifiers

  SHOULD_SETUP_VERIFIERS=${should_setup_verifiers:-false}

  echo "SHOULD_SETUP_VERIFIERS: $SHOULD_SETUP_VERIFIERS"

  echo "Running L1 SCs deployment simulation..."
  BROADCAST=false USE_TIMELOCKED_OWNER=$USE_TIMELOCKED_OWNER SHOULD_SETUP_VERIFIERS=false docker compose --profile l1-deployer up

  echo "Extracting L1 deployment results after simulation..."
  extract_l1_deployment_results

  if [ "$SHOULD_SETUP_VERIFIERS" = "true" ]; then
    generate_prover_chain_spec

    # Prompt user for SGX MR_ENCLAVE
    echo "Enter SGX MR_ENCLAVE (return to skip): "
    read -r sgx_mr_enclave
    export MR_ENCLAVE=${sgx_mr_enclave:-3ec57ed7974834005b8df5d80e0edfc69542580a0a305f80fd81199c181ac7cc}

    # Prompt user for SGX MR_SIGNER
    echo "Enter SGX MR_SIGNER (return to skip): "
    read -r sgx_mr_signer
    export MR_SIGNER=${sgx_mr_signer:-ca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5}

    # Prompt user for SGX V3_QUOTE_BYTES
    echo "Is SGX V3_QUOTE_BYTES file ready (return to continue): "
    read -r is_v3_quote_bytes_ready
    export V3_QUOTE_BYTES="$(cat V3_QUOTE_BYTES.txt | tr -d '\n')"

    echo "V3_QUOTE_BYTES: $V3_QUOTE_BYTES"

    # Prompt user for SP1_BLOCK_PROVING_PROGRAM_VKEY
    echo "Enter SP1_BLOCK_PROVING_PROGRAM_VKEY (return to skip): "
    read -r sp1_block_proving_program_vkey
    export SP1_BLOCK_PROVING_PROGRAM_VKEY=${sp1_block_proving_program_vkey:-7551aa7009644e503ffa7fce53f657264a3a1b45516afc5b026ff7e43c10d62a}

    # Prompt user for SP1_BLOCK_PROVING_PROGRAM_VK_HASH
    echo "Enter SP1_AGGREGATION_PROGRAM_VKEY (return to skip): "
    read -r sp1_aggregation_program_vkey
    export SP1_AGGREGATION_PROGRAM_VKEY=${sp1_aggregation_program_vkey:-0x000795db478eeeb7bef37247eb93389ba2a4e6c1cbe59a49afc3bd6ac2ad27ba}

    # Prompt user for RISC0_BLOCK_PROVING_IMAGE_ID
    echo "Enter RISC0_BLOCK_PROVING_IMAGE_ID (return to skip): "
    read -r risc0_block_proving_image_id
    export RISC0_BLOCK_PROVING_IMAGE_ID=${risc0_block_proving_image_id:-0x002eb51e99132ea02f27349345fe7e98c6867beab29a2426d1e4f693e2857bcd}

    # Prompt user for RISC0_AGGREGATION_IMAGE_ID
    echo "Enter RISC0_AGGREGATION_IMAGE_ID (return to skip): "
    read -r risc0_aggregation_image_id
    export RISC0_AGGREGATION_IMAGE_ID=${risc0_aggregation_image_id:-0x00dfdb4cc33bb068dce12585b8ecfcc8c3ae194ffaf6d19e0ebfd3fc33145c7a}
  fi

  BROADCAST=true USE_TIMELOCKED_OWNER=$USE_TIMELOCKED_OWNER SHOULD_SETUP_VERIFIERS=$SHOULD_SETUP_VERIFIERS docker compose --profile l1-deployer up

  echo "Extracting L1 deployment results after actual deployment..."
  extract_l1_deployment_results

  # Generate prover env vars if setup verifiers is true
  if [ "$SHOULD_SETUP_VERIFIERS" = "true" ]; then
    generate_prover_env_vars
  fi
}

extract_l1_deployment_results() {
  # Extract L1 deployment results from deploy_l1.json
  echo "Extracting L1 deployment results..."
  export TAIKO_INBOX=$(cat ./deployment/deploy_l1.json | jq -r '.taiko')
  export TAIKO_WRAPPER=$(cat ./deployment/deploy_l1.json | jq -r '.taiko_wrapper')
  export AUTOMATA_DCAP_ATTESTATION=$(cat ./deployment/deploy_l1.json | jq -r '.automata_dcap_attestation')
  export L1_BRIDGE=$(cat ./deployment/deploy_l1.json | jq -r '.bridge')
  export L1_ERC1155_VAULT=$(cat ./deployment/deploy_l1.json | jq -r '.erc1155_vault')
  export L1_ERC20_VAULT=$(cat ./deployment/deploy_l1.json | jq -r '.erc20_vault')
  export L1_ERC721_VAULT=$(cat ./deployment/deploy_l1.json | jq -r '.erc721_vault')
  export FORCED_INCLUSION_STORE=$(cat ./deployment/deploy_l1.json | jq -r '.forced_inclusion_store')
  
  # Handle potentially missing fields with jq's alternative operator
  export L1_OWNER=$(cat ./deployment/deploy_l1.json | jq -r '.l1_owner // "0x0000000000000000000000000000000000000000"')
  
  export PEM_CERT_CHAIN_LIB=$(cat ./deployment/deploy_l1.json | jq -r '.pem_cert_chain_lib')
  export PROOF_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.proof_verifier')
  export RISC0_GROTH16_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.risc0_groth16_verifier')
  export RISC0_RETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.risc0_reth_verifier')
  export SGX_RETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.sgx_reth_verifier')
  export SHARED_RESOLVER=$(cat ./deployment/deploy_l1.json | jq -r '.shared_resolver')
  export SIG_VERIFY_LIB=$(cat ./deployment/deploy_l1.json | jq -r '.sig_verify_lib')
  export L1_SIGNAL_SERVICE=$(cat ./deployment/deploy_l1.json | jq -r '.signal_service')
  export SP1_RETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.sp1_reth_verifier')
  export SUCCINCT_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.succinct_verifier')
  
  # Handle potentially missing field with jq's alternative operator
  export L1_TIMELOCK_CONTROLLER=$(cat ./deployment/deploy_l1.json | jq -r '.surge_timelock_controller // "0x0000000000000000000000000000000000000000"')

  echo "TAIKO_INBOX: $TAIKO_INBOX"
  echo "TAIKO_WRAPPER: $TAIKO_WRAPPER"
  echo "AUTOMATA_DCAP_ATTESTATION: $AUTOMATA_DCAP_ATTESTATION"
  echo "BRIDGE: $L1_BRIDGE"
  echo "ERC1155_VAULT: $L1_ERC1155_VAULT"
  echo "ERC20_VAULT: $L1_ERC20_VAULT"
  echo "ERC721_VAULT: $L1_ERC721_VAULT"
  echo "FORCED_INCLUSION_STORE: $FORCED_INCLUSION_STORE"
  echo "L1_OWNER: $L1_OWNER"
  echo "PEM_CERT_CHAIN_LIB: $PEM_CERT_CHAIN_LIB"
  echo "PROOF_VERIFIER: $PROOF_VERIFIER"
  echo "RISC0_GROTH16_VERIFIER: $RISC0_GROTH16_VERIFIER"
  echo "RISC0_RETH_VERIFIER: $RISC0_RETH_VERIFIER"
  echo "SGX_RETH_VERIFIER: $SGX_RETH_VERIFIER"
  echo "SHARED_RESOLVER: $SHARED_RESOLVER"
  echo "SIG_VERIFY_LIB: $SIG_VERIFY_LIB"
  echo "SIGNAL_SERVICE: $L1_SIGNAL_SERVICE"
  echo "SP1_RETH_VERIFIER: $SP1_RETH_VERIFIER"
  echo "SUCCINCT_VERIFIER: $SUCCINCT_VERIFIER"
  echo "SURGE_TIMELOCK_CONTROLLER: $L1_TIMELOCK_CONTROLLER"

  echo "L1 deployment results extracted successfully"
}

deploy_proposer_wrapper() {
  # Check if deployment is already completed
  if [ -f "deployment/proposer_wrappers.json" ]; then
    export SURGE_PROPOSER_WRAPPER=$(cat ./deployment/proposer_wrappers.json | jq -r '.proposer_wrapper')
    echo "Proposer Wrapper deployment already completed (proposer_wrappers.json exists), deployment will be skipped"
    return 0
  else
    echo "Deploying Proposer Wrapper..."

    echo "Run the simulation first..."
    BROADCAST=false docker compose --profile wrapper-deployer up

    export SURGE_PROPOSER_WRAPPER=$(cat ./deployment/proposer_wrappers.json | jq -r '.proposer_wrapper')

    echo "Run the actual deployment..."
    BROADCAST=true docker compose --profile wrapper-deployer up

    echo "Proposer Wrapper deployed successfully"
  fi
}

deposit_bond() {
  echo "Depositing bond..."

  # Prompt user for deposit bond
  echo "Deposit bond? (true/false) [default: true]: "
  read -r deposit_bond

  DEPOSIT_BOND=${deposit_bond:-true}

  if [ "$DEPOSIT_BOND" = "true" ]; then 

    # Prompt user for BOND_AMOUNT
    echo "Enter bond amount (in ETH, default: 1000): "
    read -r bond_amount

    BOND_AMOUNT=${bond_amount:-1000}
    # Convert ETH to wei using bc
    BOND_AMOUNT=$(echo "$BOND_AMOUNT * 1000000000000000000" | bc | cut -d. -f1)

    docker compose --profile bond-depositer up

    echo "Bond deposited successfully"
  else
    return 0
  fi
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
    # Deploy L2 SCs first
    deploy_l2

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

generate_prover_chain_spec() {
  echo "Generating prover chain spec..."

  # Get chain IDs from environment or use defaults
  L1_CHAIN_ID=${L1_CHAINID:-3151908}
  L2_CHAIN_ID=${L2_CHAINID:-763374}

  GENESIS_TIME=$(curl -s http://localhost:33001/eth/v1/beacon/genesis | jq -r '.data.genesis_time')

  # Generate chain spec list
  cat > configs/chain_spec_list_default.json << EOF
[
  {
    "name": "surge_dev_l1",
    "chain_id": $L1_CHAIN_ID,
    "max_spec_id": "CANCUN",
    "hard_forks": {
      "FRONTIER": {
        "Block": 0
      },
      "SHANGHAI": {
        "Timestamp": 0
      },
      "CANCUN": {
        "Timestamp": 0
      }
    },
    "eip_1559_constants": {
      "base_fee_change_denominator": "0x8",
      "base_fee_max_increase_denominator": "0x8",
      "base_fee_max_decrease_denominator": "0x8",
      "elasticity_multiplier": "0x2"
    },
    "l1_contract": null,
    "l2_contract": null,
    "rpc": "$L1_RPC",
    "beacon_rpc": "$L1_BEACON_RPC",
    "verifier_address_forks": {
      "FRONTIER": {
        "SGX": null,
        "SP1": null,
        "RISC0": null
      }
    },
    "genesis_time": $GENESIS_TIME,
    "seconds_per_slot": 12,
    "is_taiko": false
  },
  {
    "name": "surge_dev",
    "chain_id": $L2_CHAIN_ID,
    "max_spec_id": "PACAYA",
    "hard_forks": {
      "HEKLA": {
        "Block": 0
      },
      "ONTAKE": {
        "Block": 1
      },
      "PACAYA": {
        "Block": 1
      },
      "CANCUN": "TBD"
    },
    "eip_1559_constants": {
      "base_fee_change_denominator": "0x8",
      "base_fee_max_increase_denominator": "0x8",
      "base_fee_max_decrease_denominator": "0x8",
      "elasticity_multiplier": "0x2"
    },
    "l1_contract": "$TAIKO_INBOX",
    "l2_contract": "$TAIKO_ANCHOR",
    "rpc": "$L2_RPC",
    "beacon_rpc": null,
    "verifier_address_forks": {
      "HEKLA": {
        "SGX": "$SGX_RETH_VERIFIER",
        "SP1": "$SP1_RETH_VERIFIER",
        "RISC0": "$RISC0_RETH_VERIFIER"
      },
      "ONTAKE": {
        "SGX": "$SGX_RETH_VERIFIER",
        "SP1": "$SP1_RETH_VERIFIER",
        "RISC0": "$RISC0_RETH_VERIFIER"
      }
    },
    "genesis_time": 0,
    "seconds_per_slot": 1,
    "is_taiko": true
  }
]
EOF
  
  echo "Prover chain spec generated successfully"
  
  # Print the generated content with clear dividers
  echo ""
  echo "=================================================================================="
  echo "GENERATED CHAIN SPEC LIST (configs/chain_spec_list_default.json)"
  echo "=================================================================================="
  echo ""
  cat configs/chain_spec_list_default.json
  echo ""
  echo "=================================================================================="
  echo "Chain spec generated and saved to: configs/chain_spec_list_default.json"
  echo "=================================================================================="
  echo ""
}

generate_prover_env_vars() {
  echo "Generating prover env vars..."

  # Set SGX_INSTANCE_ID from the JSON file
  export SGX_INSTANCE_ID=$(cat deployment/sgx_instances.json | jq -r '.sgx_instance_id')

  echo ""
  echo "=================================================================================="
  echo "GENERATED PROVER ENV VARS"
  echo "=================================================================================="
  echo ""
  echo "export SGX_INSTANCE_ID=$SGX_INSTANCE_ID"
  echo "export SGX_VERIFIER_ADDRESS=$SGX_RETH_VERIFIER"
  echo "export ATTESTATION_ADDRESS=$AUTOMATA_DCAP_ATTESTATION"
  echo "export PEM_CERTCHAIN_ADDRESS=$PEM_CERT_CHAIN_LIB"
  echo "export GROTH16_VERIFIER_ADDRESS=$RISC0_GROTH16_VERIFIER"
  echo "export SP1_VERIFIER_ADDRESS=$SUCCINCT_VERIFIER"
  echo ""
  echo "=================================================================================="
  echo "Prover env vars generated, please copy and paste them when you start the provers"
  echo "=================================================================================="
  echo ""

  echo "Prover env vars generated successfully"
}

deploy_surge() {
  # Select remote or local
  echo "Select remote or local (0 for local, 1 for remote) [default: local]: "
  read -r remote_or_local

  REMOTE_OR_LOCAL=${remote_or_local:-0}

  if [ "$REMOTE_OR_LOCAL" = "1" ]; then
    echo "Using remote environment"

    # Prepare Blockscout for remote
    prepare_blockscout_for_remote

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

  # Deploy L1 SCs
  deploy_l1

  # Extract L1 deployment results
  extract_l1_deployment_results

  # Deploy Proposer Wrapper
  deploy_proposer_wrapper

  # Deposit bond
  deposit_bond

  # Start L2 Stack
  start_l2_stack

  # Start Relayers
  start_relayers
}

deploy_surge
