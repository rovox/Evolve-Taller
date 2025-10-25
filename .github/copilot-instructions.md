# Copilot Instructions for Evolve-Taller

Below are concise, repo-specific instructions to help an AI coding agent be immediately productive.

## High-level Architecture

- **Tilt-driven dev loop**: `Tiltfile` composes three docker-compose files: `docker-compose.reth.yml`, `docker-compose.celestia.yml`, `docker-compose.evolve.yml`. JWTs and secret files are exchanged through the `jwt-tokens`/`/shared` volume.
- **Smart contracts** (Foundry): `rwa-soberano-evolve/` uses a **modular architecture** to stay under the 24KB EVM contract size limit.
- **Frontend** (React + Vite): `frontend/` — static ABIs in `frontend/src/abis/`, entry point at `frontend/src/App.tsx`.
- **Orchestration scripts**: `scripts/` ties the stack together (deployment, testing, address sync).

## Smart Contract Architecture (CRITICAL)

The RWA contracts use a **modular design pattern** to overcome EVM bytecode size limits. Understanding this structure is essential:

```
rwa-soberano-evolve/src/
├── core/                          # Base contract modules (inheritance chain)
│   ├── RWATokenCore.sol          # Asset management + ERC1155 base + AccessControl
│   ├── RWATokenMinting.sol       # Mint/burn operations + shareholder tracking
│   └── RWATokenQueries.sol       # View functions for asset/shareholder queries
├── extensions/                    # Feature extensions
│   ├── RWATokenSales.sol         # Public sale logic (buyShares) + payment processing
│   └── RWATokenAdmin.sol         # Pausable + emergency controls + role management
├── libraries/                     # External libraries (not deployed)
│   ├── RWAStorage.sol            # Shared structs (Asset, SaleConfig, etc.)
│   ├── RWAMath.sol               # Pure math functions (share calculations, etc.)
│   └── RWAValidation.sol         # Input validation helpers
├── RWAToken.sol                  # Main facade contract (v2.0.0-modular)
├── DocumentRegistry.sol          # Document hash registry
├── RWASovereignRollup.sol        # Rollup governance contract
└── DividendDistributor.sol       # Dividend distribution logic
```

### Modular Contract Inheritance Chain

```
RWAToken.sol (facade)
├─ RWATokenQueries
│  └─ RWATokenMinting
│     └─ RWATokenCore (ERC1155, Ownable, AccessControl)
├─ RWATokenSales (ReentrancyGuard + SafeERC20)
└─ RWATokenAdmin (Pausable)
```
# Copilot instructions for Evolve-Taller (concise)

This file gives actionable, repo-specific guidance so an AI coding agent can be productive quickly.

Core architecture (high level)
- Tilt-driven dev loop: `Tiltfile` composes three stacks (`docker-compose.reth.yml`, `docker-compose.celestia.yml`, `docker-compose.evolve.yml`) and shares secrets via `/shared`.
- Tilt-driven dev loop: `Tiltfile` composes three stacks (`docker-compose.reth.yml`, `docker-compose.celestia.yml`, `docker-compose.evolve.yml`) and shares secrets via `/shared`. Note: Celestia-specific JWTs are stored under `/shared/jwt/celestia-jwt.token` (see `scripts/celestia-fund.sh` and `Tiltfile` references).
- Smart contracts (Foundry): `rwa-soberano-evolve/` uses a modular facade pattern (see `rwa-soberano-evolve/src/` — `core/`, `extensions/`, `libraries/`, plus `RWAToken.sol`). Keep changes small to stay under the 24KB contract limit.
- Frontend (React + Vite): `frontend/` — static ABIs live in `frontend/src/abis/`. Entry points: `frontend/src/App.tsx` and `frontend/src/config/wagmi.ts`.

Key developer workflows (commands to run)
- Start full local stack: `tilt up` (or `tilt up --reth-only` to skip Celestia/rollup).
- Contract unit tests: `cd rwa-soberano-evolve && forge test -vv`.
- Manual deploy (dev RPC alias `reth`):
  `cd rwa-soberano-evolve && forge script script/Deploy.s.sol --rpc-url reth --broadcast`
- Frontend dev: `cd frontend && npm ci && npm run dev`.
- Integration smoke test (requires `cast`/Foundry tools): `./scripts/test-rwa-integration.sh` — this also demonstrates owner-routing and address sync.

Project-specific conventions (do not assume defaults)
- Deployment addresses must be written to `rwa-soberano-evolve/deployed-addresses.env`. Sync them to the UI with `scripts/sync-contract-addresses.sh` (copies into `frontend/public/deployed-addresses.env`).
- Frontend expects static ABI JSON in `frontend/src/abis/` — update the ABI copy task when contract filenames change.
  - ABI generation/copy: build contracts with `forge build` (produces `out/`), then copy selected JSON ABI files into `frontend/src/abis/`. See `scripts/deploy-rwa-contracts.sh` and `rwa-soberano-evolve/script/` for helpers that extract ABIs and write `deployed-addresses.env`.
- Contract structure rules: add new features to `core/`, `extensions/`, or `libraries/`. Add storage changes to `RWAStorage.sol` and math to `RWAMath.sol` to minimize bytecode growth.
- After contract edits run: `./scripts/verify-contract-sizes.sh` to avoid exceeding 24KB.

Integration & automation (important files)
- `Tiltfile` — resource ordering, health checks, and which scripts run.
- `/scripts/rollup-init.sh` and `scripts/rollkit-start.sh` — create/read `/shared/rollkit.env` and start the sequencer.
- `scripts/test-rwa-integration.sh` — canonical example: owner detection, `cast` usage, tx parsing, Celestia checks.
- `rwa-soberano-evolve/script/` — JS helpers and deployment scripts.

Patterns to reuse (concrete examples)
- Owner-routing: check `owner()` on the registry; if owner == `RWASovereignRollup` address, route write calls via the RWA facade (see `scripts/test-rwa-integration.sh`).
- Safe ERC20 handling: contracts use `SafeERC20` for non-compliant tokens — follow that in JS/ts helpers when simulating payments.
- Shell scripts: prefer robust parsing (`cast send` -> regex tx hash -> `cast wait <tx>`). Use `jq` where available for receipts.

Assumptions an agent can make
- Local RPC: `http://localhost:8545` (reth). Sequencer RPC: `http://localhost:7331`.
- Chain ID for local development: 1234. `foundry.toml` contains useful RPC aliases; use them instead of hard-coded URLs.
- Secrets (`PRIVATE_KEY`, JWTs) are injected via Tilt into `/shared`; do not embed secrets in code.

If any rule or workflow here is unclear, tell me which area (deploy, ABIs, owner-routing, or Tilt) and I will expand with exact code/script snippets.
Developer assumptions the agent can make
