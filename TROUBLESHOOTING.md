# Solución a Problemas del Frontend y Despliegue de Contratos

## Problemas Identificados

1. ❌ **El botón "Run Integration Tests" no funciona** - El servidor HTTP simple no soporta POST
2. ❌ **No hay resultados de pruebas** - `rosca_test_results.json` no existe
3. ❌ **El balance de ETH muestra "-"** - El frontend no puede obtener el balance
4. ❌ **Los contratos no están desplegados** - La dirección en el código no tiene contrato desplegado

## Causa Raíz

`ev-reth` **NO** tiene cuentas desbloqueadas como Anvil. La cuenta en el genesis (`0x24150227Be6732d4D82B4711Cceddd555b0524C0`) tiene fondos masivos pero necesitamos su clave privada para desplegar contratos.

## Soluciones

### Opción 1: Usar la Clave Privada del Sequencer (RECOMENDADO)

El sequencer tiene una cuenta configurada. Podemos usar esa clave:

```bash
# 1. Obtener la dirección del sequencer
docker exec single-sequencer evnode keys show signer --keyring-backend file

# 2. Exportar la clave privada
docker exec single-sequencer evnode keys export signer --keyring-backend file --unsafe --unarmored-hex

# 3. Desplegar ROSCA con esa clave
cd /home/robvox/evolve-deployment/contracts
forge create src/ROSCA.sol:ROSCA \
  --rpc-url http://localhost:8545 \
  --private-key <CLAVE_PRIVADA_DEL_SEQUENCER> \
  --legacy
```

### Opción 2: Generar Nueva Cuenta y Fondearla

```bash
# 1. Generar nueva cuenta
cast wallet new

# 2. Guardar la clave privada y dirección

# 3. Enviar fondos desde la cuenta del genesis usando cast
# (Esto requiere tener la clave privada del genesis)
```

### Opción 3: Usar Cuenta de Anvil Predeterminada (MÁS SIMPLE)

La forma más simple es enviar fondos a la cuenta de Anvil que ya tenemos:

```bash
# 1. Primero necesitamos la clave privada de la cuenta del genesis
# Esta información debería estar en la documentación del proyecto

# 2. Una vez tengamos la clave, enviamos fondos:
cast send \
  --rpc-url http://localhost:8545 \
  --private-key <CLAVE_GENESIS> \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --value 1000ether \
  --legacy

# 3. Luego desplegamos ROSCA:
cd /home/robvox/evolve-deployment/contracts
forge create src/ROSCA.sol:ROSCA \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --legacy
```

## Pasos para Arreglar el Frontend

### 1. Desplegar el Contrato ROSCA

Una vez tengamos el contrato desplegado, obtendremos una dirección como:
```
Deployed to: 0x1234567890abcdef...
```

### 2. Actualizar la Dirección en el Frontend

Editar `/home/robvox/evolve-deployment/frontend/app.js`:

```javascript
// Línea 23 - Actualizar con la dirección real del contrato desplegado
const CONTRACT_ADDRESS = "0xDIRECCION_REAL_DEL_CONTRATO";
```

### 3. Guardar la Dirección

```bash
echo "0xDIRECCION_REAL_DEL_CONTRATO" > /home/robvox/evolve-deployment/frontend/.rosca-address
```

### 4. Ejecutar las Pruebas de Integración

```bash
cd /home/robvox/evolve-deployment
python3 test_rosca_integration.py
```

Esto generará `frontend/rosca_test_results.json` con todos los resultados.

### 5. Iniciar el Frontend

```bash
cd frontend
python serve.py
# Abrir http://localhost:8000
```

## Arreglar el Problema del Balance

El frontend muestra "-" porque no puede obtener el balance del contrato. Esto se debe a que:

1. El contrato no está desplegado en la dirección configurada
2. O la conexión con MetaMask no está funcionando correctamente

**Solución:**
- Asegúrate de que MetaMask esté conectado a la red correcta (Chain ID: 1234)
- Agrega la red personalizada en MetaMask:
  - Network Name: Evolve Local
  - RPC URL: http://localhost:8545
  - Chain ID: 1234
  - Currency Symbol: ETH

## Arreglar el Botón "Run Integration Tests"

El servidor HTTP simple (`serve.py`) no soporta POST requests. Hay dos opciones:

### Opción A: Ejecutar las Pruebas Manualmente

```bash
cd /home/robvox/evolve-deployment
python3 test_rosca_integration.py
# Luego refrescar el frontend
```

### Opción B: Actualizar el Servidor (Más Complejo)

Necesitaríamos modificar `serve.py` para soportar POST requests y ejecutar el script de pruebas.

## Comandos Útiles para Diagnóstico

```bash
# Ver balance de la cuenta del genesis
curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x24150227Be6732d4D82B4711Cceddd555b0524C0","latest"],"id":1}'

# Ver si un contrato está desplegado
curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["0xDIRECCION_CONTRATO","latest"],"id":1}'

# Ver el número de bloque actual
curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Ver el estado de Celestia
docker exec celestia-node celestia state balance --node.store /home/celestia
```

## Próximos Pasos Recomendados

1. **Obtener la clave privada del sequencer** o de la cuenta del genesis
2. **Desplegar el contrato ROSCA** con esa clave
3. **Actualizar la dirección** en `frontend/app.js`
4. **Ejecutar las pruebas** manualmente
5. **Verificar el frontend** en http://localhost:8000

## Información de la Cuenta del Genesis

- **Dirección**: `0x24150227Be6732d4D82B4711Cceddd555b0524C0`
- **Balance**: `0x4a47e3c12448f4ad000000` (aproximadamente 100,000,000 ETH)
- **Ubicación**: `/home/robvox/evolve-deployment/stacks/single-sequencer/genesis.json`

**NOTA**: La clave privada de esta cuenta debería estar documentada en algún lugar del proyecto o fue generada durante la configuración inicial del sequencer.
