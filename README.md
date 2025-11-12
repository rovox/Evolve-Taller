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

## Configuración inicial (PRIMERA VEZ)

⚠️ **IMPORTANTE**: Antes de iniciar el stack por primera vez, debes configurar los archivos de entorno con tus propios valores.

### 1. Copiar archivos de plantilla

Ejecuta los siguientes comandos para crear tus archivos de configuración desde las plantillas:

```bash
# Copiar archivos .env
cp stacks/da-celestia/.env.example stacks/da-celestia/.env
cp stacks/single-sequencer/.env.example stacks/single-sequencer/.env
cp stacks/eth-explorer/.env.example stacks/eth-explorer/.env
cp stacks/eth-faucet/.env.example stacks/eth-faucet/.env

# Copiar passphrase
cp stacks/single-sequencer/passphrase.example stacks/single-sequencer/passphrase
```

### 2. Generar valores seguros

Genera credenciales únicas para tu deployment:

```bash
# Para passphrase del secuenciador
openssl rand -base64 32

# Para SECRET_KEY_BASE del explorador
openssl rand -base64 64

# Para contraseña de PostgreSQL
openssl rand -hex 16
```

### 3. Editar archivos de configuración

Edita cada archivo `.env` y `passphrase` para reemplazar los valores de ejemplo:

- **`stacks/da-celestia/.env`**: 
  - Genera tus propios `DA_HEADER_NAMESPACE` y `DA_DATA_NAMESPACE` únicos
  - Actualiza `DA_TRUSTED_HEIGHT` y `DA_TRUSTED_HASH` desde [Celestia Mocha](https://mocha.celenium.io/)

- **`stacks/single-sequencer/.env`**:
  - Usa los MISMOS namespaces que configuraste en `da-celestia/.env`
  - Ajusta `SEQUENCER_DA_START_HEIGHT` para que coincida con `DA_TRUSTED_HEIGHT`

- **`stacks/single-sequencer/passphrase`**:
  - Reemplaza con el passphrase generado en el paso 2

- **`stacks/eth-explorer/.env`**:
  - Configura `EXPLORER_POSTGRES_PASSWORD` con una contraseña segura
  - Configura `SECRET_KEY_BASE` con la clave generada

- **`stacks/eth-faucet/.env`**:
  - Genera una nueva clave privada (con MetaMask o `cast wallet new`)
  - ⚠️ Nunca uses una clave que contenga fondos reales

### 4. Verificar la configuración

Una vez editados todos los archivos, verifica que:
- Los namespaces sean idénticos entre `da-celestia/.env` y `single-sequencer/.env`
- Todos los valores `XXXXXXX` hayan sido reemplazados
- El archivo `passphrase` contenga solo el passphrase (sin comentarios)

---

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

## Seguridad

Este repositorio incluye protección para información sensible mediante `.gitignore`. Los archivos `.env` y `passphrase` **NO** deben incluirse en Git.

Para más información sobre prácticas de seguridad, consulta: **[SECURITY.md](SECURITY.md)**

⚠️ **Recordatorio**: Nunca compartas tus archivos `.env` reales o el archivo `passphrase`.

## Créditos
- Basado en ev-toolbox (EVStack). Este repo añade hardening en la inicialización de Celestia para evitar duplicaciones en `[State]` y facilita el flujo local con Makefile.
