// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title DocumentRegistry
 * @notice Registro simple para documentos vinculados a activos tokenizados
 */
contract DocumentRegistry is AccessControl, Ownable {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    struct DocumentRecord {
        uint256 assetId;
        bytes32 documentHash;
        string documentURI;
        string documentType;
        address submitter;
        uint256 registeredAt;
    }

    mapping(uint256 => DocumentRecord[]) private _documentsByAsset;
    mapping(uint256 => DocumentRecord) private _latestDocumentByAsset;
    mapping(bytes32 => bool) private _registeredDocuments;

    event DocumentRegistered(
        uint256 indexed assetId,
        bytes32 indexed documentHash,
        string documentURI,
        string documentType,
        address indexed submitter
    );

    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
    }

    /**
     * @notice Registra un nuevo documento asociado a un activo
     */
    function registerDocument(
        uint256 assetId,
        bytes32 documentHash,
        string memory documentURI,
        string memory documentType
    ) external onlyRole(REGISTRAR_ROLE) returns (bytes32) {
        require(documentHash != bytes32(0), "Registry: invalid document hash");
        require(!_registeredDocuments[documentHash], "Registry: document already registered");
        require(bytes(documentURI).length > 0, "Registry: document URI required");
        require(bytes(documentType).length > 0, "Registry: document type required");

        DocumentRecord memory record = DocumentRecord({
            assetId: assetId,
            documentHash: documentHash,
            documentURI: documentURI,
            documentType: documentType,
            submitter: _msgSender(),
            registeredAt: block.timestamp
        });

        _documentsByAsset[assetId].push(record);
        _latestDocumentByAsset[assetId] = record;
    _registeredDocuments[documentHash] = true;

        emit DocumentRegistered(assetId, documentHash, documentURI, documentType, _msgSender());
        return documentHash;
    }

    /**
     * @notice Obtiene el documento más reciente de un activo
     */
    function getLatestDocument(uint256 assetId)
        external
        view
        returns (DocumentRecord memory)
    {
        DocumentRecord memory record = _latestDocumentByAsset[assetId];
        require(record.registeredAt != 0, "Registry: no document for asset");
        return record;
    }

    /**
     * @notice Obtiene el historial completo de documentos por activo
     */
    function getDocumentHistory(uint256 assetId)
        external
        view
        returns (DocumentRecord[] memory)
    {
        return _documentsByAsset[assetId];
    }

    /**
     * @notice Permite que el propietario otorgue permisos de registrador
     */
    function grantRegistrar(address account) external onlyOwner {
        require(account != address(0), "Registry: zero address");
    _grantRole(REGISTRAR_ROLE, account);
    }

    /**
     * @notice Permite que el propietario revoque permisos de registrador
     */
    function revokeRegistrar(address account) external onlyOwner {
        require(account != address(0), "Registry: zero address");
        _revokeRole(REGISTRAR_ROLE, account);
    }

    /**
     * @inheritdoc AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
