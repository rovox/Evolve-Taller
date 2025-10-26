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
    
    # Export rollkit.env from docker volume to host for tests (namespace discovery)
    local_resource('export-rollkit-env',
        '''
        set -e
        echo "📤 Exporting rollkit.env from docker volume to host..."
        # copy from the shared jwt-tokens volume where /shared is mounted
        docker run --rm -v jwt-tokens:/shared -v "$PWD":/host alpine:3.18 \
            sh -c 'if [ -f /shared/rollkit.env ]; then cp /shared/rollkit.env /host/rollkit.env && echo "✅ rollkit.env exported to host"; else echo "⚠ rollkit.env not found in volume yet"; fi'
        # show the namespace if present
        if [ -f ./rollkit.env ]; then
            echo "🔎 Host rollkit.env:" && sed -n '1,120p' ./rollkit.env || true
            echo ""
            echo "📛 DA_NAMESPACE (host):" && grep -E '^DA_NAMESPACE=' ./rollkit.env | cut -d'=' -f2- || echo "(not set)"
        else
            echo "⚠ ./rollkit.env missing on host"
        fi
        ''',
        resource_deps=['rollup-init'],
        labels=['rollkit']
    )

    # Simple namespace log presenter for quick checks in Tilt UI
    local_resource('show-da-namespace',
        '''
        if [ -f ./rollkit.env ]; then
            echo "📛 DA_NAMESPACE from ./rollkit.env:" && grep -E '^DA_NAMESPACE=' ./rollkit.env | cut -d'=' -f2-
        else
            echo "⚠ ./rollkit.env not found (run export-rollkit-env or wait for rollup-init)"
        fi
        ''',
        resource_deps=['export-rollkit-env'],
        labels=['rollkit']
    )

    # Show key Rollkit config from rollkit.env for visibility
    local_resource('show-rollkit-config',
        '''
        if [ -f ./rollkit.env ]; then
            echo "🧭 Rollkit config from ./rollkit.env"
            grep -E '^(EVM_GENESIS_HASH|EVM_BLOCK_TIME)=' ./rollkit.env || echo "(keys not found)"
        else
            echo "⚠ ./rollkit.env not found (export may not have completed yet)"
        fi
        ''',
        resource_deps=['export-rollkit-env'],
        labels=['rollkit']
    )

    # Engine API health-check: validate Reth authrpc (8551) and EV-Node connectivity hints
    local_resource('engine-health',
        '''
        set -e
        echo "🩺 Checking Engine API (Reth authrpc on 8551)"
        # Read JWT secret from docker volume
        JWT=$(docker run --rm -v jwt-tokens:/shared alpine:3.18 sh -c 'cat /shared/reth-jwt-secret.txt' 2>/dev/null || true)
        if [ -z "$JWT" ]; then
            echo "⚠ Could not read JWT from volume jwt-tokens:/shared/reth-jwt-secret.txt"
        else
            echo "🔑 JWT diagnostic: length=${#JWT} bytes, first 12 chars: ${JWT:0:12}..."
            # Try a basic engine method
            RESP=$(curl -s -X POST http://localhost:8551 \
                -H "Authorization: Bearer $JWT" \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","method":"engine_exchangeCapabilities","params":[],"id":1}')
            if echo "$RESP" | grep -q 'result'; then
                echo "✅ Engine API responded to engine_exchangeCapabilities"
                command -v jq >/dev/null 2>&1 && echo "$RESP" | jq -r '.result | @json' || echo "$RESP"
            else
                echo "⚠ engine_exchangeCapabilities not supported or failed. Trying fallback: engine_exchangeTransitionConfigurationV1..."
                FALLBACK=$(curl -s -X POST http://localhost:8551 \
                    -H "Authorization: Bearer $JWT" \
                    -H "Content-Type: application/json" \
                    -d '{"jsonrpc":"2.0","method":"engine_exchangeTransitionConfigurationV1","params":[],"id":1}')
                if echo "$FALLBACK" | grep -q 'result'; then
                    echo "✅ Engine API responded to engine_exchangeTransitionConfigurationV1"
                    command -v jq >/dev/null 2>&1 && echo "$FALLBACK" | jq -r '.result | @json' || echo "$FALLBACK"
                else
                    echo "❌ Engine API did not respond to either method. Raw: $RESP $FALLBACK"
                fi
            fi
        fi

        echo "\n🌐 Checking direct connectivity from rollkit-evm-single to reth-node:8551 (inside Docker network)"
        docker exec rollkit-evm-single sh -c 'apk add --no-cache curl >/dev/null 2>&1; curl -s -X POST http://reth-node:8551 -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"engine_exchangeCapabilities\",\"params\":[],\"id\":1}"' 2>/dev/null | grep -q 'result' && echo "✅ rollkit-evm-single can reach reth-node:8551 (engine_exchangeCapabilities)" || echo "❌ rollkit-evm-single cannot reach reth-node:8551 or method not supported"

        echo "\n📝 rollkit-evm-single recent logs (engine related):"
        docker logs --tail 80 rollkit-evm-single 2>/dev/null | grep -Ei 'engine|reth|payload|connected|authrpc' || docker logs --tail 40 rollkit-evm-single 2>/dev/null || true
        ''',
        resource_deps=['reth-ready', 'rollkit-sequencer', 'export-rollkit-env'],
        labels=['rollkit']
    )
    
    
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

        if [ ! -f deployed-contracts.json ]; then
            printf "%b❌ URGENTE: deployed-contracts.json no fue generado por el script%b\n" "$RED" "$NC"
            printf "%bSugerencia:%b verifica fs_permissions en rwa-soberano-evolve/foundry.toml:\n" "$YELLOW" "$NC"
            printf "  fs_permissions = [ { access = \"read\", path = \"./\" }, { access = \"write\", path = \"./deployed-contracts.json\" } ]\n"
            exit 1
        fi

        printf "%b✅ Contracts deployed. Details written to deployed-contracts.json%b\\n" "$GREEN" "$NC"
        cat deployed-contracts.json
        ''',
        resource_deps=['rollkit-sequencer'],
        labels=['contracts']
    )

    # Sync contracts and start frontend dev server
    local_resource('sync-and-start-frontend',
        '''
        set -e
        echo "📦 Syncing contracts to frontend via Node.js script..."
        node scripts/sync-from-foundry.mjs

        echo "\n---------------------------------------------"
        echo "🚀 Starting frontend dev server..."
        cd frontend
        if [ ! -d node_modules ]; then
            echo "📦 Installing frontend dependencies..."
            npm install
        fi
        npm run dev
        ''',
        resource_deps=['deploy-rwa-contracts'],
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