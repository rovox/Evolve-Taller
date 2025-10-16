# Tiltfile - Rollup Development Environment

# Allow Tilt to run with the current k8s context (safety check)
allow_k8s_contexts('admin@k8s-tools-internal')

# Configuration flags
config.define_bool('reth-only', args=False, usage='Run only Reth (disable full rollup stack)')

cfg = config.parse()

# Create shared network and JWT secret for all services
local('docker network create rollup-network || true')

# Generate JWT secret for Reth (before it starts)
local_resource('generate-jwt-secret',
    '''
    echo "🔐 Checking for existing JWT secret..."
    docker run --rm -v jwt-tokens:/shared alpine:latest sh -c "
    if [ -f /shared/reth-jwt-secret.txt ]; then
        echo 'Using existing JWT secret'
    else
        echo 'Generating new JWT secret for Reth...'
        apk add --no-cache openssl &&
        openssl rand -hex 32 > /shared/reth-jwt-secret.txt &&
        echo 'JWT secret generated'
    fi
    "
    ''',
    labels=['init']
)

# Always start Reth
docker_compose('./docker-compose.reth.yml')
dc_resource('reth-node', resource_deps=['generate-jwt-secret'], labels=['reth'])

# Reth readiness check - available in all modes
local_resource('reth-ready',
    '''
    echo "🔧 Waiting for Reth to be ready..."
    
    timeout 30 bash -c '
    until curl -s http://localhost:8545 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}" \
        | grep -q "result"; do
        echo "Waiting for Reth RPC..."
        sleep 5
    done'
    
    echo ""
    echo "🎉 RETH IS READY!"
    echo "================"
    echo "🔧 Reth RPC: http://localhost:8545"
    ''',
    resource_deps=['reth-node'],
    labels=['reth']
)

# Full rollup stack is enabled by default (unless --reth-only is specified)
if not cfg.get('reth-only'):
    print("🚀 Starting Full Rollup Stack (Reth + Celestia + Rollkit)...")
    
    # Start Celestia DA node
    docker_compose('./docker-compose.celestia.yml')
    dc_resource('celestia-node', labels=['celestia'])
    
    # Fund Celestia and get its JWT token
    local_resource('celestia-fund',
        '''
        echo "🔑 Waiting for Celestia node to start..."
        
        timeout 60 bash -c '
        until docker exec celestia echo "Container ready" > /dev/null 2>&1; do
            echo "Waiting for container..."
            sleep 2
        done'
        
        echo "💰 Running funding and JWT setup..."
        docker exec celestia sh /fund.sh
        ''',
        resource_deps=['celestia-node'],
        labels=['celestia']
    )
    
    # Initialize rollup with all dependencies
    local_resource('celestia-ready',
        '''
        jwt_token=$(docker exec celestia cat /shared/jwt/celestia-jwt.token)
        
        echo "✅ Celestia JWT Token obtained!"
        echo "🔍 Testing Celestia RPC with JWT token..."
        
        curl -s -X POST http://localhost:26658 \\
            -H "Authorization: Bearer $jwt_token" \\
            -H "Content-Type: application/json" \\
            -d '{"jsonrpc":"2.0","method":"header.NetworkHead","params":[],"id":1}' \\
            | jq .
        
        echo ""
        echo "🎉 Celestia is ready for rollup!"
        echo "🔑 Celestia JWT: $jwt_token"
        ''',
        resource_deps=['celestia-fund'],
        labels=['celestia']
    )
    
    # Start Rollkit sequencer
    docker_compose('./docker-compose.evolve.yml')
    dc_resource('rollup-init', labels=['rollkit'])
    dc_resource('rollkit-sequencer', labels=['rollkit'])
    
    
    # Deploy RWA smart contracts to the rollup once the sequencer is up
    local_resource('deploy-rwa-contracts',
        '''
        set -euo pipefail

    RED="\033[0;31m"
    YELLOW="\033[1;33m"
    GREEN="\033[0;32m"
    NC="\033[0m"

        printf "🚀 Deploying RWA smart contracts...\\n"
        cd rwa-soberano-evolve || exit 1
        if command -v forge >/dev/null 2>&1; then
            forge build
        else
            printf "%b❌ forge not found in PATH%b\\n" "$RED" "$NC"
            exit 1
        fi

        PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}
        printf "Using RPC: http://localhost:8545\\n"
        if ! PRIVATE_KEY=$PRIVATE_KEY forge script script/DeployToRollup.s.sol --rpc-url http://localhost:8545 --broadcast --legacy; then
            printf "%b❌ Deploy failed (see forge logs above)%b\\n" "$RED" "$NC"
            exit 1
        fi

        if [ ! -f deployed-addresses.env ]; then
            printf "%b❌ URGENTE: deployed-addresses.env no fue generado por el script%b\n" "$RED" "$NC"
            printf "%bSugerencia:%b verifica fs_permissions en rwa-soberano-evolve/foundry.toml:\n" "$YELLOW" "$NC"
            printf "  fs_permissions = [ { access = \"read\", path = \"./\" }, { access = \"write\", path = \"./deployed-addresses.env\" } ]\n"
            exit 1
        fi

        printf "%b✅ Contracts deployed. Addresses:%b\\n" "$GREEN" "$NC"
        cat deployed-addresses.env
        ''',
        resource_deps=['rollkit-sequencer'],
        labels=['contracts']
    )

    # Run a quick integration test that exercises the deployed contracts
    local_resource('rwa-integration-test',
        '''
        echo "🧪 Running RWA integration test..."
        # Ensure script is executable and run it
        if [ -f ./test-rwa-integration.sh ]; then
            chmod +x ./test-rwa-integration.sh
            ./test-rwa-integration.sh || (echo "Integration test failed" && exit 1)
        else
            echo "test-rwa-integration.sh not found in repo root"
            exit 1
        fi
        ''',
        resource_deps=['deploy-rwa-contracts'],
        labels=['contracts']
    )

    # Sync contract addresses to frontend
    local_resource('sync-frontend-addresses',
        '''
        echo "📦 Syncing contract addresses to frontend..."
        if [ -f ./sync-contract-addresses.sh ]; then
            chmod +x ./sync-contract-addresses.sh
            ./sync-contract-addresses.sh
        else
            echo "sync-contract-addresses.sh not found"
            exit 1
        fi
        ''',
        resource_deps=['rwa-integration-test'],
        labels=['frontend']
    )

    # Start frontend dev server
    local_resource('frontend-dev',
        '''
        cd frontend
        if [ ! -d node_modules ]; then
            echo "📦 Installing frontend dependencies..."
            npm install
        fi
        echo "🚀 Starting frontend dev server..."
        npm run dev
        ''',
        resource_deps=['sync-frontend-addresses'],
        serve_cmd='cd frontend && npm run dev',
        links=['http://localhost:5173'],
        labels=['frontend']
    )

# Manual health check from host
local_resource('reth-health',
    '''
    curl -s http://localhost:8545 \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq .
    ''',
    trigger_mode=TRIGGER_MODE_MANUAL,
    labels=['test']
)

# Print usage info
print("")
if not cfg.get('reth-only'):
    print("🚀 FULL ROLLUP STACK ENABLED")
    print("🔧 Reth: http://localhost:8545")
    print("🌟 Celestia: http://localhost:26658")
    print("🔄 Evolve: http://localhost:7331")
    print("🎨 Frontend: http://localhost:5173")
    # Blockscout and nginx proxy removed from default flow
else:
    print("🔧 RETH-ONLY MODE")
    print("🔗 Reth RPC: http://localhost:8545")

print("📊 Tilt Dashboard: http://localhost:10350")
print("🌐 Shared Network: rollup-network")
print("")
print("💡 Usage:")
print("  tilt up           # Full rollup stack + Frontend (DEFAULT)")
print("  tilt up --reth-only # Just Reth for development")