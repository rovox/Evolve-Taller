# EV Demo - Rollkit + Celestia + Reth Stack

This demo runs a complete rollup development environment with Reth as the execution layer, Celestia as the data availability layer, and Rollkit as the sequencer.

## Prerequisites

### Required Software
- **Docker**: Version 20.10+ with Docker Compose
- **Tilt**: For development environment orchestration
- **Python 3.7+**: For running stress tests (optional)
- **curl** and **jq**: For testing endpoints

### Installation Commands

#### Docker
```bash
# macOS
brew install docker
# or install Docker Desktop from docker.com

# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

#### Tilt
```bash
# macOS
brew install tilt-dev/tap/tilt

# Linux/Windows
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
```

#### Python Dependencies (for stress testing)
```bash
pip install -r requirements.txt
```

## Quick Start

### 1. Start the Full Rollup Stack
```bash
tilt up
```

This will start:
- **Reth** (Execution Layer): `http://localhost:8545`
- **Celestia** (Data Availability): `http://localhost:26658` 
- **Rollkit** (Sequencer): `http://localhost:26657`

### 2. Access Tilt Dashboard
Open `http://localhost:10350` to monitor all services.

### 3. Test the Stack
```bash
# Test Reth
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | jq .

# Test Rollkit
curl -s http://localhost:26657/status | jq .
```

## Alternative: Reth-Only Mode

For development with just the execution layer:

```bash
tilt up --reth-only
```

This runs only Reth at `http://localhost:8545`.

## Stress Testing

Run the included stress test to simulate high transaction volume:

```bash
python3 stress_test.py
```

The stress test:
- Creates and funds random accounts
- Sends high-volume transactions 
- Targets 200+ MGas/s throughput
- Provides real-time monitoring

## Stopping the Demo

```bash
tilt down
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 8545, 8546, 8551, 26657, 26658 are available
2. **Docker network errors**: Run `docker network create rollup-network` manually
3. **Permission issues**: Ensure Docker daemon is running and accessible

### Clean Reset
```bash
tilt down
docker system prune -a
docker volume prune
```

## Architecture

- **Reth**: High-performance Ethereum execution client
- **Celestia**: Modular data availability network (Mocha testnet)
- **Rollkit**: Rollup development kit for sovereign rollups
- **Docker Compose**: Service orchestration across three compose files

## Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Reth RPC | 8545 | JSON-RPC endpoint |
| Reth WS | 8546 | WebSocket endpoint |
| Reth Auth | 8551 | Engine API endpoint |
| Reth Metrics | 9001 | Prometheus metrics |
| Celestia RPC | 26658 | Data availability RPC |
| Rollkit RPC | 26657 | Sequencer RPC |
| Rollkit P2P | 7676 | Peer-to-peer |
| Rollkit Metrics | 26660 | Prometheus metrics |