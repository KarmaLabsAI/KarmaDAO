// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPlatformFeeRouter
 * @dev Interface for Platform Fee Collection and Routing
 * Stage 8.2 - Fee Collection and Routing Requirements
 */
interface IPlatformFeeRouter {
    
    // ============ ENUMS ============
    
    enum PlatformType {
        SILLY_PORT,         // SillyPort platform
        SILLY_HOTEL,        // SillyHotel game
        KARMA_LABS_ASSETS   // KarmaLabs asset platform
    }
    
    enum UserTier {
        BASIC,              // Basic tier
        PREMIUM,            // Premium tier (5% discount)
        VIP,                // VIP tier (10% discount)
        WHALE              // Whale tier (15% discount)
    }
    
    enum FeeType {
        TRANSACTION,        // Transaction fees
        SUBSCRIPTION,       // Subscription fees
        PREMIUM_FEATURE,    // Premium feature fees
        MARKETPLACE,        // Marketplace fees
        ROYALTY            // Royalty fees
    }
    
    // ============ STRUCTS ============
    
    struct FeeConfig {
        uint256 basePercentage;
        uint256 minimumFee;
        uint256 maximumFee;
        bool isActive;
        uint256 lastUpdated;
    }
    
    struct UserFeeProfile {
        UserTier tier;
        uint256 totalSpent;
        uint256 discountPercentage;
        uint256 karmaHoldings;
        bool isPremiumSubscriber;
        uint256 lastActivity;
    }
    
    struct FeeCollectionData {
        bytes32 collectionId;
        PlatformType platform;
        FeeType feeType;
        address payer;
        uint256 amount;
        uint256 actualFee;
        uint256 discountApplied;
        uint256 timestamp;
        bool isRouted;
    }
    
    struct OptimizationMetrics {
        uint256 totalCollected;
        uint256 totalRouted;
        uint256 averageFee;
        uint256 discountsApplied;
        uint256 gasOptimization;
        uint256 lastOptimization;
    }
    
    // ============ EVENTS ============
    
    event FeeCollected(bytes32 indexed collectionId, PlatformType platform, FeeType feeType, address indexed payer, uint256 amount, uint256 actualFee);
    event FeeRouted(bytes32 indexed collectionId, address indexed destination, uint256 amount);
    event UserTierUpdated(address indexed user, UserTier oldTier, UserTier newTier);
    event FeeConfigUpdated(PlatformType platform, FeeType feeType, FeeConfig config);
    event OptimizationExecuted(uint256 totalOptimized, uint256 gasUsed);
    
    // ============ FEE COLLECTION FUNCTIONS ============
    
    /**
     * @dev Collect fees from platform transactions
     * @param platform Platform type
     * @param feeType Type of fee
     * @param baseAmount Base transaction amount
     * @param payer Address paying the fee
     * @return collectionId Unique collection identifier
     * @return actualFee Actual fee collected after optimizations
     */
    function collectFee(
        PlatformType platform,
        FeeType feeType,
        uint256 baseAmount,
        address payer
    ) external payable returns (bytes32 collectionId, uint256 actualFee);
    
    /**
     * @dev Route collected fees to destination contracts
     * @param collectionIds Array of collection IDs to route
     * @return totalRouted Total amount routed
     */
    function routeFees(bytes32[] calldata collectionIds) external returns (uint256 totalRouted);
    
    /**
     * @dev Calculate optimal fee for user and transaction
     * @param platform Platform type
     * @param feeType Type of fee
     * @param baseAmount Base transaction amount
     * @param user User address
     * @return optimalFee Calculated optimal fee
     * @return discountPercentage Applied discount percentage
     */
    function calculateOptimalFee(
        PlatformType platform,
        FeeType feeType,
        uint256 baseAmount,
        address user
    ) external view returns (uint256 optimalFee, uint256 discountPercentage);
    
    // ============ USER TIER MANAGEMENT ============
    
    /**
     * @dev Update user tier based on activity and holdings
     * @param user User address
     * @return newTier Updated user tier
     */
    function updateUserTier(address user) external returns (UserTier newTier);
    
    /**
     * @dev Get user fee profile
     * @param user User address
     * @return profile User fee profile
     */
    function getUserFeeProfile(address user) external view returns (UserFeeProfile memory profile);
    
    /**
     * @dev Check if user qualifies for tier upgrade
     * @param user User address
     * @return qualifiesForUpgrade Whether user qualifies for upgrade
     * @return suggestedTier Suggested tier if upgrade available
     */
    function checkTierUpgrade(address user) external view returns (bool qualifiesForUpgrade, UserTier suggestedTier);
    
    // ============ FEE CONFIGURATION ============
    
    /**
     * @dev Configure fee structure for platform and fee type
     * @param platform Platform type
     * @param feeType Fee type
     * @param config Fee configuration
     */
    function configureFee(PlatformType platform, FeeType feeType, FeeConfig calldata config) external;
    
    /**
     * @dev Get fee configuration
     * @param platform Platform type
     * @param feeType Fee type
     * @return config Fee configuration
     */
    function getFeeConfig(PlatformType platform, FeeType feeType) external view returns (FeeConfig memory config);
    
    /**
     * @dev Bulk update fee configurations
     * @param platforms Array of platform types
     * @param feeTypes Array of fee types
     * @param configs Array of fee configurations
     */
    function bulkConfigureFees(
        PlatformType[] calldata platforms,
        FeeType[] calldata feeTypes,
        FeeConfig[] calldata configs
    ) external;
    
    // ============ FEE OPTIMIZATION ============
    
    /**
     * @dev Execute fee optimization algorithm
     * @return optimizedAmount Total amount optimized
     * @return gasUsed Gas used for optimization
     */
    function executeOptimization() external returns (uint256 optimizedAmount, uint256 gasUsed);
    
    /**
     * @dev Get optimization metrics
     * @return metrics Current optimization metrics
     */
    function getOptimizationMetrics() external view returns (OptimizationMetrics memory metrics);
    
    /**
     * @dev Predict optimal fee for future transaction
     * @param platform Platform type
     * @param feeType Fee type
     * @param baseAmount Base amount
     * @param user User address
     * @param futureTimestamp Future timestamp
     * @return predictedFee Predicted optimal fee
     */
    function predictOptimalFee(
        PlatformType platform,
        FeeType feeType,
        uint256 baseAmount,
        address user,
        uint256 futureTimestamp
    ) external view returns (uint256 predictedFee);
    
    // ============ ANALYTICS AND REPORTING ============
    
    /**
     * @dev Get fee collection statistics
     * @param platform Platform type
     * @return totalCollected Total fees collected
     * @return totalRouted Total fees routed
     * @return averageFee Average fee amount
     * @return uniqueUsers Number of unique users
     */
    function getFeeStats(PlatformType platform) external view returns (
        uint256 totalCollected,
        uint256 totalRouted,
        uint256 averageFee,
        uint256 uniqueUsers
    );
    
    /**
     * @dev Get user fee history
     * @param user User address
     * @param limit Number of records to return
     * @return collections Array of fee collections
     */
    function getUserFeeHistory(address user, uint256 limit) external view returns (FeeCollectionData[] memory collections);
    
    /**
     * @dev Get platform fee breakdown
     * @param platform Platform type
     * @return feeTypes Array of fee types
     * @return amounts Array of amounts collected per type
     * @return percentages Array of percentage distribution
     */
    function getPlatformFeeBreakdown(PlatformType platform) external view returns (
        FeeType[] memory feeTypes,
        uint256[] memory amounts,
        uint256[] memory percentages
    );
    
    // ============ INTEGRATION FUNCTIONS ============
    
    /**
     * @dev Register platform for fee collection
     * @param platform Platform type
     * @param platformAddress Platform contract address
     * @return success Whether registration was successful
     */
    function registerPlatform(PlatformType platform, address platformAddress) external returns (bool success);
    
    /**
     * @dev Set buyback burn contract for fee routing
     * @param buybackBurnAddress BuybackBurn contract address
     */
    function setBuybackBurnContract(address buybackBurnAddress) external;
    
    /**
     * @dev Set revenue stream integrator for advanced routing
     * @param revenueStreamAddress RevenueStreamIntegrator contract address
     */
    function setRevenueStreamIntegrator(address revenueStreamAddress) external;
    
    /**
     * @dev Emergency withdrawal of stuck fees
     * @param amount Amount to withdraw (0 = all)
     * @return withdrawnAmount Amount withdrawn
     */
    function emergencyWithdraw(uint256 amount) external returns (uint256 withdrawnAmount);
}
