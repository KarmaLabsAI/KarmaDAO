// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IZeroGIntegration
 * @dev Interface for 0G blockchain integration and cross-chain communication
 * @notice Defines AI inference payment system and metadata storage integration
 */
interface IZeroGIntegration {
    // ============ EVENTS ============
    
    event CrossChainMessageSent(
        bytes32 indexed messageId,
        address indexed sender,
        address indexed recipient,
        uint256 chainId,
        bytes data
    );
    
    event CrossChainMessageReceived(
        bytes32 indexed messageId,
        address indexed sender,
        address indexed recipient,
        uint256 sourceChainId,
        bytes data
    );
    
    event AIInferenceRequested(
        bytes32 indexed requestId,
        address indexed user,
        string aiModel,
        uint256 complexity,
        uint256 estimatedCost
    );
    
    event AIInferenceCompleted(
        bytes32 indexed requestId,
        address indexed user,
        uint256 actualCost,
        string resultHash
    );
    
    event MetadataStored(
        bytes32 indexed dataId,
        address indexed owner,
        uint256 size,
        uint256 storageCost,
        string storageHash
    );
    
    event SettlementProcessed(
        bytes32 indexed settlementId,
        address indexed user,
        uint256 totalCost,
        uint256 karmaSpent
    );
    
    // ============ ENUMS ============
    
    enum MessageStatus {
        PENDING,
        SENT,
        DELIVERED,
        FAILED
    }
    
    enum InferenceStatus {
        REQUESTED,
        PROCESSING,
        COMPLETED,
        FAILED
    }
    
    enum StorageStatus {
        UPLOADING,
        STORED,
        VERIFIED,
        FAILED
    }
    
    // ============ STRUCTS ============
    
    struct CrossChainMessage {
        bytes32 messageId;
        address sender;
        address recipient;
        uint256 sourceChainId;
        uint256 targetChainId;
        bytes data;
        MessageStatus status;
        uint256 timestamp;
        uint256 gasLimit;
        uint256 fee;
    }
    
    struct AIInferenceRequest {
        bytes32 requestId;
        address user;
        string aiModel;
        string inputData;
        uint256 complexity;
        uint256 estimatedCost;
        uint256 actualCost;
        InferenceStatus status;
        string resultHash;
        uint256 timestamp;
    }
    
    struct MetadataStorage {
        bytes32 dataId;
        address owner;
        string contentHash;
        uint256 size;
        uint256 storageCost;
        StorageStatus status;
        uint256 timestamp;
        string encryptionKey;
        bool isPublic;
    }
    
    struct UsageReport {
        address user;
        uint256 computeUnits;
        uint256 storageUsed;
        uint256 dataTransferred;
        uint256 totalCost;
        uint256 timestamp;
    }
    
    // ============ CROSS-CHAIN COMMUNICATION ============
    
    /**
     * @dev Send cross-chain message to 0G blockchain
     * @param recipient Target address on 0G chain
     * @param data Message payload
     * @param gasLimit Gas limit for execution
     * @return messageId Unique identifier for the message
     */
    function sendCrossChainMessage(
        address recipient,
        bytes calldata data,
        uint256 gasLimit
    ) external payable returns (bytes32 messageId);
    
    /**
     * @dev Receive cross-chain message from 0G blockchain
     * @param messageId Unique message identifier
     * @param sender Original sender address
     * @param data Message payload
     */
    function receiveCrossChainMessage(
        bytes32 messageId,
        address sender,
        bytes calldata data
    ) external;
    
    /**
     * @dev Get cross-chain message details
     * @param messageId Message identifier
     * @return Message details
     */
    function getCrossChainMessage(bytes32 messageId) 
        external 
        view 
        returns (CrossChainMessage memory);
    
    // ============ AI INFERENCE PAYMENT SYSTEM ============
    
    /**
     * @dev Request AI inference with payment
     * @param aiModel AI model identifier
     * @param inputData Input data for inference
     * @param complexity Computational complexity estimate
     * @return requestId Unique request identifier
     */
    function requestAIInference(
        string memory aiModel,
        string memory inputData,
        uint256 complexity
    ) external returns (bytes32 requestId);
    
    /**
     * @dev Complete AI inference and settle payment
     * @param requestId Request identifier
     * @param resultHash Result data hash
     * @param actualCost Actual computational cost
     */
    function completeAIInference(
        bytes32 requestId,
        string memory resultHash,
        uint256 actualCost
    ) external;
    
    /**
     * @dev Get AI inference request details
     * @param requestId Request identifier
     * @return Request details
     */
    function getAIInferenceRequest(bytes32 requestId) 
        external 
        view 
        returns (AIInferenceRequest memory);
    
    // ============ METADATA AND STORAGE INTEGRATION ============
    
    /**
     * @dev Store metadata on 0G blockchain
     * @param contentHash Content hash (IPFS/0G)
     * @param size Data size in bytes
     * @param isPublic Whether data is publicly accessible
     * @param encryptionKey Encryption key for private data
     * @return dataId Unique storage identifier
     */
    function storeMetadata(
        string memory contentHash,
        uint256 size,
        bool isPublic,
        string memory encryptionKey
    ) external returns (bytes32 dataId);
    
    /**
     * @dev Retrieve metadata from storage
     * @param dataId Storage identifier
     * @return Storage details
     */
    function getStoredMetadata(bytes32 dataId) 
        external 
        view 
        returns (MetadataStorage memory);
    
    /**
     * @dev Verify metadata integrity
     * @param dataId Storage identifier
     * @param contentHash Expected content hash
     * @return verified Whether integrity check passed
     */
    function verifyMetadataIntegrity(
        bytes32 dataId,
        string memory contentHash
    ) external view returns (bool verified);
    
    // ============ ORACLE AND SETTLEMENT ============
    
    /**
     * @dev Report usage from 0G blockchain
     * @param user User address
     * @param computeUnits Compute units used
     * @param storageUsed Storage bytes used
     * @param dataTransferred Data transfer bytes
     * @param proof Usage proof from 0G
     */
    function reportUsage(
        address user,
        uint256 computeUnits,
        uint256 storageUsed,
        uint256 dataTransferred,
        bytes calldata proof
    ) external;
    
    /**
     * @dev Process settlement for accumulated usage
     * @param user User to settle for
     * @param reportIds Array of usage report IDs
     * @return settlementId Settlement identifier
     */
    function processSettlement(
        address user,
        bytes32[] calldata reportIds
    ) external returns (bytes32 settlementId);
    
    /**
     * @dev Get user usage summary
     * @param user User address
     * @return totalCompute Total compute units used
     * @return totalStorage Total storage used
     * @return totalTransfer Total data transferred
     * @return totalCost Total cost in KARMA
     */
    function getUserUsage(address user) 
        external 
        view 
        returns (
            uint256 totalCompute,
            uint256 totalStorage,
            uint256 totalTransfer,
            uint256 totalCost
        );
    
    // ============ CONFIGURATION AND MANAGEMENT ============
    
    /**
     * @dev Update pricing parameters
     * @param computePrice Price per compute unit in KARMA
     * @param storagePrice Price per storage byte in KARMA
     * @param transferPrice Price per transfer byte in KARMA
     */
    function updatePricing(
        uint256 computePrice,
        uint256 storagePrice,
        uint256 transferPrice
    ) external;
    
    /**
     * @dev Set 0G chain configuration
     * @param chainId 0G blockchain chain ID
     * @param bridgeAddress Bridge contract address on 0G
     * @param gasLimit Default gas limit for cross-chain calls
     */
    function configure0GChain(
        uint256 chainId,
        address bridgeAddress,
        uint256 gasLimit
    ) external;
    
    /**
     * @dev Add authorized AI service provider
     * @param provider Provider address
     * @param models Supported AI models
     */
    function addAIProvider(
        address provider,
        string[] memory models
    ) external;
    
    /**
     * @dev Emergency pause system
     * @param reason Pause reason
     */
    function emergencyPause(string memory reason) external;
    
    /**
     * @dev Resume system operations
     */
    function emergencyUnpause() external;
} 