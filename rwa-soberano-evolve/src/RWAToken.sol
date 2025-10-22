// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./core/RWATokenQueries.sol";
import "./extensions/RWATokenSales.sol";
import "./extensions/RWATokenAdmin.sol";

/// @title RWA Tokenization Contract
/// @notice Tokenizes Real World Assets using ERC1155 with modular architecture
/// @dev Implements modular design to stay under 24KB deployment limit
/// @custom:security-contact security@rwa-soberano.com
contract RWAToken is RWATokenQueries, RWATokenSales, RWATokenAdmin {
    
    /// @notice Contract version
    string public constant VERSION = "2.0.0-modular";
    
    /// @notice Initialize the RWA Token contract
    /// @param uri Base URI for token metadata
    constructor(string memory uri) RWATokenCore(uri) {
        // Constructor logic handled by parent contracts
    }
    
    /// @notice Get contract version
    /// @return Version string
    function version() external pure returns (string memory) {
        return VERSION;
    }
    
    // Override _update to combine pausable and shareholder tracking
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(RWATokenAdmin, ERC1155) {
        super._update(from, to, ids, values);
        
        // Track shareholder changes for non-zero transfers
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                // Add to shareholders if first time receiving
                if (balanceOf(to, ids[i]) == values[i]) {
                    _addToShareholders(ids[i], to);
                }
                
                // Remove from shareholders if balance becomes zero
                if (balanceOf(from, ids[i]) == values[i]) {
                    _removeFromShareholders(ids[i], from);
                }
            }
        }
    }
    
    /// @notice Emergency function to receive ETH
    receive() external payable {}
}