---
description: Repository Information Overview
alwaysApply: true
---

# Repository Information Overview

## Repository Summary
Evolve-Taller is a Real World Assets (RWA) tokenization platform built on the Evolve + Celestia stack, featuring sovereign rollup technology for secure and efficient asset tokenization. The platform enables document registration, asset tokenization, dividend distribution, and uses a modular smart contract architecture.

## Repository Structure
- **rwa-soberano-evolve/**: Smart contracts (Foundry) for RWA tokenization
- **frontend/**: React application with Web3 integration
- **scripts/**: Deployment and utility scripts
- **chain/**: Network configuration
- **Tiltfile**: Development orchestration
- **docker-compose.*.yml**: Service definitions for Reth, Celestia, and Evolve

### Main Repository Components
- **Smart Contracts**: Modular Solidity contracts for RWA tokenization
- **Frontend**: React/Vite application with Wagmi for Web3 integration
- **Rollup Infrastructure**: Evolve-based sovereign rollup with Celestia for data availability
- **Development Environment**: Tilt-orchestrated Docker services

## Projects

### Smart Contracts (rwa-soberano-evolve)
**Configuration File**: foundry.toml

#### Language & Runtime
**Language**: Solidity
**Version**: 0.8.28
**Build System**: Foundry
**Package Manager**: npm

#### Dependencies
**Main Dependencies**:
- OpenZeppelin Contracts (ERC1155, AccessControl, etc.)
- Forge Standard Library

#### Build & Installation
```bash
cd rwa-soberano-evolve
forge build
forge script script/Deploy.s.sol --rpc-url reth --broadcast
```

#### Testing
**Framework**: Foundry (Forge)
**Test Location**: rwa-soberano-evolve/test/
**Naming Convention**: *.t.sol for Solidity tests, *.test.js for JavaScript tests
**Configuration**: foundry.toml
**Run Command**:
```bash
cd rwa-soberano-evolve
forge test -vv
```

### Frontend
**Configuration File**: package.json, vite.config.ts

#### Language & Runtime
**Language**: TypeScript, React
**Version**: React 19.1.1, TypeScript 5.9.3
**Build System**: Vite 7.1.7
**Package Manager**: npm

#### Dependencies
**Main Dependencies**:
- React 19.1.1
- Wagmi 2.18.1
- Viem 2.38.3
- Ethers 6.15.0
- TailwindCSS 4.1.14
- React Hot Toast 2.6.0

#### Build & Installation
```bash
cd frontend
npm install
npm run dev
```

### Development Environment
**Configuration File**: Tiltfile, docker-compose.*.yml

#### Docker Configuration
**Dockerfile**: Uses pre-built images
**Services**:
- **reth-node**: Ethereum execution layer (port 8545)
- **celestia-node**: Data availability layer (port 26658)
- **rollkit-sequencer**: Sovereign rollup sequencer (port 7331)
- **rollup-init**: Initialization service for rollup

#### Usage & Operations
**Key Commands**:
```bash
# Start full development environment
tilt up

# Start only Reth (without Celestia/rollup)
tilt up --reth-only

# Clean reset
tilt down
docker system prune -a
docker volume prune
```

**Integration Points**:
- Shared JWT tokens via Docker volumes
- Contract addresses synced to frontend via deployed-addresses.env
- ABIs copied from contract build artifacts to frontend/src/abis/

#### Validation
**Quality Checks**: Comprehensive test suite for contracts
**Testing Approach**: Unit tests, integration tests, and end-to-end testing via Tilt pipeline