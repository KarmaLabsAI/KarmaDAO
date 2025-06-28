// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAIInferencePayment
 * @dev Interface for AI inference payment system on 0G blockchain
 * Stage 8.1 - AI Inference Payment System Requirements
 */
interface IAIInferencePayment {
    
    // ============ ENUMS ============
    
    enum InferenceType {
        TEXT_GENERATION,        // Text generation models
        IMAGE_GENERATION,       // Image generation models
        CODE_GENERATION,        // Code generation models
        AUDIO_GENERATION,       // Audio generation models
        VIDEO_GENERATION,       // Video generation models
        MULTIMODAL,            // Multimodal models
        CUSTOM                 // Custom AI models
    }
    
    enum ModelComplexity {
        LIGHT,      // Light models (< 1B parameters)
        MEDIUM,     // Medium models (1B - 10B parameters)
        HEAVY,      // Heavy models (10B - 100B parameters)
        ULTRA       // Ultra models (> 100B parameters)
    }
    
    enum InferenceStatus {
        REQUESTED,      // Inference requested
        QUEUED,         // In processing queue
        PROCESSING,     // Currently processing
        COMPLETED,      // Successfully completed
        FAILED,         // Failed processing
        TIMEOUT,        // Request timeout
        CANCELLED       // Request cancelled
    }
    
    enum PriorityLevel {
        LOW,        // Low priority (cheapest)
        NORMAL,     // Normal priority
        HIGH,       // High priority (faster)
        URGENT      // Urgent priority (fastest, most expensive)
    }
    
    // ============ STRUCTS ============
    
    struct InferenceRequest {
        bytes32 requestId;
        address requester;
        InferenceType inferenceType;
        ModelComplexity complexity;
        PriorityLevel priority;
        bytes inputData;
        bytes outputData;
        uint256 estimatedCost;
        uint256 actualCost;
        uint256 timestamp;
        uint256 completionTime;
        InferenceStatus status;
        string modelName;
        uint256 inputTokens;
        uint256 outputTokens;
        uint256 computeUnits;
    }
    
    struct PricingModel {
        uint256 basePrice;              // Base price per compute unit
        uint256 complexityMultiplier;   // Multiplier based on model complexity
        uint256 priorityMultiplier;     // Multiplier based on priority
        uint256 tokenPrice;             // Price per token
        uint256 setupCost;              // One-time setup cost
        bool isActive;
    }
    
    struct InferenceMetrics {
        uint256 totalRequests;
        uint256 completedRequests;
        uint256 failedRequests;
        uint256 totalCost;
        uint256 averageProcessingTime;
        uint256 averageCost;
        mapping(InferenceType => uint256) requestsByType;
        mapping(ModelComplexity => uint256) requestsByComplexity;
    }
    
    struct QueueConfig {
        uint256 maxQueueSize;
        uint256 maxProcessingTime;
        uint256 priorityWeights;
        uint256 fairnessWeight;
        bool isActive;
    }
    
    // ============ EVENTS ============
    
    event InferenceRequested(
        bytes32 indexed requestId,
        address indexed requester,
        InferenceType indexed inferenceType,
        ModelComplexity complexity,
        uint256 estimatedCost
    );
    
    event InferenceCompleted(
        bytes32 indexed requestId,
        address indexed requester,
        uint256 actualCost,
        uint256 processingTime
    );
    
    event InferenceFailed(
        bytes32 indexed requestId,
        address indexed requester,
        string reason
    );
    
    event PricingModelUpdated(
        InferenceType indexed inferenceType,
        ModelComplexity indexed complexity,
        uint256 newPrice
    );
    
    event PaymentProcessed(
        bytes32 indexed requestId,
        address indexed payer,
        uint256 amount,
        address recipient
    );
    
    // ============ FUNCTIONS ============
    
    /**
     * @dev Request AI inference with payment
     */
    function requestInference(
        InferenceType inferenceType,
        ModelComplexity complexity,
        PriorityLevel priority,
        bytes calldata inputData,
        string calldata modelName
    ) external payable returns (bytes32 requestId);
    
    /**
     * @dev Complete inference request and process payment
     */
    function completeInference(
        bytes32 requestId,
        bytes calldata outputData,
        uint256 actualComputeUnits,
        uint256 inputTokens,
        uint256 outputTokens
    ) external;
    
    /**
     * @dev Cancel inference request and refund
     */
    function cancelInference(bytes32 requestId) external;
    
    /**
     * @dev Get inference request details
     */
    function getInferenceRequest(bytes32 requestId) external view returns (InferenceRequest memory);
    
    /**
     * @dev Calculate cost for inference request
     */
    function calculateInferenceCost(
        InferenceType inferenceType,
        ModelComplexity complexity,
        PriorityLevel priority,
        uint256 estimatedComputeUnits,
        uint256 estimatedTokens
    ) external view returns (uint256 cost);
    
    /**
     * @dev Get current pricing model
     */
    function getPricingModel(
        InferenceType inferenceType,
        ModelComplexity complexity
    ) external view returns (PricingModel memory);
    
    /**
     * @dev Get queue position for request
     */
    function getQueuePosition(bytes32 requestId) external view returns (uint256 position);
    
    /**
     * @dev Get inference metrics
     */
    function getInferenceMetrics(address user) external view returns (
        uint256 totalRequests,
        uint256 completedRequests,
        uint256 totalCost,
        uint256 averageCost
    );
} 