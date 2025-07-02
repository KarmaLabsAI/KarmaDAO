// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRevenueStreamIntegrator
 * @dev Interface for Stage 6.2 Revenue Stream Integration
 * 
 * Stage 6.2 Implementation Requirements:
 * - Platform Fee Collection hooks for iNFT, SillyHotel, SillyPort, KarmaLabs assets
 * - Centralized Credit System Integration with Oracle bridge
 * - Economic Security and Controls for large buyback operations
 * 
 * Key Features:
 * - Automated fee collection from all platform sources
 * - Off-chain to on-chain revenue bridge via Oracle system
 * - Enhanced security controls for buyback operations
 * - Real-time revenue tracking and analytics
 */
interface IRevenueStreamIntegrator {
    
    // ============ ENUMS ============
    
    enum PlatformType {
        INFT_TRADING,           // iNFT marketplace trading fees
        SILLY_HOTEL,            // SillyHotel in-game purchases
        SILLY_PORT,             // SillyPort premium features
        KARMA_LABS_ASSETS       // KarmaLabs asset trading platform
    }
    
    enum PaymentMethod {
        CRYPTO_DIRECT,          // Direct crypto payments (ETH, USDC, etc.)
        STRIPE_CARD,            // Stripe credit card processing
        PRIVY_INTEGRATION,      // Privy payment processing
        BANK_TRANSFER,          // Traditional bank transfers
        PAYPAL                  // PayPal payments
    }
    
    enum BuybackSecurityLevel {
        STANDARD,               // Normal operations (<10% Treasury)
        ELEVATED,               // Requires additional approvals (10-25% Treasury)
        CRITICAL                // Maximum security (>25% Treasury)
    }
    
    // ============ STRUCTS ============
    
    struct PlatformConfig {
        address contractAddress;     // Platform contract address
        uint256 feePercentage;      // Fee percentage in basis points
        bool isActive;              // Whether fee collection is active
        address feeCollector;       // Authorized fee collector address
        uint256 minCollectionAmount; // Minimum amount before collection
        uint256 totalCollected;    // Total fees collected to date
    }
    
    struct CreditSystemConfig {
        address oracleAddress;       // Oracle for off-chain data
        uint256 conversionRate;      // USD to KARMA conversion rate
        uint256 minimumPurchase;     // Minimum credit purchase amount
        uint256 buybackThreshold;   // Threshold for automatic buyback trigger
        bool isActive;              // Whether credit system is active
        uint256 totalCreditsIssued; // Total credits issued
    }
    
    struct SecurityConfig {
        uint256 multisigThreshold;   // ETH amount requiring multisig (basis points of Treasury)
        uint256 cooldownPeriod;      // Minimum time between large buybacks
        uint256 maxSlippageProtection; // MEV protection slippage limit
        bool sandwichProtection;     // Anti-sandwich attack protection
        bool flashloanProtection;    // Anti-flashloan attack protection
        uint256 lastLargeBuyback;    // Timestamp of last large buyback
    }
    
    struct RevenueMetrics {
        uint256 totalPlatformRevenue; // Total revenue from all platforms
        uint256 totalCreditRevenue;   // Total revenue from credit system
        uint256 totalBuybacksTriggered; // Number of buybacks triggered
        uint256 lastRevenueUpdate;    // Last revenue update timestamp
        mapping(PlatformType => uint256) platformBreakdown; // Revenue by platform
        mapping(PaymentMethod => uint256) paymentBreakdown; // Revenue by payment method
    }
    
    struct OffChainRevenue {
        uint256 amount;             // Revenue amount in USD
        PaymentMethod method;       // Payment method used
        PlatformType platform;      // Platform source
        uint256 timestamp;          // Transaction timestamp
        bytes32 transactionHash;    // Off-chain transaction identifier
        bool processed;             // Whether revenue has been processed
    }
    
    // ============ PLATFORM FEE COLLECTION ============
    
    /**
     * @dev Configure platform fee collection settings
     * @param platform Platform type to configure
     * @param config Platform configuration parameters
     */
    function configurePlatform(PlatformType platform, PlatformConfig calldata config) external;
    
    /**
     * @dev Collect fees from iNFT trading platform
     * @param tradeAmount Total trade amount
     * @param feeAmount Fee amount to collect
     * @param trader Address of the trader
     */
    function collectINFTTradingFees(
        uint256 tradeAmount,
        uint256 feeAmount,
        address trader
    ) external payable;
    
    /**
     * @dev Collect fees from SillyHotel in-game purchases
     * @param purchaseAmount Purchase amount
     * @param feeAmount Fee amount to collect
     * @param player Address of the player
     */
    function collectSillyHotelFees(
        uint256 purchaseAmount,
        uint256 feeAmount,
        address player
    ) external payable;
    
    /**
     * @dev Collect fees from SillyPort premium features
     * @param subscriptionType Type of subscription
     * @param feeAmount Monthly fee amount
     * @param subscriber Address of the subscriber
     */
    function collectSillyPortFees(
        uint256 subscriptionType,
        uint256 feeAmount,
        address subscriber
    ) external payable;
    
    /**
     * @dev Collect fees from KarmaLabs asset trading
     * @param assetType Type of asset traded
     * @param tradeAmount Trade amount
     * @param feeAmount Fee amount to collect
     * @param trader Address of the trader
     */
    function collectKarmaLabsFees(
        uint256 assetType,
        uint256 tradeAmount,
        uint256 feeAmount,
        address trader
    ) external payable;
    
    /**
     * @dev Get platform configuration
     * @param platform Platform to query
     * @return config Platform configuration
     */
    function getPlatformConfig(PlatformType platform) 
        external view returns (PlatformConfig memory config);
    
    /**
     * @dev Get platform revenue breakdown
     * @return platformRevenue Array of revenue amounts by platform
     * @return totalRevenue Total revenue across all platforms
     */
    function getPlatformRevenue() 
        external view returns (uint256[] memory platformRevenue, uint256 totalRevenue);
    
    // ============ CENTRALIZED CREDIT SYSTEM INTEGRATION ============
    
    /**
     * @dev Configure centralized credit system parameters
     * @param config Credit system configuration
     */
    function configureCreditSystem(CreditSystemConfig calldata config) external;
    
    /**
     * @dev Process off-chain revenue via Oracle
     * @param offChainRevenue Array of off-chain revenue data
     * @param oracleSignature Oracle signature for verification
     */
    function processOffChainRevenue(
        OffChainRevenue[] calldata offChainRevenue,
        bytes calldata oracleSignature
    ) external;
    
    /**
     * @dev Issue credits for off-chain purchases
     * @param recipient Address to receive credits
     * @param usdAmount USD amount of purchase
     * @param method Payment method used
     * @return creditsIssued Amount of credits issued
     */
    function issueCredits(
        address recipient,
        uint256 usdAmount,
        PaymentMethod method
    ) external returns (uint256 creditsIssued);
    
    /**
     * @dev Convert credits to KARMA tokens
     * @param amount Amount of credits to convert
     * @return karmaTokens Amount of KARMA tokens received
     */
    function convertCreditsToKarma(uint256 amount) external returns (uint256 karmaTokens);
    
    /**
     * @dev Trigger automatic buyback from credit system revenue
     * @param minBuybackAmount Minimum amount for buyback execution
     * @return executionId Buyback execution ID
     */
    function triggerCreditBuyback(uint256 minBuybackAmount) external returns (uint256 executionId);
    
    /**
     * @dev Get credit system status
     * @return config Current credit system configuration
     * @return totalCredits Total credits in circulation
     * @return conversionRate Current USD to KARMA conversion rate
     */
    function getCreditSystemStatus() 
        external view returns (
            CreditSystemConfig memory config,
            uint256 totalCredits,
            uint256 conversionRate
        );
    
    // ============ ECONOMIC SECURITY AND CONTROLS ============
    
    /**
     * @dev Configure security parameters for buyback operations
     * @param config Security configuration parameters
     */
    function configureSecurityControls(SecurityConfig calldata config) external;
    
    /**
     * @dev Request multisig approval for large buyback operation
     * @param ethAmount ETH amount for buyback
     * @param justification Reason for large buyback
     * @return approvalId Approval request ID
     */
    function requestLargeBuybackApproval(
        uint256 ethAmount,
        string calldata justification
    ) external returns (uint256 approvalId);
    
    /**
     * @dev Approve large buyback operation (multisig)
     * @param approvalId Approval request ID
     */
    function approveLargeBuyback(uint256 approvalId) external;
    
    /**
     * @dev Execute approved large buyback operation
     * @param approvalId Approved request ID
     * @return executionId Buyback execution ID
     */
    function executeLargeBuyback(uint256 approvalId) external returns (uint256 executionId);
    
    /**
     * @dev Enable anti-sandwich attack protection
     * @param maxSlippage Maximum slippage tolerance
     * @param frontrunWindow Time window for frontrun detection
     */
    function enableSandwichProtection(uint256 maxSlippage, uint256 frontrunWindow) external;
    
    /**
     * @dev Enable MEV protection mechanisms
     * @param protectionLevel Level of MEV protection
     * @param maxPriorityFee Maximum priority fee for transactions
     */
    function enableMEVProtection(uint256 protectionLevel, uint256 maxPriorityFee) external;
    
    /**
     * @dev Emergency pause for market manipulation scenarios
     * @param reason Reason for emergency pause
     */
    function emergencyPauseTrading(string calldata reason) external;
    
    /**
     * @dev Get security configuration
     * @return config Current security settings
     * @return approvalsPending Number of pending large buyback approvals
     * @return lastSecurityUpdate Timestamp of last security update
     */
    function getSecurityConfig() 
        external view returns (
            SecurityConfig memory config,
            uint256 approvalsPending,
            uint256 lastSecurityUpdate
        );
    
    // ============ ANALYTICS AND REPORTING ============
    
    /**
     * @dev Get comprehensive revenue metrics
     * @return totalRevenue Total revenue from all sources
     * @param startTimestamp Start time for metrics
     * @param endTimestamp End time for metrics
     */
    function getRevenueMetrics(uint256 startTimestamp, uint256 endTimestamp) 
        external view returns (uint256 totalRevenue);
    
    /**
     * @dev Get revenue breakdown by platform and payment method
     * @return platformBreakdown Revenue by platform type
     * @return paymentBreakdown Revenue by payment method
     */
    function getRevenueBreakdown() 
        external view returns (
            uint256[] memory platformBreakdown,
            uint256[] memory paymentBreakdown
        );
    
    /**
     * @dev Export revenue data for transparency reporting
     * @param fromTimestamp Start timestamp
     * @param toTimestamp End timestamp
     * @return revenueData Detailed revenue transaction data
     */
    function exportRevenueData(uint256 fromTimestamp, uint256 toTimestamp) 
        external view returns (bytes memory revenueData);
    
    // ============ CONFIGURATION AND ADMIN ============
    
    /**
     * @dev Update Oracle address for off-chain revenue verification
     * @param newOracle New Oracle contract address
     */
    function updateOracle(address newOracle) external;
    
    /**
     * @dev Update BuybackBurn contract address
     * @param newBuybackBurn New BuybackBurn contract address
     */
    function updateBuybackBurn(address newBuybackBurn) external;
    
    /**
     * @dev Set minimum thresholds for automatic operations
     * @param revenueThreshold Minimum revenue for buyback trigger
     * @param creditThreshold Minimum credits for conversion
     */
    function setOperationThresholds(uint256 revenueThreshold, uint256 creditThreshold) external;
    
    /**
     * @dev Emergency fund recovery
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to recover
     */
    function emergencyRecovery(address token, uint256 amount) external;
    
    // ============ EVENTS ============
    
    event PlatformConfigured(PlatformType indexed platform, address contractAddress, uint256 feePercentage);
    event PlatformFeesCollected(PlatformType indexed platform, uint256 amount, address indexed payer);
    event CreditSystemConfigured(address indexed oracle, uint256 conversionRate);
    event OffChainRevenueProcessed(uint256 totalAmount, uint256 transactionCount);
    event CreditsIssued(address indexed recipient, uint256 creditsAmount, uint256 usdAmount);
    event CreditsConverted(address indexed user, uint256 creditsAmount, uint256 karmaAmount);
    event SecurityConfigured(uint256 multisigThreshold, uint256 cooldownPeriod);
    event LargeBuybackRequested(uint256 indexed approvalId, uint256 ethAmount, address requester);
    event LargeBuybackApproved(uint256 indexed approvalId, address indexed approver);
    event LargeBuybackExecuted(uint256 indexed approvalId, uint256 executionId);
    event SandwichProtectionEnabled(uint256 maxSlippage, uint256 frontrunWindow);
    event MEVProtectionEnabled(uint256 protectionLevel, uint256 maxPriorityFee);
    event EmergencyTradingPaused(string reason, address indexed pauser);
    event RevenueMetricsUpdated(uint256 totalRevenue, uint256 timestamp);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event BuybackBurnUpdated(address indexed oldContract, address indexed newContract);
    event ThresholdsUpdated(uint256 revenueThreshold, uint256 creditThreshold);
    event EmergencyRecovery(address indexed token, uint256 amount, address indexed recipient);
} 