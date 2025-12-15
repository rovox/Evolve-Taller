#!/bin/bash
# Update Celestia DA Start Height to recent block
# This script queries the Celestia Mocha testnet and updates the .env file

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🌌 Updating Celestia DA Start Height...${NC}"

# Configuration
ENV_FILE_DA="stacks/da-celestia/.env"
ENV_FILE_SEQ="stacks/single-sequencer/.env"
CELESTIA_API="https://api-mocha.celenium.io/v1"

# Get current block height from Celestia API
echo -e "${YELLOW}📡 Querying Celestia Mocha API...${NC}"

RESPONSE=$(curl -s "$CELESTIA_API/block" || echo "")

if [ -z "$RESPONSE" ]; then
    echo -e "${RED}❌ Failed to query Celestia API${NC}"
    exit 1
fi

# Extract height and hash
CURRENT_HEIGHT=$(echo "$RESPONSE" | jq -r '.height')
CURRENT_HASH=$(echo "$RESPONSE" | jq -r '.hash')

if [ -z "$CURRENT_HEIGHT" ] || [ "$CURRENT_HEIGHT" = "null" ]; then
    echo -e "${RED}❌ Failed to extract block height${NC}"
    exit 1
fi

# Use a block slightly in the past for safety (100 blocks back)
SAFE_HEIGHT=$((CURRENT_HEIGHT - 100))

echo -e "${GREEN}✅ Current Mocha height: $CURRENT_HEIGHT${NC}"
echo -e "${GREEN}✅ Using safe height: $SAFE_HEIGHT${NC}"

# Get the block at safe height
echo -e "${YELLOW}📡 Fetching block at height $SAFE_HEIGHT...${NC}"

BLOCK_RESPONSE=$(curl -s "$CELESTIA_API/block/$SAFE_HEIGHT" || echo "")

if [ -z "$BLOCK_RESPONSE" ]; then
    echo -e "${YELLOW}⚠️  Failed to get specific block, using current hash${NC}"
    SAFE_HASH=$CURRENT_HASH
else
    SAFE_HASH=$(echo "$BLOCK_RESPONSE" | jq -r '.hash')
fi

echo -e "${GREEN}✅ Block hash: $SAFE_HASH${NC}"

# Update DA Celestia .env
if [ -f "$ENV_FILE_DA" ]; then
    echo -e "${YELLOW}📝 Updating $ENV_FILE_DA...${NC}"
    
    # Backup original
    cp "$ENV_FILE_DA" "$ENV_FILE_DA.backup"
    
    # Update or add DA_TRUSTED_HEIGHT
    if grep -q "^DA_TRUSTED_HEIGHT=" "$ENV_FILE_DA"; then
        sed -i "s/^DA_TRUSTED_HEIGHT=.*/DA_TRUSTED_HEIGHT=\"$SAFE_HEIGHT\"/" "$ENV_FILE_DA"
    else
        echo "DA_TRUSTED_HEIGHT=\"$SAFE_HEIGHT\"" >> "$ENV_FILE_DA"
    fi
    
    # Update or add DA_TRUSTED_HASH
    if grep -q "^DA_TRUSTED_HASH=" "$ENV_FILE_DA"; then
        sed -i "s/^DA_TRUSTED_HASH=.*/DA_TRUSTED_HASH=\"$SAFE_HASH\"/" "$ENV_FILE_DA"
    else
        echo "DA_TRUSTED_HASH=\"$SAFE_HASH\"" >> "$ENV_FILE_DA"
    fi
    
    echo -e "${GREEN}✅ Updated $ENV_FILE_DA${NC}"
else
    echo -e "${RED}❌ File not found: $ENV_FILE_DA${NC}"
fi

# Update Sequencer .env
if [ -f "$ENV_FILE_SEQ" ]; then
    echo -e "${YELLOW}📝 Updating $ENV_FILE_SEQ...${NC}"
    
    # Backup original
    cp "$ENV_FILE_SEQ" "$ENV_FILE_SEQ.backup"
    
    # Update or add SEQUENCER_DA_START_HEIGHT
    if grep -q "^SEQUENCER_DA_START_HEIGHT=" "$ENV_FILE_SEQ"; then
        sed -i "s/^SEQUENCER_DA_START_HEIGHT=.*/SEQUENCER_DA_START_HEIGHT=\"$SAFE_HEIGHT\"/" "$ENV_FILE_SEQ"
    else
        echo "SEQUENCER_DA_START_HEIGHT=\"$SAFE_HEIGHT\"" >> "$ENV_FILE_SEQ"
    fi
    
    echo -e "${GREEN}✅ Updated $ENV_FILE_SEQ${NC}"
else
    echo -e "${RED}❌ File not found: $ENV_FILE_SEQ${NC}"
fi

echo -e "${GREEN}🎉 DA Start Height updated successfully!${NC}"
echo -e "${YELLOW}ℹ️  Old values backed up to .backup files${NC}"
echo -e "${YELLOW}ℹ️  Restart services for changes to take effect: make stop && make start${NC}"
