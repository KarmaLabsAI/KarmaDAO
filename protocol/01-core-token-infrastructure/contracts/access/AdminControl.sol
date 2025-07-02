// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./KarmaMultiSigManager.sol";
import "./KarmaTimelock.sol";

/**
 * @title AdminControl
 * @dev Unified administrative control system for the Karma protocol
 * Stage 1.2 - Administrative Control System
 */
contract AdminControl is AccessControl, ReentrancyGuard, Pausable {
    
    // ============ ROLES ============
    
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant MULTISIG_ADMIN_ROLE = keccak256("MULTISIG_ADMIN_ROLE");
    bytes32 public constant PROTOCOL_ADMIN_ROLE = keccak256("PROTOCOL_ADMIN_ROLE");
    
    // ============ STATE VARIABLES ============
    
    KarmaMultiSigManager public immutable multiSigManager;
    KarmaTimelock public immutable timelock;
    
    mapping(address => bool) public authorizedContracts;
    mapping(bytes32 => bool) public emergencyPausedRoles;
    
    uint256 public emergencyPauseDuration;
    uint256 public lastEmergencyPause;
    
    // ============ EVENTS ============
    
    event EmergencyPauseActivated(address indexed admin, uint256 duration);
    event EmergencyPauseDeactivated(address indexed admin);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event RoleEmergencyPaused(bytes32 indexed role, bool paused);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event MultiSigManagerUpdated(address indexed oldManager, address indexed newManager);
    event TimelockUpdated(address indexed oldTimelock, address indexed newTimelock);
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _multiSigManager,
        address payable _timelock,
        uint256 _emergencyPauseDuration
    ) {
        require(_multiSigManager != address(0), "AdminControl: Invalid multisig manager");
        require(_timelock != address(0), "AdminControl: Invalid timelock");
        require(_emergencyPauseDuration > 0, "AdminControl: Invalid pause duration");
        
        multiSigManager = KarmaMultiSigManager(_multiSigManager);
        timelock = KarmaTimelock(_timelock);
        emergencyPauseDuration = _emergencyPauseDuration;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ADMIN_ROLE, msg.sender);
        _grantRole(TIMELOCK_ADMIN_ROLE, _timelock);
        _grantRole(MULTISIG_ADMIN_ROLE, _multiSigManager);
    }
    
    // ============ MODIFIERS ============
    
    modifier onlyAuthorizedContract() {
        require(authorizedContracts[msg.sender], "AdminControl: Unauthorized contract");
        _;
    }
    
    modifier notEmergencyPaused() {
        require(!paused(), "AdminControl: Emergency pause active");
        _;
    }
    
    modifier validAddress(address _address) {
        require(_address != address(0), "AdminControl: Invalid address");
        _;
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    function emergencyPause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        require(!paused(), "AdminControl: Already paused");
        
        _pause();
        lastEmergencyPause = block.timestamp;
        
        emit EmergencyPauseActivated(msg.sender, emergencyPauseDuration);
    }
    
    function emergencyUnpause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        require(paused(), "AdminControl: Not paused");
        require(
            block.timestamp >= lastEmergencyPause + emergencyPauseDuration,
            "AdminControl: Pause duration not elapsed"
        );
        
        _unpause();
        
        emit EmergencyPauseDeactivated(msg.sender);
    }
    
    function emergencyRoleRevocation(
        bytes32 role,
        address account
    ) external onlyRole(EMERGENCY_ADMIN_ROLE) {
        require(hasRole(role, account), "AdminControl: Account does not have role");
        
        _revokeRole(role, account);
        emergencyPausedRoles[role] = true;
        
        emit RoleEmergencyPaused(role, true);
    }
    
    function restoreEmergencyRevokedRole(
        bytes32 role
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(emergencyPausedRoles[role], "AdminControl: Role not emergency paused");
        
        emergencyPausedRoles[role] = false;
        
        emit RoleEmergencyPaused(role, false);
    }
    
    // ============ CONTRACT AUTHORIZATION ============
    
    function authorizeContract(
        address contractAddress
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) validAddress(contractAddress) {
        authorizedContracts[contractAddress] = true;
        emit ContractAuthorized(contractAddress, true);
    }
    
    function deauthorizeContract(
        address contractAddress
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) validAddress(contractAddress) {
        authorizedContracts[contractAddress] = false;
        emit ContractAuthorized(contractAddress, false);
    }
    
    function batchAuthorizeContracts(
        address[] calldata contractAddresses,
        bool[] calldata authorizations
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) {
        require(
            contractAddresses.length == authorizations.length,
            "AdminControl: Arrays length mismatch"
        );
        
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            require(contractAddresses[i] != address(0), "AdminControl: Invalid address");
            authorizedContracts[contractAddresses[i]] = authorizations[i];
            emit ContractAuthorized(contractAddresses[i], authorizations[i]);
        }
    }
    
    // ============ ROLE MANAGEMENT ============
    
    function grantRoleWithTimelock(
        bytes32 role,
        address account
    ) external onlyRole(TIMELOCK_ADMIN_ROLE) notEmergencyPaused {
        require(!emergencyPausedRoles[role], "AdminControl: Role emergency paused");
        _grantRole(role, account);
    }
    
    function revokeRoleWithTimelock(
        bytes32 role,
        address account
    ) external onlyRole(TIMELOCK_ADMIN_ROLE) notEmergencyPaused {
        _revokeRole(role, account);
    }
    
    function transferAdmin(
        address newAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) validAddress(newAdmin) {
        address previousAdmin = msg.sender;
        
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, previousAdmin);
        
        emit AdminTransferred(previousAdmin, newAdmin);
    }
    
    // ============ MULTISIG INTEGRATION ============
    
    function executeMultiSigTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyRole(MULTISIG_ADMIN_ROLE) nonReentrant notEmergencyPaused returns (bytes memory) {
        require(authorizedContracts[target], "AdminControl: Target not authorized");
        
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "AdminControl: Transaction failed");
        
        return result;
    }
    
    // ============ TIMELOCK INTEGRATION ============
    
    function scheduleTimelockOperation(
        address target,
        uint256 value,
        bytes calldata data,
        KarmaTimelock.OperationType operationType
    ) external onlyRole(TIMELOCK_ADMIN_ROLE) returns (bytes32) {
        require(authorizedContracts[target], "AdminControl: Target not authorized");
        
        return timelock.queueOperation(target, value, data, operationType);
    }
    
    function executeTimelockOperation(
        bytes32 operationId
    ) external onlyRole(TIMELOCK_ADMIN_ROLE) nonReentrant notEmergencyPaused {
        timelock.executeOperation(operationId);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function isContractAuthorized(address contractAddress) external view returns (bool) {
        return authorizedContracts[contractAddress];
    }
    
    function isRoleEmergencyPaused(bytes32 role) external view returns (bool) {
        return emergencyPausedRoles[role];
    }
    
    function getAdminInfo() external view returns (
        address multiSigManagerAddress,
        address timelockAddress,
        uint256 pauseDuration,
        uint256 lastPause,
        bool isPaused
    ) {
        return (
            address(multiSigManager),
            address(timelock),
            emergencyPauseDuration,
            lastEmergencyPause,
            paused()
        );
    }
    
    function hasAnyRole(
        bytes32[] calldata roles,
        address account
    ) external view returns (bool) {
        for (uint256 i = 0; i < roles.length; i++) {
            if (hasRole(roles[i], account)) {
                return true;
            }
        }
        return false;
    }
    
    // ============ CONFIGURATION ============
    
    function updateEmergencyPauseDuration(
        uint256 newDuration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newDuration > 0, "AdminControl: Invalid duration");
        emergencyPauseDuration = newDuration;
    }
} 