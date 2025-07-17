#!/bin/bash

set -e

remove_l2_stack() {
    echo "Removing L2 stack..."

    # Remove L2 EL and drive
    docker compose --profile driver --profile proposer --profile spammer --profile prover --profile blockscout down --remove-orphans

    # Remove deployer containers
    docker compose --profile l1-deployer --profile bond-depositer --profile l2-deployer --profile sgx-register --profile sp1-register --profile risc0-register down --remove-orphans


    echo "L2 stack and relayers removed successfully"
}

remove_relayers() {
    echo "Removing relayers..."

    # Remove relayers
    docker compose --profile relayer-l1 --profile relayer-l2 --profile relayer-api down --remove-orphans

    # Remove relayer init
    docker compose --profile relayer-init --profile relayer-migrations down --remove-orphans

    echo "Relayers removed successfully"
}

remove_db() {
    echo "Removing database..."

    # Remove DB
    rm -rf ./execution-data
    rm -rf ./blockscout-postgres-data
    rm -rf ./mysql-data
    rm -rf ./rabbitmq

    echo "Database removed successfully"
}

remove_configs() {
    echo "Removing configs..."

    rm -rf ./deployment/*.json
    rm -rf ./configs/*.json

    echo "Configs removed successfully"
}

remove_l2_stack
remove_relayers
remove_db
remove_configs

echo "Surge removed successfully"
