# Tiltfile - Rollup Development Environment

# Allow Tilt to run with the current k8s context (safety check)
allow_k8s_contexts('admin@k8s-tools-internal')

# Configuration flags
config.define_bool('reth-only', args=False, usage='Run only Reth (disable full rollup stack)')

cfg = config.parse()

# Centralized scripts directory (update here if scripts move)
SCRIPTS_DIR = './scripts'

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
        
        # Aumentar el timeout a 120 segundos (era 60 segundos)
        timeout 120 bash -c '
        until docker exec celestia echo "Container ready" > /dev/null 2>&1; do
            echo "Waiting for container..."
            sleep 2
        done'
        
        # Dar tiempo adicional al nodo para inicializarse por completo
        echo "⏳ Esperando inicialización completa del nodo Celestia..."
        sleep 15
        
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
    local_resource('rollkit-ready',
        '''
        echo "⏳ Waiting for Rollkit RPC..."

        timeout 60 bash -c '
        until curl -s http://localhost:7331 \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}" \
            | grep -q "result"; do
            echo "Waiting for Rollkit RPC..."
            sleep 3
        done'

        echo "✅ Rollkit RPC ready"
        ''',
        resource_deps=['rollkit-sequencer'],
        labels=['rollkit']
    )
    
    
    # Deploy RWA smart contracts to the rollup once the sequencer is up (delegates to scripts/deploy-rwa-contracts.sh)
    local_resource('deploy-rwa-contracts',
        '''
        echo "🚀 Running deploy wrapper: %s/deploy-rwa-contracts.sh"
        if [ -f %s/deploy-rwa-contracts.sh ]; then
            chmod +x %s/deploy-rwa-contracts.sh
            %s/deploy-rwa-contracts.sh || (echo "Deploy script failed" && exit 1)
        else
            echo "%s/deploy-rwa-contracts.sh not found"
            exit 1
        fi
        ''' % (SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR),
        resource_deps=['rollkit-ready'],
        labels=['contracts']
    )

    # Run contract unit tests after deployment (delegates to scripts/run-contract-tests.sh)
    local_resource('run-contract-tests',
        '''
        echo "🧪 Running contract tests wrapper: %s/run-contract-tests.sh"
        if [ -f %s/run-contract-tests.sh ]; then
            chmod +x %s/run-contract-tests.sh
            %s/run-contract-tests.sh || (echo "Contract tests failed" && exit 1)
        else
            echo "%s/run-contract-tests.sh not found"
            exit 1
        fi
        ''' % (SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR),
        resource_deps=['deploy-rwa-contracts'],
        labels=['contracts']
    )

    # Run a quick integration test that exercises the deployed contracts
    local_resource('rwa-integration-test',
        '''
        echo "🧪 Running RWA integration test (%s/test-rwa-integration.sh)..."
        if [ -f %s/test-rwa-integration.sh ]; then
            chmod +x %s/test-rwa-integration.sh
            %s/test-rwa-integration.sh || (echo "Integration test failed" && exit 1)
        else
            echo "%s/test-rwa-integration.sh not found"
            exit 1
        fi
        ''' % (SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR),
        resource_deps=['run-contract-tests'],
        labels=['contracts']
    )

    local_resource('evolve-integration-tests',
        '''
        echo "🧪 Running Evolve integration tests (rwa-soberano-evolve/test/evolve-integration.test.js)..."
        cd rwa-soberano-evolve
        if [ ! -d node_modules ]; then
            echo "📦 Installing Node dependencies..."
            npm install
        fi

        export PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
        export EVOLVE_RPC_URL="${EVOLVE_RPC_URL:-http://localhost:7331}"
        export CELESTIA_RPC_URL="${CELESTIA_RPC_URL:-http://localhost:26658}"

        npx mocha test/evolve-integration.test.js --reporter spec || (echo "Evolve integration tests failed" && exit 1)
        ''',
        resource_deps=['rwa-integration-test'],
        labels=['contracts']
    )

    # Sync deployed contract addresses to frontend
    local_resource('sync-frontend-addresses',
        '''
        echo "🔄 Syncing contract addresses to frontend (%s/sync-contract-addresses.sh)..."
        if [ -f %s/sync-contract-addresses.sh ]; then
            chmod +x %s/sync-contract-addresses.sh
            %s/sync-contract-addresses.sh || (echo "Address sync failed" && exit 1)
        else
            echo "%s/sync-contract-addresses.sh not found"
            exit 1
        fi
        ''' % (SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR),
        resource_deps=['evolve-integration-tests'],
        labels=['frontend']
    )

    # Start the frontend dev server
    local_resource('frontend-dev',
        '''
        echo "🌐 Starting frontend dev server (%s/start-frontend.sh)..."
        if [ -f %s/start-frontend.sh ]; then
            chmod +x %s/start-frontend.sh
            %s/start-frontend.sh
        else
            echo "%s/start-frontend.sh not found, falling back to 'cd frontend && npm run dev'"
            cd frontend && npm run dev
        fi
        ''' % (SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR, SCRIPTS_DIR),
        resource_deps=['sync-frontend-addresses'],
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