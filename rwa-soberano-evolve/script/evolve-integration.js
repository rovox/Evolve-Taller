const { execSync } = require('child_process');
const { ethers } = require('ethers');
const fs = require('fs');

class EvolveIntegration {
    constructor() {
        this.evolveRpcUrl = process.env.EVOLVE_RPC_URL || 'http://localhost:7331';
        this.celestiaRpcUrl = process.env.CELESTIA_RPC_URL || 'https://rpc-mocha.pops.one/';
        this.provider = new ethers.JsonRpcProvider(this.evolveRpcUrl);
        this.wallet = new ethers.Wallet(process.env.PRIVATE_KEY, this.provider);
    }

    async startEvolveNode() {
        console.log(' Iniciando nodo Evolve...');

        try {
            // Iniciar DA local para desarrollo
            execSync('go install github.com/evstack/ev-node/da/cmd/local-da@latest', { stdio: 'inherit' });

            // En una terminal separada, necesitarías ejecutar:
            // local-da
            console.log(' DA local instalado. Ejecuta en terminal separada: local-da');

        } catch (error) {
            console.log('  DA local ya instalado o en ejecución');
        }

        // Para producción con Celestia Mocha, usaríamos:
        // ./build/testapp start --evnode.da.layer celestia --evnode.da.config '{"rpc":"'${CELESTIA_RPC_URL}'"}' --evnode.signer.passphrase secret
    }

    async deployContractsToEvolve() {
        console.log(' Desplegando contratos en Evolve Rollup...');

        // 1. Compilar contratos
        console.log(' Compilando contratos...');
        execSync('forge build', { stdio: 'inherit' });

        // 2. Desplegar DocumentRegistry
        const registryArtifact = JSON.parse(
            fs.readFileSync('out/DocumentRegistry.sol/DocumentRegistry.json', 'utf8')
        );

        const registryFactory = new ethers.ContractFactory(
            registryArtifact.abi,
            registryArtifact.bytecode.object,
            this.wallet
        );

        const registry = await registryFactory.deploy();
        await registry.waitForDeployment();
        const registryAddress = await registry.getAddress();

        console.log(' DocumentRegistry desplegado en:', registryAddress);

        // 3. Desplegar RWASovereignRollup
        const rollupArtifact = JSON.parse(
            fs.readFileSync('out/RWASovereignRollup.sol/RWASovereignRollup.json', 'utf8')
        );

        const rollupFactory = new ethers.ContractFactory(
            rollupArtifact.abi,
            rollupArtifact.bytecode.object,
            this.wallet
        );

        const rollup = await rollupFactory.deploy();
        await rollup.waitForDeployment();
        const rollupAddress = await rollup.getAddress();

        console.log(' RWASovereignRollup desplegado en:', rollupAddress);

        return { registryAddress, rollupAddress };
    }

    async interactWithEvolveAPI() {
        console.log(' Interactuando con Evolve API...');

        try {
            // Health check
            const healthResponse = await fetch(`${this.evolveRpcUrl}/health/live`);
            console.log(' Evolve Health:', await healthResponse.text());

            // Store API - obtener información de bloques
            const storeResponse = await fetch(`${this.evolveRpcUrl}/store/block`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ height: "1" })
            });

            const blockInfo = await storeResponse.json();
            console.log(' Información del bloque:', blockInfo);

        } catch (error) {
            console.log('⚠️  Evolve API no disponible, ejecuta primero el nodo Evolve');
        }
    }

    async simulateCelestiaDAPublication(documentHash) {
        console.log(' Simulando publicación en Celestia DA...');

        // En un entorno real, esto usaría el SDK de Evolve para publicar en Celestia
        // Por ahora simulamos la publicación

        const daPayload = {
            namespace: 'rwa-sovereign',
            data: documentHash,
            timestamp: Date.now()
        };

        const daTransactionHash = ethers.keccak256(
            ethers.toUtf8Bytes(JSON.stringify(daPayload))
        );

        console.log(' Transacción DA simulada:', daTransactionHash);
        return daTransactionHash;
    }

    async fullIntegrationFlow() {
        console.log(' Iniciando flujo completo de integración...\n');

        // 1. Desplegar contratos
        const { registryAddress, rollupAddress } = await this.deployContractsToEvolve();

        // 2. Interactuar con Evolve API
        await this.interactWithEvolveAPI();

        // 3. Registrar documento y publicar en DA
        const documentContent = "Documento legal del RWA - Propiedad Inmobiliaria #001";
        const documentHash = ethers.keccak256(ethers.toUtf8Bytes(documentContent));

        console.log(' Registrando documento con hash:', documentHash);

        const registry = await ethers.getContractAt('DocumentRegistry', registryAddress, this.wallet);
        const tx = await registry.registerDocument(documentHash);
        await tx.wait();

        console.log(' Documento registrado en contrato');

        // 4. Simular publicación en Celestia DA
        const daTxHash = await this.simulateCelestiaDAPublication(documentHash);

        // 5. Commit block en el rollup
        const rollup = await ethers.getContractAt('RWASovereignRollup', rollupAddress, this.wallet);
        const stateRoot = ethers.keccak256(ethers.toUtf8Bytes("state_root_" + Date.now()));

        const commitTx = await rollup.commitBlock(stateRoot, daTxHash);
        await commitTx.wait();

        console.log(' Bloque commitado en rollup');

        return {
            registryAddress,
            rollupAddress,
            documentHash,
            daTransactionHash: daTxHash,
            commitTransaction: commitTx.hash
        };
    }
}

module.exports = EvolveIntegration;