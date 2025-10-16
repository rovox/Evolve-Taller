const EvolveIntegration = require('./evolve-integration');

async function main() {
    console.log(' Despliegue en Evolve Rollup + Celestia DA\n');

    const integrator = new EvolveIntegration();

    try {
        const result = await integrator.fullIntegrationFlow();

        console.log('\n ¡Despliegue exitoso!');
        console.log('=====================');
        console.log(' DocumentRegistry:', result.registryAddress);
        console.log(' RWASovereignRollup:', result.rollupAddress);
        console.log(' Document Hash:', result.documentHash);
        console.log(' Celestia DA Tx:', result.daTransactionHash);
        console.log(' Commit Tx:', result.commitTransaction);
        console.log('\n Tu RWA está ahora en el Rollup Soberano con Celestia DA!');

    } catch (error) {
        console.error(' Error en el despliegue:', error);
        process.exit(1);
    }
}

main();