// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../interfaces/I0GBridge.sol";

/**
 * @title KarmaCrossChainBridge
 * @dev Cross-chain communication bridge between Arbitrum and 0G blockchain
 * Stage 8.1 - Cross-Chain Communication Implementation
 */
contract KarmaCrossChainBridge is I0GBridge, AccessControl, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MIN_CONFIRMATIONS = 3;
    uint256 public constant MAX_GAS_LIMIT = 10000000;
    uint256 public constant TIMEOUT_PERIOD = 24 hours;
    uint256 public constant DISPUTE_PERIOD = 7 days;
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaToken;
    address public treasury;
    address public aiInferencePayment;
    address public metadataStorage;
    address public oracle;
    
    // Bridge state
    mapping(bytes32 => CrossChainMessage) private _messages;
    mapping(bytes32 => mapping(address => bool)) private _messageValidations;
    mapping(bytes32 => uint256) private _validationCounts;
    mapping(address => uint256) private _nonces;
    mapping(MessageType => uint256) private _messageFees;
    
    BridgeConfig private _bridgeConfig;
    
    // Message tracking
    bytes32[] public allMessageIds;
    mapping(address => bytes32[]) public messagesByUser;
    mapping(MessageType => bytes32[]) public messagesByType;
    mapping(MessageStatus => bytes32[]) public messagesByStatus;
    
    // Validator management
    address[] public validators;
    mapping(address => bool) public isValidator;
    mapping(address => uint256) public validatorStake;
    uint256 public totalValidatorStake;
    uint256 public minimumValidatorStake = 100000 ether; // 100K KARMA
    
    // Bridge metrics
    struct BridgeMetrics {
        uint256 totalMessages;
        uint256 successfulMessages;
        uint256 failedMessages;
        uint256 totalVolume;
        uint256 totalFees;
        mapping(MessageType => uint256) messagesByType;
    }
    
    BridgeMetrics private _bridgeMetrics;
    
    // ============ EVENTS ============
    
    event ValidatorAdded(address indexed validator, uint256 stake);
    event ValidatorRemoved(address indexed validator);
    event MessageValidated(bytes32 indexed messageId, address indexed validator);
    event BridgeFeesUpdated(MessageType indexed messageType, uint256 newFee);
    event EmergencyActionTaken(address indexed executor, string action);
    
    // ============ MODIFIERS ============
    
    modifier onlyBridgeManager() {
        require(hasRole(BRIDGE_MANAGER_ROLE, msg.sender), "KarmaBridge: Not bridge manager");
        _;
    }
    
    modifier onlyValidator() {
        require(hasRole(VALIDATOR_ROLE, msg.sender), "KarmaBridge: Not validator");
        _;
    }
    
    modifier onlyRelayer() {
        require(hasRole(RELAYER_ROLE, msg.sender), "KarmaBridge: Not relayer");
        _;
    }
    
    modifier validMessageId(bytes32 messageId) {
        require(_messages[messageId].messageId != bytes32(0), "KarmaBridge: Invalid message ID");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _treasury,
        address _admin
    ) {
        karmaToken = _karmaToken;
        treasury = _treasury;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(BRIDGE_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize bridge configuration
        _bridgeConfig = BridgeConfig({
            minConfirmations: MIN_CONFIRMATIONS,
            maxGasLimit: MAX_GAS_LIMIT,
            bridgeFee: 0.001 ether,
            timeoutPeriod: TIMEOUT_PERIOD,
            isActive: true
        });
        
        // Initialize message type fees
        _messageFees[MessageType.INFERENCE_REQUEST] = 0.01 ether;
        _messageFees[MessageType.PAYMENT_SETTLEMENT] = 0.005 ether;
        _messageFees[MessageType.METADATA_STORAGE] = 0.002 ether;
        _messageFees[MessageType.ASSET_BRIDGE] = 0.01 ether;
        _messageFees[MessageType.ORACLE_UPDATE] = 0.001 ether;
    }
    
    // ============ EXTERNAL FUNCTIONS ============
    
    /**
     * @dev Send cross-chain message to 0G blockchain
     */
    function sendMessage(
        address recipient,
        MessageType messageType,
        bytes calldata payload,
        uint256 gasLimit
    ) external payable whenNotPaused nonReentrant returns (bytes32 messageId) {
        require(_bridgeConfig.isActive, "KarmaBridge: Bridge not active");
        require(gasLimit <= _bridgeConfig.maxGasLimit, "KarmaBridge: Gas limit too high");
        require(recipient != address(0), "KarmaBridge: Invalid recipient");
        
        // Calculate required fee
        uint256 requiredFee = calculateBridgeFee(messageType, gasLimit, msg.value);
        require(msg.value >= requiredFee, "KarmaBridge: Insufficient fee");
        
        // Generate message ID
        messageId = keccak256(
            abi.encodePacked(
                msg.sender,
                recipient,
                messageType,
                payload,
                _nonces[msg.sender]++,
                block.timestamp
            )
        );
        
        // Create message
        CrossChainMessage storage message = _messages[messageId];
        message.messageId = messageId;
        message.sender = msg.sender;
        message.recipient = recipient;
        message.messageType = messageType;
        message.payload = payload;
        message.value = msg.value - requiredFee;
        message.gasLimit = gasLimit;
        message.timestamp = block.timestamp;
        message.status = MessageStatus.PENDING;
        message.blockNumber = block.number;
        
        // Track message
        allMessageIds.push(messageId);
        messagesByUser[msg.sender].push(messageId);
        messagesByType[messageType].push(messageId);
        messagesByStatus[MessageStatus.PENDING].push(messageId);
        
        // Update metrics
        _bridgeMetrics.totalMessages++;
        _bridgeMetrics.totalVolume += msg.value;
        _bridgeMetrics.totalFees += requiredFee;
        _bridgeMetrics.messagesByType[messageType]++;
        
        // Transfer fee to treasury
        if (requiredFee > 0) {
            (bool success, ) = treasury.call{value: requiredFee}("");
            require(success, "KarmaBridge: Fee transfer failed");
        }
        
        emit MessageSent(messageId, msg.sender, recipient, messageType, msg.value);
    }
    
    /**
     * @dev Process received message from 0G blockchain
     */
    function processMessage(
        bytes32 messageId,
        bytes calldata proof,
        CrossChainMessage calldata message
    ) external onlyRelayer whenNotPaused nonReentrant {
        require(_messages[messageId].messageId == bytes32(0), "KarmaBridge: Message already exists");
        require(message.messageId == messageId, "KarmaBridge: Message ID mismatch");
        require(_verifyProof(messageId, proof), "KarmaBridge: Invalid proof");
        
        // Store the message
        _messages[messageId] = message;
        _messages[messageId].status = MessageStatus.PROCESSING;
        
        // Track message
        allMessageIds.push(messageId);
        messagesByUser[message.sender].push(messageId);
        messagesByType[message.messageType].push(messageId);
        messagesByStatus[MessageStatus.PROCESSING].push(messageId);
        
        emit MessageReceived(messageId, message.recipient, MessageStatus.PROCESSING);
    }
    
    /**
     * @dev Validate message (used by validators)
     */
    function validateMessage(
        bytes32 messageId,
        bool isValid
    ) external onlyValidator validMessageId(messageId) {
        require(!_messageValidations[messageId][msg.sender], "KarmaBridge: Already validated");
        require(_messages[messageId].status == MessageStatus.PENDING || 
                _messages[messageId].status == MessageStatus.PROCESSING, "KarmaBridge: Invalid status");
        
        _messageValidations[messageId][msg.sender] = true;
        
        if (isValid) {
            _validationCounts[messageId]++;
            emit MessageValidated(messageId, msg.sender);
            
            // Check if enough validations
            if (_validationCounts[messageId] >= _bridgeConfig.minConfirmations) {
                _finalizeMessage(messageId, MessageStatus.COMPLETED);
            }
        }
    }
    
    /**
     * @dev Calculate bridge fee for message
     */
    function calculateBridgeFee(
        MessageType messageType,
        uint256 gasLimit,
        uint256 value
    ) public view returns (uint256 fee) {
        fee = _bridgeConfig.bridgeFee + _messageFees[messageType];
        
        // Add gas-based fee
        fee += (gasLimit * 0.000001 ether) / 1000000; // Base gas price component
        
        // Add value-based fee (0.1% of value)
        if (value > 0) {
            fee += (value * 10) / 10000;
        }
    }
    
    /**
     * @dev Get message details
     */
    function getMessage(bytes32 messageId) external view returns (CrossChainMessage memory) {
        return _messages[messageId];
    }
    
    /**
     * @dev Get bridge configuration
     */
    function getBridgeConfig() external view returns (BridgeConfig memory) {
        return _bridgeConfig;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Add validator
     */
    function addValidator(address validator, uint256 stake) external onlyBridgeManager {
        require(!isValidator[validator], "KarmaBridge: Already validator");
        require(stake >= minimumValidatorStake, "KarmaBridge: Insufficient stake");
        
        validators.push(validator);
        isValidator[validator] = true;
        validatorStake[validator] = stake;
        totalValidatorStake += stake;
        
        _grantRole(VALIDATOR_ROLE, validator);
        
        emit ValidatorAdded(validator, stake);
    }
    
    /**
     * @dev Remove validator
     */
    function removeValidator(address validator) external onlyBridgeManager {
        require(isValidator[validator], "KarmaBridge: Not validator");
        
        isValidator[validator] = false;
        totalValidatorStake -= validatorStake[validator];
        validatorStake[validator] = 0;
        
        _revokeRole(VALIDATOR_ROLE, validator);
        
        // Remove from validators array
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
        
        emit ValidatorRemoved(validator);
    }
    
    /**
     * @dev Update bridge configuration
     */
    function updateBridgeConfig(
        uint256 minConfirmations,
        uint256 maxGasLimit,
        uint256 bridgeFee,
        uint256 timeoutPeriod,
        bool isActive
    ) external onlyBridgeManager {
        require(minConfirmations > 0, "KarmaBridge: Invalid confirmations");
        require(maxGasLimit > 0, "KarmaBridge: Invalid gas limit");
        
        _bridgeConfig.minConfirmations = minConfirmations;
        _bridgeConfig.maxGasLimit = maxGasLimit;
        _bridgeConfig.bridgeFee = bridgeFee;
        _bridgeConfig.timeoutPeriod = timeoutPeriod;
        _bridgeConfig.isActive = isActive;
        
        emit BridgeConfigUpdated(minConfirmations, maxGasLimit, bridgeFee);
    }
    
    /**
     * @dev Update message type fees
     */
    function updateMessageFees(
        MessageType messageType,
        uint256 fee
    ) external onlyBridgeManager {
        _messageFees[messageType] = fee;
        emit BridgeFeesUpdated(messageType, fee);
    }
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "KarmaBridge: Not emergency role");
        _pause();
        emit EmergencyActionTaken(msg.sender, "Emergency Pause");
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyBridgeManager {
        _unpause();
        emit EmergencyActionTaken(msg.sender, "Emergency Unpause");
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Finalize message status
     */
    function _finalizeMessage(bytes32 messageId, MessageStatus newStatus) internal {
        MessageStatus oldStatus = _messages[messageId].status;
        _messages[messageId].status = newStatus;
        
        // Update tracking arrays
        _removeFromStatusArray(messageId, oldStatus);
        messagesByStatus[newStatus].push(messageId);
        
        // Update metrics
        if (newStatus == MessageStatus.COMPLETED) {
            _bridgeMetrics.successfulMessages++;
        } else if (newStatus == MessageStatus.FAILED) {
            _bridgeMetrics.failedMessages++;
        }
        
        emit MessageStatusUpdated(messageId, oldStatus, newStatus);
    }
    
    /**
     * @dev Remove message from status tracking array
     */
    function _removeFromStatusArray(bytes32 messageId, MessageStatus status) internal {
        bytes32[] storage statusArray = messagesByStatus[status];
        for (uint256 i = 0; i < statusArray.length; i++) {
            if (statusArray[i] == messageId) {
                statusArray[i] = statusArray[statusArray.length - 1];
                statusArray.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Verify cross-chain proof (simplified for demonstration)
     */
    function _verifyProof(bytes32 messageId, bytes calldata proof) internal pure returns (bool) {
        // Simplified proof verification - in production would verify Merkle proofs
        return proof.length > 0 && messageId != bytes32(0);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get bridge metrics
     */
    function getBridgeMetrics() external view returns (
        uint256 totalMessages,
        uint256 successfulMessages,
        uint256 failedMessages,
        uint256 totalVolume,
        uint256 totalFees
    ) {
        return (
            _bridgeMetrics.totalMessages,
            _bridgeMetrics.successfulMessages,
            _bridgeMetrics.failedMessages,
            _bridgeMetrics.totalVolume,
            _bridgeMetrics.totalFees
        );
    }
    
    /**
     * @dev Get user messages
     */
    function getUserMessages(address user) external view returns (bytes32[] memory) {
        return messagesByUser[user];
    }
    
    /**
     * @dev Get messages by type
     */
    function getMessagesByType(MessageType messageType) external view returns (bytes32[] memory) {
        return messagesByType[messageType];
    }
    
    /**
     * @dev Get validator list
     */
    function getValidators() external view returns (address[] memory) {
        return validators;
    }
} 