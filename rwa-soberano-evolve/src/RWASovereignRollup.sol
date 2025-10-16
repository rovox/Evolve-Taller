// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {DocumentRegistry} from "./DocumentRegistry.sol";
import {AssetToken} from "./AssetToken.sol";

/**
 * @title RWASovereignRollup
 * @notice Contrato principal que integra tokenización RWA con registro de documentos y simulacion de Rollup Soberano
 * @dev Simula las funciones críticas de un Rollup Soberano en Evolve + Celestia
 */
contract RWASovereignRollup is Ownable {
    // --- Contratos Integrados ---
    DocumentRegistry public documentRegistry;
    AssetToken public assetToken;

    // --- Estado del Rollup ---
    bytes32 public lastStateRoot;
    uint256 public blockNumber;

    struct RollupBlock {
        bytes32 stateRoot;
        bytes32 daHash;
        uint256 timestamp;
        address aggregator;
    }

    mapping(uint256 => RollupBlock) public blocks;

    // --- Eventos ---
    event RollupBlockCommitted(
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
    constructor() Ownable(msg.sender) {
        documentRegistry = new DocumentRegistry();
        blockNumber = 1;
    }

    /**
     * @notice Sets the AssetToken reference after deployment
     * @dev Called by the deployer script to wire up the token
     */
    function setAssetToken(address _assetToken) external onlyOwner {
        require(address(assetToken) == address(0), "AssetToken already set");
        require(_assetToken != address(0), "Invalid token address");
        assetToken = AssetToken(_assetToken);
    }

    /**
     * @notice Getter for registry (alias for documentRegistry)
     * @dev Provides compatibility with integration tests
     */
    function registry() external view returns (address) {
        return address(documentRegistry);
    }

    // --- Funciones del Rollup ---

    /**
     * @notice Simula la commit de un bloque del Rollup a Celestia DA
     */
    function commitBlock(bytes32 stateRoot, bytes32 daHash) external onlyOwner {
        blocks[blockNumber] = RollupBlock({
            stateRoot: stateRoot,
            daHash: daHash,
            timestamp: block.timestamp,
            aggregator: msg.sender
        });

        lastStateRoot = stateRoot;

        emit RollupBlockCommitted(blockNumber, stateRoot, daHash, msg.sender);
        blockNumber++;
    }

    /**
     * @notice Función de tokenización que simula ejecución en el Rollup Soberano
     */
    function requestTokenization(
        uint256 amount,
        bytes32 documentHash
    ) external returns (uint256 requestId) {
        require(amount > 0, "RWARollup: amount must be greater than zero");
        require(
            documentHash != bytes32(0),
            "RWARollup: document hash required"
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

        return requestId;
    }

    /**
     * @notice Verifica que un documento está incluido en el rollup
     */
    function verifyDocumentInclusion(
        bytes32 documentHash,
        uint256 targetBlock
    ) external view returns (bool) {
        // En un rollup real, esto verificaría una prueba de inclusión Merkle
        // Aquí simulamos con una verificación simple
        return blocks[targetBlock].daHash != bytes32(0);
    }

    // --- Funciones de Integración con DocumentRegistry ---

    function registerDocument(
        bytes32 documentHash
    ) external onlyOwner returns (bytes32) {
        return documentRegistry.registerDocument(documentHash);
    }

    function getDocumentRecord()
        external
        view
        returns (DocumentRegistry.DocumentRecord memory)
    {
        return documentRegistry.getDocumentRecord(documentRegistry.RWA_ID());
    }

    // --- Funciones Internas ---

    function _simulateRollupInclusion(bytes32 documentHash) internal {
        // Simular que el documento será incluido en el próximo bloque del rollup
        bytes32 simulatedDaHash = keccak256(
            abi.encodePacked(documentHash, lastStateRoot, block.timestamp)
        );

        // En un entorno real, esto se enviaría a Celestia DA
        emit RollupBlockCommitted(
            blockNumber,
            keccak256(abi.encodePacked(lastStateRoot, documentHash)),
            simulatedDaHash,
            address(this)
        );
    }
}
