#!/usr/bin/env python3
"""
Enhanced Rollup Stress Test - Python Implementation

This script performs comprehensive stress testing of the Reth node and rollup stack:
- Creates and funds random accounts for state growth
- Sends high-volume transactions with aggressive gas pricing
- Targets 200+ MGas/s throughput with proper nonce management
- Provides real-time monitoring and comprehensive reporting

Features:
- Robust nonce synchronization (prevents NonceTooHigh errors)
- Aggressive gas pricing (5x network price, 10 Gwei minimum)
- Concurrent transaction processing with multiprocessing
- State growth simulation with random account creation
- Real-time gas throughput monitoring
- Comprehensive performance reporting
"""

import asyncio
import json
import logging
import multiprocessing
import random
import secrets
import threading
import time
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import requests
from eth_account import Account
from web3 import Web3

# Configuration
@dataclass
class StressTestConfig:
    # Network settings
    rpc_url: str = "http://localhost:8545"
    chain_id: int = 1234
    
    # Test parameters - minimal to test basic functionality
    concurrent_processes: int = 5  # Limited to available genesis accounts
    transactions_per_process: int = 100  # Very small to test if nonce works
    random_accounts_per_process: int = 5  # Minimal accounts
    time_limit_seconds: int = 120  # 2 minutes
    
    # Transaction settings
    transfer_amount_eth: float = 0.001
    funding_amount_eth: float = 1.0
    sleep_between_tx: float = 0.0  # No delay for maximum throughput
    
    # Gas settings  
    gas_limit: int = 21000  # Standard ETH transfer gas limit
    gas_price_multiplier: int = 10  # 10x network price for very aggressive inclusion
    min_gas_price_gwei: int = 20  # Higher minimum for faster inclusion
    
    # Target performance
    target_gas_per_second: int = 200_000_000  # 200 MGas/s
    
    # Pre-funded accounts (from genesis)
    genesis_accounts: List[str] = None
    
    def __post_init__(self):
        if self.genesis_accounts is None:
            # Only 5 actual genesis accounts from chain/README.md
            self.genesis_accounts = [
                "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",  # Account 1
                "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",  # Account 2
                "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",  # Account 3
                "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",  # Account 4
                "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a",  # Account 5
            ]

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'


def get_pending_nonce(rpc_url: str, address: str) -> int:
    """Get pending nonce for address"""
    try:
        response = requests.post(
            rpc_url,
            json={
                "jsonrpc": "2.0",
                "method": "eth_getTransactionCount",
                "params": [address, "pending"],
                "id": 1
            },
            timeout=2
        )
        
        if response.status_code == 200 and 'result' in response.json():
            return int(response.json()['result'], 16)
        else:
            return 0
            
    except Exception as e:
        print(f"Failed to get nonce for {address}: {e}")
        return 0


def get_aggressive_gas_price(config: StressTestConfig) -> int:
    """Get aggressive gas price for fast inclusion"""
    try:
        # Get current network gas price
        response = requests.post(
            config.rpc_url,
            json={
                "jsonrpc": "2.0",
                "method": "eth_gasPrice",
                "params": [],
                "id": 1
            },
            timeout=2
        )
        
        if response.status_code == 200 and 'result' in response.json():
            base_price = int(response.json()['result'], 16)
        else:
            base_price = Web3.to_wei(1, 'gwei')  # 1 Gwei fallback
        
        # Apply aggressive multiplier and minimum
        aggressive_price = base_price * config.gas_price_multiplier
        min_price = Web3.to_wei(config.min_gas_price_gwei, 'gwei')
        
        return max(aggressive_price, min_price)
        
    except Exception as e:
        print(f"Failed to get gas price: {e}, using fallback")
        return Web3.to_wei(config.min_gas_price_gwei, 'gwei')


def send_transaction_safe(config: StressTestConfig, from_account: Account, to_address: str, 
                         value_wei: int, is_genesis: bool = False) -> Tuple[bool, int, str]:
    """Send a transaction with proper nonce management"""
    max_retries = 5 if is_genesis else 3
    
    for attempt in range(max_retries):
        try:
            # Get current blockchain nonce right before sending
            current_nonce = get_pending_nonce(config.rpc_url, from_account.address)
            gas_price = get_aggressive_gas_price(config)
            
            # Build transaction with current blockchain nonce
            transaction = {
                'to': to_address,
                'value': value_wei,
                'gas': config.gas_limit,
                'gasPrice': gas_price,
                'nonce': current_nonce,
                'chainId': config.chain_id
            }
            
            # Sign transaction
            signed_txn = from_account.sign_transaction(transaction)
            
            # Send transaction
            response = requests.post(
                config.rpc_url,
                json={
                    "jsonrpc": "2.0",
                    "method": "eth_sendRawTransaction", 
                    "params": [signed_txn.raw_transaction.hex()],
                    "id": 1
                },
                timeout=5
            )
            
            if response.status_code == 200 and 'result' in response.json():
                # Transaction sent successfully
                tx_hash = response.json()['result']
                
                # Reduced wait times for higher throughput
                if is_genesis:
                    time.sleep(0.01)  # 10ms wait for genesis accounts
                else:
                    time.sleep(0.005)  # 5ms wait for regular accounts
                
                return True, config.gas_limit, ""
            else:
                error = response.json().get('error', {}).get('message', 'Unknown error')
                
                # If nonce error, wait and retry
                if "nonce" in error.lower() and attempt < max_retries - 1:
                    wait_time = 0.05 if is_genesis else 0.02  # Reduced retry wait times
                    time.sleep(wait_time)
                    continue
                    
                return False, 0, error
                
        except Exception as e:
            if attempt < max_retries - 1:
                wait_time = 0.05 if is_genesis else 0.02  # Reduced exception retry waits
                time.sleep(wait_time)
                continue
            return False, 0, str(e)
    
    return False, 0, "Max retries exceeded"


def create_random_account() -> Account:
    """Create a new random account"""
    private_key = '0x' + secrets.token_hex(32)
    return Account.from_key(private_key)


def stress_test_process(process_id: int, config: StressTestConfig, genesis_accounts: List[Account]) -> Dict:
    """Run stress test for a single process"""
    print(f"{Colors.BLUE}[P{process_id}] 🎲 Starting process...{Colors.END}")
    
    # Each process gets its own dedicated genesis account to avoid nonce conflicts
    # If we have more processes than accounts, we'll need to handle this differently
    if process_id >= len(genesis_accounts):
        print(f"{Colors.RED}[P{process_id}] ❌ Not enough genesis accounts for all processes{Colors.END}")
        return {
            'process_id': process_id,
            'transactions': 0,
            'accounts_created': 0,
            'elapsed': 0,
            'sent': 0,
            'failed': 0,
            'gas_used': 0
        }
    
    genesis_account = genesis_accounts[process_id]
    
    # Local metrics for this process
    local_sent = 0
    local_failed = 0
    local_gas_used = 0
    local_accounts_created = 0
    
    # Remove nonce management - let send_transaction_and_wait handle it
    
    # Phase 1: Create and fund random accounts
    random_accounts = []
    print(f"{Colors.BLUE}[P{process_id}] 💰 Creating {config.random_accounts_per_process} accounts...{Colors.END}")
    
    for i in range(config.random_accounts_per_process):
        # Create random account
        random_account = create_random_account()
        random_accounts.append(random_account)
        
        # Fund the account
        funding_amount = Web3.to_wei(config.funding_amount_eth, 'ether')
        
        success, gas_used, error = send_transaction_safe(config, genesis_account, random_account.address, 
                                                         funding_amount, is_genesis=True)
        if success:
            local_accounts_created += 1
            local_sent += 1
            local_gas_used += gas_used
        else:
            local_failed += 1
            if "nonce" in error.lower():
                print(f"{Colors.YELLOW}[P{process_id}] ⚠️ Nonce error during funding: {error}{Colors.END}")
        
        if config.sleep_between_tx > 0:
            time.sleep(config.sleep_between_tx)
    
    print(f"{Colors.GREEN}[P{process_id}] ✅ Created and funded {len(random_accounts)} accounts{Colors.END}")
    
    # Phase 2: High-volume transactions (simplified - no threading to avoid nonce conflicts)
    start_time = time.time()
    tx_count = 0
    transfer_amount = Web3.to_wei(config.transfer_amount_eth, 'ether')
    
    all_accounts = [genesis_account] + random_accounts
    
    for i in range(config.transactions_per_process):
        # Check time limit
        if time.time() - start_time >= config.time_limit_seconds:
            print(f"{Colors.YELLOW}[P{process_id}] ⏰ Time limit reached{Colors.END}")
            break
        
        # Randomly select source and destination
        from_account = random.choice(all_accounts)
        to_account = random.choice([acc for acc in all_accounts if acc != from_account])
        
        # Send transaction with automatic nonce management
        is_genesis_account = from_account == genesis_account  # Only the genesis account for this process
        success, gas_used, error = send_transaction_safe(
            config, from_account, to_account.address, transfer_amount, is_genesis=is_genesis_account
        )
        
        if success:
            local_sent += 1
            local_gas_used += gas_used
        else:
            local_failed += 1
            if "nonce" in error.lower():  # Log ALL nonce errors in small test
                print(f"{Colors.YELLOW}[P{process_id}] ⚠️ Nonce error at tx {i}: {error}{Colors.END}")
        
        tx_count += 1
        
        # Progress reporting (throttled)
        if i % 500 == 0 and i > 0:
            elapsed = time.time() - start_time
            rate = tx_count / max(elapsed, 1)
            print(f"{Colors.YELLOW}[P{process_id}] ⚡ Progress: {i}/{config.transactions_per_process} txs, {rate:.1f} TPS{Colors.END}")
        
        # No delay for maximum throughput
        if config.sleep_between_tx > 0:
            time.sleep(config.sleep_between_tx)
    
    elapsed = time.time() - start_time
    print(f"{Colors.GREEN}[P{process_id}] 🏁 Completed: {tx_count} transactions in {elapsed:.1f}s{Colors.END}")
    
    return {
        'process_id': process_id,
        'transactions': tx_count,
        'accounts_created': local_accounts_created,
        'elapsed': elapsed,
        'sent': local_sent,
        'failed': local_failed,
        'gas_used': local_gas_used
    }



class RethStressTest:
    """Main stress test class"""
    
    def __init__(self, config: StressTestConfig):
        self.config = config
        self.web3 = Web3(Web3.HTTPProvider(config.rpc_url))
        self.setup_logging()
        
        # Convert private keys to accounts
        self.genesis_accounts = [Account.from_key(pk) for pk in config.genesis_accounts]
        
        print(f"{Colors.BLUE}🚀 Enhanced Rollup Stress Test - Python Implementation{Colors.END}")
        print(f"{Colors.BLUE}================================================{Colors.END}")
        print(f"Target: {Colors.YELLOW}{config.target_gas_per_second:,} gas/s{Colors.END} ({config.target_gas_per_second/1_000_000:.0f} MGas/s)")
        print(f"Processes: {Colors.CYAN}{config.concurrent_processes}{Colors.END}")
        print(f"Transactions per process: {Colors.CYAN}{config.transactions_per_process}{Colors.END}")
        print(f"Accounts per process: {Colors.CYAN}{config.random_accounts_per_process}{Colors.END}")
        print(f"Time limit: {Colors.CYAN}{config.time_limit_seconds}s{Colors.END}")
        print()
    
    def setup_logging(self):
        """Setup logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('stress_test.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    
    def get_account_balances(self) -> Dict[str, float]:
        """Get balances for all genesis accounts"""
        balances = {}
        for i, account in enumerate(self.genesis_accounts):
            try:
                balance_wei = self.web3.eth.get_balance(account.address)
                balance_eth = Web3.from_wei(balance_wei, 'ether')
                balances[f"Account {i}"] = float(balance_eth)
            except Exception as e:
                self.logger.warning(f"Failed to get balance for account {i}: {e}")
                balances[f"Account {i}"] = 0.0
        return balances
    
    def get_txpool_status(self) -> Dict:
        """Get transaction pool status"""
        try:
            response = requests.post(
                self.config.rpc_url,
                json={
                    "jsonrpc": "2.0",
                    "method": "txpool_status",
                    "params": [],
                    "id": 1
                },
                timeout=2
            )
            
            if response.status_code == 200 and 'result' in response.json():
                result = response.json()['result']
                return {
                    'pending': int(result.get('pending', '0x0'), 16),
                    'queued': int(result.get('queued', '0x0'), 16)
                }
            else:
                return {'pending': 0, 'queued': 0}
                
        except Exception as e:
            self.logger.warning(f"Failed to get txpool status: {e}")
            return {'pending': 0, 'queued': 0}
    
    def print_final_report(self):
        """Print comprehensive final report"""
        stats = self.final_stats
        
        print(f"\n{Colors.GREEN}🎉 STATE GROWTH STRESS TEST COMPLETED!{Colors.END}")
        print("=" * 60)
        print(f"Total Transactions Sent: {Colors.GREEN}{stats['total_sent']:,}{Colors.END}")
        print(f"Total Failed: {Colors.RED}{stats['total_failed']:,}{Colors.END}")
        print(f"Total Accounts Created: {Colors.BLUE}{stats['total_accounts_created']:,}{Colors.END}")
        print(f"Total Gas Used: {Colors.YELLOW}{stats['total_gas_used']:,} gas{Colors.END}")
        print(f"Total Time: {Colors.BLUE}{stats['elapsed_time']:.1f}s{Colors.END}")
        print()
        
        print(f"Average TPS: {Colors.YELLOW}{stats['tps']:.2f}{Colors.END}")
        print(f"Gas Throughput: {Colors.YELLOW}{stats['gas_per_second']:,.0f} gas/s{Colors.END}")
        print(f"Gas Throughput: {Colors.YELLOW}{stats['mgas_per_second']:.2f} MGas/s{Colors.END}")
        
        # Check target achievement
        if stats['mgas_per_second'] >= self.config.target_gas_per_second / 1_000_000:
            print(f"{Colors.GREEN}✅ TARGET ACHIEVED: 200+ MGas/s!{Colors.END}")
        else:
            target_mgas = self.config.target_gas_per_second / 1_000_000
            print(f"{Colors.YELLOW}⚠️ Target: {target_mgas:.0f} MGas/s (achieved: {stats['mgas_per_second']:.2f} MGas/s){Colors.END}")
        
        print(f"Success Rate: {Colors.GREEN}{stats['success_rate']:.1f}%{Colors.END}")
        print(f"State Growth: {Colors.BLUE}{stats['total_accounts_created']:,} new accounts{Colors.END} added to blockchain state")
        print()
        
        # Show balances
        print(f"{Colors.BLUE}💰 Final Account Balances:{Colors.END}")
        balances = self.get_account_balances()
        for account, balance in balances.items():
            print(f"  {account}: {balance:.4f} ETH")
        print()
        
        # Show txpool status
        txpool = self.get_txpool_status()
        print(f"{Colors.BLUE}🏊 Transaction Pool Status:{Colors.END}")
        print(f"  Pending: {txpool['pending']:,}")
        print(f"  Queued: {txpool['queued']:,}")
        print()
        
        print(f"{Colors.BLUE}💡 Monitor your enhanced Reth metrics at: http://localhost:9001{Colors.END}")
        print(f"{Colors.BLUE}💡 Monitor Rollkit metrics at: http://localhost:26660{Colors.END}")
    
    def run(self):
        """Run the complete stress test"""
        # Validate that we have enough genesis accounts
        if self.config.concurrent_processes > len(self.genesis_accounts):
            print(f"{Colors.RED}❌ Error: {self.config.concurrent_processes} processes requested but only {len(self.genesis_accounts)} genesis accounts available{Colors.END}")
            print(f"{Colors.YELLOW}💡 Reducing concurrent processes to {len(self.genesis_accounts)}{Colors.END}")
            self.config.concurrent_processes = len(self.genesis_accounts)
        
        print(f"{Colors.CYAN}🔥 Starting {self.config.concurrent_processes} concurrent processes...{Colors.END}")
        print()
        
        # Collect results from all processes
        all_results = []
        start_time = time.time()
        
        # Run concurrent stress test processes
        with ProcessPoolExecutor(max_workers=self.config.concurrent_processes) as executor:
            futures = [
                executor.submit(stress_test_process, i, self.config, self.genesis_accounts) 
                for i in range(self.config.concurrent_processes)
            ]
            
            # Wait for completion and collect results
            for future in as_completed(futures):
                try:
                    result = future.result()
                    all_results.append(result)
                    self.logger.info(f"Process {result['process_id']} completed")
                except Exception as e:
                    self.logger.error(f"Process failed: {e}")
        
        # Aggregate results from all processes
        total_sent = sum(r['sent'] for r in all_results)
        total_failed = sum(r['failed'] for r in all_results)
        total_gas_used = sum(r['gas_used'] for r in all_results)
        total_accounts_created = sum(r['accounts_created'] for r in all_results)
        total_time = time.time() - start_time
        
        # Create final stats
        self.final_stats = {
            'total_sent': total_sent,
            'total_failed': total_failed,
            'total_gas_used': total_gas_used,
            'total_accounts_created': total_accounts_created,
            'elapsed_time': total_time,
            'tps': total_sent / max(total_time, 1),
            'gas_per_second': total_gas_used / max(total_time, 1),
            'mgas_per_second': total_gas_used / max(total_time, 1) / 1_000_000,
            'success_rate': total_sent * 100 / max(total_sent + total_failed, 1)
        }
        
        # Print final comprehensive report
        self.print_final_report()

def main():
    """Main entry point"""
    # Create configuration
    config = StressTestConfig()
    
    # Create and run stress test
    stress_test = RethStressTest(config)
    
    try:
        stress_test.run()
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}🛑 Stress test interrupted{Colors.END}")
    except Exception as e:
        print(f"\n{Colors.RED}❌ Stress test failed: {e}{Colors.END}")
        raise

if __name__ == "__main__":
    main()
