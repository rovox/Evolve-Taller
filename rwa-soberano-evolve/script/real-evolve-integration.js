const { ethers } = require('ethers');
const fs = require('fs');

class RealEvolveIntegration {
    constructor() {
        // Usar la RPC de Evolve desde el docker-compose
        this.evolveRpcUrl = process.env.EVOLVE_RPC_URL || 'http://localhost:8545';
        this.provider = new ethers.JsonRpcProvider(this.evolveRpcUrl);
        this.wallet = new ethers.Wallet(process.env.PRIVATE_KEY, this.provider);

        console.log(' Conectado a Evolve RPC:', this.evolveRpcUrl);
    }

    async checkConnection() {
        try {
            const blockNumber = await this.provider.getBlockNumber();
            console.log(' Conectado a Evolve. Block number:', blockNumber);

            const network = await this.provider.getNetwork();
            console.log(' Chain ID:', network.chainId);

            return true;
        } catch (error) {
            console.error(' Error conectando a Evolve:', error.message);
            return false;
        }
    }

    async deployContracts() {
        console.log(' Desplegando contratos en Evolve Rollup...');

        // Leer los ABIs compilados
        const registryArtifact = JSON.parse(
            fs.readFileSync('../rwa-soberano-evolve/out/DocumentRegistry.sol/DocumentRegistry.json', 'utf8')
        );

        const rollupArtifact = JSON.parse(
            fs.readFileSync('../rwa-soberano-evolve/out/RWASovereignRollup.sol/RWASovereignRollup.json', 'utf8')
        );

        // Desplegar DocumentRegistry
        const registryFactory = new ethers.ContractFactory(
            registryArtifact.abi,
            registryArtifact.bytecode.object,
            this.wallet
        );

        console.log(' Desplegando DocumentRegistry...');
        const registry = await registryFactory.deploy();
        await registry.waitForDeployment();
        const registryAddress = await registry.getAddress();
        console.log(' DocumentRegistry desplegado en:', registryAddress);

        // Desplegar RWASovereignRollup
        const rollupFactory = new ethers.ContractFactory(
            rollupArtifact.abi,
            rollupArtifact.bytecode.object,
            this.wallet
        );

        console.log(' Desplegando RWASovereignRollup...');
        const rollup = await rollupFactory.deploy();
        await rollup.waitForDeployment();
        const rollupAddress = await rollup.getAddress();
        console.log(' RWASovereignRollup desplegado en:', rollupAddress);

        return { registryAddress, rollupAddress };
    }

    async interactWithContracts(registryAddress, rollupAddress) {
        console.log('\n🔨 Interactuando con contratos...');

        const registry = new ethers.Contract(
            registryAddress,
            JSON.parse(fs.readFileSync('../rwa-soberano-evolve/out/DocumentRegistry.sol/DocumentRegistry.json', 'utf8')).abi,
            this.wallet
        );

        const rollup = new ethers.Contract(
            rollupAddress,
            JSON.parse(fs.readFileSync('../rwa-soberano-evolve/out/RWASovereignRollup.sol/RWASovereignRollup.json', 'utf8')).abi,
            this.wallet
        );

        // 1. Registrar documento
        const documentContent = "Documento Legal RWA - Propiedad Inmobiliaria #001";
        const documentHash = ethers.keccak256(ethers.toUtf8Bytes(documentContent));

        console.log(' Registrando documento con hash:', documentHash);
        const registerTx = await registry.registerDocument(documentHash);
        await registerTx.wait();
        console.log(' Documento registrado. TX:', registerTx.hash);

        // 2. Commit block en el rollup
        const stateRoot = ethers.keccak256(ethers.toUtf8Bytes("state_root_" + Date.now()));
        const daHash = ethers.keccak256(ethers.toUtf8Bytes("da_hash_" + Date.now()));

        console.log(' Commitando bloque en rollup...');
        const commitTx = await rollup.commitBlock(stateRoot, daHash);
        await commitTx.wait();
        console.log(' Bloque commitado. TX:', commitTx.hash);

        // 3. Verificar datos
        const documentRecord = await registry.getDocumentRecord(1);
        console.log(' Registro de documento:', {
            hash: documentRecord.documentHash,
            daTxHash: documentRecord.daTransactionHash,
            timestamp: new Date(Number(documentRecord.timestamp) * 1000).toISOString()
        });

        return {
            documentHash,
            registerTx: registerTx.hash,
            commitTx: commitTx.hash,
            documentRecord
        };
    }

    async simulateCelestiaIntegration(documentHash) {
        console.log('\n Simulando integración con Celestia...');

        // En un entorno real, aquí publicaríamos en Celestia DA
        // Por ahora simulamos con hashes

        const celestiaNamespace = '0x1234567890abcdef'; // Namespace de ejemplo
        const daBatchHash = ethers.keccak256(
            ethers.toUtf8Bytes(JSON.stringify({
                namespace: celestiaNamespace,
                data: documentHash,
                timestamp: Date.now(),
                network: 'celestia-mocha'
            }))
        );

        console.log('  Simulación Celestia DA completada');
        console.log('   - Namespace:', celestiaNamespace);
        console.log('   - Batch Hash:', daBatchHash);

        return daBatchHash;
    }
}

module.exports = RealEvolveIntegration;