#!/usr/bin/env python3
"""
DA Consumption Analyzer
Analyzes Celestia DA layer consumption patterns and costs
"""

import json
import subprocess
import re
from datetime import datetime
from collections import defaultdict


def parse_sequencer_logs(num_lines=500):
    """Parse sequencer logs to extract DA submission information"""
    try:
        cmd = ["docker", "logs", "single-sequencer", "--tail", str(num_lines)]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        logs = result.stdout
        return logs
    except Exception as e:
        print(f"❌ Error reading logs: {e}")
        return ""


def analyze_blob_submissions(logs):
    """Analyze blob submission patterns"""
    analysis = {
        "successful": 0,
        "failed": 0,
        "insufficient_funds": 0,
        "costs": [],
        "error_types": defaultdict(int)
    }
    
    # Count successful submissions
    analysis["successful"] = logs.count("blob submitted") + logs.count("Submitted blobs")
    
    # Count failed submissions
    analysis["failed"] = logs.count("DA layer submission failed")
    
    # Count insufficient funds errors
    analysis["insufficient_funds"] = logs.count("insufficient funds")
    
    # Extract cost information from error messages
    # Pattern: "spendable balance XXXutia is smaller than YYYutia"
    cost_pattern = r'smaller than (\d+)utia'
    costs = re.findall(cost_pattern, logs)
    analysis["costs"] = [int(c) for c in costs]
    
    # Categorize error types
    if "insufficient funds" in logs:
        analysis["error_types"]["insufficient_funds"] = logs.count("insufficient funds")
    if "validation failed" in logs:
        analysis["error_types"]["validation_failed"] = logs.count("validation failed")
    if "broadcast tx error" in logs:
        analysis["error_types"]["broadcast_error"] = logs.count("broadcast tx error")
    
    return analysis


def analyze_submission_triggers(logs):
    """Analyze what triggers blob submissions"""
    triggers = {
        "block_production": 0,
        "time_based": 0,
        "transaction_batching": 0
    }
    
    # Look for patterns indicating submission triggers
    # This is simplified - actual triggers would need more detailed log analysis
    
    # Count block-related submissions
    triggers["block_production"] = logs.count("new block") + logs.count("block produced")
    
    # Count time-based submissions (DA_BLOCK_TIME=30s)
    triggers["time_based"] = logs.count("DA block time") + logs.count("30s")
    
    return triggers


def calculate_statistics(analysis):
    """Calculate consumption statistics"""
    stats = {}
    
    total_attempts = analysis["successful"] + analysis["failed"]
    stats["total_attempts"] = total_attempts
    
    if total_attempts > 0:
        stats["success_rate"] = (analysis["successful"] / total_attempts) * 100
        stats["failure_rate"] = (analysis["failed"] / total_attempts) * 100
    else:
        stats["success_rate"] = 0
        stats["failure_rate"] = 0
    
    if analysis["costs"]:
        stats["avg_cost_per_blob"] = sum(analysis["costs"]) / len(analysis["costs"])
        stats["min_cost"] = min(analysis["costs"])
        stats["max_cost"] = max(analysis["costs"])
        stats["total_cost_attempted"] = sum(analysis["costs"])
    else:
        stats["avg_cost_per_blob"] = 100537  # Default estimate
        stats["min_cost"] = 0
        stats["max_cost"] = 0
        stats["total_cost_attempted"] = 0
    
    return stats


def main():
    """Main analysis function"""
    print("=" * 70)
    print("📊 Celestia DA Consumption Analyzer")
    print("=" * 70)
    print(f"Timestamp: {datetime.now().isoformat()}\n")
    
    # Parse logs
    print("📖 Parsing sequencer logs...")
    logs = parse_sequencer_logs(num_lines=1000)
    
    if not logs:
        print("❌ No logs available")
        return
    
    # Analyze blob submissions
    print("\n🔍 Analyzing Blob Submissions...")
    analysis = analyze_blob_submissions(logs)
    
    print(f"   ✅ Successful: {analysis['successful']}")
    print(f"   ❌ Failed: {analysis['failed']}")
    print(f"   💸 Insufficient Funds Errors: {analysis['insufficient_funds']}")
    
    # Calculate statistics
    print("\n📈 Statistics:")
    stats = calculate_statistics(analysis)
    
    print(f"   Total Attempts: {stats['total_attempts']}")
    print(f"   Success Rate: {stats['success_rate']:.1f}%")
    print(f"   Failure Rate: {stats['failure_rate']:.1f}%")
    
    if analysis["costs"]:
        print(f"\n💰 Cost Analysis:")
        print(f"   Average Cost per Blob: {stats['avg_cost_per_blob']:,.0f} utia")
        print(f"   Min Cost: {stats['min_cost']:,} utia")
        print(f"   Max Cost: {stats['max_cost']:,} utia")
        print(f"   Total Cost Attempted: {stats['total_cost_attempted']:,} utia")
    
    # Analyze triggers
    print("\n🎯 Submission Triggers:")
    triggers = analyze_submission_triggers(logs)
    print(f"   Block Production Events: {triggers['block_production']}")
    print(f"   Time-based Events: {triggers['time_based']}")
    
    # Error breakdown
    if analysis["error_types"]:
        print("\n❌ Error Breakdown:")
        for error_type, count in analysis["error_types"].items():
            print(f"   {error_type}: {count}")
    
    # Recommendations
    print("\n💡 Recommendations:")
    
    if analysis["insufficient_funds"] > 0:
        print("   ⚠️  Wallet needs refunding - insufficient funds detected")
    
    if stats["failure_rate"] > 50:
        print("   ⚠️  High failure rate - investigate network or configuration issues")
    
    if stats.get("avg_cost_per_blob", 0) > 150000:
        print("   ⚠️  High blob costs - consider optimizing data size or batching")
    
    if analysis["successful"] > 0:
        print("   ✅ Blob submissions are working when funds are available")
    
    # Save analysis results
    results = {
        "timestamp": datetime.now().isoformat(),
        "analysis": {
            "successful_submissions": analysis["successful"],
            "failed_submissions": analysis["failed"],
            "insufficient_funds_errors": analysis["insufficient_funds"]
        },
        "statistics": stats,
        "triggers": triggers,
        "error_types": dict(analysis["error_types"]),
        "recommendations": []
    }
    
    if analysis["insufficient_funds"] > 0:
        results["recommendations"].append("Refund wallet - insufficient funds detected")
    if stats["failure_rate"] > 50:
        results["recommendations"].append("Investigate high failure rate")
    
    output_file = "/home/robvox/evolve-deployment/frontend/da_consumption_analysis.json"
    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\n💾 Analysis saved to: {output_file}")
    print("\n" + "=" * 70)


if __name__ == "__main__":
    main()
