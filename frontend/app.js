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

// Contract address - will be loaded dynamically
let CONTRACT_ADDRESS = "";

class ROSCAApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.contract = null;
        this.userAddress = null;

        this.init();
    }

    async init() {
        await this.loadContractAddress();
        this.setupEventListeners();
        await this.checkWalletConnection();
    }

    async loadContractAddress() {
        try {
            const response = await fetch('.rosca-address');
            if (response.ok) {
                const address = await response.text();
                CONTRACT_ADDRESS = address.trim();
                console.log('Contract address loaded:', CONTRACT_ADDRESS);

                // Update UI to show loaded address
                const balanceDiv = document.getElementById('contractBalance');
                if (balanceDiv) {
                    const addrSpan = document.createElement('div');
                    addrSpan.style.fontSize = '0.8em';
                    addrSpan.style.color = '#7f8c8d';
                    addrSpan.style.marginTop = '2px';
                    addrSpan.textContent = `Address: ${CONTRACT_ADDRESS.slice(0, 6)}...${CONTRACT_ADDRESS.slice(-4)}`;
                    balanceDiv.appendChild(addrSpan);
                }
            } else {
                console.error('Failed to load contract address file');
                this.showMessage('Could not load contract address. System might be initializing.', 'warning');
            }
        } catch (error) {
            console.error('Error loading contract address:', error);
            this.showMessage('Error loading contract address', 'error');
        }
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

        // Integration Tests
        document.getElementById('runTestsBtn').addEventListener('click', () => {
            this.runIntegrationTests();
        });

        document.getElementById('refreshTestsBtn').addEventListener('click', () => {
            this.loadTestResults();
        });

        // Celestia Monitoring
        document.getElementById('refreshCelestiaBtn').addEventListener('click', () => {
            this.loadCelestiaData();
        });

        // Auto-load test results and Celestia data on init
        this.loadTestResults();
        this.loadCelestiaData();
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
            this.showMessage(`Payout winners: ${winners.map(w => w.slice(0, 8) + '...').join(', ')}`, 'info');
        } catch (e) {
            console.error('Failed fetching payout history', e);
            this.showMessage('Failed to fetch payout history', 'error');
        }
    }

    // Integration Tests Methods
    async runIntegrationTests() {
        const resultsDiv = document.getElementById('testResults');
        resultsDiv.innerHTML = '<div class="loading"></div><p>Running integration tests... This may take a few minutes.</p>';

        try {
            const response = await fetch('/run_tests', {
                method: 'POST'
            });

            if (response.ok) {
                this.showMessage('Integration tests started! Results will appear shortly.', 'success');
                // Wait a bit then load results
                setTimeout(() => this.loadTestResults(), 5000);
            } else {
                this.showMessage('Failed to start integration tests', 'error');
                resultsDiv.innerHTML = '<div class="error">Failed to start tests. Make sure the backend is running.</div>';
            }
        } catch (error) {
            console.error('Error running tests:', error);
            this.showMessage('Error: ' + error.message, 'error');
            resultsDiv.innerHTML = '<div class="error">Error running tests. Check console for details.</div>';
        }
    }

    async loadTestResults() {
        const resultsDiv = document.getElementById('testResults');

        try {
            const response = await fetch('/rosca_test_results.json');

            if (!response.ok) {
                resultsDiv.innerHTML = '<p>No test results available yet. Click "Run Integration Tests" to execute tests.</p>';
                return;
            }

            const data = await response.json();
            this.renderTestResults(data);

        } catch (error) {
            console.error('Error loading test results:', error);
            resultsDiv.innerHTML = '<p>No test results found. Run integration tests first.</p>';
        }
    }

    renderTestResults(data) {
        const resultsDiv = document.getElementById('testResults');

        let html = '<div class="test-summary">';

        // Summary stats
        if (data.summary) {
            html += `
                <div class="test-stat">
                    <div class="number">${data.summary.total_tests || 0}</div>
                    <div class="label">Total Tests</div>
                </div>
                <div class="test-stat">
                    <div class="number" style="color: #27ae60;">${data.summary.passed_tests || 0}</div>
                    <div class="label">Passed</div>
                </div>
                <div class="test-stat">
                    <div class="number" style="color: #e74c3c;">${data.summary.failed_tests || 0}</div>
                    <div class="label">Failed</div>
                </div>
                <div class="test-stat">
                    <div class="number">${data.initial_block || 0}</div>
                    <div class="label">Initial Block</div>
                </div>
            `;
        }

        html += '</div>';

        // Deployment Information
        if (data.deployment && data.deployment.status === 'success') {
            html += `
                <div class="deployment-info">
                    <h4>📝 Contract Deployment</h4>
                    <div class="tx-detail">
                        <span class="label">Contract Address:</span>
                        <span class="value">${data.deployment.contract_address}</span>
                    </div>
                    <div class="tx-detail">
                        <span class="label">Transaction Hash:</span>
                        <span class="value">
                            <a href="#" class="tx-link" title="${data.deployment.transaction_hash}">
                                ${data.deployment.transaction_hash.slice(0, 20)}...
                            </a>
                        </span>
                    </div>
                    <div class="tx-detail">
                        <span class="label">Block Number:</span>
                        <span class="value">${data.deployment.block_number}</span>
                    </div>
                    <div class="tx-detail">
                        <span class="label">Gas Used:</span>
                        <span class="value">${data.deployment.gas_used.toLocaleString()}</span>
                    </div>
                    <div class="tx-detail">
                        <span class="label">Deployer:</span>
                        <span class="value">${data.deployment.deployer}</span>
                    </div>
                </div>
            `;
        }

        // RPC Endpoints Test Results
        if (data.rpc_endpoints) {
            html += '<div class="card"><h4>🔌 JSON-RPC Endpoints</h4>';
            data.rpc_endpoints.forEach(endpoint => {
                const status = endpoint.success ? '✅' : '❌';
                html += `
                    <div class="tx-detail">
                        <span class="label">${status} ${endpoint.method}</span>
                        <span class="value">${endpoint.result || 'Failed'}</span>
                    </div>
                `;
            });
            html += '</div>';
        }

        // Celestia Info
        if (data.celestia) {
            html += `
                <div class="card">
                    <h4>🌌 Celestia DA Layer</h4>
                    <div class="tx-detail">
                        <span class="label">Wallet Balance:</span>
                        <span class="value">${(data.celestia.balance || 0).toLocaleString()} utia</span>
                    </div>
                    <div class="tx-detail">
                        <span class="label">Wallet Address:</span>
                        <span class="value">
                            <a href="https://mocha.celenium.io/address/${data.celestia.address}" 
                               target="_blank" class="tx-link">
                                ${data.celestia.address}
                            </a>
                        </span>
                    </div>
            `;

            if (data.celestia.recent_submissions) {
                html += `
                    <div class="tx-detail">
                        <span class="label">Recent Successful Submissions:</span>
                        <span class="value">${data.celestia.recent_submissions.successful}</span>
                    </div>
                    <div class="tx-detail">
                        <span class="label">Recent Failed Submissions:</span>
                        <span class="value">${data.celestia.recent_submissions.failed}</span>
                    </div>
                `;
            }

            html += '</div>';
        }

        // Timestamp
        if (data.timestamp) {
            html += `<p style="text-align: center; color: #7f8c8d; margin-top: 20px;">
                Last updated: ${new Date(data.timestamp).toLocaleString()}
            </p>`;
        }

        resultsDiv.innerHTML = html;
    }

    async loadCelestiaData() {
        const monitorDiv = document.getElementById('celestiaMonitor');
        monitorDiv.innerHTML = '<div class="loading"></div><p>Loading Celestia data...</p>';

        try {
            // Load wallet status
            const walletResponse = await fetch('/celestia_wallet_status.json');
            const daResponse = await fetch('/da_consumption_analysis.json');

            let html = '';

            // Wallet Information
            if (walletResponse.ok) {
                const walletData = await walletResponse.json();

                html += `
                    <div class="celestia-wallet">
                        <h4>💰 Wallet Status</h4>
                        <div>Address: <a href="https://mocha.celenium.io/address/${walletData.wallet.address}" 
                                         target="_blank" style="color: white; text-decoration: underline;">
                            ${walletData.wallet.address}
                        </a></div>
                        <div class="balance-display">${(walletData.wallet.balance || 0).toLocaleString()} ${walletData.wallet.denom || 'utia'}</div>
                        <div>Estimated Capacity: ~${walletData.wallet.estimated_capacity} blob submissions</div>
                        <div style="margin-top: 10px; font-size: 0.9em;">Updated: ${new Date(walletData.timestamp).toLocaleString()}</div>
                    </div>
                `;

                // Alerts
                if (walletData.alerts && walletData.alerts.length > 0) {
                    walletData.alerts.forEach(alert => {
                        const alertClass = alert.includes('CRITICAL') ? 'alert-critical' : 'alert-warning';
                        html += `<div class="alert-box ${alertClass}">${alert}</div>`;
                    });
                } else {
                    html += '<div class="alert-box alert-success">✅ Wallet balance is sufficient</div>';
                }

                // Activity Stats
                if (walletData.activity) {
                    html += `
                        <div class="da-stats">
                            <div class="da-stat-card">
                                <div class="stat-label">Successful Submissions</div>
                                <div class="stat-value">${walletData.activity.successful_submissions}</div>
                            </div>
                            <div class="da-stat-card">
                                <div class="stat-label">Failed Submissions</div>
                                <div class="stat-value" style="color: #e74c3c;">${walletData.activity.failed_submissions}</div>
                            </div>
                            <div class="da-stat-card">
                                <div class="stat-label">Total Attempts</div>
                                <div class="stat-value">${walletData.activity.total_attempts}</div>
                            </div>
                        </div>
                    `;
                }
            }

            // DA Consumption Analysis
            if (daResponse.ok) {
                const daData = await daResponse.json();

                html += '<div class="card"><h4>📊 DA Consumption Analysis</h4>';

                if (daData.statistics) {
                    html += `
                        <div class="da-stats">
                            <div class="da-stat-card">
                                <div class="stat-label">Success Rate</div>
                                <div class="stat-value">${daData.statistics.success_rate.toFixed(1)}%</div>
                            </div>
                            <div class="da-stat-card">
                                <div class="stat-label">Avg Cost per Blob</div>
                                <div class="stat-value">${Math.round(daData.statistics.avg_cost_per_blob).toLocaleString()}</div>
                                <div class="stat-label">utia</div>
                            </div>
                            <div class="da-stat-card">
                                <div class="stat-label">Total Cost Attempted</div>
                                <div class="stat-value">${Math.round(daData.statistics.total_cost_attempted).toLocaleString()}</div>
                                <div class="stat-label">utia</div>
                            </div>
                        </div>
                    `;
                }

                // Recommendations
                if (daData.recommendations && daData.recommendations.length > 0) {
                    html += '<h4 style="margin-top: 20px;">💡 Recommendations</h4><ul>';
                    daData.recommendations.forEach(rec => {
                        html += `<li>${rec}</li>`;
                    });
                    html += '</ul>';
                }

                html += `<p style="text-align: center; color: #7f8c8d; margin-top: 20px;">
                    Last analyzed: ${new Date(daData.timestamp).toLocaleString()}
                </p>`;

                html += '</div>';
            }

            if (!html) {
                html = '<p>No Celestia monitoring data available. Run monitoring scripts first.</p>';
            }

            monitorDiv.innerHTML = html;

        } catch (error) {
            console.error('Error loading Celestia data:', error);
            monitorDiv.innerHTML = '<div class="error">Error loading Celestia data. Make sure monitoring scripts have been run.</div>';
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