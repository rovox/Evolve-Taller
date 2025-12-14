#!/bin/bash
# Fail on any error
set -e

# Fail on any error in a pipeline
set -o pipefail

# Fail when using undeclared variables
set -u

# Source shared logging utility
. /usr/local/lib/logging.sh

LIGHT_NODE_CONFIG_PATH=/home/celestia/config.toml
INIT_LOCK_FILE=/home/celestia/.initialized

# Auto-fetch latest trusted height and hash from RPC if not hardcoded or stale
log "INFO" "Fetching latest trusted sync point from Celestia RPC..."
RPC_URL="https://rpc-mocha.pops.one"

# Attempt to auto-fetch with timeout and error handling (don't fail script if this fails)
FETCH_SUCCESS=false
LATEST_HEIGHT=""

# Get latest block height with explicit timeout (15s connect, 30s max)
if command -v jq >/dev/null 2>&1; then
    # Prefer jq for reliable JSON parsing
    LATEST_HEIGHT=$(curl -s --connect-timeout 15 --max-time 30 "${RPC_URL}/block" 2>/dev/null | jq -r '.result.block.header.height // empty' 2>/dev/null) || true
else
    # Fallback to grep-based parsing
    LATEST_HEIGHT=$(curl -s --connect-timeout 15 --max-time 30 "${RPC_URL}/block" 2>/dev/null | grep -o '"height":"[0-9]*"' | head -1 | grep -o '[0-9]*') || true
fi

if [ -n "$LATEST_HEIGHT" ] && [ "$LATEST_HEIGHT" -gt 0 ] 2>/dev/null; then
    # Use a height slightly behind latest for stability (10 blocks ≈ 1.5 minutes)
    SAFE_HEIGHT=$((LATEST_HEIGHT - 10))
    log "INFO" "Latest block height: $LATEST_HEIGHT, using safe height: $SAFE_HEIGHT"
    
    # Fetch the block hash at the safe height
    BLOCK_HASH=""
    if command -v jq >/dev/null 2>&1; then
        BLOCK_HASH=$(curl -s --connect-timeout 15 --max-time 30 "${RPC_URL}/block?height=${SAFE_HEIGHT}" 2>/dev/null | jq -r '.result.block_id.hash // empty' 2>/dev/null) || true
    else
        BLOCK_HASH=$(curl -s --connect-timeout 15 --max-time 30 "${RPC_URL}/block?height=${SAFE_HEIGHT}" 2>/dev/null | grep -o '"hash":"[A-F0-9]*"' | head -1 | sed 's/"hash":"\([^"]*\)"/\1/') || true
    fi
    
    if [ -n "$BLOCK_HASH" ]; then
        DA_TRUSTED_HEIGHT="$SAFE_HEIGHT"
        DA_TRUSTED_HASH="$BLOCK_HASH"
        FETCH_SUCCESS=true
        log "SUCCESS" "Auto-fetched trusted state: height=$DA_TRUSTED_HEIGHT, hash=$DA_TRUSTED_HASH"
    else
        log "WARN" "Could not fetch block hash, using .env values: height=${DA_TRUSTED_HEIGHT}, hash=${DA_TRUSTED_HASH:0:16}..."
    fi
else
    log "WARN" "Could not fetch latest height from RPC (timeout or connectivity issue)"
    log "INFO" "Using .env values: height=${DA_TRUSTED_HEIGHT}, hash=${DA_TRUSTED_HASH:0:16}..."
fi

if [ ! -f "$INIT_LOCK_FILE" ]; then
    log "INIT" "Starting Celestia Light Node initialization"
    log "INFO" "Light node config path: $LIGHT_NODE_CONFIG_PATH"
    log "INFO" "DA Core IP: ${DA_CORE_IP}"
    log "INFO" "DA Core Port: ${DA_CORE_PORT}"
    log "INFO" "DA Network: ${DA_NETWORK}"
    log "INFO" "DA RPC Port: ${DA_RPC_PORT}"
    log "INFO" "DA Trusted Height: ${DA_TRUSTED_HEIGHT}"
    log "INFO" "DA Trusted Hash: ${DA_TRUSTED_HASH}"

# Initializing the light node
    if [ ! -f "$LIGHT_NODE_CONFIG_PATH" ]; then
        log "INFO" "Config file does not exist. Initializing the light node"

        log "INIT" "Initializing celestia light node with network: ${DA_NETWORK}"
        if ! celestia light init \
            "--core.ip=${DA_CORE_IP}" \
            "--core.port=${DA_CORE_PORT}" \
            "--p2p.network=${DA_NETWORK}"; then
            log "ERROR" "Failed to initialize celestia light node"
            exit 1
        fi
        log "SUCCESS" "Celestia light node initialization completed"

        log "CONFIG" "Updating configuration with latest trusted state"

        # Update StartupTimeout to 180s within [Node] section (critical for sync completion)
        log "CONFIG" "Setting StartupTimeout to 180s in [Node] section"
        if ! sed -i '/^\[Node\]/,/^\[/{s/^[[:space:]]*StartupTimeout[[:space:]]*=.*/  StartupTimeout = "180s"/}' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update StartupTimeout"
            exit 1
        fi
        log "SUCCESS" "StartupTimeout set to 180s"

        # Update RPC configuration for external access within [RPC] section
        log "CONFIG" "Configuring RPC for external access (0.0.0.0) in [RPC] section"
        if ! sed -i '/^\[RPC\]/,/^\[/{s/^[[:space:]]*Address[[:space:]]*=.*/  Address = "0.0.0.0"/}' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update RPC Address"
            exit 1
        fi
        log "SUCCESS" "RPC Address set to 0.0.0.0"

        # Enable SkipAuth for RPC within [RPC] section
        log "CONFIG" "Enabling RPC SkipAuth in [RPC] section"
        if ! sed -i '/^\[RPC\]/,/^\[/{s/^[[:space:]]*SkipAuth[[:space:]]*=.*/  SkipAuth = true/}' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to enable SkipAuth"
            exit 1
        fi
        log "SUCCESS" "RPC SkipAuth enabled"

        # Update Header.Syncer.SyncFromHeight (correct field name for v0.28+)
        log "CONFIG" "Updating Header.Syncer.SyncFromHeight to: $DA_TRUSTED_HEIGHT"
        if ! sed -i '/\[Header\.Syncer\]/,/^\[/{s/^[[:space:]]*SyncFromHeight[[:space:]]*=.*/  SyncFromHeight = '$DA_TRUSTED_HEIGHT'/}' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update SyncFromHeight"
            exit 1
        fi
        log "SUCCESS" "SyncFromHeight updated successfully"

        # Update Header.Syncer.SyncFromHash (correct field name for v0.28+)
        log "CONFIG" "Updating Header.Syncer.SyncFromHash to: $DA_TRUSTED_HASH"
        # Escape special characters for sed
        TRUSTED_HASH_ESCAPED=$(printf '%s\n' "$DA_TRUSTED_HASH" | sed 's/[[\.*^$()+?{|]/\\&/g')
        if ! sed -i '/\[Header\.Syncer\]/,/^\[/{s/^[[:space:]]*SyncFromHash[[:space:]]*=.*/  SyncFromHash = "'"$TRUSTED_HASH_ESCAPED"'"/}' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update SyncFromHash"
            exit 1
        fi
        log "SUCCESS" "SyncFromHash updated successfully"

        log "SUCCESS" "Configuration completed - Trusted height: $DA_TRUSTED_HEIGHT, Trusted hash: $DA_TRUSTED_HASH"

    else
        log "INFO" "Config file already exists at $LIGHT_NODE_CONFIG_PATH"
        log "INFO" "Skipping initialization - light node already configured"
    fi

# Ensure TxWorkerAccounts is set to 8 under [State] section
    log "CONFIG" "Ensuring TxWorkerAccounts is set to 8 in [State] section"
    if grep -q "^\[State\]" "$LIGHT_NODE_CONFIG_PATH"; then
        # Check if TxWorkerAccounts exists within [State] section
        if sed -n '/^\[State\]/,/^\[/{/^[[:space:]]*TxWorkerAccounts[[:space:]]*=/p}' "$LIGHT_NODE_CONFIG_PATH" | grep -q .; then
            # Exists: ensure set to 8 (only within [State] section)
            log "CONFIG" "Updating TxWorkerAccounts to 8 within [State] section"
            if ! sed -i '/^\[State\]/,/^\[/{s/^[[:space:]]*TxWorkerAccounts[[:space:]]*=.*/  TxWorkerAccounts = 8/}' "$LIGHT_NODE_CONFIG_PATH"; then
                log "ERROR" "Failed to update TxWorkerAccounts"
                exit 1
            fi
            log "SUCCESS" "TxWorkerAccounts ensured at 8"
        else
            # Missing: add it right after [State]
            log "CONFIG" "Adding TxWorkerAccounts = 8 to [State] section"
            if ! sed -i '/^\[State\]/a\  TxWorkerAccounts = 8' "$LIGHT_NODE_CONFIG_PATH"; then
                log "ERROR" "Failed to add TxWorkerAccounts to [State] section"
                exit 1
            fi
            log "SUCCESS" "TxWorkerAccounts added to [State] section"
        fi
    else
        log "WARN" "[State] section not found in config file"
    fi

    # Mark initialization complete
    if touch "$INIT_LOCK_FILE" 2>/dev/null; then
        # Verify lock file was actually created
        if [ -f "$INIT_LOCK_FILE" ]; then
            log "SUCCESS" "Initial configuration complete. Lock file created at $INIT_LOCK_FILE"
        else
            log "ERROR" "Lock file creation reported success but file not found - filesystem issue?"
            log "WARN" "Configuration may re-run on next restart"
        fi
    else
        log "ERROR" "Cannot create lock file at $INIT_LOCK_FILE - check volume permissions"
        log "WARN" "Configuration may re-run on next restart"
    fi
else
    log "INFO" "Node already initialized. Lock file present at $INIT_LOCK_FILE"
    
    # CRITICAL: Always ensure StartupTimeout and RPC config are correct, even on existing volumes
    if [ -f "$LIGHT_NODE_CONFIG_PATH" ]; then
        log "CONFIG" "Verifying critical config values on existing volume..."
        
        # Check and fix StartupTimeout if needed
        CURRENT_TIMEOUT=$(grep -E '^[[:space:]]*StartupTimeout' "$LIGHT_NODE_CONFIG_PATH" | head -1 | grep -oE '"[^"]+"' | tr -d '"')
        if [ "$CURRENT_TIMEOUT" != "180s" ]; then
            log "WARN" "StartupTimeout is $CURRENT_TIMEOUT, updating to 180s"
            sed -i '/^\[Node\]/,/^\[/{s/^[[:space:]]*StartupTimeout[[:space:]]*=.*/  StartupTimeout = "180s"/}' "$LIGHT_NODE_CONFIG_PATH" || true
        fi
        
        # Check and fix RPC Address if needed
        CURRENT_ADDR=$(sed -n '/^\[RPC\]/,/^\[/{s/^[[:space:]]*Address[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p}' "$LIGHT_NODE_CONFIG_PATH" | head -1)
        if [ "$CURRENT_ADDR" != "0.0.0.0" ]; then
            log "WARN" "RPC Address is $CURRENT_ADDR, updating to 0.0.0.0"
            sed -i '/^\[RPC\]/,/^\[/{s/^[[:space:]]*Address[[:space:]]*=.*/  Address = "0.0.0.0"/}' "$LIGHT_NODE_CONFIG_PATH" || true
        fi
        
        # Check and fix SkipAuth if needed
        CURRENT_SKIPAUTH=$(sed -n '/^\[RPC\]/,/^\[/{s/^[[:space:]]*SkipAuth[[:space:]]*=[[:space:]]*\(.*\)/\1/p}' "$LIGHT_NODE_CONFIG_PATH" | head -1)
        if [ "$CURRENT_SKIPAUTH" != "true" ]; then
            log "WARN" "RPC SkipAuth is $CURRENT_SKIPAUTH, updating to true"
            sed -i '/^\[RPC\]/,/^\[/{s/^[[:space:]]*SkipAuth[[:space:]]*=.*/  SkipAuth = true/}' "$LIGHT_NODE_CONFIG_PATH" || true
        fi
        
        log "SUCCESS" "Critical config values verified/updated"
    fi
fi

log "INIT" "Starting Celestia light node"
log "INFO" "Light node will be accessible on RPC port: ${DA_RPC_PORT}"
log "INFO" "Starting with skip-auth enabled for RPC access"
log "INFO" "Connecting to public RPC (TLS disabled - endpoint doesn't support it)"

celestia light start \
    "--core.ip=${DA_CORE_IP}" \
    "--core.port=${DA_CORE_PORT}" \
    "--p2p.network=${DA_NETWORK}" \
    --rpc.addr=0.0.0.0 \
    "--rpc.port=${DA_RPC_PORT}" \
    --rpc.skip-auth
