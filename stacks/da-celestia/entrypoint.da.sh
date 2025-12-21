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
DATA_DIR=/home/celestia/data

log "INIT" "Starting Celestia Light Node with auto-cleanup"
log "INFO" "Light node config path: $LIGHT_NODE_CONFIG_PATH"
log "INFO" "DA Core IP: ${DA_CORE_IP}"
log "INFO" "DA Core Port: ${DA_CORE_PORT}"
log "INFO" "DA Network: ${DA_NETWORK}"
log "INFO" "DA RPC Port: ${DA_RPC_PORT}"
log "INFO" "DA Trusted Height: ${DA_TRUSTED_HEIGHT}"
log "INFO" "DA Trusted Hash: ${DA_TRUSTED_HASH}"

# Measure disk usage BEFORE cleanup
if [ -d "$DATA_DIR" ]; then
    BEFORE_SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    log "INFO" "Data directory size BEFORE cleanup: $BEFORE_SIZE"
    
    # Execute unsafe-reset-store to clean old data (preserves keys)
    log "CLEANUP" "Executing unsafe-reset-store to free disk space..."
    if celestia light unsafe-reset-store --node.store /home/celestia 2>/dev/null; then
        log "SUCCESS" "Store reset completed successfully"
    else
        log "WARN" "Reset store failed or not needed (first run)"
    fi
    
    # Measure disk usage AFTER cleanup
    AFTER_SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "0")
    log "SUCCESS" "Data directory size AFTER cleanup: $AFTER_SIZE"
else
    log "INFO" "Data directory doesn't exist yet (first run)"
fi

# Always initialize if config doesn't exist
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
fi

# ALWAYS update trusted state (not just first time)
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
TRUSTED_HASH_ESCAPED=$(printf '%s\n' "$DA_TRUSTED_HASH" | sed 's/[[\.*^$()+?{|]/\\&/g')
if ! sed -i 's/^[[:space:]]*TrustedHash = .*/  TrustedHash = "'"$TRUSTED_HASH_ESCAPED"'"/' "$LIGHT_NODE_CONFIG_PATH"; then
    log "ERROR" "Failed to update Header.TrustedHash"
    exit 1
fi
log "SUCCESS" "Header.TrustedHash updated successfully"

log "SUCCESS" "Configuration completed - Trusted height: $DA_TRUSTED_HEIGHT, Trusted hash: $DA_TRUSTED_HASH"

# Ensure TxWorkerAccounts is set to 8 under [State] section
log "CONFIG" "Ensuring TxWorkerAccounts is set to 8 in [State] section"
if grep -q "^\[State\]" "$LIGHT_NODE_CONFIG_PATH"; then
    if sed -n '/^\[State\]/,/^\[/{/^[[:space:]]*TxWorkerAccounts[[:space:]]*=/p}' "$LIGHT_NODE_CONFIG_PATH" | grep -q .; then
        log "CONFIG" "Updating TxWorkerAccounts to 8 within [State] section"
        if ! sed -i '/^\[State\]/,/^\[/{s/^[[:space:]]*TxWorkerAccounts[[:space:]]*=.*/  TxWorkerAccounts = 8/}' "$LIGHT_NODE_CONFIG_PATH"; then
            log "ERROR" "Failed to update TxWorkerAccounts"
            exit 1
        fi
        log "SUCCESS" "TxWorkerAccounts ensured at 8"
    else
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

# Clean up duplicate [Header.Syncer] sections that break TOML parsing
log "CONFIG" "Checking for duplicate [Header.Syncer] sections"
if grep -q "^[[:space:]]*\[Header\.Syncer\]" "$LIGHT_NODE_CONFIG_PATH"; then
    COUNT=$(grep -c "^[[:space:]]*\[Header\.Syncer\]" "$LIGHT_NODE_CONFIG_PATH" || echo 0)
    if [ "$COUNT" -gt 1 ]; then
        log "WARN" "Found $COUNT [Header.Syncer] sections. Removing duplicates"
        if ! awk '
            BEGIN { in_dup = 0; syncer_seen = 0 }
            /^[[:space:]]*\[Header\.Syncer\]/ {
                if (syncer_seen == 0) { syncer_seen = 1; in_dup = 0; print; next }
                else { in_dup = 1; next }
            }
            /^[[:space:]]*\[/ { in_dup = 0; print; next }
            { if (in_dup == 0) print }
        ' "$LIGHT_NODE_CONFIG_PATH" > "$LIGHT_NODE_CONFIG_PATH.tmp"; then
            log "ERROR" "Failed to sanitize duplicate [Header.Syncer] sections"
            exit 1
        fi
        mv "$LIGHT_NODE_CONFIG_PATH.tmp" "$LIGHT_NODE_CONFIG_PATH"
        log "SUCCESS" "Duplicate [Header.Syncer] sections removed"
    else
        log "INFO" "Only one [Header.Syncer] section present"
    fi
else
    log "INFO" "No [Header.Syncer] section found"
fi

# Align Header.Syncer with trusted state from .env (rewrite the block atomically)
log "CONFIG" "Ensuring Header.Syncer matches trusted state"
PRUNING_WINDOW=${PRUNING_WINDOW:-240h0m0s}
TMP_SYNCER="$LIGHT_NODE_CONFIG_PATH.syncer.tmp"
if ! awk \
    -v hash="$DA_TRUSTED_HASH" \
    -v height="$DA_TRUSTED_HEIGHT" \
    -v prune="$PRUNING_WINDOW" \
    'BEGIN {done=0; in_syncer=0}
     /^[[:space:]]*\[Header\.Syncer\]/ {
         if (!done) {
             print "[Header.Syncer]";
             printf "  SyncFromHash = \"%s\"\n", hash;
             printf "  SyncFromHeight = %s\n", height;
             printf "  PruningWindow = \"%s\"\n", prune;
             done=1;
         }
         in_syncer=1;
         next;
     }
     /^[[:space:]]*\[/ { in_syncer=0 }
     { if (!in_syncer) print }
     END {
         if (!done) {
             print "[Header.Syncer]";
             printf "  SyncFromHash = \"%s\"\n", hash;
             printf "  SyncFromHeight = %s\n", height;
             printf "  PruningWindow = \"%s\"\n", prune;
         }
     }' "$LIGHT_NODE_CONFIG_PATH" > "$TMP_SYNCER"; then
    log "ERROR" "Failed to rewrite Header.Syncer block"
    exit 1
fi
mv "$TMP_SYNCER" "$LIGHT_NODE_CONFIG_PATH"
log "SUCCESS" "Header.Syncer rewritten to height $DA_TRUSTED_HEIGHT and hash $DA_TRUSTED_HASH"

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
