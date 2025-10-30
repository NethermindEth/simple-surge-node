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

mkdir -p /app/test/azure-tdx-assets

url_decode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

echo "Downloading TCB info from $AZURE_TDX_TCB_LINK"
TCB_RESPONSE=$(curl -s -D - -X GET "${AZURE_TDX_TCB_LINK}")

echo "Saving TCB info to /app/test/azure-tdx-assets/tcb.json"
echo "$TCB_RESPONSE" | sed '1,/^\r$/d' > /app/test/azure-tdx-assets/tcb_full.json
echo "Minifying TCB JSON..."
jq -c . /app/test/azure-tdx-assets/tcb_full.json > /app/test/azure-tdx-assets/tcb.json

echo "Extracting TCB cert chain..."
TCB_CERT_CHAIN=$(echo "$TCB_RESPONSE" | grep -i "^Tcb-Info-Issuer-Chain:" | cut -d' ' -f2- | tr -d '\r\n')

if [ -z "$TCB_CERT_CHAIN" ]; then
    echo "Error: Could not find Tcb-Info-Issuer-Chain header"
    exit 1
fi

TCB_CERT_CHAIN_DECODED=$(url_decode "$TCB_CERT_CHAIN")

echo "Extracting TCB certificates from chain..."
echo "$TCB_CERT_CHAIN_DECODED" | awk '
    /-----BEGIN CERTIFICATE-----/ {
        cert_num++
        in_cert=1
    }
    in_cert {
        cert[cert_num] = cert[cert_num] $0 "\n"
    }
    /-----END CERTIFICATE-----/ {
        in_cert=0
    }
    END {
        for (i=1; i<=cert_num; i++) {
            print cert[i] > "/app/test/azure-tdx-assets/temp_tcb_cert_" i ".pem"
        }
        print "Found " cert_num " TCB certificates"
    }
'

if [ -f "/app/test/azure-tdx-assets/temp_tcb_cert_1.pem" ]; then
    echo "Processing TCB Signing Certificate..."
    mv /app/test/azure-tdx-assets/temp_tcb_cert_1.pem /app/test/azure-tdx-assets/tdx_tcb_signing_cert.pem
    openssl x509 -in /app/test/azure-tdx-assets/tdx_tcb_signing_cert.pem -outform DER -out /app/test/azure-tdx-assets/tdx_tcb_signing_cert.der
    echo -n "0x" > /app/test/azure-tdx-assets/tdx_tcb_signing_cert.hex
    xxd -p -c 1000000 /app/test/azure-tdx-assets/tdx_tcb_signing_cert.der | tr -d '\n' >> /app/test/azure-tdx-assets/tdx_tcb_signing_cert.hex
fi

if [ -f "/app/test/azure-tdx-assets/temp_tcb_cert_2.pem" ]; then
    echo "Processing TCB Root CA Certificate..."
    mv /app/test/azure-tdx-assets/temp_tcb_cert_2.pem /app/test/azure-tdx-assets/tdx_tcb_root_cert.pem
    openssl x509 -in /app/test/azure-tdx-assets/tdx_tcb_root_cert.pem -outform DER -out /app/test/azure-tdx-assets/tdx_tcb_root_cert.der
    echo -n "0x" > /app/test/azure-tdx-assets/tdx_tcb_root_cert.hex
    xxd -p -c 1000000 /app/test/azure-tdx-assets/tdx_tcb_root_cert.der | tr -d '\n' >> /app/test/azure-tdx-assets/tdx_tcb_root_cert.hex
fi

rm -f /app/test/azure-tdx-assets/temp_tcb_cert_*.pem

echo "Downloading QE identity..."
curl -s "${AZURE_TDX_QE_IDENTITY_LINK}" -o /app/test/azure-tdx-assets/qe_identity_full.json
echo "Minifying QE identity JSON..."
jq -c . /app/test/azure-tdx-assets/qe_identity_full.json > /app/test/azure-tdx-assets/qe_identity.json

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

./script/layer1/surge/setup_azure_tdx_verifier.sh

cp /app/deployments/azure_tdx_instances.json /deployment/azure_tdx_instances.json

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Azure TDX verifier setup successfully                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

touch /deployment/azure_tdx_verifier_setup.lock
