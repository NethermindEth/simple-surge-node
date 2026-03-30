#!/bin/bash

set -e

echo
echo "============================================="
echo " Starting to setup ZISK..."
echo "============================================="
echo

cast send ${ZISK_VERIFIER_ADDRESS} \
  "setProgramTrusted(bytes32,bool)" \
  ${ZISK_BATCH_VKEY} true \
  --private-key ${PRIVATE_KEY} \
  --rpc-url ${L1_ENDPOINT_HTTP}

echo
echo "============================================="
echo " ✅ ZISK setup successfully"
echo "============================================="
echo

touch /deployment/zisk_setup.lock
