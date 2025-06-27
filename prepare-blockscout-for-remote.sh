#!/bin/bash

# Get the machine's IP address using ip command (works on Ubuntu)
MACHINE_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' | head -n1)

# Fallback to hostname -I if ip route doesn't work
if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(hostname -I | awk '{print $1}')
fi

# Final fallback to parsing ip addr output
if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | awk '{print $2}' | cut -d'/' -f1)
fi

if [ -z "$MACHINE_IP" ]; then
    echo "Error: Could not determine machine IP address"
    exit 1
fi

echo "Setting Blockscout to use machine IP: $MACHINE_IP"

# Replace localhost with machine IP for blockscout
sed -i.bak 's/^BLOCKSCOUT_API_HOST=.*/BLOCKSCOUT_API_HOST='$MACHINE_IP'/g' .env

echo "Successfully updated blockscout launcher to use machine IP: $MACHINE_IP"
