// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RWAToken
 * @dev Token ERC1155 para tokenización de activos del mundo real (RWA)
 * Permite crear, mintear, quemar y gestionar participaciones en activos reales
 */
contract RWAToken is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    ERC1155URIStorage,
    Ownable,
    AccessControl,
    Pausable,
    ReentrancyGuard
{
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ASSET_MANAGER_ROLE =
        keccak256("ASSET_MANAGER_ROLE");

    // Estructura para almacenar información del activo
    struct Asset {
        uint256 assetId;
        string name;
        string description;
        string assetType; // "Departamento", "Obra de Arte", "Auto", etc.
        uint256 totalShares; // expressed in whole shares (not 1e18)
        uint256 valueInUSD;
        address[] shareholders;
        bool active;
        string ipfsMetadata; // Hash IPFS con documentos legales
        uint256 createdAt;
        // Venta/mint público opcional
        address paymentToken; // address(0) for native
        uint256 pricePerShareWei; // price per 1 whole share (not 1e18). For ERC20, decimals depend on token
        bool saleActive;
    }

    // Estructura para transacciones de accionistas
    struct ShareholderTransaction {
        address shareholder;
        uint256 assetId;
        uint256 amount;
        string transactionType; // "mint", "burn", "transfer"
        uint256 timestamp;
    }

    // Variables de estado
    mapping(uint256 => Asset) public assets;
    mapping(uint256 => ShareholderTransaction[]) public assetTransactionHistory;
    mapping(address => mapping(uint256 => bool)) public isShareholder;
    
    uint256 public assetCounter;
    uint256 public constant DECIMALS = 18;
    uint256 public constant SHARES_MULTIPLIER = 10 ** DECIMALS;

    // Eventos
    event AssetCreated(
        uint256 indexed assetId,
        string name,
        string assetType,
        uint256 totalShares,
        uint256 valueInUSD
    );

    event AssetUpdated(uint256 indexed assetId, string newDescription);

    event SharesMinted(
        uint256 indexed assetId,
        address indexed to,
        uint256 amount,
        uint256 percentage
    );

    event SharesBurned(
        uint256 indexed assetId,
        address indexed from,
        uint256 amount
    );

    event ShareholderAdded(
        uint256 indexed assetId,
        address indexed shareholder,
        uint256 percentage
    );

    event ShareholderRemoved(
        uint256 indexed assetId,
        address indexed shareholder
    );

    event TransactionRecorded(
        uint256 indexed assetId,
        address indexed shareholder,
        string transactionType,
        uint256 amount
    );

    event AssetSaleUpdated(
        uint256 indexed assetId,
        address paymentToken,
        uint256 pricePerShareWei,
        bool saleActive
    );

    // Modificadores
    modifier assetExists(uint256 _assetId) {
        require(_assetId < assetCounter, "Asset does not exist");
        require(assets[_assetId].active, "Asset is not active");
        _;
    }

    modifier onlyAssetManager() {
        require(
            hasRole(ASSET_MANAGER_ROLE, msg.sender) || owner() == msg.sender,
            "Must have asset manager role"
        );
        _;
    }

    constructor(string memory _uri) ERC1155(_uri) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ASSET_MANAGER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        assetCounter = 0;
    }

    // ==================== Funciones de Activos ====================

    /**
     * @dev Crear un nuevo activo tokenizado
     * @param _name Nombre del activo
     * @param _description Descripción del activo
     * @param _assetType Tipo de activo (Departamento, Arte, Auto, etc.)
     * @param _totalShares Número total de acciones
     * @param _valueInUSD Valor del activo en USD
     * @param _ipfsMetadata Hash IPFS con documentos
     */
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
        Asset storage newAsset = assets[assetId];

        newAsset.assetId = assetId;
        newAsset.name = _name;
        newAsset.description = _description;
        newAsset.assetType = _assetType;
        newAsset.totalShares = _totalShares;
        newAsset.valueInUSD = _valueInUSD;
        newAsset.active = true;
        newAsset.ipfsMetadata = _ipfsMetadata;
        newAsset.createdAt = block.timestamp;
        newAsset.paymentToken = address(0);
        newAsset.pricePerShareWei = 0;
        newAsset.saleActive = false;

        assetCounter++;

        emit AssetCreated(assetId, _name, _assetType, _totalShares, _valueInUSD);

        return assetId;
    }

    /**
     * @dev Actualizar descripción del activo
     */
    function updateAssetDescription(uint256 _assetId, string memory _newDescription)
        public
        onlyAssetManager
        assetExists(_assetId)
    {
        assets[_assetId].description = _newDescription;
        emit AssetUpdated(_assetId, _newDescription);
    }

    /**
     * @dev Desactivar un activo
     */
    function deactivateAsset(uint256 _assetId)
        public
        onlyAssetManager
        assetExists(_assetId)
    {
        assets[_assetId].active = false;
    }

    // ==================== Funciones de Minteo ====================

    /**
     * @dev Mintear acciones para un accionista
     * @param _to Dirección del accionista
     * @param _assetId ID del activo
     * @param _amount Cantidad de acciones a mintear
     * @param _data Datos adicionales
     */
    function mintShares(
        address _to,
        uint256 _assetId,
        uint256 _amount,
        bytes memory _data
    ) public onlyRole(MINTER_ROLE) assetExists(_assetId) {
        _mintSharesInternal(_to, _assetId, _amount, _data);
    }

    /**
     * @dev Mintear en lote para múltiples accionistas
     */
    function mintSharesBatch(
        address[] memory _tos,
        uint256 _assetId,
        uint256[] memory _amounts,
        bytes memory _data
    ) public onlyRole(MINTER_ROLE) assetExists(_assetId) {
        require(_tos.length == _amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _tos.length; i++) {
            mintShares(_tos[i], _assetId, _amounts[i], _data);
        }
    }

    // ==================== Funciones de Quema ====================

    /**
     * @dev Quemar acciones de un accionista
     * @param _from Dirección del accionista
     * @param _assetId ID del activo
     * @param _amount Cantidad de acciones a quemar
     */
    function burnShares(
        address _from,
        uint256 _assetId,
        uint256 _amount
    ) public onlyRole(BURNER_ROLE) assetExists(_assetId) {
        require(_from != address(0), "Cannot burn from zero address");
        require(balanceOf(_from, _assetId) >= _amount, "Insufficient balance");
        _burn(_from, _assetId, _amount);

        // actualizar estado de accionistas
        uint256 remainingBalance = balanceOf(_from, _assetId);
        if (remainingBalance == 0 && isShareholder[_from][_assetId]) {
            isShareholder[_from][_assetId] = false;
            emit ShareholderRemoved(_assetId, _from);
        }

        // Registrar transacción
        _recordTransaction(_from, _assetId, _amount, "burn");

        emit SharesBurned(_assetId, _from, _amount);
    }

    /**
     * @dev Quemar acciones del propietario
     */
    function burn(
        uint256 _assetId,
        uint256 _amount
    ) public {
        burnShares(msg.sender, _assetId, _amount);
    }

    /**
     * @dev Quemar en lote
     */
    function burnBatch(
        address _from,
        uint256[] memory _assetIds,
        uint256[] memory _amounts
    ) public override {
        require(
            msg.sender == _from || isApprovedForAll(_from, msg.sender),
            "Not authorized"
        );

        for (uint256 i = 0; i < _assetIds.length; i++) {
            burnShares(_from, _assetIds[i], _amounts[i]);
        }
    }

    // ==================== Funciones de Consulta ====================

    /**
     * @dev Obtener información del activo
     */
    function getAssetInfo(uint256 _assetId)
        public
        view
        assetExists(_assetId)
        returns (
            string memory name,
            string memory description,
            string memory assetType,
            uint256 totalShares,
            uint256 valueInUSD,
            bool active,
            uint256 createdAt
        )
    {
        Asset storage asset = assets[_assetId];
        return (
            asset.name,
            asset.description,
            asset.assetType,
            asset.totalShares,
            asset.valueInUSD,
            asset.active,
            asset.createdAt
        );
    }

    /**
     * @dev Obtener lista de accionistas de un activo
     */
    function getShareholders(uint256 _assetId)
        public
        view
        assetExists(_assetId)
        returns (address[] memory)
    {
        return assets[_assetId].shareholders;
    }

    /**
     * @dev Obtener porcentaje de participación
     */
    function getSharePercentage(uint256 _assetId, address _shareholder)
        public
        view
        assetExists(_assetId)
        returns (uint256)
    {
        uint256 bal = balanceOf(_shareholder, _assetId);
        if (bal == 0) return 0;
        return (bal * 100) / (assets[_assetId].totalShares * SHARES_MULTIPLIER);
    }

    /**
     * @dev Obtener el valor por acción
     */
    function getValuePerShare(uint256 _assetId)
        public
        view
        assetExists(_assetId)
        returns (uint256)
    {
        return assets[_assetId].valueInUSD / assets[_assetId].totalShares;
    }

    /**
     * @dev Obtener valor total de un accionista en un activo
     */
    function getShareholderValue(uint256 _assetId, address _shareholder)
        public
        view
        assetExists(_assetId)
        returns (uint256)
    {
        uint256 percentage = getSharePercentage(_assetId, _shareholder);
        return (assets[_assetId].valueInUSD * percentage) / 100;
    }

    /**
     * @dev Obtener historial de transacciones
     */
    function getTransactionHistory(uint256 _assetId)
        public
        view
        assetExists(_assetId)
        returns (ShareholderTransaction[] memory)
    {
        return assetTransactionHistory[_assetId];
    }

    /**
     * @dev Obtener el suministro total de un activo (en tokens enteros)
     */
    function getTotalSupplyFormatted(uint256 _assetId)
        public
        view
        returns (uint256)
    {
        return totalSupply(_assetId) / SHARES_MULTIPLIER;
    }

    // ==================== Funciones Internas ====================

    /**
     * @dev Registrar transacción en el historial
     */
    function _recordTransaction(
        address _shareholder,
        uint256 _assetId,
        uint256 _amount,
        string memory _type
    ) internal {
        ShareholderTransaction memory transaction = ShareholderTransaction({
            shareholder: _shareholder,
            assetId: _assetId,
            amount: _amount,
            transactionType: _type,
            timestamp: block.timestamp
        });

        assetTransactionHistory[_assetId].push(transaction);
        emit TransactionRecorded(_assetId, _shareholder, _type, _amount);
    }

    /**
     * @dev Lógica interna compartida para minteo de acciones
     */
    function _mintSharesInternal(
        address _to,
        uint256 _assetId,
        uint256 _amount,
        bytes memory _data
    ) internal assetExists(_assetId) {
        require(_to != address(0), "Cannot mint to zero address");
        require(_amount > 0, "Amount must be greater than 0");

        // Validar que no exceda el total de acciones (en 1e18)
        uint256 currentSupply = totalSupply(_assetId);
        require(
            currentSupply + _amount <= assets[_assetId].totalShares * SHARES_MULTIPLIER,
            "Exceeds total shares"
        );

        // Agregar como accionista si es nuevo
        if (!isShareholder[_to][_assetId]) {
            assets[_assetId].shareholders.push(_to);
            isShareholder[_to][_assetId] = true;
            uint256 pct = ( (_amount) * 100) / (assets[_assetId].totalShares * SHARES_MULTIPLIER);
            emit ShareholderAdded(_assetId, _to, pct);
        }

        _mint(_to, _assetId, _amount, _data);

        // Registrar transacción
        _recordTransaction(_to, _assetId, _amount, "mint");

        uint256 pctTo = getSharePercentage(_assetId, _to);
        emit SharesMinted(_assetId, _to, _amount, pctTo);
    }

    // ==================== Override de Funciones ERC1155 ====================

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._update(from, to, ids, values);

        // Bookkeep shareholders list on direct transfers
        // Add receiver if new and receiving non-zero
        if (to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (!isShareholder[to][ids[i]] && balanceOf(to, ids[i]) > 0) {
                    assets[ids[i]].shareholders.push(to);
                    isShareholder[to][ids[i]] = true;
                    emit ShareholderAdded(ids[i], to, getSharePercentage(ids[i], to));
                }
            }
        }
        // Remove sender if balance becomes zero
        if (from != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (balanceOf(from, ids[i]) == 0 && isShareholder[from][ids[i]]) {
                    isShareholder[from][ids[i]] = false;
                    emit ShareholderRemoved(ids[i], from);
                }
            }
        }
    }

    function uri(uint256 tokenId)
        public
        view
        override(ERC1155, ERC1155URIStorage)
        returns (string memory)
    {
        return ERC1155URIStorage.uri(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ==================== Funciones de Control ====================

    /**
     * @dev Pausar todas las transferencias
     */
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Reanudar todas las transferencias
     */
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Asignar role de MINTER
     */
    function grantMinterRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(MINTER_ROLE, _account);
    }

    /**
     * @dev Asignar role de BURNER
     */
    function grantBurnerRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(BURNER_ROLE, _account);
    }

    /**
     * @dev Asignar role de ASSET_MANAGER
     */
    function grantAssetManagerRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(ASSET_MANAGER_ROLE, _account);
    }

    // ==================== URIs ====================
    /**
     * @dev Define un URI específico por assetId (tokenId)
     */
    function setAssetURI(uint256 _assetId, string memory _uri) public onlyAssetManager assetExists(_assetId) {
        _setURI(_assetId, _uri);
    }

    /**
     * @dev Define un URI base para todos los tokens (si no se define individual)
     */
    function setBaseURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(newuri);
    }

    // ==================== Venta / Minteo Pagado ====================
    /**
     * @dev Configura parámetros de venta para un asset
     * @param _assetId Id del asset
     * @param _paymentToken address(0) para nativo, o ERC20 address
     * @param _pricePerShareWei precio por 1 share (entero, no 1e18). Para nativo en wei. Para ERC20 en su unidad mínima
     * @param _saleActive activar o no la venta pública
     */
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

    /**
     * @dev Compra de shares utilizando nativo o ERC20.
     * shareAmount es expresado en 1e18 (SHARES_MULTIPLIER). Requiere que el precio esté configurado.
     */
    function buyShares(uint256 _assetId, uint256 _shareAmount, bytes calldata _data)
        external
        payable
        nonReentrant
        assetExists(_assetId)
        whenNotPaused
    {
        require(assets[_assetId].saleActive, "Sale not active");
        require(_shareAmount > 0, "Invalid amount");
        require(
            totalSupply(_assetId) + _shareAmount <= assets[_assetId].totalShares * SHARES_MULTIPLIER,
            "Exceeds total shares"
        );

        // calcular costo por shareAmount (en shares enteros)
        // shareAmount está en 1e18; convertimos a unidades enteras con redondeo hacia abajo
        uint256 wholeShares = _shareAmount / SHARES_MULTIPLIER;
        require(wholeShares > 0, "Amount too small");
        uint256 cost = wholeShares * assets[_assetId].pricePerShareWei;
        address payToken = assets[_assetId].paymentToken;

        if (payToken == address(0)) {
            // pago nativo
            require(msg.value == cost, "Incorrect ETH sent");
        } else {
            // pago ERC20
            require(msg.value == 0, "ETH not accepted");
            require(cost > 0, "Price not set");
            bool success = IERC20(payToken).transferFrom(msg.sender, address(this), cost);
            require(success, "Transfer failed");
        }

        _mintSharesInternal(msg.sender, _assetId, _shareAmount, _data);
    }

    /**
     * @dev Retirar fondos recaudados (ETH)
     */
    function withdrawETH(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount == 0) amount = address(this).balance;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    /**
     * @dev Retirar tokens ERC20 recaudados
     */
    function withdrawERC20(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount == 0) amount = IERC20(token).balanceOf(address(this));
        bool success = IERC20(token).transfer(to, amount);
        require(success, "Transfer failed");
    }
}