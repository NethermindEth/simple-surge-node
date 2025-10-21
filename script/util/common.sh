#!/bin/bash

# Common utility functions for Surge devnet scripts

set -o pipefail

print_success() {
    echo "[SUCCESS] $1"
}

print_error() {
    echo "[ERROR] $1"
}

print_info() {
    echo "[INFO] $1"
}

wait_for_rpc() {
    local rpc_url="$1"
    local max_retries="${2:-10}"
    local retry_delay="${3:-10}"

    print_info "Testing RPC endpoint at $rpc_url"
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if curl -f "$rpc_url" -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null; then
            echo
            print_success "RPC is responding"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -eq $max_retries ]; then
                echo
                print_error "RPC failed to respond after $max_retries retries"
                return 1
            fi
            print_info "Retry $retry_count/$max_retries - waiting ${retry_delay}s..."
            sleep "$retry_delay"
        fi
    done
}

deploy_l1() {
    local l1_package_dir="${1:-../surge-ethereum-package}"
    local environment="${2:-local}"
    local mode="${3:-silence}"

    echo "Deploying L1 Devnet"

    if [ ! -d "$l1_package_dir" ]; then
        print_error "surge-ethereum-package directory not found at $l1_package_dir"
        print_info "Current directory: $(pwd)"
        ls -la ../
        return 1
    fi

    print_info "Running L1 deployment from $l1_package_dir"
    pushd "$l1_package_dir" > /dev/null

    if ./deploy-surge-devnet-l1.sh --environment "$environment" --mode "$mode"; then
        popd > /dev/null
        print_success "L1 deployment completed"
        return 0
    else
        popd > /dev/null
        print_error "L1 deployment failed"
        return 1
    fi
}

configure_env_no_provers() {
    local env_file="${1:-.env.devnet}"

    echo "Configuring environment for no-prover testing"
    print_info "Disabling provers in $env_file"

    if [ ! -f "$env_file" ]; then
        print_error "$env_file not found"
        return 1
    fi

    sed -i 's/^ENABLE_PROVER=true/ENABLE_PROVER=false/' "$env_file"
    print_success "Provers disabled"
    return 0
}
