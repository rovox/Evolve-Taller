# Guía Detallada de Celestia y Desarrollo de DApps en el Stack

Este documento explica en profundidad la interacción con Celestia en este proyecto, cómo se gestiona la seguridad y las wallets, y proporciona una guía práctica para que un desarrollador pueda construir una DApp sobre esta infraestructura.

## 1. Conexión y Seguridad de Celestia en el Proyecto

En esta arquitectura, el **secuenciador (Rollkit)** es el único componente que necesita interactuar directamente con Celestia. Los usuarios finales de una DApp nunca interactúan con Celestia; solo interactúan con el rollup (la capa EVM).

### Conexión RPC y Generación de Token JWT

*   **Conexión RPC:** Rollkit se conecta al nodo de Celestia a través de su endpoint RPC, que en este setup es `http://celestia-node:26658`. Esta URL está definida en el archivo `rollkit.env` que se genera dinámicamente.

*   **Generación del Token JWT:** La comunicación con el RPC de Celestia está protegida. Para autenticarse, Rollkit necesita un JSON Web Token (JWT). Este token se genera de la siguiente manera:
    1.  El proceso lo inicia el `Tiltfile` al ejecutar el script `celestia-fund.sh` dentro del contenedor de Celestia.
    2.  Dentro del script, el comando clave es:
        ```bash
        celestia light auth admin --node.store /home/celestia
        ```
    3.  Este comando instruye al nodo de Celestia a generar un token de administrador (`admin`). Este token otorga permisos para realizar acciones en el nodo, como consultar la wallet y enviar transacciones (en este caso, para publicar los blobs de datos).
    4.  El token generado se guarda en el volumen compartido (`/shared/jwt/celestia-jwt.token`) para que el contenedor de Rollkit pueda leerlo y usarlo para autenticar sus peticiones.

### Generación de Wallets y Fondos

*   **Wallet del Secuenciador:** El nodo de Celestia tiene su propia wallet interna para pagar las tarifas de transacción en la red de Celestia (Mocha testnet). El script `celestia-fund.sh` obtiene la dirección de esta wallet (`celestia...`) usando una llamada RPC (`state.AccountAddress`).
*   **Obtención de Fondos:** Una vez que tiene la dirección, el script comprueba el saldo en la testnet Mocha. Si el saldo es insuficiente, utiliza un faucet público (`https://faucet.celestia-mocha.com`) para solicitar TIA de prueba. **Esto es crucial:** el secuenciador necesita tener TIA en su wallet para poder pagar por la publicación de los blobs de datos en Celestia.

--- 

## 2. Guía Práctica: Desplegar una DApp ERC20 en este Entorno

Imaginemos que un desarrollador quiere desplegar un contrato ERC20 y crear una DApp simple. Aquí están los pasos que seguiría:

1.  **Escribir el Smart Contract:**
    *   Crear un contrato estándar de ERC20 en **Solidity**. Por ejemplo, `MyToken.sol`.

2.  **Configurar el Entorno de Despliegue:**
    *   Utilizar una herramienta de desarrollo de Ethereum como **Foundry** o **Hardhat**.
    *   Configurar la herramienta para que se conecte al RPC del rollup. El endpoint es el de Reth, que está expuesto en `http://localhost:8545`.
    *   En la configuración de la herramienta (ej. `foundry.toml` o `hardhat.config.js`), se debe especificar la URL del RPC y una clave privada para el despliegue. Esta clave privada debe corresponder a una cuenta de la EVM (formato `0x...`), no de Celestia.

3.  **Desplegar el Contrato:**
    *   Ejecutar el comando de despliegue (ej. `forge create` o `npx hardhat run --network local_rollup scripts/deploy.js`).
    *   La herramienta enviará la transacción de despliegue al RPC de Reth (`:8545`).
    *   Reth pasará la transacción a Rollkit. Rollkit la ejecutará, la incluirá en un bloque y publicará los datos de la transacción en Celestia.
    *   La herramienta recibirá la dirección del contrato desplegado en el rollup.

4.  **Crear la Interfaz de la DApp (Frontend):**
    *   Desarrollar una aplicación web simple (ej. con React, Vue).
    *   Usar una librería como `ethers.js` o `viem` para interactuar con la blockchain.
    *   Configurar la librería para que se conecte al RPC del rollup (`http://localhost:8545`).
    *   La DApp podrá leer datos del contrato ERC20 (saldos, nombre, etc.) y enviar transacciones (transferencias) a través de la wallet del usuario (ej. MetaMask).

5.  **Verificar las Transacciones:**
    *   El desarrollador puede usar el explorador **Blockscout** que corre en `http://localhost:80` para ver el despliegue del contrato, las transferencias y los bloques del rollup, todo en una interfaz amigable.

--- 

## 3. La Cuestión de las Wallets: ¿Keplr, MetaMask o Ambas?

Esta es la clave para entender la arquitectura modular. **Se necesitan dos tipos de wallets, pero para dos actores diferentes:**

1.  **Wallet de Celestia (ej. Keplr):**
    *   **¿Quién la usa?:** **El operador del secuenciador.** En este proyecto, es el propio sistema automatizado (`celestia-fund.sh`).
    *   **¿Para qué?:** Para gestionar los fondos (TIA) necesarios para pagar las tarifas de disponibilidad de datos en la red de Celestia. El secuenciador usa estos fondos cada vez que publica un lote de transacciones (un blob).
    *   **¿La necesita el usuario final de la DApp?:** **No.** El usuario final no tiene idea de que Celestia existe. Su experiencia es puramente EVM.

2.  **Wallet de EVM (ej. MetaMask):**
    *   **¿Quién la usa?:** **El usuario final de la DApp y el desarrollador.**
    *   **¿Para qué?:** Para interactuar con el rollup. El desarrollador la usa para desplegar contratos. El usuario final la usa para firmar transacciones en la DApp (ej. transferir tokens ERC20, interactuar con un protocolo DeFi, etc.). Esta wallet gestiona las claves y los fondos (ETH de prueba del rollup) en la capa de ejecución.

**En resumen:** El desarrollador y el usuario usan MetaMask para interactuar con el rollup. El sistema del rollup (el secuenciador) usa una wallet de Celestia por debajo para publicar los datos. Son dos dominios completamente separados.

--- 

## 4. Interactuando con los Contenedores Docker

Para depurar o inspeccionar el estado de cada componente, puedes acceder a los contenedores directamente:

*   **Comando base:** `docker exec -it <nombre_del_contenedor> /bin/sh` (o `/bin/bash`)

*   **Acceder a Reth:**
    ```bash
    docker exec -it reth-dev /bin/sh
    ```
    *Útil para ver los logs de Reth o interactuar con su base de datos.*

*   **Acceder a Celestia:**
    ```bash
    docker exec -it celestia /bin/sh
    ```
    *Útil para usar el CLI de Celestia, comprobar el saldo de la wallet o regenerar tokens JWT manualmente.*

*   **Acceder a Rollkit:**
    ```bash
    docker exec -it rollkit-evm-single /bin/sh
    ```
    *Útil para ver los logs del secuenciador y cómo se está comunicando con Reth y Celestia.*

**¿Por qué se usan contenedores?** Porque encapsulan cada servicio con sus dependencias, garantizando que el entorno sea idéntico y reproducible en cualquier máquina. Esto elimina los problemas de "en mi máquina funciona" y simplifica enormemente la gestión de una arquitectura tan compleja.

--- 

## 5. Simplificación y el Rol del Secuenciador

Tu idea de "conectar una wallet que se conecte con la testnet de mocha y mande blobs" es muy perspicaz y toca un punto fundamental.

Si bien un usuario *podría* técnicamente enviar datos a Celestia como un blob, eso **no es un rollup**. Un rollup no es solo un lugar para tirar datos; es un sistema que crea un **estado compartido y ordenado**. El rol del secuenciador (Rollkit) es precisamente ese:

1.  **Recibir transacciones** de muchos usuarios.
2.  **Establecer un orden canónico** para esas transacciones.
3.  **Ejecutarlas** para calcular un nuevo estado (el resultado de todas las operaciones).
4.  **Publicar el lote ordenado de transacciones** en Celestia como un blob.

Sin el secuenciador, no habría una única "verdad" sobre el orden de las transacciones o el estado del rollup. El código de este proyecto (Rollkit, scripts, etc.) existe para gestionar esa lógica compleja de secuenciación y publicación. La configuración reduce la cantidad de código que *tú* tienes que escribir, ya que te abstrae de tener que construir un secuenciador desde cero.

--- 

## 6. Pasos para un Proyecto de Real World Assets (RWA)

Un proyecto de RWA es más complejo porque une el mundo on-chain con el mundo legal y físico off-chain. Un rollup soberano como el de este proyecto es una excelente opción tecnológica por su flexibilidad y bajos costos.

**Alternativas Tecnológicas:**
*   **L2 Públicos (Arbitrum, Optimism):** Mayor seguridad derivada de Ethereum, pero menos personalizables.
*   **Appchains (Cosmos SDK):** Total soberanía, pero requiere construir más componentes de la pila.
*   **Rollup Soberano (este stack):** Un buen equilibrio. Soberanía, personalización y reutilización de la EVM como capa de ejecución.

**Pasos a Seguir:**

1.  **Marco Legal y Estructura Off-Chain:** Es el paso más importante. Define el activo real (ej. un inmueble, una factura), crea la entidad legal (ej. un SPV) que lo posee y establece los contratos legales que vinculan el activo al token.
2.  **Diseño del Token On-Chain:**
    *   Elige un estándar de token. Un ERC20 es simple, pero para RWA, un estándar como **ERC-3643 (T-REX)** es más adecuado, ya que incluye soporte para identidad, listas blancas y reglas de cumplimiento normativo.
3.  **Desarrollo de Smart Contracts:**
    *   **Contrato del Token:** Implementa el estándar elegido.
    *   **Contrato de Identidad:** Un registro on-chain que asocia direcciones de wallet con identidades verificadas (KYC/AML).
    *   **Contrato de Reglas (Compliance):** Define quién puede poseer el token y bajo qué condiciones (ej. solo inversores acreditados de ciertos países).
4.  **Infraestructura de Oráculos:** Necesitarás oráculos para traer datos del mundo real a la blockchain, como la valoración actualizada del activo, y para reflejar eventos off-chain (como el pago de un alquiler) en el estado on-chain.
5.  **Despliegue y Plataforma:** Despliega los contratos en tu rollup soberano. La ventaja aquí es que puedes controlar las tarifas de gas y el rendimiento de la red.
6.  **Plataforma para Inversores (DApp):** Una interfaz web donde los usuarios verificados pueden ver los activos, comprar/vender tokens y gestionar su cartera, interactuando con los smart contracts a través de sus wallets (ej. MetaMask).