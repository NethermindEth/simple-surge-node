#!/bin/bash

set -e

echo "=========================================="
echo "Starting Local Devnet Health Check"
echo "=========================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Step 1: Clean up any existing deployment
echo "=========================================="
echo "Step 1: Cleanup existing deployment"
echo "=========================================="
print_info "Running surge-remover.sh --devnet-non-interactive"
if ./surge-remover.sh --devnet-non-interactive; then
    print_success "Cleanup completed"
else
    print_error "Cleanup failed"
    exit 1
fi
echo

# Step 2: Ensure .env file exists
echo "=========================================="
echo "Step 2: Prepare environment"
echo "=========================================="
if [ ! -f .env ]; then
    print_info "Copying .env.devnet to .env"
    cp .env.devnet .env
    print_success ".env file created"
else
    print_info ".env file already exists"
fi
echo

# Step 3: Deploy protocol
echo "=========================================="
echo "Step 3: Deploy protocol (L1 contracts)"
echo "=========================================="
print_info "Running surge-protocol-deployer.sh --devnet-non-interactive"
if ./surge-protocol-deployer.sh --devnet-non-interactive; then
    print_success "Protocol deployment completed"
else
    print_error "Protocol deployment failed"
    exit 1
fi
echo

# Step 4: Verify protocol deployment artifacts
echo "=========================================="
echo "Step 4: Verify protocol deployment"
echo "=========================================="
if [ ! -f "deployment/deploy_l1.json" ]; then
    print_error "deploy_l1.json not found"
    exit 1
else
    print_success "deploy_l1.json found"
fi

if [ ! -f "deployment/proposer_wrappers.json" ]; then
    print_error "proposer_wrappers.json not found"
    exit 1
else
    print_success "proposer_wrappers.json found"
fi
echo

# Step 5: Deploy stack
echo "=========================================="
echo "Step 5: Deploy L2 stack"
echo "=========================================="
print_info "Running surge-stack-deployer.sh --devnet-non-interactive"
if ./surge-stack-deployer.sh --devnet-non-interactive; then
    print_success "Stack deployment completed"
else
    print_error "Stack deployment failed"
    exit 1
fi
echo

# Step 6: Verify services are running
echo "=========================================="
echo "Step 6: Verify services"
echo "=========================================="
print_info "Checking running containers"
docker compose ps
echo

print_info "Checking critical containers are healthy..."
# Check L2 execution client container
if docker compose ps | grep "l2-nethermind-execution-client" | grep -q "(healthy)"; then
    print_success "L2 execution client container is healthy"
else
    print_error "L2 execution client container is not healthy"
    exit 1
fi

# Check other critical containers are running
CRITICAL_CONTAINERS=("l2-taiko-consensus-client" "l2-taiko-proposer-client" "relayer-l1-indexer" "relayer-l2-indexer")
for container in "${CRITICAL_CONTAINERS[@]}"; do
    if docker compose ps | grep "$container" | grep -q "Up"; then
        print_success "$container is running"
    else
        print_error "$container is not running"
        exit 1
    fi
done
echo

# Step 7: Health check L2 RPC endpoints
echo "=========================================="
echo "Step 7: Health check L2 RPC endpoints"
echo "=========================================="
print_info "Waiting 30 seconds for services to stabilize..."
sleep 30

print_info "Testing L2 RPC endpoint at http://localhost:8547"
if curl -f http://localhost:8547 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null; then
    echo
    print_success "L2 execution client RPC is responding"
else
    echo
    print_error "L2 execution client RPC health check failed"
    exit 1
fi

print_info "Testing L2 WebSocket endpoint at ws://localhost:8548"
if curl -f http://localhost:8548 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null; then
    echo
    print_success "L2 WebSocket endpoint is responding"
else
    echo
    print_error "L2 WebSocket endpoint health check failed"
    exit 1
fi
echo

# Step 8: Optional - Check container logs for errors
echo "=========================================="
echo "Step 8: Check for errors in logs"
echo "=========================================="
print_info "Checking for errors in container logs (last 50 lines)"
if docker compose logs --tail=50 | grep -i "error\|fatal\|panic" | grep -v "error_code" | head -20; then
    print_info "Found some errors in logs (review above)"
else
    print_success "No critical errors found in recent logs"
fi
echo

# Final summary
echo "=========================================="
echo "Health Check Summary"
echo "=========================================="
print_success "All health checks passed!"
echo
print_info "Services are running. You can now:"
echo "  - Access L2 RPC: http://localhost:8547"
echo "  - Access L2 Blockscout: http://localhost:3000"
echo "  - Access L1 RPC: http://localhost:32003"
echo "  - View logs: docker compose logs -f"
echo
print_info "To clean up when done:"
echo "  ./surge-remover.sh --devnet-non-interactive"
echo
