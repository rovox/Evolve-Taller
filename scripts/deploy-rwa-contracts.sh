# filepath: scripts/deploy-rwa-contracts.sh
#!/usr/bin/env bash
set -euo pipefail

RED="\033[0;31m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
NC="\033[0m"

printf "🚀 Deploying RWA smart contracts (using Forge)\n"
cd rwa-soberano-evolve || { echo "rwa-soberano-evolve directory not found"; exit 1; }

if ! command -v forge >/dev/null 2>&1; then
  printf "%b❌ forge not found in PATH%b\n" "$RED" "$NC"
  exit 1
fi

# Build contracts
printf "🔨 Building contracts...\n"
forge build

# Set deployment variables
PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}
RPC_URL=${RPC_URL:-http://localhost:8545}

printf "Using RPC: %s\n" "$RPC_URL"
printf "Deploying with Forge script: script/Deploy.s.sol\n"

# Deploy using Forge (with verbose output for debugging)
if ! PRIVATE_KEY=$PRIVATE_KEY forge script script/Deploy.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --legacy \
    -vvv; then
  printf "%b❌ Forge deploy failed (see logs above)%b\n" "$RED" "$NC"
  exit 1
fi

# Verify deployed-addresses.env was created
if [ ! -f deployed-addresses.env ]; then
  printf "%b❌ CRITICAL: deployed-addresses.env not generated%b\n" "$RED" "$NC"
  printf "%bChecking broadcast directory for deployment artifacts...%b\n" "$YELLOW" "$NC"
  
  # Try to extract addresses from broadcast logs
  BROADCAST_DIR="broadcast/Deploy.s.sol/31337"
  if [ -d "$BROADCAST_DIR" ]; then
    printf "Found broadcast directory, attempting to parse deployment...\n"
    LATEST_RUN=$(ls -t "$BROADCAST_DIR"/run-*.json | head -1)
    
    if [ -f "$LATEST_RUN" ]; then
      printf "Parsing deployment from: %s\n" "$LATEST_RUN"
      
      # Extract contract addresses (adjust jq query based on Deploy.s.sol structure)
      jq -r '.transactions[] | select(.transactionType == "CREATE") | 
        "\(.contractName)=\(.contractAddress)"' "$LATEST_RUN" > deployed-addresses.env || true
      
      if [ -s deployed-addresses.env ]; then
        printf "%b⚠️  Manually extracted addresses from broadcast logs%b\n" "$YELLOW" "$NC"
      else
        printf "%b❌ Could not extract addresses from broadcast logs%b\n" "$RED" "$NC"
        printf "%bSuggestion:%b Update Deploy.s.sol to write deployed-addresses.env using vm.writeFile()%b\n" "$YELLOW" "$NC"
        exit 1
      fi
    fi
  else
    printf "%b❌ No broadcast directory found%b\n" "$RED" "$NC"
    exit 1
  fi
fi

printf "%b✅ Contracts deployed. Addresses:%b\n" "$GREEN" "$NC"
cat deployed-addresses.env

# Validate addresses format
if ! grep -qE '^[A-Z_]+=(0x[a-fA-F0-9]{40})$' deployed-addresses.env; then
  printf "%b⚠️  Warning: deployed-addresses.env may have incorrect format%b\n" "$YELLOW" "$NC"
fi