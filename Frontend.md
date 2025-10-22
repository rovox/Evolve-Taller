# Integración y Flujo de Funcionamiento del Frontend

Este documento describe cómo la aplicación frontend, construida con React y Vite, consume la lógica de los contratos inteligentes y cuál es su flujo de funcionamiento.

## 1. Configuración del Entorno Frontend

Para que el frontend pueda interactuar con la blockchain, necesita tres elementos clave: los ABIs de los contratos, sus direcciones desplegadas y una conexión a un proveedor de RPC.

### Flujo de Configuración con Tilt

El [`Tiltfile`](Tiltfile) automatiza gran parte de esta configuración:

1.  **Despliegue de Contratos**: Como se describió anteriormente, `tilt up` despliega los contratos.
2.  **Sincronización de Direcciones**: El recurso `sync-frontend-addresses` ejecuta [`scripts/sync-contract-addresses.sh`](scripts/sync-contract-addresses.sh). Este script es fundamental, ya que:
    -   Copia `rwa-soberano-evolve/deployed-addresses.env` a `frontend/public/deployed-addresses.env`. Esto permite que la aplicación cargue las direcciones en tiempo de ejecución.
    -   Crea `frontend/.env.local` con las direcciones como variables de entorno (`VITE_*_ADDRESS`), permitiendo su acceso durante el build de Vite.
3.  **Copia de ABIs**: Los ABIs generados en `rwa-soberano-evolve/out/` son copiados a `frontend/src/abis/` mediante scripts auxiliares (ver `scripts/deploy-rwa-contracts.sh` y `rwa-soberano-evolve/script/` para detalles). El archivo `frontend/src/abis/index.ts` debe ser actualizado para importar los nuevos ABIs si los nombres de los contratos cambian.
4.  **Arranque del Servidor**: Finalmente, el recurso `frontend-dev` ejecuta [`scripts/start-frontend.sh`](scripts/start-frontend.sh), que instala las dependencias (`npm ci`) si es necesario y arranca el servidor de desarrollo de Vite con `npm run dev`.

## 2. Flujo de Funcionamiento del Frontend

La aplicación frontend permite a los usuarios interactuar con los contratos inteligentes a través de su wallet de navegador (MetaMask).

### Conexión a la Wallet y a la Red

-   La aplicación utiliza librerías como `wagmi` y `ethers` para gestionar la conexión con la wallet.
-   El usuario debe conectar su MetaMask a la red local de desarrollo, que según el [`README.md`](README.md) es `http://localhost:8545` con un Chain ID de `31337`.
-   La UI mostrará errores si MetaMask no está instalado o si está conectado a una red incorrecta.

### Interacción con Contratos

-   **Hooks Personalizados**: La lógica de interacción está encapsulada en hooks de React para ser reutilizable. El archivo [`FRONTEND-INTEGRATION.md`](FRONTEND-INTEGRATION.md) muestra un ejemplo clave, `useRWAToken`.
-   **`useRWAToken`**:
    -   Importa el ABI desde `frontend/src/abis/RWAToken.json`.
    -   Obtiene la dirección del contrato desde las variables de entorno o el archivo de configuración.
    -   Utiliza el hook `useContract` de `wagmi` para crear una instancia del contrato.
    -   Expone funciones que encapsulan las llamadas a los métodos del contrato, como `createAsset`. Estas funciones preparan la transacción, la envían a través del `signer` de `wagmi` y esperan su confirmación.

### Flujo Típico de un Usuario

1.  **Acceso a la UI**: El usuario abre `http://localhost:5173` en su navegador.
2.  **Conexión**: La aplicación le pide conectar su wallet. El usuario aprueba la conexión en MetaMask.
3.  **Visualización de Datos**: La aplicación utiliza las funciones de solo lectura (`view`) de los contratos (ej. desde `RWATokenQueries.sol`) para mostrar el estado actual: lista de activos, balances de tokens, etc.
4.  **Ejecución de una Transacción**:
    -   El usuario rellena un formulario para, por ejemplo, registrar un documento en `DocumentRegistry.sol`.
    -   Al hacer clic en "Registrar", se llama a una función del hook correspondiente (ej. `useDocumentRegistry`).
    -   Esta función construye y envía la transacción.
    -   MetaMask solicita al usuario que firme y confirme la transacción.
    -   La aplicación espera la confirmación de la transacción (`tx.wait()`) y actualiza la UI para reflejar el nuevo estado (mostrando el documento recién registrado).

Este flujo se repite para todas las interacciones, como la compra de acciones (`buyShares` en `RWATokenSales.sol`) o el reclamo de dividendos (`claimDividend` en `DividendDistributor.sol`).