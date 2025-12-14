#!/usr/bin/env bash
# scripts/tx_to_celestia.sh - Map EVM tx hash to Celestia block height

set -euo pipefail

TX_HASH="${1:-}"
RPC_URL="${RPC_URL:-http://localhost:8545}"

if [[ -z "$TX_HASH" ]]; then
  echo "Usage: $0 <tx_hash>" >&2
  exit 1
fi

# Get EVM block number from receipt
RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json 2>/dev/null || echo '{}')
BLOCK_NUM=$(echo "$RECEIPT" | jq -r '.blockNumber // empty')

if [[ -z "$BLOCK_NUM" ]]; then
  echo "Error: Transaction not found or not mined" >&2
  exit 1
fi

BLOCK_NUM_DEC=$((BLOCK_NUM))

# Query sequencer logs for DA submission containing this block
# Format: "successfully submitted items to DA layer" with height info
CELESTIA_HEIGHT=$(docker logs single-sequencer 2>&1 | \
  grep -E "successfully submitted.*itemType=data" -A 3 | \
  grep -oP 'height=\K[0-9]+' | tail -n1 || echo "")

if [[ -z "$CELESTIA_HEIGHT" ]]; then
  echo "Warning: Could not map to Celestia height (tx may not be published yet)" >&2
  CELESTIA_HEIGHT="pending"
fi

# Output JSON
cat <<EOF
{
  "tx_hash": "$TX_HASH",
  "evm_block": $BLOCK_NUM_DEC,
  "celestia_height": "$CELESTIA_HEIGHT",
  "celenium_url": "https://mocha.celenium.io/block/$CELESTIA_HEIGHT"
}
EOF
