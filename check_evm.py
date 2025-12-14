import json
import requests
import time

RPC_URL = "http://localhost:8545"
HEADERS = {'Content-Type': 'application/json'}

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": int(time.time()),
        "method": method,
        "params": params
    }
    try:
        response = requests.post(RPC_URL, headers=HEADERS, json=payload, timeout=5)
        return response.json()
    except Exception as e:
        return {"error": str(e)}

print(f"Checking {RPC_URL}...")

# 1. Chain ID
resp = rpc_call("eth_chainId")
print(f"Chain ID: {resp.get('result', resp)}")

# 2. Block Number
resp = rpc_call("eth_blockNumber")
print(f"Block Number: {resp.get('result', resp)}")

# 3. Nonce
addr = "0x24150227Be6732d4D82B4711Cceddd555b0524C0"
resp = rpc_call("eth_getTransactionCount", [addr, "latest"])
print(f"Nonce: {resp.get('result', resp)}")

# 4. Send Raw Transaction (Simple transfer)
# We need to sign it validly. Since we don't have web3.py installed easily, we will rely on cast for signing if possible,
# or just check if the node is alive first.

# 5. TxPool content
resp = rpc_call("txpool_content")
print(f"TxPool pending: {resp.get('result', {}).get('pending', 'N/A')}")
