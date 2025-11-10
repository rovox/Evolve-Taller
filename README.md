# Evolve Deployment (basado en ev-toolbox)

Este repositorio contiene una infraestructura de devnet local orquestada con Docker Compose. Está basada en ev-toolbox:

- Proyecto base: https://github.com/evstack/ev-toolbox
- El proceso seguido para generar este repo está documentado en `proceso.txt` (transcripción íntegra de la instalación interactiva).

## Arquitectura (resumen)
- Red compartida: `evstack_shared`.
- Componentes principales:
  - Celestia DA (light node + celestia-appd) en `stacks/da-celestia/`.
  - Secuenciador EVM (ev-node-evm-single) + motor Reth en `stacks/single-sequencer/`.
  - Extras opcionales: Blockscout (BE/FE/stats + Postgres + Redis) en `stacks/eth-explorer/` y faucet en `stacks/eth-faucet/`.
- Orden de arranque: Celestia → Secuenciador → Extras.

## Mejora aplicada: Celestia TxWorkers duplicados
Se detectó un problema donde, tras reinicios, la configuración de Celestia regeneraba entradas bajo la sección `[State]`, provocando duplicación de TxWorkers.

- Solución implementada en `stacks/da-celestia/entrypoint.da.sh`:
  - Inicialización idempotente con un archivo candado `~/.initialized`.
  - Normalización de `TxWorkerAccounts` dentro de `[State]` para que quede forzado a `8` y sin duplicados en el bloque de configuración relevante.
  - Actualización controlada de `TrustedHash`, `SampleFrom` y `DASer.SampleFrom`.

Con esto, los reinicios no vuelven a duplicar la configuración y el light node queda consistente.

## Estructura del repo
- `Makefile`: tareas de ciclo de vida (start/stop/logs/status/clean).
- `lib/logging.sh`: helper de logging compartido entre entrypoints.
- `stacks/da-celestia/`: compose y entrypoints para celestia-appd y light node.
- `stacks/single-sequencer/`: compose del secuenciador, `genesis.json` y `passphrase`.
- `stacks/eth-explorer/`, `stacks/eth-faucet/`: servicios opcionales.
- `proceso.txt`: pasos seguidos para generar este despliegue.

## Uso básico
- Iniciar core (Celestia + Secuenciador) y esperar health checks:
```bash
make start
```
- Iniciar servicios extra (requiere el secuenciador activo):
```bash
make start-extras
```
- Estado y logs:
```bash
make status
make logs        # Core
make logs-da     # Celestia
make logs-sequencer
make logs-extras
```
- Parar y limpiar:
```bash
make stop
make stop-with-volumes   # ¡Ver advertencia de volúmenes!
make clean               # Elimina volúmenes y redes
```

## Advertencia importante sobre volúmenes (wallet Celestia)
Se recomienda NO borrar los volúmenes una vez inicializado el repositorio, ya que allí se guarda la configuración de la wallet de Celestia que genera `celestia-node` con la herramienta `cel-key`. Si elimina los volúmenes, perderá las llaves.

- Para listar las claves del light node:
```bash
docker exec -it celestia-node cel-key list --node.type=light
```

## Endpoints locales
- Celestia DA RPC: http://localhost:26658
- Reth (JSON-RPC): http://localhost:8545
- Blockscout (frontend): http://localhost:3000
- Faucet: http://localhost:8081

## Créditos
- Basado en ev-toolbox (EVStack). Este repo añade hardening en la inicialización de Celestia para evitar duplicaciones en `[State]` y facilita el flujo local con Makefile.
