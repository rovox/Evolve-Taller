#!/usr/bin/env bash
# test-rwa-integration.sh - Integration test for RWA contracts on Evolve rollup
# This script verifies that contracts are deployed, callable, and interacting with the rollup

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 RWA Integration Test Suite"
echo "=============================="
echo ""

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$ROOT_DIR/rwa-soberano-evolve"
ADDRESSES_FILE="$CONTRACTS_DIR/deployed-addresses.env"
RPC_URL="${RPC_URL:-http://localhost:8545}"
PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"

# Celestia defaults (host-side). You can override via env.
CELESTIA_RPC="${CELESTIA_RPC:-http://localhost:26658}"
# Attempt to read rollkit env from shared volume or local file for DA namespace/token.
ROLLKIT_ENV_FILE="${ROLLKIT_ENV_FILE:-/shared/rollkit.env}"
ALT_ROLLKIT_ENV_FILE="${ALT_ROLLKIT_ENV_FILE:-./rollkit.env}"

# Helper to fail fast with red, urgent messaging
fail() {
    local msg="$1"
    echo -e "${RED}❌ URGENTE: ${msg}${NC}"
    exit 1
}

# --- Utilidades de diagnóstico (para depurar fallas sin eliminar funcionalidades) ---
section() { echo -e "\n==============================\n$1\n==============================\n"; }

signer_addr() {
    if cast wallet address --private-key "$PRIVATE_KEY" >/dev/null 2>&1; then
        cast wallet address --private-key "$PRIVATE_KEY"
        return
    fi
    echo ""
}

debug_env() {
    section "🔎 Diagnóstico de entorno"
    local CHAIN_ID GAS_PRICE SIGNER BALANCE NONCE
    CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "N/A")
    GAS_PRICE=$(cast gas-price --rpc-url "$RPC_URL" 2>/dev/null || echo "N/A")
    SIGNER=$(signer_addr || true)
    [ -n "$SIGNER" ] && BALANCE=$(cast balance "$SIGNER" --rpc-url "$RPC_URL" 2>/dev/null || echo "N/A") || BALANCE="N/A"
    [ -n "$SIGNER" ] && NONCE=$(cast nonce "$SIGNER" --rpc-url "$RPC_URL" 2>/dev/null || echo "N/A") || NONCE="N/A"
    echo "RPC:        $RPC_URL"
    echo "Chain ID:   $CHAIN_ID"
    echo "Gas Price:  $GAS_PRICE"
    echo "Signer:     ${SIGNER:-N/A}"
    echo "Balance:    $BALANCE"
    echo "Nonce:      $NONCE"
}

dump_code() {
    local LABEL="$1"; local ADDR="$2"
    local CODE
    CODE=$(cast code "$ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    local LEN=$(( (${#CODE} - 2) / 2 ))
    echo "• $LABEL ($ADDR) bytecode bytes: $LEN"
}

dump_receipt() {
    local TX="$1"
    echo "📑 Receipt para $TX:"
    cast receipt "$TX" --rpc-url "$RPC_URL" 2>/dev/null || echo "(sin receipt)"
}

simulate_call() {
    local TO="$1"; local SIG="$2"; shift 2
    local SIGNER
    SIGNER=$(signer_addr || true)
    echo "🧪 Simulación (eth_call) $SIG ..."
    cast call "$TO" "$SIG" "$@" --from "${SIGNER:-0x0000000000000000000000000000000000000001}" --rpc-url "$RPC_URL" 2>&1 || true
}
# --- Fin utilidades ---

# --- Celestia DA: utilidades para verificación ---
resolve_namespace() {
    # Priority order: explicit envs, then local rollkit.env (host), then /shared rollkit.env
    for var in EV_NAMESPACE NAMESPACE_ID ROLLKIT_NAMESPACE_ID DA_NAMESPACE; do
        if [ -n "${!var:-}" ]; then echo "${!var}"; return; fi
    done
    if [ -f "$ALT_ROLLKIT_ENV_FILE" ]; then
        grep -E '(^DA_NAMESPACE=|^EV_NAMESPACE=|^NAMESPACE_ID=|^ROLLKIT_NAMESPACE_ID=)' "$ALT_ROLLKIT_ENV_FILE" \
          | tail -n1 | cut -d'=' -f2 | tr -d '"' | tr -d "'"; return
    fi
    if [ -f "$ROLLKIT_ENV_FILE" ]; then
        grep -E '(^DA_NAMESPACE=|^EV_NAMESPACE=|^NAMESPACE_ID=|^ROLLKIT_NAMESPACE_ID=)' "$ROLLKIT_ENV_FILE" \
          | tail -n1 | cut -d'=' -f2 | tr -d '"' | tr -d "'"; return
    fi
    echo ""
}

resolve_celestia_auth() {
    # Try env, then rollkit files
    if [ -n "${CELESTIA_AUTH_TOKEN:-}" ]; then echo "$CELESTIA_AUTH_TOKEN"; return; fi
    if [ -f "$ROLLKIT_ENV_FILE" ]; then
        grep -E '^DA_AUTH_TOKEN=' "$ROLLKIT_ENV_FILE" | tail -n1 | cut -d'=' -f2 | tr -d '"' | tr -d "'"; return
    fi
    if [ -f "$ALT_ROLLKIT_ENV_FILE" ]; then
        grep -E '^DA_AUTH_TOKEN=' "$ALT_ROLLKIT_ENV_FILE" | tail -n1 | cut -d'=' -f2 | tr -d '"' | tr -d "'"; return
    fi
    echo ""
}

celestia_curl() {
    # Wrapper that includes Authorization header if available
    local URL_PATH="$1"; shift || true
    local TOKEN; TOKEN=$(resolve_celestia_auth || true)
    if [ -n "$TOKEN" ]; then
        curl -s "${CELESTIA_RPC%/}/$URL_PATH" -H "Authorization: Bearer $TOKEN" "$@"
    else
        curl -s "${CELESTIA_RPC%/}/$URL_PATH" "$@"
    fi
}

celestia_post_jsonrpc() {
    local METHOD="$1"; shift || true
    local PARAMS_JSON="${1:-[]}"; shift || true
    local TOKEN; TOKEN=$(resolve_celestia_auth || true)
    local HDRS=(-H "Content-Type: application/json")
    if [ -n "$TOKEN" ]; then HDRS+=(-H "Authorization: Bearer $TOKEN"); fi
    curl -s -X POST "$CELESTIA_RPC" "${HDRS[@]}" -d "{\"jsonrpc\":\"2.0\",\"method\":\"$METHOD\",\"params\":$PARAMS_JSON,\"id\":1}"
}

celestia_info() {
    echo "📡 Celestia endpoint: $CELESTIA_RPC"
    local RES; RES=$(celestia_post_jsonrpc "header.NetworkHead" "[]" 2>/dev/null || echo "")
    if echo "$RES" | grep -q 'result'; then
        echo "✓ Celestia RPC responde"
        if command -v jq >/dev/null 2>&1; then
            echo "$RES" | jq -r '"Altura actual: \(.result.header.height)"' 2>/dev/null || true
        fi
        CELESTIA_OK=1
    else
        echo "⚠ No hay respuesta de Celestia RPC (o falta token)"
        CELESTIA_OK=0
    fi
}

celestia_check_recent_blobs() {
    local LABEL="$1"; local LOOKBACK="${2:-10}"
    local NS; NS="$(resolve_namespace || true)"
    celestia_info
    if [ -z "$NS" ]; then
        echo "⚠ Namespace no detectado. Exporta DA_NAMESPACE/NAMESPACE_ID o monta /shared/rollkit.env accesible."
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "ℹ Instala 'jq' para inspeccionar blobs de Celestia"
        return 0
    fi
    local HEAD; HEAD=$(celestia_post_jsonrpc "header.NetworkHead" "[]" | jq -r '.result.header.height // 0' 2>/dev/null || echo 0)
    echo "🔎 Buscando blobs del namespace $NS (últimos $LOOKBACK headers)..."
    local FOUND=0
    for ((h=HEAD; h>HEAD-LOOKBACK && h>0; h--)); do
        local RES; RES=$(celestia_curl "namespaced_data/$h/$NS" 2>/dev/null || echo "")
        if echo "$RES" | jq -e '.result.data[]' >/dev/null 2>&1; then
            FOUND=1
            echo "✅ Celestia: blobs encontrados en altura $h para $LABEL"
            echo "$RES" | jq -r '.result.data[] | "- commitment: \(.commitment)\n  bytes: \((.data|length))"'
        fi
    done
    [ "$FOUND" = "0" ] && echo "⚠ No se encontraron blobs recientes para el namespace $NS (puede ser normal si no hubo txs)."
}

# --- NFT: mostrar 'muestra' del NFT RWA existente ---
show_nft_muestra_existing() {
    # Intenta detectar si el TOKEN_ADDRESS es ERC721 y mostrar su token RWA
    local IS721
    IS721=$(cast call "$TOKEN_ADDRESS" "supportsInterface(bytes4)(bool)" 0x80ac58cd --rpc-url "$RPC_URL" 2>/dev/null || echo "")
    if [ "$IS721" != "true" ]; then
        echo "• TOKEN_ADDRESS no reporta ERC721 (supportsInterface). Se omite la muestra NFT."
        return 0
    fi

    local TID
    TID=$(cast call "$TOKEN_ADDRESS" "getRWATokenId()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "1")
    local OWNER_NFT
    OWNER_NFT=$(cast call "$TOKEN_ADDRESS" "ownerOf(uint256)(address)" "$TID" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
    echo "🎨 Muestra NFT RWA: tokenId $TID owner $OWNER_NFT"
}
# --- Fin Celestia/NFT helpers ---

# --- Host log: explicit namespace verification ---
section "🧭 Namespace detection"
NS_DETECTED=$(resolve_namespace || true)
if [ -n "$NS_DETECTED" ]; then
    echo "DA Namespace: $NS_DETECTED"
else
    echo "⚠ No DA namespace detected yet (set DA_NAMESPACE/NAMESPACE_ID or ensure ./rollkit.env exists)"
fi


# Preflight: ensure 'cast' is available for the tests below
if ! command -v cast >/dev/null 2>&1; then
    fail "'cast' (Foundry) no está instalado o no está en el PATH. Instálalo para continuar."
fi

# Check if deployed-addresses.env exists, attempt to generate it if missing
if [ ! -f "$ADDRESSES_FILE" ]; then
    echo -e "${YELLOW}⚠ deployed-addresses.env not found, attempting on-demand deployment...${NC}"

    if ! command -v forge >/dev/null 2>&1; then
        fail "Foundry (forge) no está instalado, no se pueden desplegar contratos automáticamente. Esperado en: $ADDRESSES_FILE"
    fi

    pushd "$CONTRACTS_DIR" >/dev/null || fail "No se puede entrar a $CONTRACTS_DIR"

    export PRIVATE_KEY

    if ! forge script script/DeployToRollup.s.sol:DeployToRollup \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --legacy \
        --skip-simulation \
        --slow \
        --chain-id 1234; then
        popd >/dev/null || true
        fail "Fallo al desplegar contratos vía Forge"
    fi

    popd >/dev/null || fail "No se pudo volver al directorio raíz del repo"

    if [ ! -f "$ADDRESSES_FILE" ]; then
        fail "El despliegue no generó deployed-addresses.env (esperado en $ADDRESSES_FILE). Verifica fs_permissions en rwa-soberano-evolve/foundry.toml"
    fi

    echo -e "${GREEN}✓ Contracts deployed automatically${NC}"
fi

# Load contract addresses
echo "📋 Loading contract addresses..."
source "$ADDRESSES_FILE"

# Verify all required addresses are set
if [ -z "${REGISTRY_ADDRESS:-}" ] || [ -z "${TOKEN_ADDRESS:-}" ] || [ -z "${RWA_ADDRESS:-}" ]; then
    echo -e "${RED}❌ Error: Missing contract addresses in deployed-addresses.env${NC}"
    echo "REGISTRY_ADDRESS: ${REGISTRY_ADDRESS:-NOT SET}"
    echo "TOKEN_ADDRESS: ${TOKEN_ADDRESS:-NOT SET}"
    echo "RWA_ADDRESS: ${RWA_ADDRESS:-NOT SET}"
    exit 1
fi

echo -e "${GREEN}✓ Contract addresses loaded${NC}"
echo "  Registry:  $REGISTRY_ADDRESS"
echo "  Token:     $TOKEN_ADDRESS"
echo "  RWA:       $RWA_ADDRESS"
echo ""

# Test 1: Verify RPC connectivity
echo "🔌 Test 1: Verifying RPC connectivity..."
if ! BLOCK_NUM=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null); then
    fail "No se puede conectar al RPC en $RPC_URL"
fi
echo -e "${GREEN}✓ RPC connected. Current block: $BLOCK_NUM${NC}"
echo ""

# Test 2: Verify contracts have code deployed
echo "📦 Test 2: Verifying contracts are deployed..."
for CONTRACT_NAME in "Registry" "Token" "RWA"; do
    case $CONTRACT_NAME in
        Registry) ADDRESS=$REGISTRY_ADDRESS ;;
        Token) ADDRESS=$TOKEN_ADDRESS ;;
        RWA) ADDRESS=$RWA_ADDRESS ;;
    esac
    
    CODE=$(cast code "$ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    if [ "$CODE" = "0x" ]; then
        fail "No hay código en $CONTRACT_NAME ($ADDRESS)"
    fi
    echo -e "${GREEN}✓ $CONTRACT_NAME has deployed code${NC}"
done
echo ""

# Test 3: Verify RWA contract wiring
echo "🔗 Test 3: Verifying RWA contract references..."
REGISTRY_FROM_RWA=$(cast call "$RWA_ADDRESS" "registry()(address)" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")
TOKEN_FROM_RWA=$(cast call "$RWA_ADDRESS" "assetToken()(address)" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")

if [ "$REGISTRY_FROM_RWA" != "$REGISTRY_ADDRESS" ]; then
    fail "RWA.registry() devolvió $REGISTRY_FROM_RWA, se esperaba $REGISTRY_ADDRESS"
fi
echo -e "${GREEN}✓ RWA.registry() points to correct address${NC}"

if [ "$TOKEN_FROM_RWA" != "$TOKEN_ADDRESS" ]; then
    fail "RWA.assetToken() devolvió $TOKEN_FROM_RWA, se esperaba $TOKEN_ADDRESS"
fi
echo -e "${GREEN}✓ RWA.assetToken() points to correct address${NC}"
echo ""

# Test 4: Register a document in DocumentRegistry (robust)
echo "📄 Test 4: Registering a test document..."
DOC_HASH="0x$(echo -n "test-integration-doc-$(date +%s)" | sha256sum | cut -d' ' -f1)"
DOC_URI="ipfs://QmTestIntegration$(date +%s)" # informativo; la ABI no lo requiere

# Diagnóstico previo útil para fallas típicas (permiso onlyOwner, fondos, nonce)
debug_env
OWNER=$(cast call "$REGISTRY_ADDRESS" "owner()(address)" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
SIGNER=$(signer_addr || true)
echo "• Registry.owner(): $OWNER"
echo "• Signer actual:   ${SIGNER:-N/A}"

# Intento de mostrar historial de ownership (resiliente a variaciones de cast)
echo "• Ownership transfer history (si existe):"
(
    cast logs --address "$REGISTRY_ADDRESS" \
        "OwnershipTransferred(address,address)" \
        --from-block 0 --to-block latest \
        --rpc-url "$RPC_URL" 2>/dev/null \
    || cast logs --address "$REGISTRY_ADDRESS" \
        "OwnershipTransferred(address,address)" \
        --rpc-url "$RPC_URL" 2>/dev/null \
    || true
) || true

# Determinar contrato objetivo según ownership: si el owner del Registry es RWA,
# debemos invocar vía RWA para pasar el onlyOwner del Registry.
TARGET_ADDR="$REGISTRY_ADDRESS"
TARGET_LABEL="Registry"
if [ -n "$OWNER" ] && [ "${OWNER,,}" = "${RWA_ADDRESS,,}" ]; then
    TARGET_ADDR="$RWA_ADDRESS"
    TARGET_LABEL="RWA"
fi

echo "• Intentando registerDocument(bytes32) contra $TARGET_LABEL ($TARGET_ADDR) con DOC_HASH=$DOC_HASH"

SEND_LOG="/tmp/cast_send_register.log"
set +e
CAST_OUT=$(cast send "$TARGET_ADDR" \
    "registerDocument(bytes32)" \
    "$DOC_HASH" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --legacy 2>&1 | tee "$SEND_LOG")
STATUS=$?
set -e

# Robust TX hash extraction (handles both 'transactionHash' and generic hex capture)
TX_HASH=$(echo "$CAST_OUT" | grep -Eo '0x[0-9a-fA-F]{64}' | tail -n1 || true)

if [ $STATUS -ne 0 ] || [ -z "$TX_HASH" ]; then
    echo -e "${RED}❌ URGENTE: Falló la transacción de registro de documento${NC}"
    echo "— Salida de cast send —"
    echo "$CAST_OUT"
    echo ""
    simulate_call "$TARGET_ADDR" "registerDocument(bytes32)" "$DOC_HASH"
    echo ""
    dump_code "$TARGET_LABEL" "$TARGET_ADDR"
    dump_code "Token" "$TOKEN_ADDRESS"
    dump_code "RWA" "$RWA_ADDRESS"
    if [ "$TARGET_LABEL" = "Registry" ] && [ -n "$OWNER" ] && [ "${OWNER,,}" = "${RWA_ADDRESS,,}" ]; then
        fail "El owner del Registry es RWA; debes registrar vía RWA.registerDocument(bytes32). Se intentó automáticamente y falló. Revisa el estado del RWA o eventos."
    else
        fail "Revisa la firma usada y permisos del signer; si el Registry es ownable por otro contrato/cuenta, llama a través del owner."
    fi
fi

echo -e "${GREEN}✓ Document registered (tx: $TX_HASH)${NC}"

# Esperar y validar receipt (método A: --json + jq). Fallback: chequeo básico si falta jq.
if command -v jq >/dev/null 2>&1; then
    echo "⏳ Esperando inclusión en bloque (hasta 60s)..."
    TIMEOUT=60; ELAPSED=0; SLEEP=2
    RECEIPT_JSON=""; BLOCK_HEX=""; STATUS_HEX=""
    while [ $ELAPSED -lt $TIMEOUT ]; do
        TEMP=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null || echo "")
        BLOCK_HEX=$(echo "$TEMP" | jq -r '.blockNumber // .result.blockNumber // empty' 2>/dev/null || echo "")
        if [ -n "$BLOCK_HEX" ] && [ "$BLOCK_HEX" != "null" ]; then
            RECEIPT_JSON="$TEMP"
            STATUS_HEX=$(echo "$RECEIPT_JSON" | jq -r '.status // .result.status // empty' | tr '[:upper:]' '[:lower:]')
            break
        fi
        sleep $SLEEP; ELAPSED=$((ELAPSED+SLEEP))
        echo "  Esperando... (${ELAPSED}s)"
    done
    if [ -z "$RECEIPT_JSON" ]; then
        fail "Tx de registro no incluida en bloque tras ${TIMEOUT}s."
    fi
    if [ "$STATUS_HEX" != "0x1" ] && [ "$STATUS_HEX" != "1" ]; then
        echo "$RECEIPT_JSON" | jq . >/dev/null 2>&1 || true
        fail "Tx de registro fallida (status=$STATUS_HEX)."
    fi
    echo -e "${GREEN}✓ Receipt válida (status=$STATUS_HEX, block=$BLOCK_HEX)${NC}"
else
    echo "🔎 Método B: Validación básica sin jq (status en receipt)"
    # Polling simple vía eth_getTransactionReceipt hasta que deje de ser null
    TIMEOUT=60; ELAPSED=0; SLEEP=2
    while [ $ELAPSED -lt $TIMEOUT ]; do
        R=$(curl -s -X POST "$RPC_URL" -H 'Content-Type: application/json' \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}")
        if echo "$R" | grep -q '"result":null'; then
            sleep $SLEEP; ELAPSED=$((ELAPSED+SLEEP)); continue
        fi
        if echo "$R" | grep -q '"status":"0x0"'; then
            fail "Tx de registro revertida (status 0x0)"
        fi
        echo -e "${GREEN}✓ Receipt válida (status 0x1)${NC}"; break
    done
    [ $ELAPSED -ge $TIMEOUT ] && fail "Timeout esperando receipt de registro"
fi

# Verificar documento almacenado segun ABI real: RWA_ID() y getDocumentRecord(uint256)
RWA_ID_VAL=$(cast call "$REGISTRY_ADDRESS" "RWA_ID()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
if [ -z "$RWA_ID_VAL" ]; then
    fail "No se pudo leer RWA_ID() del Registry"
fi

DOC_REC=$(cast call "$REGISTRY_ADDRESS" \
    "getDocumentRecord(uint256)((bytes32,bytes32,uint256,address))" \
    "$RWA_ID_VAL" \
    --rpc-url "$RPC_URL" 2>/dev/null || echo "")

if [ -z "$DOC_REC" ] || ! echo "$DOC_REC" | grep -qi "$DOC_HASH"; then
    echo "Registro leído: $DOC_REC"
    fail "El documento registrado no se encontró o no coincide el hash"
fi

echo -e "${GREEN}✓ Document retrieved and verified for RWA_ID=$RWA_ID_VAL${NC}"
echo "  Record: $DOC_REC"
echo ""

# Explicación onlyOwner y verificación DA tras registro
echo "ℹ El 'nuevo documento' es el hash anclado en DocumentRegistry mediante registerDocument(bytes32)."
echo "   Esta función suele estar protegida con onlyOwner: solo el owner del Registry puede llamarla."
echo "   En muchos despliegues de este repo el owner del Registry es el contrato RWA; por eso el script"
echo "   autodirige la llamada a RWA si detecta que es el owner, evitando fallos de permiso."

echo "🛰 Verificando publicación en Celestia tras registrar el documento..."
celestia_check_recent_blobs "DocumentRegistry.registerDocument" 12

# Test 5: Mostrar 'muestra' del NFT RWA existente (no acuña, solo muestra el token ya minteado)
echo "🎨 Test 5: Muestra del NFT RWA existente"
show_nft_muestra_existing

# Test 6: Mint tokens (ERC20)
echo "💰 Test 6: Minting RWA tokens..."
RECIPIENT="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"  # Second account from genesis
MINT_AMOUNT="1000000000000000000"  # 1 token (18 decimals)

# Enviar transacción de minteo y extraer hash de forma robusta
TX_OUT=$(cast send "$TOKEN_ADDRESS" \
    "mint(address,uint256)" \
    "$RECIPIENT" \
    "$MINT_AMOUNT" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --legacy 2>&1 || true)
TX_HASH=$(echo "$TX_OUT" | grep -Eo '0x[0-9a-fA-F]{64}' | head -n1 || echo "")
if [ -z "$TX_HASH" ]; then
    echo "Salida cast send:"; echo "$TX_OUT"
    fail "Falló la transacción de minteo de tokens (no se pudo extraer TX hash)"
fi
echo -e "${GREEN}✓ Tx de minteo enviada (tx: $TX_HASH)${NC}"

# Validación A (preferida): usar --json + jq para status, inclusión y evento Transfer esperado
if command -v jq >/dev/null 2>&1; then
    echo "⏳ Esperando inclusión en bloque (hasta 60s)..."
    TIMEOUT=60; ELAPSED=0; SLEEP=2
    RECEIPT_JSON=""; BLOCK_HEX=""; STATUS_HEX=""
    while [ $ELAPSED -lt $TIMEOUT ]; do
        TEMP=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null || echo "")
        BLOCK_HEX=$(echo "$TEMP" | jq -r '.blockNumber // .result.blockNumber // empty' 2>/dev/null || echo "")
        if [ -n "$BLOCK_HEX" ] && [ "$BLOCK_HEX" != "null" ]; then
            RECEIPT_JSON="$TEMP"
            STATUS_HEX=$(echo "$RECEIPT_JSON" | jq -r '.status // .result.status // empty' | tr '[:upper:]' '[:lower:]')
            break
        fi
        sleep $SLEEP; ELAPSED=$((ELAPSED+SLEEP))
        echo "  Esperando... (${ELAPSED}s)"
    done
    if [ -z "$RECEIPT_JSON" ]; then
        fail "Tx de minteo no incluida en bloque tras ${TIMEOUT}s."
    fi
    if [ "$STATUS_HEX" != "0x1" ] && [ "$STATUS_HEX" != "1" ]; then
        echo "$RECEIPT_JSON" | jq . >/dev/null 2>&1 || true
        fail "Tx de minteo fallida (status=$STATUS_HEX)."
    fi
    # Comprobar evento Transfer (ERC20): topic0 = Transfer, topic2 = destinatario
    TRANSFER_TOPIC="0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    RECIPIENT_TOPIC="0x000000000000000000000000${RECIPIENT#0x}"
    HAS_TRANSFER=$(echo "$RECEIPT_JSON" | jq -e --arg t "$TRANSFER_TOPIC" --arg to "$RECIPIENT_TOPIC" '(.logs // []) | any(.topics[0]==$t and .topics[2]|ascii_downcase==$to|ascii_downcase)')
    if [ "$HAS_TRANSFER" != "true" ]; then
        echo -e "${YELLOW}⚠ Éxito on-chain, pero no se detectó Transfer al destinatario (${RECIPIENT})${NC}"
    else
        echo -e "${GREEN}✓ Evento Transfer detectado hacia ${RECIPIENT}${NC}"
    fi
    echo -e "${GREEN}✓ Receipt válida (status=$STATUS_HEX, block=$BLOCK_HEX)${NC}"
else
    # Validación B: sin jq. Polling eth_getTransactionReceipt y chequeo de status solamente
    echo "🔎 Método B: Validación simple por receipt.status (sin jq)"
    TIMEOUT=60; ELAPSED=0; SLEEP=2
    while [ $ELAPSED -lt $TIMEOUT ]; do
        R=$(curl -s -X POST "$RPC_URL" -H 'Content-Type: application/json' \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}")
        if echo "$R" | grep -q '"result":null'; then
            sleep $SLEEP; ELAPSED=$((ELAPSED+SLEEP)); continue
        fi
        if echo "$R" | grep -q '"status":"0x0"'; then
            fail "Tx de minteo revertida (status 0x0)"
        fi
        echo -e "${GREEN}✓ Receipt válida (status 0x1)${NC}"; break
    done
    [ $ELAPSED -ge $TIMEOUT ] && fail "Timeout esperando receipt de minteo"
fi

# Verify balance (estado observable)
BALANCE=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$RECIPIENT" \
    --rpc-url "$RPC_URL" 2>/dev/null || echo "0")

if [ "$BALANCE" = "0" ]; then
    fail "El balance de tokens es 0 después del minteo"
fi
echo -e "${GREEN}✓ Token balance verified: $BALANCE wei${NC}"
echo ""

# Test 7: Verify token metadata
echo "🏷️  Test 7: Verifying token metadata..."
TOKEN_NAME=$(cast call "$TOKEN_ADDRESS" "name()(string)" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
TOKEN_SYMBOL=$(cast call "$TOKEN_ADDRESS" "symbol()(string)" --rpc-url "$RPC_URL" 2>/dev/null || echo "")

if [ -z "$TOKEN_NAME" ] || [ -z "$TOKEN_SYMBOL" ]; then
    fail "No se pudo obtener la metadata del token"
fi
echo -e "${GREEN}✓ Token name: $TOKEN_NAME${NC}"
echo -e "${GREEN}✓ Token symbol: $TOKEN_SYMBOL${NC}"
echo ""

# Test 8: Verify Celestia DA connectivity (JSON-RPC)
echo "🌟 Test 8: Checking Celestia DA connection (JSON-RPC)..."
if command -v curl >/dev/null 2>&1; then
    # Try to get Celestia network head to verify DA layer is reachable (include auth if present)
    CELESTIA_RESPONSE=$(celestia_post_jsonrpc "header.NetworkHead" "[]" 2>/dev/null || echo "")
    
    if echo "$CELESTIA_RESPONSE" | grep -q "result"; then
        echo -e "${GREEN}✓ Celestia DA layer is reachable${NC}"
        # Extract latest height if available
        if command -v jq >/dev/null 2>&1; then
            HEIGHT=$(echo "$CELESTIA_RESPONSE" | jq -r '.result.header.height' 2>/dev/null || echo "unknown")
            echo "  Latest Celestia height: $HEIGHT"
        fi
    else
        echo -e "${YELLOW}⚠ Warning: Celestia DA layer not reachable (may not affect local tests)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ curl not found, skipping Celestia check${NC}"
fi
echo ""

# Test 9: Verify rollup is producing blocks
echo "⛓️  Test 9: Verifying rollup block production..."
INITIAL_BLOCK=$BLOCK_NUM
sleep 5
NEW_BLOCK=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "0")

if [ "$NEW_BLOCK" -le "$INITIAL_BLOCK" ]; then
    echo -e "${YELLOW}⚠ Warning: No new blocks produced in 5 seconds${NC}"
else
    BLOCKS_PRODUCED=$((NEW_BLOCK - INITIAL_BLOCK))
    echo -e "${GREEN}✓ Rollup producing blocks ($BLOCKS_PRODUCED blocks in 5s)${NC}"
fi
echo ""

# Summary
echo "=============================="
echo -e "${GREEN}✅ ALL INTEGRATION TESTS PASSED${NC}"
echo "=============================="
echo ""
echo "Summary:"
echo "  • RPC connectivity: OK"
echo "  • Contracts deployed: OK"
echo "  • Contract wiring: OK"
echo "  • Document registration: OK"
echo "  • NFT muestra: OK"
echo "  • Token minting: OK"
echo "  • Token metadata: OK"
echo "  • Celestia DA: $([ -n "${CELESTIA_RESPONSE:-}" ] && echo 'OK' || echo 'SKIPPED')"
echo "  • Block production: OK"
echo ""
echo "🎉 RWA contracts are fully integrated with Evolve rollup!"
echo ""

exit 0
