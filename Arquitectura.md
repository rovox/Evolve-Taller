# Arquitectura de Contratos, Despliegue y Testing

Este documento detalla la arquitectura de los contratos inteligentes del proyecto, su proceso de despliegue orquestado por Tilt y los mecanismos de validación y testing.

## 1. Arquitectura de Contratos Inteligentes

El sistema utiliza una arquitectura modular para los contratos de `rwa-soberano-evolve/` con el fin de gestionar la complejidad y mantenerse por debajo del límite de tamaño de 24KB del EVM.

### Contratos Principales

-   **`RWAToken.sol`**: Es el contrato de fachada principal que implementa el estándar ERC-1155 para la tokenización de activos. Agrega funcionalidades de módulos de `core/` y `extensions/`.
-   **`DocumentRegistry.sol`**: Un registro para hashes de documentos (ej. IPFS, Celestia DA) que permite versionado, soporte multi-activo y asignación de roles (`REGISTRAR_ROLE`).
-   **`RWASovereignRollup.sol`**: Contrato de orquestación que integra la lógica del rollup, gestionando la comunicación entre contratos y los commits de bloques.
-   **`DividendDistributor.sol`**: Gestiona la distribución de ingresos a los tenedores de tokens, permitiendo la creación de dividendos y su posterior reclamo.

### Estructura Modular (`rwa-soberano-evolve/src/`)

La funcionalidad del contrato `RWAToken.sol` se divide en módulos para mejorar la legibilidad y el mantenimiento.

-   **`core/`**: Contiene la lógica base.
    -   `RWATokenCore.sol`: Gestión de activos, implementación base de ERC-1155 y control de acceso.
    -   `RWATokenMinting.sol`: Lógica para la creación (`mint`) y quema (`burn`) de tokens.
    -   `RWATokenQueries.sol`: Funciones de solo lectura (`view`) para consultar datos de activos y accionistas.
-   **`extensions/`**: Módulos con funcionalidades extendidas.
    -   `RWATokenSales.sol`: Lógica para la venta pública de acciones (`buyShares`) y procesamiento de pagos.
    -   `RWATokenAdmin.sol`: Funciones administrativas como pausar el contrato y gestionar roles.
-   **`libraries/`**: Bibliotecas de apoyo.
    -   `RWAStorage.sol`: Define las estructuras de datos (`structs`) compartidas como `Asset` y `SaleConfig`.
    -   `RWAMath.sol`: Funciones matemáticas puras para cálculos.
    -   `RWAValidation.sol`: Helpers para la validación de entradas.

### Generación de ABIs

Los ABIs (Application Binary Interfaces) son cruciales para que el frontend interactúe con los contratos. El flujo para obtenerlos es:

1.  Compilar los contratos con Foundry:
    ```bash
    cd rwa-soberano-evolve
    forge build
    ```
2.  Los archivos JSON de los ABIs se generan en el directorio `rwa-soberano-evolve/out/`.
3.  Estos archivos deben ser copiados manualmente o mediante un script al directorio `frontend/src/abis/` para que el frontend pueda importarlos. El script `copy:abis` en [`rwa-soberano-evolve/package.json`](rwa-soberano-evolve/package.json) es un ejemplo de ello.

## 2. Proceso de Despliegue con Tilt

El despliegue está totalmente orquestado por el archivo [`Tiltfile`](Tiltfile), que define una secuencia de pasos para levantar el entorno completo.

El flujo de despliegue de contratos se activa con `tilt up` (si no se usa la bandera `--reth-only`):

1.  **`reth-ready`**: Espera a que el nodo de Reth (`http://localhost:8545`) esté disponible.
2.  **`celestia-ready`**: Espera a que el nodo de Celestia (`http://localhost:26658`) esté operativo y se haya obtenido el JWT.
3.  **`rollkit-ready`**: Espera a que el secuenciador del rollup Evolve (`http://localhost:7331`) esté listo para recibir transacciones.
4.  **`deploy-rwa-contracts`**: Una vez que toda la infraestructura está lista, este recurso ejecuta el script [`scripts/deploy-rwa-contracts.sh`](scripts/deploy-rwa-contracts.sh). Este script utiliza `forge script` para desplegar los contratos en el rollup.
5.  **`sync-frontend-addresses`**: Tras el despliegue, se ejecuta [`scripts/sync-contract-addresses.sh`](scripts/sync-contract-addresses.sh), que lee las direcciones de los contratos desde `rwa-soberano-evolve/deployed-addresses.env` y las sincroniza con el frontend, creando los archivos `frontend/public/deployed-addresses.env` y `frontend/.env.local`.

## 3. Procedimientos de Testeo y Validación

El proyecto cuenta con múltiples capas de testing para asegurar la calidad y el correcto funcionamiento.

-   **Pruebas Unitarias (Foundry)**:
    -   Se ejecutan a través del recurso `run-contract-tests` en [`Tiltfile`](Tiltfile), que llama al script [`scripts/run-contract-tests.sh`](scripts/run-contract-tests.sh).
    -   Este script simplemente ejecuta `forge test -vv` dentro de `rwa-soberano-evolve/`.
    -   Los tests, como `RWAToken.t.sol`, cubren la lógica de negocio de cada contrato de forma aislada.

-   **Pruebas de Integración (Scripts)**:
    -   **`rwa-integration-test`**: Este recurso de Tilt ejecuta [`scripts/test-rwa-integration.sh`](scripts/test-rwa-integration.sh), un test de humo que utiliza `cast` (de Foundry) para realizar operaciones básicas en los contratos ya desplegados y verificar su estado.
    -   **`evolve-integration-tests`**: Un test más avanzado basado en JavaScript/Mocha, definido en [`rwa-soberano-evolve/test/evolve-integration.test.js`](rwa-soberano-evolve/test/evolve-integration.test.js). Este test simula un flujo completo, incluyendo el despliegue y la interacción con la API de Evolve.

-   **Validación de Configuración**:
    -   El script [`scripts/verify-setup.sh`](scripts/verify-setup.sh) comprueba que todos los archivos y configuraciones necesarios para la integración estén en su lugar.
    -   El script [`scripts/verify-contract-sizes.sh`](scripts/verify-contract-sizes.sh) revisa que los contratos compilados no excedan el límite de tamaño del EVM.