#!/usr/bin/env bash
set -euo pipefail

# Quick, non-destructive E2E: reuse existing infra and PRIVATE_KEY
# Requires: cast, forge, jq, curl

RPC_URL="${RPC_URL:-http://localhost:8545}"
PRIVATE_KEY="${PRIVATE_KEY:-}"
CHAIN_ID="${CHAIN_ID:-1234}"
ROSCA_ADDRESS="${ROSCA_ADDRESS:-}"

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
  log "No se encontró ROSCA desplegado. Desplegando con forge script (no se reinicia nada)..."
  (cd contracts && forge script script/DeployROSCA.s.sol:DeployROSCAScript \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vvv) | tee /tmp/rosca_deploy.log

  # Intentar leer dirección desde broadcast
  latest=$(ls -1 contracts/broadcast/DeployROSCA.s.sol/*/run-latest.json 2>/dev/null | tail -n1)
  if [[ -n "$latest" ]]; then
    ROSCA=$(jq -r '.transactions[] | select(.contractName=="ROSCA") | .contractAddress' "$latest" | grep -E '^0x[0-9a-fA-F]{40}$' | tail -n1)
  fi
fi

if [[ -z "$ROSCA" ]]; then
  echo "Error: No se pudo determinar la dirección del contrato ROSCA" >&2
  exit 1
fi

log "ROSCA en: $ROSCA"
echo "$ROSCA" > frontend/.rosca-address

# Actualizar frontend/app.js in-place (no cambia lógica, solo dirección)
if [[ -f frontend/app.js ]]; then
  sed -i.bak -E "s/(const CONTRACT_ADDRESS = \")[^"]+(\";)/\\1$ROSCA\\2/" frontend/app.js || true
  log "✔ Actualizado frontend/app.js con la dirección del contrato"
fi

# Pruebas rápidas con cast (crear, unir, contribuir)
GROUP_NAME="Quick E2E Group"
MONTHLY_ETH="0.01"
DURATION=3
MONTHLY_WEI=$(cast to-wei "$MONTHLY_ETH" eth)

log "▶ createGroup('$GROUP_NAME',$MONTHLY_WEI,$DURATION)"
TX1=$(cast send "$ROSCA" "createGroup(string,uint256,uint256)" "$GROUP_NAME" "$MONTHLY_WEI" "$DURATION" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy | tail -n1)
RCPT1=$(echo "$TX1" | awk '{print $NF}')
cast receipt "$RCPT1" --rpc-url "$RPC_URL" >/dev/null || true

GC=$(cast call "$ROSCA" "groupCounter()(uint256)" --rpc-url "$RPC_URL")
log "groupCounter: $GC"

# Crear cuenta secundaria efímera y fondearla con 0.05 ETH
SECOND_JSON=$(cast wallet new --json)
SECOND_ADDR=$(echo "$SECOND_JSON" | jq -r '.address')
SECOND_PK=$(echo "$SECOND_JSON" | jq -r '.private_key')
log "Cuenta secundaria: $SECOND_ADDR (efímera)"

cast send "$SECOND_ADDR" --value $(cast to-wei 0.05 eth) --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy >/dev/null

log "▶ joinGroup(0) con segunda cuenta"
cast send "$ROSCA" "joinGroup(uint256)" 0 --rpc-url "$RPC_URL" --private-key "$SECOND_PK" --legacy >/dev/null

# Contribución del creador
log "▶ contribute(0) con value=$MONTHLY_WEI"
cast send "$ROSCA" "contribute(uint256)" 0 --value "$MONTHLY_WEI" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy >/dev/null

# Lecturas
INFO=$(cast call "$ROSCA" "getGroupInfo(uint256)" 0 --rpc-url "$RPC_URL")
log "getGroupInfo(0): $INFO"

MEMBERS=$(cast call "$ROSCA" "getGroupMembers(uint256)(address[])" 0 --rpc-url "$RPC_URL")
log "Miembros(0): $MEMBERS"

log "✔ E2E rápido completado. Revisa Explorer y frontend si están activos."
