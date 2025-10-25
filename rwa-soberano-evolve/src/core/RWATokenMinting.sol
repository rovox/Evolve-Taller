// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RWATokenCore} from "./RWATokenCore.sol";
import {RWAValidation} from "../libraries/RWAValidation.sol";

abstract contract RWATokenMinting is RWATokenCore {
    
    event SharesMinted(address indexed to, uint256 indexed assetId, uint256 amount);
    event SharesBurned(address indexed from, uint256 indexed assetId, uint256 amount);
    
    /// @notice Mint shares to an address
    /// @param to Recipient address
    /// @param assetId Asset identifier
    /// @param amount Amount of shares to mint
    /// @param data Additional data
    function mintShares(
        address to,
        uint256 assetId,
        uint256 amount,
        bytes memory data
    ) public onlyAssetManager assetExists(assetId) {
        _mintSharesInternal(to, assetId, amount, data);
    }
    
    /// @notice Batch mint shares to multiple addresses for the same asset
    /// @param recipients Array of recipient addresses
    /// @param assetId Asset identifier
    /// @param amounts Array of amounts to mint to each recipient
    /// @param data Additional data
    function mintSharesBatch(
        address[] memory recipients,
        uint256 assetId,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyAssetManager assetExists(assetId) {
        RWAValidation.requireNotEmpty(recipients.length);
        RWAValidation.requireArrayMatch(recipients.length, amounts.length);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mintSharesInternal(recipients[i], assetId, amounts[i], data);
        }
    }
    
    /// @notice Batch mint shares to an address
    /// @param to Recipient address
    /// @param ids Array of asset identifiers
    /// @param amounts Array of amounts to mint
    /// @param data Additional data
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyAssetManager {
        RWAValidation.requireNotEmpty(ids.length);
        RWAValidation.requireArrayMatch(ids.length, amounts.length);
        
        for (uint256 i = 0; i < ids.length; i++) {
            _checkAssetExists(ids[i]);
        }
        
        _mintBatch(to, ids, amounts, data);
    }
    
    /// @notice Internal mint function with shareholder tracking
    function _mintSharesInternal(
        address to,
        uint256 assetId,
        uint256 amount,
        bytes memory data
    ) internal {
        if (balanceOf(to, assetId) == 0) {
            _addToShareholders(assetId, to);
        }
        
        _mint(to, assetId, amount, data);
        emit SharesMinted(to, assetId, amount);
    }
    
    /// @notice Burn shares from caller
    /// @param assetId Asset identifier
    /// @param amount Amount of shares to burn
    function burnShares(uint256 assetId, uint256 amount) public {
        _burnInternal(msg.sender, assetId, amount, "");
    }
    
    /// @notice Burn shares from any address (admin only)
    /// @param from Address to burn from
    /// @param assetId Asset identifier
    /// @param amount Amount of shares to burn
    function burnShares(address from, uint256 assetId, uint256 amount) public onlyAssetManager {
        _burnInternal(from, assetId, amount, "");
    }
    
    /// @notice Burn shares from an address (with approval)
    /// @param from Address to burn from
    /// @param assetId Asset identifier
    /// @param amount Amount of shares to burn
    /// @param data Additional data
    function burn(
        address from,
        uint256 assetId,
        uint256 amount,
        bytes memory data
    ) public {
        require(
            msg.sender == from || isApprovedForAll(from, msg.sender),
            "Not authorized"
        );
        _burnInternal(from, assetId, amount, data);
    }
    
    /// @notice Internal burn function with shareholder tracking
    function _burnInternal(
        address from,
        uint256 assetId,
        uint256 amount,
        bytes memory data
    ) internal {
        require(balanceOf(from, assetId) >= amount, "Insufficient balance");
        require(assets[assetId].active, "Asset not active");
        
        uint256 newBalance = balanceOf(from, assetId) - amount;
        if (newBalance == 0) {
            _removeFromShareholders(assetId, from);
        }
        
        _burn(from, assetId, amount);
        emit SharesBurned(from, assetId, amount);
    }
}
