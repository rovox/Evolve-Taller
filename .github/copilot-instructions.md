# Copilot Instructions for Evolve-Taller
```markdown
# Copilot Instructions for Evolve-Taller (updated)

Below are concise, repo-specific instructions to help an AI coding agent be immediately productive.

High level
- Tilt-driven dev loop: `Tiltfile` composes three docker-compose files: `docker-compose.reth.yml`, `docker-compose.celestia.yml`, `docker-compose.evolve.yml`. JWTs and secret files are exchanged through the `jwt-tokens`/`/shared` volume.
- Smart contracts live in `rwa-soberano-evolve/` (Foundry). Frontend is `frontend/` (React + Vite). Scripts that tie the stack together are in `scripts/`.

Quick workflows (explicit commands)
- Start full dev environment: `tilt up` (or `tilt up --reth-only` to skip Celestia + rollup).
- Manually deploy contracts: `cd rwa-soberano-evolve && forge script script/Deploy.s.sol --rpc-url reth --broadcast` (scripts often use `reth` RPC alias from `foundry.toml`).
- Run contract unit tests: `cd rwa-soberano-evolve && forge test -vv`.
- Frontend dev server: `cd frontend && npm install && npm run dev` (Tilt usually handles this after sync).
- Canonical integration smoke test: `./scripts/test-rwa-integration.sh` (expects `cast`/Foundry tools in PATH, generates `deployed-addresses.env` if missing).

Key conventions and gotchas (do not assume defaults)
- Address sync: deployments must write `rwa-soberano-evolve/deployed-addresses.env`. Use `scripts/sync-contract-addresses.sh` to copy these into `frontend/public/deployed-addresses.env`. Tilt calls the sync step automatically.
- Registry ownership: `DocumentRegistryV2` is often owned by `RWASovereignRollup`. Write operations may need to be routed through the RWA contract (see `scripts/test-rwa-integration.sh` which autodetects owner and invokes via RWA when needed).
- ABIs & copy script: frontend expects static ABIs in `frontend/src/abis/`. The repo's `npm run copy:abis` target may point at `out/DocumentRegistry.sol` while the source is `src/DocumentRegistryV2.sol` — update the script when changing ABIs.
- Foundry aliases: `foundry.toml` defines RPC aliases (`reth`, `localhost`). Use these names in forge/cast scripts to match Tilt's environment.

Integration points and files to inspect
- Orchestration: `Tiltfile` (resource ordering, health checks, and which scripts Tilt runs).
- Rollup init: `scripts/rollup-init.sh` creates `/shared/rollkit.env` (genesis hash, JWTs, DA namespace) used by `scripts/rollkit-start.sh`.
- Sequencer entrypoint: `scripts/rollkit-start.sh` reads `/shared/rollkit.env` and executes `evm-single` with flags built from the env file.
- Integration test: `scripts/test-rwa-integration.sh` — canonical example of calling contracts with `cast`, robust tx parsing, Celestia checks, and owner-routing logic.
- Contract sources & deployment helpers: `rwa-soberano-evolve/src/` and `rwa-soberano-evolve/script/` (JS and Forge scripts).
- Frontend entry: `frontend/src/App.tsx`, `frontend/src/config/wagmi.ts`, and `frontend/src/abis/`.

Examples to copy/use
- Detecting registry owner and routing calls (pattern used in `test-rwa-integration.sh`): read `owner()` then call either Registry or RWA address depending on owner value.
- Robust cast usage: capture tx hash from `cast send` output using regex, then `cast wait <tx>` and validate receipt via `jq` when available.

Developer assumptions the agent can make
- Local RPC: `http://localhost:8545` (Reth) and Chain ID 31337 / rollup chain-id 1234 in scripts. Sequencer RPC at `http://localhost:7331`.
- Foundry and cast must be used for contract interactions in scripts. `PRIVATE_KEY` often provided by Tilt environment; default dev key is present in `scripts/test-rwa-integration.sh` if not set.

## Copilot instructions — Evolve-Taller (concise)

These notes help an AI coding agent be productive quickly in this repo. Focus on the precise files/commands below.

- Architecture: three coordinated parts.
	- Smart contracts (Foundry): `rwa-soberano-evolve/` — contracts in `src/`, Forge scripts in `script/`, tests in `test/`.
	- Frontend (React + Vite): `frontend/` — static ABIs live under `frontend/src/abis/` and the app entry is `frontend/src/App.tsx`.
	- Orchestration & infra: `Tiltfile` composes `docker-compose.reth.yml`, `docker-compose.celestia.yml`, `docker-compose.evolve.yml`. Secrets/JWTs are exchanged via the `/shared` volume.

- High-value commands (explicit)
	- Start all services: `tilt up` (or `tilt up --reth-only` to skip Celestia/rollup).
	- Run contract tests: `cd rwa-soberano-evolve && forge test -vv`.
	- Deploy manually: `cd rwa-soberano-evolve && forge script script/Deploy.s.sol --rpc-url reth --broadcast`.
	- Frontend dev: `cd frontend && npm install && npm run dev` (Tilt normally handles this and the ABI sync).
	- Canonical smoke test: `./scripts/test-rwa-integration.sh` (uses `cast`, may write `deployed-addresses.env`).

- Conventions & gotchas (specific)
	- Deployment addresses: deployment flows must output `rwa-soberano-evolve/deployed-addresses.env`. Use `scripts/sync-contract-addresses.sh` to copy into `frontend/public/deployed-addresses.env`.
	- Registry ownership pattern: write calls to the registry may be proxied through `RWASovereignRollup` when the owner is the rollup contract. See `scripts/test-rwa-integration.sh` for the detection and routing pattern.
	- ABIs: frontend expects static ABI files under `frontend/src/abis/`. If you change contract names (e.g., `DocumentRegistryV2`), update the copy script or `package.json` npm tasks that export ABIs.
	- Foundry RPC aliases: rely on `rwa-soberano-evolve/foundry.toml` aliases like `reth` and `localhost` when invoking `forge`/`cast` so Tilt's environment matches.

- Integration touchpoints to inspect (quick list)
	- `Tiltfile` — orchestration, resource ordering, health checks.
	- `scripts/rollup-init.sh` — produces `/shared/rollkit.env` (genesis, JWTs, namespace).
	- `scripts/rollkit-start.sh` — builds flags from `/shared/rollkit.env` and runs `evm-single`.
	- `scripts/test-rwa-integration.sh` — canonical example: owner detection, `cast` usage, tx parsing, Celestia checks.
	- `rwa-soberano-evolve/src/` and `rwa-soberano-evolve/script/` — contract sources and deployment helpers.

- Useful patterns/examples to copy
	- Owner detection: call `owner()` on registry, compare to registry address; if owner == RWA address then route writes through RWA contract (see `test-rwa-integration.sh`).
	- Shell scripting: scripts output verbose, human-friendly logs — preserve that style and add clear failure messages.

- Assumptions an agent can make
	- Local Reth RPC: `http://localhost:8545`; Sequencer RPC: `http://localhost:7331`.
	- Common chain-ids present in scripts: 31337 and 1234 — prefer the value used by Tilt unless directed otherwise.
	- `PRIVATE_KEY` and other dev secrets are injected by Tilt into `/shared` or env; do not hard-code keys/JWTs.

- If you change orchestration or scripts
	- Update `Tiltfile` if resource names/order change.
	- Ensure new deploy flows still write `rwa-soberano-evolve/deployed-addresses.env` and add sync logic to `scripts/sync-contract-addresses.sh`.

If any section is unclear or you want me to expand examples (deploy flow, ABI copy script, or owner-routing), tell me which area and I'll iterate.
