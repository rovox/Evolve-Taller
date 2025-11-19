// ROSCA Contract ABI (simplified for demo)
const ROSCA_ABI = [
    "function createGroup(string memory _name, uint256 _monthlyAmount, uint256 _duration) external returns (uint256)",
    "function joinGroup(uint256 groupId) external payable",
    "function contribute(uint256 groupId) external payable",
    "function getGroupInfo(uint256 groupId) external view returns (string memory name, uint256 monthlyAmount, uint256 duration, uint256 startTime, uint256 memberCount, uint256 currentMonth, bool isActive, uint256 totalContributions)",
    "function getGroupMembers(uint256 groupId) external view returns (address[] memory)",
    "function getMemberContribution(uint256 groupId, address member) external view returns (uint256)",
    "function getMonthlyWinner(uint256 groupId, uint256 month) external view returns (address)",
    "function hasReceivedPayout(uint256 groupId, address member) external view returns (bool)",
    "function getCurrentMonth(uint256 groupId) public view returns (uint256)",
    "function groupCounter() public view returns (uint256)",
    "function getContractBalance() external view returns (uint256)",
    "function getPayoutWinners(uint256 groupId) external view returns (address[] memory)",
    "function getEligibleMembers(uint256 groupId) external view returns (address[] memory)",
    "event GroupCreated(uint256 indexed groupId, string name, uint256 monthlyAmount, uint256 duration, address creator)",
    "event MemberJoined(uint256 indexed groupId, address indexed member)",
    "event ContributionMade(uint256 indexed groupId, address indexed member, uint256 amount, uint256 month)",
    "event PayoutDistributed(uint256 indexed groupId, address indexed winner, uint256 amount, uint256 month)"
];

// Contract address - update to the deployed contract address from your local deploy
const CONTRACT_ADDRESS = "0x5fbdb2315678afecb367f032d93f642f64180aa3"; // deployed via DeployROSCA.s.sol

class ROSCAApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.contract = null;
        this.userAddress = null;
        
        this.init();
    }
    
    async init() {
        this.setupEventListeners();
        await this.checkWalletConnection();
    }
    
    setupEventListeners() {
        // Tab switching
        document.querySelectorAll('.tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                this.switchTab(e.target.dataset.tab);
            });
        });
        
        // Wallet connection
        document.getElementById('connectBtn').addEventListener('click', () => {
            this.connectWallet();
        });
        // Disconnect button (cleans dApp state)
        const disconnectBtn = document.getElementById('disconnectBtn');
        if (disconnectBtn) {
            disconnectBtn.addEventListener('click', () => {
                this.disconnectWallet();
            });
        }
        
        // Forms
        document.getElementById('createGroupForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.createGroup();
        });
        
        document.getElementById('joinGroupForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.joinGroup();
        });
        
        document.getElementById('contributeForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.contribute();
        });
        
        // Group preview
        document.getElementById('joinGroupId').addEventListener('input', (e) => {
            this.previewGroup(e.target.value);
        });
        
        // Refresh groups
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.loadUserGroups();
        });
    }
    
    switchTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.tab').forEach(tab => {
            tab.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
        
        // Update tab content
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(tabName).classList.add('active');
        
        // Load data for specific tabs
        if (tabName === 'view') {
            this.loadUserGroups();
        }
    }
    
    async checkWalletConnection() {
        if (typeof window.ethereum !== 'undefined') {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                if (accounts.length > 0) {
                    await this.connectWallet();
                }
            } catch (error) {
                console.error('Error checking wallet connection:', error);
            }
        }
    }
    
    async connectWallet() {
        try {
            if (typeof window.ethereum === 'undefined') {
                this.showMessage('Please install MetaMask!', 'error');
                return;
            }
            
            // Request account access
            const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            
            // Set up provider and signer
            this.provider = new ethers.providers.Web3Provider(window.ethereum);
            this.signer = this.provider.getSigner();
            this.userAddress = accounts[0];
            
            // Initialize contract
            this.contract = new ethers.Contract(CONTRACT_ADDRESS, ROSCA_ABI, this.signer);
            
            // Update UI
            this.updateConnectionStatus(true);
            this.showMessage('Wallet connected successfully!', 'success');
            
            // Set up event listeners for contract events
            this.setupContractEventListeners();
            // Update contract balance display
            this.updateContractBalance();
            // Show disconnect button and hide connect button
            const disconnectBtn = document.getElementById('disconnectBtn');
            if (disconnectBtn) disconnectBtn.style.display = 'inline-block';
            const connectBtn = document.getElementById('connectBtn');
            if (connectBtn) connectBtn.style.display = 'none';
            
        } catch (error) {
            console.error('Error connecting wallet:', error);
            this.showMessage('Failed to connect wallet: ' + error.message, 'error');
        }
    }

    disconnectWallet() {
        // Clear dApp state — user must remove connected site in MetaMask to fully revoke
        this.provider = null;
        this.signer = null;
        this.contract = null;
        this.userAddress = null;
        localStorage.removeItem('rosca_connected');
        this.updateConnectionStatus(false);
        const disconnectBtn = document.getElementById('disconnectBtn');
        if (disconnectBtn) disconnectBtn.style.display = 'none';
        const connectBtn = document.getElementById('connectBtn');
        if (connectBtn) connectBtn.style.display = 'inline-block';
        this.showMessage('Disconnected (dApp state cleared). To fully disconnect remove site from MetaMask.', 'info');
    }
    
    setupContractEventListeners() {
        if (!this.contract) return;
        
        // Listen for group creation
        this.contract.on('GroupCreated', (groupId, name, monthlyAmount, duration, creator) => {
            if (creator.toLowerCase() === this.userAddress.toLowerCase()) {
                this.showMessage(`Group "${name}" created successfully! Group ID: ${groupId}`, 'success');
            }
        });
        
        // Listen for member joins
        this.contract.on('MemberJoined', (groupId, member) => {
            if (member.toLowerCase() === this.userAddress.toLowerCase()) {
                this.showMessage(`Successfully joined group ${groupId}!`, 'success');
            }
        });
        
        // Listen for contributions
        this.contract.on('ContributionMade', (groupId, member, amount, month) => {
            if (member.toLowerCase() === this.userAddress.toLowerCase()) {
                const ethAmount = ethers.utils.formatEther(amount);
                this.showMessage(`Contribution of ${ethAmount} ETH made to group ${groupId}!`, 'success');
            }
        });
        
        // Listen for payouts
        this.contract.on('PayoutDistributed', (groupId, winner, amount, month) => {
            const ethAmount = ethers.utils.formatEther(amount);
            if (winner.toLowerCase() === this.userAddress.toLowerCase()) {
                this.showMessage(`Congratulations! You won ${ethAmount} ETH from group ${groupId}!`, 'success');
            } else {
                this.showMessage(`Payout of ${ethAmount} ETH distributed to ${winner.slice(0, 8)}... in group ${groupId}`, 'success');
            }
            // Update UI state
            this.updateContractBalance();
            this.loadUserGroups();
        });
    }
    
    updateConnectionStatus(connected) {
        const statusDiv = document.getElementById('connectionStatus');
        const statusText = document.getElementById('statusText');
        const connectBtn = document.getElementById('connectBtn');
        
        if (connected) {
            statusDiv.className = 'connection-status connected';
            statusText.textContent = `Connected: ${this.userAddress.slice(0, 8)}...${this.userAddress.slice(-6)}`;
            connectBtn.style.display = 'none';
        } else {
            statusDiv.className = 'connection-status disconnected';
            statusText.textContent = 'No wallet connected';
            connectBtn.style.display = 'inline-block';
        }
    }

    async updateContractBalance() {
        try {
            if (!this.provider) return;
            const bal = await this.provider.getBalance(CONTRACT_ADDRESS);
            const node = document.getElementById('balanceValue');
            if (node) node.textContent = ethers.utils.formatEther(bal) + ' ETH';
        } catch (e) {
            console.error('Failed to update contract balance', e);
        }
    }
    
    async createGroup() {
        if (!this.contract) {
            this.showMessage('Please connect your wallet first', 'error');
            return;
        }
        
        try {
            const name = document.getElementById('groupName').value;
            const monthlyAmount = document.getElementById('monthlyAmount').value;
            const duration = document.getElementById('duration').value;
            
            if (!name || !monthlyAmount || !duration) {
                this.showMessage('Please fill in all fields', 'error');
                return;
            }
            
            const monthlyAmountWei = ethers.utils.parseEther(monthlyAmount);
            
            this.showMessage('Creating group...', 'info');
            
            const tx = await this.contract.createGroup(name, monthlyAmountWei, parseInt(duration));
            await tx.wait();
            
            // Clear form
            document.getElementById('createGroupForm').reset();
            
        } catch (error) {
            console.error('Error creating group:', error);
            this.showMessage('Failed to create group: ' + error.message, 'error');
        }
    }
    
    async joinGroup() {
        if (!this.contract) {
            this.showMessage('Please connect your wallet first', 'error');
            return;
        }
        
        try {
            const groupId = document.getElementById('joinGroupId').value;
            
            if (!groupId) {
                this.showMessage('Please enter a group ID', 'error');
                return;
            }
            
            this.showMessage('Joining group...', 'info');
            
            const tx = await this.contract.joinGroup(parseInt(groupId));
            await tx.wait();
            
            // Clear form
            document.getElementById('joinGroupForm').reset();
            document.getElementById('groupPreview').style.display = 'none';
            
        } catch (error) {
            console.error('Error joining group:', error);
            this.showMessage('Failed to join group: ' + error.message, 'error');
        }
    }
    
    async contribute() {
        if (!this.contract) {
            this.showMessage('Please connect your wallet first', 'error');
            return;
        }
        
        try {
            const groupId = document.getElementById('contributeGroupId').value;
            
            if (!groupId) {
                this.showMessage('Please enter a group ID', 'error');
                return;
            }
            
            // Get group info to determine contribution amount
            const groupInfo = await this.contract.getGroupInfo(parseInt(groupId));
            const monthlyAmount = groupInfo[1]; // monthlyAmount is at index 1
            
            this.showMessage('Making contribution...', 'info');
            
            const tx = await this.contract.contribute(parseInt(groupId), { value: monthlyAmount });
            await tx.wait();
            
            // Clear form
            document.getElementById('contributeForm').reset();
            
        } catch (error) {
            console.error('Error making contribution:', error);
            this.showMessage('Failed to make contribution: ' + error.message, 'error');
        }
    }
    
    async previewGroup(groupId) {
        if (!this.contract || !groupId) {
            document.getElementById('groupPreview').style.display = 'none';
            return;
        }
        
        try {
            const groupInfo = await this.contract.getGroupInfo(parseInt(groupId));
            
            document.getElementById('previewName').textContent = groupInfo[0];
            document.getElementById('previewAmount').textContent = ethers.utils.formatEther(groupInfo[1]);
            document.getElementById('previewDuration').textContent = groupInfo[2].toString();
            document.getElementById('previewMembers').textContent = groupInfo[4].toString();
            
            document.getElementById('groupPreview').style.display = 'block';
            
        } catch (error) {
            document.getElementById('groupPreview').style.display = 'none';
        }
    }
    
    async loadUserGroups() {
        if (!this.contract) {
            this.showMessage('Please connect your wallet first', 'error');
            return;
        }
        
        try {
            const groupsList = document.getElementById('groupsList');
            groupsList.innerHTML = '<div class="loading"></div>';
            
            const groupCounter = await this.contract.groupCounter();
            const userGroups = [];
            
            // Check each group to see if user is a member
            for (let i = 0; i < groupCounter; i++) {
                try {
                    const members = await this.contract.getGroupMembers(i);
                    const isMember = members.some(member => 
                        member.toLowerCase() === this.userAddress.toLowerCase()
                    );
                    
                    if (isMember) {
                        const groupInfo = await this.contract.getGroupInfo(i);
                        const contribution = await this.contract.getMemberContribution(i, this.userAddress);
                        const hasReceived = await this.contract.hasReceivedPayout(i, this.userAddress);
                        
                        userGroups.push({
                            id: i,
                            name: groupInfo[0],
                            monthlyAmount: groupInfo[1],
                            duration: groupInfo[2],
                            memberCount: groupInfo[4],
                            currentMonth: groupInfo[5],
                            isActive: groupInfo[6],
                            contribution: contribution,
                            hasReceived: hasReceived,
                            members: members
                        });
                    }
                } catch (error) {
                    console.error(`Error loading group ${i}:`, error);
                }
            }
            
            this.renderUserGroups(userGroups);
            
        } catch (error) {
            console.error('Error loading user groups:', error);
            this.showMessage('Failed to load groups: ' + error.message, 'error');
        }
    }
    
    renderUserGroups(groups) {
        const groupsList = document.getElementById('groupsList');
        
        if (groups.length === 0) {
            groupsList.innerHTML = '<p>You are not a member of any groups yet.</p>';
            return;
        }
        
        const groupsHtml = groups.map(group => `
            <div class="card">
                <h4>${group.name} (ID: ${group.id})</h4>
                <div class="info-grid">
                    <div class="info-item">
                        <strong>Monthly Amount:</strong> ${ethers.utils.formatEther(group.monthlyAmount)} ETH
                    </div>
                    <div class="info-item">
                        <strong>Duration:</strong> ${group.duration} months
                    </div>
                    <div class="info-item">
                        <strong>Members:</strong> ${group.memberCount}/${group.duration}
                    </div>
                    <div class="info-item">
                        <strong>Current Month:</strong> ${group.currentMonth}
                    </div>
                    <div class="info-item">
                        <strong>Status:</strong> ${group.isActive ? 'Active' : 'Completed'}
                    </div>
                    <div class="info-item">
                        <strong>Your Contribution:</strong> ${ethers.utils.formatEther(group.contribution)} ETH
                    </div>
                </div>
                
                <div class="members-list">
                    <strong>Members:</strong>
                    <div style="display:flex; gap:10px; margin-top:10px; flex-wrap:wrap;">
                    ${group.members.map(member => `
                        <div class="member-item" style="display:flex; align-items:center; gap:8px;">
                            <div class="avatar" data-address="${member}"></div>
                            <span>${member.slice(0, 8)}...${member.slice(-6)}</span>
                            <span class="status-badge ${member.toLowerCase() === this.userAddress.toLowerCase() ? 'status-paid' : 'status-pending'}" style="margin-left:8px;">
                                ${member.toLowerCase() === this.userAddress.toLowerCase() ? 'You' : 'Member'}
                            </span>
                        </div>
                    `).join('')}
                    </div>
                </div>
                
                ${group.isActive ? `
                    <button class="btn" onclick="app.quickContribute(${group.id})">
                        Contribute ${ethers.utils.formatEther(group.monthlyAmount)} ETH
                    </button>
                ` : ''}
            </div>
        `).join('');
        
        groupsList.innerHTML = groupsHtml;

        // Attach jazzicon avatars after rendering
        document.querySelectorAll('.avatar').forEach(node => {
            const addr = node.getAttribute('data-address');
            try {
                const seed = parseInt(addr.slice(2, 10), 16);
                const icon = jazzicon(32, seed);
                node.innerHTML = '';
                node.appendChild(icon);
            } catch (e) {
                // ignore
            }
        });
    }
    
    async quickContribute(groupId) {
        if (!this.contract) {
            this.showMessage('Please connect your wallet first', 'error');
            return;
        }
        
        try {
            const groupInfo = await this.contract.getGroupInfo(groupId);
            const monthlyAmount = groupInfo[1];
            
            this.showMessage('Making contribution...', 'info');
            
            const tx = await this.contract.contribute(groupId, { value: monthlyAmount });
            await tx.wait();
            
            // Refresh the groups list
            setTimeout(() => this.loadUserGroups(), 2000);
            
        } catch (error) {
            console.error('Error making contribution:', error);
            this.showMessage('Failed to make contribution: ' + error.message, 'error');
        }
    }
    
    async showPayoutHistory(groupId) {
        if (!this.contract) return;
        try {
            const winners = await this.contract.getPayoutWinners(groupId);
            this.showMessage(`Payout winners: ${winners.map(w => w.slice(0,8)+'...').join(', ')}`, 'info');
        } catch (e) {
            console.error('Failed fetching payout history', e);
            this.showMessage('Failed to fetch payout history', 'error');
        }
    }
    
    showMessage(message, type = 'info') {
        const messagesDiv = document.getElementById('messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = type;
        messageDiv.textContent = message;
        
        messagesDiv.appendChild(messageDiv);
        
        // Remove message after 5 seconds
        setTimeout(() => {
            if (messageDiv.parentNode) {
                messageDiv.parentNode.removeChild(messageDiv);
            }
        }, 5000);
    }
}

// Initialize the app
const app = new ROSCAApp();