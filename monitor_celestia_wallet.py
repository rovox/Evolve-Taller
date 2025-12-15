#!/usr/bin/env python3
"""
Celestia Wallet Monitor
Monitors wallet balance, transaction history, and provides alerts
"""

import json
import subprocess
import sys
from datetime import datetime


def get_wallet_balance():
    """Get current Celestia wallet balance"""
    try:
        cmd = ["docker", "exec", "celestia-node", "celestia", "state", "balance", "--node.store", "/home/celestia"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            data = json.loads(result.stdout)
            balance = int(data.get("result", {}).get("amount", "0"))
            denom = data.get("result", {}).get("denom", "utia")
            return balance, denom
        else:
            print(f"❌ Error getting balance: {result.stderr}")
            return None, None
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None, None


def get_wallet_address():
    """Get Celestia wallet address"""
    try:
        cmd = ["docker", "exec", "celestia-node", "celestia", "state", "account-address", "--node.store", "/home/celestia"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            data = json.loads(result.stdout)
            return data.get("result", "")
        else:
            return None
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None


def analyze_sequencer_logs():
    """Analyze sequencer logs for blob submission activity"""
    try:
        cmd = ["docker", "logs", "single-sequencer", "--tail", "100"]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        logs = result.stdout
        
        # Count submissions
        successful = logs.count("blob submitted") + logs.count("Submitted blobs")
        failed = logs.count("DA layer submission failed")
        insufficient_funds = logs.count("insufficient funds")
        
        # Extract recent blob costs (if available in logs)
        # This is a simplified analysis - actual costs would need more detailed parsing
        
        return {
            "successful_submissions": successful,
            "failed_submissions": failed,
            "insufficient_funds_errors": insufficient_funds,
            "total_attempts": successful + failed
        }
    except Exception as e:
        print(f"❌ Error analyzing logs: {e}")
        return None


def estimate_remaining_capacity(balance, avg_cost_per_blob=100537):
    """Estimate how many blob submissions can be made with current balance"""
    if balance is None or balance == 0:
        return 0
    return balance // avg_cost_per_blob


def main():
    """Main monitoring function"""
    print("=" * 70)
    print("🌌 Celestia Wallet Monitor")
    print("=" * 70)
    print(f"Timestamp: {datetime.now().isoformat()}\n")
    
    # Get wallet info
    address = get_wallet_address()
    if address:
        print(f"📍 Wallet Address: {address}")
        print(f"   Celenium Explorer: https://mocha.celenium.io/address/{address}\n")
    
    # Get balance
    balance, denom = get_wallet_balance()
    if balance is not None:
        print(f"💰 Current Balance: {balance:,} {denom}")
        
        # Estimate capacity
        avg_cost = 100537  # Average cost per blob submission (from logs)
        remaining_blobs = estimate_remaining_capacity(balance, avg_cost)
        
        print(f"   Average Blob Cost: ~{avg_cost:,} {denom}")
        print(f"   Estimated Capacity: ~{remaining_blobs} blob submissions\n")
        
        # Alert if low
        if balance < avg_cost:
            print("⚠️  WARNING: Balance critically low! Cannot submit blobs.")
            print(f"   Need at least {avg_cost:,} {denom} per submission.\n")
        elif balance < avg_cost * 10:
            print("⚠️  CAUTION: Balance low. Consider refunding soon.")
            print(f"   Less than 10 submissions remaining.\n")
        else:
            print("✅ Balance sufficient for operations.\n")
    
    # Analyze recent activity
    print("📊 Recent Activity Analysis:")
    log_analysis = analyze_sequencer_logs()
    
    if log_analysis:
        print(f"   ✅ Successful Submissions: {log_analysis['successful_submissions']}")
        print(f"   ❌ Failed Submissions: {log_analysis['failed_submissions']}")
        print(f"   💸 Insufficient Funds Errors: {log_analysis['insufficient_funds_errors']}")
        print(f"   📈 Total Attempts: {log_analysis['total_attempts']}\n")
        
        if log_analysis['total_attempts'] > 0:
            success_rate = (log_analysis['successful_submissions'] / log_analysis['total_attempts']) * 100
            print(f"   Success Rate: {success_rate:.1f}%\n")
    
    # Save monitoring data
    monitoring_data = {
        "timestamp": datetime.now().isoformat(),
        "wallet": {
            "address": address,
            "balance": balance,
            "denom": denom,
            "estimated_capacity": remaining_blobs if balance else 0
        },
        "activity": log_analysis,
        "alerts": []
    }
    
    if balance and balance < avg_cost:
        monitoring_data["alerts"].append("CRITICAL: Balance too low for blob submissions")
    elif balance and balance < avg_cost * 10:
        monitoring_data["alerts"].append("WARNING: Balance running low")
    
    # Save to file for frontend
    output_file = "/home/robvox/evolve-deployment/frontend/celestia_wallet_status.json"
    with open(output_file, "w") as f:
        json.dump(monitoring_data, f, indent=2)
    
    print(f"💾 Monitoring data saved to: {output_file}")
    
    print("\n" + "=" * 70)
    
    # Exit with error code if critically low
    if balance and balance < avg_cost:
        sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()
