# Instrucciones Técnicas Detalladas para Agente VS Code
## Optimización Avanzada de Contratos Inteligentes RWAToken con Foundry

### 🎯 CONTEXTO DEL PROYECTO

**Stack Tecnológico:**
- Solidity ^0.8.28
- Foundry (forge, cast, anvil, chisel)
- OpenZeppelin Contracts v5.x
- ERC1155 Multi-Token Standard

**Problema Crítico:**
- RWAToken.sol = 32,941 bytes > límite EVM (24,576 bytes)
- Deployment bloqueado por tamaño excesivo de bytecode
- Necesidad urgente de modularización arquitectónica

**Objetivo Principal:**
Reducir bytecode de 32,941 → ~22,000 bytes mediante:
1. División modular del contrato monolítico
2. Implementación de librerías externas reutilizables
3. Optimización de patrones de código gas-intensive
4. Aplicación de mejores prácticas de seguridad (SafeERC20)

---

## 🚨 FASE 1: TAREAS CRÍTICAS (BLOQUEAN DEPLOYMENT)

### T1. MODULARIZACIÓN ARQUITECTÓNICA COMPLETA

**Crear estructura modular siguiendo principios de separación de concerns:**

```
src/
├── core/
│   ├── RWATokenCore.sol          # Asset management + core logic
│   ├── RWATokenMinting.sol       # Mint/burn centralized logic  
│   └── RWATokenQueries.sol       # View functions optimization
├── extensions/
│   ├── RWATokenSales.sol         # Public sales (buyShares)
│   └── RWATokenAdmin.sol         # Access control + emergency
├── libraries/
│   ├── RWAStorage.sol            # Shared structs
│   ├── RWAMath.sol               # Pure mathematical functions
│   └── RWAValidation.sol         # Input validation helpers
└── RWAToken.sol                  # Main facade contract
```

**T1.1: RWATokenCore.sol Implementation**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../libraries/RWAStorage.sol";
import "../libraries/RWAMath.sol";

abstract contract RWATokenCore is ERC1155, Ownable, AccessControl {
    using RWAMath for uint256;
    
    // State variables
    mapping(uint256 => RWAStorage.Asset) public assets;
    uint256 public assetCounter;
    
    // Events
    event AssetCreated(uint256 indexed assetId, string name, uint256 totalShares);
    
    // Optimized modifier implementation
    modifier assetExists(uint256 _assetId) {
        _checkAssetExists(_assetId);
        _;
    }
    
    modifier onlyAssetManager() {
        _checkAssetManager();
        _;
    }
    
    function _checkAssetManager() private view {
        require(
            hasRole(keccak256("ASSET_MANAGER_ROLE"), msg.sender) || owner() == msg.sender,
            "Must have asset manager role"
        );
    }
    
    function _checkAssetExists(uint256 _assetId) private view {
        require(_assetId < assetCounter, "Asset does not exist");
        require(assets[_assetId].active, "Asset is not active");
    }
    
    function createAsset(
        string memory _name,
        string memory _description, 
        string memory _assetType,
        uint256 _totalShares,
        uint256 _valueInUSD,
        string memory _ipfsMetadata
    ) public onlyAssetManager returns (uint256) {
        require(_totalShares > 0, "Total shares must be greater than 0");
        require(_valueInUSD > 0, "Value must be greater than 0");
        
        uint256 assetId = assetCounter;
        RWAStorage.Asset storage newAsset = assets[assetId];
        
        newAsset.assetId = assetId;
        newAsset.name = _name;
        newAsset.description = _description;
        newAsset.assetType = _assetType;
        newAsset.totalShares = _totalShares;
        newAsset.valueInUSD = _valueInUSD;
        newAsset.active = true;
        newAsset.ipfsMetadata = _ipfsMetadata;
        newAsset.createdAt = block.timestamp;
        
        assetCounter++;
        
        emit AssetCreated(assetId, _name, _totalShares);
        return assetId;
    }
}
```

**T1.2: RWATokenSales.sol Implementation**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../core/RWATokenCore.sol";

abstract contract RWATokenSales is RWATokenCore, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using RWAMath for uint256;
    
    event AssetSaleUpdated(uint256 indexed assetId, address paymentToken, uint256 pricePerShareWei, bool saleActive);
    
    function setAssetSale(
        uint256 _assetId,
        address _paymentToken, 
        uint256 _pricePerShareWei,
        bool _saleActive
    ) public onlyAssetManager assetExists(_assetId) {
        assets[_assetId].paymentToken = _paymentToken;
        assets[_assetId].pricePerShareWei = _pricePerShareWei;
        assets[_assetId].saleActive = _saleActive;
        emit AssetSaleUpdated(_assetId, _paymentToken, _pricePerShareWei, _saleActive);
    }
    
    function buyShares(uint256 _assetId, uint256 _shareAmount, bytes calldata _data) 
        external 
        payable 
        nonReentrant 
        assetExists(_assetId) 
    {
        require(assets[_assetId].saleActive, "Sale not active");
        require(_shareAmount > 0, "Invalid amount");
        
        (uint256 wholeShares, uint256 cost) = RWAMath.calculateCost(
            _shareAmount,
            assets[_assetId].pricePerShareWei
        );
        
        _processPurchase(_assetId, cost);
        _mintSharesInternal(msg.sender, _assetId, _shareAmount, _data);
    }
    
    function _processPurchase(uint256 _assetId, uint256 cost) private {
        address payToken = assets[_assetId].paymentToken;
        
        if (payToken == address(0)) {
            require(msg.value == cost, "Incorrect ETH sent");
        } else {
            require(msg.value == 0, "ETH not accepted");
            require(cost > 0, "Price not set");
            IERC20(payToken).safeTransferFrom(msg.sender, address(this), cost);
        }
    }
    
    // Abstract function implemented by main contract
    function _mintSharesInternal(address to, uint256 assetId, uint256 amount, bytes memory data) internal virtual;
}
```

**T1.3: RWATokenAdmin.sol Implementation**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "../core/RWATokenCore.sol";

abstract contract RWATokenAdmin is RWATokenCore, Pausable {
    
    event EmergencyStop(address indexed admin, string reason);
    event ContractResumed(address indexed admin);
    
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }
    
    function _checkAdmin() private view {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || owner() == msg.sender,
            "Must have admin role"
        );
    }
    
    function emergencyPause(string memory reason) external onlyAdmin {
        _pause();
        emit EmergencyStop(msg.sender, reason);
    }
    
    function resume() external onlyAdmin {
        _unpause(); 
        emit ContractResumed(msg.sender);
    }
    
    function grantAssetManagerRole(address account) external onlyAdmin {
        grantRole(keccak256("ASSET_MANAGER_ROLE"), account);
    }
    
    function revokeAssetManagerRole(address account) external onlyAdmin {
        revokeRole(keccak256("ASSET_MANAGER_ROLE"), account);
    }
}
```

### T2. IMPLEMENTACIÓN SAFEERC20 (CRÍTICO PARA SEGURIDAD)

**Problema:** Tokens como USDT no retornan boolean en transfer(), causando fondos bloqueados.

**Solución:**
```solidity
// En RWATokenSales.sol - REEMPLAZAR todas las transferencias:

// ❌ ANTES (inseguro - puede fallar silenciosamente)
IERC20(paymentToken).transferFrom(msg.sender, address(this), cost);

// ✅ DESPUÉS (seguro - maneja tokens no-compliant)
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;

IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), cost);
```

**Localizar y reemplazar en:**
- Función `buyShares()` 
- Función `withdrawPayments()`
- Cualquier interacción directa con ERC20 tokens

### T3. OPTIMIZACIÓN MODIFIER ONLYASSETMANAGER

**Problema:** Modifiers duplican código en cada función que los usa.

**Solución implementar patrón de función privada:**

```solidity
// ❌ ANTES (duplica ~100 bytes por cada función que lo usa)
modifier onlyAssetManager() {
    require(
        hasRole(ASSET_MANAGER_ROLE, msg.sender) || owner() == msg.sender,
        "Must have asset manager role"
    );
    _;
}

// ✅ DESPUÉS (reutiliza código - ahorra ~500 bytes total)
function _checkAssetManager() private view {
    require(
        hasRole(ASSET_MANAGER_ROLE, msg.sender) || owner() == msg.sender,
        "Must have asset manager role"
    );
}

modifier onlyAssetManager() {
    _checkAssetManager();
    _;
}
```

**Aplicar patrón también a:**
- `onlyAdmin()` modifier
- `assetExists()` modifier  
- Cualquier modifier usado en >3 funciones

---

## ⚡ FASE 2: ALTA PRIORIDAD (SEGURIDAD + PERFORMANCE)

### T4. LIBRERÍA RWASTORAGE.SOL

**Crear src/libraries/RWAStorage.sol:**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RWAStorage {
    struct Asset {
        uint256 assetId;
        string name;
        string description;
        string assetType;
        uint256 totalShares;
        uint256 valueInUSD;
        address[] shareholders;
        bool active;
        string ipfsMetadata;
        uint256 createdAt;
        address paymentToken;
        uint256 pricePerShareWei;
        bool saleActive;
    }

    struct ShareholderTransaction {
        address shareholder;
        uint256 assetId;
        uint256 amount;
        string transactionType;
        uint256 timestamp;
    }
    
    // Helper functions for struct manipulation
    function initializeAsset(Asset storage asset, uint256 id, string memory name) internal {
        asset.assetId = id;
        asset.name = name;
        asset.active = true;
        asset.createdAt = block.timestamp;
    }
}
```

### T5. LIBRERÍA RWAMATH.SOL  

**Crear src/libraries/RWAMath.sol:**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RWAMath {
    uint256 constant DECIMALS = 18;
    uint256 constant SHARES_MULTIPLIER = 10 ** DECIMALS;
    uint256 constant PERCENTAGE_BASE = 100;
    
    function calculateSharePercentage(
        uint256 balance,
        uint256 totalShares
    ) internal pure returns (uint256) {
        if (balance == 0) return 0;
        return (balance * PERCENTAGE_BASE) / (totalShares * SHARES_MULTIPLIER);
    }
    
    function calculateShareholderValue(
        uint256 balance,
        uint256 totalShares, 
        uint256 totalValue
    ) internal pure returns (uint256) {
        uint256 percentage = calculateSharePercentage(balance, totalShares);
        return (totalValue * percentage) / PERCENTAGE_BASE;
    }
    
    function calculateCost(
        uint256 shareAmount,
        uint256 pricePerShareWei
    ) internal pure returns (uint256 wholeShares, uint256 cost) {
        wholeShares = shareAmount / SHARES_MULTIPLIER;
        require(wholeShares > 0, "Amount too small");
        cost = wholeShares * pricePerShareWei;
    }
    
    // Add more math utilities as needed
    function percentageOf(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return (amount * percentage) / PERCENTAGE_BASE;
    }
}
```

### T6. CONSOLIDACIÓN FUNCIONES DUPLICADAS

**Problema:** `burnShares()` y `burn()` contienen lógica similar.

**Solución:**
```solidity
// Crear función interna compartida
function _burnInternal(
    address from,
    uint256 assetId,
    uint256 amount,
    bytes memory data
) internal {
    require(balanceOf(from, assetId) >= amount, "Insufficient balance");
    
    // Lógica de validación compartida
    require(assets[assetId].active, "Asset not active");
    
    // Actualizar shareholders si balance llega a 0
    uint256 newBalance = balanceOf(from, assetId) - amount;
    if (newBalance == 0) {
        _removeFromShareholders(assetId, from);
    }
    
    // Burn ERC1155
    _burn(from, assetId, amount);
    
    // Emitir evento
    emit SharesBurned(from, assetId, amount);
}

// Refactorizar funciones públicas
function burnShares(uint256 assetId, uint256 amount) public {
    _burnInternal(msg.sender, assetId, amount, "");
}

function burn(address from, uint256 assetId, uint256 amount, bytes memory data) public {
    require(msg.sender == from || isApprovedForAll(from, msg.sender), "Not authorized");
    _burnInternal(from, assetId, amount, data);
}
```

### T7. VALIDACIÓN ARRAYS VACÍOS

**Agregar a todas las funciones batch:**
```solidity
function mintBatch(
    address to,
    uint256[] memory ids, 
    uint256[] memory amounts,
    bytes memory data
) public onlyAssetManager {
    require(ids.length > 0, "Empty arrays");
    require(ids.length == amounts.length, "Array length mismatch");
    
    // Resto de la lógica...
    _mintBatch(to, ids, amounts, data);
}
```

---

## 🔧 FASE 3: LIMPIEZA Y MANTENIBILIDAD

### T8. LIMPIEZA ARTEFACTOS OBSOLETOS

```bash
# Ejecutar en directorio del proyecto
forge clean
rm -rf broadcast/*/31337/
find out/ -name "*.json" -mtime +30 -delete
git clean -fd  # Solo si tienes backup
```

### T9. CONSOLIDAR EVENTOS REDUNDANTES

**Problema:** `ShareholderAdded` se emite múltiples veces.

**Solución:**
```solidity
// Emitir solo en función de alto nivel, no en internas
function _mintSharesInternal(address to, uint256 assetId, uint256 amount, bytes memory data) internal {
    if (balanceOf(to, assetId) == 0) {
        assets[assetId].shareholders.push(to);
        // SOLO emitir aquí, no en _update()
        emit ShareholderAdded(to, assetId);
    }
    
    _mint(to, assetId, amount, data);
}
```

### T10. EXTRAER CONSTANTES MÁGICAS

```solidity
// Definir al inicio del contrato
uint256 private constant MAX_PERCENTAGE = 100;
uint256 private constant PRECISION = 1e18;
uint256 private constant MAX_SHAREHOLDERS_PER_ASSET = 1000;

// Usar en lugar de números mágicos
function calculatePercentage(uint256 shares, uint256 total) public pure returns (uint256) {
    return (shares * MAX_PERCENTAGE) / total;  // En lugar de: (shares * 100) / total
}
```

### T11. COMPLETAR DOCUMENTACIÓN NATSPEC

```solidity
/// @title RWA Tokenization Contract  
/// @notice Tokeniza Real World Assets usando ERC1155
/// @dev Implementa modularización para evitar límite de 24KB
contract RWAToken is RWATokenCore, RWATokenSales, RWATokenAdmin {

    /// @notice Crea un nuevo activo RWA tokenizado
    /// @param _name Nombre descriptivo del activo
    /// @param _totalShares Total de shares a emitir para este activo
    /// @param _valueInUSD Valor del activo en USD (sin decimales)
    /// @return assetId Identificador único del activo creado
    /// @dev Solo accounts con ASSET_MANAGER_ROLE pueden ejecutar
    function createAsset(
        string memory _name,
        uint256 _totalShares,
        uint256 _valueInUSD
    ) public onlyAssetManager returns (uint256 assetId) {
        // Implementation
    }
}
```

---

## 🧪 COMANDOS DE VALIDACIÓN FOUNDRY

### Verificación de Tamaño de Contrato
```bash
# Ver tamaños de todos los contratos
forge build --sizes

# Verificar específicamente RWAToken
forge build --sizes | grep -E "RWAToken"

# Generar reporte detallado 
forge build --sizes --format table > contract_sizes.txt
```

### Testing Comprehensivo  
```bash
# Ejecutar todos los tests con verbosidad
forge test -vvv

# Test con reporte de gas
forge test --gas-report

# Cobertura de código
forge coverage --report summary
forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage
```

### Deployment Local para Validación
```bash
# Iniciar nodo local
anvil

# Deploy con script optimizado  
forge script script/DeployModular.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

# Verificar deployment exitoso
cast call $DEPLOYED_ADDRESS "assetCounter()" --rpc-url http://localhost:8545
```

---

## 📊 CONFIGURACIÓN FOUNDRY OPTIMIZADA

**foundry.toml:**
```toml
[profile.default]
src = "src"
out = "out" 
libs = ["lib"]
solc_version = "0.8.28"

# Optimización para deployment
optimizer = true
optimizer_runs = 200  # Balance deployment vs runtime cost

# Para contratos grandes, usar runs=1 reduce bytecode
# optimizer_runs = 1  # Descomenta si aún excede límite

remappings = [
    '@openzeppelin/=lib/openzeppelin-contracts/',
    '@forge-std/=lib/forge-std/src/'
]

# Testing configuration  
fuzz_runs = 256
verbosity = 2

[profile.size-optimized]
optimizer = true
optimizer_runs = 1  # Minimiza deployment cost

[profile.production]
optimizer = true
optimizer_runs = 200
via_ir = false
```

---

## 🎯 MÉTRICAS DE ÉXITO Y VALIDACIÓN

### Targets Objetivos:
- **Tamaño final:** < 22,000 bytes (margen de seguridad: 2,576 bytes)
- **Reducción esperada:** ~10,941 bytes desde estado actual
- **Cobertura de tests:** > 90%
- **Optimización de gas:** 10-20% reducción en funciones críticas  
- **Seguridad:** 100% compatibilidad SafeERC20 con tokens non-standard

### Checklist Final:
- [ ] `forge build --sizes` confirma todos los contratos < 24KB
- [ ] `forge test` pasa al 100% sin errores
- [ ] `forge coverage` > 90% line coverage  
- [ ] Deployment local exitoso en anvil
- [ ] Tests de integración con tokens reales (USDT, USDC, etc.)
- [ ] Auditoría de seguridad básica completada
- [ ] Documentación NatSpec 100% completa

---

## 🚀 CONSIDERACIONES AVANZADAS

### Gas Optimization Patterns:
1. **Packed Structs:** Organizar variables por tamaño para ocupar menos slots de storage
2. **Batch Operations:** Procesar múltiples operaciones en una transacción
3. **Storage Layout:** Minimizar escrituras storage (SSTORE = 20,000 gas)
4. **Library Deployment:** Libraries se deployan una vez, contratos las referencian

### Security Best Practices:
1. **Reentrancy Guards:** Usar OpenZeppelin's ReentrancyGuard
2. **Access Control:** Principio de menor privilegio 
3. **Input Validation:** Validar todos los parámetros externos
4. **Error Handling:** Custom errors son más gas-eficientes que require strings

### Future Upgradability:
Si se requiere upgradabilidad futura, considerar:
- **Proxy Pattern:** Simple pero introduce complejidad de storage collisions
- **Diamond Pattern:** Más complejo pero permite módulos ilimitados
- **Immutable Deployment:** Más seguro, require redeploy para cambios

---

**NOTA IMPORTANTE:** Este plan está diseñado para ser ejecutado incrementalmente. Cada fase debe ser completada y validada antes de proceder a la siguiente. Mantener backups del código en cada fase crítica y usar control de versiones (git) para trackear cambios.