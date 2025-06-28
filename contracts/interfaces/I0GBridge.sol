// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title I0GBridge
 * @dev Interface for cross-chain communication between Arbitrum and 0G blockchain
 * Stage 8.1 - Cross-Chain Communication Requirements
 */
interface I0GBridge {
    
    // ============ ENUMS ============
    
    enum MessageStatus {
        PENDING,        // Message pending processing
        PROCESSING,     // Message being processed
        COMPLETED,      // Message successfully processed
        FAILED,         // Message failed processing
        DISPUTED,       // Message under dispute
        CANCELLED       // Message cancelled
    }
    
    enum MessageType {
        INFERENCE_REQUEST,      // AI inference request
        PAYMENT_SETTLEMENT,     // Payment settlement
        METADATA_STORAGE,       // Metadata storage request
        ASSET_BRIDGE,          // Asset bridging
        ORACLE_UPDATE          // Oracle data update
    }
    
    // ============ STRUCTS ============
    
    struct CrossChainMessage {
        bytes32 messageId;
        address sender;
        address recipient;
        MessageType messageType;
        bytes payload;
        uint256 value;
        uint256 gasLimit;
        uint256 timestamp;
        MessageStatus status;
        bytes32 proofHash;
        uint256 blockNumber;
    }
    
    struct BridgeConfig {
        uint256 minConfirmations;
        uint256 maxGasLimit;
        uint256 bridgeFee;
        uint256 timeoutPeriod;
        bool isActive;
    }
    
    // ============ EVENTS ============
    
    event MessageSent(
        bytes32 indexed messageId,
        address indexed sender,
        address indexed recipient,
        MessageType messageType,
        uint256 value
    );
    
    event MessageReceived(
        bytes32 indexed messageId,
        address indexed recipient,
        MessageStatus status
    );
    
    event MessageStatusUpdated(
        bytes32 indexed messageId,
        MessageStatus oldStatus,
        MessageStatus newStatus
    );
    
    event BridgeConfigUpdated(
        uint256 minConfirmations,
        uint256 maxGasLimit,
        uint256 bridgeFee
    );
    
    // ============ FUNCTIONS ============
    
    /**
     * @dev Send cross-chain message to 0G blockchain
     */
    function sendMessage(
        address recipient,
        MessageType messageType,
        bytes calldata payload,
        uint256 gasLimit
    ) external payable returns (bytes32 messageId);
    
    /**
     * @dev Process received message from 0G blockchain
     */
    function processMessage(
        bytes32 messageId,
        bytes calldata proof,
        CrossChainMessage calldata message
    ) external;
    
    /**
     * @dev Get message details
     */
    function getMessage(bytes32 messageId) external view returns (CrossChainMessage memory);
    
    /**
     * @dev Get bridge configuration
     */
    function getBridgeConfig() external view returns (BridgeConfig memory);
    
    /**
     * @dev Calculate bridge fee for message
     */
    function calculateBridgeFee(
        MessageType messageType,
        uint256 gasLimit,
        uint256 value
    ) external view returns (uint256 fee);
} 