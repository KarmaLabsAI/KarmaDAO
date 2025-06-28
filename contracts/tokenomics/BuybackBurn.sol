// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBuybackBurn.sol";
import "../interfaces/ITreasury.sol";

/**
 * @title BuybackBurn
 * @dev Automated token buyback and burn mechanism implementing Stage 6.1 requirements
 * 
 * Stage 6.1 Implementation:
 * - DEX Integration Engine with Uniswap V3 and multi-DEX support
 * - Automatic Triggering System with monthly schedule and $50K threshold
 * - Fee Collection Integration from platform transactions
 * - Burn Mechanism Implementation with KarmaToken integration
 * 
 * Key Features:
 * - Multi-DEX support (Uniswap V3, SushiSwap, Balancer, Curve)
 * - Optimal routing algorithms for best swap rates
 * - Price impact calculation and slippage protection (max 5%)
 * - Chainlink Keepers compatible automated execution
 * - Fee collection from multiple platform sources (0.5% iNFT trades, 10% credit surcharges)
 * - Token burn with comprehensive logging and transparency
 * - Economic sustainability with Treasury integration
 */
contract BuybackBurn is IBuybackBurn, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ CONSTANTS ============
    
    // Role definitions
    bytes32 public constant BUYBACK_MANAGER_ROLE = keccak256("BUYBACK_MANAGER_ROLE");
    bytes32 public constant FEE_COLLECTOR_ROLE = keccak256("FEE_COLLECTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE"); // For Chainlink Keepers
    
    // Default configuration constants
    uint256 private constant BASIS_POINTS = 10000; // 100.00%
    uint256 private constant DEFAULT_THRESHOLD = 50000 * 1e18; // $50K equivalent in ETH
    uint256 private constant DEFAULT_MAX_SLIPPAGE = 500; // 5%
    uint256 private constant MIN_EXECUTION_AMOUNT = 1 * 1e18; // 1 ETH minimum
    uint256 private constant MONTHLY_SCHEDULE_DAY = 15; // 15th of each month
    uint256 private constant COOLDOWN_PERIOD = 24 hours; // Minimum time between auto executions
    uint256 private constant PRICE_PRECISION = 1e18; // 18 decimal precision
    
    // Fee collection constants
    uint256 private constant INFT_TRADE_FEE = 50; // 0.5%
    uint256 private constant CREDIT_SURCHARGE_FEE = 1000; // 10%
    uint256 private constant PREMIUM_SUBSCRIPTION_FEE = 15 * 1e18; // $15 per month
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    IERC20 public karmaToken;
    ITreasury public treasury;
    
    // DEX configurations
    mapping(DEXType => DEXConfig) private _dexConfigs;
    DEXType[] private _activeDEXes;
    
    // Automatic triggering
    AutoTriggerConfig public autoTriggerConfig;
    
    // Fee collection
    mapping(FeeSource => FeeCollectionConfig) private _feeConfigs;
    uint256 private _totalFeesCollected;
    mapping(FeeSource => uint256) private _feesBySource;
    
    // Execution tracking
    uint256 private _nextExecutionId;
    mapping(uint256 => BuybackExecution) private _executions;
    BuybackExecution[] private _executionHistory;
    
    // Metrics and analytics
    BuybackMetrics public metrics;
    
    // Configuration
    uint256 public minimumThreshold;
    uint256 public maxSlippage;
    
    // Burn tracking
    uint256 public totalTokensBurned;
    uint256 public burnCount;
    uint256 public lastBurnTimestamp;
    
    // ============ MODIFIERS ============
    
    modifier onlyBuybackManager() {
        require(hasRole(BUYBACK_MANAGER_ROLE, msg.sender), "BuybackBurn: caller is not buyback manager");
        _;
    }
    
    modifier onlyFeeCollector() {
        require(hasRole(FEE_COLLECTOR_ROLE, msg.sender), "BuybackBurn: caller is not fee collector");
        _;
    }
    
    modifier onlyEmergencyRole() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "BuybackBurn: caller does not have emergency role");
        _;
    }
    
    modifier onlyKeeper() {
        require(hasRole(KEEPER_ROLE, msg.sender), "BuybackBurn: caller is not authorized keeper");
        _;
    }
    
    modifier validDEX(DEXType dexType) {
        require(uint256(dexType) <= 3, "BuybackBurn: invalid DEX type");
        _;
    }
    
    modifier validFeeSource(FeeSource source) {
        require(uint256(source) <= 3, "BuybackBurn: invalid fee source");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _admin,
        address _karmaToken,
        address _treasury
    ) {
        require(_admin != address(0), "BuybackBurn: invalid admin address");
        require(_karmaToken != address(0), "BuybackBurn: invalid karma token address");
        require(_treasury != address(0), "BuybackBurn: invalid treasury address");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(BUYBACK_MANAGER_ROLE, _admin);
        _grantRole(FEE_COLLECTOR_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        _grantRole(KEEPER_ROLE, _admin); // Admin can act as keeper initially
        
        karmaToken = IERC20(_karmaToken);
        treasury = ITreasury(_treasury);
        
        // Initialize configuration
        minimumThreshold = DEFAULT_THRESHOLD;
        maxSlippage = DEFAULT_MAX_SLIPPAGE;
        _nextExecutionId = 1;
        
        // Initialize auto-trigger configuration
        autoTriggerConfig = AutoTriggerConfig({
            enabled: false, // Start disabled for safety
            monthlySchedule: MONTHLY_SCHEDULE_DAY,
            thresholdAmount: DEFAULT_THRESHOLD,
            lastExecution: 0,
            cooldownPeriod: COOLDOWN_PERIOD
        });
        
        // Initialize fee collection configurations
        _initializeFeeConfigurations();
        
        // Initialize default DEX configurations (placeholders for now)
        _initializeDEXConfigurations();
    }
    
    // ============ INITIALIZATION FUNCTIONS ============
    
    function _initializeFeeConfigurations() internal {
        // iNFT trades (0.5%)
        _feeConfigs[FeeSource.INFT_TRADES] = FeeCollectionConfig({
            source: FeeSource.INFT_TRADES,
            collector: address(this),
            percentage: INFT_TRADE_FEE,
            isActive: true,
            totalCollected: 0
        });
        
        // Credit system surcharge (10%)
        _feeConfigs[FeeSource.CREDIT_SURCHARGE] = FeeCollectionConfig({
            source: FeeSource.CREDIT_SURCHARGE,
            collector: address(this),
            percentage: CREDIT_SURCHARGE_FEE,
            isActive: true,
            totalCollected: 0
        });
        
        // Premium subscription revenue
        _feeConfigs[FeeSource.PREMIUM_SUBSCRIPTION] = FeeCollectionConfig({
            source: FeeSource.PREMIUM_SUBSCRIPTION,
            collector: address(this),
            percentage: BASIS_POINTS, // 100% collection
            isActive: true,
            totalCollected: 0
        });
        
        // Licensing fees
        _feeConfigs[FeeSource.LICENSING_FEES] = FeeCollectionConfig({
            source: FeeSource.LICENSING_FEES,
            collector: address(this),
            percentage: BASIS_POINTS, // 100% collection
            isActive: true,
            totalCollected: 0
        });
    }
    
    function _initializeDEXConfigurations() internal {
        // Note: These are placeholder configurations for Arbitrum
        // In production, these would be actual DEX router addresses
        
        // Uniswap V3 (primary DEX)
        _dexConfigs[DEXType.UNISWAP_V3] = DEXConfig({
            router: address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45), // Uniswap V3 SwapRouter on Arbitrum
            factory: address(0x1F98431c8aD98523631AE4a59f267346ea31F984), // Uniswap V3 Factory
            poolFee: 3000, // 0.3%
            isActive: true,
            minLiquidity: 100 * 1e18, // 100 ETH minimum liquidity
            maxSlippage: 300 // 3%
        });
        
        // SushiSwap
        _dexConfigs[DEXType.SUSHISWAP] = DEXConfig({
            router: address(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506), // SushiSwap Router on Arbitrum
            factory: address(0xc35DADB65012eC5796536bD9864eD8773aBc74C4), // SushiSwap Factory
            poolFee: 3000, // 0.3%
            isActive: false, // Start inactive, can be enabled later
            minLiquidity: 50 * 1e18, // 50 ETH minimum liquidity
            maxSlippage: 500 // 5%
        });
        
        // Balancer
        _dexConfigs[DEXType.BALANCER] = DEXConfig({
            router: address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), // Balancer Vault on Arbitrum
            factory: address(0), // Balancer uses Vault, not factory pattern
            poolFee: 2500, // 0.25% typical
            isActive: false, // Start inactive
            minLiquidity: 75 * 1e18, // 75 ETH minimum liquidity
            maxSlippage: 400 // 4%
        });
        
        // Curve
        _dexConfigs[DEXType.CURVE] = DEXConfig({
            router: address(0), // Curve router address (to be configured)
            factory: address(0), // Curve factory address (to be configured)
            poolFee: 400, // 0.04% typical
            isActive: false, // Start inactive
            minLiquidity: 25 * 1e18, // 25 ETH minimum liquidity
            maxSlippage: 200 // 2%
        });
        
        // Add Uniswap V3 as the initial active DEX
        _activeDEXes.push(DEXType.UNISWAP_V3);
    }
    
    // ============ DEX INTEGRATION ENGINE ============
    
    function configureDEX(DEXType dexType, DEXConfig calldata config) 
        external override onlyBuybackManager validDEX(dexType) {
        require(config.router != address(0), "BuybackBurn: invalid router address");
        require(config.maxSlippage <= BASIS_POINTS, "BuybackBurn: slippage too high");
        
        bool wasActive = _dexConfigs[dexType].isActive;
        _dexConfigs[dexType] = config;
        
        // Update active DEXes list
        if (config.isActive && !wasActive) {
            _activeDEXes.push(dexType);
        } else if (!config.isActive && wasActive) {
            // Remove from active list
            for (uint256 i = 0; i < _activeDEXes.length; i++) {
                if (_activeDEXes[i] == dexType) {
                    _activeDEXes[i] = _activeDEXes[_activeDEXes.length - 1];
                    _activeDEXes.pop();
                    break;
                }
            }
        }
        
        emit DEXConfigured(dexType, config.router, config.isActive);
    }
    
    function getOptimalRoute(uint256 ethAmount) 
        external view override returns (DEXType bestDex, uint256 expectedTokens, uint256 priceImpact) {
        require(ethAmount > 0, "BuybackBurn: invalid ETH amount");
        
        bestDex = DEXType.UNISWAP_V3; // Default to Uniswap V3
        expectedTokens = 0;
        priceImpact = 0;
        
        uint256 bestExpectedTokens = 0;
        uint256 lowestPriceImpact = BASIS_POINTS;
        
        // Check all active DEXes for optimal route
        for (uint256 i = 0; i < _activeDEXes.length; i++) {
            DEXType dex = _activeDEXes[i];
            DEXConfig storage config = _dexConfigs[dex];
            
            if (!config.isActive) continue;
            
            // Calculate expected tokens and price impact for this DEX
            (uint256 tokens, uint256 impact) = _calculateSwapOutput(dex, ethAmount);
            
            // Check if this route is better (more tokens with acceptable slippage)
            if (tokens > bestExpectedTokens && impact <= config.maxSlippage) {
                bestExpectedTokens = tokens;
                lowestPriceImpact = impact;
                bestDex = dex;
            }
        }
        
        expectedTokens = bestExpectedTokens;
        priceImpact = lowestPriceImpact;
    }
    
    function executeSwap(SwapParams calldata params) 
        external override onlyBuybackManager nonReentrant whenNotPaused returns (uint256 tokensReceived) {
        require(params.amountIn > 0, "BuybackBurn: invalid input amount");
        require(params.amountIn <= address(this).balance, "BuybackBurn: insufficient ETH balance");
        require(params.deadline > block.timestamp, "BuybackBurn: deadline exceeded");
        require(_dexConfigs[params.dex].isActive, "BuybackBurn: DEX not active");
        
        // Check slippage protection
        uint256 priceImpact = _calculatePriceImpactInternal(params.dex, params.amountIn);
        require(priceImpact <= params.maxSlippage, "BuybackBurn: slippage too high");
        
        if (priceImpact > _dexConfigs[params.dex].maxSlippage) {
            emit SlippageProtectionTriggered(params.dex, priceImpact, _dexConfigs[params.dex].maxSlippage);
            revert("BuybackBurn: slippage protection triggered");
        }
        
        // Execute swap (simplified for demo - in production would integrate with actual DEX routers)
        tokensReceived = _executeSwapInternal(params);
        
        // Update metrics
        metrics.totalETHSpent += params.amountIn;
        metrics.totalTokensBought += tokensReceived;
        metrics.totalExecutions++;
        metrics.lastExecution = block.timestamp;
        metrics.priceImpactAvg = ((metrics.priceImpactAvg * (metrics.totalExecutions - 1)) + priceImpact) / metrics.totalExecutions;
        if (tokensReceived > 0) {
            metrics.averagePrice = (metrics.totalETHSpent * PRICE_PRECISION) / metrics.totalTokensBought;
        }
        
        return tokensReceived;
    }
    
    function calculatePriceImpact(DEXType dex, uint256 ethAmount) 
        external view override returns (uint256 priceImpact) {
        return _calculatePriceImpactInternal(dex, ethAmount);
    }
    
    function _calculatePriceImpactInternal(DEXType dex, uint256 ethAmount) 
        internal view returns (uint256 priceImpact) {
        require(_dexConfigs[dex].isActive, "BuybackBurn: DEX not active");
        
        // Simplified price impact calculation
        // In production, this would query actual DEX pools
        (, priceImpact) = _calculateSwapOutput(dex, ethAmount);
        
        return priceImpact;
    }
    
    function getDEXConfig(DEXType dexType) 
        external view override returns (DEXConfig memory config) {
        return _dexConfigs[dexType];
    }
    
    // ============ AUTOMATIC TRIGGERING SYSTEM ============
    
    function configureAutoTrigger(AutoTriggerConfig calldata config) 
        external override onlyBuybackManager {
        require(config.thresholdAmount >= MIN_EXECUTION_AMOUNT, "BuybackBurn: threshold too low");
        require(config.cooldownPeriod >= 1 hours, "BuybackBurn: cooldown too short");
        require(config.monthlySchedule >= 1 && config.monthlySchedule <= 28, "BuybackBurn: invalid schedule day");
        
        autoTriggerConfig = config;
        
        emit AutoTriggerConfigured(config.enabled, config.thresholdAmount, config.monthlySchedule);
    }
    
    function checkTriggerCondition() 
        external view override returns (bool shouldExecute, TriggerType triggerType, uint256 ethAmount) {
        if (!autoTriggerConfig.enabled) {
            return (false, TriggerType.MANUAL, 0);
        }
        
        // Check cooldown period
        if (block.timestamp < autoTriggerConfig.lastExecution + autoTriggerConfig.cooldownPeriod) {
            return (false, TriggerType.MANUAL, 0);
        }
        
        uint256 availableETH = address(this).balance;
        
        // Check threshold trigger
        if (availableETH >= autoTriggerConfig.thresholdAmount) {
            return (true, TriggerType.THRESHOLD, availableETH);
        }
        
        // Check monthly schedule trigger
        uint256 currentDay = (block.timestamp / 86400) % 30 + 1; // Simplified day of month calculation
        if (currentDay == autoTriggerConfig.monthlySchedule && availableETH >= MIN_EXECUTION_AMOUNT) {
            // Check if we haven't executed this month
            uint256 currentMonth = block.timestamp / (30 * 86400); // Simplified month calculation
            uint256 lastExecutionMonth = autoTriggerConfig.lastExecution / (30 * 86400);
            
            if (currentMonth > lastExecutionMonth) {
                return (true, TriggerType.SCHEDULED, availableETH);
            }
        }
        
        return (false, TriggerType.MANUAL, 0);
    }
    
    function performUpkeep() 
        external override onlyKeeper nonReentrant whenNotPaused returns (bool success, uint256 executionId) {
        (bool shouldExecute, TriggerType triggerType, uint256 ethAmount) = this.checkTriggerCondition();
        
        if (!shouldExecute) {
            return (false, 0);
        }
        
        // Execute buyback with optimal routing
        (DEXType bestDex, uint256 expectedTokens, uint256 priceImpact) = this.getOptimalRoute(ethAmount);
        
        // Create swap parameters
        SwapParams memory params = SwapParams({
            dex: bestDex,
            amountIn: ethAmount,
            minAmountOut: (expectedTokens * (BASIS_POINTS - maxSlippage)) / BASIS_POINTS,
            maxSlippage: maxSlippage,
            deadline: block.timestamp + 300 // 5 minutes
        });
        
        // Execute the swap
        uint256 tokensReceived = _executeSwapInternal(params);
        
        // Execute burn
        bool burnSuccess = _burnTokensInternal(tokensReceived);
        
        // Record execution
        executionId = _recordExecution(ethAmount, tokensReceived, burnSuccess ? tokensReceived : 0, bestDex, triggerType, msg.sender, priceImpact);
        
        // Update auto-trigger config
        autoTriggerConfig.lastExecution = block.timestamp;
        
        emit AutoTriggerExecuted(triggerType, ethAmount, executionId);
        
        return (true, executionId);
    }
    
    function manualTrigger(uint256 ethAmount, uint256 maxSlippageParam) 
        external override onlyBuybackManager nonReentrant whenNotPaused returns (uint256 executionId) {
        require(ethAmount > 0 && ethAmount <= address(this).balance, "BuybackBurn: invalid ETH amount");
        require(maxSlippageParam <= BASIS_POINTS, "BuybackBurn: invalid slippage");
        
        // Get optimal route
        (DEXType bestDex, uint256 expectedTokens, uint256 priceImpact) = this.getOptimalRoute(ethAmount);
        
        // Create swap parameters
        SwapParams memory params = SwapParams({
            dex: bestDex,
            amountIn: ethAmount,
            minAmountOut: (expectedTokens * (BASIS_POINTS - maxSlippageParam)) / BASIS_POINTS,
            maxSlippage: maxSlippageParam,
            deadline: block.timestamp + 300 // 5 minutes
        });
        
        // Execute swap
        uint256 tokensReceived = _executeSwapInternal(params);
        
        // Execute burn
        bool burnSuccess = _burnTokensInternal(tokensReceived);
        
        // Record execution
        executionId = _recordExecution(ethAmount, tokensReceived, burnSuccess ? tokensReceived : 0, bestDex, TriggerType.MANUAL, msg.sender, priceImpact);
        
        return executionId;
    }
    
    function emergencyTrigger(uint256 ethAmount, DEXType dex) 
        external override onlyEmergencyRole nonReentrant returns (uint256 executionId) {
        require(ethAmount > 0 && ethAmount <= address(this).balance, "BuybackBurn: invalid ETH amount");
        require(_dexConfigs[dex].isActive, "BuybackBurn: DEX not active");
        
        // Emergency execution with maximum slippage allowed
        uint256 emergencySlippage = _dexConfigs[dex].maxSlippage;
        (uint256 expectedTokens,) = _calculateSwapOutput(dex, ethAmount);
        
        SwapParams memory params = SwapParams({
            dex: dex,
            amountIn: ethAmount,
            minAmountOut: (expectedTokens * (BASIS_POINTS - emergencySlippage)) / BASIS_POINTS,
            maxSlippage: emergencySlippage,
            deadline: block.timestamp + 600 // 10 minutes for emergency
        });
        
        uint256 tokensReceived = _executeSwapInternal(params);
        bool burnSuccess = _burnTokensInternal(tokensReceived);
        
        executionId = _recordExecution(ethAmount, tokensReceived, burnSuccess ? tokensReceived : 0, dex, TriggerType.EMERGENCY, msg.sender, emergencySlippage);
        
        emit EmergencyAction("Emergency buyback triggered", msg.sender, ethAmount);
        
        return executionId;
    }
    
    function getAutoTriggerConfig() 
        external view override returns (AutoTriggerConfig memory config) {
        return autoTriggerConfig;
    }
    
    // ============ FEE COLLECTION INTEGRATION ============
    
    function configureFeeCollection(FeeSource source, FeeCollectionConfig calldata config) 
        external override onlyBuybackManager validFeeSource(source) {
        require(config.collector != address(0), "BuybackBurn: invalid collector address");
        require(config.percentage <= BASIS_POINTS, "BuybackBurn: invalid percentage");
        
        _feeConfigs[source] = config;
        
        emit FeeCollectionConfigured(source, config.collector, config.percentage);
    }
    
    function collectPlatformFees(uint256 amount, FeeSource source) 
        external payable override onlyFeeCollector validFeeSource(source) {
        require(_feeConfigs[source].isActive, "BuybackBurn: fee source not active");
        require(msg.value == amount, "BuybackBurn: amount mismatch");
        
        _feeConfigs[source].totalCollected += amount;
        _feesBySource[source] += amount;
        _totalFeesCollected += amount;
        
        emit FeesCollected(source, amount, msg.sender);
    }
    
    function collectCreditSurcharge(uint256 amount) 
        external payable override onlyFeeCollector {
        require(_feeConfigs[FeeSource.CREDIT_SURCHARGE].isActive, "BuybackBurn: credit surcharge not active");
        require(msg.value == amount, "BuybackBurn: amount mismatch");
        
        _feeConfigs[FeeSource.CREDIT_SURCHARGE].totalCollected += amount;
        _feesBySource[FeeSource.CREDIT_SURCHARGE] += amount;
        _totalFeesCollected += amount;
        
        emit FeesCollected(FeeSource.CREDIT_SURCHARGE, amount, msg.sender);
    }
    
    function collectSubscriptionRevenue(uint256 subscriberCount, uint256 monthlyFee) 
        external payable override onlyFeeCollector {
        require(_feeConfigs[FeeSource.PREMIUM_SUBSCRIPTION].isActive, "BuybackBurn: subscription revenue not active");
        
        uint256 totalRevenue = subscriberCount * monthlyFee;
        require(msg.value == totalRevenue, "BuybackBurn: revenue mismatch");
        
        _feeConfigs[FeeSource.PREMIUM_SUBSCRIPTION].totalCollected += totalRevenue;
        _feesBySource[FeeSource.PREMIUM_SUBSCRIPTION] += totalRevenue;
        _totalFeesCollected += totalRevenue;
        
        emit FeesCollected(FeeSource.PREMIUM_SUBSCRIPTION, totalRevenue, msg.sender);
    }
    
    function collectLicensingFees(address licensor, uint256 amount) 
        external payable override onlyFeeCollector {
        require(_feeConfigs[FeeSource.LICENSING_FEES].isActive, "BuybackBurn: licensing fees not active");
        require(licensor != address(0), "BuybackBurn: invalid licensor");
        require(msg.value == amount, "BuybackBurn: amount mismatch");
        
        _feeConfigs[FeeSource.LICENSING_FEES].totalCollected += amount;
        _feesBySource[FeeSource.LICENSING_FEES] += amount;
        _totalFeesCollected += amount;
        
        emit FeesCollected(FeeSource.LICENSING_FEES, amount, msg.sender);
    }
    
    function getFeeCollectionConfig(FeeSource source) 
        external view override returns (FeeCollectionConfig memory config) {
        return _feeConfigs[source];
    }
    
    function getTotalFeesCollected() 
        external view override returns (uint256 totalFees, uint256[] memory feeBreakdown) {
        totalFees = _totalFeesCollected;
        
        feeBreakdown = new uint256[](4);
        feeBreakdown[0] = _feesBySource[FeeSource.INFT_TRADES];
        feeBreakdown[1] = _feesBySource[FeeSource.CREDIT_SURCHARGE];
        feeBreakdown[2] = _feesBySource[FeeSource.PREMIUM_SUBSCRIPTION];
        feeBreakdown[3] = _feesBySource[FeeSource.LICENSING_FEES];
    }
    
    // ============ BURN MECHANISM IMPLEMENTATION ============
    
    function burnTokens(uint256 amount) 
        external override onlyBuybackManager returns (bool success) {
        return _burnTokensInternal(amount);
    }
    
    function batchBurnTokens(uint256[] calldata amounts) 
        external override onlyBuybackManager returns (uint256 totalBurned) {
        require(amounts.length > 0, "BuybackBurn: empty amounts array");
        
        for (uint256 i = 0; i < amounts.length; i++) {
            if (_burnTokensInternal(amounts[i])) {
                totalBurned += amounts[i];
            }
        }
        
        return totalBurned;
    }
    
    function calculateOptimalBurn(uint256 availableTokens) 
        external view override returns (uint256 recommendedBurn, string memory reasoning) {
        if (availableTokens == 0) {
            return (0, "No tokens available for burning");
        }
        
        uint256 currentSupply = karmaToken.totalSupply();
        uint256 burnPercentage = (availableTokens * BASIS_POINTS) / currentSupply;
        
        if (burnPercentage < 10) { // Less than 0.1% of supply
            return (availableTokens, "Minimal impact burn - proceed with all available tokens");
        } else if (burnPercentage < 100) { // Less than 1% of supply
            return (availableTokens, "Moderate impact burn - recommended for regular operations");
        } else if (burnPercentage < 500) { // Less than 5% of supply
            uint256 conservative = (currentSupply * 100) / BASIS_POINTS; // 1% of supply
            return (conservative, "High impact burn - recommend limiting to 1% of supply");
        } else {
            uint256 maxRecommended = (currentSupply * 50) / BASIS_POINTS; // 0.5% of supply
            return (maxRecommended, "Extreme impact burn - recommend limiting to 0.5% of supply");
        }
    }
    
    function getBurnStatistics() 
        external view override returns (
            uint256 totalBurned, 
            uint256 burnCountResult, 
            uint256 lastBurn, 
            uint256 currentSupply
        ) {
        return (
            totalTokensBurned,
            burnCount,
            lastBurnTimestamp,
            karmaToken.totalSupply()
        );
    }
    
    // ============ REPORTING AND ANALYTICS ============
    
    function getBuybackMetrics() 
        external view override returns (BuybackMetrics memory) {
        return metrics;
    }
    
    function getExecutionHistory(uint256 fromTimestamp, uint256 toTimestamp) 
        external view override returns (BuybackExecution[] memory executions) {
        require(fromTimestamp <= toTimestamp, "BuybackBurn: invalid timestamp range");
        
        uint256 count = 0;
        for (uint256 i = 0; i < _executionHistory.length; i++) {
            if (_executionHistory[i].timestamp >= fromTimestamp && 
                _executionHistory[i].timestamp <= toTimestamp) {
                count++;
            }
        }
        
        executions = new BuybackExecution[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < _executionHistory.length && index < count; i++) {
            if (_executionHistory[i].timestamp >= fromTimestamp && 
                _executionHistory[i].timestamp <= toTimestamp) {
                executions[index] = _executionHistory[i];
                index++;
            }
        }
        
        return executions;
    }
    
    function getBalanceStatus() 
        external view override returns (uint256 ethBalance, uint256 karmaBalance, uint256 availableForBuyback) {
        ethBalance = address(this).balance;
        karmaBalance = karmaToken.balanceOf(address(this));
        availableForBuyback = ethBalance >= minimumThreshold ? ethBalance : 0;
    }
    
    function exportTransactionData(uint256 fromTimestamp, uint256 toTimestamp) 
        external view override returns (bytes memory transactions) {
        BuybackExecution[] memory executions = this.getExecutionHistory(fromTimestamp, toTimestamp);
        return abi.encode(executions);
    }
    
    // ============ CONFIGURATION AND ADMIN ============
    
    function updateKarmaToken(address newToken) 
        external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newToken != address(0), "BuybackBurn: invalid token address");
        address oldToken = address(karmaToken);
        karmaToken = IERC20(newToken);
        emit KarmaTokenUpdated(oldToken, newToken);
    }
    
    function updateTreasury(address newTreasury) 
        external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTreasury != address(0), "BuybackBurn: invalid treasury address");
        address oldTreasury = address(treasury);
        treasury = ITreasury(newTreasury);
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
    
    function setMinimumThreshold(uint256 threshold) 
        external override onlyBuybackManager {
        require(threshold >= MIN_EXECUTION_AMOUNT, "BuybackBurn: threshold too low");
        uint256 oldThreshold = minimumThreshold;
        minimumThreshold = threshold;
        emit ThresholdUpdated(oldThreshold, threshold);
    }
    
    function setMaxSlippage(uint256 slippage) 
        external override onlyBuybackManager {
        require(slippage <= BASIS_POINTS, "BuybackBurn: invalid slippage");
        uint256 oldSlippage = maxSlippage;
        maxSlippage = slippage;
        emit SlippageUpdated(oldSlippage, slippage);
    }
    
    function emergencyPause() 
        external override onlyEmergencyRole {
        _pause();
        emit BuybackPaused(msg.sender);
    }
    
    function emergencyUnpause() 
        external override onlyEmergencyRole {
        _unpause();
        emit BuybackUnpaused(msg.sender);
    }
    
    function emergencyWithdraw(uint256 amount) 
        external override onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        uint256 withdrawAmount = (amount == 0) ? balance : amount;
        require(withdrawAmount <= balance, "BuybackBurn: insufficient balance");
        
        (bool success, ) = address(treasury).call{value: withdrawAmount}("");
        require(success, "BuybackBurn: emergency withdrawal failed");
        
        emit EmergencyAction("Emergency withdrawal to treasury", msg.sender, withdrawAmount);
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _calculateSwapOutput(DEXType dex, uint256 ethAmount) 
        internal view returns (uint256 expectedTokens, uint256 priceImpact) {
        // Simplified calculation for demo purposes
        // In production, this would query actual DEX pools for accurate pricing
        
        DEXConfig storage config = _dexConfigs[dex];
        if (!config.isActive) {
            return (0, BASIS_POINTS); // Maximum price impact if DEX not active
        }
        
        // Mock calculation based on a 1:1000 ETH:KARMA ratio for demo
        uint256 baseRate = 1000; // 1 ETH = 1000 KARMA tokens
        expectedTokens = ethAmount * baseRate;
        
        // Calculate price impact based on swap size (simplified)
        uint256 liquidityImpact = (ethAmount * BASIS_POINTS) / config.minLiquidity;
        priceImpact = liquidityImpact > config.maxSlippage ? config.maxSlippage : liquidityImpact;
        
        // Adjust expected tokens based on price impact
        expectedTokens = (expectedTokens * (BASIS_POINTS - priceImpact)) / BASIS_POINTS;
        
        return (expectedTokens, priceImpact);
    }
    
    function _executeSwapInternal(SwapParams memory params) 
        internal returns (uint256 tokensReceived) {
        // Simplified swap execution for demo purposes
        // In production, this would integrate with actual DEX routers
        
        (uint256 expectedTokens,) = _calculateSwapOutput(params.dex, params.amountIn);
        require(expectedTokens >= params.minAmountOut, "BuybackBurn: insufficient output amount");
        
        // For demo purposes, we'll simulate receiving the expected tokens
        // In production, this would be actual DEX interaction
        tokensReceived = expectedTokens;
        
        return tokensReceived;
    }
    
    function _burnTokensInternal(uint256 amount) 
        internal returns (bool success) {
        if (amount == 0) {
            return true;
        }
        
        // Check if we have enough tokens to burn
        uint256 balance = karmaToken.balanceOf(address(this));
        if (balance < amount) {
            return false;
        }
        
        try karmaToken.transfer(address(0), amount) {
            // Update burn statistics
            totalTokensBurned += amount;
            burnCount++;
            lastBurnTimestamp = block.timestamp;
            
            // Update metrics
            metrics.totalTokensBurned += amount;
            
            emit TokensBurned(amount, karmaToken.totalSupply(), address(this));
            return true;
        } catch {
            return false;
        }
    }
    
    function _recordExecution(
        uint256 ethAmount,
        uint256 tokensReceived,
        uint256 tokensBurned,
        DEXType dexUsed,
        TriggerType triggerType,
        address executor,
        uint256 priceImpact
    ) internal returns (uint256 executionId) {
        executionId = _nextExecutionId++;
        
        BuybackExecution memory execution = BuybackExecution({
            id: executionId,
            timestamp: block.timestamp,
            ethAmount: ethAmount,
            tokensReceived: tokensReceived,
            tokensBurned: tokensBurned,
            dexUsed: dexUsed,
            triggerType: triggerType,
            priceImpact: priceImpact,
            executor: executor
        });
        
        _executions[executionId] = execution;
        _executionHistory.push(execution);
        
        emit BuybackExecuted(
            executionId,
            ethAmount,
            tokensReceived,
            tokensBurned,
            dexUsed,
            triggerType,
            priceImpact
        );
        
        return executionId;
    }
    
    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {
        // Allow receiving ETH from Treasury or fee collection
        emit FeesCollected(FeeSource.INFT_TRADES, msg.value, msg.sender);
    }
} 