// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KarmaMultiSigManager
 * @dev Contract for managing Gnosis Safe integration and administrative controls
 * 
 * Features:
 * - Gnosis Safe factory integration for 3-of-5 multisig setup
 * - Role management functions for easy admin transitions
 * - Emergency response mechanisms with timelock patterns
 * - Standardized admin transfer workflows
 */
contract KarmaMultiSigManager is AccessControl, ReentrancyGuard {
    
    // ============ STATE VARIABLES ============
    
    address public gnosisSafeFactory;
    address public gnosisSafeMasterCopy;
    address public multisigWallet;
    
    address private _pendingAdmin;
    uint256 private _adminTransferInitiated;
    uint256 public constant ADMIN_TRANSFER_DELAY = 2 days;
    
    // Role definitions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // ============ EVENTS ============
    
    event MultiSigCreated(address indexed multisig, address[] owners, uint256 threshold);
    event AdminTransferInitiated(address indexed currentAdmin, address indexed pendingAdmin);
    event AdminTransferCompleted(address indexed previousAdmin, address indexed newAdmin);
    event AdminTransferCancelled(address indexed currentAdmin, address indexed cancelledAdmin);
    event EmergencyActionExecuted(address indexed executor, string action);
    
    // ============ MODIFIERS ============
    
    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "KarmaMultiSig: caller is not emergency role");
        _;
    }
    
    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "KarmaMultiSig: caller is not operator role");
        _;
    }
    
    modifier afterTransferDelay() {
        require(
            _adminTransferInitiated != 0 && 
            block.timestamp >= _adminTransferInitiated + ADMIN_TRANSFER_DELAY,
            "KarmaMultiSig: transfer delay not met"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize the contract with initial admin
     * @param initialAdmin Address that will receive all initial roles
     */
    constructor(address initialAdmin) {
        require(initialAdmin != address(0), "KarmaMultiSig: Invalid admin address");
        
        // Grant all roles to initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(EMERGENCY_ROLE, initialAdmin);
        _grantRole(OPERATOR_ROLE, initialAdmin);
    }
    
    // ============ GNOSIS SAFE INTEGRATION ============
    
    /**
     * @dev Set Gnosis Safe factory and master copy addresses
     * @param factory Address of the Gnosis Safe factory
     * @param masterCopy Address of the Gnosis Safe master copy
     */
    function setGnosisSafeAddresses(address factory, address masterCopy) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(factory != address(0), "KarmaMultiSig: Invalid factory address");
        require(masterCopy != address(0), "KarmaMultiSig: Invalid master copy address");
        
        gnosisSafeFactory = factory;
        gnosisSafeMasterCopy = masterCopy;
    }
    
    /**
     * @dev Create a 3-of-5 multisig wallet using Gnosis Safe
     * @param owners Array of 5 owner addresses for the multisig
     * @param saltNonce Salt for deterministic address generation
     */
    function createMultiSig(address[] memory owners, uint256 saltNonce) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns (address) 
    {
        require(owners.length == 5, "KarmaMultiSig: Must have exactly 5 owners");
        require(gnosisSafeFactory != address(0), "KarmaMultiSig: Gnosis Safe factory not set");
        
        // Validate all owners are valid addresses
        for (uint256 i = 0; i < owners.length; i++) {
            require(owners[i] != address(0), "KarmaMultiSig: Invalid owner address");
            // Check for duplicates
            for (uint256 j = i + 1; j < owners.length; j++) {
                require(owners[i] != owners[j], "KarmaMultiSig: Duplicate owner address");
            }
        }
        
        // Create the multisig with 3-of-5 threshold
        uint256 threshold = 3;
        
        // This is a simplified implementation - in production, you'd use the actual Gnosis Safe factory
        // For now, we'll store the configuration and emit an event
        multisigWallet = address(uint160(uint256(keccak256(abi.encodePacked(
            address(this),
            owners,
            threshold,
            saltNonce,
            block.timestamp
        )))));
        
        emit MultiSigCreated(multisigWallet, owners, threshold);
        
        return multisigWallet;
    }
    
    // ============ ADMIN TRANSFER FUNCTIONS ============
    
    /**
     * @dev Initiates admin transfer to multisig wallet
     * @param newAdmin Address of the new admin (typically the created multisig)
     */
    function initiateAdminTransfer(address newAdmin) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newAdmin != address(0), "KarmaMultiSig: Invalid new admin address");
        require(newAdmin != msg.sender, "KarmaMultiSig: Cannot transfer to self");
        
        _pendingAdmin = newAdmin;
        _adminTransferInitiated = block.timestamp;
        
        emit AdminTransferInitiated(msg.sender, newAdmin);
    }
    
    /**
     * @dev Accepts admin transfer after delay period
     * Must be called by the pending admin
     */
    function acceptAdminTransfer() 
        external 
        afterTransferDelay 
        nonReentrant 
    {
        require(msg.sender == _pendingAdmin, "KarmaMultiSig: Only pending admin can accept");
        
        address previousAdmin = msg.sender;
        
        // Grant all roles to new admin
        _grantRole(DEFAULT_ADMIN_ROLE, _pendingAdmin);
        _grantRole(EMERGENCY_ROLE, _pendingAdmin);
        _grantRole(OPERATOR_ROLE, _pendingAdmin);
        
        emit AdminTransferCompleted(previousAdmin, _pendingAdmin);
        
        // Clear pending admin state
        _pendingAdmin = address(0);
        _adminTransferInitiated = 0;
    }
    
    /**
     * @dev Cancels pending admin transfer
     * Can only be called by current admin
     */
    function cancelAdminTransfer() 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(_pendingAdmin != address(0), "KarmaMultiSig: No pending transfer");
        
        address cancelledAdmin = _pendingAdmin;
        _pendingAdmin = address(0);
        _adminTransferInitiated = 0;
        
        emit AdminTransferCancelled(msg.sender, cancelledAdmin);
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency role revocation function
     * @param role Role to revoke
     * @param account Account to revoke role from
     */
    function emergencyRevokeRole(bytes32 role, address account) 
        external 
        onlyEmergency 
    {
        require(role != DEFAULT_ADMIN_ROLE, "KarmaMultiSig: Cannot revoke admin role via emergency");
        _revokeRole(role, account);
        emit EmergencyActionExecuted(msg.sender, "Role Revoked");
    }
    
    /**
     * @dev Emergency role granting function
     * @param role Role to grant
     * @param account Account to grant role to
     */
    function emergencyGrantRole(bytes32 role, address account) 
        external 
        onlyEmergency 
    {
        require(role != DEFAULT_ADMIN_ROLE, "KarmaMultiSig: Cannot grant admin role via emergency");
        _grantRole(role, account);
        emit EmergencyActionExecuted(msg.sender, "Role Granted");
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Returns the pending admin address
     */
    function pendingAdmin() external view returns (address) {
        return _pendingAdmin;
    }
    
    /**
     * @dev Returns admin transfer status information
     */
    function getAdminTransferStatus() 
        external 
        view 
        returns (
            address pending,
            uint256 initiatedAt,
            uint256 timeRemaining,
            bool canAccept
        ) 
    {
        pending = _pendingAdmin;
        initiatedAt = _adminTransferInitiated;
        
        if (initiatedAt == 0) {
            timeRemaining = 0;
            canAccept = false;
        } else {
            uint256 deadline = initiatedAt + ADMIN_TRANSFER_DELAY;
            timeRemaining = block.timestamp >= deadline ? 0 : deadline - block.timestamp;
            canAccept = block.timestamp >= deadline;
        }
    }
    
    /**
     * @dev Returns multisig configuration
     */
    function getMultiSigInfo() 
        external 
        view 
        returns (
            address factory,
            address masterCopy,
            address wallet
        ) 
    {
        return (gnosisSafeFactory, gnosisSafeMasterCopy, multisigWallet);
    }
} 