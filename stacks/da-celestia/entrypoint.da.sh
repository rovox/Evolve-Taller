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

        if ! sed -i.bak \
            -e "s/\(TrustedHash[[:space:]]*=[[:space:]]*\).*/\1\"$DA_TRUSTED_HASH\"/" \
            -e "s/\(SampleFrom[[:space:]]*=[[:space:]]*\).*/\1$DA_TRUSTED_HEIGHT/" \
            "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update config with latest trusted state"
            exit 1
        fi
        log "SUCCESS" "Config updated with latest trusted state"

        # Update DASer.SampleFrom
        log "CONFIG" "Updating DASer.SampleFrom to: $DA_TRUSTED_HEIGHT"
        if ! sed -i 's/^[[:space:]]*SampleFrom = .*/  SampleFrom = '$DA_TRUSTED_HEIGHT'/' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update DASer.SampleFrom"
            exit 1
        fi
        log "SUCCESS" "DASer.SampleFrom updated successfully"

        # Update Header.TrustedHash
        log "CONFIG" "Updating Header.TrustedHash to: $DA_TRUSTED_HASH"
        # Escape special characters for sed
        TRUSTED_HASH_ESCAPED=$(printf '%s\n' "$DA_TRUSTED_HASH" | sed 's/[[\.*^$()+?{|]/\\&/g')
        if ! sed -i 's/^[[:space:]]*TrustedHash = .*/  TrustedHash = "'"$TRUSTED_HASH_ESCAPED"'"/' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update Header.TrustedHash"
            exit 1
        fi
        log "SUCCESS" "Header.TrustedHash updated successfully"

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
    log "INFO" "Node already initialized, skipping configuration. Lock file present at $INIT_LOCK_FILE"
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
