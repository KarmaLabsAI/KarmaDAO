// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IMetadataStorage.sol";
import "../interfaces/I0GBridge.sol";

/**
 * @title KarmaMetadataStorage
 * @dev iNFT metadata storage and management on 0G blockchain
 * Stage 8.1 - Metadata and Storage Integration Implementation
 */
contract KarmaMetadataStorage is IMetadataStorage, AccessControl, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant STORAGE_MANAGER_ROLE = keccak256("STORAGE_MANAGER_ROLE");
    bytes32 public constant ACCESS_MANAGER_ROLE = keccak256("ACCESS_MANAGER_ROLE");
    bytes32 public constant PRICING_MANAGER_ROLE = keccak256("PRICING_MANAGER_ROLE");
    bytes32 public constant DATA_VALIDATOR_ROLE = keccak256("DATA_VALIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MAX_FILE_SIZE = 100 * 1024 * 1024; // 100MB
    uint256 public constant MAX_STORAGE_DURATION = 10 * 365 days; // 10 years
    uint256 public constant MIN_STORAGE_DURATION = 1 days;
    uint256 public constant BYTES_PER_MB = 1024 * 1024;
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaToken;
    address public bridge;
    address public treasury;
    address public aiInferencePayment;
    
    // Storage requests
    mapping(bytes32 => StorageRequest) private _storageRequests;
    mapping(address => bytes32[]) public requestsByUser;
    mapping(StorageType => bytes32[]) public requestsByType;
    mapping(StorageStatus => bytes32[]) public requestsByStatus;
    mapping(AccessLevel => bytes32[]) public requestsByAccessLevel;
    
    // Storage configuration
    StorageConfig private _storageConfig;
    
    // Access control for stored data
    mapping(bytes32 => AccessControl) private _accessControls;
    mapping(bytes32 => mapping(address => bool)) private _authorizedUsers;
    mapping(bytes32 => mapping(address => uint256)) private _userAccessCount;
    mapping(bytes32 => mapping(address => uint256)) private _lastAccessTime;
    
    // Data integrity tracking
    mapping(bytes32 => bytes32) public dataHashes;
    mapping(bytes32 => uint256) public verificationCount;
    mapping(bytes32 => mapping(address => bool)) public hasVerified;
    
    // Storage metrics (struct defined in IMetadataStorage interface)
    
    StorageMetrics private _storageMetrics;
    
    // Additional user cost tracking (not in interface struct)
    mapping(address => uint256) private _userStorageCosts;
    
    // IPFS integration
    mapping(bytes32 => string) public ipfsHashes;
    mapping(string => bytes32) public hashToRequestId;
    mapping(string => bool) public usedIPFSHashes;
    
    // Encryption management
    mapping(bytes32 => bool) public isEncrypted;
    mapping(bytes32 => bytes32) public encryptionKeyHashes;
    mapping(address => mapping(bytes32 => bytes)) private _userEncryptionKeys;
    
    // Request counter
    uint256 private _requestCounter;
    
    // ============ EVENTS ============
    
    event DataVerified(bytes32 indexed requestId, address indexed verifier, bool isValid);
    event EncryptionKeyUpdated(bytes32 indexed requestId, address indexed user);
    event IPFSHashUpdated(bytes32 indexed requestId, string ipfsHash);
    event StorageExtended(bytes32 indexed requestId, uint256 newExpirationTime);
    event StorageUpgraded(bytes32 indexed requestId, AccessLevel newAccessLevel);
    
    // ============ MODIFIERS ============
    
    modifier onlyStorageManager() {
        require(hasRole(STORAGE_MANAGER_ROLE, msg.sender), "KarmaStorage: Not storage manager");
        _;
    }
    
    modifier onlyAccessManager() {
        require(hasRole(ACCESS_MANAGER_ROLE, msg.sender), "KarmaStorage: Not access manager");
        _;
    }
    
    modifier onlyPricingManager() {
        require(hasRole(PRICING_MANAGER_ROLE, msg.sender), "KarmaStorage: Not pricing manager");
        _;
    }
    
    modifier validRequestId(bytes32 requestId) {
        require(_storageRequests[requestId].requestId != bytes32(0), "KarmaStorage: Invalid request ID");
        _;
    }
    
    modifier onlyDataOwner(bytes32 requestId) {
        require(_storageRequests[requestId].requester == msg.sender, "KarmaStorage: Not data owner");
        _;
    }
    
    modifier hasAccess(bytes32 requestId) {
        StorageRequest memory request = _storageRequests[requestId];
        require(
            request.requester == msg.sender ||
            _authorizedUsers[requestId][msg.sender] ||
            request.accessLevel == AccessLevel.PUBLIC,
            "KarmaStorage: Access denied"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _bridge,
        address _treasury,
        address _admin
    ) {
        karmaToken = _karmaToken;
        bridge = _bridge;
        treasury = _treasury;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(STORAGE_MANAGER_ROLE, _admin);
        _grantRole(ACCESS_MANAGER_ROLE, _admin);
        _grantRole(PRICING_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize storage configuration
        _storageConfig = StorageConfig({
            basePricePerMB: 0.001 ether,
            durationMultiplier: 100, // 1.0x base
            accessPricePerQuery: 0.0001 ether,
            encryptionSurcharge: 0.01 ether,
            maxStorageDuration: MAX_STORAGE_DURATION,
            maxFileSize: MAX_FILE_SIZE,
            isActive: true
        });
    }
    
    // ============ EXTERNAL FUNCTIONS ============
    
    /**
     * @dev Request data storage on 0G blockchain
     */
    function requestStorage(
        StorageType storageType,
        AccessLevel accessLevel,
        bytes calldata data,
        uint256 storageDuration,
        address[] calldata authorizedUsers
    ) external payable whenNotPaused nonReentrant returns (bytes32 requestId) {
        require(_storageConfig.isActive, "KarmaStorage: Storage not active");
        require(data.length > 0, "KarmaStorage: Empty data");
        require(data.length <= _storageConfig.maxFileSize, "KarmaStorage: File too large");
        require(storageDuration >= MIN_STORAGE_DURATION, "KarmaStorage: Duration too short");
        require(storageDuration <= _storageConfig.maxStorageDuration, "KarmaStorage: Duration too long");
        
        // Calculate storage cost
        uint256 storageCost = calculateStorageCost(storageType, accessLevel, data.length, storageDuration);
        require(msg.value >= storageCost, "KarmaStorage: Insufficient payment");
        
        // Generate request ID
        requestId = keccak256(
            abi.encodePacked(
                msg.sender,
                storageType,
                accessLevel,
                data,
                storageDuration,
                _requestCounter++,
                block.timestamp
            )
        );
        
        // Calculate data hash
        bytes32 dataHash = keccak256(data);
        
        // Create storage request
        StorageRequest storage request = _storageRequests[requestId];
        request.requestId = requestId;
        request.requester = msg.sender;
        request.storageType = storageType;
        request.accessLevel = accessLevel;
        request.dataHash = dataHash;
        request.dataSize = data.length;
        request.storageDuration = storageDuration;
        request.timestamp = block.timestamp;
        request.expirationTime = block.timestamp + storageDuration;
        request.status = StorageStatus.PENDING;
        request.storageCost = storageCost;
        request.accessCount = 0;
        
        // Set up access control
        if (authorizedUsers.length > 0) {
            for (uint256 i = 0; i < authorizedUsers.length; i++) {
                _authorizedUsers[requestId][authorizedUsers[i]] = true;
            }
            request.authorizedUsers = authorizedUsers;
        }
        
        // Handle encryption for private/encrypted data
        if (accessLevel == AccessLevel.ENCRYPTED) {
            isEncrypted[requestId] = true;
            // In production, would generate and manage encryption keys
            bytes32 keyHash = keccak256(abi.encodePacked(requestId, msg.sender, block.timestamp));
            encryptionKeyHashes[requestId] = keyHash;
        }
        
        // Track request
        requestsByUser[msg.sender].push(requestId);
        requestsByType[storageType].push(requestId);
        requestsByStatus[StorageStatus.PENDING].push(requestId);
        requestsByAccessLevel[accessLevel].push(requestId);
        
        // Update metrics
        _storageMetrics.totalStorageRequests++;
        _storageMetrics.totalDataStored += data.length;
        _storageMetrics.totalStorageCost += storageCost;
        _storageMetrics.storageByType[storageType] += data.length;
        _storageMetrics.userStorageUsage[msg.sender] += data.length;
        _userStorageCosts[msg.sender] += storageCost;
        
        if (_storageMetrics.totalStorageRequests > 0) {
            _storageMetrics.averageStorageDuration = 
                (_storageMetrics.averageStorageDuration * (_storageMetrics.totalStorageRequests - 1) + storageDuration) / 
                _storageMetrics.totalStorageRequests;
        }
        
        // Store data hash for integrity verification
        dataHashes[requestId] = dataHash;
        
        // Transfer payment to treasury
        if (storageCost > 0) {
            (bool success, ) = treasury.call{value: storageCost}("");
            require(success, "KarmaStorage: Payment transfer failed");
        }
        
        // Refund excess payment
        if (msg.value > storageCost) {
            uint256 refund = msg.value - storageCost;
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "KarmaStorage: Refund failed");
        }
        
        emit StorageRequested(requestId, msg.sender, storageType, data.length, storageCost);
    }
    
    /**
     * @dev Mark data as stored (called by storage validators)
     */
    function markDataStored(
        bytes32 requestId,
        string calldata ipfsHash
    ) external onlyStorageManager validRequestId(requestId) {
        require(!usedIPFSHashes[ipfsHash], "KarmaStorage: IPFS hash already used");
        require(_storageRequests[requestId].status == StorageStatus.PENDING, "KarmaStorage: Invalid status");
        
        // Update request
        _storageRequests[requestId].status = StorageStatus.STORED;
        _storageRequests[requestId].ipfsHash = ipfsHash;
        
        // Update tracking
        ipfsHashes[requestId] = ipfsHash;
        hashToRequestId[ipfsHash] = requestId;
        usedIPFSHashes[ipfsHash] = true;
        
        _updateRequestStatus(requestId, StorageStatus.PENDING, StorageStatus.STORED);
        
        emit DataStored(requestId, _storageRequests[requestId].requester, ipfsHash, _storageRequests[requestId].dataHash);
        emit IPFSHashUpdated(requestId, ipfsHash);
    }
    
    /**
     * @dev Retrieve stored data
     */
    function retrieveData(
        bytes32 requestId,
        bytes calldata decryptionKey
    ) external payable hasAccess(requestId) returns (bytes memory data) {
        StorageRequest storage request = _storageRequests[requestId];
        require(request.status == StorageStatus.STORED, "KarmaStorage: Data not stored");
        require(block.timestamp <= request.expirationTime, "KarmaStorage: Storage expired");
        
        // Check access payment for non-public data
        if (request.accessLevel != AccessLevel.PUBLIC && msg.sender != request.requester) {
            uint256 accessCost = _storageConfig.accessPricePerQuery;
            require(msg.value >= accessCost, "KarmaStorage: Insufficient access payment");
            
            // Transfer access fee to treasury
            (bool success, ) = treasury.call{value: accessCost}("");
            require(success, "KarmaStorage: Access fee transfer failed");
        }
        
        // Update access tracking
        request.accessCount++;
        _userAccessCount[requestId][msg.sender]++;
        _lastAccessTime[requestId][msg.sender] = block.timestamp;
        _storageMetrics.totalAccessCount++;
        
        // Handle encryption for encrypted data
        if (isEncrypted[requestId]) {
            require(decryptionKey.length > 0, "KarmaStorage: Decryption key required");
            // In production, would verify decryption key
            bytes32 providedKeyHash = keccak256(decryptionKey);
            // Simplified verification - in production would be more sophisticated
        }
        
        // In production, would retrieve actual data from IPFS/0G storage
        // For now, return a placeholder indicating successful access
        data = abi.encode("DATA_ACCESS_GRANTED", requestId, request.ipfsHash);
        
        emit DataAccessed(requestId, msg.sender, msg.value);
    }
    
    /**
     * @dev Grant access to stored data
     */
    function grantAccess(
        bytes32 requestId,
        address user
    ) external onlyDataOwner(requestId) validRequestId(requestId) {
        require(user != address(0), "KarmaStorage: Invalid user");
        require(!_authorizedUsers[requestId][user], "KarmaStorage: Already authorized");
        
        _authorizedUsers[requestId][user] = true;
        
        // Add to authorized users array
        _storageRequests[requestId].authorizedUsers.push(user);
        
        emit AccessGranted(requestId, user, msg.sender);
    }
    
    /**
     * @dev Revoke access to stored data
     */
    function revokeAccess(
        bytes32 requestId,
        address user
    ) external onlyDataOwner(requestId) validRequestId(requestId) {
        require(_authorizedUsers[requestId][user], "KarmaStorage: Not authorized");
        
        _authorizedUsers[requestId][user] = false;
        
        // Remove from authorized users array
        address[] storage authorizedUsers = _storageRequests[requestId].authorizedUsers;
        for (uint256 i = 0; i < authorizedUsers.length; i++) {
            if (authorizedUsers[i] == user) {
                authorizedUsers[i] = authorizedUsers[authorizedUsers.length - 1];
                authorizedUsers.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Extend storage duration
     */
    function extendStorage(
        bytes32 requestId,
        uint256 additionalDuration
    ) external payable onlyDataOwner(requestId) validRequestId(requestId) {
        StorageRequest storage request = _storageRequests[requestId];
        require(request.status == StorageStatus.STORED, "KarmaStorage: Data not stored");
        require(additionalDuration > 0, "KarmaStorage: Invalid duration");
        
        uint256 newExpirationTime = request.expirationTime + additionalDuration;
        require(
            newExpirationTime <= request.timestamp + _storageConfig.maxStorageDuration,
            "KarmaStorage: Exceeds max duration"
        );
        
        // Calculate additional cost
        uint256 additionalCost = calculateStorageCost(
            request.storageType,
            request.accessLevel,
            request.dataSize,
            additionalDuration
        );
        
        require(msg.value >= additionalCost, "KarmaStorage: Insufficient payment");
        
        // Update request
        request.expirationTime = newExpirationTime;
        request.storageDuration += additionalDuration;
        request.storageCost += additionalCost;
        
        // Update metrics
        _storageMetrics.totalStorageCost += additionalCost;
        _userStorageCosts[msg.sender] += additionalCost;
        
        // Transfer payment to treasury
        (bool success, ) = treasury.call{value: additionalCost}("");
        require(success, "KarmaStorage: Payment transfer failed");
        
        emit StorageExtended(requestId, newExpirationTime);
    }
    
    /**
     * @dev Delete stored data
     */
    function deleteData(bytes32 requestId) external onlyDataOwner(requestId) validRequestId(requestId) {
        StorageRequest storage request = _storageRequests[requestId];
        require(request.status == StorageStatus.STORED, "KarmaStorage: Data not stored");
        
        // Update status
        request.status = StorageStatus.DELETED;
        _updateRequestStatus(requestId, StorageStatus.STORED, StorageStatus.DELETED);
        
        // Clean up IPFS tracking
        string memory ipfsHash = request.ipfsHash;
        delete ipfsHashes[requestId];
        delete hashToRequestId[ipfsHash];
        delete usedIPFSHashes[ipfsHash];
        
        // Clean up encryption data
        if (isEncrypted[requestId]) {
            delete isEncrypted[requestId];
            delete encryptionKeyHashes[requestId];
        }
    }
    
    /**
     * @dev Calculate storage cost
     */
    function calculateStorageCost(
        StorageType storageType,
        AccessLevel accessLevel,
        uint256 dataSize,
        uint256 storageDuration
    ) public view returns (uint256 cost) {
        // Base cost calculation
        uint256 dataSizeInMB = (dataSize + BYTES_PER_MB - 1) / BYTES_PER_MB; // Round up
        cost = dataSizeInMB * _storageConfig.basePricePerMB;
        
        // Apply duration multiplier
        cost = cost * storageDuration * _storageConfig.durationMultiplier / (30 days * 100);
        
        // Apply storage type multiplier
        if (storageType == StorageType.AI_TRAINING_DATA) cost = cost * 150 / 100; // 1.5x
        else if (storageType == StorageType.ENCRYPTED_DATA) cost = cost * 200 / 100; // 2x
        else if (storageType == StorageType.SYSTEM_DATA) cost = cost * 120 / 100; // 1.2x
        
        // Apply access level surcharge
        if (accessLevel == AccessLevel.ENCRYPTED) {
            cost += _storageConfig.encryptionSurcharge;
        } else if (accessLevel == AccessLevel.PRIVATE) {
            cost = cost * 110 / 100; // 1.1x
        }
    }
    
    /**
     * @dev Get storage request details
     */
    function getStorageRequest(bytes32 requestId) external view returns (StorageRequest memory) {
        return _storageRequests[requestId];
    }
    
    /**
     * @dev Get storage configuration
     */
    function getStorageConfig() external view returns (StorageConfig memory) {
        return _storageConfig;
    }
    
    /**
     * @dev Get user storage metrics
     */
    function getUserStorageMetrics(address user) external view returns (
        uint256 totalRequests,
        uint256 totalDataStored,
        uint256 totalCost,
        uint256 totalAccesses
    ) {
        bytes32[] memory userRequests = requestsByUser[user];
        totalRequests = userRequests.length;
        totalDataStored = _storageMetrics.userStorageUsage[user];
        totalCost = _userStorageCosts[user];
        
        // Calculate total accesses
        for (uint256 i = 0; i < userRequests.length; i++) {
            totalAccesses += _storageRequests[userRequests[i]].accessCount;
        }
    }
    
    /**
     * @dev Verify data integrity
     */
    function verifyDataIntegrity(
        bytes32 requestId,
        bytes32 expectedHash
    ) external view validRequestId(requestId) returns (bool isValid) {
        return dataHashes[requestId] == expectedHash;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Update storage configuration
     */
    function updateStorageConfig(
        uint256 basePricePerMB,
        uint256 durationMultiplier,
        uint256 accessPricePerQuery,
        uint256 encryptionSurcharge,
        uint256 maxStorageDuration,
        uint256 maxFileSize,
        bool isActive
    ) external onlyPricingManager {
        _storageConfig.basePricePerMB = basePricePerMB;
        _storageConfig.durationMultiplier = durationMultiplier;
        _storageConfig.accessPricePerQuery = accessPricePerQuery;
        _storageConfig.encryptionSurcharge = encryptionSurcharge;
        _storageConfig.maxStorageDuration = maxStorageDuration;
        _storageConfig.maxFileSize = maxFileSize;
        _storageConfig.isActive = isActive;
        
        emit StorageConfigUpdated(basePricePerMB, maxStorageDuration, maxFileSize);
    }
    
    /**
     * @dev Handle expired storage (cleanup)
     */
    function cleanupExpiredStorage(bytes32[] calldata requestIds) external onlyStorageManager {
        for (uint256 i = 0; i < requestIds.length; i++) {
            bytes32 requestId = requestIds[i];
            StorageRequest storage request = _storageRequests[requestId];
            
            if (request.status == StorageStatus.STORED && 
                block.timestamp > request.expirationTime) {
                
                request.status = StorageStatus.EXPIRED;
                _updateRequestStatus(requestId, StorageStatus.STORED, StorageStatus.EXPIRED);
                
                emit StorageExpired(requestId, request.requester, request.expirationTime);
            }
        }
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Update request status tracking
     */
    function _updateRequestStatus(
        bytes32 requestId,
        StorageStatus oldStatus,
        StorageStatus newStatus
    ) internal {
        // Remove from old status array
        bytes32[] storage oldArray = requestsByStatus[oldStatus];
        for (uint256 i = 0; i < oldArray.length; i++) {
            if (oldArray[i] == requestId) {
                oldArray[i] = oldArray[oldArray.length - 1];
                oldArray.pop();
                break;
            }
        }
        
        // Add to new status array
        requestsByStatus[newStatus].push(requestId);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get global storage metrics
     */
    function getGlobalStorageMetrics() external view returns (
        uint256 totalRequests,
        uint256 totalDataStored,
        uint256 totalCost,
        uint256 totalAccesses,
        uint256 averageDuration
    ) {
        return (
            _storageMetrics.totalStorageRequests,
            _storageMetrics.totalDataStored,
            _storageMetrics.totalStorageCost,
            _storageMetrics.totalAccessCount,
            _storageMetrics.averageStorageDuration
        );
    }
    
    /**
     * @dev Get user requests
     */
    function getUserRequests(address user) external view returns (bytes32[] memory) {
        return requestsByUser[user];
    }
    
    /**
     * @dev Get requests by type
     */
    function getRequestsByType(StorageType storageType) external view returns (bytes32[] memory) {
        return requestsByType[storageType];
    }
    
    /**
     * @dev Check if user has access to data
     */
    function hasAccessToData(bytes32 requestId, address user) external view returns (bool) {
        StorageRequest memory request = _storageRequests[requestId];
        return request.requester == user || 
               _authorizedUsers[requestId][user] || 
               request.accessLevel == AccessLevel.PUBLIC;
    }
} 