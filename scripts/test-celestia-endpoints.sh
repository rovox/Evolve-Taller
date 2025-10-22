#!/usr/bin/env bash
# scripts/test-celestia-endpoints.sh
# Compare Celestia RPC responses between two endpoints for basic JSON-RPC calls.

set -euo pipefail

LOCAL=${1:-http://localhost:26658}
REMOTE=${2:-https://celestia-mocha-rpc.publicnode.com:443}

echo "Comparing Celestia endpoints"
echo "Local : $LOCAL"
echo "Remote: $REMOTE"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

call_rpc() {
  local url="$1"
  local method="$2"
  local data
  data='{"jsonrpc":"2.0","method":"'"$method"'","params":[],"id":1}'
  if curl -s -X POST "$url" -H "Content-Type: application/json" -d "$data" | jq -S . 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

echo "\n[1] header.NetworkHead"
local_head=$(curl -s -X POST "$LOCAL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"header.NetworkHead","params":[],"id":1}') || local_head=''
remote_head=$(curl -s -X POST "$REMOTE" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"header.NetworkHead","params":[],"id":1}') || remote_head=''

echo "-- Local response --"
echo "$local_head" | jq -S . || echo "$local_head"

echo "-- Remote response --"
echo "$remote_head" | jq -S . || echo "$remote_head"

# Quick diff on presence of 'result' key
local_has_result=$(echo "$local_head" | jq 'has("result")' 2>/dev/null || echo false)
remote_has_result=$(echo "$remote_head" | jq 'has("result")' 2>/dev/null || echo false)

echo "\nPresence of 'result': local=$local_has_result remote=$remote_has_result"

# Optional health endpoint check (some nodes expose /health or /status)
echo "\n[2] HTTP health endpoints (GET)"
for url in "$LOCAL" "$REMOTE"; do
  echo "Checking $url/health"
  if curl -s --max-time 5 "$url/health" | jq -S . 2>/dev/null; then
    echo "(OK) $url/health returned JSON"
  else
    echo "(NO JSON) $url/health non-JSON or not reachable"
  fi
done

# Summary guidance
cat <<EOF

Summary:
- If both endpoints return a JSON with 'result', the RPCs are reachable and respond to the same method.
- Differences in fields (heights, hashes) may be due to node sync or network differences.
- Some public nodes may block methods or require auth; in that case remote response may be an error object.

Notes:
- For gRPC tests (celestia gRPC over TLS), you'll need grpcurl or a gRPC client; this script only tests JSON-RPC HTTP.
- If remote requires an Authorization header, set CELESTIA_BEARER env before calling this script, e.g.

  CELESTIA_BEARER=yourtoken ./scripts/test-celestia-endpoints.sh http://localhost:26658 https://celestia-mocha-rpc.publicnode.com:443

EOF
