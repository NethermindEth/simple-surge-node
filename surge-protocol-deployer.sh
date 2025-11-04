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
fi

if [ "$SURGE_ENVIRONMENT" = "1" ]; then
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🚀 Using Devnet Environment                                   "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  if [ "$NON_INTERACTIVE" = "false" ]; then
    # Select remote or local
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Select remote or local:                                    "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ 0 for local                                                  ║"
    echo "║ 1 for remote                                                 ║"
    echo "║ [default: local]                                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r remote_or_local

    REMOTE_OR_LOCAL=${remote_or_local:-0}
  fi
  if [ "$REMOTE_OR_LOCAL" = "1" ]; then
    # Select which devnet machine to use
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Select which devnet machine to use:                        "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ 1 for Devnet 1 (prover)                                      ║"
    echo "║ 2 for Devnet 2 (taiko-client)                                ║"
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
      echo "  🚀 Using Devnet 2 (taiko-client)                              "
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
    echo "  🚀 Using others                                               "
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
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ⚠️ Using Staging Environment, skipping protocol deployment... "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ Please execute surge-stack-deployer.sh directly              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🔧 REQUIRED ACTION: Copy the correct env file for Staging     "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ Run: cp .env.staging .env                                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  exit 0
elif [ "$SURGE_ENVIRONMENT" = "3" ]; then
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ⚠️ Using Testnet Environment, skipping protocol deployment... "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ Please execute surge-stack-deployer.sh directly              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🔧 REQUIRED ACTION: Copy the correct env file for Testnet     "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ Run: cp .env.hoodi .env                                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  exit 0
fi

# Load environment variables from .env file if it exists
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
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ Automatically copying .env.devnet to .env                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  cp .env.devnet .env
  set -a  # automatically export all variables
  source .env
  set +a  # disable automatic export
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ✅ Successfully loaded Devnet environment variables           "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
fi

# Helper function to update environment variables in .env file
update_env_var() {
  local env_file="$1"
  local var_name="$2"
  local var_value="$3"

  # Check if the variable exists in the file
  if grep -q "^${var_name}=" "$env_file"; then
    # Update existing variable
    sed -i.bak "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
  else
    # Add new variable if it doesn't exist
    echo "${var_name}=${var_value}" >> "$env_file"
  fi
}

generate_prover_chain_spec() {
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Generating prover chain spec list json...                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  GENESIS_TIME=$(curl -s http://localhost:33001/eth/v1/beacon/genesis | jq -r '.data.genesis_time')

  # Generate chain spec list
  cat > configs/chain_spec_list_default.json << EOF
[
  {
    "name": "surge_dev_l1",
    "chain_id": $L1_CHAINID,
    "max_spec_id": "CANCUN",
    "hard_forks": {},
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
    "verifier_address_forks": {},
    "genesis_time": $GENESIS_TIME,
    "seconds_per_slot": 12,
    "is_taiko": false
  },
  {
    "name": "surge_dev",
    "chain_id": $L2_CHAINID,
    "max_spec_id": "PACAYA",
    "hard_forks": {
        "ONTAKE": {
            "Block": 1
        },
        "PACAYA": {
            "Block": 1
        }
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
      "ONTAKE": {
        "SGX": "$SGX_RETH_VERIFIER",
        "SGXGETH": "$SGX_GETH_VERIFIER",
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

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ✅ Prover chain spec list json generated successfully,        "
  echo "  and saved to: configs/chain_spec_list_default.json            "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
}

generate_prover_env_vars() {
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Generating prover env vars...                                ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  # Set SGX_INSTANCE_ID from the JSON file
  if [ -f "deployment/sgx_instances.json" ]; then
    export SGX_INSTANCE_ID=$(cat deployment/sgx_instances.json | jq -r '.sgx_instance_id // "0"')
  else
    export SGX_INSTANCE_ID="0"
  fi

  echo ">>>>>>"
  echo "export SGX_INSTANCE_ID=$SGX_INSTANCE_ID"
  echo "export SGX_ONTAKE_INSTANCE_ID=${SGX_INSTANCE_ID}"
  echo "export SGX_PACAYA_INSTANCE_ID=${SGX_INSTANCE_ID}"
  echo "export GROTH16_VERIFIER_ADDRESS=$RISC0_GROTH16_VERIFIER"
  echo "export SP1_VERIFIER_ADDRESS=$SUCCINCT_VERIFIER"
  echo ">>>>>>"
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ✅ Prover env vars generated successfully,                    "
  echo "  please copy and paste them when you start the provers         "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
}

retrieve_guest_data() {
  if [ "$1" = "sgx_reth" ]; then
    if [ "$SGX_RAIKO_HOST" != "" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  Retrieving guest data for SGX - $SGX_RAIKO_HOST               "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export MR_ENCLAVE_RETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_reth.mr_enclave')
      export MR_SIGNER_RETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_reth.mr_signer')
      export V3_QUOTE_BYTES_RETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_reth.quote')
    fi
  elif [ "$1" = "sgx_geth" ]; then
    if [ "$SGX_RAIKO_HOST" != "" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  Retrieving guest data for SGXGETH - $SGX_RAIKO_HOST           "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export MR_ENCLAVE_GETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_geth.mr_enclave')
      export MR_SIGNER_GETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_geth.mr_signer')
      export V3_QUOTE_BYTES_GETH=$(curl -s "$SGX_RAIKO_HOST/guest_data" | jq -r '.sgx_geth.quote')
    fi
  elif [ "$1" = "sp1" ]; then
    if [ "$RAIKO_HOST_ZKVM" != "" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  Retrieving guest data for SP1 - $RAIKO_HOST_ZKVM              "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export SP1_BLOCK_PROVING_PROGRAM_VKEY=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.sp1.block_program_hash')
      export SP1_AGGREGATION_PROGRAM_VKEY=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.sp1.aggregation_program_hash')
    fi
  elif [ "$1" = "risc0" ]; then
    if [ "$RAIKO_HOST_ZKVM" != "" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  Retrieving guest data for RISC0 - $RAIKO_HOST_ZKVM            "
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      export RISC0_AGGREGATION_IMAGE_ID=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.risc0.aggregation_program_hash')
      export RISC0_BLOCK_PROVING_IMAGE_ID=$(curl -s "$RAIKO_HOST_ZKVM/guest_data" | jq -r '.risc0.block_program_hash')
    fi
  fi
  echo
}

deploy_l1() {
  mkdir -p deployment

  # Check if deployment is already completed
  if [ -f "deployment/deploy_l1.json" ]; then
    if [ "$NON_INTERACTIVE" = "true" ]; then
      START_NEW_DEPLOYMENT=false
    else
      # Prompt user for starting a new deployment if the deployment results are already present
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "  ⚠️ Surge L1 deployment already completed                      "
      echo "  (deploy_l1.json exists)                                       "
      echo "║══════════════════════════════════════════════════════════════║"
      echo "║ Start a new deployment? (true/false) [default: false]        ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      read -r start_new_deployment
      START_NEW_DEPLOYMENT=${start_new_deployment:-false}
    fi

    if [ "$START_NEW_DEPLOYMENT" = "true" ]; then
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Starting a new deployment...                                 ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      rm -f deployment/*.json
      ./surge-remover.sh
    else
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Using existing deployment...                                 ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      return 0
    fi
  fi

  # Check if deployment is currently running
  if [ -f "deployment/deploy_l1.lock" ]; then
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️ Surge L1 deployment is already running                    "
    echo "  (deploy_l1.lock exists)                                       "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ Please wait for it to complete or remove the lock file if    ║"
    echo "║ the previous deployment failed.                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    exit 1
  fi

  # Create lock file to indicate deployment is starting
  touch deployment/deploy_l1.lock

  # Ensure lock file is removed on script exit (success or failure)
  trap 'rm -f deployment/deploy_l1.lock' EXIT

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Preparing Surge L1 SCs deployment...                         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  if [ "$NON_INTERACTIVE" = "true" ]; then
    export USE_TIMELOCKED_OWNER=false
  else
    # Prompt user for USE_TIMELOCKED_OWNER with default to false
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Use timelocked owner? (true/false) [default: false]          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r timelocked_owner

    export USE_TIMELOCKED_OWNER=${timelocked_owner:-false}
  fi

  # Update USE_TIMELOCKED_OWNER in env file for other functions and scripts to use
  update_env_var ".env" "USE_TIMELOCKED_OWNER" "$USE_TIMELOCKED_OWNER"

  # Clean up backup file if it exists
  if [ -f ".env.bak" ]; then
    rm ".env.bak"
  fi

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Deploying Surge L1 SCs...                                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  BROADCAST=true USE_TIMELOCKED_OWNER=$USE_TIMELOCKED_OWNER VERIFY=false docker compose -f docker-compose-protocol.yml --profile l1-deployer up
}

extract_l1_deployment_results() {
  # Extract L1 deployment results from deploy_l1.json
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Extracting Surge L1 SCs deployment results...                ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  export TAIKO_INBOX=$(cat ./deployment/deploy_l1.json | jq -r '.taiko')
  export TAIKO_WRAPPER=$(cat ./deployment/deploy_l1.json | jq -r '.taiko_wrapper')
  export AUTOMATA_DCAP_ATTESTATION_GETH=$(cat ./deployment/deploy_l1.json | jq -r '.automata_dcap_attestation_geth')
  export AUTOMATA_DCAP_ATTESTATION_RETH=$(cat ./deployment/deploy_l1.json | jq -r '.automata_dcap_attestation_reth')
  export BRIDGE=$(cat ./deployment/deploy_l1.json | jq -r '.bridge')
  export ERC1155_VAULT=$(cat ./deployment/deploy_l1.json | jq -r '.erc1155_vault')
  export ERC20_VAULT=$(cat ./deployment/deploy_l1.json | jq -r '.erc20_vault')
  export ERC721_VAULT=$(cat ./deployment/deploy_l1.json | jq -r '.erc721_vault')
  export FORCED_INCLUSION_STORE=$(cat ./deployment/deploy_l1.json | jq -r '.forced_inclusion_store')

  # Handle potentially missing fields with jq's alternative operator
  export L1_OWNER=$(cat ./deployment/deploy_l1.json | jq -r '.l1_owner // "0x0000000000000000000000000000000000000000"')

  export PEM_CERT_CHAIN_LIB=$(cat ./deployment/deploy_l1.json | jq -r '.pem_cert_chain_lib')
  export PROOF_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.proof_verifier')
  export RISC0_GROTH16_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.risc0_groth16_verifier')
  export RISC0_RETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.risc0_reth_verifier')
  export SGX_GETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.sgx_geth_verifier')
  export SGX_RETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.sgx_reth_verifier')
  export SHARED_RESOLVER=$(cat ./deployment/deploy_l1.json | jq -r '.shared_resolver')
  export SIG_VERIFY_LIB=$(cat ./deployment/deploy_l1.json | jq -r '.sig_verify_lib')
  export SIGNAL_SERVICE=$(cat ./deployment/deploy_l1.json | jq -r '.signal_service')
  export SP1_RETH_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.sp1_reth_verifier')
  export SUCCINCT_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.succinct_verifier')

  # Handle potentially missing field with jq's alternative operator
  export SURGE_TIMELOCK_CONTROLLER=$(cat ./deployment/deploy_l1.json | jq -r '.surge_timelock_controller // "0x0000000000000000000000000000000000000000"')

  echo
  echo ">>>>>>"
  echo " TAIKO_INBOX: $TAIKO_INBOX "
  echo " TAIKO_WRAPPER: $TAIKO_WRAPPER "
  echo " AUTOMATA_DCAP_ATTESTATION_GETH: $AUTOMATA_DCAP_ATTESTATION_GETH "
  echo " AUTOMATA_DCAP_ATTESTATION_RETH: $AUTOMATA_DCAP_ATTESTATION_RETH "
  echo " BRIDGE: $BRIDGE "
  echo " ERC1155_VAULT: $ERC1155_VAULT "
  echo " ERC20_VAULT: $ERC20_VAULT "
  echo " ERC721_VAULT: $ERC721_VAULT "
  echo " FORCED_INCLUSION_STORE: $FORCED_INCLUSION_STORE "
  echo " L1_OWNER: $L1_OWNER "
  echo " PEM_CERT_CHAIN_LIB: $PEM_CERT_CHAIN_LIB "
  echo " PROOF_VERIFIER: $PROOF_VERIFIER "
  echo " RISC0_GROTH16_VERIFIER: $RISC0_GROTH16_VERIFIER "
  echo " RISC0_RETH_VERIFIER: $RISC0_RETH_VERIFIER "
  echo " SGX_GETH_VERIFIER: $SGX_GETH_VERIFIER "
  echo " SGX_RETH_VERIFIER: $SGX_RETH_VERIFIER "
  echo " SHARED_RESOLVER: $SHARED_RESOLVER "
  echo " SIG_VERIFY_LIB: $SIG_VERIFY_LIB "
  echo " SIGNAL_SERVICE: $SIGNAL_SERVICE "
  echo " SP1_RETH_VERIFIER: $SP1_RETH_VERIFIER "
  echo " SUCCINCT_VERIFIER: $SUCCINCT_VERIFIER "
  echo " SURGE_TIMELOCK_CONTROLLER: $SURGE_TIMELOCK_CONTROLLER "
  echo ">>>>>>"
  echo

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Updating .env with extracted values...                       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  update_env_var ".env" "TAIKO_INBOX" "$TAIKO_INBOX"
  update_env_var ".env" "TAIKO_WRAPPER" "$TAIKO_WRAPPER"
  update_env_var ".env" "AUTOMATA_DCAP_ATTESTATION_GETH" "$AUTOMATA_DCAP_ATTESTATION_GETH"
  update_env_var ".env" "AUTOMATA_DCAP_ATTESTATION_RETH" "$AUTOMATA_DCAP_ATTESTATION_RETH"
  update_env_var ".env" "BRIDGE" "$BRIDGE"
  update_env_var ".env" "ERC1155_VAULT" "$ERC1155_VAULT"
  update_env_var ".env" "ERC20_VAULT" "$ERC20_VAULT"
  update_env_var ".env" "ERC721_VAULT" "$ERC721_VAULT"
  update_env_var ".env" "FORCED_INCLUSION_STORE" "$FORCED_INCLUSION_STORE"
  update_env_var ".env" "L1_OWNER" "$L1_OWNER"
  update_env_var ".env" "PEM_CERT_CHAIN_LIB" "$PEM_CERT_CHAIN_LIB"
  update_env_var ".env" "PROOF_VERIFIER" "$PROOF_VERIFIER"
  update_env_var ".env" "RISC0_GROTH16_VERIFIER" "$RISC0_GROTH16_VERIFIER"
  update_env_var ".env" "RISC0_RETH_VERIFIER" "$RISC0_RETH_VERIFIER"
  update_env_var ".env" "SGX_GETH_VERIFIER" "$SGX_GETH_VERIFIER"
  update_env_var ".env" "SGX_RETH_VERIFIER" "$SGX_RETH_VERIFIER"
  update_env_var ".env" "SHARED_RESOLVER" "$SHARED_RESOLVER"
  update_env_var ".env" "SIG_VERIFY_LIB" "$SIG_VERIFY_LIB"
  update_env_var ".env" "SIGNAL_SERVICE" "$SIGNAL_SERVICE"
  update_env_var ".env" "SP1_RETH_VERIFIER" "$SP1_RETH_VERIFIER"
  update_env_var ".env" "SUCCINCT_VERIFIER" "$SUCCINCT_VERIFIER"
  update_env_var ".env" "SURGE_TIMELOCK_CONTROLLER" "$SURGE_TIMELOCK_CONTROLLER"

  # Clean up backup file if it exists
  if [ -f ".env.bak" ]; then
    rm ".env.bak"
  fi
}

deploy_proposer_wrapper() {
  # Check if deployment is already completed
  if [ -f "deployment/proposer_wrappers.json" ]; then
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ⚠️  Proposer Wrapper deployment already completed              "
    echo "  (proposer_wrappers.json exists)                               "
    echo "║══════════════════════════════════════════════════════════════║"
    echo "║ Deployment will be skipped...                                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    return 0
  else
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Deploying Surge Proposer Wrapper...                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile proposer-wrapper-deployer up
  fi
}

extract_surge_proposer_wrapper() {
  export SURGE_PROPOSER_WRAPPER=$(cat ./deployment/proposer_wrappers.json | jq -r '.proposer_wrapper')

  echo
  echo ">>>>>>"
  echo " SURGE_PROPOSER_WRAPPER: $SURGE_PROPOSER_WRAPPER "
  echo ">>>>>>"
  echo

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Updating .env with proposer wrapper address...               ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  update_env_var ".env" "SURGE_PROPOSER_WRAPPER" "$SURGE_PROPOSER_WRAPPER"

  # Clean up backup file if it exists
  if [ -f ".env.bak" ]; then
    rm ".env.bak"
  fi
}

deploy_provers() {
  if [ "$NON_INTERACTIVE" = "true" ]; then
    RUNNING_PROVERS=false
  else
    # Prompt user for RUNNING_PROVERS with default to false
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Running provers? (true/false) [default: false]               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r running_provers

    RUNNING_PROVERS=${running_provers:-false}
  fi

  # If running provers is true, set up the verifiers
  if [ "$RUNNING_PROVERS" = "true" ]; then
    generate_prover_chain_spec

    if [ ! -f "deployment/sgx_reth_verifier_setup.lock" ]; then
      # Prompt user for running SGX Raiko
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Running SGX Raiko? (true/false) [default: false]              ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      read -r running_sgx_raiko
      RUNNING_SGX_RAIKO=${running_sgx_raiko:-false}

      if [ "$RUNNING_SGX_RAIKO" = "true" ]; then
        # Retrieve guest data from prover endpoint
        retrieve_guest_data sgx_reth
        if [ "$MR_ENCLAVE_RETH" = "" ] && [ "$MR_ENCLAVE" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SGX RETH MR_ENCLAVE is not set                             "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        else
          export MR_ENCLAVE=$MR_ENCLAVE_RETH
        fi

        if [ "$MR_SIGNER_RETH" = "" ] && [ "$MR_SIGNER" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SGX RETH MR_SIGNER is not set                              "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        else
          export MR_SIGNER=$MR_SIGNER_RETH
        fi

        if [ "$V3_QUOTE_BYTES_RETH" = "" ] && [ "$V3_QUOTE_BYTES" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SGX RETH V3_QUOTE_BYTES is not set                         "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        else
          export V3_QUOTE_BYTES=$V3_QUOTE_BYTES_RETH
        fi

        SGX_VERIFIER_ADDRESS=${SGX_RETH_VERIFIER} AUTOMATA_PROXY_ADDRESS=${AUTOMATA_DCAP_ATTESTATION_RETH} BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile sgx-reth-verifier-setup up
      fi
    fi

    # TODO: Add support for SGX Gaiko

    if [ ! -f "deployment/sgx_geth_verifier_setup.lock" ]; then
      # Prompt user for running SGX Gaiko
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Running SGX Gaiko? (true/false) [default: false]              ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      read -r running_sgx_gaiko
      RUNNING_SGX_GAIKO=${running_sgx_gaiko:-false}

      if [ "$RUNNING_SGX_GAIKO" = "true" ]; then
        retrieve_guest_data sgx_geth
        if [ "$MR_ENCLAVE_GETH" = "" ] && [ "$MR_ENCLAVE" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SGX GETH MR_ENCLAVE is not set                             "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        else
          export MR_ENCLAVE=$MR_ENCLAVE_GETH
        fi

        if [ "$MR_SIGNER_GETH" = "" ] && [ "$MR_SIGNER" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SGX GETH MR_SIGNER is not set                              "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        else
          export MR_SIGNER=$MR_SIGNER_GETH
        fi

        if [ "$V3_QUOTE_BYTES_GETH" = "" ] && [ "$V3_QUOTE_BYTES" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SGX GETH V3_QUOTE_BYTES is not set                         "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        else
          export V3_QUOTE_BYTES=$V3_QUOTE_BYTES_GETH
        fi

        SGX_VERIFIER_ADDRESS=${SGX_GETH_VERIFIER} AUTOMATA_PROXY_ADDRESS=${AUTOMATA_DCAP_ATTESTATION_GETH} BROADCAST=true VERIFY=false docker compose -f docker-compose-protocol.yml --profile sgx-geth-verifier-setup up
      fi
    fi

    if [ ! -f "deployment/sp1_verifier_setup.lock" ]; then
      # Prompt user for running SP1 Raiko
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Running SP1? (true/false) [default: false]                   ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      read -r running_sp1_raiko
      RUNNING_SP1_RAIKO=${running_sp1_raiko:-false}

      if [ "$RUNNING_SP1_RAIKO" = "true" ]; then
        retrieve_guest_data sp1
        if [ "$SP1_BLOCK_PROVING_PROGRAM_VKEY" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SP1_BLOCK_PROVING_PROGRAM_VKEY is not set                  "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        fi

        if [ "$SP1_AGGREGATION_PROGRAM_VKEY" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ SP1_AGGREGATION_PROGRAM_VKEY is not set                    "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        fi

        BROADCAST=true docker compose -f docker-compose-protocol.yml --profile sp1-verifier-setup up
      fi
    fi

    if [ ! -f "deployment/risc0_verifier_setup.lock" ]; then
      # Prompt user for running RISC0 Raiko
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Running RISC0? (true/false) [default: false]                 ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      read -r running_risc0_raiko
      RUNNING_RISC0_RAIKO=${running_risc0_raiko:-false}

      if [ "$RUNNING_RISC0_RAIKO" = "true" ]; then
        retrieve_guest_data risc0
        if [ "$RISC0_BLOCK_PROVING_IMAGE_ID" = "" ]; then
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ RISC0_BLOCK_PROVING_IMAGE_ID is not set                    "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        fi

        if [ "$RISC0_AGGREGATION_IMAGE_ID" = "" ]; then
          echo
          echo "╔══════════════════════════════════════════════════════════════╗"
          echo "  ❗ RISC0_AGGREGATION_IMAGE_ID is not set                      "
          echo "║══════════════════════════════════════════════════════════════║"
          echo "║ Please set it and rerun the script                           ║"
          echo "╚══════════════════════════════════════════════════════════════╝"
          echo
          exit 1
        fi

        BROADCAST=true docker compose -f docker-compose-protocol.yml --profile risc0-verifier-setup up
      fi
    fi

    # Generate prover env vars once set up the verifiers
    generate_prover_env_vars
  fi
}

deposit_bond() {
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║ Depositing bond...                                           ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo

  if [ "$NON_INTERACTIVE" = "true" ]; then
    DEPOSIT_BOND=true
  else
    # Prompt user for deposit bond
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Deposit bond? (true/false) [default: true]                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    read -r deposit_bond

    DEPOSIT_BOND=${deposit_bond:-true}
  fi

  if [ "$DEPOSIT_BOND" = "true" ]; then
    if [ "$NON_INTERACTIVE" = "true" ]; then
      BOND_AMOUNT=1000
    else
      # Prompt user for BOND_AMOUNT
      echo
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║ Enter bond amount (in ETH, default: 1000)                    ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      echo
      read -r bond_amount

      BOND_AMOUNT=${bond_amount:-1000}
    fi

    # Convert to wei
    export BOND_AMOUNT=$(echo "$BOND_AMOUNT * 1000000000000000000" | bc | cut -d. -f1)

    docker compose -f docker-compose-protocol.yml --profile bond-deposit up
  else
    return 0
  fi
}

deploy_surge_protocol() {
  # Deploy L1 SCs
  deploy_l1

  # Extract L1 deployment results
  extract_l1_deployment_results

  # Deploy Surge Proposer Wrapper
  deploy_proposer_wrapper

  # Extract Surge Proposer Wrapper address
  extract_surge_proposer_wrapper

  # Deploy Provers
  deploy_provers

  # Deposit bond
  deposit_bond

  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  ✅ Surge Protocol deployment completed successfully           "
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "  🔧 NEXT ACTION:                                               "
  echo "║══════════════════════════════════════════════════════════════║"
  echo "║ Run ./surge-stack-deployer.sh to start the L2 stack          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo
}

deploy_surge_protocol
