# ROSCA Demo Frontend

A simple web interface for interacting with the ROSCA (Rotating Savings and Credit Association) smart contract.

## Features

- **Create Group**: Start a new ROSCA group with custom parameters
- **Join Group**: Join an existing ROSCA group by ID
- **Contribute**: Make monthly contributions to your groups
- **View Groups**: See all groups you're a member of and their status

## Setup

1. **Deploy the Contract**: First deploy the ROSCA contract using Foundry
   ```bash
   cd ../contracts
   forge script script/DeployROSCA.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```

2. **Update Contract Address**: Copy the deployed contract address and update `CONTRACT_ADDRESS` in `app.js`

3. **Start Local Server**: Serve the frontend files (you can use any web server)
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Using Node.js
   npx serve .
   
   # Or simply open index.html in your browser
   ```

4. **Connect Wallet**: 
   - Install MetaMask
   - Connect to your local network (http://localhost:8545)
   - Import one of the test accounts from Anvil

## Test Accounts (Anvil Default)

If using Anvil for local testing, you can import these accounts:

- Account 0: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- Account 1: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`
- Account 2: `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a`

## Usage Flow

1. **Connect Wallet**: Click "Connect Wallet" to connect MetaMask
2. **Create a Group**: 
   - Go to "Create Group" tab
   - Fill in group name, monthly amount (in ETH), and duration
   - Click "Create Group" and confirm transaction
3. **Join Groups**: 
   - Go to "Join Group" tab
   - Enter a group ID to preview and join
4. **Make Contributions**:
   - Go to "Contribute" tab and enter group ID
   - Or use the quick contribute button in "View Groups"
5. **Monitor Groups**: Use "View Groups" to see all your group memberships and status

## Smart Contract Events

The frontend listens for the following events:
- `GroupCreated`: When a new group is created
- `MemberJoined`: When someone joins a group
- `ContributionMade`: When a contribution is made
- `PayoutDistributed`: When a payout is distributed to a winner

## Demo Scenario

For a complete demo:
1. Create a group with 3-month duration and 0.1 ETH monthly amount
2. Have 3 different accounts join the group
3. All members contribute for the first month
4. Observe the automatic payout to a randomly selected member
5. Continue contributions for subsequent months

## Network Configuration

Default configuration is for local development:
- RPC URL: http://localhost:8545
- Chain ID: 31337 (Anvil default)

For other networks, update the MetaMask network settings accordingly.