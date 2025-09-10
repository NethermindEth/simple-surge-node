#!/bin/bash

set -e

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Starting to setup RISC0 verifier...                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

./script/layer1/surge/setup_risc0_verifier.sh

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ RISC0 verifier setup successfully                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

touch /deployment/risc0_verifier_setup.lock
