const { expect } = require('chai');
const EvolveIntegration = require('../scripts/evolve-integration');
const { ethers } = require('ethers');

describe('Integración Real Evolve + Celestia', function () {
    this.timeout(60000); // 60 segundos timeout

    let integrator;
    let deploymentResult;

    before(async function () {
        integrator = new EvolveIntegration();

        // Solo ejecutar si tenemos configuración de Evolve
        if (!process.env.PRIVATE_KEY) {
            this.skip();
        }
    });

    it('debería desplegar contratos en Evolve Rollup', async function () {
        deploymentResult = await integrator.deployContractsToEvolve();

        expect(deploymentResult.registryAddress).to.match(/^0x[a-fA-F0-9]{40}$/);
        expect(deploymentResult.rollupAddress).to.match(/^0x[a-fA-F0-9]{40}$/);

        console.log(' Registry:', deploymentResult.registryAddress);
        console.log(' Rollup:', deploymentResult.rollupAddress);
    });

    it('debería ejecutar flujo completo de integración', async function () {
        const integrationResult = await integrator.fullIntegrationFlow();

        expect(integrationResult.documentHash).to.match(/^0x[a-fA-F0-9]{64}$/);
        expect(integrationResult.daTransactionHash).to.match(/^0x[a-fA-F0-9]{64}$/);
        expect(integrationResult.commitTransaction).to.match(/^0x[a-fA-F0-9]{64}$/);

        console.log(' Flujo completo ejecutado exitosamente');
        console.log(' Document Hash:', integrationResult.documentHash);
        console.log(' DA Tx Hash:', integrationResult.daTransactionHash);
        console.log(' Commit Tx:', integrationResult.commitTransaction);
    });

    it('debería interactuar con Evolve API', async function () {
        await integrator.interactWithEvolveAPI();
        // Si no hay error, la prueba pasa
        expect(true).to.be.true;
    });
});