// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IAIInferencePayment.sol";
import "../interfaces/I0GBridge.sol";

/**
 * @title KarmaAIInferencePayment
 * @dev AI inference payment system with dynamic pricing and queue management
 * Stage 8.1 - AI Inference Payment System Implementation
 */
contract KarmaAIInferencePayment is IAIInferencePayment, AccessControl, Pausable, ReentrancyGuard {
    using Math for uint256;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant AI_PAYMENT_MANAGER_ROLE = keccak256("AI_PAYMENT_MANAGER_ROLE");
    bytes32 public constant INFERENCE_EXECUTOR_ROLE = keccak256("INFERENCE_EXECUTOR_ROLE");
    bytes32 public constant PRICING_MANAGER_ROLE = keccak256("PRICING_MANAGER_ROLE");
    bytes32 public constant QUEUE_MANAGER_ROLE = keccak256("QUEUE_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MAX_QUEUE_SIZE = 10000;
    uint256 public constant MAX_PROCESSING_TIME = 1 hours;
    uint256 public constant MIN_COMPUTE_UNITS = 1;
    uint256 public constant MAX_COMPUTE_UNITS = 1000000;
    uint256 public constant BASE_TIMEOUT = 30 minutes;
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaToken;
    address public bridge;
    address public treasury;
    address public oracle;
    
    // Inference requests
    mapping(bytes32 => InferenceRequest) private _inferenceRequests;
    mapping(address => bytes32[]) public requestsByUser;
    mapping(InferenceType => bytes32[]) public requestsByType;
    mapping(InferenceStatus => bytes32[]) public requestsByStatus;
    mapping(ModelComplexity => bytes32[]) public requestsByComplexity;
    
    // Pricing models
    mapping(InferenceType => mapping(ModelComplexity => PricingModel)) private _pricingModels;
    mapping(string => bool) public supportedModels;
    mapping(string => ModelComplexity) public modelComplexity;
    mapping(string => InferenceType) public modelTypes;
    
    // Queue management
    bytes32[] public processingQueue;
    mapping(PriorityLevel => bytes32[]) public queuesByPriority;
    mapping(bytes32 => uint256) public queuePositions;
    uint256 public currentQueueSize;
    
    struct QueueConfig {
        uint256 maxQueueSize;
        uint256 maxProcessingTime;
        uint256[4] priorityWeights; // Weights for LOW, NORMAL, HIGH, URGENT
        uint256 fairnessWeight;
        bool isActive;
    }
    
    QueueConfig private _queueConfig;
    
    // Inference metrics (struct defined in IAIInferencePayment interface)
    
    InferenceMetrics private _inferenceMetrics;
    
    // Additional user metrics tracking (not in interface struct)
    mapping(address => uint256) private _userRequests;
    mapping(address => uint256) private _userSpending;
    
    // User management
    mapping(address => uint256) public userTotalSpent;
    mapping(address => uint256) public userRequestCount;
    mapping(address => uint256) public userLastRequest;
    mapping(address => bool) public isVIPUser;
    mapping(address => uint256) public userPriorityMultiplier; // 100 = 1x, 200 = 2x, etc.
    
    // Request counter
    uint256 private _requestCounter;
    
    // ============ EVENTS ============
    
    event ModelAdded(string indexed modelName, InferenceType inferenceType, ModelComplexity complexity);
    event ModelRemoved(string indexed modelName);
    event VIPStatusUpdated(address indexed user, bool isVIP);
    event QueuePositionUpdated(bytes32 indexed requestId, uint256 newPosition);
    event ProcessingStarted(bytes32 indexed requestId, uint256 timestamp);
    event PricingModelUpdated(InferenceType indexed inferenceType, ModelComplexity indexed complexity);
    
    // ============ MODIFIERS ============
    
    modifier onlyAIPaymentManager() {
        require(hasRole(AI_PAYMENT_MANAGER_ROLE, msg.sender), "KarmaAI: Not AI payment manager");
        _;
    }
    
    modifier onlyInferenceExecutor() {
        require(hasRole(INFERENCE_EXECUTOR_ROLE, msg.sender), "KarmaAI: Not inference executor");
        _;
    }
    
    modifier onlyPricingManager() {
        require(hasRole(PRICING_MANAGER_ROLE, msg.sender), "KarmaAI: Not pricing manager");
        _;
    }
    
    modifier validRequestId(bytes32 requestId) {
        require(_inferenceRequests[requestId].requestId != bytes32(0), "KarmaAI: Invalid request ID");
        _;
    }
    
    modifier supportedModel(string calldata modelName) {
        require(supportedModels[modelName], "KarmaAI: Unsupported model");
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
        _grantRole(AI_PAYMENT_MANAGER_ROLE, _admin);
        _grantRole(PRICING_MANAGER_ROLE, _admin);
        _grantRole(QUEUE_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize queue configuration
        _queueConfig = QueueConfig({
            maxQueueSize: MAX_QUEUE_SIZE,
            maxProcessingTime: MAX_PROCESSING_TIME,
            priorityWeights: [uint256(25), 50, 100, 200], // LOW, NORMAL, HIGH, URGENT
            fairnessWeight: 10,
            isActive: true
        });
        
        // Initialize default pricing models
        _initializeDefaultPricingModels();
    }
    
    // ============ EXTERNAL FUNCTIONS ============
    
    /**
     * @dev Request AI inference with payment
     */
    function requestInference(
        InferenceType inferenceType,
        ModelComplexity complexity,
        PriorityLevel priority,
        bytes calldata inputData,
        string calldata modelName
    ) external payable whenNotPaused nonReentrant supportedModel(modelName) returns (bytes32 requestId) {
        require(_queueConfig.isActive, "KarmaAI: Queue not active");
        require(currentQueueSize < _queueConfig.maxQueueSize, "KarmaAI: Queue full");
        require(inputData.length > 0, "KarmaAI: Empty input data");
        
        // Estimate compute units and tokens (simplified calculation)
        uint256 estimatedComputeUnits = _estimateComputeUnits(inferenceType, complexity, inputData.length);
        uint256 estimatedTokens = _estimateTokens(inferenceType, inputData.length);
        
        // Calculate cost
        uint256 estimatedCost = calculateInferenceCost(
            inferenceType,
            complexity,
            priority,
            estimatedComputeUnits,
            estimatedTokens
        );
        
        require(msg.value >= estimatedCost, "KarmaAI: Insufficient payment");
        
        // Generate request ID
        requestId = keccak256(
            abi.encodePacked(
                msg.sender,
                inferenceType,
                complexity,
                modelName,
                inputData,
                _requestCounter++,
                block.timestamp
            )
        );
        
        // Create inference request
        InferenceRequest storage request = _inferenceRequests[requestId];
        request.requestId = requestId;
        request.requester = msg.sender;
        request.inferenceType = inferenceType;
        request.complexity = complexity;
        request.priority = priority;
        request.inputData = inputData;
        request.estimatedCost = estimatedCost;
        request.actualCost = 0;
        request.timestamp = block.timestamp;
        request.completionTime = 0;
        request.status = InferenceStatus.REQUESTED;
        request.modelName = modelName;
        request.inputTokens = estimatedTokens;
        request.outputTokens = 0;
        request.computeUnits = estimatedComputeUnits;
        
        // Track request
        requestsByUser[msg.sender].push(requestId);
        requestsByType[inferenceType].push(requestId);
        requestsByStatus[InferenceStatus.REQUESTED].push(requestId);
        requestsByComplexity[complexity].push(requestId);
        
        // Add to queue
        _addToQueue(requestId, priority);
        
        // Update metrics
        _inferenceMetrics.totalRequests++;
        _inferenceMetrics.requestsByType[inferenceType]++;
        _inferenceMetrics.requestsByComplexity[complexity]++;
        _userRequests[msg.sender]++;
        
        // Update user data
        userRequestCount[msg.sender]++;
        userLastRequest[msg.sender] = block.timestamp;
        
        // Refund excess payment
        if (msg.value > estimatedCost) {
            uint256 refund = msg.value - estimatedCost;
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "KarmaAI: Refund failed");
        }
        
        emit InferenceRequested(requestId, msg.sender, inferenceType, complexity, estimatedCost);
    }
    
    /**
     * @dev Complete inference request and process payment
     */
    function completeInference(
        bytes32 requestId,
        bytes calldata outputData,
        uint256 actualComputeUnits,
        uint256 inputTokens,
        uint256 outputTokens
    ) external onlyInferenceExecutor validRequestId(requestId) {
        InferenceRequest storage request = _inferenceRequests[requestId];
        require(request.status == InferenceStatus.PROCESSING, "KarmaAI: Not in processing");
        require(outputData.length > 0, "KarmaAI: Empty output data");
        
        // Calculate actual cost
        uint256 actualCost = calculateInferenceCost(
            request.inferenceType,
            request.complexity,
            request.priority,
            actualComputeUnits,
            inputTokens + outputTokens
        );
        
        // Update request
        request.outputData = outputData;
        request.actualCost = actualCost;
        request.completionTime = block.timestamp;
        request.status = InferenceStatus.COMPLETED;
        request.inputTokens = inputTokens;
        request.outputTokens = outputTokens;
        request.computeUnits = actualComputeUnits;
        
        // Update tracking
        _updateRequestStatus(requestId, InferenceStatus.PROCESSING, InferenceStatus.COMPLETED);
        _removeFromQueue(requestId);
        
        // Update metrics
        _inferenceMetrics.completedRequests++;
        _inferenceMetrics.totalCost += actualCost;
        _userSpending[request.requester] += actualCost;
        
        uint256 processingTime = block.timestamp - request.timestamp;
        _inferenceMetrics.averageProcessingTime = 
            (_inferenceMetrics.averageProcessingTime * (_inferenceMetrics.completedRequests - 1) + processingTime) / 
            _inferenceMetrics.completedRequests;
        _inferenceMetrics.averageCost = _inferenceMetrics.totalCost / _inferenceMetrics.completedRequests;
        
        // Update user data
        userTotalSpent[request.requester] += actualCost;
        
        // Handle cost difference
        if (actualCost > request.estimatedCost) {
            // Charge additional amount - in production would handle via escrow
            uint256 additional = actualCost - request.estimatedCost;
            // For now, we'll absorb the difference and emit an event
            emit PaymentProcessed(requestId, request.requester, additional, treasury);
        } else if (actualCost < request.estimatedCost) {
            // Refund difference
            uint256 refund = request.estimatedCost - actualCost;
            (bool success, ) = request.requester.call{value: refund}("");
            require(success, "KarmaAI: Refund failed");
        }
        
        emit InferenceCompleted(requestId, request.requester, actualCost, processingTime);
    }
    
    /**
     * @dev Cancel inference request and refund
     */
    function cancelInference(bytes32 requestId) external validRequestId(requestId) {
        InferenceRequest storage request = _inferenceRequests[requestId];
        require(
            request.requester == msg.sender || hasRole(AI_PAYMENT_MANAGER_ROLE, msg.sender),
            "KarmaAI: Not authorized"
        );
        require(
            request.status == InferenceStatus.REQUESTED || request.status == InferenceStatus.QUEUED,
            "KarmaAI: Cannot cancel"
        );
        
        // Update status
        InferenceStatus oldStatus = request.status;
        request.status = InferenceStatus.CANCELLED;
        _updateRequestStatus(requestId, oldStatus, InferenceStatus.CANCELLED);
        
        // Remove from queue if queued
        if (oldStatus == InferenceStatus.QUEUED) {
            _removeFromQueue(requestId);
        }
        
        // Process refund
        uint256 refundAmount = request.estimatedCost;
        if (refundAmount > 0) {
            (bool success, ) = request.requester.call{value: refundAmount}("");
            require(success, "KarmaAI: Refund failed");
        }
        
        emit InferenceFailed(requestId, request.requester, "Cancelled by user");
    }
    
    /**
     * @dev Calculate cost for inference request
     */
    function calculateInferenceCost(
        InferenceType inferenceType,
        ModelComplexity complexity,
        PriorityLevel priority,
        uint256 estimatedComputeUnits,
        uint256 estimatedTokens
    ) public view returns (uint256 cost) {
        PricingModel memory pricing = _pricingModels[inferenceType][complexity];
        require(pricing.isActive, "KarmaAI: Pricing not active");
        
        // Base cost calculation
        cost = pricing.setupCost;
        cost += estimatedComputeUnits * pricing.basePrice * pricing.complexityMultiplier / 100;
        cost += estimatedTokens * pricing.tokenPrice;
        
        // Apply priority multiplier
        uint256 priorityMultiplier = _getPriorityMultiplier(priority);
        cost = cost * priorityMultiplier / 100;
        
        // Apply user priority multiplier if VIP
        if (isVIPUser[msg.sender] && userPriorityMultiplier[msg.sender] > 0) {
            cost = cost * userPriorityMultiplier[msg.sender] / 100;
        }
    }
    
    /**
     * @dev Get inference request details
     */
    function getInferenceRequest(bytes32 requestId) external view returns (InferenceRequest memory) {
        return _inferenceRequests[requestId];
    }
    
    /**
     * @dev Get current pricing model
     */
    function getPricingModel(
        InferenceType inferenceType,
        ModelComplexity complexity
    ) external view returns (PricingModel memory) {
        return _pricingModels[inferenceType][complexity];
    }
    
    /**
     * @dev Get queue position for request
     */
    function getQueuePosition(bytes32 requestId) external view returns (uint256 position) {
        return queuePositions[requestId];
    }
    
    /**
     * @dev Get inference metrics
     */
    function getInferenceMetrics(address user) external view returns (
        uint256 totalRequests,
        uint256 completedRequests,
        uint256 totalCost,
        uint256 averageCost
    ) {
        if (user != address(0)) {
            return (
                _userRequests[user],
                _userRequests[user], // Simplified - would track per user
                _userSpending[user],
                _userRequests[user] > 0 ? 
                    _userSpending[user] / _userRequests[user] : 0
            );
        } else {
            return (
                _inferenceMetrics.totalRequests,
                _inferenceMetrics.completedRequests,
                _inferenceMetrics.totalCost,
                _inferenceMetrics.averageCost
            );
        }
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Add supported AI model
     */
    function addModel(
        string calldata modelName,
        InferenceType inferenceType,
        ModelComplexity complexity
    ) external onlyAIPaymentManager {
        supportedModels[modelName] = true;
        modelTypes[modelName] = inferenceType;
        modelComplexity[modelName] = complexity;
        
        emit ModelAdded(modelName, inferenceType, complexity);
    }
    
    /**
     * @dev Remove supported AI model
     */
    function removeModel(string calldata modelName) external onlyAIPaymentManager {
        supportedModels[modelName] = false;
        delete modelTypes[modelName];
        delete modelComplexity[modelName];
        
        emit ModelRemoved(modelName);
    }
    
    /**
     * @dev Update pricing model
     */
    function updatePricingModel(
        InferenceType inferenceType,
        ModelComplexity complexity,
        uint256 basePrice,
        uint256 complexityMultiplier,
        uint256 priorityMultiplier,
        uint256 tokenPrice,
        uint256 setupCost,
        bool isActive
    ) external onlyPricingManager {
        PricingModel storage pricing = _pricingModels[inferenceType][complexity];
        pricing.basePrice = basePrice;
        pricing.complexityMultiplier = complexityMultiplier;
        pricing.priorityMultiplier = priorityMultiplier;
        pricing.tokenPrice = tokenPrice;
        pricing.setupCost = setupCost;
        pricing.isActive = isActive;
        
        emit PricingModelUpdated(inferenceType, complexity, basePrice);
    }
    
    /**
     * @dev Set VIP status for user
     */
    function setVIPStatus(address user, bool vipStatus, uint256 priorityMultiplier) external onlyAIPaymentManager {
        isVIPUser[user] = vipStatus;
        userPriorityMultiplier[user] = priorityMultiplier;
        
        emit VIPStatusUpdated(user, vipStatus);
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Initialize default pricing models
     */
    function _initializeDefaultPricingModels() internal {
        // Text generation pricing
        _pricingModels[InferenceType.TEXT_GENERATION][ModelComplexity.LIGHT] = PricingModel({
            basePrice: 0.0001 ether,
            complexityMultiplier: 100,
            priorityMultiplier: 100,
            tokenPrice: 0.00001 ether,
            setupCost: 0.001 ether,
            isActive: true
        });
        
        _pricingModels[InferenceType.TEXT_GENERATION][ModelComplexity.MEDIUM] = PricingModel({
            basePrice: 0.0005 ether,
            complexityMultiplier: 200,
            priorityMultiplier: 100,
            tokenPrice: 0.00005 ether,
            setupCost: 0.002 ether,
            isActive: true
        });
        
        // Image generation pricing
        _pricingModels[InferenceType.IMAGE_GENERATION][ModelComplexity.MEDIUM] = PricingModel({
            basePrice: 0.001 ether,
            complexityMultiplier: 300,
            priorityMultiplier: 100,
            tokenPrice: 0.0001 ether,
            setupCost: 0.005 ether,
            isActive: true
        });
    }
    
    /**
     * @dev Add request to processing queue
     */
    function _addToQueue(bytes32 requestId, PriorityLevel priority) internal {
        processingQueue.push(requestId);
        queuesByPriority[priority].push(requestId);
        queuePositions[requestId] = processingQueue.length;
        currentQueueSize++;
        
        // Update request status
        _inferenceRequests[requestId].status = InferenceStatus.QUEUED;
        _updateRequestStatus(requestId, InferenceStatus.REQUESTED, InferenceStatus.QUEUED);
    }
    
    /**
     * @dev Remove request from queue
     */
    function _removeFromQueue(bytes32 requestId) internal {
        uint256 position = queuePositions[requestId];
        require(position > 0, "KarmaAI: Not in queue");
        
        // Remove from main queue
        uint256 lastIndex = processingQueue.length - 1;
        if (position - 1 != lastIndex) {
            processingQueue[position - 1] = processingQueue[lastIndex];
            queuePositions[processingQueue[position - 1]] = position;
        }
        processingQueue.pop();
        
        delete queuePositions[requestId];
        currentQueueSize--;
    }
    
    /**
     * @dev Update request status tracking
     */
    function _updateRequestStatus(
        bytes32 requestId,
        InferenceStatus oldStatus,
        InferenceStatus newStatus
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
    
    /**
     * @dev Get priority multiplier
     */
    function _getPriorityMultiplier(PriorityLevel priority) internal view returns (uint256) {
        if (priority == PriorityLevel.LOW) return 75;
        if (priority == PriorityLevel.NORMAL) return 100;
        if (priority == PriorityLevel.HIGH) return 150;
        if (priority == PriorityLevel.URGENT) return 250;
        return 100;
    }
    
    /**
     * @dev Estimate compute units needed
     */
    function _estimateComputeUnits(
        InferenceType inferenceType,
        ModelComplexity complexity,
        uint256 inputSize
    ) internal pure returns (uint256) {
        uint256 base = inputSize / 100; // Base calculation
        
        if (complexity == ModelComplexity.LIGHT) base = base * 1;
        else if (complexity == ModelComplexity.MEDIUM) base = base * 3;
        else if (complexity == ModelComplexity.HEAVY) base = base * 10;
        else if (complexity == ModelComplexity.ULTRA) base = base * 30;
        
        if (inferenceType == InferenceType.IMAGE_GENERATION) base = base * 5;
        else if (inferenceType == InferenceType.VIDEO_GENERATION) base = base * 20;
        
        return Math.max(base, MIN_COMPUTE_UNITS);
    }
    
    /**
     * @dev Estimate tokens needed
     */
    function _estimateTokens(InferenceType inferenceType, uint256 inputSize) internal pure returns (uint256) {
        if (inferenceType == InferenceType.TEXT_GENERATION || 
            inferenceType == InferenceType.CODE_GENERATION) {
            return inputSize / 4; // Rough token estimation
        }
        return inputSize / 10; // For other types
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get queue status
     */
    function getQueueStatus() external view returns (
        uint256 totalQueued,
        uint256 lowPriority,
        uint256 normalPriority,
        uint256 highPriority,
        uint256 urgentPriority
    ) {
        return (
            currentQueueSize,
            queuesByPriority[PriorityLevel.LOW].length,
            queuesByPriority[PriorityLevel.NORMAL].length,
            queuesByPriority[PriorityLevel.HIGH].length,
            queuesByPriority[PriorityLevel.URGENT].length
        );
    }
    
    /**
     * @dev Get user requests
     */
    function getUserRequests(address user) external view returns (bytes32[] memory) {
        return requestsByUser[user];
    }
} 