// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {RWATokenMinting} from "../core/RWATokenMinting.sol";

abstract contract RWATokenAdmin is RWATokenMinting, Pausable {
    
    event EmergencyStop(address indexed admin, string reason);
    event ContractResumed(address indexed admin);
    
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }
    
    function _checkAdmin() private view {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || owner() == msg.sender,
            "Must have admin role"
        );
    }
    
    /// @notice Pause all contract operations in emergency
    /// @param reason Reason for emergency pause
    function emergencyPause(string memory reason) external onlyAdmin {
        _pause();
        emit EmergencyStop(msg.sender, reason);
    }
    
    /// @notice Resume contract operations after pause
    function resume() external onlyAdmin {
        _unpause();
        emit ContractResumed(msg.sender);
    }
    
    /// @notice Grant asset manager role to an account
    /// @param account Address to grant role to
    function grantAssetManagerRole(address account) external onlyAdmin {
        RWAValidation.requireValidAddress(account);
        grantRole(ASSET_MANAGER_ROLE, account);
    }
    
    /// @notice Revoke asset manager role from an account
    /// @param account Address to revoke role from
    function revokeAssetManagerRole(address account) external onlyAdmin {
        revokeRole(ASSET_MANAGER_ROLE, account);
    }
    
    // Override transfer functions to respect pause
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override whenNotPaused {
        super._update(from, to, ids, values);
    }
}
