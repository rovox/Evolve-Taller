#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📏 Verifying Smart Contract Sizes"
echo "=================================="
echo ""

cd rwa-soberano-evolve || exit 1

# Build contracts
echo "Building contracts..."
forge build --sizes 2>&1 | tee /tmp/contract_sizes.txt

# Check RWAToken size
echo ""
echo "Checking RWAToken bytecode size..."

SIZE_LIMIT=24576
RWA_SIZE=$(grep -E "RWAToken\s+" /tmp/contract_sizes.txt | awk '{print $NF}' | tr -d ',' || echo "0")

if [ "$RWA_SIZE" -gt "$SIZE_LIMIT" ]; then
    echo -e "${RED}❌ RWAToken size: $RWA_SIZE bytes (exceeds limit of $SIZE_LIMIT)${NC}"
    exit 1
elif [ "$RWA_SIZE" -gt 22000 ]; then
    echo -e "${YELLOW}⚠️  RWAToken size: $RWA_SIZE bytes (approaching limit)${NC}"
else
    echo -e "${GREEN}✅ RWAToken size: $RWA_SIZE bytes (within safe limits)${NC}"
fi

echo ""
echo "All contract sizes:"
grep -E "(RWAToken|Core|Minting|Sales|Admin|Queries)" /tmp/contract_sizes.txt || true

echo ""
echo "=================================="
