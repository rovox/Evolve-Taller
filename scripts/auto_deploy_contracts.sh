#!/bin/bash
# Auto-deploy ROSCA contract when sequencer is ready
# This script waits for the sequencer to be healthy and then deploys the ROSCA contract

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Auto-Deploy Script Starting...${NC}"

# Configuration
RPC_URL="${RPC_URL:-http://ev-reth-sequencer:8545}"
CHAIN_ID="${CHAIN_ID:-1234}"
MAX_RETRIES=60
RETRY_DELAY=5

# Output files
CONTRACT_ADDRESS_FILE="/volumes/contracts/.rosca-address"
DEPLOYMENT_INFO_FILE="/volumes/contracts/deployment_info.json"

# Ensure output directory exists
mkdir -p /volumes/contracts

echo -e "${YELLOW}⏳ Waiting for sequencer to be ready...${NC}"

# Wait for sequencer to be ready
retries=0
while [ $retries -lt $MAX_RETRIES ]; do
    if curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        $RPC_URL > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Sequencer is ready!${NC}"
        break
    fi
    
    retries=$((retries + 1))
    echo -e "${YELLOW}  Waiting... ($retries/$MAX_RETRIES)${NC}"
    sleep $RETRY_DELAY
done

if [ $retries -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Sequencer did not become ready in time${NC}"
    exit 1
fi

# Additional wait to ensure sequencer is fully initialized
echo -e "${YELLOW}⏳ Waiting additional 10 seconds for full initialization...${NC}"
sleep 10

# Check if contract is already deployed
if [ -f "$CONTRACT_ADDRESS_FILE" ]; then
    EXISTING_ADDRESS=$(cat "$CONTRACT_ADDRESS_FILE")
    echo -e "${YELLOW}📝 Found existing contract address: $EXISTING_ADDRESS${NC}"
    
    # Verify contract still exists
    CODE=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$EXISTING_ADDRESS\",\"latest\"],\"id\":1}" \
        $RPC_URL | jq -r '.result')
    
    if [ "$CODE" != "0x" ] && [ "$CODE" != "" ]; then
        echo -e "${GREEN}✅ Contract already deployed and verified at: $EXISTING_ADDRESS${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Contract not found at previous address, redeploying...${NC}"
    fi
fi

echo -e "${YELLOW}📦 Deploying ROSCA contract...${NC}"

# Deploy contract using forge
cd /contracts

# Use environment variable for private key or default to genesis account
PRIVATE_KEY="${DEPLOYER_PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"

# Deploy contract
DEPLOY_OUTPUT=$(forge create src/ROSCA.sol:ROSCA \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy \
    --json 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Contract deployment failed:${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# Extract contract address
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | jq -r '.deployedTo')
TX_HASH=$(echo "$DEPLOY_OUTPUT" | jq -r '.transactionHash')

if [ -z "$CONTRACT_ADDRESS" ] || [ "$CONTRACT_ADDRESS" = "null" ]; then
    echo -e "${RED}❌ Failed to extract contract address${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✅ Contract deployed successfully!${NC}"
echo -e "${GREEN}   Address: $CONTRACT_ADDRESS${NC}"
echo -e "${GREEN}   TX Hash: $TX_HASH${NC}"

# Save contract address
echo "$CONTRACT_ADDRESS" > "$CONTRACT_ADDRESS_FILE"
echo -e "${GREEN}✅ Contract address saved to: $CONTRACT_ADDRESS_FILE${NC}"

# Get deployment details
BLOCK_NUMBER=$(curl -s -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}" \
    $RPC_URL | jq -r '.result.blockNumber')

DEPLOYER=$(curl -s -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}" \
    $RPC_URL | jq -r '.result.from')

GAS_USED=$(curl -s -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TX_HASH\"],\"id\":1}" \
    $RPC_URL | jq -r '.result.gasUsed')

# Convert hex to decimal
BLOCK_NUM_DEC=$((16#${BLOCK_NUMBER#0x}))
GAS_USED_DEC=$((16#${GAS_USED#0x}))

# Create deployment info JSON
cat > "$DEPLOYMENT_INFO_FILE" <<EOF
{
  "contract_address": "$CONTRACT_ADDRESS",
  "transaction_hash": "$TX_HASH",
  "block_number": $BLOCK_NUM_DEC,
  "gas_used": $GAS_USED_DEC,
  "deployer": "$DEPLOYER",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "success"
}
EOF

echo -e "${GREEN}✅ Deployment info saved to: $DEPLOYMENT_INFO_FILE${NC}"

# Verify contract
CODE=$(curl -s -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$CONTRACT_ADDRESS\",\"latest\"],\"id\":1}" \
    $RPC_URL | jq -r '.result')

if [ "$CODE" != "0x" ] && [ "$CODE" != "" ]; then
    CODE_LENGTH=${#CODE}
    echo -e "${GREEN}✅ Contract verified! Bytecode length: $CODE_LENGTH characters${NC}"
else
    echo -e "${RED}❌ Contract verification failed${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Auto-deployment complete!${NC}"
