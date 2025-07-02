// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title I0GOracle
 * @dev Interface for 0G usage reporting oracle and cross-chain settlement
 * Stage 8.1 - Oracle and Settlement Requirements
 */
interface I0GOracle {
    
    // ============ ENUMS ============
    
    enum OracleType {
        USAGE_REPORTER,         // Reports 0G usage data
        PRICE_FEED,            // Price feed oracle
        SETTLEMENT_VALIDATOR,   // Validates settlements
        DISPUTE_RESOLVER,      // Resolves disputes
        BRIDGE_VALIDATOR       // Validates bridge operations
    }
    
    enum DataStatus {
        PENDING,               // Data pending validation
        VALIDATED,             // Data validated
        DISPUTED,              // Data under dispute
        REJECTED,              // Data rejected
        EXPIRED                // Data expired
    }
    
    enum SettlementStatus {
        PENDING,               // Settlement pending
        PROCESSING,            // Settlement processing
        COMPLETED,             // Settlement completed
        FAILED,                // Settlement failed
        DISPUTED,              // Settlement disputed
        CANCELLED              // Settlement cancelled
    }
    
    // ============ STRUCTS ============
    
    struct UsageReport {
        bytes32 reportId;
        address reporter;
        address user;
        uint256 computeUnits;
        uint256 storageUsed;
        uint256 dataTransferred;
        uint256 timestamp;
        uint256 blockNumber;
        DataStatus status;
        bytes32 proofHash;
        uint256 cost;
        string serviceType;
    }
    
    struct SettlementRequest {
        bytes32 settlementId;
        address requester;
        address recipient;
        uint256 amount;
        bytes32[] usageReports;
        uint256 timestamp;
        SettlementStatus status;
        bytes32 proofHash;
        uint256 deadline;
        bool isAutomatic;
    }
    
    struct DisputeCase {
        bytes32 disputeId;
        bytes32 originalReportId;
        address disputer;
        address defendant;
        string reason;
        bytes evidence;
        uint256 timestamp;
        uint256 resolutionDeadline;
        DataStatus resolution;
        address resolver;
        uint256 penalty;
    }
    
    struct OracleConfig {
        uint256 reportingThreshold;    // Minimum threshold for reporting
        uint256 validationPeriod;      // Time for validation
        uint256 disputePeriod;         // Time for dispute submission
        uint256 settlementThreshold;   // Minimum amount for settlement
        uint256 oracleFee;             // Fee for oracle services
        bool isActive;
    }
    
    struct PriceData {
        uint256 karmaPrice;            // KARMA token price in USD
        uint256 computePrice;          // Price per compute unit
        uint256 storagePrice;          // Price per storage unit
        uint256 transferPrice;         // Price per data transfer
        uint256 timestamp;
        uint256 blockNumber;
        address reporter;
    }
    
    // ============ EVENTS ============
    
    event UsageReported(
        bytes32 indexed reportId,
        address indexed reporter,
        address indexed user,
        uint256 computeUnits,
        uint256 cost
    );
    
    event SettlementRequested(
        bytes32 indexed settlementId,
        address indexed requester,
        address indexed recipient,
        uint256 amount
    );
    
    event SettlementCompleted(
        bytes32 indexed settlementId,
        address indexed recipient,
        uint256 amount
    );
    
    event DisputeRaised(
        bytes32 indexed disputeId,
        bytes32 indexed reportId,
        address indexed disputer,
        string reason
    );
    
    event DisputeResolved(
        bytes32 indexed disputeId,
        DataStatus resolution,
        address resolver
    );
    
    event PriceUpdated(
        uint256 karmaPrice,
        uint256 computePrice,
        uint256 storagePrice,
        address reporter
    );
    
    // ============ FUNCTIONS ============
    
    /**
     * @dev Report usage data from 0G blockchain
     */
    function reportUsage(
        address user,
        uint256 computeUnits,
        uint256 storageUsed,
        uint256 dataTransferred,
        string calldata serviceType,
        bytes calldata proof
    ) external returns (bytes32 reportId);
    
    /**
     * @dev Request settlement based on usage reports
     */
    function requestSettlement(
        address recipient,
        bytes32[] calldata reportIds,
        bool isAutomatic
    ) external returns (bytes32 settlementId);
    
    /**
     * @dev Process automatic settlement
     */
    function processAutomaticSettlement(
        bytes32 settlementId
    ) external;
    
    /**
     * @dev Validate usage report
     */
    function validateReport(
        bytes32 reportId,
        bool isValid,
        bytes calldata validationProof
    ) external;
    
    /**
     * @dev Raise dispute for usage report
     */
    function raiseDispute(
        bytes32 reportId,
        string calldata reason,
        bytes calldata evidence
    ) external returns (bytes32 disputeId);
    
    /**
     * @dev Resolve dispute
     */
    function resolveDispute(
        bytes32 disputeId,
        DataStatus resolution,
        bytes calldata resolutionData
    ) external;
    
    /**
     * @dev Update price data
     */
    function updatePrices(
        uint256 karmaPrice,
        uint256 computePrice,
        uint256 storagePrice,
        uint256 transferPrice,
        bytes calldata priceProof
    ) external;
    
    /**
     * @dev Get usage report
     */
    function getUsageReport(bytes32 reportId) external view returns (UsageReport memory);
    
    /**
     * @dev Get settlement request
     */
    function getSettlementRequest(bytes32 settlementId) external view returns (SettlementRequest memory);
    
    /**
     * @dev Get current prices
     */
    function getCurrentPrices() external view returns (PriceData memory);
    
    /**
     * @dev Calculate settlement amount
     */
    function calculateSettlementAmount(
        bytes32[] calldata reportIds
    ) external view returns (uint256 totalAmount);
    
    /**
     * @dev Get oracle configuration
     */
    function getOracleConfig() external view returns (OracleConfig memory);
} 