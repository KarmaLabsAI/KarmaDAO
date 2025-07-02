// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMetadataStorage
 * @dev Interface for iNFT metadata storage and management on 0G blockchain
 * Stage 8.1 - Metadata and Storage Integration Requirements
 */
interface IMetadataStorage {
    
    // ============ ENUMS ============
    
    enum StorageType {
        INFT_METADATA,      // iNFT metadata storage
        AI_TRAINING_DATA,   // AI training data storage
        USER_CONTENT,       // User generated content
        SYSTEM_DATA,        // System configuration data
        ENCRYPTED_DATA,     // Encrypted private data
        PUBLIC_DATA         // Public accessible data
    }
    
    enum AccessLevel {
        PUBLIC,             // Publicly accessible
        RESTRICTED,         // Restricted access
        PRIVATE,            // Private access only
        ENCRYPTED           // Encrypted storage
    }
    
    enum StorageStatus {
        PENDING,            // Storage request pending
        STORING,            // Currently storing
        STORED,             // Successfully stored
        FAILED,             // Storage failed
        EXPIRED,            // Storage expired
        DELETED             // Storage deleted
    }
    
    // ============ STRUCTS ============
    
    struct StorageRequest {
        bytes32 requestId;
        address requester;
        StorageType storageType;
        AccessLevel accessLevel;
        bytes32 dataHash;
        uint256 dataSize;
        uint256 storageDuration;
        uint256 timestamp;
        uint256 expirationTime;
        StorageStatus status;
        string ipfsHash;
        bytes encryptionKey;
        address[] authorizedUsers;
        uint256 storageCost;
        uint256 accessCount;
    }
    
    struct StorageConfig {
        uint256 basePricePerMB;         // Base price per megabyte
        uint256 durationMultiplier;     // Multiplier for storage duration
        uint256 accessPricePerQuery;    // Price per access query
        uint256 encryptionSurcharge;    // Additional cost for encryption
        uint256 maxStorageDuration;     // Maximum storage duration
        uint256 maxFileSize;            // Maximum file size
        bool isActive;
    }
    
    struct StorageMetrics {
        uint256 totalStorageRequests;
        uint256 totalDataStored;        // In bytes
        uint256 totalStorageCost;
        uint256 averageStorageDuration;
        uint256 totalAccessCount;
        mapping(StorageType => uint256) storageByType;
        mapping(address => uint256) userStorageUsage;
    }
    
    struct AccessControl {
        address owner;
        mapping(address => bool) authorizedUsers;
        mapping(address => uint256) accessCount;
        mapping(address => uint256) lastAccessTime;
        bool isPublic;
        bool requiresPayment;
        uint256 accessPrice;
    }
    
    // ============ EVENTS ============
    
    event StorageRequested(
        bytes32 indexed requestId,
        address indexed requester,
        StorageType indexed storageType,
        uint256 dataSize,
        uint256 storageCost
    );
    
    event DataStored(
        bytes32 indexed requestId,
        address indexed requester,
        string ipfsHash,
        bytes32 dataHash
    );
    
    event DataAccessed(
        bytes32 indexed requestId,
        address indexed accessor,
        uint256 accessCost
    );
    
    event StorageExpired(
        bytes32 indexed requestId,
        address indexed requester,
        uint256 expirationTime
    );
    
    event AccessGranted(
        bytes32 indexed requestId,
        address indexed user,
        address indexed grantor
    );
    
    event StorageConfigUpdated(
        uint256 basePricePerMB,
        uint256 maxStorageDuration,
        uint256 maxFileSize
    );
    
    // ============ FUNCTIONS ============
    
    /**
     * @dev Request data storage on 0G blockchain
     */
    function requestStorage(
        StorageType storageType,
        AccessLevel accessLevel,
        bytes calldata data,
        uint256 storageDuration,
        address[] calldata authorizedUsers
    ) external payable returns (bytes32 requestId);
    
    /**
     * @dev Retrieve stored data
     */
    function retrieveData(
        bytes32 requestId,
        bytes calldata decryptionKey
    ) external payable returns (bytes memory data);
    
    /**
     * @dev Grant access to stored data
     */
    function grantAccess(
        bytes32 requestId,
        address user
    ) external;
    
    /**
     * @dev Revoke access to stored data
     */
    function revokeAccess(
        bytes32 requestId,
        address user
    ) external;
    
    /**
     * @dev Extend storage duration
     */
    function extendStorage(
        bytes32 requestId,
        uint256 additionalDuration
    ) external payable;
    
    /**
     * @dev Delete stored data
     */
    function deleteData(bytes32 requestId) external;
    
    /**
     * @dev Get storage request details
     */
    function getStorageRequest(bytes32 requestId) external view returns (StorageRequest memory);
    
    /**
     * @dev Calculate storage cost
     */
    function calculateStorageCost(
        StorageType storageType,
        AccessLevel accessLevel,
        uint256 dataSize,
        uint256 storageDuration
    ) external view returns (uint256 cost);
    
    /**
     * @dev Get storage configuration
     */
    function getStorageConfig() external view returns (StorageConfig memory);
    
    /**
     * @dev Get user storage metrics
     */
    function getUserStorageMetrics(address user) external view returns (
        uint256 totalRequests,
        uint256 totalDataStored,
        uint256 totalCost,
        uint256 totalAccesses
    );
    
    /**
     * @dev Verify data integrity
     */
    function verifyDataIntegrity(
        bytes32 requestId,
        bytes32 expectedHash
    ) external view returns (bool isValid);
} 