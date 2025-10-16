# Análisis Detallado de la Configuración de Evolve (Rollkit)

Este documento profundiza en el proceso de configuración y arranque del secuenciador Evolve (Rollkit) dentro de este proyecto. El secuenciador es el componente `rollkit-sequencer` definido en `docker-compose.evolve.yml`.

## 1. Flujo de Configuración Dinámica

La configuración de Rollkit no es estática; se construye dinámicamente durante el proceso de arranque orquestado por Tilt. Este flujo asegura que el secuenciador tenga toda la información correcta para conectarse con los otros servicios (Reth y Celestia), que también se inician simultáneamente.

El proceso se divide en dos fases principales, gestionadas por dos scripts diferentes:

1.  **Fase de Creación de Configuración (`rollup-init.sh`)**
2.  **Fase de Arranque del Secuenciador (`rollkit-start.sh`)**

--- 

## 2. Fase 1: Creación de Configuración (`rollup-init.sh`)

Este script se ejecuta en un contenedor temporal (`rollup-init`) y su única misión es **crear el archivo de configuración `rollkit.env`**. Este archivo se guarda en un volumen Docker compartido (`jwt-tokens`) para que el contenedor del secuenciador pueda acceder a él más tarde.

Pasos que realiza el script:

1.  **Espera a los Servicios Dependientes:** Primero, se asegura de que Reth y Celestia estén completamente operativos enviando peticiones `curl` a sus respectivos endpoints de RPC.

2.  **Obtiene el Genesis Hash de Reth:** Ejecuta una llamada RPC a Reth (`eth_getBlockByNumber` para el bloque `0x0`) para obtener el hash del bloque génesis. Este hash es un identificador único de la cadena y es fundamental para que Rollkit sepa a qué estado inicial conectarse.

3.  **Obtiene los Secretos de Autenticación (JWT):**
    *   Lee el secreto JWT de Reth desde `/shared/reth-jwt-secret.txt`.
    *   Espera y lee el token JWT de Celestia desde `/shared/celestia-jwt.token`.
    Estos tokens son necesarios para que Rollkit pueda autenticarse contra las APIs seguras de Reth (Engine API) y Celestia.

4.  **Genera el Archivo `rollkit.env`:** Finalmente, escribe todos los valores recolectados en el archivo `/shared/rollkit.env`. El contenido de este archivo es la configuración final que usará el secuenciador:

    ```bash
    EVM_ENGINE_URL=http://reth-node:8551
    EVM_ETH_URL=http://reth-node:8545
    EVM_JWT_SECRET=...
    EVM_GENESIS_HASH=...
    EVM_BLOCK_TIME=1s
    EVM_SIGNER_PASSPHRASE=secret
    DA_ADDRESS=http://celestia-node:26658
    DA_AUTH_TOKEN=...
    DA_NAMESPACE=00000000000000000000000000000000000000000000000000deadbee
    ```

--- 

## 3. Fase 2: Arranque del Secuenciador (`rollkit-start.sh`)

Este script es el `entrypoint` (punto de entrada) del contenedor `rollkit-sequencer`. Su responsabilidad es leer la configuración creada en la fase anterior y usarla para iniciar el proceso del secuenciador (`evm-single`).

Pasos que realiza el script:

1.  **Espera y Carga la Configuración:** El script espera hasta que el archivo `/shared/rollkit.env` exista. Una vez que lo encuentra, lo carga en el entorno del shell con el comando `source`.

2.  **Exporta las Variables:** Exporta todas las variables cargadas para que sean accesibles por el proceso hijo (el binario `evm-single`).

3.  **Construye los Argumentos de Línea de Comandos:** El script convierte las variables de entorno en flags o argumentos para el comando `evm-single start`. Por ejemplo, la variable de entorno `$DA_ADDRESS` se convierte en el flag `--rollkit.da.address $DA_ADDRESS`.

4.  **Ejecuta el Secuenciador:** Finalmente, ejecuta el binario `evm-single start` con todos los flags de configuración. A continuación se detallan los parámetros más importantes:

    *   `--evm.engine-url $EVM_ENGINE_URL`
        *   **Descripción:** La URL de la Engine API de Reth. Es la conexión principal para ejecutar transacciones y bloques.
        *   **Valor:** `http://reth-node:8551`

    *   `--evm.jwt-secret $EVM_JWT_SECRET`
        *   **Descripción:** El secreto compartido para autenticar la conexión con la Engine API de Reth.

    *   `--evm.genesis-hash $EVM_GENESIS_HASH`
        *   **Descripción:** El hash del bloque génesis de la cadena de Reth. Asegura que Rollkit y Reth estén sincronizados desde el principio.

    *   `--rollkit.da.address $DA_ADDRESS`
        *   **Descripción:** La URL del nodo de Celestia al que se publicarán los blobs de datos.
        *   **Valor:** `http://celestia-node:26658`

    *   `--rollkit.da.auth_token $DA_AUTH_TOKEN`
        *   **Descripción:** El token para autenticarse con el nodo de Celestia.

    *   `--rollkit.da.namespace $DA_NAMESPACE`
        *   **Descripción:** Un identificador único para los datos de este rollup en Celestia. Permite que diferentes rollups compartan la misma capa de DA sin conflictos.

    *   `--rollkit.node.block_time $EVM_BLOCK_TIME`
        *   **Descripción:** El intervalo de tiempo para la producción de bloques. 
        *   **Valor:** `1s` (un bloque por segundo).

    *   `--rollkit.rpc.address=0.0.0.0:7331`
        *   **Descripción:** Expone el propio RPC del secuenciador para que los usuarios y herramientas puedan interactuar con él (aunque en este setup, las transacciones se envían directamente a Reth).

En resumen, la configuración de Evolve/Rollkit es un proceso dinámico y robusto que desacopla la definición de los servicios de su configuración en tiempo de ejecución, permitiendo que el stack se auto-configure al arrancar.