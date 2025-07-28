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

prompt_for_sp1_configs() {
    # Prompt user for SP1_BLOCK_PROVING_PROGRAM_VKEY
    echo "Enter SP1_BLOCK_PROVING_PROGRAM_VKEY (return to skip): "
    read -r sp1_block_proving_program_vkey
    export SP1_BLOCK_PROVING_PROGRAM_VKEY=${sp1_block_proving_program_vkey:-7551aa7009644e503ffa7fce53f657264a3a1b45516afc5b026ff7e43c10d62a}

    # Prompt user for SP1_BLOCK_PROVING_PROGRAM_VK_HASH
    echo "Enter SP1_AGGREGATION_PROGRAM_VKEY (return to skip): "
    read -r sp1_aggregation_program_vkey
    export SP1_AGGREGATION_PROGRAM_VKEY=${sp1_aggregation_program_vkey:-0x000795db478eeeb7bef37247eb93389ba2a4e6c1cbe59a49afc3bd6ac2ad27ba}
}

extract_l1_deployment_results

prompt_for_sp1_configs

SP1_RETH_VERIFIER=$SP1_RETH_VERIFIER docker compose --profile sp1-register up
