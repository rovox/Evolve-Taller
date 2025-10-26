// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {DocumentRegistry} from "./DocumentRegistry.sol";
import {AssetToken} from "./AssetToken.sol";

/**
 * @title RWASovereignRollup
 * @notice Contrato principal que integra tokenización RWA, registro de documentos y fraccionalización.
 * @dev Actúa como el punto de entrada único para la interacción del usuario. Es un token ERC20 que representa las acciones.
 */
contract RWASovereignRollup is ERC20, Ownable {
    // --- Contratos y Estado ---
    DocumentRegistry public documentRegistry;
    AssetToken public assetToken;
    uint256 private _totalAssets; // Representa el valor total bloqueado, p. ej., en ETH o un stablecoin.
    
    // --- Estado del Rollup ---
    struct BlockInfo {
        bytes32 stateRoot;
        bytes32 daHash;
        uint256 timestamp;
        address aggregator;
    }
    
    mapping(uint256 => BlockInfo) public blocks;
    uint256 public blockCount;
    bytes32 public lastStateRoot;

    // --- Eventos ---
    event AssetCreated(
        uint256 indexed rwaId,
        bytes32 indexed documentHash,
        address creator
    );
    event FractionPurchased(
        address indexed buyer,
        uint256 amountPaid,
        uint256 sharesMinted
    );
    event BlockCommitted(
        uint256 indexed blockNumber,
        bytes32 indexed stateRoot,
        bytes32 indexed daHash,
        address aggregator
    );
    event TokenizationRequested(
        address indexed requester,
        uint256 amount,
        bytes32 documentHash,
        uint256 timestamp
    );

    // --- Constructor ---
    constructor() ERC20("RWA Fractional Share", "RWAS") Ownable(msg.sender) {
        documentRegistry = new DocumentRegistry();
        // El registry es propiedad del rollup contract para que pueda llamar sus métodos
    }

    /**
     * @notice Configura la dirección del contrato AssetToken
     * @dev Solo el propietario puede llamar a esto
     * @param _assetToken La dirección del contrato AssetToken
     */
    function setAssetToken(address _assetToken) external onlyOwner {
        require(_assetToken != address(0), "RWASovereignRollup: AssetToken address cannot be zero");
        assetToken = AssetToken(_assetToken);
    }

    /**
     * @notice Commitea un nuevo bloque al rollup
     * @dev Solo el propietario puede llamar a esto
     * @param stateRoot El root del estado del bloque
     * @param daHash El hash de la transacción DA
     */
    function commitBlock(bytes32 stateRoot, bytes32 daHash) external onlyOwner {
        blockCount++;
        
        blocks[blockCount] = BlockInfo({
            stateRoot: stateRoot,
            daHash: daHash,
            timestamp: block.timestamp,
            aggregator: msg.sender
        });
        
        lastStateRoot = stateRoot;
        
        emit BlockCommitted(blockCount, stateRoot, daHash, msg.sender);
    }

    /**
     * @notice Solicita la tokenización de un activo RWA
     * @param amount La cantidad a tokenizar
     * @param documentHash El hash del documento asociado
     * @return requestId El ID único de la solicitud
     */
    function requestTokenization(
        uint256 amount,
        bytes32 documentHash
    ) external returns (uint256 requestId) {
        require(amount > 0, "RWASovereignRollup: amount must be greater than zero");
        require(
            documentHash != bytes32(0),
            "RWASovereignRollup: document hash required"
        );

        requestId = uint256(
            keccak256(abi.encodePacked(msg.sender, amount, block.timestamp))
        );

        emit TokenizationRequested(
            msg.sender,
            amount,
            documentHash,
            block.timestamp
        );

        // Simular inclusión en el próximo bloque del rollup
        _simulateRollupInclusion(documentHash);
    }

    /**
     * @notice Verifica que un documento está incluido en un bloque específico del rollup
     * @param documentHash El hash del documento a verificar
     * @param targetBlock El número del bloque a verificar
     * @return Verdadero si el documento está incluido en el bloque
     */
    function verifyDocumentInclusion(
        bytes32 documentHash,
        uint256 targetBlock
    ) external view returns (bool) {
        // En un rollup real, esto verificaría una prueba de inclusión Merkle
        // Aquí simulamos con una verificación simple basada en que el bloque existe
        return targetBlock <= blockCount && blocks[targetBlock].daHash != bytes32(0);
    }

    /**
     * @notice Registra un documento en el registro
     * @param documentHash El hash del documento a registrar
     * @return daTransactionHash El hash de la transacción DA simulada
     */
    function registerDocument(
        bytes32 documentHash
    ) external returns (bytes32) {
        return documentRegistry.registerDocument(documentHash, msg.sender);
    }

    // --- Funciones Principales ---

    /**
     * @notice Crea un nuevo activo tokenizado registrando su documento legal.
     * @dev Solo el propietario del AssetToken puede llamar a esto. Emite un evento AssetCreated.
     * @param documentHash El hash del documento legal que respalda el RWA.
     */
    function createAsset(bytes32 documentHash) external {
        require(address(assetToken) != address(0), "RWASovereignRollup: AssetToken not set");
        require(assetToken.isRWATokenOwner(msg.sender), "RWASovereignRollup: Only AssetToken owner can create assets");
        require(
            documentHash != bytes32(0),
            "RWASovereignRollup: El hash del documento no puede ser cero."
        );
        
        bytes32 daTransactionHash = documentRegistry.registerDocument(documentHash, msg.sender);

        emit AssetCreated(
            documentRegistry.RWA_ID(),
            documentHash,
            msg.sender
        );
    }

    /**
     * @notice Permite a un usuario comprar una fracción del RWA a cambio de ETH.
     * @dev Convierte el ETH enviado en acciones (shares) del token ERC20.
     *      La relación es 1:1 (1 Wei de ETH = 1 unidad de share).
     */
    function purchaseFraction() external payable {
        uint256 amountPaid = msg.value;
        require(amountPaid > 0, "RWASovereignRollup: Debes enviar ETH para comprar fracciones.");

        // En un caso real, el ETH se transferiría a una bóveda o al propietario del activo.
        // Aquí, simplemente lo aceptamos y actualizamos el total de activos.
        _totalAssets += amountPaid;

        // Mint shares para el comprador (relación 1:1 con la cantidad pagada en wei)
        uint256 sharesToMint = amountPaid;
        _mint(msg.sender, sharesToMint);

        emit FractionPurchased(msg.sender, amountPaid, sharesToMint);
    }

    // --- Funciones de Consulta ---

    /**
     * @notice Devuelve el valor total de los activos gestionados por este contrato.
     */
    function totalAssets() external view returns (uint256) {
        return _totalAssets;
    }

    /**
     * @notice Obtiene la información del registro del documento para el RWA principal.
     */
    function getDocumentRecord()
        external
        view
        returns (DocumentRegistry.DocumentRecord memory)
    {
        return documentRegistry.getDocumentRecord(documentRegistry.RWA_ID());
    }

    // --- Funciones Internas ---

    /**
     * @notice Simula la inclusión de un documento en el próximo bloque del rollup
     * @param documentHash El hash del documento a incluir
     */
    function _simulateRollupInclusion(bytes32 documentHash) internal {
        // Simular que el documento será incluido en el próximo bloque del rollup
        bytes32 simulatedDaHash = keccak256(
            abi.encodePacked(documentHash, lastStateRoot, block.timestamp)
        );

        // Actualizar el último state root
        lastStateRoot = keccak256(abi.encodePacked(lastStateRoot, documentHash));

        // En un entorno real, esto se enviaría a Celestia DA
        emit BlockCommitted(
            blockCount + 1,
            lastStateRoot,
            simulatedDaHash,
            address(this)
        );
    }
}