# Copilot instructions for this repo

Local devnet via Docker Compose:
- Celestia DA (light node + celestia-appd) → `stacks/da-celestia/`
- EVM single sequencer + Reth EL → `stacks/single-sequencer/`
- Optional: Blockscout (BE/FE/stats + Postgres + Redis) and ETH faucet → `stacks/eth-explorer/`, `stacks/eth-faucet/`

## Architecture at a glance
- Single shared network: `evstack_shared`. Bring-up: Celestia → Sequencer → Extras.
- Celestia bootstraps in 3 init steps, then runs:
  - `init-1-permission` (chown volumes) → `init-2-appd` (init, download-genesis, enable gRPC 0.0.0.0:9090) → `init-3-snapshot` (download/unpack; writes `_created_by_init_script`).
  - `app` (celestia-appd) health-gates `da` (light node). `entrypoint.da.sh` writes `.initialized` and enforces `State.TxWorkerAccounts = 8`.
- Sequencer stack:
  - `jwt-init-sequencer` creates `/jwt/jwt.hex`. `ev-reth-sequencer` exposes HTTP:8545, AuthRPC:8551, Metrics:9001.
  - `single-sequencer` (`entrypoint.sequencer.sh`) initializes on first run, exports `/volumes/sequencer_export/genesis.json`, auto-fetches `EVM_GENESIS_HASH` from Reth if unset.

## Key files and host ports
- Orchestration: `Makefile`, shared logger `lib/logging.sh`.
- Celestia: `stacks/da-celestia/docker-compose.yml`, `entrypoint.init-2.sh`, `entrypoint.init-3.sh`, `entrypoint.da.sh`, `.env`.
- Sequencer: `stacks/single-sequencer/docker-compose.yml`, `entrypoint.sequencer.sh`, `genesis.json`, `passphrase`.
- Extras: `stacks/eth-explorer/docker-compose.yml`, `stacks/eth-faucet/docker-compose.yml`.
- Endpoints: Celestia http://localhost:26658 · Reth http://localhost:8545 · Explorer http://localhost:3000 · Faucet http://localhost:8081.

## Everyday workflows
- Start core and wait for health: `make start` (probes 26658 and 8545 via curl/JSON-RPC).
- Start extras: `make start-extras` (asserts 8545). Inspect: `make status`, `make logs*`.
- Stop/Clean: `make stop`, `make stop-with-volumes`, `make clean` (removes named volumes, prunes networks).

## Configuration & secrets
- Per-stack `.env` files:
  - Celestia (`stacks/da-celestia/.env`): `DA_CORE_IP`, `DA_CORE_PORT`, `DA_NETWORK`, `DA_RPC_PORT`, `DA_TRUSTED_HEIGHT`, `DA_TRUSTED_HASH`, `DA_HEADER_NAMESPACE`, `DA_DATA_NAMESPACE`, optional `SNAPSHOT_URL`.
  - Sequencer env: `SEQUENCER_DA_HEADER_NAMESPACE`, `SEQUENCER_DA_DATA_NAMESPACE`, `EVM_ENGINE_URL`, `EVM_ETH_URL`, `EVM_JWT_SECRET_FILE`, `EVM_BLOCK_TIME`.
  - Explorer: `EXPLORER_POSTGRES_PASSWORD`, DB hosts/ports, `RETH_HOST(_HTTP/_WS)_PORT`, `CHAIN_ID`, `EXPLORER_FRONTEND_PORT`.
  - Faucet: `ETH_FAUCET_PORT` (defaults `WEB3_PROVIDER` to `http://ev-reth-sequencer:8545`).
- Secrets: signer passphrase file `stacks/single-sequencer/passphrase`; JWT in volume `jwttoken-sequencer`.

## Cross-component interfaces (examples)
- Celestia RPC: `celestia light start --rpc.addr=0.0.0.0 --rpc.port=${DA_RPC_PORT}`.
- Sequencer → Reth: `--evm.engine-url http://ev-reth-sequencer:8551`, `--evm.eth-url http://ev-reth-sequencer:8545`, `--evm.jwt-secret-file /root/jwt/jwt.hex`, optional `--evm.genesis-hash`.
- Sequencer → DA: `--evnode.da.address http://celestia-node:26658`, namespaces from `${SEQUENCER_DA_HEADER_NAMESPACE}` and `${SEQUENCER_DA_DATA_NAMESPACE}`.
- Exported artifact: `/volumes/sequencer_export/genesis.json` for tooling.

## Troubleshooting quick hits
- Celestia not up: check `init-2-appd`/`init-3-snapshot` logs, verify `DA_TRUSTED_*` and `SNAPSHOT_URL`.
- Sequencer stalls: confirm `/root/.evm-single/config`, JWT mount, engine URLs, and if `EVM_GENESIS_HASH` was resolved.
- Explorer issues: ensure DB health, Redis, and `RETH_HOST(_HTTP/_WS)_PORT` are set; UI bound to `${EXPLORER_FRONTEND_PORT}:3000`.
- Volumes: names are stack-scoped (e.g., `celestia-appd-data`, `ev-reth-sequencer-data`, `sequencer-export`); `make clean` removes them.

## Extending
- Add services under `stacks/<name>/docker-compose.yml`, attach to `evstack_shared`, and (optionally) wire Make targets for lifecycle/logs.

Open questions for maintainers: provide default `.env` templates for explorer/faucet? Document Reth WS port expectations explicitly?
