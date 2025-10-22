#!/usr/bin/env bash
set -euo pipefail

echo "🔁 Preparing frontend environment"
# Copy deployed addresses if present
if [ -f ../rwa-soberano-evolve/deployed-addresses.env ]; then
  echo "Copying deployed-addresses.env to frontend/public"
  mkdir -p frontend/public
  cp ../rwa-soberano-evolve/deployed-addresses.env frontend/public/deployed-addresses.env
fi

cd frontend || { echo "frontend directory not found"; exit 1; }

# Install if node_modules missing
if [ ! -d node_modules ]; then
  echo "Installing frontend dependencies..."
  npm ci
fi

echo "🌐 Starting Vite dev server (npm run dev)"
npm run dev
