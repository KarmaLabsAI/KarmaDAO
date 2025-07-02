// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBuybackBurn
 * @dev Interface for the BuybackBurn contract implementing Stage 6.1 requirements
 * 
 * Stage 6.1 Features:
 * - DEX Integration Engine with Uniswap V3 and multi-DEX support
 * - Automatic Triggering System with monthly schedule and $50K threshold
 * - Fee Collection Integration from platform transactions
 * - Burn Mechanism Implementation with KarmaToken integration
 * 
 * Key Requirements:
 * - Automated token buyback from multiple DEXes with optimal routing
 * - Price impact calculation and slippage protection (max 5%)
 * - Chainlink Keepers integration for automated execution
 * - Fee collection from platform transactions (0.5% iNFT trades, 10% credit surcharges)
 * - Token burn with comprehensive logging and transparency
 */
interface IBuybackBurn {
    
    // ============ ENUMS ============
    
    enum DEXType {
        UNISWAP_V3,
        SUSHISWAP,
        BALANCER,
        CURVE
    }
    
    enum TriggerType {
        MANUAL,
        SCHEDULED,
        THRESHOLD,
        EMERGENCY
    }
    
    enum FeeSource {
        INFT_TRADES,           // 0.5% from iNFT trades
        CREDIT_SURCHARGE,      // 10% on non-crypto payments
        PREMIUM_SUBSCRIPTION,  // $15/month fees
        LICENSING_FEES         // Third-party licensing revenue
    }
    
    // ============ STRUCTS ============
    
    struct DEXConfig {
        address router;           // DEX router address
        address factory;          // DEX factory address
        uint24 poolFee;          // Pool fee tier
        bool isActive;           // Whether DEX is active
        uint256 minLiquidity;    // Minimum liquidity threshold
        uint256 maxSlippage;     // Maximum allowed slippage (basis points)
    }
    
    struct BuybackExecution {
        uint256 id;              // Unique execution ID
        uint256 timestamp;       // Execution timestamp
        uint256 ethAmount;       // ETH used for buyback
        uint256 tokensReceived;  // KARMA tokens received
        uint256 tokensBurned;    // KARMA tokens burned
        DEXType dexUsed;         // DEX used for swap
        TriggerType triggerType; // How execution was triggered
        uint256 priceImpact;     // Price impact percentage (basis points)
        address executor;        // Address that triggered execution
    }
    
    struct AutoTriggerConfig {
        bool enabled;            // Whether auto-triggering is enabled
        uint256 monthlySchedule; // Monthly execution schedule (day of month)
        uint256 thresholdAmount; // ETH threshold for execution ($50K default)
        uint256 lastExecution;   // Last automatic execution timestamp
        uint256 cooldownPeriod;  // Minimum time between executions
    }
    
    struct FeeCollectionConfig {
        FeeSource source;        // Source of fees
        address collector;       // Address authorized to collect fees
        uint256 percentage;      // Fee percentage (basis points)
        bool isActive;          // Whether fee collection is active
        uint256 totalCollected; // Total fees collected from this source
    }
    
    struct SwapParams {
        DEXType dex;            // Preferred DEX
        uint256 amountIn;       // ETH amount to swap
        uint256 minAmountOut;   // Minimum KARMA tokens expected
        uint256 maxSlippage;    // Maximum slippage tolerance
        uint256 deadline;       // Transaction deadline
    }
    
    struct BuybackMetrics {
        uint256 totalETHSpent;      // Total ETH used for buybacks
        uint256 totalTokensBought;  // Total KARMA tokens purchased
        uint256 totalTokensBurned;  // Total KARMA tokens burned
        uint256 totalExecutions;    // Number of buyback executions
        uint256 averagePrice;       // Average purchase price
        uint256 lastExecution;      // Last execution timestamp
        uint256 priceImpactAvg;     // Average price impact
    }
    
    // ============ DEX INTEGRATION ENGINE ============
    
    /**
     * @dev Configure DEX parameters and routing
     * @param dexType Type of DEX to configure
     * @param config DEX configuration parameters
     */
    function configureDEX(DEXType dexType, DEXConfig calldata config) external;
    
    /**
     * @dev Get optimal swap route for given amount
     * @param ethAmount ETH amount to swap
     * @return bestDex Optimal DEX for swap
     * @return expectedTokens Expected KARMA tokens
     * @return priceImpact Estimated price impact (basis points)
     */
    function getOptimalRoute(uint256 ethAmount) 
        external view returns (DEXType bestDex, uint256 expectedTokens, uint256 priceImpact);
    
    /**
     * @dev Execute token buyback with optimal routing
     * @param params Swap parameters
     * @return tokensReceived KARMA tokens received from swap
     */
    function executeSwap(SwapParams calldata params) external returns (uint256 tokensReceived);
    
    /**
     * @dev Calculate price impact for swap
     * @param dex DEX to use for calculation
     * @param ethAmount ETH amount for swap
     * @return priceImpact Price impact in basis points
     */
    function calculatePriceImpact(DEXType dex, uint256 ethAmount) 
        external view returns (uint256 priceImpact);
    
    /**
     * @dev Get DEX configuration
     * @param dexType DEX to query
     * @return config DEX configuration
     */
    function getDEXConfig(DEXType dexType) external view returns (DEXConfig memory config);
    
    // ============ AUTOMATIC TRIGGERING SYSTEM ============
    
    /**
     * @dev Configure automatic triggering parameters
     * @param config Auto-trigger configuration
     */
    function configureAutoTrigger(AutoTriggerConfig calldata config) external;
    
    /**
     * @dev Check if automatic execution should be triggered
     * @return shouldExecute Whether execution should happen
     * @return triggerType Type of trigger (schedule/threshold)
     * @return ethAmount Amount of ETH to use for buyback
     */
    function checkTriggerCondition() 
        external view returns (bool shouldExecute, TriggerType triggerType, uint256 ethAmount);
    
    /**
     * @dev Execute automatic buyback (Chainlink Keepers compatible)
     * @return success Whether execution was successful
     * @return executionId ID of the execution
     */
    function performUpkeep() external returns (bool success, uint256 executionId);
    
    /**
     * @dev Manual trigger for buyback execution
     * @param ethAmount ETH amount to use for buyback
     * @param maxSlippage Maximum slippage tolerance
     * @return executionId ID of the execution
     */
    function manualTrigger(uint256 ethAmount, uint256 maxSlippage) 
        external returns (uint256 executionId);
    
    /**
     * @dev Emergency trigger with admin override
     * @param ethAmount ETH amount to use
     * @param dex Specific DEX to use
     * @return executionId ID of the execution
     */
    function emergencyTrigger(uint256 ethAmount, DEXType dex) 
        external returns (uint256 executionId);
    
    /**
     * @dev Get auto-trigger configuration
     * @return config Current auto-trigger settings
     */
    function getAutoTriggerConfig() external view returns (AutoTriggerConfig memory config);
    
    // ============ FEE COLLECTION INTEGRATION ============
    
    /**
     * @dev Configure fee collection from different sources
     * @param source Fee source type
     * @param config Fee collection configuration
     */
    function configureFeeCollection(FeeSource source, FeeCollectionConfig calldata config) external;
    
    /**
     * @dev Collect fees from platform transactions (0.5% iNFT trades)
     * @param amount Fee amount collected
     * @param source Source of the fees
     */
    function collectPlatformFees(uint256 amount, FeeSource source) external payable;
    
    /**
     * @dev Collect credit system surcharge (10% on non-crypto payments)
     * @param amount Surcharge amount from off-chain payments
     */
    function collectCreditSurcharge(uint256 amount) external payable;
    
    /**
     * @dev Collect premium subscription revenue ($15/month fees)
     * @param subscriberCount Number of premium subscribers
     * @param monthlyFee Monthly fee amount per subscriber
     */
    function collectSubscriptionRevenue(uint256 subscriberCount, uint256 monthlyFee) external payable;
    
    /**
     * @dev Collect third-party licensing fees
     * @param licensor Address of the licensor
     * @param amount Licensing fee amount
     */
    function collectLicensingFees(address licensor, uint256 amount) external payable;
    
    /**
     * @dev Get fee collection configuration
     * @param source Fee source to query
     * @return config Fee collection settings
     */
    function getFeeCollectionConfig(FeeSource source) 
        external view returns (FeeCollectionConfig memory config);
    
    /**
     * @dev Get total fees collected from all sources
     * @return totalFees Total ETH collected
     * @return feeBreakdown Breakdown by source
     */
    function getTotalFeesCollected() 
        external view returns (uint256 totalFees, uint256[] memory feeBreakdown);
    
    // ============ BURN MECHANISM IMPLEMENTATION ============
    
    /**
     * @dev Execute token burn after buyback
     * @param amount Amount of KARMA tokens to burn
     * @return success Whether burn was successful
     */
    function burnTokens(uint256 amount) external returns (bool success);
    
    /**
     * @dev Batch burn tokens for gas efficiency
     * @param amounts Array of token amounts to burn
     * @return totalBurned Total tokens burned
     */
    function batchBurnTokens(uint256[] calldata amounts) external returns (uint256 totalBurned);
    
    /**
     * @dev Calculate optimal burn amount based on circulating supply and price
     * @param availableTokens Tokens available for burning
     * @return recommendedBurn Recommended burn amount
     * @return reasoning Reasoning for the recommendation
     */
    function calculateOptimalBurn(uint256 availableTokens) 
        external view returns (uint256 recommendedBurn, string memory reasoning);
    
    /**
     * @dev Get burn statistics
     * @return totalBurned Total tokens burned to date
     * @return burnCount Number of burn operations
     * @return lastBurn Timestamp of last burn
     * @return currentSupply Current circulating supply
     */
    function getBurnStatistics() 
        external view returns (
            uint256 totalBurned, 
            uint256 burnCount, 
            uint256 lastBurn, 
            uint256 currentSupply
        );
    
    // ============ REPORTING AND ANALYTICS ============
    
    /**
     * @dev Get comprehensive buyback metrics
     * @return metrics Detailed buyback statistics
     */
    function getBuybackMetrics() external view returns (BuybackMetrics memory metrics);
    
    /**
     * @dev Get execution history for time range
     * @param fromTimestamp Start timestamp
     * @param toTimestamp End timestamp
     * @return executions Array of executions in time range
     */
    function getExecutionHistory(uint256 fromTimestamp, uint256 toTimestamp) 
        external view returns (BuybackExecution[] memory executions);
    
    /**
     * @dev Get current contract balance and allocation status
     * @return ethBalance Current ETH balance
     * @return karmaBalance Current KARMA token balance
     * @return availableForBuyback ETH available for next buyback
     */
    function getBalanceStatus() 
        external view returns (uint256 ethBalance, uint256 karmaBalance, uint256 availableForBuyback);
    
    /**
     * @dev Export transaction data for transparency
     * @param fromTimestamp Start timestamp
     * @param toTimestamp End timestamp
     * @return transactions Detailed transaction data
     */
    function exportTransactionData(uint256 fromTimestamp, uint256 toTimestamp) 
        external view returns (bytes memory transactions);
    
    // ============ CONFIGURATION AND ADMIN ============
    
    /**
     * @dev Update KarmaToken contract address
     * @param newToken New KarmaToken contract address
     */
    function updateKarmaToken(address newToken) external;
    
    /**
     * @dev Update Treasury contract address for funding
     * @param newTreasury New Treasury contract address
     */
    function updateTreasury(address newTreasury) external;
    
    /**
     * @dev Set minimum buyback threshold
     * @param threshold Minimum ETH amount for buyback execution
     */
    function setMinimumThreshold(uint256 threshold) external;
    
    /**
     * @dev Set maximum slippage tolerance
     * @param slippage Maximum slippage in basis points (default 500 = 5%)
     */
    function setMaxSlippage(uint256 slippage) external;
    
    /**
     * @dev Emergency pause all buyback operations
     */
    function emergencyPause() external;
    
    /**
     * @dev Resume buyback operations
     */
    function emergencyUnpause() external;
    
    /**
     * @dev Withdraw emergency funds to Treasury
     * @param amount Amount to withdraw (0 = all)
     */
    function emergencyWithdraw(uint256 amount) external;
    
    // ============ EVENTS ============
    
    event DEXConfigured(DEXType indexed dexType, address router, bool isActive);
    event AutoTriggerConfigured(bool enabled, uint256 threshold, uint256 monthlySchedule);
    event FeeCollectionConfigured(FeeSource indexed source, address collector, uint256 percentage);
    
    event BuybackExecuted(
        uint256 indexed executionId,
        uint256 ethAmount,
        uint256 tokensReceived,
        uint256 tokensBurned,
        DEXType dexUsed,
        TriggerType triggerType,
        uint256 priceImpact
    );
    
    event TokensBurned(uint256 amount, uint256 newTotalSupply, address burner);
    event FeesCollected(FeeSource indexed source, uint256 amount, address collector);
    event OptimalRouteCalculated(DEXType bestDex, uint256 expectedTokens, uint256 priceImpact);
    
    event SlippageProtectionTriggered(DEXType dex, uint256 expectedSlippage, uint256 maxSlippage);
    event AutoTriggerExecuted(TriggerType triggerType, uint256 ethAmount, uint256 executionId);
    event EmergencyAction(string action, address executor, uint256 amount);
    
    event KarmaTokenUpdated(address indexed oldToken, address indexed newToken);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event SlippageUpdated(uint256 oldSlippage, uint256 newSlippage);
    
    event BuybackPaused(address indexed pauser);
    event BuybackUnpaused(address indexed unpauser);
} 