#!/usr/bin/env bash
# verify-setup.sh - Quick verification that all integration files are in place

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Verifying RWA Integration Setup"
echo "==================================="
echo ""

ERRORS=0

# Check Tiltfile modifications
echo -n "Checking Tiltfile modifications... "
if grep -q "deploy-rwa-contracts" Tiltfile && grep -q "rwa-integration-test" Tiltfile; then
    if grep -q "blockscout-start" Tiltfile; then
        echo -e "${RED}FAILED${NC}"
        echo "  ⚠️  Blockscout resources still present in Tiltfile"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}OK${NC}"
    fi
else
    echo -e "${RED}FAILED${NC}"
    echo "  ⚠️  Missing deploy-rwa-contracts or rwa-integration-test in Tiltfile"
    ERRORS=$((ERRORS + 1))
fi

# Check DeployToRollup.s.sol
echo -n "Checking DeployToRollup.s.sol... "
if [ -f "rwa-soberano-evolve/script/DeployToRollup.s.sol" ]; then
    if grep -q "DocumentRegistry" rwa-soberano-evolve/script/DeployToRollup.s.sol && \
       grep -q "AssetToken" rwa-soberano-evolve/script/DeployToRollup.s.sol && \
       grep -q "RWASovereingRollup" rwa-soberano-evolve/script/DeployToRollup.s.sol; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo "  ⚠️  DeployToRollup.s.sol missing required contract deployments"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}FAILED${NC}"
    echo "  ⚠️  DeployToRollup.s.sol not found"
    ERRORS=$((ERRORS + 1))
fi

# Check test-rwa-integration.sh
echo -n "Checking test-rwa-integration.sh... "
if [ -f "test-rwa-integration.sh" ]; then
    if [ -x "test-rwa-integration.sh" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
        echo "  ⚠️  test-rwa-integration.sh exists but is not executable"
        echo "  Run: chmod +x test-rwa-integration.sh"
    fi
else
    echo -e "${RED}FAILED${NC}"
    echo "  ⚠️  test-rwa-integration.sh not found"
    ERRORS=$((ERRORS + 1))
fi

# Check documentation files
echo -n "Checking documentation... "
DOC_COUNT=0
[ -f "RWA-INTEGRATION-GUIDE.md" ] && DOC_COUNT=$((DOC_COUNT + 1))
[ -f "INTEGRATION-FLOW.txt" ] && DOC_COUNT=$((DOC_COUNT + 1))

if [ $DOC_COUNT -eq 2 ]; then
    echo -e "${GREEN}OK${NC} (2 files)"
elif [ $DOC_COUNT -eq 1 ]; then
    echo -e "${YELLOW}PARTIAL${NC} (1 file)"
else
    echo -e "${RED}FAILED${NC}"
    echo "  ⚠️  Documentation files not found"
    ERRORS=$((ERRORS + 1))
fi

# Check source contracts exist
echo -n "Checking RWA source contracts... "
CONTRACT_COUNT=0
[ -f "rwa-soberano-evolve/src/DocumentRegistry.sol" ] && CONTRACT_COUNT=$((CONTRACT_COUNT + 1))
[ -f "rwa-soberano-evolve/src/AssetToken.sol" ] && CONTRACT_COUNT=$((CONTRACT_COUNT + 1))
[ -f "rwa-soberano-evolve/src/RWASovereingRollup.sol" ] && CONTRACT_COUNT=$((CONTRACT_COUNT + 1))

if [ $CONTRACT_COUNT -eq 3 ]; then
    echo -e "${GREEN}OK${NC} (3 contracts)"
elif [ $CONTRACT_COUNT -gt 0 ]; then
    echo -e "${YELLOW}PARTIAL${NC} ($CONTRACT_COUNT contracts)"
    echo "  ⚠️  Some RWA contracts missing"
else
    echo -e "${RED}FAILED${NC}"
    echo "  ⚠️  RWA source contracts not found"
    ERRORS=$((ERRORS + 1))
fi

# Check Foundry installation
echo -n "Checking Foundry installation... "
if command -v forge >/dev/null 2>&1; then
    FORGE_VERSION=$(forge --version | head -n1)
    echo -e "${GREEN}OK${NC} ($FORGE_VERSION)"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "  ⚠️  forge not found in PATH"
    echo "  Install: curl -L https://foundry.paradigm.xyz | bash && foundryup"
fi

# Check cast installation
echo -n "Checking cast installation... "
if command -v cast >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "  ⚠️  cast not found (needed for integration tests)"
fi

echo ""
echo "==================================="

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Ready to deploy. Run:"
    echo "  tilt up"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the errors above before deploying."
    echo ""
    exit 1
fi
