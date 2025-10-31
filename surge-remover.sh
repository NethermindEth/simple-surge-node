#!/bin/bash

set -e

NON_INTERACTIVE=false
if [ "$1" = "--devnet-non-interactive" ]; then
  NON_INTERACTIVE=true
fi

remove_l2_stack() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Removing L2 stack...                                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Remove L2 EL and drive
    docker compose --profile driver --profile proposer --profile spammer --profile prover --profile blockscout down --remove-orphans

    # Remove deployer containers
    docker compose -f docker-compose-protocol.yml --profile l1-deployer --profile proposer-wrapper-deployer --profile sgx-verifier-setup --profile sp1-verifier-setup --profile risc0-verifier-setup --profile bond-deposit --profile l2-deployer down --remove-orphans

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ L2 stack and relayers removed successfully                 "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

remove_relayers() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Removing relayers...                                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Remove relayers
    docker compose -f docker-compose-relayer.yml --profile relayer-l1 --profile relayer-l2 --profile relayer-api down --remove-orphans

    # Remove relayer init
    docker compose -f docker-compose-relayer.yml --profile relayer-init --profile relayer-migrations down --remove-orphans

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Relayers removed successfully                              "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

remove_db() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Removing database...                                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Remove DB contents but preserve directory structure with .gitkeep
    if [ -d "./execution-data" ] && [ -n "$(ls -A ./execution-data 2>/dev/null)" ]; then
        rm -rf ./execution-data/* || echo "Warning: Could not remove some execution-data files"
    fi

    if [ -d "./blockscout-postgres-data" ] && [ -n "$(ls -A ./blockscout-postgres-data 2>/dev/null)" ]; then
        rm -rf ./blockscout-postgres-data/* || echo "Warning: Could not remove some blockscout-postgres-data files"
    fi

    if [ -d "./mysql-data" ] && [ -n "$(ls -A ./mysql-data 2>/dev/null)" ]; then
        rm -rf ./mysql-data/* || echo "Warning: Could not remove some mysql-data files"
    fi

    if [ -d "./rabbitmq" ] && [ -n "$(ls -A ./rabbitmq 2>/dev/null)" ]; then
        rm -rf ./rabbitmq/* || echo "Warning: Could not remove some rabbitmq files"
    fi

    # Recreate .gitkeep files
    touch ./execution-data/.gitkeep
    touch ./blockscout-postgres-data/.gitkeep
    touch ./mysql-data/.gitkeep
    touch ./rabbitmq/.gitkeep

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Database removed successfully                              "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

remove_configs() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Removing configs...                                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    rm -rf ./deployment/*.json
    rm -rf ./deployment/*.lock
    rm -rf ./configs/*.json

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Configs removed successfully                               "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

remove_env_file() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║ Removing env file...                                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo


    rm -f .env

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "  ✅ Env file removed successfully                              "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

remove_network() {
    if docker network ls | grep -q "surge-network"; then
        docker network rm surge-network
    fi
}

remove_l2_stack
remove_relayers
remove_db
remove_configs
# remove_env_file
remove_network

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "  ✅ Surge removed successfully                                 "
echo "╚══════════════════════════════════════════════════════════════╝"
echo
