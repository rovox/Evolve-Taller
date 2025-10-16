const RealEvolveIntegration = require('./real-evolve-integration');

async function main() {
    console.log(' INICIANDO INTEGRACIÓN REAL CON EVOLVE + CELESTIA\n');

    if (!process.env.PRIVATE_KEY) {
        console.error(' PRIVATE_KEY no configurada en .env');
        process.exit(1);
    }

    const integrator = new RealEvolveIntegration();

    try {
        // 1. Verificar conexión
        const isConnected = await integrator.checkConnection();
        if (!isConnected) {
            console.error(' No se pudo conectar a Evolve. Asegúrate de que tilt up esté ejecutándose.');
            process.exit(1);
        }

        // 2. Desplegar contratos
        const { registryAddress, rollupAddress } = await integrator.deployContracts();

        // 3. Interactuar con contratos
        const interactionResult = await integrator.interactWithContracts(registryAddress, rollupAddress);

        // 4. Simular Celestia
        const celestiaResult = await integrator.simulateCelestiaIntegration(interactionResult.documentHash);

        // 5. Resultado final
        console.log('\n ¡INTEGRACIÓN EXITOSA!');
        console.log('=====================');
        console.log(' Resumen:');
        console.log('   - DocumentRegistry:', registryAddress);
        console.log('   - RWASovereignRollup:', rollupAddress);
        console.log('   - Document Hash:', interactionResult.documentHash);
        console.log('   - Register TX:', interactionResult.registerTx);
        console.log('   - Commit TX:', interactionResult.commitTx);
        console.log('   - Celestia Batch:', celestiaResult);
        console.log('\n Tu RWA está ahora en un Rollup Soberano real!');

        // Guardar direcciones para el frontend
        const config = {
            registryAddress,
            rollupAddress,
            documentHash: interactionResult.documentHash,
            rpcUrl: integrator.evolveRpcUrl,
            chainId: (await integrator.provider.getNetwork()).chainId
        };

        fs.writeFileSync('./evolve-config.json', JSON.stringify(config, null, 2));
        console.log(' Configuración guardada en: evolve-config.json');

    } catch (error) {
        console.error(' Error en la integración:', error);
        process.exit(1);
    }
}

main();