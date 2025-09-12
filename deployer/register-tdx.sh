#!/bin/bash

set -e

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
    
    # Extract Azure TDX verifier address
    export AZURE_TDX_VERIFIER=$(cat ./deployment/deploy_l1.json | jq -r '.azure_tdx_verifier // "0x0000000000000000000000000000000000000000"')
    
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
    echo "AZURE_TDX_VERIFIER: $AZURE_TDX_VERIFIER"
    echo "SHARED_RESOLVER: $SHARED_RESOLVER"
    echo "SIG_VERIFY_LIB: $SIG_VERIFY_LIB"
    echo "SIGNAL_SERVICE: $L1_SIGNAL_SERVICE"
    echo "SP1_RETH_VERIFIER: $SP1_RETH_VERIFIER"
    echo "SUCCINCT_VERIFIER: $SUCCINCT_VERIFIER"
    echo "SURGE_TIMELOCK_CONTROLLER: $L1_TIMELOCK_CONTROLLER"

    echo "L1 deployment results extracted successfully"
}

prompt_for_tdx_configs() {
    echo "Configuring TDX (Azure TDX) verifier..."
    
    # Prompt user for TDX trusted parameters
    echo "Is TDX_TRUSTED_PARAMS_BYTES file ready? (return to continue): "
    read -r is_tdx_trusted_params_ready
    
    if [ -f "TDX_TRUSTED_PARAMS_BYTES.txt" ]; then
        export TDX_TRUSTED_PARAMS_BYTES=$(cat TDX_TRUSTED_PARAMS_BYTES.txt | tr -d '\n')
        echo "TDX_TRUSTED_PARAMS_BYTES loaded successfully"
    else
        echo "Warning: TDX_TRUSTED_PARAMS_BYTES.txt not found"
        echo "Enter TDX_TRUSTED_PARAMS_BYTES (hex string, return to skip): "
        read -r tdx_trusted_params
        export TDX_TRUSTED_PARAMS_BYTES=${tdx_trusted_params:-""}
    fi
    
    # Prompt user for TDX quote bytes
    echo "Is TDX_QUOTE_BYTES file ready? (return to continue): "
    read -r is_tdx_quote_ready
    
    if [ -f "TDX_QUOTE_BYTES.txt" ]; then
        export TDX_QUOTE_BYTES=$(cat TDX_QUOTE_BYTES.txt | tr -d '\n')
        echo "TDX_QUOTE_BYTES loaded successfully"
    else
        echo "Warning: TDX_QUOTE_BYTES.txt not found"
        echo "Enter TDX_QUOTE_BYTES (hex string, return to skip): "
        read -r tdx_quote_bytes
        export TDX_QUOTE_BYTES=${tdx_quote_bytes:-""}
    fi
    
    # Prompt for TDX DAO addresses if needed for collateral setup
    echo "Enter TDX_PCS_DAO_ADDRESS (return to skip): "
    read -r tdx_pcs_dao
    export TDX_PCS_DAO_ADDRESS=${tdx_pcs_dao:-"0x0000000000000000000000000000000000000000"}
    
    echo "Enter TDX_FMSPC_TCB_DAO_ADDRESS (return to skip): "
    read -r tdx_fmspc_tcb_dao
    export TDX_FMSPC_TCB_DAO_ADDRESS=${tdx_fmspc_tcb_dao:-"0x0000000000000000000000000000000000000000"}
    
    echo "Enter TDX_ENCLAVE_IDENTITY_DAO_ADDRESS (return to skip): "
    read -r tdx_enclave_identity_dao
    export TDX_ENCLAVE_IDENTITY_DAO_ADDRESS=${tdx_enclave_identity_dao:-"0x0000000000000000000000000000000000000000"}
    
    echo "Enter TDX_ENCLAVE_IDENTITY_HELPER_ADDRESS (return to skip): "
    read -r tdx_enclave_identity_helper
    export TDX_ENCLAVE_IDENTITY_HELPER_ADDRESS=${tdx_enclave_identity_helper:-"0x0000000000000000000000000000000000000000"}
    
    echo "TDX configuration completed"
    echo "TDX_TRUSTED_PARAMS_BYTES: $TDX_TRUSTED_PARAMS_BYTES"
    echo "TDX_QUOTE_BYTES: $TDX_QUOTE_BYTES"
    echo "TDX_PCS_DAO_ADDRESS: $TDX_PCS_DAO_ADDRESS"
    echo "TDX_FMSPC_TCB_DAO_ADDRESS: $TDX_FMSPC_TCB_DAO_ADDRESS"
    echo "TDX_ENCLAVE_IDENTITY_DAO_ADDRESS: $TDX_ENCLAVE_IDENTITY_DAO_ADDRESS"
    echo "TDX_ENCLAVE_IDENTITY_HELPER_ADDRESS: $TDX_ENCLAVE_IDENTITY_HELPER_ADDRESS"
}

extract_l1_deployment_results

prompt_for_tdx_configs

BROADCAST=true docker compose --profile tdx-register up