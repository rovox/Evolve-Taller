# 🎬 Guía de Demostración Visual - Evolve RWA

Esta guía te ayudará a presentar una demo impresionante del sistema de tokenización RWA en el rollup soberano Evolve.

## 📋 Preparación Pre-Demo

### 1. Verificar que todo esté limpio
```bash
cd /home/robvox/evolve/evolve-demo
tilt down
docker system prune -f
```

### 2. Iniciar el stack completo
```bash
tilt up
```

**Esperar a que todos los servicios estén verdes en Tilt** (http://localhost:10350)

Servicios críticos:
- ✅ `reth-node` - Ejecución de Ethereum
- ✅ `celestia-node` - Capa de disponibilidad de datos
- ✅ `rollkit-sequencer` - Secuenciador del rollup
- ✅ `deploy-rwa-contracts` - Contratos desplegados
- ✅ `rwa-integration-test` - Pruebas pasadas
- ✅ `frontend-dev` - Frontend corriendo

### 3. Abrir las ventanas de la demo
- 📊 **Tilt Dashboard**: http://localhost:10350
- 🎨 **Frontend**: http://localhost:5173
- 🔍 **Blockscout**: http://localhost
- 🖥️ **Terminal**: Mantener visible para logs en vivo

## 🎯 Flujo de Demostración (5-10 minutos)

### Paso 1: Mostrar el Dashboard de Tilt (30 segundos)
```
🗣️ "Aquí tenemos el stack completo corriendo:
   - Reth como cliente de ejecución
   - Celestia para disponibilidad de datos
   - Rollkit como secuenciador del rollup soberano
   - Los contratos RWA ya están desplegados y probados"
```

**Acción**: Señalar todos los servicios en verde en http://localhost:10350

---

### Paso 2: Abrir el Frontend (30 segundos)
```
🗣️ "Esta es la interfaz visual que muestra el estado del sistema en tiempo real"
```

**Acción**: Abrir http://localhost:5173

**Destacar**:
- ✅ Panel "System Status" con todos los contratos en verde
- ✅ Direcciones de los contratos desplegados
- ✅ Número de bloque actual incrementándose
- ✅ Conexión RPC activa

---

### Paso 3: Conectar Wallet (1 minuto)

#### Si MetaMask NO está configurado:
```
🗣️ "Vamos a conectar MetaMask a nuestro rollup local"
```

**Agregar red personalizada en MetaMask**:
- Network Name: `Evolve Rollup (Local)`
- RPC URL: `http://localhost:8545`
- Chain ID: `1234`
- Currency Symbol: `ETH`

#### Conectar
```
🗣️ "Ahora conectamos la wallet al sistema"
```

**Acción**: Click en "Conectar a Evolve Rollup" en el frontend

**Resultado esperado**: Toast de éxito "Wallet conectada exitosamente!"

---

### Paso 4: Ver Contratos en Blockscout (1 minuto)
```
🗣️ "Podemos verificar que los contratos están realmente desplegados en el explorador de bloques"
```

**Acción**: 
1. Click en botón "View" junto a "RWASovereignRollup" en el panel System Status
2. Se abre Blockscout en http://localhost
3. Mostrar:
   - Código del contrato verificado
   - Transacciones del despliegue
   - Estado actual

**Regresar al frontend**

---

### Paso 5: Registrar un Documento (2 minutos)
```
🗣️ "Ahora vamos a registrar un documento RWA en el registro inmutable"
```

**Acción**:
1. En la sección "Registro de Documentos", ingresar:
   ```
   Contenido: Título de propiedad - Casa Ejemplo 123
   ```
2. Click en "Registrar Documento"
3. Aprobar transacción en MetaMask
4. Esperar confirmación (toast verde)

**Destacar**:
- Hash del documento generado automáticamente
- Transacción enviada al rollup
- Bloque incrementa en el panel superior

**Ir a Blockscout**:
```
🗣️ "Podemos ver la transacción registrada en la blockchain"
```
- Buscar la dirección del `DocumentRegistry`
- Mostrar la transacción `registerDocument`
- Ver el hash del documento en los eventos

---

### Paso 6: Verificar Estado Final (1 minuto)
```
🗣️ "El sistema está funcionando de punta a punta:
   - Contratos desplegados en el rollup
   - Datos disponibles en Celestia
   - Explorador de bloques funcional
   - Interfaz de usuario conectada"
```

**Acción**: Volver al panel System Status y mostrar:
- Bloque actual (ha incrementado)
- Todos los sistemas operativos
- Tiempo total de la demo: ~5-10 minutos

---

## 🎬 Demo Rápida (2 minutos)

Si el tiempo es limitado, usa este flujo express:

1. **Abrir frontend** (15s)
   - Mostrar System Status todo verde
   - Destacar bloque incrementando

2. **Conectar wallet** (30s)
   - Click "Conectar"
   - Aprobar MetaMask

3. **Registrar documento** (45s)
   - Texto de ejemplo
   - Enviar transacción
   - Mostrar toast de éxito

4. **Ver en Blockscout** (30s)
   - Click "View" en RWA contract
   - Mostrar transacciones

---

## 🔧 Troubleshooting Durante la Demo

### MetaMask no conecta
```bash
# Verificar RPC
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Frontend muestra contratos no desplegados
```bash
# Re-sincronizar addresses
./sync-contract-addresses.sh
# Refrescar navegador (Ctrl+R)
```

### Blockscout no carga
```bash
# Verificar en Tilt dashboard que nginx esté corriendo
# O acceder directamente: http://localhost:4000
```

### Tilt se atascó en algún paso
```bash
# En Tilt dashboard, click en el recurso fallido
# Ver logs completos
# Si es necesario, restart ese recurso específico
```

---

## 💡 Puntos Clave para Enfatizar

1. **Rollup Soberano**: No depende de Ethereum L1, usa Celestia para DA
2. **Contratos Reales**: RWASovereignRollup, DocumentRegistry, AssetToken
3. **Sistema Completo**: Desde la UI hasta la DA layer
4. **Explorador Funcional**: Blockscout corriendo localmente
5. **Pruebas Pasadas**: Integration tests verifican todo el flujo

---

## 📸 Screenshots Sugeridos (para documentación)

1. Tilt Dashboard - Todos los servicios verdes
2. Frontend - System Status panel
3. Frontend - Wallet conectada
4. Frontend - Documento registrado (toast de éxito)
5. Blockscout - Contrato RWASovereignRollup
6. Blockscout - Transacción de registerDocument

---

## 🎤 Script de Elevator Pitch (30 segundos)

```
"Este es un rollup soberano completo para tokenización de activos del mundo real.
Usa Reth como cliente de ejecución, Celestia para disponibilidad de datos,
y Rollkit como secuenciador. Los contratos implementan registro inmutable de
documentos, tokenización ERC721, y gestión de activos. Todo desplegado localmente
con explorador de bloques y frontend funcional. Desde cero hasta transacciones
en menos de 5 minutos."
```

---

## ✅ Checklist Final

Antes de la demo, verifica:

- [ ] `tilt up` corriendo sin errores
- [ ] Todos los recursos verdes en Tilt dashboard
- [ ] Frontend accesible en http://localhost:5173
- [ ] Blockscout accesible en http://localhost
- [ ] MetaMask configurado con red Evolve Local
- [ ] Cuenta con fondos (la primera de la genesis tiene ETH)
- [ ] Navegador en pantalla completa o vista dividida profesional
- [ ] Terminal visible para mostrar "bajo el capó" si preguntan

---

**¡Buena suerte con tu demo! 🚀**
