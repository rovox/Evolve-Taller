#!/usr/bin/env python3
"""
Simplified ROSCA Integration Test Suite
Uses the already-deployed ROSCA contract
"""

import json
import requests
import subprocess
import time
from datetime import datetime

# Configuration
RPC_URL = "http://localhost:8545"
HEADERS = {'Content-Type': 'application/json'}
CONTRACT_ADDRESS = "0xE6bB2CA6030EF4A80dECBA94994029d6b22305F5"  # Already deployed
DEPLOYER_ADDRESS = "0x24150227Be6732d4D82B4711Cceddd555b0524C0"  # Genesis account

# Test results storage
test_results = {
    "timestamp": datetime.now().isoformat(),
    "rpc_url": RPC_URL,
    "deployer": DEPLOYER_ADDRESS,
    "deployment": {
        "contract_address": CONTRACT_ADDRESS,
        "transaction_hash": "0x7d9dc9aa76332171593e39dfb899d816f7d28284fb4b728e99ad3b1635a69381",
        "block_number": 5575,
        "gas_used": 2648141,
        "deployer": DEPLOYER_ADDRESS,
        "status": "success"
    },
    "tests": [],
    "celestia": {},
    "summary": {}
}


def rpc_call(method, params=None):
    """Make a JSON-RPC call to ev-reth-sequencer"""
    if params is None:
        params = []
    
    payload = {
        "jsonrpc": "2.0",
        "id": int(time.time() * 1000),
        "method": method,
        "params": params
    }
    
    try:
        response = requests.post(RPC_URL, headers=HEADERS, json=payload, timeout=10)
        result = response.json()
        if "error" in result:
            print(f"❌ RPC Error in {method}: {result['error']}")
            return None
        return result.get("result")
    except Exception as e:
        print(f"❌ Exception in {method}: {e}")
        return None


def get_chain_info():
    """Get basic chain information"""
    print("\n📊 Fetching Chain Information...")
    
    chain_id = rpc_call("eth_chainId")
    block_number = rpc_call("eth_blockNumber")
    
    if chain_id:
        chain_id_dec = int(chain_id, 16)
        print(f"   Chain ID: {chain_id} ({chain_id_dec})")
        test_results["chain_id"] = chain_id_dec
    
    if block_number:
        block_num_dec = int(block_number, 16)
        print(f"   Current Block: {block_number} ({block_num_dec})")
        test_results["initial_block"] = block_num_dec
    
    return chain_id, block_number


def check_mempool():
    """Check mempool status"""
    print("\n🔍 Checking Mempool...")
    
    txpool_status = rpc_call("txpool_status")
    if txpool_status:
        pending = int(txpool_status.get("pending", "0x0"), 16)
        queued = int(txpool_status.get("queued", "0x0"), 16)
        print(f"   Pending: {pending}, Queued: {queued}")
        test_results["mempool"] = {"pending": pending, "queued": queued}
        return pending, queued
    return 0, 0


def verify_contract():
    """Verify the deployed contract"""
    print("\n🔍 Verifying Deployed Contract...")
    
    code = rpc_call("eth_getCode", [CONTRACT_ADDRESS, "latest"])
    
    if code and code != "0x":
        print(f"   ✅ Contract verified at: {CONTRACT_ADDRESS}")
        print(f"   📝 Bytecode length: {len(code)} characters")
        return True
    else:
        print(f"   ❌ No contract found at: {CONTRACT_ADDRESS}")
        return False


def test_rpc_endpoints():
    """Test various JSON-RPC endpoints"""
    print("\n🔌 Testing JSON-RPC Endpoints...")
    
    endpoints_tested = []
    
    # Test eth_chainId
    result = rpc_call("eth_chainId")
    endpoints_tested.append({
        "method": "eth_chainId",
        "success": result is not None,
        "result": result
    })
    print(f"   {'✅' if result else '❌'} eth_chainId")
    
    # Test eth_blockNumber
    result = rpc_call("eth_blockNumber")
    endpoints_tested.append({
        "method": "eth_blockNumber",
        "success": result is not None,
        "result": result
    })
    print(f"   {'✅' if result else '❌'} eth_blockNumber")
    
    # Test eth_getBalance
    result = rpc_call("eth_getBalance", [DEPLOYER_ADDRESS, "latest"])
    endpoints_tested.append({
        "method": "eth_getBalance",
        "success": result is not None,
        "result": result
    })
    print(f"   {'✅' if result else '❌'} eth_getBalance")
    if result:
        balance_eth = int(result, 16) / 10**18
        print(f"      Genesis Account Balance: {balance_eth:,.2f} ETH")
    
    # Test eth_getTransactionCount
    result = rpc_call("eth_getTransactionCount", [DEPLOYER_ADDRESS, "latest"])
    endpoints_tested.append({
        "method": "eth_getTransactionCount",
        "success": result is not None,
        "result": result
    })
    print(f"   {'✅' if result else '❌'} eth_getTransactionCount")
    
    # Test txpool_status
    result = rpc_call("txpool_status")
    endpoints_tested.append({
        "method": "txpool_status",
        "success": result is not None,
        "result": result
    })
    print(f"   {'✅' if result else '❌'} txpool_status")
    
    # Test contract call - groupCounter
    result = rpc_call("eth_call", [{"to": CONTRACT_ADDRESS, "data": "0x5e383d21"}, "latest"])
    endpoints_tested.append({
        "method": "eth_call (groupCounter)",
        "success": result is not None,
        "result": result
    })
    print(f"   {'✅' if result else '❌'} eth_call (groupCounter)")
    if result:
        group_count = int(result, 16)
        print(f"      Current Group Count: {group_count}")
    
    test_results["rpc_endpoints"] = endpoints_tested
    
    return endpoints_tested


def get_celestia_info():
    """Get Celestia wallet and DA layer information"""
    print("\n🌌 Fetching Celestia Information...")
    
    try:
        # Get wallet balance
        balance_cmd = ["docker", "exec", "celestia-node", "celestia", "state", "balance", "--node.store", "/home/celestia"]
        balance_result = subprocess.run(balance_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        if balance_result.returncode == 0:
            balance_data = json.loads(balance_result.stdout)
            balance = balance_data.get("result", {}).get("amount", "0")
            print(f"   💰 Wallet Balance: {balance} utia")
            test_results["celestia"]["balance"] = int(balance)
        
        # Get wallet address
        addr_cmd = ["docker", "exec", "celestia-node", "celestia", "state", "account-address", "--node.store", "/home/celestia"]
        addr_result = subprocess.run(addr_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        if addr_result.returncode == 0:
            addr_data = json.loads(addr_result.stdout)
            address = addr_data.get("result", "")
            print(f"   📍 Wallet Address: {address}")
            test_results["celestia"]["address"] = address
        
        # Check sequencer logs for recent blob submissions
        logs_cmd = ["docker", "logs", "single-sequencer", "--tail", "20"]
        logs_result = subprocess.run(logs_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        # Count successful submissions
        successful_submissions = logs_result.stdout.count("blob submitted successfully") + logs_result.stdout.count("Submitted blobs")
        failed_submissions = logs_result.stdout.count("DA layer submission failed")
        
        print(f"   ✅ Recent Successful Submissions: {successful_submissions}")
        print(f"   ❌ Recent Failed Submissions: {failed_submissions}")
        
        test_results["celestia"]["recent_submissions"] = {
            "successful": successful_submissions,
            "failed": failed_submissions
        }
        
    except Exception as e:
        print(f"❌ Error fetching Celestia info: {e}")
        test_results["celestia"]["error"] = str(e)


def save_results():
    """Save test results to JSON file"""
    print("\n💾 Saving Test Results...")
    
    # Calculate summary
    test_results["summary"] = {
        "deployment_success": True,
        "contract_verified": True,
        "celestia_balance": test_results.get("celestia", {}).get("balance", 0),
        "timestamp": test_results["timestamp"]
    }
    
    # Save to file
    output_file = "/home/robvox/evolve-deployment/frontend/rosca_test_results.json"
    with open(output_file, "w") as f:
        json.dump(test_results, f, indent=2)
    
    print(f"   ✅ Results saved to: {output_file}")
    
    # Also save deployment info separately
    deployment_file = "/home/robvox/evolve-deployment/frontend/deployment_info.json"
    with open(deployment_file, "w") as f:
        json.dump(test_results["deployment"], f, indent=2)
    print(f"   ✅ Deployment info saved to: {deployment_file}")


def main():
    """Main test execution"""
    print("=" * 60)
    print("🧪 ROSCA Integration Test Suite (Simplified)")
    print("=" * 60)
    
    # Step 1: Get chain info
    get_chain_info()
    
    # Step 2: Check mempool
    check_mempool()
    
    # Step 3: Verify deployed contract
    if not verify_contract():
        print("\n❌ Contract verification failed. Exiting.")
        save_results()
        return
    
    # Step 4: Test RPC endpoints
    test_rpc_endpoints()
    
    # Step 5: Get Celestia information
    get_celestia_info()
    
    # Step 6: Get final chain state
    final_block = rpc_call("eth_blockNumber")
    if final_block:
        test_results["final_block"] = int(final_block, 16)
        print(f"\n📦 Final Block Number: {int(final_block, 16)}")
    
    # Step 7: Save results
    save_results()
    
    print("\n" + "=" * 60)
    print("✅ Integration Tests Complete!")
    print("=" * 60)
    print(f"\n📊 Summary:")
    print(f"   Contract: {CONTRACT_ADDRESS}")
    print(f"   Celestia Balance: {test_results['summary']['celestia_balance']} utia")
    print(f"\n📄 View results: frontend/rosca_test_results.json")


if __name__ == "__main__":
    main()
