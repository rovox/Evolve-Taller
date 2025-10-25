// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RWATokenCore} from "./RWATokenCore.sol";

abstract contract RWATokenQueries is RWATokenCore {
    using RWAMath for uint256;
    
    /// @notice Get asset details
    /// @param _assetId Asset identifier
    /// @return Asset struct
    function getAsset(uint256 _assetId) public view returns (RWAStorage.Asset memory) {
        return assets[_assetId];
    }
    /// @notice Get transaction history for an asset
    /// @param _assetId Asset identifier
    /// @return Array of transaction records
    function getTransactionHistory(uint256 _assetId) 
        public 
        view 
        returns (RWAStorage.ShareholderTransaction[] memory) 
    {
        // Implementation depends on how you're storing transaction history
        // This is just a placeholder
        return assetTransactions[_assetId];
    }    mapping(uint256 => RWAStorage.ShareholderTransaction[]) public assetTransactions;

    /// @notice Get the total number of assets created
    /// @return The total count of assets
    function getTotalAssets() public view returns (uint256) {
        return assetCounter;
    }

    /// @notice Check if an asset is active
    /// @param _assetId Asset identifier
    /// @return True if the asset is active, false otherwise
    function isAssetActive(uint256 _assetId) public view returns (bool) {
        return assets[_assetId].active;
    }

    /// @notice Get the IPFS metadata hash for an asset
    /// @param _assetId Asset identifier
    /// @return IPFS metadata hash
    function getAssetMetadata(uint256 _assetId) public view returns (string memory) {
        return assets[_assetId].ipfsMetadata;
    }

    /// @notice Get the creation timestamp of an asset
    /// @param _assetId Asset identifier
    /// @return Unix timestamp of asset creation
    function getAssetCreationTime(uint256 _assetId) public view returns (uint256) {
        return assets[_assetId].createdAt;
    }


    /// @notice Get list of shareholders for an asset
    /// @param _assetId Asset identifier
    /// @return Array of shareholder addresses
    function getShareholders(uint256 _assetId) public view returns (address[] memory) {
        return assets[_assetId].shareholders;
    }
    
    /// @notice Calculate shareholder's percentage ownership
    /// @param _assetId Asset identifier
    /// @param _shareholder Shareholder address
    /// @return Ownership percentage (with 2 decimal precision)
    function getShareholderPercentage(uint256 _assetId, address _shareholder)
        public
        view
        returns (uint256)
    {
        uint256 balance = balanceOf(_shareholder, _assetId);
        uint256 totalShares = assets[_assetId].totalShares;
        return RWAMath.calculateSharePercentage(balance, totalShares);
    }
    
    /// @notice Calculate USD value of shareholder's position
    /// @param _assetId Asset identifier
    /// @param _shareholder Shareholder address
    /// @return USD value
    function getShareholderValue(uint256 _assetId, address _shareholder)
        public
        view
        returns (uint256)
    {
        uint256 balance = balanceOf(_shareholder, _assetId);
        uint256 totalShares = assets[_assetId].totalShares;
        uint256 totalValue = assets[_assetId].valueInUSD;
        return RWAMath.calculateShareholderValue(balance, totalShares, totalValue);
    }
    
    /// @notice Get total number of shareholders for an asset
    /// @param _assetId Asset identifier
    /// @return Number of shareholders
    function getShareholderCount(uint256 _assetId) public view returns (uint256) {
        return assets[_assetId].shareholders.length;
    }
}
