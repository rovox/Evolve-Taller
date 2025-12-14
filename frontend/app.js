// ROSCA Contract ABI (simplified for demo)
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

// Contract address - will be auto-loaded from deployment_info.json
let CONTRACT_ADDRESS = "0x3eb22e0fd63cec1cc01652ca26e8f471347e8f5d"; // fallback
let DEPLOYMENT_INFO = null;

// Celestia Constants
const CELESTIA_SEQUENCER_ADDRESS = 'celestia1j4rkmm42vhdf8t2lggzmm6hfdu9u6agqatm7eh';
const CELESTIA_API_BASE = 'https://api-mocha.celenium.io';
const CELESTIA_RPC_BASE = 'https://rpc-mocha.celenium.io';
const CELESTIA_EXPLORER_BASE = 'https://mocha.celenium.io';

// Auto-load deployment info
async function loadDeploymentInfo() {
    try {
        const response = await fetch('./deployment_info.json?t=' + Date.now());
        if (response.ok) {
            DEPLOYMENT_INFO = await response.json();
            if (DEPLOYMENT_INFO.contracts?.ROSCA?.address) {
                CONTRACT_ADDRESS = DEPLOYMENT_INFO.contracts.ROSCA.address;
                console.log('✅ Loaded ROSCA from deployment_info:', CONTRACT_ADDRESS);
            }
            updateDeploymentMetadata();
        }
    } catch (e) {
        console.warn('⚠ No deployment_info.json found, using fallback address');
    }
}

function updateDeploymentMetadata() {
    if (!DEPLOYMENT_INFO) return;
    
    const metadataHTML = `
        <div class="deployment-metadata">
            <h3>🔗 Deployment Info</h3>
            <div class="metadata-grid">
                ${DEPLOYMENT_INFO.contracts?.ROSCA ? `
                    <div class="contract-info">
                        <strong>ROSCA Contract:</strong>
                        <code>${DEPLOYMENT_INFO.contracts.ROSCA.address}</code>
                        ${DEPLOYMENT_INFO.contracts.ROSCA.tx_hash ? `
                            <div class="tx-info">
                                <small>TX: <code>${DEPLOYMENT_INFO.contracts.ROSCA.tx_hash.slice(0, 16)}...</code></small>
                                ${DEPLOYMENT_INFO.contracts.ROSCA.celestia_height && DEPLOYMENT_INFO.contracts.ROSCA.celestia_height !== 'pending' ? `
                                    <a href="${DEPLOYMENT_INFO.contracts.ROSCA.celenium_url}" target="_blank" class="celestia-link">
                                        📡 Celestia Block ${DEPLOYMENT_INFO.contracts.ROSCA.celestia_height}
                                    </a>
                                ` : '<span class="pending">⏳ Pending DA</span>'}
                            </div>
                        ` : ''}
                    </div>
                ` : ''}
                
                ${DEPLOYMENT_INFO.contracts?.Greeter ? `
                    <div class="contract-info">
                        <strong>Greeter Contract:</strong>
                        <code>${DEPLOYMENT_INFO.contracts.Greeter.address}</code>
                        ${DEPLOYMENT_INFO.contracts.Greeter.tx_hash ? `
                            <div class="tx-info">
                                <small>TX: <code>${DEPLOYMENT_INFO.contracts.Greeter.tx_hash.slice(0, 16)}...</code></small>
                                ${DEPLOYMENT_INFO.contracts.Greeter.celestia_height && DEPLOYMENT_INFO.contracts.Greeter.celestia_height !== 'pending' ? `
                                    <a href="${DEPLOYMENT_INFO.contracts.Greeter.celenium_url}" target="_blank" class="celestia-link">
                                        📡 Celestia Block ${DEPLOYMENT_INFO.contracts.Greeter.celestia_height}
                                    </a>
                                ` : '<span class="pending">⏳ Pending DA</span>'}
                            </div>
                        ` : ''}
                    </div>
                ` : ''}
                
                <div class="network-info">
                    <strong>Network:</strong> Chain ID ${DEPLOYMENT_INFO.chain_id}<br>
                    <strong>Deployer:</strong> <code>${DEPLOYMENT_INFO.deployer?.slice(0, 16)}...</code><br>
                    <strong>Last Updated:</strong> ${new Date(DEPLOYMENT_INFO.last_updated).toLocaleString()}
                </div>
            </div>
            <button onclick="loadDeploymentInfo()" class="btn-refresh">🔄 Refresh</button>
        </div>
    `;
    
    // Insert before wallet-section or at the top of main content
    const existing = document.querySelector('.deployment-metadata');
    if (existing) {
        existing.outerHTML = metadataHTML;
    } else {
        const walletSection = document.querySelector('.wallet-section');
        if (walletSection) {
            walletSection.insertAdjacentHTML('beforebegin', metadataHTML);
        }
    }
}

class ROSCAApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.contract = null;
        this.userAddress = null;

        // Celestia State
        this.celestiaPollingInterval = null;
        this.lastCelestiaBlock = 0;
        this.celestiaCache = {};

        this.init();
    }

    async init() {
        await loadDeploymentInfo();
        this.setupEventListeners();
        await this.checkWalletConnection();

        // Iniciar monitoreo de Celestia si estamos en modo demo
        if (window.location.hash === '#demo') {
            this.startCelestiaMonitoring();
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

        // Local Wallet connection
        const localBtn = document.getElementById('connectLocalBtn');
        if (localBtn) {
            localBtn.addEventListener('click', () => {
                this.connectLocalWallet();
            });
        }

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

        // Refresh Celestia
        const refreshCelestiaBtn = document.getElementById('refreshCelestiaBtn');
        if (refreshCelestiaBtn) {
            refreshCelestiaBtn.addEventListener('click', () => {
                this.loadCelestiaActivity();
            });
        }
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
        } else if (tabName === 'celestia') {
            this.loadCelestiaActivity();
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
            const localBtn = document.getElementById('connectLocalBtn');
            if (localBtn) localBtn.style.display = 'none';

        } catch (error) {
            console.error('Error connecting wallet:', error);
            this.showMessage('Failed to connect wallet: ' + error.message, 'error');
        }
    }

    async connectLocalWallet() {
        try {
            this.showMessage('Connecting to local burner wallet...', 'info');

            // Connect to local RPC
            this.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');

            // Check if we have a saved private key
            let privateKey = localStorage.getItem('rosca_local_pk');
            if (!privateKey) {
                const wallet = ethers.Wallet.createRandom();
                privateKey = wallet.privateKey;
                localStorage.setItem('rosca_local_pk', privateKey);
            }

            // Create wallet connected to provider
            const wallet = new ethers.Wallet(privateKey, this.provider);
            this.signer = wallet;
            this.userAddress = wallet.address;

            // Initialize contract
            this.contract = new ethers.Contract(CONTRACT_ADDRESS, ROSCA_ABI, this.signer);

            // Try to fund wallet if balance is low
            const balance = await wallet.getBalance();
            if (balance.lt(ethers.utils.parseEther("0.01"))) {
                this.showMessage('Funding wallet from Faucet...', 'info');
                try {
                    // Attempt to use the faucet (assuming standard POST /faucet or similar)
                    // Since we don't know the exact API, we'll try a common one or just log it
                    await fetch('http://localhost:8081/faucet', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ address: this.userAddress })
                    }).catch(() => { });

                    // Wait a bit for funding
                    await new Promise(r => setTimeout(r, 2000));
                } catch (e) {
                    console.warn('Faucet funding failed', e);
                }
            }

            // Update UI
            this.updateConnectionStatus(true, 'Local');
            this.showMessage(`Connected with Local Wallet: ${this.userAddress}`, 'success');

            // Set up event listeners
            this.setupContractEventListeners();
            this.updateContractBalance();

            // Update buttons
            const disconnectBtn = document.getElementById('disconnectBtn');
            if (disconnectBtn) disconnectBtn.style.display = 'inline-block';
            const connectBtn = document.getElementById('connectBtn');
            if (connectBtn) connectBtn.style.display = 'none';
            const localBtn = document.getElementById('connectLocalBtn');
            if (localBtn) localBtn.style.display = 'none';

        } catch (error) {
            console.error('Error connecting local wallet:', error);
            this.showMessage('Failed to connect local wallet: ' + error.message, 'error');
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
        const localBtn = document.getElementById('connectLocalBtn');
        if (localBtn) localBtn.style.display = 'inline-block';

        this.showMessage('Disconnected (dApp state cleared).', 'info');
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

    async loadCelestiaActivity() {
        const listDiv = document.getElementById('celestiaList');
        if (!listDiv) return;

        // Solo mostrar loading si está vacío para evitar parpadeos en actualizaciones automáticas
        if (!listDiv.hasChildNodes() || listDiv.innerHTML === '<div class="loading"></div>') {
            listDiv.innerHTML = '<div class="loading">Cargando actividad de Celestia...</div>';
        }

        try {
            // Cargar transacciones y datos del nodo en paralelo
            const [txsResponse, nodeInfo] = await Promise.allSettled([
                this.fetchWithCache(`${CELESTIA_API_BASE}/v1/address/${CELESTIA_SEQUENCER_ADDRESS}/txs?limit=10`, 'celestia_txs'),
                this.fetchCelestiaNodeInfo()
            ]);

            const transactions = txsResponse.status === 'fulfilled' ? txsResponse.value : [];
            const nodeData = nodeInfo.status === 'fulfilled' ? nodeInfo.value : null;

            // Mostrar estadísticas del nodo
            const statsHtml = this.renderCelestiaStats(nodeData);

            // Mostrar transacciones
            const transactionsHtml = Array.isArray(transactions)
                ? transactions.map(tx => this.renderCelestiaTransaction(tx)).join('')
                : '<p>No se pudieron cargar las transacciones</p>';

            listDiv.innerHTML = statsHtml + transactionsHtml;

            // Resaltar transacciones nuevas
            this.highlightNewTransactions(transactions);

        } catch (error) {
            console.error('Error al cargar actividad de Celestia:', error);
            const isNetworkError = error.message.includes('Failed to fetch') || error.message.includes('NetworkError') || error.message.includes('tiempo de espera');

            listDiv.innerHTML = `
                <div class="error-message">
                    <p><strong>⚠️ Error de Conexión</strong></p>
                    <p>${isNetworkError ? 'No se pudo conectar con la red de Celestia. Verifique su conexión a internet.' : 'Ocurrió un error al cargar los datos.'}</p>
                    <pre style="font-size: 0.8em; margin-top: 5px;">${error.message}</pre>
                    <button onclick="app.loadCelestiaActivity()" class="btn btn-sm btn-secondary" style="margin-top: 10px;">
                        Intentar de nuevo
                    </button>
                </div>
            `;
        }
    }

    async fetchCelestiaNodeInfo() {
        try {
            const response = await fetch(`${CELESTIA_RPC_BASE}/status`);
            return await response.json();
        } catch (error) {
            console.error('Error al obtener información del nodo:', error);
            return null;
        }
    }

    async fetchWithCache(url, cacheKey, ttl = 30000) {
        const now = Date.now();

        // Verificar caché
        if (this.celestiaCache[cacheKey] && (now - this.celestiaCache[cacheKey].timestamp < ttl)) {
            return this.celestiaCache[cacheKey].data;
        }

        // Si no hay caché o está expirado, hacer la solicitud
        const response = await fetch(url);
        const data = await response.json();

        // Actualizar caché
        this.celestiaCache[cacheKey] = {
            timestamp: now,
            data: data
        };

        return data;
    }

    renderCelestiaStats(nodeInfo) {
        if (!nodeInfo) return '<div class="error-message">No se pudo obtener información del nodo</div>';

        return `
            <div class="celestia-stats">
                <div class="stat-item">
                    <span class="stat-label">Nodo:</span>
                    <span class="stat-value">${nodeInfo?.result?.node_info?.moniker || 'N/A'}</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">Red:</span>
                    <span class="stat-value">${nodeInfo?.result?.node_info?.network || 'N/A'}</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">Versión:</span>
                    <span class="stat-value">${nodeInfo?.result?.node_info?.version || 'N/A'}</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">Último bloque:</span>
                    <span class="stat-value">${nodeInfo?.result?.sync_info?.latest_block_height || 'N/A'}</span>
                </div>
            </div>
        `;
    }

    renderCelestiaTransaction(tx) {
        if (!tx) return '';

        const isBlob = tx.message_types?.includes('MsgPayForBlobs');
        const typeBadge = isBlob
            ? '<span class="status-badge status-paid">Envío de Datos</span>'
            : `<span class="status-badge status-pending">${tx.message_types?.[0]?.split('.')?.pop() || 'Transacción'}</span>`;

        const date = tx.time ? new Date(tx.time).toLocaleString() : 'N/A';
        const txHash = tx.hash || 'N/A';
        const height = tx.height || 'N/A';
        const gasUsed = tx.gas_used || '0';
        const gasWanted = tx.gas_wanted || '0';
        const feeAmount = tx.fee || '0';

        // Extraer información específica para transacciones de blobs si está disponible en la respuesta de Celenium
        let blobInfo = '';
        if (isBlob) {
            blobInfo = `
                <div class="info-item">
                    <strong>Namespace:</strong> ${tx.blobs?.[0]?.namespace || 'N/A'}
                </div>
                <div class="info-item">
                    <strong>Share Commit:</strong> ${tx.blobs?.[0]?.share_commitment?.substring(0, 10) || 'N/A'}...
                </div>
            `;
        }

        return `
            <div class="card celestia-tx" data-tx-hash="${txHash}" data-height="${height}">
                <div class="tx-header">
                    <div class="tx-hash-container">
                        <span class="tx-hash-label">TX:</span>
                        <span class="tx-hash" title="${txHash}">
                            ${txHash.substring(0, 12)}...${txHash.substring(txHash.length - 6)}
                        </span>
                    </div>
                    ${typeBadge}
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <strong>Altura:</strong> ${height}
                    </div>
                    <div class="info-item">
                        <strong>Fecha:</strong> ${date}
                    </div>
                    <div class="info-item">
                        <strong>Gas:</strong> ${gasUsed} / ${gasWanted}
                    </div>
                    <div class="info-item">
                        <strong>Tarifa:</strong> ${feeAmount} utia
                    </div>
                    ${blobInfo}
                </div>
                <div class="tx-actions">
                    <a href="${CELESTIA_EXPLORER_BASE}/tx/${txHash}" 
                       target="_blank" 
                       class="btn btn-sm" 
                       style="padding: 5px 10px; font-size: 0.9em;">
                        Ver en explorador
                    </a>
                </div>
            </div>
        `;
    }

    highlightNewTransactions(transactions) {
        if (!transactions || !transactions.length) return;

        // Obtener el bloque más reciente
        const latestBlock = transactions[0]?.height;
        if (!latestBlock || latestBlock === this.lastCelestiaBlock) return;

        // Resaltar solo las transacciones del nuevo bloque
        const newTxs = transactions.filter(tx => tx.height > this.lastCelestiaBlock);
        newTxs.forEach(tx => {
            // Usamos setTimeout para asegurar que el DOM se ha actualizado
            setTimeout(() => {
                const txElement = document.querySelector(`.celestia-tx[data-tx-hash="${tx.hash}"]`);
                if (txElement) {
                    txElement.classList.add('highlight');
                    // Eliminar la clase después de la animación
                    setTimeout(() => txElement.classList.remove('highlight'), 2000);
                }
            }, 100);
        });

        this.lastCelestiaBlock = latestBlock;
    }

    startCelestiaMonitoring() {
        // Detener cualquier intervalo existente
        this.stopCelestiaMonitoring();

        // Cargar actividad inicial
        this.loadCelestiaActivity();

        // Configurar intervalo para actualizaciones periódicas
        this.celestiaPollingInterval = setInterval(() => {
            this.loadCelestiaActivity();
        }, 15000); // Actualizar cada 15 segundos
    }

    stopCelestiaMonitoring() {
        if (this.celestiaPollingInterval) {
            clearInterval(this.celestiaPollingInterval);
            this.celestiaPollingInterval = null;
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
document.addEventListener('DOMContentLoaded', () => {
    const app = new ROSCAApp();

    // Manejar el botón de auto-actualización
    const toggleAutoRefreshBtn = document.getElementById('toggleAutoRefresh');
    if (toggleAutoRefreshBtn) {
        let autoRefreshEnabled = localStorage.getItem('celestiaAutoRefresh') === 'true';
        updateAutoRefreshButton(toggleAutoRefreshBtn, autoRefreshEnabled);

        toggleAutoRefreshBtn.addEventListener('click', () => {
            autoRefreshEnabled = !autoRefreshEnabled;
            localStorage.setItem('celestiaAutoRefresh', autoRefreshEnabled);

            if (autoRefreshEnabled) {
                app.startCelestiaMonitoring();
            } else {
                app.stopCelestiaMonitoring();
            }

            updateAutoRefreshButton(toggleAutoRefreshBtn, autoRefreshEnabled);
        });

        // Iniciar auto-actualización si estaba activada
        if (autoRefreshEnabled) {
            app.startCelestiaMonitoring();
        }
    }

    // Si estamos en modo demo, iniciar automáticamente
    if (window.location.hash === '#demo') {
        app.showMessage('Modo demostración activado. Monitoreando actividad de Celestia...', 'info');
        const celestiaTab = document.querySelector('[data-tab="celestia"]');
        if (celestiaTab) celestiaTab.click();

        // Forzar la actualización inicial
        setTimeout(() => app.loadCelestiaActivity(), 1000);
    }
});

function updateAutoRefreshButton(button, isEnabled) {
    const icon = button.querySelector('.btn-icon');
    if (isEnabled) {
        if (icon) icon.textContent = '⏸️';
        button.title = 'Pausar auto-actualización';
        button.classList.add('active');
    } else {
        if (icon) icon.textContent = '⏯️';
        button.title = 'Activar auto-actualización';
        button.classList.remove('active');
    }
}