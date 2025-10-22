# Propuestas de Mejora para la Automatización y Pruebas

Este documento detalla una serie de mejoras propuestas para el proyecto `Evolve-Taller`, con el objetivo de crear un flujo de trabajo de desarrollo, pruebas e integración totalmente automatizado y centralizado en `Tilt`.

## 1. Visión General de la Arquitectura Propuesta

La meta es extender el `Tiltfile` actual para que no solo levante el entorno, sino que actúe como un orquestador completo del ciclo de vida del desarrollo, abarcando desde la validación estática hasta las pruebas End-to-End (E2E) que simulan la interacción real del usuario.

El flujo automatizado propuesto sería el siguiente:

1.  **Inicio del Entorno Core:** `Tilt` levanta la infraestructura base (Reth, Celestia, Rollkit).
2.  **Compilación y Pruebas de Contratos:**
    *   Se compilan los contratos de Solidity.
    *   Se ejecutan las pruebas unitarias de Foundry.
    *   Se genera un snapshot del uso de gas para monitorear la eficiencia.
3.  **Despliegue y Sincronización:**
    *   Los contratos se despliegan en el rollup local.
    *   Las direcciones de los contratos desplegados se sincronizan automáticamente con el frontend.
4.  **Pruebas de Integración del Backend:**
    *   Se ejecuta un script de integración que verifica la comunicación entre los contratos y el rollup.
5.  **Validación y Pruebas del Frontend:**
    *   Se instalan las dependencias del frontend.
    *   Se ejecutan las pruebas unitarias y de componentes del frontend (usando Vitest/React Testing Library).
6.  **Pruebas End-to-End (E2E):**
    *   Se levanta el frontend en modo de producción.
    *   Un framework como Playwright o Cypress ejecuta pruebas E2E que interactúan con la UI del frontend, realizan transacciones a través de MetaMask y verifican que los resultados se reflejen correctamente en la blockchain.
7.  **Generación de Documentación:**
    *   Se genera automáticamente la documentación técnica de los contratos de Solidity.

## 2. Mejoras Detalladas

### 2.1. Integración de Pruebas de Frontend

*   **Problema:** El flujo actual no valida automáticamente el frontend.
*   **Solución:** Añadir un `local_resource` en el `Tiltfile` para ejecutar las pruebas del frontend.
*   **Implementación:**
    *   Crear un script `scripts/run-frontend-tests.sh`.
    *   Este script ejecutará `npm test` (o `yarn test`) dentro del directorio `frontend`.
    *   Añadir un `local_resource` en el `Tiltfile` que dependa del `sync-frontend-addresses` y ejecute este nuevo script.

### 2.2. Pruebas End-to-End (E2E) con Playwright

*   **Problema:** No existen pruebas que validen el sistema completo desde la perspectiva del usuario.
*   **Solución:** Implementar un conjunto de pruebas E2E con Playwright. Playwright es ideal porque tiene un excelente soporte para extensiones de navegador como MetaMask.
*   **Implementación:**
    1.  **Configurar Playwright:** Añadir Playwright al proyecto, probablemente en un nuevo directorio `e2e-tests`.
    2.  **Automatizar MetaMask:** Crear un script para descargar y configurar una instancia de MetaMask dentro de Playwright, importando las cuentas de prueba.
    3.  **Escribir Casos de Prueba:**
        *   **Conexión de Wallet:** Verificar que el frontend se conecta correctamente a MetaMask.
        *   **Registro de Documento:** Simular la subida y registro de un documento a través de la UI.
        *   **Tokenización de Activo:** Realizar una tokenización de un activo y verificar que los tokens ERC-1155 se emiten correctamente.
        *   **Distribución de Dividendos:** Iniciar una distribución de dividendos y verificar que un tenedor de tokens puede reclamarlos.
    4.  **Integrar en Tilt:** Añadir un `local_resource` final en el `Tiltfile` que ejecute las pruebas de Playwright. Este recurso dependerá de que el frontend y todos los servicios del backend estén listos.

### 2.3. Monitoreo de Gas y Rendimiento

*   **Problema:** No hay un seguimiento del coste de gas de las operaciones de los contratos.
*   **Solución:** Utilizar `forge snapshot` para generar un informe de uso de gas.
*   **Implementación:**
    *   Modificar el script `scripts/run-contract-tests.sh` para que, además de ejecutar los tests, corra `forge snapshot --check`.
    *   El flag `--check` hará que el paso falle si el uso de gas ha cambiado, alertando sobre cambios inesperados en la eficiencia.

### 2.4. Generación Automatizada de Documentación

*   **Problema:** La documentación técnica de los contratos no se genera automáticamente.
*   **Solución:** Usar `solidity-docgen` para generar documentación en formato Markdown a partir de los comentarios NatSpec del código.
*   **Implementación:**
    *   Añadir `solidity-docgen` como una dependencia de desarrollo.
    *   Crear un script `scripts/generate-docs.sh` que ejecute `solidity-docgen`.
    *   Añadir un `local_resource` en el `Tiltfile` (posiblemente manual o que se ejecute después de los tests) para generar la documentación.

### 2.5. Centralización de Scripts y Configuración

*   **Problema:** Múltiples scripts de shell dispersos.
*   **Solución:** Unificar la lógica en scripts más robustos y parametrizables, posiblemente usando JavaScript/TypeScript con `execa` para una mejor gestión de subprocesos.
*   **Implementación:**
    *   Crear un directorio `orchestration` o similar.
    *   Desarrollar un script principal (e.g., `main.ts`) que actúe como punto de entrada para todas las tareas de automatización (test, deploy, etc.).
    *   Refactorizar los scripts de shell existentes a funciones dentro de este nuevo sistema. El `Tiltfile` solo llamaría a este script con diferentes argumentos.

## 3. Pasos a Seguir

1.  **Implementar Pruebas de Frontend:**
    *   Crear `scripts/run-frontend-tests.sh`.
    *   Añadir el `local_resource` correspondiente en el `Tiltfile`.
2.  **Configurar Playwright para Pruebas E2E:**
    *   Añadir el directorio `e2e-tests` con la configuración de Playwright.
    *   Crear los primeros casos de prueba E2E.
    *   Integrar la ejecución de estas pruebas en el `Tiltfile`.
3.  **Integrar Monitoreo de Gas:**
    *   Actualizar `scripts/run-contract-tests.sh` para incluir `forge snapshot`.
4.  **Refactorizar y Centralizar Scripts:**
    *   Iniciar el refactor de los scripts de `scripts/` a un sistema de orquestación más avanzado.
5.  **Generar Documentación:**
    *   Configurar `solidity-docgen` y añadir el script de generación de documentación.

Este plan proporciona una hoja de ruta clara para transformar tu entorno de desarrollo en una plataforma de integración continua local, aumentando la confianza en cada cambio y mejorando la productividad del desarrollador.
