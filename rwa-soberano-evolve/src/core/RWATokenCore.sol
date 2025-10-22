// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../libraries/RWAStorage.sol";
import "../libraries/RWAMath.sol";
import "../libraries/RWAValidation.sol";

abstract contract RWATokenCore is ERC1155, Ownable, AccessControl {
    using RWAMath for uint256;
    
    // Role definitions
    bytes32 public constant ASSET_MANAGER_ROLE = keccak256("ASSET_MANAGER_ROLE");
    
    // State variables
    mapping(uint256 => RWAStorage.Asset) public assets;
    uint256 public assetCounter;
    
    // Constants
    uint256 private constant MAX_SHAREHOLDERS_PER_ASSET = 1000;
    
    // Events
    event AssetCreated(uint256 indexed assetId, string name, uint256 totalShares);
    event ShareholderAdded(address indexed shareholder, uint256 indexed assetId);
    event ShareholderRemoved(address indexed shareholder, uint256 indexed assetId);
    
    constructor(string memory uri) ERC1155(uri) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ASSET_MANAGER_ROLE, msg.sender);
    }
    
    // Optimized modifiers using private functions
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
            hasRole(ASSET_MANAGER_ROLE, msg.sender) || owner() == msg.sender,
            "Must have asset manager role"
        );
    }
    
    function _checkAssetExists(uint256 _assetId) internal view {
        require(_assetId < assetCounter, "Asset does not exist");
        require(assets[_assetId].active, "Asset is not active");
    }
    
    /// @notice Create a new RWA asset
    /// @param _name Asset name
    /// @param _description Asset description
    /// @param _assetType Type of asset (e.g., "real_estate", "art")
    /// @param _totalShares Total shares to issue
    /// @param _valueInUSD Asset value in USD
    /// @param _ipfsMetadata IPFS hash for metadata
    /// @return assetId Unique identifier for the created asset
    function createAsset(
        string memory _name,
        string memory _description, 
        string memory _assetType,
        uint256 _totalShares,
        uint256 _valueInUSD,
        string memory _ipfsMetadata
    ) public onlyAssetManager returns (uint256) {
        RWAValidation.requirePositiveAmount(_totalShares);
        RWAValidation.requirePositiveAmount(_valueInUSD);
        
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
    
    /// @notice Update asset metadata
    function updateAssetMetadata(
        uint256 _assetId,
        string memory _ipfsMetadata
    ) public onlyAssetManager assetExists(_assetId) {
        assets[_assetId].ipfsMetadata = _ipfsMetadata;
    }
    
    /// @notice Deactivate an asset
    function deactivateAsset(uint256 _assetId) public onlyAssetManager assetExists(_assetId) {
        assets[_assetId].active = false;
    }
    
    /// @notice Add shareholder to asset's shareholder list
    function _addToShareholders(uint256 assetId, address shareholder) internal {
        require(
            assets[assetId].shareholders.length < MAX_SHAREHOLDERS_PER_ASSET,
            "Max shareholders reached"
        );
        assets[assetId].shareholders.push(shareholder);
        emit ShareholderAdded(shareholder, assetId);
    }
    
    /// @notice Remove shareholder from asset's shareholder list
    function _removeFromShareholders(uint256 assetId, address shareholder) internal {
        address[] storage shareholders = assets[assetId].shareholders;
        for (uint256 i = 0; i < shareholders.length; i++) {
            if (shareholders[i] == shareholder) {
                shareholders[i] = shareholders[shareholders.length - 1];
                shareholders.pop();
                emit ShareholderRemoved(shareholder, assetId);
                break;
            }
        }
    }
    
    // Required AccessControl override
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
