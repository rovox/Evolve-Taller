#!/usr/bin/env bash
set -euo pipefail

# CI-style wrapper to run deploy -> tests -> integration smoke -> sync -> (optionally) start frontend
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔁 CI Integration wrapper starting"

# 1) Deploy contracts
if [ -f "$ROOT_DIR/deploy-rwa-contracts.sh" ]; then
  echo "Step 1: Deploying contracts"
  (cd "$ROOT_DIR" && ./deploy-rwa-contracts.sh)
else
  echo "Deploy wrapper not found: $ROOT_DIR/deploy-rwa-contracts.sh"
  exit 1
fi

# 2) Run unit tests
if [ -f "$ROOT_DIR/run-contract-tests.sh" ]; then
  echo "Step 2: Running unit tests"
  (cd "$ROOT_DIR" && ./run-contract-tests.sh)
else
  echo "Test wrapper not found: $ROOT_DIR/run-contract-tests.sh"
  exit 1
fi

# 3) Run integration smoke test
if [ -f "$ROOT_DIR/test-rwa-integration.sh" ]; then
  echo "Step 3: Running integration smoke test"
  (cd "$ROOT_DIR" && ./test-rwa-integration.sh)
else
  echo "Integration test not found: $ROOT_DIR/test-rwa-integration.sh"
  echo "Skipping integration smoke test"
fi

# 4) Sync addresses to frontend
if [ -f "$ROOT_DIR/sync-contract-addresses.sh" ]; then
  echo "Step 4: Syncing addresses to frontend"
  (cd "$ROOT_DIR" && ./sync-contract-addresses.sh)
else
  echo "Sync script not found: $ROOT_DIR/sync-contract-addresses.sh"
  exit 1
fi

# 5) Start frontend (optional - run in foreground)
if [ "${1:-}" = "--start-frontend" ]; then
  if [ -f "$ROOT_DIR/start-frontend.sh" ]; then
    echo "Step 5: Starting frontend"
    (cd "$ROOT_DIR" && ./start-frontend.sh)
  else
    echo "Start frontend script not found"
    exit 1
  fi
fi

echo "✅ CI integration wrapper finished"
