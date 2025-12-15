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

## Documentación Detallada
Para una explicación profunda de todos los componentes y flujo de datos, ver [ARCHITECTURE.md](ARCHITECTURE.md).

## Características Nuevas (Automation)
1. **Despliegue Automático de Contratos**: Al iniciar `make start`, un contenedor `contract-deployer` espera a que el sequencer esté listo y despliega ROSCA automáticamente.
2. **Actualización de DA Height**: Antes de iniciar, se consulta la API de Celestia Mocha para actualizar `DA_TRUSTED_HEIGHT` y sincronizar más rápido.
3. **Frontend Dinámico**: La UI lee automáticamente la dirección del contrato desplegado desde `.rosca-address`.

## Árbol del proyecto (resumido)
```
.
├─ Makefile                      # Ciclo de vida y logs por servicio
├─ ARCHITECTURE.md               # Documentación detallada de arquitectura
├─ scripts/
│  ├─ auto_deploy_contracts.sh   # Despliegue automático
│  └─ update_da_height.sh        # Actualización de altura DA
├─ stacks/
│  ├─ da-celestia/               # Core: Capa DA
│  ├─ single-sequencer/          # Core: Sequencer + Auto-deployer
│  ├─ eth-explorer/              # Opcional: Blockscout
│  ├─ eth-faucet/                # Opcional: Faucet
│  └─ eth-indexer/               # Deprecated: Sin uso actual
└─ frontend/                     # Dashboard de monitoreo
```

## Componentes Opcionales y Limpieza
- **eth-explorer**: Útil para debugging visual, pero consume recursos. Habilitar solo si es necesario con `make start-extras`.
- **eth-faucet**: Útil si necesitas múltiples cuentas de prueba.
- **eth-indexer**: Carpeta heredada sin funcionalidad activa. Puede ser ignorada o eliminada.

## Configuración
1) Copia y edita las plantillas
```bash
cp stacks/da-celestia/.env.example stacks/da-celestia/.env
cp stacks/single-sequencer/.env.example stacks/single-sequencer/.env
```

2) (Automático) No necesitas configurar `DA_TRUSTED_HEIGHT` manualmente, el script lo hará por ti al iniciar.

## Arranque y verificación
- Arranque core con automatización completa:
```bash
make start
```
Esto iniciará Celestia, el Sequencer y **desplegará los contratos automáticamente**.

- Verificar estado desde el frontend:
```bash
cd frontend && python3 serve.py
# Abrir http://localhost:8000
```

- Servicios extra (requiere core arriba):
```bash
make start-extras
```

- Estado y logs:
```bash
make status
make logs-da         # Logs Celestia
make logs-sequencer  # Logs Sequencer
docker logs contract-deployer # Ver logs de despliegue de contratos
```
