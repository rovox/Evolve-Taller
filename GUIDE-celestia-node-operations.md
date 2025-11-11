# Celestia Light Node Operations Guide (Mocha Network)

## 1. Overview
This guide explains how your current Celestia light node (service `celestia-node`) operates using a public Core RPC, how to inspect health, submit blobs, query balances, and safely manage keys & Docker resources. It complements the audit file.

## 2. Runtime Architecture
- Node Type: Light (`celestia light start`)
- Image: `ghcr.io/celestiaorg/celestia-node:v0.28.2-mocha`
- Public Core RPC: `rpc-mocha.pops.one:9090` (non-TLS)
- Exposed RPC Port (host): `26658` mapped to container `26658`
- Data Volume: `celestia-node-data` mounted at `/home/celestia`
- Entrypoint Script: `stacks/da-celestia/entrypoint.da.sh` handles one-time init with lock file `.initialized`

## 3. Key & Account Management
Your wallet (default signer) lives under `/home/celestia/keys` inside the volume. The CLI uses this signer automatically.

### 3.1 Show Address
```bash
# Inside host (using container):
docker exec celestia-node celestia state account-address
```
Output example:
```json
{ "result": "celestia1990a2zkjnx0n3wzkkg87u9gvfzmppxxq5afm0f" }
```

### 3.2 Show Balance
```bash
docker exec celestia-node celestia state balance
```
Returns denom + amount, e.g. `utia`.

### 3.3 Backup Keys (Recommended before any reset)
```bash
# Create backup archive inside container
docker exec celestia-node bash -c 'tar -czf /home/celestia/key-backup-$(date +%Y%m%d).tar.gz -C /home/celestia keys'
# Copy to host
docker cp celestia-node:/home/celestia/key-backup-$(date +%Y%m%d).tar.gz ./backups/
# Verify
tar -tzf ./backups/key-backup-$(date +%Y%m%d).tar.gz | head
```
Keep this archive offline if possible.

### 3.4 Avoiding Key Loss
- Never delete the volume `celestia-node-data` without a backup.
- Do not remove `/home/celestia/.initialized` unless you intend to re-init.
- When pruning images/containers, ensure the volume name is not removed (use `docker volume ls` to confirm).

## 4. Health & Monitoring
### 4.1 Healthcheck Logic
Current Docker healthcheck executes JSON-RPC `p2p.Info` and verifies a `result` key. This ensures RPC server + module wiring.

### 4.2 Manual RPC Probes
```bash
# Peer info
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"p2p.Info"}' http://localhost:26658 | jq '.'

# Network head (height, chain id)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":2,"method":"header.NetworkHead"}' http://localhost:26658 | jq '.'
```

### 4.3 Quick Latency Check Script
```bash
#!/usr/bin/env bash
REQ='{"jsonrpc":"2.0","id":1,"method":"header.NetworkHead"}'
START=$(date +%s%3N)
RESP=$(curl -s -X POST -H 'Content-Type: application/json' --data "$REQ" http://localhost:26658)
END=$(date +%s%3N)
MS=$((END-START))
HEIGHT=$(echo "$RESP" | jq -r '.result.header.height')
echo "height=$HEIGHT latency=${MS}ms"
```

## 5. Blob Submission (Data Availability Posting)
Light nodes can submit blobs (PayForBlob) using the node’s default signer.

### 5.1 Concept
A blob is namespaced data posted to the DA layer. Submission returns the height where included. You must choose a namespace (8 bytes in v0) and provide blob data. Gas price can be set (often default function in client libs).

### 5.2 Using celestia-openrpc Client (Go Example)
Reference snippet adapted from `celestia-openrpc` README:
```go
namespace, _ := share.NewBlobNamespaceV0([]byte{0xDE, 0xAD, 0xBE, 0xEF})
helloBlob, _ := blob.NewBlobV0(namespace, []byte("Hello, World!"))
height, err := client.Blob.Submit(ctx, []*blob.Blob{helloBlob}, blob.DefaultGasPrice())
```
The client handles JSON-RPC calls (WebSocket or HTTP). For simple tests you can use HTTP POST.

### 5.3 Raw JSON-RPC Pattern (HTTP POST)
`blob.Submit` generally expects a list of blobs serialized. Manual crafting is complex (namespaces, commitments, version flags). Prefer the Go client or community libraries. If you must do raw JSON-RPC:
1. Generate blob structure (namespace + data + commitment) via library.
2. POST: `{"jsonrpc":"2.0","id":1,"method":"blob.Submit","params":[<serialized blobs>, <gasPrice>]}`
3. Receive `{ "result": <height> }`.

### 5.4 Fetching Blobs
```go
retrieved, err := client.Blob.GetAll(ctx, height, []share.Namespace{namespace})
```
Compare commitments to ensure integrity.

## 6. Resource Consumption & Cleanup
### 6.1 Current Images
- In-use: `celestia-node:v0.28.2-mocha` (~578MB)
- Legacy / removable: `busybox:latest` (~4MB) if not referenced by any active container; used sometimes in multi-step init but now absent.
- Base image: `ghcr.io/linuxserver/baseimage-alpine:3.22` (~367MB) — only needed if another stack depends on it (not for the light node). Remove if unused.

### 6.2 Check Usage
```bash
docker ps
docker images
docker stats --no-stream
```
If `busybox` and `linuxserver/baseimage-alpine` have no containers (`docker ps -a`), they can be safely removed:
```bash
docker image rm busybox:latest ghcr.io/linuxserver/baseimage-alpine:3.22
```

### 6.3 Volume Size
To inspect:
```bash
docker run --rm -v celestia-node-data:/data busybox sh -c 'du -sh /data'
```
Monitor growth; prune only with backups.

## 7. Recovery / Re-Init Procedure
If corruption occurs:
1. Stop container: `docker stop celestia-node`
2. Backup keys directory.
3. Remove `.initialized` file: `docker exec celestia-node rm /home/celestia/.initialized`
4. Start container again → init logic runs; verify `config.toml` retains Core IP.
5. Re-check balance.

## 8. Common Pitfalls
| Issue | Cause | Resolution |
|-------|-------|------------|
| Unhealthy (old healthcheck) | Invalid /status GET | Use JSON-RPC p2p.Info probe |
| TLS errors | Endpoint lacks TLS | Keep `TLSEnabled=false` |
| Lost keys | Volume removal without backup | Always archive `keys` first |
| Init repeating | Lock file deleted accidentally | Restore from backup or let re-init run |

## 9. Verification Checklist (Daily)
- `docker ps` shows `celestia-node` (healthy)
- `header.NetworkHead` responds with increasing height
- `celestia state balance` returns expected amount
- Volume size within expected growth threshold

## 10. Quick Commands Summary
```bash
# Address
docker exec celestia-node celestia state account-address
# Balance
docker exec celestia-node celestia state balance
# Peer Info
curl -s -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"p2p.Info"}' http://localhost:26658 | jq '.'
# Network Head
curl -s -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":2,"method":"header.NetworkHead"}' http://localhost:26658 | jq '.'
# Key Backup
docker exec celestia-node bash -c 'tar -czf /home/celestia/key-backup-$(date +%Y%m%d).tar.gz -C /home/celestia keys'
# Remove unused images (if no containers depend)
docker image rm busybox:latest ghcr.io/linuxserver/baseimage-alpine:3.22
```

## 11. Next Enhancements
- Add automated cron for latency + height logging.
- Integrate alert if height stagnates > X minutes.
- Explore signing blobs via a client library for structured submission tests.

---
Generated on 2025-11-11.
