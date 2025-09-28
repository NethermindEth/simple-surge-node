#!/bin/bash

set -e

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Preparing TDX assets...                                      ║"
echo "║ Downloading TCB info...                                      ║"
echo "║ Decoding TCB cert chain...                                   ║"
echo "║ Downloading QE identity...                                   ║"
echo "║ Converting TCB info to lowercase...                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

mkdir -p /app/test/tdx-assets

url_decode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

echo "Downloading TCB info from $TDX_TCB_LINK"
TCB_RESPONSE=$(curl -s -D - -X GET "${TDX_TCB_LINK}")

echo "Saving TCB info to /app/test/tdx-assets/tcb.json"
echo "$TCB_RESPONSE" | sed '1,/^\r$/d' > /app/test/tdx-assets/tcb.json
jq '.tcbInfo.fmspc |= ascii_downcase' /app/test/tdx-assets/tcb.json > /app/test/tdx-assets/temp.json && mv /app/test/tdx-assets/temp.json /app/test/tdx-assets/tcb.json

echo "Decoding TCB cert chain..."
TCB_CERT_CHAIN=$(echo "$TCB_RESPONSE" | grep -i "^Tcb-Info-Issuer-Chain:" | cut -d' ' -f2- | tr -d '\r\n')
TCB_CERT_CHAIN_DECODED=$(url_decode "$TCB_CERT_CHAIN")
TCB_SIGNING_CERT=$(echo "$TCB_CERT_CHAIN_DECODED" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | sed -n '1,/-----END CERTIFICATE-----/p')
echo "$TCB_SIGNING_CERT" > /app/test/tdx-assets/tdx_tcb_signing_cert.pem

echo "Converting TCB signing cert to DER..."
openssl x509 -in /app/test/tdx-assets/tdx_tcb_signing_cert.pem -outform DER -out /app/test/tdx-assets/tdx_tcb_signing_cert.der
echo -n "0x" > /app/test/tdx-assets/tdx_tcb_signing_cert.hex
xxd -p -c 1000000 /app/test/tdx-assets/tdx_tcb_signing_cert.der | tr -d '\n' >> /app/test/tdx-assets/tdx_tcb_signing_cert.hex

echo "Downloading QE identity..."
curl ${TDX_QE_IDENTITY_LINK} -o /app/test/tdx-assets/qe_identity.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ TDX assets prepared successfully                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Starting to setup TDX verifier...                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

./script/layer1/surge/setup_tdx_verifier.sh

cp /app/deployments/tdx_instances.json /deployment/tdx_instances.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ TDX verifier setup successfully                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

touch /deployment/tdx_verifier_setup.lock
