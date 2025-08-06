# EV Demo - EV-Node + Celestia + Reth Stack

This demo runs a complete rollup development environment with Reth as the execution layer, Celestia as the data availability layer, and EV-Node as the sequencer.

## Prerequisites

### Required Software
- **Docker**: Version 20.10+ with Docker Compose
- **Tilt**: For development environment orchestration
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


## Quick Start

### 1. Start the Full Rollup Stack
```bash
tilt up
```

This will start:
- **Reth** (Execution Layer): `http://localhost:8545`
- **Celestia** (Data Availability): `http://localhost:26658` 
- **EV-Node** (Sequencer): `http://localhost:7331`
- **Blockscout** (Explorer): `http://localhost:80`

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

# Test EV-Node
curl -s http://localhost:7331/status | jq .
```

## Alternative: Reth-Only Mode

For development with just the execution layer:

```bash
tilt up --reth-only
```

This runs only Reth at `http://localhost:8545`.

## Load Testing

1. Install the Spamoor in the `spamoor` directory:
```bash
cd spamoor
make
```
2. Run the spamoor daemon to simulate high transaction volume:

```bash
./spamoor/bin/spamoor-daemon -h "http://localhost:8545" -p "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" --port 26678
```

The spamoor daemon:
- Sends high-volume transactions to test network performance
- Connects to the local Reth RPC endpoint
- Uses a test private key for transaction signing
- Runs on port 26678 for monitoring

## Stopping the Demo

```bash
tilt down
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 8545, 8546, 8551, 7331, 26658, 80, 4000 are available
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
- **EV-Node**: Sovereign rollup sequencer built on Rollkit
- **Docker Compose**: Service orchestration across three compose files

## Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Reth RPC | 8545 | JSON-RPC endpoint |
| Reth WS | 8546 | WebSocket endpoint |
| Reth Auth | 8551 | Engine API endpoint |
| Reth Metrics | 9001 | Prometheus metrics |
| Celestia RPC | 26658 | Data availability RPC |
| EV-Node RPC | 7331 | Sequencer RPC |
| EV-Node P2P | 7676 | Peer-to-peer |
| EV-Node Metrics | 26660 | Prometheus metrics |
| Blockscout Web | 80 | Block explorer (nginx proxy) |
| Blockscout API | 4000 | Direct API access |