# Gemini Code Assistant Context

Este documento proporciona un contexto técnico detallado para el Asistente de Código Gemini, describiendo la arquitectura, el flujo de funcionamiento y las posibles mejoras del proyecto de Rollup Soberano para Activos del Mundo Real (RWA).

## 1. Arquitectura Detallada

El proyecto implementa un stack completo para un rollup soberano que utiliza la Máquina Virtual de Ethereum (EVM). La arquitectura está diseñada para ser modular y desacoplada, utilizando servicios en contenedores orquestados por Tilt y Docker Compose.

### 1.1. Componentes Principales

1.  **Frontend:** Una aplicación de React (con Vite y TypeScript) que sirve como interfaz de usuario para interactuar con los contratos inteligentes del rollup.
2.  **Pila del Rollup (Backend):**
    *   **Capa de Ejecución:** **Reth** (`reth-node`), un cliente de ejecución de Ethereum de alto rendimiento.
    *   **Secuenciador:** **EV-Node** (`rollkit-sequencer`), un secuenciador personalizado del proyecto Evolve que ordena transacciones.
    *   **Capa de Disponibilidad de Datos (DA):** **Celestia** (`celestia-node`), donde se publican los lotes de transacciones del rollup.
3.  **Contratos Inteligentes:** Lógica de negocio en Solidity (RWAVault, DocumentRegistry) gestionada con el framework Foundry.
4.  **Orquestación:** **Tilt** y **Docker Compose** para automatizar el inicio, la configuración y la interconexión de todos los servicios.

### 1.2. Frontend (React + Vite)

-   **Ubicación:** `frontend/`
-   **Tecnologías:** React, TypeScript, Vite.
-   **Interacción con Blockchain:** Utiliza `wagmi` para la conexión de billeteras y `viem` para leer y escribir en los contratos inteligentes desplegados en el rollup.
-   **Componente Clave:** `RWAInterface.tsx` contiene toda la lógica de la UI para depositar fondos y registrar documentos.
-   **Configuración:** Las direcciones de los contratos se inyectan en tiempo de ejecución a través del script `sync-contract-addresses.sh`, que las lee desde el entorno de Foundry y las escribe en el archivo `.env` del frontend.

### 1.3. Backend (Pila del Rollup Soberano)

#### Orquestación (Tilt & Docker Compose)

-   **`Tiltfile`**: Es el cerebro de la orquestación. Define la secuencia de inicio de todos los servicios, gestiona las dependencias entre ellos y automatiza tareas como el despliegue de contratos y la configuración del frontend.
-   **`docker-compose.*.yml`**: Definen los servicios individuales (Reth, Celestia, EV-Node), sus imágenes de Docker, volúmenes y redes.
-   **Red:** Todos los contenedores se conectan a una red Docker compartida (`rollup-network`) para permitir la comunicación interna por nombre de servicio (ej. `http://reth-node:8545`).

#### Capa de Ejecución (Reth)

-   **Servicio:** `reth-node`
-   **Propósito:** Procesa las transacciones, ejecuta el código de los contratos inteligentes y mantiene el estado del rollup. Expone un endpoint RPC compatible con Ethereum (`http://localhost:8545`) que es utilizado por la billetera del usuario (MetaMask) y el secuenciador.
-   **Seguridad:** La comunicación entre Reth y el secuenciador está asegurada mediante un secreto JWT (`reth-jwt-secret.txt`) que se genera al iniciar el stack.

#### Secuenciador (EV-Node)

-   **Servicio:** `rollkit-sequencer`
-   **Imagen:** `ghcr.io/evstack/ev-node-evm-single:pr-2763`
-   **Propósito:** Es el corazón del rollup. Su función es:
    1.  Observar las transacciones enviadas al RPC de Reth.
    2.  Ordenarlas en bloques.
    3.  Agrupar los bloques en lotes.
    4.  Publicar estos lotes en la capa de disponibilidad de datos (Celestia).
-   **Configuración:** Se configura a través del archivo `rollkit.env`, generado dinámicamente por el script `rollup-init.sh`. Este archivo le indica al secuenciador cómo conectarse a Reth (RPC y JWT) y a Celestia (endpoint y token de autenticación).

#### Capa de Disponibilidad de Datos (Celestia)

-   **Servicio:** `celestia-node`
-   **Propósito:** Garantizar que los datos de las transacciones del rollup estén disponibles públicamente para que cualquiera pueda verificar el estado del rollup. El secuenciador paga tasas en Celestia para publicar los datos.

### 1.4. Contratos Inteligentes (Solidity & Foundry)

-   **Ubicación:** `rwa-soberano-evolve/`
-   **Framework:** Foundry.
-   **Contratos Principales:**
    -   `RWAVault.sol`: Un contrato para que los usuarios depositen activos (actualmente ETH).
    -   `DocumentRegistry.sol`: Permite registrar el hash de un documento, anclando su existencia en el rollup.
-   **Despliegue:** El script `script/DeployToRollup.s.sol` se ejecuta automáticamente por Tilt después de que el secuenciador está en línea. Despliega los contratos en el rollup a través del RPC de Reth.

## 2. Flujo de Funcionamiento

### 2.1. Inicio del Entorno (`tilt up`)

1.  **Red y Secretos:** Se crea la red `rollup-network` y se genera el secreto JWT para Reth.
2.  **Arranque de Servicios Base:** Se inician `reth-node` y `celestia-node`.
3.  **Configuración de Celestia:** El script `celestia-fund.sh` crea una billetera en el nodo de Celestia y obtiene un token de autenticación.
4.  **Inicialización del Rollup:** El contenedor `rollup-init` ejecuta `rollup-init.sh`. Este script espera a que Reth y Celestia estén listos, obtiene sus datos de conexión (URLs, hashes, tokens) y los escribe en el archivo `rollkit.env`.
5.  **Arranque del Secuenciador:** Con `rollkit.env` listo, el servicio `rollkit-sequencer` (EV-Node) arranca y se conecta a Reth y Celestia.
6.  **Despliegue de Contratos:** Tilt ejecuta el script de Foundry `DeployToRollup.s.sol`, que despliega los contratos en el rollup. Las direcciones resultantes se guardan en `deployed-addresses.env`.
7.  **Sincronización del Frontend:** El script `sync-contract-addresses.sh` copia las direcciones de los contratos al archivo `.env` del frontend.
8.  **Inicio del Frontend:** Se instalan las dependencias (`npm install`) y se inicia el servidor de desarrollo de Vite.

### 2.2. Flujo de una Transacción (Registrar un Documento)

1.  **Usuario:** El usuario escribe el contenido de un documento en el `textarea` del frontend y hace clic en "Registrar Documento".
2.  **Frontend (React):**
    *   El componente `RWAInterface.tsx` calcula el hash del contenido.
    *   Llama a la función `writeContractAsync` de `wagmi`, especificando la dirección del contrato `DocumentRegistry`, su ABI y la función `registerDocument` con el hash como argumento.
3.  **Billetera (MetaMask):** `wagmi` se comunica con MetaMask, que pide al usuario que firme la transacción.
4.  **Capa de Ejecución (Reth):** MetaMask envía la transacción firmada al RPC de Reth (`http://localhost:8545`). Reth la coloca en su "mempool".
5.  **Secuenciador (EV-Node):** El secuenciador detecta la transacción en el mempool de Reth, la incluye en un nuevo bloque del rollup y la ejecuta para actualizar el estado (el hash queda registrado en el contrato).
6.  **Capa de DA (Celestia):** Periódicamente, el secuenciador empaqueta los nuevos bloques en un lote y lo publica en la red de Celestia, pagando la tasa correspondiente. Esto garantiza la disponibilidad de los datos de la transacción.
7.  **Confirmación (Feedback al Usuario):** El frontend recibe el hash de la transacción y muestra una notificación de éxito. Opcionalmente, puede esperar la confirmación del bloque para asegurar la finalidad.

## 3. Trabajos Futuros y Mejoras

### 3.1. Funcionalidad y UX

-   **Reintegrar un Explorador de Bloques:** El proyecto carece de visibilidad on-chain. Reintegrar **Blockscout** o añadir otro explorador es una alta prioridad para poder inspeccionar bloques, transacciones y contratos.
-   **Mejorar la UI/UX del Frontend:**
    *   Utilizar una librería de componentes como **Material-UI** o **Chakra UI** para un diseño más profesional.
    *   Reemplazar los `setTimeout` por una espera real de la confirmación de la transacción (`waitForTransactionReceipt` en `viem`).
    *   Añadir más funcionalidades: visualizar los RWA tokenizados, ver el historial de registros, etc.
-   **Lógica de RWA más Sofisticada:** El `RWAVault` es muy simple. Se podría evolucionar para que acuñe un token ERC-20 o ERC-721 que represente la participación o la propiedad del activo.

### 3.2. Robustez y Seguridad

-   **Contratos Actualizables (Upgradable):** Implementar el patrón de proxy de OpenZeppelin (`openzeppelin-upgrades`) para permitir la actualización de la lógica de los contratos sin perder el estado ni cambiar las direcciones.
-   **Control de Acceso:** Añadir control de acceso a las funciones críticas de los contratos (ej. `Ownable` de OpenZeppelin) para que solo roles autorizados puedan ejecutar ciertas acciones.
-   **Auditoría de Seguridad:** Realizar una auditoría formal de los contratos inteligentes antes de considerar cualquier uso en producción.
-   **Hardening del Secuenciador:** Investigar y configurar medidas de protección para el secuenciador contra ataques de denegación de servicio (DoS) y spam de transacciones.

### 3.3. Pruebas y Calidad del Código

-   **Expandir Cobertura de Pruebas:**
    *   **Contratos:** Añadir más escenarios de prueba en Foundry, incluyendo pruebas de bifurcación (forking tests).
    *   **Frontend:** Implementar pruebas unitarias para los componentes de React con **Vitest** y **React Testing Library**.
    *   **Integración:** Crear pruebas de extremo a extremo (E2E) con herramientas como **Playwright** o **Cypress** que simulen el flujo completo del usuario.
-   **CI/CD (Integración Continua):** Configurar **GitHub Actions** para que ejecute automáticamente las pruebas (`forge test`, `npm test`) en cada `push` o `pull request` para asegurar que no se introducen regresiones.

### 3.4. Documentación

-   **Actualizar Documentación Pública:** Sincronizar `README.md`, `DEMO-GUIDE.md`, etc., para reflejar el estado actual del proyecto (ej. la eliminación de Blockscout).
-   **Documentación de Contratos (NatSpec):** Añadir comentarios de documentación en el formato NatSpec a todas las funciones y variables públicas de los contratos de Solidity para generar documentación automáticamente.