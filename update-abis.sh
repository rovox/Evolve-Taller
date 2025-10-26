#!/usr/bin/env bash
set -euo pipefail

echo "🔄 Actualizando ABIs para el frontend..."

cd rwa-soberano-evolve
forge build --silent

mkdir -p ../frontend/src/abis

# Copiar ABIs compiladas
cp out/DocumentRegistry.sol/DocumentRegistry.json ../frontend/src/abis/ 2>/dev/null || echo "⚠️  DocumentRegistry ABI no encontrada"
cp out/AssetToken.sol/AssetToken.json ../frontend/src/abis/ 2>/dev/null || echo "⚠️  AssetToken ABI no encontrada"
cp out/RWASovereignRollup.sol/RWASovereignRollup.json ../frontend/src/abis/ 2>/dev/null || echo "⚠️  RWASovereignRollup ABI no encontrada"

echo "✅ ABIs copiadas a frontend/src/abis/"
ls -lh ../frontend/src/abis/*.json 2>/dev/null || echo "Ningún ABI copiado"