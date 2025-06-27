// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKarmaAccessControl
 * @dev Standardized access control interface for all Karma Labs contracts
 * 
 * This interface defines the standard roles and access control patterns
 * used across the entire Karma Labs ecosystem for consistency and security.
 */
interface IKarmaAccessControl {
    
    // ============ STANDARD ROLES ============
    
    /**
     * @dev Returns the DEFAULT_ADMIN_ROLE identifier
     * This role can manage all other roles and is typically held by multisig
     */
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    
    /**
     * @dev Returns the EMERGENCY_ROLE identifier
     * This role can trigger emergency pauses and recovery procedures
     */
    function EMERGENCY_ROLE() external pure returns (bytes32);
    
    /**
     * @dev Returns the OPERATOR_ROLE identifier
     * This role can perform day-to-day operations but not admin functions
     */
    function OPERATOR_ROLE() external pure returns (bytes32);
    
    // ============ ROLE MANAGEMENT ============
    
    /**
     * @dev Grants role to account
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function grantRole(bytes32 role, address account) external;
    
    /**
     * @dev Revokes role from account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) external;
    
    /**
     * @dev Checks if account has role
     * @param role The role to check
     * @param account The account to check
     * @return True if account has role
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    /**
     * @dev Renounces role for the calling account
     * @param role The role to renounce
     * @param account The account renouncing the role (must be msg.sender)
     */
    function renounceRole(bytes32 role, address account) external;
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Pauses the contract (if pausable)
     * Only callable by EMERGENCY_ROLE
     */
    function emergencyPause() external;
    
    /**
     * @dev Unpauses the contract (if pausable)
     * Only callable by EMERGENCY_ROLE
     */
    function emergencyUnpause() external;
    
    /**
     * @dev Returns whether the contract is currently paused
     */
    function paused() external view returns (bool);
    
    // ============ ADMIN TRANSFER ============
    
    /**
     * @dev Initiates admin transfer to new multisig
     * @param newAdmin Address of the new admin (typically multisig)
     */
    function initiateAdminTransfer(address newAdmin) external;
    
    /**
     * @dev Accepts admin transfer (must be called by new admin)
     */
    function acceptAdminTransfer() external;
    
    /**
     * @dev Cancels pending admin transfer
     */
    function cancelAdminTransfer() external;
    
    /**
     * @dev Returns the pending admin address
     */
    function pendingAdmin() external view returns (address);
    
    // ============ EVENTS ============
    
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event EmergencyPauseTriggered(address indexed account);
    event EmergencyUnpauseTriggered(address indexed account);
    event AdminTransferInitiated(address indexed currentAdmin, address indexed pendingAdmin);
    event AdminTransferCompleted(address indexed previousAdmin, address indexed newAdmin);
    event AdminTransferCancelled(address indexed currentAdmin, address indexed cancelledAdmin);
} 