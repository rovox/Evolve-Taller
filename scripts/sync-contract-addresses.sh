#!/usr/bin/env bash
# sync-contract-addresses.sh - Sync deployed contract addresses to frontend

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACTS_DIR="$REPO_ROOT/rwa-soberano-evolve"
FRONTEND_DIR="$REPO_ROOT/frontend"
ADDRESSES_FILE="$CONTRACTS_DIR/deployed-addresses.env"

if [ ! -f "$ADDRESSES_FILE" ]; then
    echo "❌ deployed-addresses.env not found at: $ADDRESSES_FILE"
    echo "Run deployment first: tilt up or forge script ..."
    exit 1
fi

echo "📦 Syncing contract addresses to frontend..."

# Copy to frontend public directory so it can be fetched at runtime
mkdir -p "$FRONTEND_DIR/public"
cp "$ADDRESSES_FILE" "$FRONTEND_DIR/public/deployed-addresses.env"

# Also create a .env.local for Vite
source "$ADDRESSES_FILE"

cat > "$FRONTEND_DIR/.env.local" <<EOF
# Auto-generated contract addresses - DO NOT EDIT MANUALLY
VITE_REGISTRY_ADDRESS=${REGISTRY_ADDRESS}
VITE_TOKEN_ADDRESS=${TOKEN_ADDRESS}
VITE_RWA_ADDRESS=${RWA_ADDRESS}
VITE_RPC_URL=http://localhost:8545
VITE_CHAIN_ID=1234
EOF

echo "✅ Contract addresses synced!"
echo "   Registry: ${REGISTRY_ADDRESS}"
echo "   Token:    ${TOKEN_ADDRESS}"
echo "   RWA:      ${RWA_ADDRESS}"
echo ""
echo "Frontend can now read addresses from:"
echo "  - /deployed-addresses.env (runtime)"
echo "  - import.meta.env.VITE_*_ADDRESS (build time)"
