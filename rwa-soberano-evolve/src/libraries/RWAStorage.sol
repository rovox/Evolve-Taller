// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RWAStorage {
    struct Asset {
        uint256 assetId;
        uint256 pricePerShareWei;
        uint256 totalShares;
        uint256 valueInUsd;
        uint256 createdAt;
        string name;
        string description;
        string assetType;
        string ipfsMetadata;
        address[] shareholders;
        address paymentToken;
        bool active;
        bool saleActive;
    }

    struct ShareholderTransaction {
        address shareholder;
        uint256 assetId;
        uint256 amount;
        string transactionType;
        uint256 timestamp;
    }
    
    /// @notice Initialize a new asset with basic properties
    /// @param asset Storage pointer to the asset
    /// @param id Unique identifier for the asset
    /// @param name Name of the asset
    function initializeAsset(Asset storage asset, uint256 id, string memory name) internal {
        asset.assetId = id;
        asset.name = name;
        asset.active = true;
        asset.createdAt = block.timestamp;
    }
}
