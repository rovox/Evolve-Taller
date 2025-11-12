# Evolve Deployment (Devnet local con Celestia + EVM)

Este repositorio levanta un entorno local con Docker Compose para desarrollar sobre un secuenciador EVM que publica datos en Celestia (Mocha). Se consolidó toda la documentación en este único archivo para simplificar el onboarding y la operación.

- Proyecto base: https://github.com/evstack/ev-toolbox (adaptado)
- Red única: `evstack_shared`
- Endpoints: Celestia http://localhost:26658 · Reth http://localhost:8545 · Explorer http://localhost:3000 · Faucet http://localhost:8081

## Arquitectura (a grandes rasgos)
- Celestia DA: Light node que se conecta a Core público (`rpc-mocha.pops.one:9090`). RPC expuesto con `--rpc.skip-auth` exclusivamente para dev.
- Sequencer: `ev-node-evm-single` conectado al motor `ev-reth`. Publica blobs a Celestia usando namespaces definidos en `.env`.
- Extras opcionales: Blockscout (explorador) y Faucet.

Cambios clave aplicados recientemente:
- Simplificación de Celestia: se eliminaron contenedores de `celestia-appd`; solo queda el light node con init de una sola vez (lock `.initialized`).
- Healthcheck realista para Celestia: ahora usa JSON-RPC `p2p.Info` evitando falsos negativos.
- Seguridad integrada: `.gitignore` excluye `.env` y secretos; el passphrase del secuenciador ya no vive en el repo (se genera en runtime).
- Logs por servicio: nuevas dianas en Makefile para ver `ev-reth` y `ev-node` por separado.

## Árbol del proyecto (resumido)
```
.
├─ Makefile                      # Ciclo de vida y logs por servicio
├─ lib/
│  └─ logging.sh                 # Utilidad de logs compartida
├─ stacks/
│  ├─ da-celestia/
│  │  ├─ docker-compose.yml      # Servicio celestia-node (light)
│  │  ├─ entrypoint.da.sh        # Init idempotente + start RPC
│  │  └─ .env.example            # Plantilla de configuración DA
│  ├─ single-sequencer/
│  │  ├─ docker-compose.yml      # ev-reth + ev-node + init de passphrase/JWT
│  │  ├─ entrypoint.sequencer.sh # Init y arranque del secuenciador
│  │  ├─ genesis.json            # Cadena local
│  │  └─ .env.example            # Plantilla de configuración EVM/DA
│  ├─ eth-explorer/
│  │  └─ docker-compose.yml      # Blockscout (opcional)
│  └─ eth-faucet/
│     └─ docker-compose.yml      # Faucet (opcional)
└─ .gitignore                    # Excluye .env y secretos
```

Notas importantes:
- El archivo `passphrase` fue eliminado del repo. Ahora se genera automáticamente por un contenedor init y se guarda en un volumen llamado `passphrase-sequencer` (sin tocar Git).
- Los `.env` reales nunca se versionan; usa las plantillas `.env.example` y crea tus `.env` locales.

## Configuración
1) Copia y edita las plantillas
```bash
cp stacks/da-celestia/.env.example stacks/da-celestia/.env
cp stacks/single-sequencer/.env.example stacks/single-sequencer/.env
# (Opcional) Si usas extras:
cp stacks/eth-explorer/.env.example stacks/eth-explorer/.env
cp stacks/eth-faucet/.env.example stacks/eth-faucet/.env
```
- En `da-celestia/.env`: define `DA_HEADER_NAMESPACE`, `DA_DATA_NAMESPACE`, y (si aplica) `DA_TRUSTED_*`.
- En `single-sequencer/.env`: usa los mismos namespaces; ajusta `CHAIN_ID` y `SEQUENCER_DA_START_HEIGHT`.
- En `eth-explorer/.env`: genera `EXPLORER_POSTGRES_PASSWORD` y `SECRET_KEY_BASE`.
- En `eth-faucet/.env`: usa una clave privada solo de pruebas.

2) No necesitas crear `passphrase`: el compose genera uno aleatorio automáticamente y lo monta en el secuenciador.

## Arranque y verificación
- Arranque core con health checks:
```bash
make start
```
- Servicios extra (requiere core arriba):
```bash
make start-extras
```
- Estado y logs (targets útiles):
```bash
make status          # ps de cada stack
make logs-da         # logs de celestia-node
make logs-reth       # logs del motor ev-reth
make logs-evnode     # logs del nodo ev-node
make logs-sequencer  # logs de todo el stack del secuenciador
```

### Uso manual (sin Makefile)
- Celestia:
```bash
(cd stacks/da-celestia && docker compose up -d)
# Salud: RPC JSON-RPC p2p.Info
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"p2p.Info"}' \
  http://localhost:26658 | jq '.'
```
- Sequencer (ev-reth + ev-node):
```bash
(cd stacks/single-sequencer && docker compose up -d)
# Verificar EVM
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545 | jq '.'
```
- Extras:
```bash
(cd stacks/eth-explorer && docker compose up -d)
(cd stacks/eth-faucet && docker compose up -d)
```
- Logs manuales por servicio:
```bash
(cd stacks/da-celestia && docker compose logs -f da)
(cd stacks/single-sequencer && docker compose logs -f ev-reth-sequencer)
(cd stacks/single-sequencer && docker compose logs -f single-sequencer)
```

## Cambios técnicos relevantes (resumen)
- Celestia:
  - Se eliminó `celestia-appd` del stack; el light node se conecta a Mocha Core público.
  - Healthcheck actualizado a `p2p.Info`; `TLSEnabled=false` por compatibilidad con el endpoint.
  - Se corrigió la duplicación de `State.TxWorkerAccounts` en `config.toml` (init idempotente).
- Sequencer:
  - Sidecar `jwt-init-sequencer` genera `jwt.hex` para AuthRPC.
  - NUEVO sidecar `passphrase-init-sequencer` que crea el passphrase en un volumen dedicado.
  - `entrypoint.sequencer.sh` resuelve automáticamente el `EVM_GENESIS_HASH` desde Reth si no se define.
- Makefile:
  - Nuevos targets `logs-reth` y `logs-evnode`; `logs` ahora muestra resumen y deja el seguimiento a targets específicos.
- Seguridad:
  - `.gitignore` excluye `.env` y secretos; no hay passphrase en el repo.

## Solución de problemas (rápido)
- Celestia no “healthy”: revisa `p2p.Info`, `DA_CORE_*` y que el archivo `.initialized` exista en el volumen.
- Sequencer no produce bloques: valida JWT montado, URLs del engine (`8551`) y ETH (`8545`), y namespaces de DA.
- Explorer/Faucet: asegúrate que el sequencer esté arriba y que las variables de conexión estén correctas.

## Créditos
Basado en EVStack. Adaptado y endurecido para un flujo local coherente, con generación automática de secretos (JWT/passphrase), health-checks reales y documentación unificada en este README.
