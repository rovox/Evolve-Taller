# ROSCA Implementation - Pasanaku Digital

## Overview

This implementation provides a complete ROSCA (Rotating Savings and Credit Association) system, also known as "Pasanaku" in Bolivian culture. The system consists of smart contracts built with Foundry and a simple web frontend for demonstration.

## Architecture

### Smart Contract (`contracts/src/ROSCA.sol`)

The main contract implements:

**Core Data Structures:**
- `Group`: Contains all group information including members, contributions, and payout history
- `Contribution`: Tracks individual member contributions
- `Payout`: Records payout distributions

**Key Functions:**
- `createGroup()`: Creates a new ROSCA group
- `joinGroup()`: Allows users to join existing groups
- `contribute()`: Members make monthly contributions
- `distributePayout()`: Automatically distributes payouts when all members contribute
- Various view functions for querying group and member data

**Events:**
- `GroupCreated`: Emitted when a new group is created
- `MemberJoined`: Emitted when someone joins a group
- `ContributionMade`: Emitted for each contribution
- `PayoutDistributed`: Emitted when payouts are made

### Frontend (`frontend/`)

Simple web interface using:
- HTML/CSS for the UI
- Vanilla JavaScript with ethers.js for blockchain interaction
- MetaMask integration for wallet connectivity

## File Structure

```
/home/robvox/evolve-deployment/
├── contracts/
│   ├── src/
│   │   └── ROSCA.sol                 # Main contract
│   ├── test/
│   │   └── ROSCA.t.sol              # Comprehensive tests
│   ├── script/
│   │   ├── DeployROSCA.s.sol        # Deployment script
│   │   └── DemoROSCA.s.sol          # Demo/testing script
│   └── foundry.toml                 # Foundry configuration
├── frontend/
│   ├── index.html                   # Main UI
│   ├── app.js                       # JavaScript application
│   └── README.md                    # Frontend documentation
└── ROSCA_IMPLEMENTATION.md          # This file
```

## Key Features Implemented

### 1. Group Management
- Create groups with custom parameters (name, monthly amount, duration)
- Join existing groups (limited to duration number of members)
- View group information and member lists

### 2. Contribution System
- Monthly contribution enforcement
- Automatic payout distribution when all members contribute
- Contribution tracking per member

### 3. Payout Distribution
- Pseudo-random winner selection from eligible members
- Ensures each member receives exactly one payout
- Transparent payout history

### 4. Frontend Integration
- Wallet connection via MetaMask
- Real-time event listening for contract interactions
- Intuitive tabbed interface for different operations
- Group preview functionality

## Testing

The implementation includes comprehensive tests covering:
- Group creation and validation
- Member joining restrictions
- Contribution logic and validations
- Payout distribution mechanics
- Event emissions
- Multi-group scenarios
- Time-based functionality

Run tests with:
```bash
cd contracts
forge test --match-contract ROSCATest -v
```

## Deployment

### Local Development (Anvil)

1. Start Anvil:
```bash
anvil
```

2. Deploy contract:
```bash
cd contracts
forge script script/DeployROSCA.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

3. Run demo:
```bash
forge script script/DemoROSCA.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Production Deployment

For production networks, update the deployment script with appropriate RPC URLs and private keys.

## Usage Examples

### Creating a Group
```solidity
uint256 groupId = rosca.createGroup("Monthly Savings", 0.1 ether, 6);
```

### Joining a Group
```solidity
rosca.joinGroup(groupId);
```

### Making Contributions
```solidity
rosca.contribute{value: monthlyAmount}(groupId);
```

## Demo Scenarios

### Scenario 1: Basic 3-Member Group
1. Alice creates a group: 3 months, 0.1 ETH monthly
2. Bob and Charlie join
3. All contribute for month 1 → automatic payout to winner
4. Continue for months 2 and 3

### Scenario 2: Multiple Groups
1. Different members create multiple groups
2. Users can be members of multiple groups simultaneously
3. Independent contribution cycles for each group

## Security Considerations

### Implemented
- Input validation on all functions
- Member-only access controls
- Contribution amount verification
- Group existence checks
- Reentrancy protection through careful state management

### Future Enhancements
- Oracle integration for improved randomness
- Multi-signature group management
- Emergency pause functionality
- Upgradeable contract patterns

## Integration with Existing Infrastructure

The ROSCA implementation is designed to integrate with your existing evolve-deployment infrastructure:

1. **Docker Integration**: Can be containerized alongside existing services
2. **Event Indexing**: Events can be indexed by your eth-indexer for analytics
3. **Frontend Integration**: Can be embedded in existing web applications
4. **API Integration**: Contract functions can be called via web3 APIs

## Next Steps

1. **Deploy to Local Network**: Use the deployment scripts with your local EVM node
2. **Frontend Testing**: Update contract address in frontend and test wallet interactions
3. **Event Indexing**: Configure your indexer to track ROSCA events
4. **UI Enhancement**: Extend the frontend with additional features as needed
5. **Production Deployment**: Deploy to your target network once testing is complete

## Technical Notes

- Uses Solidity ^0.8.13 for modern features and gas optimizations
- Follows OpenZeppelin patterns for security
- Implements efficient gas usage patterns
- Designed for scalability with multiple concurrent groups
- Event-driven architecture for easy integration with indexers

## Support

The implementation is fully functional and tested. All core ROSCA functionality is working including group creation, member management, contributions, and automatic payouts. The frontend provides a complete user interface for all operations.