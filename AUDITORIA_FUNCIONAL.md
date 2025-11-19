# Auditoría Funcional del Contrato ROSCA y Frontend

**Fecha:** 2025-11-19
**Objetivo:** Verificar la correcta implementación y correspondencia funcional entre el contrato inteligente `ROSCA.sol` y la aplicación frontend.
**Disclaimer:** Esta no es una auditoría de seguridad. No se han evaluado vulnerabilidades, optimización de gas avanzada ni vectores de ataque.

---

## 1. Checklist de Funcionalidad Verificada

| Característica | Método de Prueba | Resultado | Notas |
| :--- | :--- | :--- | :--- |
| **Despliegue de Contrato** | `forge script` | ✅ **Pasa** | Desplegado con `DeployROSCA.s.sol`. |
| **Creación de Grupo** | `cast send` | ✅ **Pasa** | `createGroup` funciona, emite eventos `GroupCreated` y `MemberJoined`. |
| **Consulta de Grupo** | `cast call` | ✅ **Pasa** | `getGroupInfo` y `getGroupMembers` devuelven el estado correcto. |
| **Unión de Miembro** | `cast send` | ✅ **Pasa** | `joinGroup` funciona, requiere el pago correcto y actualiza el estado. |
| **Balance del Contrato** | `cast call` | ✅ **Pasa** | `getContractBalance` refleja correctamente los fondos recibidos. |
| **Conexión Frontend** | Manual | ✅ **Pasa** | El frontend lee la dirección del archivo `.rosca-address`. |

---

## 2. Resultados de Pruebas en Línea de Comandos (CLI)

A continuación se presentan los comandos ejecutados y los resultados que confirman la funcionalidad del contrato.

### A. Despliegue
- **Comando:** `forge script script/DeployROSCA.s.sol ...`
- **Resultado:** Contrato desplegado exitosamente en `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`.

### B. Creación de Grupo
- **Comando:** `cast send <address> "createGroup(...)"`
- **Resultado:** Transacción exitosa, grupo `0` creado.

### C. Verificación de Estado
- **Comando:** `cast call <address> "getGroupInfo(0)"`
- **Resultado:** Devolvió los datos correctos del "Grupo Test".
- **Comando:** `cast call <address> "getGroupMembers(0)"`
- **Resultado:** Devolvió un array con la única dirección del creador.

### D. Unión de un Segundo Miembro
- **Comando:** `cast send <address> "joinGroup(0)" --value 1ether ...`
- **Resultado:** Transacción exitosa.
- **Comando:** `cast call <address> "getGroupMembers(0)"`
- **Resultado:** Devolvió un array con las dos direcciones de los miembros.
- **Comando:** `cast call <address> "getContractBalance()"`
- **Resultado:** Devolvió `1 ether`, correspondiente al aporte del nuevo miembro.

---

## 3. Sugerencias de Mejora (Funcionalidad y UI/UX)

Estas sugerencias no requieren cambios en el contrato, solo en el frontend (`app.js`, `index.html`).

1.  **Añadir Indicadores de Carga (Spinners):**
    *   **Sugerencia:** Mientras se espera la confirmación de una transacción de MetaMask (ej. al crear un grupo o contribuir), la interfaz debería mostrar un indicador de "cargando" (spinner o similar) sobre el botón que se presionó.
    *   **Beneficio:** Mejora la experiencia de usuario (UX) al dar feedback visual de que algo está sucediendo en segundo plano y la aplicación no está congelada.

2.  **Manejo de Errores Amigable:**
    *   **Sugerencia:** Actualmente, si una transacción falla, el error solo se ve en la consola del navegador o en MetaMask. El código del frontend debería usar un bloque `try...catch` alrededor de las llamadas al contrato. Si ocurre un error, mostrar un mensaje claro y conciso al usuario en la UI (ej. "Error: Fondos insuficientes" o "La transacción fue rechazada").
    *   **Beneficio:** Hace la aplicación más robusta y menos confusa para usuarios no técnicos.

3.  **Deshabilitar Botones de Acciones no Disponibles:**
    *   **Sugerencia:** La interfaz debería ser proactiva y deshabilitar botones cuyas acciones no se pueden realizar. Por ejemplo:
        *   El botón "Contribuir" debería estar deshabilitado si el usuario ya contribuyó en el mes actual.
        *   El botón "Unirse al grupo" debería estar deshabilitado si el grupo ya está lleno.
    *   **Beneficio:** Evita que los usuarios envíen transacciones que están destinadas a fallar, ahorrándoles frustración y gas.

4.  **Refrescar Datos Automáticamente:**
    *   **Sugerencia:** La aplicación ya escucha algunos eventos, pero se podría mejorar. Después de que una acción del usuario es exitosa (ej. `contribute`), la UI debería volver a consultar automáticamente los datos relevantes del contrato (`getGroupInfo`, `getContractBalance`, etc.) y refrescar la pantalla.
    *   **Beneficio:** Asegura que la UI siempre refleje el estado más reciente de la blockchain sin que el usuario tenga que recargar la página.

---

## 4. Resumen de Estado y Pasos Pendientes

### A. Resumen del Trabajo Realizado
*   **Contratos:** Se verificaron y corrigieron los tests de Foundry (`forge test`). Se añadieron nuevas funciones de solo lectura (`view`) en `ROSCA.sol` para facilitar la integración con el frontend.
*   **Pruebas Funcionales:** Se realizó un ciclo de pruebas exitoso usando `cast` para desplegar el contrato, crear un grupo, unir un miembro y verificar el estado del contrato en una red local.
*   **Integración con Capa de DA (Celestia):**
    *   Se iniciaron los stacks `da-celestia` y `single-sequencer` usando `make start`.
    *   Se diagnosticó y resolvió un conflicto de puertos (`8545`) entre `anvil` y `ev-reth-sequencer`.
    *   Se diagnosticó y resolvió la falta de exposición del puerto RPC (`7331`) del `single-sequencer` para permitir su investigación.
    *   **Se descubrió el bloqueante principal actual:** El secuenciador no puede publicar datos en Celestia.

### B. Resultados y Estado Actual

*   **Lo que funciona ✅:**
    *   **Contrato `ROSCA.sol`:** Es funcionalmente correcto y está listo para ser usado.
    *   **Stack de Servicios:** Los contenedores de `da-celestia` y `single-sequencer` se inician y se ejecutan correctamente.
    *   **Conectividad EVM:** El frontend puede conectarse al nodo EVM en `http://localhost:8545` para enviar transacciones.

*   **Lo que NO funciona ❌:**
    *   **Publicación en Celestia:** El `single-sequencer` falla continuamente al intentar publicar datos en Celestia debido a que su wallet no tiene fondos (`TIA` de prueba) en la red Mocha.
        *   **Consulta para verificar el error:** `docker logs single-sequencer | grep "insufficient funds"`

### C. Pasos Pendientes para Completar la Implementación

1.  **(BLOQUEANTE) Financiar la Wallet del Secuenciador:**
    *   **Acción:** El usuario debe seguir los pasos previamente indicados: encontrar la dirección `celestia1...` del secuenciador y usar un faucet de la testnet Mocha para enviarle fondos.
    *   **Comando para encontrar la dirección:** `docker logs single-sequencer | grep "signer address"`
    *   **Comando para reiniciar después de financiar:** `make stop && make start`

2.  **Investigar la API de Visualización de DA:**
    *   **Acción:** Una vez que el secuenciador tenga fondos y publique datos con éxito, se debe reanudar la investigación de la API del puerto `7331` para encontrar el método RPC que vincula el bloque EVM con la publicación en Celestia.
    *   **Consulta para verificar el éxito:** `docker logs single-sequencer` (buscar mensajes de éxito en la publicación).

3.  **Implementar la Trazabilidad en el Frontend:**
    *   **Acción:** Añadir la lógica de proxy al servidor del frontend para comunicarse con la API del secuenciador.
    *   **Acción:** Construir la sección en la UI que muestre el estado de la transacción (Pendiente -> Publicado) con un enlace al explorador de Celestia (`mocha.celenium.io`).

4.  **Implementar Mejoras Generales del Frontend:**
    *   **Acción:** Aplicar las sugerencias documentadas en la sección 3 de esta auditoría (indicadores de carga, manejo de errores y deshabilitación de botones).