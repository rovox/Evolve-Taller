import { ethers } from 'ethers';
import fs from 'fs';

async function main() {
    console.log('🚀 Iniciando despliegue FRESCO de contratos RWA...\n');

    // Configurar provider
    const rpcUrl = 'http://localhost:8545';
    const provider = new ethers.JsonRpcProvider(rpcUrl);

    // Private key de Anvil (con 0x)
    const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
    const wallet = new ethers.Wallet(privateKey, provider);

    console.log('📡 Conectado a:', rpcUrl);
    console.log('👤 Cuenta:', wallet.address);

    // Obtener nonce ACTUAL
    const currentNonce = await provider.getTransactionCount(wallet.address);
    console.log('🔢 Nonce inicial:', currentNonce);

    // Cargar ABIs
    const loadABI = (contractName) => {
        const filePath = `./out/${contractName}.sol/${contractName}.json`;
        return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    };

    const deployments = {};
    let nonce = currentNonce;

    try {
        // 1. Desplegar MockERC20
        console.log('\n📦 1/5 Desplegando MockERC20...');
        const mockABI = loadABI('MockERC20');
        const mockFactory = new ethers.ContractFactory(mockABI.abi, mockABI.bytecode.object, wallet);
        const mockERC20 = await mockFactory.deploy({ nonce: nonce++ });
        await mockERC20.waitForDeployment();
        deployments.MockERC20 = await mockERC20.getAddress();
        console.log('✅ MockERC20:', deployments.MockERC20);

        // 2. Desplegar AssetToken
        console.log('📦 2/5 Desplegando AssetToken...');
        const assetABI = loadABI('AssetToken');
        const assetFactory = new ethers.ContractFactory(assetABI.abi, assetABI.bytecode.object, wallet);
        const assetToken = await assetFactory.deploy({ nonce: nonce++ });
        await assetToken.waitForDeployment();
        deployments.AssetToken = await assetToken.getAddress();
        console.log('✅ AssetToken:', deployments.AssetToken);

        // 3. Desplegar DocumentRegistry
        console.log('📦 3/5 Desplegando DocumentRegistry...');
        const registryABI = loadABI('DocumentRegistry');
        const registryFactory = new ethers.ContractFactory(registryABI.abi, registryABI.bytecode.object, wallet);
        const documentRegistry = await registryFactory.deploy({ nonce: nonce++ });
        await documentRegistry.waitForDeployment();
        deployments.DocumentRegistry = await documentRegistry.getAddress();
        console.log('✅ DocumentRegistry:', deployments.DocumentRegistry);

        // 4. Desplegar RWAValut
        console.log('📦 4/5 Desplegando RWAValut...');
        const vaultABI = loadABI('RWAValut');
        const vaultFactory = new ethers.ContractFactory(vaultABI.abi, vaultABI.bytecode.object, wallet);
        const vault = await vaultFactory.deploy(deployments.MockERC20, deployments.AssetToken, { nonce: nonce++ });
        await vault.waitForDeployment();
        deployments.RWAValut = await vault.getAddress();
        console.log('✅ RWAValut:', deployments.RWAValut);

        // 5. Desplegar RWASovereignRollup
        console.log('📦 5/5 Desplegando RWASovereignRollup...');
    const rollupABI = loadABI('RWASovereignRollup');
        const rollupFactory = new ethers.ContractFactory(rollupABI.abi, rollupABI.bytecode.object, wallet);
        const rollup = await rollupFactory.deploy({ nonce: nonce++ });
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

        // Actualizar frontend
        const frontendEnv = `
VITE_REGISTRY_ADDRESS=${deployments.DocumentRegistry}
VITE_VAULT_ADDRESS=${deployments.RWAValut}
VITE_ROLLUP_ADDRESS=${deployments.RWASovereignRollup}
VITE_ASSET_TOKEN_ADDRESS=${deployments.AssetToken}
VITE_MOCK_ERC20_ADDRESS=${deployments.MockERC20}
VITE_EVOLVE_RPC_URL=${rpcUrl}
VITE_CELESTIA_RPC_URL=https://rpc-mocha.pops.one/
`.trim();

        fs.writeFileSync('../frontend/.env.local', frontendEnv);

        console.log('\n🎉 ¡DESPLIEGUE EXITOSO!');
        console.log('📋 Resumen en: deployments.json');
        console.log('🔧 Frontend configurado en: ../frontend/.env.local');

    } catch (error) {
        console.error('❌ Error en el despliegue:', error.message);
        if (error.info?.error) {
            console.log('🔧 Detalles:', error.info.error);
        }
        process.exit(1);
    }
}

main();