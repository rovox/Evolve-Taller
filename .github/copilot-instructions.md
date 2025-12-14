# Copilot instructions for this repo

Full-stack ROSCA (Rotating Savings and Credit Association) dApp built on a local EVM sequencer + Celestia DA devnet. The project combines smart contracts (Foundry), a vanilla JS frontend (ethers.js), and Docker-orchestrated infrastructure (ev-reth + ev-node + Celestia light node).

## Project structure
- **contracts/**: Foundry workspace with `ROSCA.sol` (core contract), tests, and deployment scripts
- **frontend/**: HTML/CSS/JS interface using ethers.js and MetaMask
- **stacks/**: Docker Compose services for infrastructure (DA layer, EVM sequencer, explorer, faucet)
- **scripts/**: E2E verification tooling (`verify_e2e.sh` uses cast/forge without destroying state)

## Architecture: Infrastructure
Single Docker network `evstack_shared`. Startup sequence: Celestia → Sequencer → Optional extras.

**Celestia DA** (`stacks/da-celestia/`):
- Light node connects to public Mocha testnet (`rpc-mocha.pops.one:9090`)
- Idempotent init in `entrypoint.da.sh` auto-fetches trusted height/hash; guards with `/home/celestia/.initialized`
- RPC at http://localhost:26658 with `--rpc.skip-auth` (dev-only)
- Health: JSON-RPC `header.LocalHead` method

**EVM Sequencer** (`stacks/single-sequencer/`):
- Two init containers create secrets: `jwt-init-sequencer` (volume `jwttoken-sequencer`), `passphrase-init-sequencer` (volume `passphrase-sequencer`)
- `ev-reth-sequencer`: execution engine at http://localhost:8545 (HTTP RPC), :8551 (AuthRPC), :9001 (metrics)
- `single-sequencer` (ev-node): idempotent init in `entrypoint.sequencer.sh`, exports `/volumes/sequencer_export/genesis.json`, auto-resolves `EVM_GENESIS_HASH` if unset
- Publishes blobs to Celestia using namespaces from `.env`

**Extras** (`stacks/eth-explorer/`, `stacks/eth-faucet/`): Blockscout + Postgres/Redis, and a simple faucet (optional)

## Architecture: Smart Contracts (ROSCA)
`contracts/src/ROSCA.sol` implements a pasanaku/tanda system:
- **Key structs**: `Group` (nested mappings for members/contributions/payouts), `Contribution`, `Payout`
- **Core functions**: `createGroup()`, `joinGroup()`, `contribute()`, `distributePayout()` (pseudo-random winner selection from eligible members)
- **View functions**: `getGroupInfo()`, `getGroupMembers()`, `getMemberContribution()`, `getContractBalance()` — added for frontend integration
- **Events**: `GroupCreated`, `MemberJoined`, `ContributionMade`, `PayoutDistributed`, `GroupCompleted`
- Payment enforcement: `joinGroup()` requires `msg.value == monthlyAmount`, `contribute()` auto-distributes payout when all members pay

## Developer workflows
**Quick start**:
1. Copy `.env.example` → `.env` in each `stacks/` subfolder (da-celestia, single-sequencer, optional extras)
2. `make start` — starts core with health checks (waits for Celestia on :26658 and EVM on :8545)
3. `make start-extras` — (optional) launches explorer (:3000) and faucet (:8081)

**Logging** (new granular targets):
- `make logs` — last 200 lines from DA + sequencer
- `make logs-reth`, `make logs-evnode` — focused logs per container
- `make logs-da`, `make logs-sequencer` — follow mode

**Contracts**:
- `cd contracts && forge test` — comprehensive tests in `test/ROSCA.t.sol`
- `forge script script/DeployROSCA.s.sol --broadcast --rpc-url http://localhost:8545 --private-key <key>` — deploy to local EVM
- After deploy, contract address is saved to `contracts/.rosca-address` (frontend reads this)

**E2E verification**: `make verify-e2e` (requires `export PRIVATE_KEY=0x...`) — non-destructive cast/forge checks reusing existing infra

**Cleanup**: `make stop` (keeps volumes), `make stop-with-volumes` (destroys state), `make clean` (drops all named volumes + prunes networks)

## Configuration patterns
- All `.env` files excluded from Git; use `.env.example` templates
- Secrets auto-generated at runtime: JWT (openssl rand), passphrase (random, mounted from volumes)
- **Critical for DA**: Sequencer needs TIA testnet funds. Check logs for signer address: `docker logs single-sequencer | grep "signer address"`, then fund via Mocha faucet
- Celestia entrypoint auto-fetches trusted sync point from RPC (can override with `DA_TRUSTED_HEIGHT`/`DA_TRUSTED_HASH` in `.env`)
- Sequencer entrypoint auto-resolves `EVM_GENESIS_HASH` from Reth if unset

## Cross-component wiring
- Sequencer → Reth: `--evm.engine-url http://ev-reth-sequencer:8551`, `--evm.eth-url http://ev-reth-sequencer:8545`, JWT at `/root/jwt/jwt.hex`
- Sequencer → Celestia: `--evnode.da.address http://celestia-node:26658`, namespaces from `${SEQUENCER_DA_HEADER_NAMESPACE}` and `${SEQUENCER_DA_DATA_NAMESPACE}`
- Frontend → EVM: connects to http://localhost:8545 via ethers.js
- Exported genesis: `stacks/single-sequencer/genesis.json` (chain config), also copied to `/volumes/sequencer_export/genesis.json`

## Health checks and debugging
- **Celestia**: `curl -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"header.LocalHead"}' http://localhost:26658`
- **EVM**: `curl -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545`
- **Common issues**:
  - Sequencer can't publish blobs: insufficient TIA funds in signer wallet (check `docker logs single-sequencer | grep "insufficient funds"`)
  - Port conflicts: Anvil and ev-reth both default to :8545 — don't run Anvil alongside the stack
  - Init errors: check JWT/passphrase mounts, verify `entrypoint.sequencer.sh` logs

## Frontend specifics
- Vanilla JS + ethers.js v6 in `frontend/app.js`
- MetaMask required; supports local network (Chain ID 1234 default, configurable)
- Reads deployed contract address from `contracts/.rosca-address` (generated by deploy script)
- Event listeners for real-time updates (`GroupCreated`, `ContributionMade`, etc.)
- Serve with `python -m http.server 8000` or `npx serve .`

## Known gotchas
- Volumes persist state (Celestia keys, JWT, passphrase, Reth chaindata). Use `make clean` only for full reset
- If sequencer stalls after restart: check `/root/.evm-single/config`, ensure `EVM_GENESIS_HASH` matches Reth genesis
- Obsolete files: `stacks/da-celestia/entrypoint.init-{2,3}.sh` were for celestia-appd (removed; only light node now)
- Celestia RPC uses `--rpc.skip-auth` (dev-only, never production)
## Blob publishing verification (Celestia DA)
**Automatic publishing**: Sequencer batches EVM blocks and submits to Celestia DA every 30 blocks (configurable via `SEQUENCER_DA_START_HEIGHT` in `.env`)

**Verify blob submission**:
- Check sequencer logs: `docker logs single-sequencer | grep "submitting headers to DA"` (shows batches sent)
- Manual blob test: `curl -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"blob.Submit","params":[[{"namespace":"AAAAAAAAAAAAAAAAAAAAAAAAAGV2b2x2ZXRscgA=","data":"SGVsbG8gZnJvbSBFdm9sdmUgVGFsbGVy","share_version":0}],{"gas_price":0.002}]}' http://localhost:26658`
- Returns Celestia block height on success

**Verify on Celenium explorer**:
1. Get tx hash from EVM: `cast receipt <tx_hash> --rpc-url http://localhost:8545` after deploying contracts
2. Find corresponding Celestia height in sequencer logs: `docker logs single-sequencer | grep "blob submitted" -A 2`
3. View on https://mocha.celenium.io/block/<height> (Mocha-4 testnet)

**Key config for blob publishing** (in `stacks/single-sequencer/.env`):
- `SEQUENCER_DA_START_HEIGHT`: Celestia height to start publishing from (use recent height ~9115000+)
- `SEQUENCER_DA_HEADER_NAMESPACE`, `SEQUENCER_DA_DATA_NAMESPACE`: base64-encoded namespace IDs (default: `AAAAAAAAAAAAAAAAAAAAAAAAAGV2b2x2ZXRscgA=`)
- Namespace corresponds to `evolvetlr` in plain text

**Tested wallet**: `celestia19f8j7rdes7rfnvlmsgafrpjxhgjayln9jqg6y6` (Mocha-4 testnet, must be funded via faucet)