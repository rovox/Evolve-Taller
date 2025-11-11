# Celestia Light Node Audit (da-celestia) – 2025-11-11

## 1. Scope & Executive Summary
This audit covers the current state of the simplified Celestia light node deployment inside the `stacks/da-celestia` stack after removing the local consensus (`celestia-appd`) services. The node now peers directly with the public Mocha network via `rpc-mocha.pops.one:9090` and maintains the existing wallet/keyring. Overall the node is healthy (actively syncing headers and performing DAS sampling) but the previous healthcheck produced false negatives. Storage and image footprint are moderate and can be optimized by pruning unused consensus images.

## 2. Architecture Snapshot
Service: `celestia-node` (light node) – Image: `ghcr.io/celestiaorg/celestia-node:v0.28.2-mocha`
Volume: `celestia-node-data` mounted at `/home/celestia` (contains `config.toml`, keyring, data store)
Entrypoint script: `entrypoint.da.sh` handles one-time init (guarded by `.initialized`) then starts RPC (`--rpc.skip-auth`).
Network: Attached to shared bridge `evstack_shared`; DNS overrides (8.8.8.8 / 8.8.4.4) ensure external Core endpoint resolution.
Core endpoint: `rpc-mocha.pops.one:9090` (non-TLS; TLS explicitly disabled in `config.toml`).

## 3. Recent Changes Implemented
- Removed consensus-related init/app containers from compose.
- Updated `.env` to set `DA_CORE_IP=rpc-mocha.pops.one`, `DA_NETWORK=mocha`.
- Removed TLS flags from the entrypoint; set `TLSEnabled = false` in `config.toml`.
- Preserved wallet and keyring untouched (no re-init of node because lock file `.initialized` retained).
- Replaced healthcheck (`GET /status`) with JSON-RPC `p2p.Info` call for accurate readiness.

## 4. Configuration Integrity
`config.toml` Core section:
- IP: `rpc-mocha.pops.one`
- Port: `9090`
- `TLSEnabled = false` (required; endpoint doesn’t offer TLS).
RPC:
- Bound `0.0.0.0:26658` via start flags.
- `--rpc.skip-auth` allows unauthenticated local access (appropriate for devnet environment; consider removing in production).
Initialization logic in `entrypoint.da.sh` only runs once; subsequent starts skip sed mutations (trusted height/hash now legacy/unreferenced unless re-init is forced).

## 5. Operational Health
Observed behaviors (logs):
- Continuous header synchronization (no stall events).
- DAS sampling succeeding at intervals (indicates availability data being processed).
Previous healthcheck status: Unhealthy due to `curl /status` returning JSON-RPC error (“Invalid request”). Updated healthcheck now asserts presence of a `result` field in `p2p.Info` response, aligning container health with functional state.

### Recommended Runtime Metric (optional)
You may extend monitoring to probe `header.NetworkHead` or `share.Availability` for richer status; current lightweight check balances reliability and overhead.

## 6. Security & Key Management
Wallet/keyring location: `/home/celestia/keys` inside volume.
Public address (example previously retrieved): `celestia1990a2zkjnx0n3wzkkg87u9gvfzmppxxq5afm0f`.
No mnemonic or private keys exposed in repository; backups should be performed before any volume reset.

### Backup Procedure (Suggested)
1. Create archive inside container:
   `docker exec celestia-node tar -czf /home/celestia/key-backup-$(date +%Y%m%d).tar.gz -C /home/celestia keys`
2. Copy to host:
   `docker cp celestia-node:/home/celestia/key-backup-$(date +%Y%m%d).tar.gz ./backups/`
3. Verify archive integrity (size > 0; optionally list contents with `tar -tzf`).

## 7. Resource Usage
Approximate current footprints (from prior inspection):
- Light node data volume: ~5–7 GB (expected to grow over time with blockstore & headers).
- In-use image: `celestia-node:v0.28.2-mocha` ~578 MB.
- Unused images (removable): `celestia-app:v6.2.0-mocha`, `celestia-app:v6.2.2-mocha` (~400 MB each).

### Cleanup Commands (Safe)
Remove unused consensus images:
`docker image rm ghcr.io/celestiaorg/celestia-app:v6.2.0-mocha ghcr.io/celestiaorg/celestia-app:v6.2.2-mocha`

Optional: Prune dangling layers (ensure no other containers depend on them):
`docker image prune -f`

Optional: Compress/export key backup + snapshot before aggressive cleanup:
`docker exec celestia-node tar -czf /home/celestia/node-snapshot-$(date +%Y%m%d).tar.gz -C /home celestia`

## 8. Healthcheck Rationale
Old check: `curl -f /status` → endpoint returns JSON-RPC error for malformed request ⇒ false negatives.
New check: JSON-RPC POST `p2p.Info` ensures RPC server responds and internal modules are wired. Low-cost & available early in startup.
Fallback alternative: `header.NetworkHead` (slightly more expensive but confirms header service readiness).

## 9. Risks & Edge Cases
- Re-init Risk: Deleting `.initialized` without backing up keys would trigger fresh config and potential key changes.
- Core Endpoint Availability: If `rpc-mocha.pops.one` degrades, node still syncs via P2P but some RPC Core-dependent calls may degrade.
- Volume Growth: Long-running DAS operation will expand storage; monitor and consider periodic pruning (if supported) or increasing host disk allocation.
- Skip-Auth Exposure: Local processes can issue RPC calls without auth; in multi-tenant hosts disable `--rpc.skip-auth`.

## 10. Recommendations (Actionable)
1. Execute key backup immediately (low effort / high safety).
2. Remove unused `celestia-app` images to reclaim ~800 MB.
3. Add lightweight monitoring (cron or external script) invoking `header.NetworkHead` and logging latency.
4. Document recovery: steps to restore from key backup + trusted height acquisition process.
5. Plan periodic storage audit (weekly) to track data growth; threshold alert at e.g. 20 GB.

## 11. Recovery & Re-init Procedure (Reference)
If forced to re-init (e.g. config corruption):
1. Stop container.
2. Backup keys directory & existing `config.toml`.
3. Remove `.initialized` lock file.
4. Start container → entrypoint re-runs init.
5. Re-apply any custom trusted state changes if required.

## 12. Verification Checklist (Post-Audit)
- [x] Container running and healthy (new healthcheck).
- [x] Headers syncing & DAS sampling logs present.
- [x] Wallet preserved (address unchanged).
- [x] Core endpoint reachable non-TLS.
- [ ] Key backup archived (pending execution).
- [ ] Unused images removed (pending cleanup).

## 13. Appendix – Suggested Monitoring Script (Optional)
```bash
#!/usr/bin/env bash
set -euo pipefail
RPC="http://localhost:26658"
REQ='{"jsonrpc":"2.0","id":1,"method":"header.NetworkHead"}'
START=$(date +%s%3N)
RESP=$(curl -s -X POST -H 'Content-Type: application/json' --data "$REQ" "$RPC" || true)
END=$(date +%s%3N)
LATENCY=$((END-START))
if echo "$RESP" | grep -q 'result'; then
  echo "OK latency=${LATENCY}ms $(echo "$RESP" | sed -n 's/.*\"height\":\([0-9]*\).*/height=\1/p')"
else
  echo "FAIL latency=${LATENCY}ms raw=$RESP" >&2
  exit 1
fi
```

---
Prepared automatically on 2025-11-11. Amend with future observations or attach key backup confirmation when completed.
