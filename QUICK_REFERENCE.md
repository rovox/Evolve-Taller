# Quick Reference Guide - EVM Integration Tests & Celestia Monitoring

## Running the Tests

### Full Integration Test Suite
```bash
cd /home/robvox/evolve-deployment
python3 test_rosca_integration.py
```
This will:
- Test all JSON-RPC endpoints
- Deploy ROSCA contract
- Run Foundry tests
- Generate `frontend/rosca_test_results.json`

### Monitor Celestia Wallet
```bash
python3 monitor_celestia_wallet.py
```
Generates: `frontend/celestia_wallet_status.json`

### Analyze DA Consumption
```bash
python3 analyze_da_consumption.py
```
Generates: `frontend/da_consumption_analysis.json`

## Viewing the Dashboard

```bash
cd frontend
python serve.py
# Open http://localhost:8000
```

Navigate to:
- **Integration Tests** tab - View test results and deployment info
- **Celestia Monitor** tab - Track wallet balance and DA consumption

## Current Status

**Celestia Wallet:**
- Address: `celestia19f8j7rdes7rfnvlmsgafrpjxhgjayln9jqg6y6`
- Balance: 2,597,245 utia
- Capacity: ~25 blob submissions
- Status: ✅ Operational

**EVM Sequencer:**
- RPC: http://localhost:8545
- Chain ID: 1234
- Status: ✅ Running

## Key Files

| File | Purpose |
|------|---------|
| `test_rosca_integration.py` | Integration test suite |
| `monitor_celestia_wallet.py` | Wallet monitoring |
| `analyze_da_consumption.py` | DA consumption analysis |
| `frontend/index.html` | Dashboard UI |
| `frontend/app.js` | Dashboard logic |

## Troubleshooting

**No test results?**
```bash
# Check if RPC is accessible
curl http://localhost:8545 -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

**Wallet balance not updating?**
```bash
# Check Celestia node
docker exec celestia-node celestia state balance --node.store /home/celestia
```

**Frontend not loading data?**
```bash
# Verify JSON files exist
ls -la frontend/*.json

# Re-run monitoring scripts
python3 monitor_celestia_wallet.py
python3 analyze_da_consumption.py
```

## Useful Links

- Celenium Explorer: https://mocha.celenium.io/address/celestia19f8j7rdes7rfnvlmsgafrpjxhgjayln9jqg6y6
- Celestia Faucet: https://faucet.celestia-mocha-4.com/
