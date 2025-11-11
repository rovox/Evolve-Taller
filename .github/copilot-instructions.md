# Copilot instructions for this repo

Local devnet orchestrated with Docker Compose (based on ev-toolbox). Goal: bring up Celestia DA + EVM single sequencer (Reth) locally, with optional Explorer/Faucet.

## Architecture at a glance
- Single network: `evstack_shared`. Bring-up order: Celestia → Sequencer → Extras.
- Celestia stack (in `stacks/da-celestia/`): three init containers, then run stage
  - `init-1-permission` → `entrypoint.init-2.sh` (init, download genesis, enable gRPC 0.0.0.0:9090) → `entrypoint.init-3.sh` (snapshot download/unpack; writes `_created_by_init_script`).
  - `entrypoint.da.sh` starts light node, writes `.initialized`, normalizes `[State]` and forces `TxWorkerAccounts = 8` to prevent duplicated TxWorkers on restarts.
- Sequencer stack (in `stacks/single-sequencer/`):
  - `jwt-init-sequencer` creates `/jwt/jwt.hex`. `ev-reth-sequencer` exposes HTTP:8545, AuthRPC:8551, Metrics:9001.
  - `entrypoint.sequencer.sh` initializes on first run, exports `/volumes/sequencer_export/genesis.json`, auto-resolves `EVM_GENESIS_HASH` from Reth when unset.
- Extras: Blockscout (+ Postgres + Redis) and Faucet in `stacks/eth-explorer/` and `stacks/eth-faucet/`.

## Files to know + ports
- Orchestration: `Makefile` (health-gated startup), shared logger `lib/logging.sh`.
- Celestia: `stacks/da-celestia/docker-compose.yml`, `entrypoint.init-2.sh`, `entrypoint.init-3.sh`, `entrypoint.da.sh`, `.env`.
- Sequencer: `stacks/single-sequencer/docker-compose.yml`, `entrypoint.sequencer.sh`, `genesis.json`, `passphrase`.
- Endpoints: Celestia http://localhost:26658 · Reth http://localhost:8545 · Explorer http://localhost:3000 · Faucet http://localhost:8081.

## Everyday workflows (Make targets)
- Start core with health checks: `make start` (waits on 26658 and eth_chainId on 8545).
- Start extras: `make start-extras` (asserts 8545 first). Inspect: `make status`, `make logs`, `make logs-da`, `make logs-sequencer`, `make logs-extras`.
- Stop/Clean: `make stop`, `make stop-with-volumes`, `make clean` (removes named volumes and prunes networks).

## Configuration and secrets
- Per-stack `.env`:
  - Celestia: `DA_CORE_IP`, `DA_CORE_PORT`, `DA_NETWORK`, `DA_RPC_PORT`, `DA_TRUSTED_HEIGHT`, `DA_TRUSTED_HASH`, `DA_HEADER_NAMESPACE`, `DA_DATA_NAMESPACE`, optional `SNAPSHOT_URL`.
  - Sequencer: `SEQUENCER_DA_HEADER_NAMESPACE`, `SEQUENCER_DA_DATA_NAMESPACE`, `EVM_ENGINE_URL`, `EVM_ETH_URL`, `EVM_JWT_SECRET_FILE`, `EVM_BLOCK_TIME`.
  - Explorer: `EXPLORER_POSTGRES_PASSWORD`, DB hosts/ports, `RETH_HOST(_HTTP/_WS)_PORT`, `CHAIN_ID`, `EXPLORER_FRONTEND_PORT`.
  - Faucet: `ETH_FAUCET_PORT` (defaults `WEB3_PROVIDER` to `http://ev-reth-sequencer:8545`).
- Secrets: signer passphrase at `stacks/single-sequencer/passphrase`; JWT lives in volume `jwttoken-sequencer`.

## Cross-component interfaces
- Celestia RPC: `celestia light start --rpc.addr=0.0.0.0 --rpc.port=${DA_RPC_PORT}` (set by entrypoints).
- Sequencer → Reth: `--evm.engine-url http://ev-reth-sequencer:8551`, `--evm.eth-url http://ev-reth-sequencer:8545`, `--evm.jwt-secret-file /root/jwt/jwt.hex`, optional `--evm.genesis-hash`.
- Sequencer → DA: `--evnode.da.address http://celestia-node:26658`, namespaces from `${SEQUENCER_DA_HEADER_NAMESPACE}` and `${SEQUENCER_DA_DATA_NAMESPACE}`.
- Exported artifact for tooling: `/volumes/sequencer_export/genesis.json`.

## Gotchas and troubleshooting
- Celestia wallet/keys live in volumes: avoid `make clean`/`stop-with-volumes` unless you intend to lose them. To list keys: `docker exec -it celestia-node cel-key list --node.type=light`.
- If Celestia isn’t healthy: check `init-2-appd`/`init-3-snapshot` logs and verify `DA_TRUSTED_*` and `SNAPSHOT_URL`.
- If sequencer stalls: confirm `/root/.evm-single/config`, JWT mount, engine URLs, and whether `EVM_GENESIS_HASH` was resolved.
- Explorer issues: ensure Postgres/Redis are up and `RETH_HOST(_HTTP/_WS)_PORT` are set; UI is bound to `${EXPLORER_FRONTEND_PORT}:3000`.

## Extending this stack
- Add a service under `stacks/<name>/docker-compose.yml`, connect it to `evstack_shared`, and optionally add Make targets for lifecycle/logs.

References: see `README.md` for a Spanish overview and `proceso.txt` for the generation transcript. Ops notes live in `stacks/*/entrypoint*.sh` and the Makefile.

Open questions for maintainers: provide default `.env` templates for explorer/faucet? Document expected Reth WS port explicitly?
