import { ethers } from 'ethers';
import fs from 'fs';

async function main() {
    console.log('🚀 Iniciando despliegue de contratos RWA...\n');

    // Configurar provider (Anvil local)
    const rpcUrl = process.env.EVOLVE_RPC_URL || 'http://localhost:8545';
    const provider = new ethers.JsonRpcProvider(rpcUrl);

    // Usar private key de Anvil para testing
    const privateKey = process.env.PRIVATE_KEY || 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
    const wallet = new ethers.Wallet(privateKey, provider);

    console.log('📡 Conectado a:', rpcUrl);
    console.log('👤 Cuenta:', wallet.address);
    console.log('💰 Balance:', ethers.formatEther(await provider.getBalance(wallet.address)), 'ETH\n');

    // Cargar ABIs
    const loadABI = (contractName) => {
        const filePath = `./out/${contractName}.sol/${contractName}.json`;
        return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    };

    const deployments = {};

    try {
        // 1. Desplegar MockERC20
        console.log('📦 1/5 Desplegando MockERC20...');
        const mockABI = loadABI('MockERC20');
        const mockFactory = new ethers.ContractFactory(mockABI.abi, mockABI.bytecode.object, wallet);
        const mockERC20 = await mockFactory.deploy();
        await mockERC20.waitForDeployment();
        deployments.MockERC20 = await mockERC20.getAddress();
        console.log('✅ MockERC20:', deployments.MockERC20);

        // 2. Desplegar AssetToken
        console.log('📦 2/5 Desplegando AssetToken...');
        const assetABI = loadABI('AssetToken');
        const assetFactory = new ethers.ContractFactory(assetABI.abi, assetABI.bytecode.object, wallet);
        const assetToken = await assetFactory.deploy();
        await assetToken.waitForDeployment();
        deployments.AssetToken = await assetToken.getAddress();
        console.log('✅ AssetToken:', deployments.AssetToken);

        // 3. Desplegar DocumentRegistry
        console.log('📦 3/5 Desplegando DocumentRegistry...');
        const registryABI = loadABI('DocumentRegistry');
        const registryFactory = new ethers.ContractFactory(registryABI.abi, registryABI.bytecode.object, wallet);
        const documentRegistry = await registryFactory.deploy();
        await documentRegistry.waitForDeployment();
        deployments.DocumentRegistry = await documentRegistry.getAddress();
        console.log('✅ DocumentRegistry:', deployments.DocumentRegistry);

        // 4. Desplegar RWAVault
        console.log('📦 4/5 Desplegando RWAVault...');
        const vaultABI = loadABI('RWAValut');
        const vaultFactory = new ethers.ContractFactory(vaultABI.abi, vaultABI.bytecode.object, wallet);
        const vault = await vaultFactory.deploy(deployments.MockERC20, deployments.AssetToken);
        await vault.waitForDeployment();
        deployments.RWAVault = await vault.getAddress();
        console.log('✅ RWAVault:', deployments.RWAVault);

        // 5. Desplegar RWASovereignRollup
        console.log('📦 5/5 Desplegando RWASovereignRollup...');
    const rollupABI = loadABI('RWASovereignRollup');
        const rollupFactory = new ethers.ContractFactory(rollupABI.abi, rollupABI.bytecode.object, wallet);
        const rollup = await rollupFactory.deploy();
        await rollup.waitForDeployment();
        deployments.RWASovereignRollup = await rollup.getAddress();
        console.log('✅ RWASovereignRollup:', deployments.RWASovereignRollup);

        // Guardar configuración
        const config = {
            contracts: deployments,
            rpcUrl: rpcUrl,
            deployer: wallet.address,
            timestamp: new Date().toISOString()
        };

        fs.writeFileSync('./deployments.json', JSON.stringify(config, null, 2));

        // Actualizar frontend automáticamente
        const frontendEnv = `
VITE_REGISTRY_ADDRESS=${deployments.DocumentRegistry}
VITE_VAULT_ADDRESS=${deployments.RWAVault}
VITE_ROLLUP_ADDRESS=${deployments.RWASovereignRollup}
VITE_ASSET_TOKEN_ADDRESS=${deployments.AssetToken}
VITE_MOCK_ERC20_ADDRESS=${deployments.MockERC20}
VITE_EVOLVE_RPC_URL=${rpcUrl}
VITE_CELESTIA_RPC_URL=https://rpc-mocha.pops.one/
`.trim();

        fs.writeFileSync('../frontend/.env.local', frontendEnv);

        console.log('\n🎉 ¡DESPLIEGUE EXITOSO!');
        console.log('=====================');
        console.log('📋 Direcciones generadas:');
        Object.entries(deployments).forEach(([name, address]) => {
            console.log(`   ${name}: ${address}`);
        });

        console.log('\n📁 Archivos generados:');
        console.log('   - deployments.json');
        console.log('   - ../frontend/.env.local');

        console.log('\n🚀 Próximos pasos:');
        console.log('   1. cd ../frontend');
        console.log('   2. npm run dev');
        console.log('   3. Abre http://localhost:5173');
        console.log('   4. Configura MetaMask con:');
        console.log('      - Network: Evolve Local');
        console.log('      - RPC: http://localhost:8545');
        console.log('      - Chain ID: 31337');

    } catch (error) {
        console.error('❌ Error en el despliegue:', error);
        process.exit(1);
    }
}

// Si el script se ejecuta directamente
if (import.meta.url === `file://${process.argv[1]}`) {
    main();
}

export { main };