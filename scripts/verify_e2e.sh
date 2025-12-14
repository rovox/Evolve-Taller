#!/usr/bin/env bash
set -euo pipefail

# Quick, non-destructive E2E: reuse existing infra and PRIVATE_KEY
# Requires: cast, forge, jq, curl

RPC_URL="${RPC_URL:-http://localhost:8545}"
PRIVATE_KEY="${PRIVATE_KEY:-}"
CHAIN_ID="${CHAIN_ID:-1234}"
ROSCA_ADDRESS="${ROSCA_ADDRESS:-}"
GREETER_ADDRESS="${GREETER_ADDRESS:-}"

log() { echo -e "[$(date +%H:%M:%S)] $*"; }

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' no está instalado o no está en PATH" >&2
    exit 1
  fi
}

require_bin curl
require_bin jq
require_bin cast
require_bin forge

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "Error: PRIVATE_KEY no está exportado en el entorno" >&2
  exit 1
fi

log "Verificando endpoints sin reiniciar nada..."
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  "$RPC_URL" | jq -e '.result' >/dev/null
log "✔ EVM RPC OK: $RPC_URL"

if curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"p2p.Info"}' \
  http://localhost:26658 | jq -e '.result' >/dev/null 2>&1; then
  log "✔ Celestia JSON-RPC OK: http://localhost:26658"
else
  log "⚠ Celestia JSON-RPC no respondió (continuando, solo para info)"
fi

ADDR=$(cast wallet address --private-key "$PRIVATE_KEY")
BAL=$(cast balance "$ADDR" --rpc-url "$RPC_URL")
CID_HEX=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "")
log "Cuenta deployer: $ADDR"
log "Balance: $BAL wei"
[[ -n "$CID_HEX" ]] && log "ChainId: $CID_HEX"

# Initialize deployment info JSON
DEPLOYMENT_INFO="frontend/deployment_info.json"
cat > "$DEPLOYMENT_INFO" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "chain_id": $CID_HEX,
  "deployer": "$ADDR",
  "private_key": "$PRIVATE_KEY",
  "rpc_url": "$RPC_URL",
  "contracts": {},
  "transactions": []
}
EOF

log "✔ Inicializado deployment_info.json"

# Helper: map tx to Celestia and add to deployment_info
map_tx_to_celestia() {
  local tx_hash="$1"
  local contract_name="$2"
  
  log "🔍 Mapeando $tx_hash a Celestia..."
  
  # Wait a bit for tx to be mined
  sleep 2
  
  RECEIPT=$(cast receipt "$tx_hash" --rpc-url "$RPC_URL" --json 2>/dev/null || echo '{}')
  BLOCK_NUM=$(echo "$RECEIPT" | jq -r '.blockNumber // "0x0"')
  BLOCK_NUM_DEC=$((BLOCK_NUM))
  
  # Query sequencer logs for recent DA submission with data
  # Look for lines like: "2:06PM INF successfully submitted items to DA layer component=da_submitter count=6 itemType=data"
  CELESTIA_LOG=$(docker logs single-sequencer 2>&1 | grep -E "itemType=data" | tail -n1)
  
  if [[ -n "$CELESTIA_LOG" ]]; then
    # Try to extract timestamp and correlate with EVM block
    log "📡 Última publicación DA: $CELESTIA_LOG"
    CELESTIA_HEIGHT="confirmed"
  else
    CELESTIA_HEIGHT="pending"
  fi
  
  if [[ "$CELESTIA_HEIGHT" == "pending" ]]; then
    log "⚠ TX aún no publicada a Celestia (esperando batch)"
  else
    log "✔ TX en bloque EVM $BLOCK_NUM_DEC → Celestia height ~$CELESTIA_HEIGHT"
  fi
  
  # Update deployment_info.json
  TMP=$(mktemp)
  jq --arg name "$contract_name" \
     --arg tx "$tx_hash" \
     --argjson block "$BLOCK_NUM_DEC" \
     --arg celestia "$CELESTIA_HEIGHT" \
     '.contracts[$name].tx_hash = $tx | 
      .contracts[$name].evm_block = $block |
      .contracts[$name].celestia_height = $celestia |
      .contracts[$name].celenium_url = "https://mocha.celenium.io/block/\($celestia)"' \
     "$DEPLOYMENT_INFO" > "$TMP" && mv "$TMP" "$DEPLOYMENT_INFO"
}

# Descubrir o desplegar ROSCA
discover_rosca() {
  # 1) variable de entorno
  if [[ -n "${ROSCA_ADDRESS}" ]]; then
    echo "$ROSCA_ADDRESS"
    return 0
  fi

  # 2) broadcast más reciente de DeployROSCAS.s.sol
  local latest
  latest=$(ls -1 contracts/broadcast/DeployROSCA.s.sol/*/run-latest.json 2>/dev/null | tail -n1 || true)
  if [[ -n "$latest" ]]; then
    jq -r '.transactions[] | select(.contractName=="ROSCA") | .contractAddress' "$latest" | grep -E '^0x[0-9a-fA-F]{40}$' | tail -n1 || true
    return 0
  fi

  # 3) archivo auxiliar si existe
  if [[ -f frontend/.rosca-address ]]; then
    cat frontend/.rosca-address | tr -d '\n' | grep -E '^0x[0-9a-fA-F]{40}$' || true
    return 0
  fi

  echo ""
}

ROSCA=$(discover_rosca)

if [[ -z "$ROSCA" ]]; then
  log "No se encontró ROSCA desplegado. Desplegando con forge script..."
  (cd contracts && forge script script/DeployROSCA.s.sol:DeployROSCAScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv) 2>&1 | tee /tmp/rosca_deploy.log

  # Intentar leer dirección desde broadcast
  latest=$(ls -1 contracts/broadcast/DeployROSCA.s.sol/*/run-latest.json 2>/dev/null | tail -n1)
  if [[ -n "$latest" ]]; then
    ROSCA=$(jq -r '.transactions[] | select(.contractName=="ROSCA") | .contractAddress' "$latest" | grep -E '^0x[0-9a-fA-F]{40}$' | tail -n1)
    ROSCA_TX=$(jq -r '.transactions[] | select(.contractName=="ROSCA") | .hash' "$latest" | grep -E '^0x[0-9a-fA-F]{64}$' | tail -n1)
  fi
fi

# Verificar que exista bytecode en la dirección encontrada; si no, redeploy
CODE=$(cast code "$ROSCA" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
if [[ "$CODE" == "0x" || -z "$CODE" ]]; then
  log "⚠ Dirección $ROSCA sin bytecode. Redeploy automático..."
  (cd contracts && forge script script/DeployROSCA.s.sol:DeployROSCAScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv) 2>&1 | tee /tmp/rosca_deploy.log

  latest=$(ls -1 contracts/broadcast/DeployROSCA.s.sol/*/run-latest.json 2>/dev/null | tail -n1)
  if [[ -n "$latest" ]]; then
    ROSCA=$(jq -r '.transactions[] | select(.contractName=="ROSCA") | .contractAddress' "$latest" | grep -E '^0x[0-9a-fA-F]{40}$' | tail -n1)
    ROSCA_TX=$(jq -r '.transactions[] | select(.contractName=="ROSCA") | .hash' "$latest" | grep -E '^0x[0-9a-fA-F]{64}$' | tail -n1)
  fi

  if [[ -z "$ROSCA" ]]; then
    echo "Error: Redeploy falló; no se pudo determinar la dirección del contrato ROSCA" >&2
    exit 1
  fi
fi

if [[ -z "$ROSCA" ]]; then
  echo "Error: No se pudo determinar la dirección del contrato ROSCA" >&2
  exit 1
fi

log "ROSCA en: $ROSCA"
echo "$ROSCA" > frontend/.rosca-address

# Guardar ROSCA en deployment_info
TMP=$(mktemp)
jq --arg addr "$ROSCA" '.contracts.ROSCA.address = $addr' "$DEPLOYMENT_INFO" > "$TMP" && mv "$TMP" "$DEPLOYMENT_INFO"

# Si tenemos tx hash, mapear a Celestia
if [[ -n "${ROSCA_TX:-}" ]]; then
  map_tx_to_celestia "$ROSCA_TX" "ROSCA"
fi

# Actualizar frontend/app.js in-place
if [[ -f frontend/app.js ]]; then
  sed -i.bak -E "s/(const CONTRACT_ADDRESS = \")[^\"]+(\";)/\\1$ROSCA\\2/" frontend/app.js || true
  log "✔ Actualizado frontend/app.js con la dirección del contrato"
fi

# === DESPLEGAR GREETER ===
log "▶ Desplegando Greeter..."
(cd contracts && forge script script/DeployGreeter.s.sol:DeployGreeter \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vvv) 2>&1 | tee /tmp/greeter_deploy.log

latest_greeter=$(ls -1 contracts/broadcast/DeployGreeter.s.sol/*/run-latest.json 2>/dev/null | tail -n1)
if [[ -n "$latest_greeter" ]]; then
  GREETER=$(jq -r '.transactions[] | select(.contractName=="Greeter") | .contractAddress' "$latest_greeter" | grep -E '^0x[0-9a-fA-F]{40}$' | tail -n1)
  GREETER_TX=$(jq -r '.transactions[] | select(.contractName=="Greeter") | .hash' "$latest_greeter" | grep -E '^0x[0-9a-fA-F]{64}$' | tail -n1)
  
  log "Greeter en: $GREETER"
  echo "$GREETER" > frontend/.greeter-address
  
  # Guardar en deployment_info
  TMP=$(mktemp)
  jq --arg addr "$GREETER" '.contracts.Greeter.address = $addr' "$DEPLOYMENT_INFO" > "$TMP" && mv "$TMP" "$DEPLOYMENT_INFO"
  
  if [[ -n "${GREETER_TX:-}" ]]; then
    map_tx_to_celestia "$GREETER_TX" "Greeter"
  fi
  
  # Test Greeter
  log "▶ Testing Greeter.greeting()"
  GREETING=$(cast call "$GREETER" "greeting()(string)" --rpc-url "$RPC_URL")
  log "Greeting inicial: $GREETING"
  
  log "▶ setGreeting('Celestia Integration Test')"
  SET_TX=$(cast send "$GREETER" "setGreeting(string)" "Celestia Integration Test" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --json | jq -r '.transactionHash')
  
  if [[ -n "$SET_TX" ]]; then
    log "setGreeting TX: $SET_TX"
    map_tx_to_celestia "$SET_TX" "Greeter_setGreeting"
  fi
  
  GREETING_FINAL=$(cast call "$GREETER" "greeting()(string)" --rpc-url "$RPC_URL")
  log "Greeting final: $GREETING_FINAL"
fi

# === PRUEBAS ROSCA ===
GROUP_NAME="Quick E2E Group"
MONTHLY_ETH="0.01"
DURATION=3
MONTHLY_WEI=$(cast to-wei "$MONTHLY_ETH" eth)

PRE_GC=$(cast call "$ROSCA" "groupCounter()(uint256)" --rpc-url "$RPC_URL")
log "Groups before: $PRE_GC"

log "▶ createGroup('$GROUP_NAME',$MONTHLY_WEI,$DURATION)"
CREATE_TX=$(cast send "$ROSCA" "createGroup(string,uint256,uint256)" "$GROUP_NAME" "$MONTHLY_WEI" "$DURATION" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --json | jq -r '.transactionHash')

if [[ -n "$CREATE_TX" ]]; then
  log "createGroup TX: $CREATE_TX"
  map_tx_to_celestia "$CREATE_TX" "ROSCA_createGroup"
fi

POST_GC=$(cast call "$ROSCA" "groupCounter()(uint256)" --rpc-url "$RPC_URL")
log "Groups after: $POST_GC"

if [[ "$POST_GC" -le "$PRE_GC" ]]; then
  log "❌ Error: Group counter did not increase"
  exit 1
fi

TARGET_GROUP_ID=$((POST_GC - 1))
log "Target Group ID: $TARGET_GROUP_ID"

# Crear cuenta secundaria
SECOND_JSON=$(cast wallet new --json)
SECOND_ADDR=$(echo "$SECOND_JSON" | jq -r '.[0].address')
SECOND_PK=$(echo "$SECOND_JSON" | jq -r '.[0].private_key')
log "Cuenta secundaria: $SECOND_ADDR (efímera)"

cast send "$SECOND_ADDR" --value $(cast to-wei 0.05 eth) --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy >/dev/null

log "▶ joinGroup($TARGET_GROUP_ID) con segunda cuenta"
JOIN_TX=$(cast send "$ROSCA" "joinGroup(uint256)" "$TARGET_GROUP_ID" \
  --rpc-url "$RPC_URL" --private-key "$SECOND_PK" --legacy --json | jq -r '.transactionHash')

if [[ -n "$JOIN_TX" ]]; then
  log "joinGroup TX: $JOIN_TX"
  map_tx_to_celestia "$JOIN_TX" "ROSCA_joinGroup"
fi

log "▶ contribute($TARGET_GROUP_ID) con value=$MONTHLY_WEI"
CONTRIBUTE_TX=$(cast send "$ROSCA" "contribute(uint256)" "$TARGET_GROUP_ID" --value "$MONTHLY_WEI" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --json | jq -r '.transactionHash')

if [[ -n "$CONTRIBUTE_TX" ]]; then
  log "contribute TX: $CONTRIBUTE_TX"
  map_tx_to_celestia "$CONTRIBUTE_TX" "ROSCA_contribute"
fi

# Lecturas finales
INFO=$(cast call "$ROSCA" "getGroupInfo(uint256)" "$TARGET_GROUP_ID" --rpc-url "$RPC_URL")
log "getGroupInfo($TARGET_GROUP_ID): $INFO"

MEMBERS=$(cast call "$ROSCA" "getGroupMembers(uint256)(address[])" "$TARGET_GROUP_ID" --rpc-url "$RPC_URL")
log "Miembros($TARGET_GROUP_ID): $MEMBERS"

# Export final de deployment_info con timestamp
TMP=$(mktemp)
jq --arg ts "$(date -Iseconds)" '.last_updated = $ts' "$DEPLOYMENT_INFO" > "$TMP" && mv "$TMP" "$DEPLOYMENT_INFO"

log "✔ E2E completado. Metadata exportada en: $DEPLOYMENT_INFO"
log "📋 Deployment Info:"
cat "$DEPLOYMENT_INFO" | jq '.'