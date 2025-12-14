import json
import requests
import sys

RPC_URL = "http://localhost:8545"
HEADERS = {'Content-Type': 'application/json'}

def send_raw_tx(raw_tx):
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_sendRawTransaction",
        "params": [raw_tx.strip()]
    }
    response = requests.post(RPC_URL, headers=HEADERS, json=payload)
    return response.json()

if __name__ == "__main__":
    with open('/tmp/raw_tx.hex', 'r') as f:
        raw_tx = f.read()
    
    print(f"Sending raw tx: {raw_tx[:20]}...")
    resp = send_raw_tx(raw_tx)
    print(f"Response: {resp}")
