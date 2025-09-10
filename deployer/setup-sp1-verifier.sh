#!/bin/bash

set -e

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Starting to setup SP1 verifier...                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

./script/layer1/surge/setup_sp1_verifier.sh

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ SP1 verifier setup successfully                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

touch /deployment/sp1_verifier_setup.lock
