// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPaymaster
 * @dev Interface for ERC-4337 Paymaster contracts
 * 
 * Implements Stage 5.1: Paymaster Contract Development requirements:
 * - Gas Sponsorship Engine with EIP-4337 account abstraction patterns
 * - Access Control and Whitelisting for approved contracts and users
 * - Anti-Abuse and Rate Limiting mechanisms
 * - Economic Sustainability with Treasury integration
 * 
 * This contract enables gasless transactions for users by sponsoring gas fees
 * based on configurable policies and access controls.
 */
interface IPaymaster {
    
    // ============ ENUMS ============
    
    enum PostOpMode {
        opSucceeded, // User operation succeeded
        opReverted,  // User operation reverted
        postOpReverted // PostOp itself reverted
    }
    
    enum UserTier {
        STANDARD,    // Basic users
        VIP,         // VIP users with higher limits
        STAKER,      // Token stakers
        PREMIUM      // Premium subscription users
    }
    
    enum SponsorshipPolicy {
        ALLOWLIST_ONLY,      // Only whitelisted users
        TOKEN_HOLDERS,       // KARMA token holders
        STAKING_REWARDS,     // Users claiming staking rewards
        PREMIUM_SUBSCRIBERS, // Premium subscribers
        PUBLIC_LIMITED       // Public with limits
    }
    
    // ============ STRUCTS ============
    
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }
    
    struct SponsorshipConfig {
        SponsorshipPolicy policy;
        uint256 maxGasPerUser;           // Max gas per user per period
        uint256 maxGasPerOperation;      // Max gas per operation
        uint256 dailyGasLimit;           // Daily total gas limit
        uint256 monthlyGasLimit;         // Monthly total gas limit
        uint256 minimumStakeRequired;    // Minimum KARMA stake for access
        bool isActive;                   // Whether sponsorship is active
    }
    
    struct UserGasUsage {
        uint256 dailyGasUsed;           // Gas used today
        uint256 monthlyGasUsed;         // Gas used this month
        uint256 lastOperationTime;     // Last operation timestamp
        uint256 operationCount;        // Total operations sponsored
        uint256 lastDayReset;          // Last daily reset timestamp
        uint256 lastMonthReset;        // Last monthly reset timestamp
        bool isBlacklisted;            // User blacklist status
    }
    
    struct ContractWhitelist {
        bool isApproved;               // Whether contract is approved
        uint256 maxGasPerCall;         // Max gas per function call
        bytes4[] allowedSelectors;     // Allowed function selectors
        uint256 dailyGasLimit;         // Daily gas limit for this contract
        uint256 gasUsedToday;          // Gas used today
        uint256 lastDayReset;          // Last daily reset
    }
    
    struct GasEstimation {
        uint256 preVerificationGas;    // Gas for bundler overhead
        uint256 verificationGasLimit;  // Gas for validation
        uint256 callGasLimit;          // Gas for execution
        uint256 totalGasEstimate;      // Total estimated gas
        uint256 gasPriceEstimate;      // Estimated gas price
        uint256 totalCostEstimate;     // Total cost in wei
    }
    
    struct PaymasterMetrics {
        uint256 totalOperationsSponsored;
        uint256 totalGasSponsored;
        uint256 totalCostSponsored;
        uint256 activeUsers;
        uint256 blacklistedUsers;
        uint256 emergencyStops;
        uint256 lastTreasuryRefill;
        uint256 currentBalance;
    }
    
    // ============ EVENTS ============
    
    event UserOperationSponsored(
        address indexed user,
        bytes32 indexed userOpHash,
        uint256 gasUsed,
        uint256 gasCost
    );
    
    event SponsorshipPolicyUpdated(
        SponsorshipPolicy indexed oldPolicy,
        SponsorshipPolicy indexed newPolicy
    );
    
    event UserTierUpdated(
        address indexed user,
        UserTier indexed oldTier,
        UserTier indexed newTier
    );
    
    event ContractWhitelisted(
        address indexed contractAddress,
        bool indexed approved
    );
    
    event UserBlacklisted(
        address indexed user,
        string reason
    );
    
    event GasLimitsUpdated(
        uint256 dailyLimit,
        uint256 monthlyLimit,
        uint256 perOperationLimit
    );
    
    event TreasuryRefilled(
        uint256 amount,
        uint256 newBalance
    );
    
    event EmergencyStop(
        address indexed caller,
        string reason
    );
    
    event AbuseDetected(
        address indexed user,
        string abuseType,
        uint256 severity
    );
    
    // ============ ERC-4337 CORE FUNCTIONS ============
    
    /**
     * @dev Validate a user operation for sponsorship
     * @param userOp The user operation to validate
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost willing to pay for this operation
     * @return context Data to pass to postOp
     * @return validationData Validation result
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);
    
    /**
     * @dev Post-operation hook called after user operation execution
     * @param mode Whether the operation succeeded, reverted, or postOp reverted
     * @param context Data from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external;
    
    // ============ GAS SPONSORSHIP ENGINE ============
    
    /**
     * @dev Estimate gas for a user operation
     * @param userOp The user operation to estimate
     * @return estimation Gas estimation breakdown
     */
    function estimateGas(
        UserOperation calldata userOp
    ) external view returns (GasEstimation memory estimation);
    
    /**
     * @dev Check if user operation is eligible for sponsorship
     * @param userOp The user operation to check
     * @return eligible Whether operation is eligible
     * @return reason Reason if not eligible
     */
    function isEligibleForSponsorship(
        UserOperation calldata userOp
    ) external view returns (bool eligible, string memory reason);
    
    /**
     * @dev Calculate sponsorship cost for operation
     * @param gasUsed Amount of gas used
     * @param gasPrice Gas price for the transaction
     * @return cost Total cost to sponsor
     */
    function calculateSponsorshipCost(
        uint256 gasUsed,
        uint256 gasPrice
    ) external view returns (uint256 cost);
    
    // ============ ACCESS CONTROL AND WHITELISTING ============
    
    /**
     * @dev Add contract to whitelist
     * @param contractAddress Contract to whitelist
     * @param maxGasPerCall Maximum gas per function call
     * @param allowedSelectors Array of allowed function selectors
     * @param dailyGasLimit Daily gas limit for this contract
     */
    function whitelistContract(
        address contractAddress,
        uint256 maxGasPerCall,
        bytes4[] calldata allowedSelectors,
        uint256 dailyGasLimit
    ) external;
    
    /**
     * @dev Remove contract from whitelist
     * @param contractAddress Contract to remove
     */
    function removeFromWhitelist(address contractAddress) external;
    
    /**
     * @dev Set user tier (VIP, staker, etc.)
     * @param user User address
     * @param tier New tier for user
     */
    function setUserTier(address user, UserTier tier) external;
    
    /**
     * @dev Check if contract call is whitelisted
     * @param contractAddress Target contract
     * @param selector Function selector
     * @param gasRequested Gas requested for call
     * @return approved Whether call is approved
     */
    function isContractCallApproved(
        address contractAddress,
        bytes4 selector,
        uint256 gasRequested
    ) external view returns (bool approved);
    
    /**
     * @dev Get user's current tier
     * @param user User address
     * @return tier Current user tier
     */
    function getUserTier(address user) external view returns (UserTier tier);
    
    // ============ ANTI-ABUSE AND RATE LIMITING ============
    
    /**
     * @dev Check if user has exceeded rate limits
     * @param user User address
     * @param gasRequested Gas requested for operation
     * @return withinLimits Whether user is within limits
     * @return resetTime When limits reset
     */
    function checkRateLimit(
        address user,
        uint256 gasRequested
    ) external view returns (bool withinLimits, uint256 resetTime);
    
    /**
     * @dev Add user to blacklist
     * @param user User to blacklist
     * @param reason Reason for blacklisting
     */
    function blacklistUser(address user, string calldata reason) external;
    
    /**
     * @dev Remove user from blacklist
     * @param user User to remove from blacklist
     */
    function removeFromBlacklist(address user) external;
    
    /**
     * @dev Update rate limits
     * @param dailyGasLimit New daily gas limit per user
     * @param monthlyGasLimit New monthly gas limit per user
     * @param maxGasPerOperation New max gas per operation
     */
    function updateRateLimits(
        uint256 dailyGasLimit,
        uint256 monthlyGasLimit,
        uint256 maxGasPerOperation
    ) external;
    
    /**
     * @dev Detect and handle potential abuse
     * @param user User to check
     * @param gasRequested Gas requested
     * @return isAbuse Whether abuse detected
     * @return severity Abuse severity (1-10)
     */
    function detectAbuse(
        address user,
        uint256 gasRequested
    ) external returns (bool isAbuse, uint256 severity);
    
    /**
     * @dev Emergency stop for suspicious activity
     * @param reason Reason for emergency stop
     */
    function emergencyStop(string calldata reason) external;
    
    /**
     * @dev Resume operations after emergency stop
     */
    function resumeOperations() external;
    
    // ============ ECONOMIC SUSTAINABILITY ============
    
    /**
     * @dev Refill paymaster from Treasury
     * @param amount Amount of ETH to request from Treasury
     */
    function refillFromTreasury(uint256 amount) external;
    
    /**
     * @dev Set automatic refill parameters
     * @param threshold Balance threshold to trigger refill
     * @param refillAmount Amount to refill when triggered
     */
    function setAutoRefillParams(
        uint256 threshold,
        uint256 refillAmount
    ) external;
    
    /**
     * @dev Get current balance and funding status
     * @return balance Current ETH balance
     * @return lastRefill Last refill timestamp
     * @return needsRefill Whether refill is needed
     */
    function getFundingStatus() external view returns (
        uint256 balance,
        uint256 lastRefill,
        bool needsRefill
    );
    
    /**
     * @dev Get cost tracking data
     * @return totalSponsored Total amount sponsored (wei)
     * @return operationsCount Total operations sponsored
     * @return avgCostPerOp Average cost per operation
     */
    function getCostTracking() external view returns (
        uint256 totalSponsored,
        uint256 operationsCount,
        uint256 avgCostPerOp
    );
    
    /**
     * @dev Optimize gas usage and fees
     * @return optimizedGasPrice Optimized gas price suggestion
     * @return costSavings Potential cost savings
     */
    function optimizeGasFees() external view returns (
        uint256 optimizedGasPrice,
        uint256 costSavings
    );
    
    // ============ CONFIGURATION AND MANAGEMENT ============
    
    /**
     * @dev Update sponsorship policy
     * @param newPolicy New sponsorship policy
     */
    function updateSponsorshipPolicy(SponsorshipPolicy newPolicy) external;
    
    /**
     * @dev Get current sponsorship configuration
     * @return config Current sponsorship config
     */
    function getSponsorshipConfig() external view returns (SponsorshipConfig memory config);
    
    /**
     * @dev Get user gas usage statistics
     * @param user User address
     * @return usage User's gas usage data
     */
    function getUserGasUsage(address user) external view returns (UserGasUsage memory usage);
    
    /**
     * @dev Get paymaster metrics and statistics
     * @return metrics Current paymaster metrics
     */
    function getPaymasterMetrics() external view returns (PaymasterMetrics memory metrics);
    
    /**
     * @dev Check if paymaster is operational
     * @return operational Whether paymaster is accepting operations
     * @return reason Reason if not operational
     */
    function isOperational() external view returns (bool operational, string memory reason);
} 