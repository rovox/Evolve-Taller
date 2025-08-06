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
    
    
    # Start Blockscout explorer after reth is ready (not dependent on rollup-ready)
    local_resource('blockscout-start',
        '''
        echo "🔍 Starting Blockscout explorer..."
        cd blockscout/docker-compose
        cp ../../blockscout.env ./envs/custom-blockscout.env
        
        echo "🔍 Starting docker containers..."
        docker compose -f geth.yml --env-file ./envs/custom-blockscout.env up -d
        
        echo "🔍 Waiting for containers to initialize..."
        sleep 10
        
        echo "🔍 Checking container status..."
        docker compose -f geth.yml --env-file ./envs/custom-blockscout.env ps
        
        echo "🔍 Checking backend logs for any errors..."
        timeout 10 docker compose -f geth.yml --env-file ./envs/custom-blockscout.env logs backend || echo "Backend logs check completed"
        ''',
        resource_deps=['reth-ready'],
        labels=['blockscout']
    )
    
    # Wait for Blockscout to be ready
    local_resource('blockscout-ready',
        '''
        echo "🔍 Waiting for Blockscout to be ready..."
        
        echo "🔍 Checking if backend is responding on port 4000..."
        timeout 120 bash -c '
        until curl -s http://localhost:4000/api/v1/config | grep -q "backend"; do
            echo "Waiting for Blockscout backend API..."
            sleep 5
        done'
        
        echo "🔍 Checking if nginx proxy is responding on port 80..."
        timeout 60 bash -c '
        until curl -s http://localhost:80 > /dev/null; do
            echo "Waiting for Nginx proxy..."
            sleep 5
        done'
        
        echo "🔍 Final container status check..."
        cd blockscout/docker-compose
        docker compose -f geth.yml --env-file ./envs/custom-blockscout.env ps
        
        echo ""
        echo "🎉 BLOCKSCOUT IS READY!"
        echo "================================"
        echo "🔍 Blockscout Frontend: http://localhost:80"
        echo "🔍 Blockscout Backend API: http://localhost:4000"
        echo "📊 Nginx Proxy: http://localhost:80"
        ''',
        resource_deps=['blockscout-start'],
        labels=['blockscout']
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
    print("🔍 Blockscout: http://localhost:4000")
    print("📊 Nginx Proxy: http://localhost:80")
else:
    print("🔧 RETH-ONLY MODE")
    print("🔗 Reth RPC: http://localhost:8545")

print("📊 Tilt Dashboard: http://localhost:10350")
print("🌐 Shared Network: rollup-network")
print("")
print("💡 Usage:")
print("  tilt up           # Full rollup stack + Blockscout (DEFAULT)")
print("  tilt up --reth-only # Just Reth for development")