# Copilot instructions for this repo

Local devnet orchestrated with Docker Compose. Purpose: run Celestia DA + a single EVM sequencer (ev-node + ev-reth) locally, with optional Explorer and Faucet.

## Architecture
- One docker network: `evstack_shared`. Startup order: Celestia → Sequencer → Extras.
- Celestia (stacks/da-celestia): single light node `celestia-node` connects to public Core `rpc-mocha.pops.one:9090`. One-time init guarded by `/home/celestia/.initialized`. RPC binds `0.0.0.0:${DA_RPC_PORT}` with `--rpc.skip-auth`. Health uses JSON-RPC `p2p.Info` on 26658.
- Sequencer (stacks/single-sequencer):
  - `jwt-init-sequencer` creates `/jwt/jwt.hex` (volume `jwttoken-sequencer`).
  - `passphrase-init-sequencer` creates signer passphrase in volume `passphrase-sequencer` as `/passphrase/passphrase`.
  - `ev-reth-sequencer` exposes HTTP 8545, AuthRPC 8551, Metrics 9001.
  - `single-sequencer` runs `entrypoint.sequencer.sh`: idempotent init, exports `/volumes/sequencer_export/genesis.json`, auto-resolves `EVM_GENESIS_HASH` from Reth if unset.
- Extras: Blockscout (explorer) + Postgres + Redis, and Faucet under `stacks/eth-explorer/` and `stacks/eth-faucet/`.

## Files + endpoints
- Orchestration: `Makefile` (health-gated start, log tails), `lib/logging.sh`.
- Celestia: `stacks/da-celestia/docker-compose.yml`, `entrypoint.da.sh`, `.env`.
- Sequencer: `stacks/single-sequencer/docker-compose.yml`, `entrypoint.sequencer.sh`, `genesis.json`.
- Endpoints: Celestia http://localhost:26658 · EVM (Reth) http://localhost:8545 · Explorer http://localhost:3000 · Faucet http://localhost:8081.

## Developer workflows (Make targets)
- Start core with health checks: `make start` (waits on 26658 + `eth_chainId`).
- Extras: `make start-extras` (requires 8545 up). Inspect: `make status`, `make logs`, `make logs-da`, `make logs-sequencer`, and focused `make logs-reth`, `make logs-evnode`, `make logs-extras`.
- Stop/Clean: `make stop`, `make stop-with-volumes`, `make clean` (drops named volumes + prunes networks).

## Configuration and secrets
- Celestia `.env`: `DA_CORE_IP` (rpc-mocha.pops.one), `DA_CORE_PORT` (9090), `DA_NETWORK` (mocha), `DA_RPC_PORT`, `DA_TRUSTED_HEIGHT`, `DA_TRUSTED_HASH`.
- Sequencer `.env`: `SEQUENCER_DA_HEADER_NAMESPACE`, `SEQUENCER_DA_DATA_NAMESPACE`, `EVM_ENGINE_URL`, `EVM_ETH_URL`, `EVM_BLOCK_TIME`. JWT is provided via volume at `/root/jwt/jwt.hex`; passphrase via volume at `/root/passphrase/passphrase` and passed as `EVM_SIGNER_PASSPHRASE_FILE`.
- Explorer `.env`: `EXPLORER_POSTGRES_PASSWORD`, DB hosts/ports, `RETH_HOST(_HTTP/_WS)_PORT`, `CHAIN_ID`, `EXPLORER_FRONTEND_PORT`.
- Faucet `.env`: `ETH_FAUCET_PORT` (defaults provider to `http://ev-reth-sequencer:8545`).

## Cross-component wiring
- Celestia RPC: `celestia light start ... --rpc.addr=0.0.0.0 --rpc.port=${DA_RPC_PORT} --rpc.skip-auth` (entrypoint-managed).
- Sequencer → Reth: `--evm.engine-url http://ev-reth-sequencer:8551`, `--evm.eth-url http://ev-reth-sequencer:8545`, `--evm.jwt-secret-file /root/jwt/jwt.hex`, optional `--evm.genesis-hash`.
- Sequencer → DA: `--evnode.da.address http://celestia-node:26658`, namespaces from `${SEQUENCER_DA_HEADER_NAMESPACE}` and `${SEQUENCER_DA_DATA_NAMESPACE}`.
- Exported artifact for tooling: `/volumes/sequencer_export/genesis.json`.

## Blob publishing + health
- Sequencer publishes blobs to Celestia via `DA_ADDRESS=http://celestia-node:26658`.
- Celestia JSON-RPC includes `blob.Submit` (prefer client libs for encoding). Quick health checks:
  - Celestia: POST `{method:"p2p.Info"}` to http://localhost:26658.
  - EVM: POST `eth_chainId` to http://localhost:8545.

## Gotchas
- Volumes hold state (Celestia keys, JWT, passphrase). Avoid `make clean`/`stop-with-volumes` unless you intend to reset.
- If sequencer stalls: check `/root/.evm-single/config`, JWT/passphrase mounts, engine URLs, and that `EVM_GENESIS_HASH` resolved.

## Obsolete files
- `stacks/da-celestia/entrypoint.init-2.sh` and `entrypoint.init-3.sh` were for celestia-appd; current compose only runs the light node.
