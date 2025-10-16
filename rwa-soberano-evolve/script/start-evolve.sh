#!/bin/bash

echo " Iniciando entorno Evolve + Celestia..."

# Configuración
export EVOLVE_RPC_URL="http://localhost:7331"
export CELESTIA_RPC_URL="https://rpc-mocha.pops.one/"
export PRIVATE_KEY=$1

# Verificar que estamos en el directorio correcto
if [ ! -f "build/testapp" ]; then
    echo " No se encuentra testapp. Ejecuta desde el directorio ev-node."
    exit 1
fi

# Iniciar DA local (para desarrollo)
echo " Iniciando DA local..."
pkill -f "local-da" || true
local-da > da.log 2>&1 &
DA_PID=$!

sleep 3

# Iniciar nodo Evolve
echo " Iniciando nodo Evolve..."
./build/testapp start --evnode.signer.passphrase secret > evolve.log 2>&1 &
EVOLVE_PID=$!

echo " Esperando que los servicios inicien..."
sleep 10

# Verificar salud
echo " Verificando salud del nodo..."
curl -s http://localhost:7331/health/live

echo ""
echo "   Servicios iniciados:"
echo "   - DA Local: PID $DA_PID"
echo "   - Evolve Node: PID $EVOLVE_PID"
echo "   - RPC URL: $EVOLVE_RPC_URL"

# Mantener el script corriendo
wait