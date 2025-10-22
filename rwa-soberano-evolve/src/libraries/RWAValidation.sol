// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library RWAValidation {
    /// @notice Validate array lengths match
    function requireArrayMatch(uint256 length1, uint256 length2) internal pure {
        require(length1 == length2, "Array length mismatch");
    }
    
    /// @notice Validate arrays are not empty
    function requireNotEmpty(uint256 length) internal pure {
        require(length > 0, "Empty arrays");
    }
    
    /// @notice Validate address is not zero
    function requireValidAddress(address addr) internal pure {
        require(addr != address(0), "Invalid address");
    }
    
    /// @notice Validate amount is greater than zero
    function requirePositiveAmount(uint256 amount) internal pure {
        require(amount > 0, "Amount must be greater than 0");
    }
}
