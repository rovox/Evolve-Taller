# Copilot Instructions for evolve-demo

## Project Overview
- **evolve-demo** is a modular rollup stack integrating:
  - **Reth** (Ethereum execution client)
  - **Celestia** (data availability layer)
  - **EV-Node** (sovereign rollup sequencer)
  - **Blockscout** (block explorer)
  - **Frontend** (React + Vite), only used for testing and demostration
  - **Smart contracts** (Solidity, Foundry)

## Architecture & Key Workflows
- **Service orchestration**: Managed via Docker Compose and the Tilt dashboard (https://tilt.dev/). Use `tilt up` to start all services, `tilt down` to stop.
- **Endpoints**:
  - Reth: `http://localhost:8545` (JSON-RPC)
  - Celestia: `http://localhost:26658`
  - EV-Node: `http://localhost:7331`
  - Blockscout: `http://localhost:80`
- **Monitoring**: Tilt dashboard at `http://localhost:10350`.
- **Load testing**: Use the `spamoor` tool (see README for build/run instructions).
- **Smart contract dev**: Use Foundry (`forge build`, `forge test`, `forge script ...`).
- **Frontend dev**: Standard Vite/React workflow in `frontend/`.

## Conventions & Patterns
- **Docker Compose**: Three main files for different stacks (`docker-compose.celestia.yml`, etc.).
- **Chain config**: `chain/genesis.json` and related files for rollup chain setup.
- **Solidity**: Contracts in `src/`, tests in `test/`, deployment scripts in `script/`.
- **Frontend**: TypeScript, React, Vite. Main entry: `frontend/src/main.tsx`.
- **Environment**: Use `.env` files for secrets/config (see `rwa-soberano-evolve/README.md`).

## Integration & Cross-Component Notes
- **Contracts** interact with the rollup via Reth/EV-Node endpoints.
- **Frontend** communicates with deployed contracts using ABIs in `frontend/src/abis/`.
- **Celestia** is used as the DA layer for the rollup chain; see `celestia-start.sh` and related scripts.
- **Blockscout** provides explorer functionality for the rollup chain.

## Examples
- Start stack: `tilt up`
- Test Reth: `curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq .`
- Build contracts: `cd rwa-soberano-evolve && forge build`
- Run frontend: `cd frontend && npm install && npm run dev`

## Troubleshooting
- Common issues: port conflicts, Docker network errors, permission issues (see main README).
- Clean reset: `tilt down && docker system prune -a && docker volume prune`

## References
- Main architecture: `README.md`
- Smart contract workflow: `rwa-soberano-evolve/README.md`
- Frontend: `frontend/README.md`
- Chain config: `chain/`
- Scripts: `*.sh`, `script/`

---
For more details, see the referenced READMEs and scripts in each directory.
