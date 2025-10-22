# Evolve-Taller: RWA Tokenization Platform

A complete Real World Assets (RWA) tokenization platform built on the Evolve + Celestia stack, featuring sovereign rollup technology for secure and efficient asset tokenization.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [MVP Status](#mvp-status)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Smart Contracts](#smart-contracts)
- [Frontend](#frontend)
- [Testing](#testing)
- [Error Handling](#error-handling)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## Project Overview

Evolve-Taller enables the tokenization of real world assets through a sovereign rollup architecture:

- **Document Registry**: Secure document storage and verification system
- **RWA Tokenization**: ERC1155-based asset tokenization with role-based access control
- **Dividend Distribution**: Automated revenue distribution to token holders
- **Sovereign Rollup**: Evolve-based rollup for scalable, secure transactions
- **Data Availability**: Celestia network for decentralized data storage

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Smart         │    │   Sovereign     │
│   (React/Vite)  │◄──►│   Contracts     │◄──►│   Rollup        │
│                 │    │   (Foundry)     │    │   (Evolve)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌─────────────────┐
                    │   Data          │
                    │   Availability  │
                    │   (Celestia)    │
                    └─────────────────┘
```

### Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Reth RPC | 8545 | Ethereum execution layer |
| Celestia RPC | 26658 | Data availability layer |
| Rollup RPC | 7331 | Sovereign rollup sequencer |
| Frontend | 5173 | React development server |
| Tilt Dashboard | 10350 | Development orchestration |

## MVP Status

### ✅ Completed Features

- **Smart Contracts**: Complete RWA tokenization suite
  - DocumentRegistryV2: Document registration and verification
  - RWAToken: ERC1155-based asset tokens with access control
  - RWASovereignRollup: Rollup integration and orchestration
  - DividendDistributor: Automated dividend distribution

- **Frontend**: React application with Web3 integration
  - System status monitoring
  - Contract interaction interface
  - MetaMask wallet integration

- **Testing**: Comprehensive test coverage
  - Unit tests for all smart contracts
  - Integration tests for end-to-end flows
  - Automated testing in CI/CD pipeline

- **Development Environment**: Full-stack orchestration
  - Tilt-based development workflow
  - Docker Compose service management
  - Automated deployment and testing

### 🚧 In Development

- Advanced frontend features (asset management UI)
- Multi-asset portfolio tracking
- Enhanced security audits
- Production deployment configurations

### 📋 Planned Features

- Cross-chain asset bridging
- Decentralized identity integration
- Advanced compliance features
- Mobile application support

## Prerequisites

### Required Software
- **Docker**: Version 20.10+ with Docker Compose
- **Tilt**: For development environment orchestration
- **Foundry**: For smart contract development and testing
- **Node.js**: Version 18+ for frontend development
- **MetaMask**: Browser extension for Web3 interaction

### Installation Commands

#### Docker & Tilt
```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Tilt
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
```

#### Foundry (Smart Contracts)
```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

#### Node.js (Frontend)
```bash
# Using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
nvm use 18
```

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd evolve-taller
```

### 2. Start Development Environment
```bash
tilt up
```

This launches:
- Reth execution client
- Celestia data availability node
- Evolve sovereign rollup sequencer
- Smart contract deployment and testing
- Frontend development server

### Secrets and JWTs

Tilt mounts a shared volume for runtime files, but some services (notably Celestia) expect JWTs in a dedicated subpath. Files and locations used by scripts/containers:

- General shared outputs: `/shared` — used for files like `deployed-addresses.env` and rollup flags.
- Celestia JWT token: `/shared/jwt/celestia-jwt.token` — created by scripts such as `scripts/celestia-fund.sh` and consumed by the Celestia container and the rollup sequencer.

How the token is produced and propagated:

1. Initialization scripts (e.g. `scripts/rollup-init.sh`) prepare secrets and may request/register a JWT with Celestia.
2. `scripts/celestia-fund.sh` (or similar helpers) write the token to `/shared/jwt/celestia-jwt.token` and set permissive read permissions so containers can access it.
3. The sequencer/rollkit startup (`scripts/rollkit-start.sh` and the `Tiltfile`) read `/shared/rollkit.env` and `/shared/jwt/celestia-jwt.token` when launching `evm-single`.

If you change Celestia or rollup startup scripts, ensure tokens are still written to `/shared/jwt/celestia-jwt.token` (or update container mounts accordingly).

### ABI generation and copy (how frontend gets ABIs)

The frontend imports static ABI JSON files from `frontend/src/abis/`. These are not automatically regenerated by Tilt; the typical developer flow is:

1. Build contracts with Foundry to produce `out/` artifacts:

```bash
cd rwa-soberano-evolve
forge build
```

2. Copy the ABI JSONs you need into the frontend ABI folder. Example:

```bash
# from repo root
cp rwa-soberano-evolve/out/DocumentRegistry.sol/DocumentRegistry.json frontend/src/abis/DocumentRegistry.json
cp rwa-soberano-evolve/out/RWASovereignRollup.sol/RWASovereignRollup.json frontend/src/abis/RWASovereignRollup.json
```

3. Ensure `frontend/src/abis/index.ts` imports the filenames you copied. If contract names change (e.g., `DocumentRegistryV2`) update the copy commands and `index.ts` accordingly.

Automation: there are helper scripts in `scripts/` and `rwa-soberano-evolve/script/` that attempt to extract ABIs/addresses from `out/` or `broadcast/` runs — inspect `scripts/deploy-rwa-contracts.sh` and `rwa-soberano-evolve/script/` for project-specific helpers. If you add or rename contracts, update those helpers so `deployed-addresses.env` and the frontend ABI files are produced correctly.

### 3. Access Interfaces
- **Frontend**: http://localhost:5173
- **Tilt Dashboard**: http://localhost:10350
- **Reth RPC**: http://localhost:8545
- **Celestia RPC**: http://localhost:26658
- **Rollup RPC**: http://localhost:7331

### 4. Connect MetaMask
Configure MetaMask to connect to `http://localhost:8545` with Chain ID `31337`.

## Smart Contracts

### Core Contracts

#### DocumentRegistryV2
- **Purpose**: Secure document registration and verification
- **Features**: Access control, document history, metadata storage
- **Key Functions**: `registerDocument()`, `verifyDocument()`, `getDocumentHistory()`

#### RWAToken
- **Purpose**: ERC1155-based RWA tokenization
- **Features**: Role-based access, token minting, transfer restrictions
- **Key Functions**: `mint()`, `burn()`, `setTokenRoles()`

#### RWASovereignRollup
- **Purpose**: Rollup orchestration and cross-contract integration
- **Features**: Block commitment, tokenization requests, document verification
- **Key Functions**: `commitBlock()`, `requestTokenization()`, `verifyDocument()`

#### DividendDistributor
- **Purpose**: Automated revenue distribution
- **Features**: Percentage-based distribution, claim tracking
- **Key Functions**: `createDividend()`, `claimDividend()`, `getClaimableAmount()`

### Deployment
Contracts are automatically deployed during `tilt up` and tested via the integrated test suite.

## Frontend

### Technology Stack
- **React 18** with TypeScript
- **Vite** for build tooling
- **Wagmi** for Web3 integration
- **MetaMask** for wallet connectivity

### Key Components
- **SystemStatus**: Monitors blockchain and contract health
- **RWAInterface**: Main application interface for asset management

### Development
```bash
cd frontend
npm install
npm run dev
```

## Testing

### Unit Tests
Comprehensive Foundry-based unit tests for all smart contracts:
```bash
cd rwa-soberano-evolve
forge test -vv
```

### Integration Tests
End-to-end testing via Tilt pipeline:
```bash
tilt up  # Runs integration tests automatically
```

### Test Coverage
- Document registration and verification flows
- Token minting and transfer operations
- Dividend distribution calculations
- Access control and permission systems
- Error condition handling

## Error Handling

### Smart Contract Errors

#### Access Control Violations
- **Error**: `AccessControlUnauthorizedAccount`
- **Cause**: Insufficient permissions for operation
- **Resolution**: Verify caller has appropriate role (ADMIN, MINTER, etc.)

#### Invalid Operations
- **Error**: `InvalidOperation`
- **Cause**: Contract state doesn't allow operation
- **Resolution**: Check contract preconditions and state

#### Insufficient Balance
- **Error**: `InsufficientBalance`
- **Cause**: User lacks tokens for operation
- **Resolution**: Verify token holdings before operations

### Frontend Errors

#### Wallet Connection Issues
- **Error**: "MetaMask not detected"
- **Resolution**: Install MetaMask extension and refresh page

#### Network Mismatch
- **Error**: "Chain ID mismatch"
- **Resolution**: Switch MetaMask to local network (Chain ID: 31337)

#### Transaction Failures
- **Error**: "Transaction reverted"
- **Resolution**: Check contract error messages and gas limits

### Infrastructure Errors

#### Service Unavailability
- **Error**: Connection refused on service ports
- **Resolution**: Check Tilt dashboard for service status

#### Docker Issues
- **Error**: Container startup failures
- **Resolution**: Check Docker resources and port availability

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check port usage
   lsof -i :8545,7331,26658,5173

   # Free ports if needed
   tilt down
   docker system prune
   ```

2. **Contract Deployment Failures**
   ```bash
   # Manual deployment
   cd rwa-soberano-evolve
   forge script script/Deploy.s.sol --rpc-url reth --broadcast
   ```

3. **Frontend Build Issues**
   ```bash
   cd frontend
   rm -rf node_modules package-lock.json
   npm install
   ```

4. **Test Failures**
   ```bash
   # Run specific test
   forge test --match-test testFunctionName -vv
   ```

### Clean Reset
```bash
tilt down
docker system prune -a
docker volume prune
rm -rf rwa-soberano-evolve/cache rwa-soberano-evolve/out
```

## Development

### Project Structure
```
evolve-taller/
├── rwa-soberano-evolve/     # Smart contracts (Foundry)
├── frontend/                # React application
├── scripts/                 # Deployment and utility scripts
├── chain/                   # Network configuration
├── Tiltfile                 # Development orchestration
└── docker-compose.*.yml     # Service definitions
```

### Contributing
1. Create feature branch from `main`
2. Add tests for new functionality
3. Update documentation as needed
4. Submit pull request with Tilt validation

### Key Workflows
- **Development**: `tilt up` for full environment
- **Testing**: `forge test` for contract tests
- **Deployment**: Scripts in `scripts/` directory
- **Frontend**: `npm run dev` in `frontend/` directory

---

**Note**: This is an MVP implementation. Production deployment requires additional security audits, testing, and infrastructure considerations.