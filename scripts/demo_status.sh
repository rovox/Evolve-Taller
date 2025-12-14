#!/usr/bin/env bash
# Quick Demo Script - Mostrar todo el sistema funcionando

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  🚀 EVOLVE DEPLOYMENT - DEMO RÁPIDO${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${RESET}"
echo ""

# 1. Verificar infraestructura
echo -e "${BLUE}📊 1. Verificando Infraestructura...${RESET}"
echo ""

if docker ps | grep -q "celestia-node.*healthy"; then
    echo -e "  ${GREEN}✅ Celestia DA:${RESET} Running (healthy)"
else
    echo -e "  ⚠️  Celestia DA: Not healthy"
fi

if docker ps | grep -q "ev-reth-sequencer"; then
    echo -e "  ${GREEN}✅ EVM Sequencer:${RESET} Running"
else
    echo -e "  ⚠️  EVM Sequencer: Not running"
fi

if docker ps | grep -q "single-sequencer"; then
    echo -e "  ${GREEN}✅ Single Sequencer:${RESET} Running"
else
    echo -e "  ⚠️  Single Sequencer: Not running"
fi

echo ""

# 2. Verificar RPC endpoints
echo -e "${BLUE}🌐 2. Verificando RPC Endpoints...${RESET}"
echo ""

CHAIN_ID=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  http://localhost:8545 | jq -r '.result')
echo -e "  ${GREEN}✅ EVM RPC:${RESET} http://localhost:8545 (Chain ID: $CHAIN_ID)"

CELESTIA_HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"header.LocalHead"}' \
  http://localhost:26658 | jq -r '.result.header.height')
echo -e "  ${GREEN}✅ Celestia RPC:${RESET} http://localhost:26658 (Height: $CELESTIA_HEIGHT)"

echo ""

# 3. Verificar contratos desplegados
echo -e "${BLUE}📝 3. Verificando Contratos Desplegados...${RESET}"
echo ""

if [[ -f "frontend/deployment_info.json" ]]; then
    ROSCA_ADDR=$(jq -r '.contracts.ROSCA.address // "not found"' frontend/deployment_info.json)
    GREETER_ADDR=$(jq -r '.contracts.Greeter.address // "not found"' frontend/deployment_info.json)
    
    if [[ "$ROSCA_ADDR" != "not found" ]]; then
        GROUP_COUNT=$(cast call "$ROSCA_ADDR" "groupCounter()(uint256)" --rpc-url http://localhost:8545)
        echo -e "  ${GREEN}✅ ROSCA:${RESET} $ROSCA_ADDR"
        echo -e "     Groups created: $GROUP_COUNT"
    fi
    
    if [[ "$GREETER_ADDR" != "not found" ]]; then
        GREETING=$(cast call "$GREETER_ADDR" "greeting()(string)" --rpc-url http://localhost:8545)
        echo -e "  ${GREEN}✅ Greeter:${RESET} $GREETER_ADDR"
        echo -e "     Current greeting: $GREETING"
    fi
else
    echo -e "  ${YELLOW}⚠️  No deployment_info.json found. Run 'make verify-e2e' first${RESET}"
fi

echo ""

# 4. Verificar publicación a Celestia
echo -e "${BLUE}📡 4. Verificando Publicación a Celestia DA...${RESET}"
echo ""

DA_SUBMISSIONS=$(docker logs single-sequencer 2>&1 | grep -c "itemType=data" 2>/dev/null || echo "0")
LAST_DA=$(docker logs single-sequencer 2>&1 | grep "itemType=data" | tail -1 2>/dev/null || echo "No data submissions yet")

# Remove newlines from count
DA_SUBMISSIONS=$(echo "$DA_SUBMISSIONS" | tr -d '\n' | grep -o '[0-9]*' || echo "0")

if [[ "${DA_SUBMISSIONS:-0}" -gt 0 ]]; then
    echo -e "  ${GREEN}✅ Data submissions:${RESET} $DA_SUBMISSIONS batches publicados"
    echo -e "  ${GREEN}✅ Último batch:${RESET}"
    echo "     $LAST_DA"
else
    echo -e "  ${YELLOW}⚠️  No data submissions yet (transactions may still be pending)${RESET}"
fi

echo ""

# 5. Frontend status
echo -e "${BLUE}🌐 5. Frontend Status...${RESET}"
echo ""

if curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Frontend:${RESET} http://localhost:8000"
    echo -e "  ${GREEN}✅ Deployment Info:${RESET} http://localhost:8000/deployment_info.json"
else
    echo -e "  ${YELLOW}⚠️  Frontend not running. Start with:${RESET}"
    echo "     cd frontend && python -m http.server 8000"
fi

echo ""

# 6. Enlaces útiles
echo -e "${BLUE}🔗 6. Enlaces Útiles...${RESET}"
echo ""
echo "  📊 Celenium Explorer: https://mocha.celenium.io"
echo "  📚 Documentación: INTEGRATION_TEST_RESULTS.md"
echo "  🧪 Ejecutar E2E: make verify-e2e"
echo ""

# 7. Comandos rápidos
echo -e "${BLUE}⚡ 7. Comandos Rápidos...${RESET}"
echo ""
echo "  # Ver logs del sequencer:"
echo "  docker logs single-sequencer -f | grep -E 'itemType|submitted'"
echo ""
echo "  # Re-ejecutar pruebas E2E:"
echo "  export PRIVATE_KEY=0xb29f0756244fd1a7a925993dfe81b93716840f57324c8af79f2e3020219c549d"
echo "  make verify-e2e"
echo ""
echo "  # Verificar estado de contratos:"
echo "  cast call \$ROSCA_ADDRESS \"groupCounter()(uint256)\" --rpc-url http://localhost:8545"
echo ""

echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✅ Demo Status Check Completado${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${RESET}"
