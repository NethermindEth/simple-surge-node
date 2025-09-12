#!/bin/sh

set -e

prepare_sgx_assets() {
    echo "Preparing SGX assets..."
    mkdir -p /app/test/sgx-assets

    echo "Downloading TCB info..."
    curl ${TCB_LINK} -o /app/test/sgx-assets/temp.json 

    echo "Downloading QE identity..."
    curl ${QE_IDENTITY_LINK} -o /app/test/sgx-assets/qe_identity.json 

    echo "Converting TCB info to lowercase..."
    jq '.tcbInfo.fmspc |= ascii_downcase' /app/test/sgx-assets/temp.json > /app/test/sgx-assets/tcb_info.json 

    echo "SGX assets prepared successfully"
}

prepare_tdx_assets() {
    echo "Preparing TDX assets..."
    mkdir -p /app/test/tdx-assets

    echo "Downloading TCB info..."
    TCB_RESPONSE=$(curl -s -D - -X GET "${TDX_TCB_LINK}")
    echo "$TCB_RESPONSE" | sed '1,/^\r$/d' > /app/test/tdx-assets/tcb.json
    jq '.tcbInfo.fmspc |= ascii_downcase' /app/test/tdx-assets/tcb.json > /app/test/tdx-assets/temp.json && mv /app/test/tdx-assets/temp.json /app/test/tdx-assets/tcb.json

    url_decode() {
        local url_encoded="${1//+/ }"
        printf '%b' "${url_encoded//%/\\x}"
    }

    echo "Decoding TCB cert chain..."
    TCB_CERT_CHAIN=$(echo "$TCB_RESPONSE" | grep -i "^Tcb-Info-Issuer-Chain:" | cut -d' ' -f2- | tr -d '\r\n')
    TCB_CERT_CHAIN_DECODED=$(url_decode "$TCB_CERT_CHAIN")
    TCB_SIGNING_CERT=$(echo "$TCB_CERT_CHAIN_DECODED" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | sed -n '1,/-----END CERTIFICATE-----/p')
    echo "$TCB_SIGNING_CERT" > /app/test/tdx-assets/tdx_tcb_signing_cert.pem

    echo "Converting TCB signing cert to DER..."
    openssl x509 -in /app/test/tdx-assets/tdx_tcb_signing_cert.pem -outform DER -out /app/test/tdx-assets/tdx_tcb_signing_cert.der
    xxd -p -c 1000000 /app/test/tdx-assets/tdx_tcb_signing_cert.der > /app/test/tdx-assets/tdx_tcb_signing_cert.hex

    echo "Downloading QE identity..."
    curl -s -X GET "$TDX_QE_IDENTITY_LINK" > /app/test/tdx-assets/qe_identity.json

    echo "TDX assets prepared successfully"
}

deploy_l1() {
    export FORK_URL=${L1_ENDPOINT_HTTP}

    if [ "$SHOULD_SETUP_VERIFIERS" = "true" ]; then
        prepare_sgx_assets
        prepare_tdx_assets
    fi
    
    echo "Deploying Surge L1 SCs..."
    ./script/layer1/surge/deploy_surge_l1.sh

    echo "Copying deployment results to /deployment..."

    cp /app/deployments/deploy_l1.json /deployment/deploy_l1.json
    
    if [ "$SHOULD_SETUP_VERIFIERS" = "true" ]; then
        cp /app/deployments/sgx_instances.json /deployment/sgx_instances.json
        cp /app/deployments/tdx_instances.json /deployment/tdx_instances.json
    fi

    echo "Deployment completed successfully"
}

deploy_l1
