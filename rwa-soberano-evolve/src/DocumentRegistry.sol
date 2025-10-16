// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title DocumentRegistry
 * @notice Registro inmutable de documentos legales del RWA con integración simulada a Celestia DA
 * @dev Almacena hashes de documentos y simula la publicación en la capa de disponibilidad de datos
 */
contract DocumentRegistry is Ownable {
    // --- Estructuras de Datos ---
    struct DocumentRecord {
        bytes32 documentHash;
        bytes32 daTransactionHash; // Hash simulado de la transacción en Celestia
        uint256 timestamp;
        address registeredBy;
    }

    // --- Estado ---
    mapping(uint256 => DocumentRecord) private _documentRecords;
    uint256 public constant RWA_ID = 1;

    // --- Eventos ---
    event DocumentRegistered(
        uint256 indexed rwaId,
        bytes32 indexed documentHash,
        bytes32 indexed daTransactionHash,
        uint256 timestamp,
        address registeredBy
    );

    event DAPublished(
        bytes32 indexed documentHash,
        bytes32 indexed daBatchHash,
        uint256 timestamp
    );

    // --- Constructor ---
    constructor() Ownable(msg.sender) {}

    // --- Funciones Públicas ---

    /**
     * @notice Registra un nuevo hash de documento para el RWA
     * @param documentHash Hash SHA256 del documento legal
     * @return daTransactionHash Hash simulado de la transacción en Celestia
     */
    function registerDocument(
        bytes32 documentHash
    ) external onlyOwner returns (bytes32 daTransactionHash) {
        require(
            documentHash != bytes32(0),
            "DocumentRegistry: hash cannot be zero"
        );
        require(
            _documentRecords[RWA_ID].timestamp == 0,
            "DocumentRegistry: document already registered"
        );

        // Simular hash de transacción en Celestia
        daTransactionHash = keccak256(
            abi.encodePacked(documentHash, block.timestamp, block.prevrandao)
        );

        _documentRecords[RWA_ID] = DocumentRecord({
            documentHash: documentHash,
            daTransactionHash: daTransactionHash,
            timestamp: block.timestamp,
            registeredBy: msg.sender
        });

        emit DocumentRegistered(
            RWA_ID,
            documentHash,
            daTransactionHash,
            block.timestamp,
            msg.sender
        );

        // Simular publicación en Celestia DA
        _simulateDAPublication(documentHash);

        return daTransactionHash;
    }

    /**
     * @notice Actualiza el documento existente (solo para emergencias)
     * @param newDocumentHash Nuevo hash del documento
     */
    function updateDocument(bytes32 newDocumentHash) external onlyOwner {
        require(
            newDocumentHash != bytes32(0),
            "DocumentRegistry: hash cannot be zero"
        );
        require(
            _documentRecords[RWA_ID].timestamp != 0,
            "DocumentRegistry: no document to update"
        );

        bytes32 daTransactionHash = keccak256(
            abi.encodePacked(newDocumentHash, block.timestamp, block.prevrandao)
        );

        _documentRecords[RWA_ID] = DocumentRecord({
            documentHash: newDocumentHash,
            daTransactionHash: daTransactionHash,
            timestamp: block.timestamp,
            registeredBy: msg.sender
        });

        emit DocumentRegistered(
            RWA_ID,
            newDocumentHash,
            daTransactionHash,
            block.timestamp,
            msg.sender
        );

        _simulateDAPublication(newDocumentHash);
    }

    // --- Funciones de Consulta ---

    function getDocumentRecord(
        uint256 rwaId
    ) external view returns (DocumentRecord memory) {
        require(rwaId == RWA_ID, "DocumentRegistry: invalid RWA ID");
        require(
            _documentRecords[rwaId].timestamp != 0,
            "DocumentRegistry: document not found"
        );
        return _documentRecords[rwaId];
    }

    function verifyDocument(
        bytes32 documentHash,
        uint256 rwaId
    ) external view returns (bool) {
        require(rwaId == RWA_ID, "DocumentRegistry: invalid RWA ID");
        return _documentRecords[rwaId].documentHash == documentHash;
    }

    // --- Funciones de Simulación Celestia DA ---

    function simulateDABatchPublication(
        bytes32[] calldata documentHashes
    ) external onlyOwner returns (bytes32 daBatchHash) {
        daBatchHash = keccak256(
            abi.encodePacked(documentHashes, block.timestamp)
        );

        for (uint i = 0; i < documentHashes.length; i++) {
            emit DAPublished(documentHashes[i], daBatchHash, block.timestamp);
        }

        return daBatchHash;
    }

    function calculateDocumentHash(
        string memory documentUri
    ) external pure returns (bytes32) {
        return sha256(bytes(documentUri));
    }

    // --- Funciones Internas ---

    function _simulateDAPublication(bytes32 documentHash) internal {
        bytes32 daBatchHash = keccak256(
            abi.encodePacked(documentHash, block.timestamp)
        );

        emit DAPublished(documentHash, daBatchHash, block.timestamp);
    }
}
