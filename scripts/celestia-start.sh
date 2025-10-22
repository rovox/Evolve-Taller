#!/bin/sh
# celestia-start.sh - Just start the Celestia node

set -e

echo "🌟 Starting Celestia Light Node..."

# Initialize if not exists
if [ ! -d "/home/celestia/config.toml" ]; then
    echo "📦 Initializing Celestia light node..."
    celestia light init --p2p.network mocha
fi

# Get latest block and update trusted hash
echo "🔄 Setting up trusted hash from latest block..."
block_response=$(curl -s https://full.consensus.mocha-4.celestia-mocha.com/block --max-time 30)
latest_block=$(echo "$block_response" | jq -r '.result.block.header.height')
latest_hash=$(echo "$block_response" | jq -r '.result.block_id.hash')

echo "📊 Latest block: $latest_block"
echo "🔗 Trusted hash: $latest_hash"

# Update config with trusted hash home/celestia/
config_file="/home/celestia/config.toml"
if [ -f "$config_file" ]; then
    sed -i.bak \
        -e "s/\(TrustedHash[[:space:]]*=[[:space:]]*\).*/\1\"$latest_hash\"/" \
        -e "s/\(SampleFrom[[:space:]]*=[[:space:]]*\).*/\1$latest_block/" \
        "$config_file"
    echo "✅ Config updated with latest trusted state"
fi

echo "🚀 Starting Celestia light node..."

# Start node (this will run in foreground and show logs)
exec celestia light start \
    --core.ip consensus-full-mocha-4.celestia-mocha.com \
    --core.port 9090 \
    --rpc.addr 0.0.0.0 \
    --rpc.port 26658 \
    --p2p.network mocha