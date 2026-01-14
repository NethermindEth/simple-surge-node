# This script deploys the Surge protocol on L1
set -e

# echo "Adding operators to whitelist..."
# cast send $SHASTA_PRECONF_WHITELIST "addOperator(address)" \
#     $OPERATOR_PUBLIC_KEY \
#     --rpc-url $L1_ENDPOINT_HTTP \
#     --private-key $PRIVATE_KEY \
#     --confirmations 1

# Get the Shasta Inbox address from deployment
SHASTA_INBOX=$(jq -r '.surge_inbox' /deployment/deploy_l1.json)

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ Surge Shasta Fork Activation                                 ║"
echo "║ Shasta Inbox: $SHASTA_INBOX                                  ║"
echo "║ Fork Time: $SHASTA_TIMESTAMP                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

# Check if already activated
echo "Checking activation status..."
ACTIVATION_TIME=$(cast call $SHASTA_INBOX "activationTimestamp()" --rpc-url $L1_ENDPOINT_HTTP)
if [ "$ACTIVATION_TIME" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
  echo "✅ Already activated at timestamp: $ACTIVATION_TIME"
  exit 0
fi

# Polling loop - wait for fork time
POLL_INTERVAL=5
echo "Waiting for fork time to be reached..."
echo ""

while true; do
  # Get current L1 timestamp
  CURRENT_TIME=$(cast block latest --rpc-url $L1_ENDPOINT_HTTP -f timestamp)
  CURRENT_BLOCK=$(cast block latest --rpc-url $L1_ENDPOINT_HTTP -f number)
  
  echo "[$(date +'%H:%M:%S')] Block: $CURRENT_BLOCK | Timestamp: $CURRENT_TIME | Fork: $SHASTA_TIMESTAMP"
  
  # Check if fork time reached
  FORK_TIMESTAMP=$((SHASTA_TIMESTAMP))  # Convert hex to decimal
  if [ $CURRENT_TIME -ge $FORK_TIMESTAMP ]; then
    echo ""
    echo "🚀 Fork time reached! Activating..."
    break
  fi
  
  # Calculate time remaining
  TIME_REMAINING=$((FORK_TIMESTAMP - CURRENT_TIME))
  echo "   ⏳ Waiting... ($TIME_REMAINING seconds remaining)"
  
  # Wait before next check
  sleep $POLL_INTERVAL
done

# Get latest L2 block hash
echo ""
echo "Getting latest L2 block hash..."
L2_BLOCK_HASH=$(cast block latest --rpc-url $L2_ENDPOINT_HTTP -f hash)
echo "L2 Block Hash: $L2_BLOCK_HASH"

# Check L2 block is valid
if [ -z "$L2_BLOCK_HASH" ] || [ "$L2_BLOCK_HASH" = "null" ]; then
  echo "❌ Error: Could not get L2 block hash"
  exit 1
fi

# Activate the fork
echo ""
echo "Sending activation transaction..."
cast send $SHASTA_INBOX \
  "activate(bytes32)" \
  $L2_BLOCK_HASH \
  --rpc-url $L1_ENDPOINT_HTTP \
  --private-key $PRIVATE_KEY

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Fork activation transaction sent successfully!"
  
  # Verify activation
  sleep 2
  ACTIVATION_TIME=$(cast call $SHASTA_INBOX "activationTimestamp()(uint48)" --rpc-url $L1_ENDPOINT_HTTP)
  echo "✅ Activation confirmed at timestamp: $ACTIVATION_TIME"
else
  echo ""
  echo "❌ Fork activation failed!"
  exit 1
fi

echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║ ✅ Surge Shasta Fork Activation completed successfully       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo
