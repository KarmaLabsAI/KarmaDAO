// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../interfaces/IPlatformFeeRouter.sol";
import "../../../interfaces/IBuybackBurnManager.sol";
import "../../../interfaces/IRevenueStreamIntegrator.sol";

/**
 * @title PlatformFeeRouter
 * @dev Implementation of Platform Fee Collection and Routing
 * Stage 8.2 - Fee Collection and Routing Implementation
 */
contract PlatformFeeRouter is IPlatformFeeRouter, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ CONSTANTS ============
    
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant TIER_UPGRADE_THRESHOLD_BASIC = 1000 * 1e6; // $1000 USD
    uint256 public constant TIER_UPGRADE_THRESHOLD_PREMIUM = 5000 * 1e6; // $5000 USD
    uint256 public constant TIER_UPGRADE_THRESHOLD_VIP = 10000 * 1e6; // $10000 USD
    uint256 public constant TIER_UPGRADE_THRESHOLD_WHALE = 50000 * 1e6; // $50000 USD
    
    uint256 public constant KARMA_HOLDINGS_BASIC = 10000 * 1e18; // 10K KARMA
    uint256 public constant KARMA_HOLDINGS_PREMIUM = 50000 * 1e18; // 50K KARMA
    uint256 public constant KARMA_HOLDINGS_VIP = 100000 * 1e18; // 100K KARMA
    uint256 public constant KARMA_HOLDINGS_WHALE = 500000 * 1e18; // 500K KARMA
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    IERC20 public karmaToken;
    IBuybackBurnManager public buybackBurnContract;
    IRevenueStreamIntegrator public revenueStreamIntegrator;
    
    // Platform registration
    mapping(PlatformType => address) public registeredPlatforms;
    mapping(address => bool) public authorizedPlatforms;
    
    // Fee configurations
    mapping(PlatformType => mapping(FeeType => FeeConfig)) public feeConfigs;
    
    // User fee profiles and tiers
    mapping(address => UserFeeProfile) public userFeeProfiles;
    mapping(UserTier => uint256) public tierDiscounts; // Discount percentages
    
    // Fee collection tracking
    mapping(bytes32 => FeeCollectionData) private _feeCollections;
    mapping(address => bytes32[]) public feeCollectionsByUser;
    mapping(PlatformType => bytes32[]) public feeCollectionsByPlatform;
    bytes32[] public pendingRouting;
    
    // Optimization metrics
    OptimizationMetrics public optimizationMetrics;
    uint256 public lastOptimizationTimestamp;
    
    // Statistics tracking
    mapping(PlatformType => uint256) public platformTotalCollected;
    mapping(PlatformType => uint256) public platformTotalRouted;
    mapping(FeeType => uint256) public feeTypeTotals;
    mapping(address => uint256) public userTotalFees;
    
    // Counter for unique collection IDs
    uint256 private _collectionCounter;
    
    // ============ EVENTS ============
    
    event PlatformRegistered(PlatformType indexed platform, address indexed platformAddress);
    event ContractIntegrationUpdated(address indexed buybackBurn, address indexed revenueStream);
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _admin,
        address _karmaToken
    ) {
        require(_admin != address(0), "PlatformFeeRouter: invalid admin address");
        require(_karmaToken != address(0), "PlatformFeeRouter: invalid karma token address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
        _grantRole(PLATFORM_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        karmaToken = IERC20(_karmaToken);
        
        _initializeFeeConfigurations();
        _initializeTierDiscounts();
    }
    
    // ============ INITIALIZATION ============
    
    function _initializeFeeConfigurations() internal {
        // SillyPort platform fees
        feeConfigs[PlatformType.SILLY_PORT][FeeType.TRANSACTION] = FeeConfig({
            basePercentage: 250, // 2.5%
            minimumFee: 1e15, // 0.001 ETH
            maximumFee: 1e18, // 1 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        feeConfigs[PlatformType.SILLY_PORT][FeeType.SUBSCRIPTION] = FeeConfig({
            basePercentage: 500, // 5%
            minimumFee: 5e15, // 0.005 ETH
            maximumFee: 5e17, // 0.5 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        feeConfigs[PlatformType.SILLY_PORT][FeeType.PREMIUM_FEATURE] = FeeConfig({
            basePercentage: 300, // 3%
            minimumFee: 2e15, // 0.002 ETH
            maximumFee: 2e17, // 0.2 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        // SillyHotel platform fees
        feeConfigs[PlatformType.SILLY_HOTEL][FeeType.TRANSACTION] = FeeConfig({
            basePercentage: 250, // 2.5%
            minimumFee: 1e15, // 0.001 ETH
            maximumFee: 1e18, // 1 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        feeConfigs[PlatformType.SILLY_HOTEL][FeeType.MARKETPLACE] = FeeConfig({
            basePercentage: 200, // 2%
            minimumFee: 5e14, // 0.0005 ETH
            maximumFee: 5e17, // 0.5 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        // KarmaLabs Assets platform fees
        feeConfigs[PlatformType.KARMA_LABS_ASSETS][FeeType.MARKETPLACE] = FeeConfig({
            basePercentage: 250, // 2.5%
            minimumFee: 1e15, // 0.001 ETH
            maximumFee: 1e18, // 1 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
        
        feeConfigs[PlatformType.KARMA_LABS_ASSETS][FeeType.ROYALTY] = FeeConfig({
            basePercentage: 100, // 1%
            minimumFee: 5e14, // 0.0005 ETH
            maximumFee: 1e17, // 0.1 ETH
            isActive: true,
            lastUpdated: block.timestamp
        });
    }
    
    function _initializeTierDiscounts() internal {
        tierDiscounts[UserTier.BASIC] = 0; // No discount
        tierDiscounts[UserTier.PREMIUM] = 500; // 5% discount
        tierDiscounts[UserTier.VIP] = 1000; // 10% discount
        tierDiscounts[UserTier.WHALE] = 1500; // 15% discount
    }
    
    // ============ FEE COLLECTION FUNCTIONS ============
    
    function collectFee(
        PlatformType platform,
        FeeType feeType,
        uint256 baseAmount,
        address payer
    ) external payable override nonReentrant whenNotPaused returns (bytes32 collectionId, uint256 actualFee) {
        require(authorizedPlatforms[msg.sender] || hasRole(PLATFORM_MANAGER_ROLE, msg.sender), "PlatformFeeRouter: unauthorized platform");
        require(baseAmount > 0, "PlatformFeeRouter: invalid base amount");
        require(payer != address(0), "PlatformFeeRouter: invalid payer address");
        
        FeeConfig storage config = feeConfigs[platform][feeType];
        require(config.isActive, "PlatformFeeRouter: fee type not active");
        
        // Calculate optimal fee with user discounts
        (uint256 optimalFee, uint256 discountPercentage) = calculateOptimalFee(platform, feeType, baseAmount, payer);
        require(msg.value >= optimalFee, "PlatformFeeRouter: insufficient fee payment");
        
        actualFee = optimalFee;
        
        // Generate collection ID
        _collectionCounter++;
        collectionId = keccak256(abi.encodePacked("FEE_COLLECTION", _collectionCounter, platform, feeType, payer, block.timestamp));
        
        // Create fee collection record
        _feeCollections[collectionId] = FeeCollectionData({
            collectionId: collectionId,
            platform: platform,
            feeType: feeType,
            payer: payer,
            amount: baseAmount,
            actualFee: actualFee,
            discountApplied: discountPercentage,
            timestamp: block.timestamp,
            isRouted: false
        });
        
        // Update tracking arrays
        feeCollectionsByUser[payer].push(collectionId);
        feeCollectionsByPlatform[platform].push(collectionId);
        pendingRouting.push(collectionId);
        
        // Update user fee profile
        UserFeeProfile storage profile = userFeeProfiles[payer];
        profile.totalSpent += actualFee;
        profile.lastActivity = block.timestamp;
        
        // Check for tier upgrade
        _checkAndUpdateUserTier(payer);
        
        // Update statistics
        platformTotalCollected[platform] += actualFee;
        feeTypeTotals[feeType] += actualFee;
        userTotalFees[payer] += actualFee;
        
        // Update optimization metrics
        optimizationMetrics.totalCollected += actualFee;
        optimizationMetrics.discountsApplied += (baseAmount * config.basePercentage / 10000) - actualFee;
        
        emit FeeCollected(collectionId, platform, feeType, payer, baseAmount, actualFee);
        
        return (collectionId, actualFee);
    }
    
    function routeFees(bytes32[] calldata collectionIds) external override onlyRole(FEE_MANAGER_ROLE) returns (uint256 totalRouted) {
        require(collectionIds.length > 0, "PlatformFeeRouter: empty collection IDs");
        
        totalRouted = 0;
        
        for (uint256 i = 0; i < collectionIds.length; i++) {
            bytes32 collectionId = collectionIds[i];
            require(_feeCollections[collectionId].collectionId == collectionId, "PlatformFeeRouter: invalid collection ID");
            require(!_feeCollections[collectionId].isRouted, "PlatformFeeRouter: already routed");
            
            FeeCollectionData storage collection = _feeCollections[collectionId];
            uint256 feeAmount = collection.actualFee;
            
            // Route fees based on platform integration
            address routingDestination = _determineRoutingDestination(collection.platform, collection.feeType);
            
            if (routingDestination != address(0) && feeAmount > 0) {
                // Route to specific integration contract
                if (routingDestination == address(buybackBurnContract)) {
                    // Route to buyback-burn system
                    (bool success, ) = routingDestination.call{value: feeAmount}("");
                    require(success, "PlatformFeeRouter: buyback routing failed");
                } else if (routingDestination == address(revenueStreamIntegrator)) {
                    // Route to revenue stream integrator
                    (bool success, ) = routingDestination.call{value: feeAmount}("");
                    require(success, "PlatformFeeRouter: revenue stream routing failed");
                }
                
                collection.isRouted = true;
                totalRouted += feeAmount;
                
                // Update metrics
                platformTotalRouted[collection.platform] += feeAmount;
                optimizationMetrics.totalRouted += feeAmount;
                
                emit FeeRouted(collectionId, routingDestination, feeAmount);
            }
        }
        
        return totalRouted;
    }
    
    function calculateOptimalFee(
        PlatformType platform,
        FeeType feeType,
        uint256 baseAmount,
        address user
    ) public view override returns (uint256 optimalFee, uint256 discountPercentage) {
        FeeConfig storage config = feeConfigs[platform][feeType];
        require(config.isActive, "PlatformFeeRouter: fee type not active");
        
        // Calculate base fee
        uint256 baseFee = (baseAmount * config.basePercentage) / 10000;
        
        // Apply min/max limits
        if (baseFee < config.minimumFee) {
            baseFee = config.minimumFee;
        } else if (baseFee > config.maximumFee) {
            baseFee = config.maximumFee;
        }
        
        // Apply user tier discounts
        UserFeeProfile memory profile = userFeeProfiles[user];
        discountPercentage = tierDiscounts[profile.tier];
        
        // Apply additional discounts for KARMA holdings
        uint256 karmaHoldings = karmaToken.balanceOf(user);
        
        if (karmaHoldings >= KARMA_HOLDINGS_WHALE) {
            discountPercentage += 500; // Additional 5% for whale holdings
        } else if (karmaHoldings >= KARMA_HOLDINGS_VIP) {
            discountPercentage += 300; // Additional 3% for VIP holdings
        } else if (karmaHoldings >= KARMA_HOLDINGS_PREMIUM) {
            discountPercentage += 200; // Additional 2% for premium holdings
        } else if (karmaHoldings >= KARMA_HOLDINGS_BASIC) {
            discountPercentage += 100; // Additional 1% for basic holdings
        }
        
        // Premium subscriber discount
        if (profile.isPremiumSubscriber) {
            discountPercentage += 200; // Additional 2% for premium subscribers
        }
        
        // Cap total discount at 30%
        if (discountPercentage > 3000) {
            discountPercentage = 3000;
        }
        
        // Calculate optimal fee with discounts
        uint256 discountAmount = (baseFee * discountPercentage) / 10000;
        optimalFee = baseFee - discountAmount;
        
        // Ensure minimum fee is still met
        if (optimalFee < config.minimumFee) {
            optimalFee = config.minimumFee;
        }
        
        return (optimalFee, discountPercentage);
    }
    
    function _determineRoutingDestination(PlatformType platform, FeeType feeType) internal view returns (address) {
        // Route marketplace and transaction fees to buyback-burn
        if (feeType == FeeType.MARKETPLACE || feeType == FeeType.TRANSACTION) {
            return address(buybackBurnContract);
        }
        
        // Route subscription and premium feature fees to revenue stream
        if (feeType == FeeType.SUBSCRIPTION || feeType == FeeType.PREMIUM_FEATURE) {
            return address(revenueStreamIntegrator);
        }
        
        // Route royalty fees to revenue stream
        if (feeType == FeeType.ROYALTY) {
            return address(revenueStreamIntegrator);
        }
        
        // Default to buyback-burn
        return address(buybackBurnContract);
    }
    
    // ============ USER TIER MANAGEMENT ============
    
    function updateUserTier(address user) external override returns (UserTier newTier) {
        return _checkAndUpdateUserTier(user);
    }
    
    function _checkAndUpdateUserTier(address user) internal returns (UserTier newTier) {
        UserFeeProfile storage profile = userFeeProfiles[user];
        UserTier currentTier = profile.tier;
        
        // Update KARMA holdings
        profile.karmaHoldings = karmaToken.balanceOf(user);
        
        // Determine new tier based on total spent and KARMA holdings
        if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_WHALE || profile.karmaHoldings >= KARMA_HOLDINGS_WHALE) {
            newTier = UserTier.WHALE;
        } else if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_VIP || profile.karmaHoldings >= KARMA_HOLDINGS_VIP) {
            newTier = UserTier.VIP;
        } else if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_PREMIUM || profile.karmaHoldings >= KARMA_HOLDINGS_PREMIUM) {
            newTier = UserTier.PREMIUM;
        } else if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_BASIC || profile.karmaHoldings >= KARMA_HOLDINGS_BASIC) {
            newTier = UserTier.PREMIUM;
        } else {
            newTier = UserTier.BASIC;
        }
        
        // Update tier if changed
        if (newTier != currentTier) {
            profile.tier = newTier;
            profile.discountPercentage = tierDiscounts[newTier];
            
            emit UserTierUpdated(user, currentTier, newTier);
        }
        
        return newTier;
    }
    
    function getUserFeeProfile(address user) external view override returns (UserFeeProfile memory profile) {
        return userFeeProfiles[user];
    }
    
    function checkTierUpgrade(address user) external view override returns (bool qualifiesForUpgrade, UserTier suggestedTier) {
        UserFeeProfile storage profile = userFeeProfiles[user];
        uint256 karmaHoldings = karmaToken.balanceOf(user);
        
        UserTier currentTier = profile.tier;
        UserTier potentialTier = currentTier;
        
        // Check upgrade eligibility
        if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_WHALE || karmaHoldings >= KARMA_HOLDINGS_WHALE) {
            potentialTier = UserTier.WHALE;
        } else if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_VIP || karmaHoldings >= KARMA_HOLDINGS_VIP) {
            potentialTier = UserTier.VIP;
        } else if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_PREMIUM || karmaHoldings >= KARMA_HOLDINGS_PREMIUM) {
            potentialTier = UserTier.PREMIUM;
        } else if (profile.totalSpent >= TIER_UPGRADE_THRESHOLD_BASIC || karmaHoldings >= KARMA_HOLDINGS_BASIC) {
            potentialTier = UserTier.PREMIUM;
        }
        
        qualifiesForUpgrade = potentialTier > currentTier;
        suggestedTier = qualifiesForUpgrade ? potentialTier : currentTier;
        
        return (qualifiesForUpgrade, suggestedTier);
    }
    
    // ============ FEE CONFIGURATION ============
    
    function configureFee(PlatformType platform, FeeType feeType, FeeConfig calldata config) external override onlyRole(FEE_MANAGER_ROLE) {
        require(config.basePercentage <= 2000, "PlatformFeeRouter: fee percentage too high"); // Max 20%
        require(config.minimumFee > 0, "PlatformFeeRouter: invalid minimum fee");
        require(config.maximumFee >= config.minimumFee, "PlatformFeeRouter: invalid maximum fee");
        
        feeConfigs[platform][feeType] = FeeConfig({
            basePercentage: config.basePercentage,
            minimumFee: config.minimumFee,
            maximumFee: config.maximumFee,
            isActive: config.isActive,
            lastUpdated: block.timestamp
        });
        
        emit FeeConfigUpdated(platform, feeType, config);
    }
    
    function getFeeConfig(PlatformType platform, FeeType feeType) external view override returns (FeeConfig memory config) {
        return feeConfigs[platform][feeType];
    }
    
    function bulkConfigureFees(
        PlatformType[] calldata platforms,
        FeeType[] calldata feeTypes,
        FeeConfig[] calldata configs
    ) external override onlyRole(FEE_MANAGER_ROLE) {
        require(platforms.length == feeTypes.length && feeTypes.length == configs.length, "PlatformFeeRouter: array length mismatch");
        
        for (uint256 i = 0; i < platforms.length; i++) {
            feeConfigs[platforms[i]][feeTypes[i]] = FeeConfig({
                basePercentage: configs[i].basePercentage,
                minimumFee: configs[i].minimumFee,
                maximumFee: configs[i].maximumFee,
                isActive: configs[i].isActive,
                lastUpdated: block.timestamp
            });
            
            emit FeeConfigUpdated(platforms[i], feeTypes[i], configs[i]);
        }
    }
    
    // ============ FEE OPTIMIZATION ============
    
    function executeOptimization() external override onlyRole(FEE_MANAGER_ROLE) returns (uint256 optimizedAmount, uint256 gasUsed) {
        uint256 gasBefore = gasleft();
        
        // Simple optimization: route all pending fees
        optimizedAmount = 0;
        uint256 routedCount = 0;
        
        for (uint256 i = 0; i < pendingRouting.length && routedCount < 50; i++) { // Limit to 50 per batch
            bytes32 collectionId = pendingRouting[i];
            if (!_feeCollections[collectionId].isRouted) {
                bytes32[] memory singleCollection = new bytes32[](1);
                singleCollection[0] = collectionId;
                optimizedAmount += this.routeFees(singleCollection);
                routedCount++;
            }
        }
        
        // Update optimization metrics
        optimizationMetrics.gasOptimization += gasBefore - gasleft();
        optimizationMetrics.lastOptimization = block.timestamp;
        lastOptimizationTimestamp = block.timestamp;
        
        gasUsed = gasBefore - gasleft();
        
        emit OptimizationExecuted(optimizedAmount, gasUsed);
        
        return (optimizedAmount, gasUsed);
    }
    
    function getOptimizationMetrics() external view override returns (OptimizationMetrics memory metrics) {
        return optimizationMetrics;
    }
    
    function predictOptimalFee(
        PlatformType platform,
        FeeType feeType,
        uint256 baseAmount,
        address user,
        uint256 futureTimestamp
    ) external view override returns (uint256 predictedFee) {
        // Simplified prediction - in production would use historical data and trends
        (uint256 currentOptimalFee, ) = calculateOptimalFee(platform, feeType, baseAmount, user);
        
        // Apply basic time-based prediction (e.g., slightly lower fees during off-peak times)
        uint256 timeOfDay = (futureTimestamp % 86400) / 3600; // Hour of day
        
        if (timeOfDay >= 2 && timeOfDay <= 6) {
            // Off-peak hours - slight discount
            predictedFee = currentOptimalFee * 95 / 100;
        } else {
            predictedFee = currentOptimalFee;
        }
        
        return predictedFee;
    }
    
    // ============ ANALYTICS AND REPORTING ============
    
    function getFeeStats(PlatformType platform) external view override returns (
        uint256 totalCollected,
        uint256 totalRouted,
        uint256 averageFee,
        uint256 uniqueUsers
    ) {
        totalCollected = platformTotalCollected[platform];
        totalRouted = platformTotalRouted[platform];
        
        bytes32[] memory collections = feeCollectionsByPlatform[platform];
        if (collections.length > 0) {
            averageFee = totalCollected / collections.length;
        }
        
        // Count unique users (simplified)
        uniqueUsers = collections.length; // Simplified - would need proper tracking
        
        return (totalCollected, totalRouted, averageFee, uniqueUsers);
    }
    
    function getUserFeeHistory(address user, uint256 limit) external view override returns (FeeCollectionData[] memory collections) {
        bytes32[] memory userCollections = feeCollectionsByUser[user];
        uint256 returnCount = limit > 0 && limit < userCollections.length ? limit : userCollections.length;
        
        collections = new FeeCollectionData[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            collections[i] = _feeCollections[userCollections[userCollections.length - 1 - i]]; // Return latest first
        }
        
        return collections;
    }
    
    function getPlatformFeeBreakdown(PlatformType platform) external view override returns (
        FeeType[] memory feeTypes,
        uint256[] memory amounts,
        uint256[] memory percentages
    ) {
        // Simplified implementation - return basic breakdown
        feeTypes = new FeeType[](3);
        amounts = new uint256[](3);
        percentages = new uint256[](3);
        
        feeTypes[0] = FeeType.TRANSACTION;
        feeTypes[1] = FeeType.MARKETPLACE;
        feeTypes[2] = FeeType.SUBSCRIPTION;
        
        uint256 totalPlatformRevenue = platformTotalCollected[platform];
        
        if (totalPlatformRevenue > 0) {
            amounts[0] = feeTypeTotals[FeeType.TRANSACTION];
            amounts[1] = feeTypeTotals[FeeType.MARKETPLACE];
            amounts[2] = feeTypeTotals[FeeType.SUBSCRIPTION];
            
            percentages[0] = (amounts[0] * 10000) / totalPlatformRevenue;
            percentages[1] = (amounts[1] * 10000) / totalPlatformRevenue;
            percentages[2] = (amounts[2] * 10000) / totalPlatformRevenue;
        }
        
        return (feeTypes, amounts, percentages);
    }
    
    // ============ INTEGRATION FUNCTIONS ============
    
    function registerPlatform(PlatformType platform, address platformAddress) external override onlyRole(PLATFORM_MANAGER_ROLE) returns (bool success) {
        require(platformAddress != address(0), "PlatformFeeRouter: invalid platform address");
        
        registeredPlatforms[platform] = platformAddress;
        authorizedPlatforms[platformAddress] = true;
        
        emit PlatformRegistered(platform, platformAddress);
        
        return true;
    }
    
    function setBuybackBurnContract(address buybackBurnAddress) external override onlyRole(PLATFORM_MANAGER_ROLE) {
        require(buybackBurnAddress != address(0), "PlatformFeeRouter: invalid buyback burn address");
        
        buybackBurnContract = IBuybackBurnManager(buybackBurnAddress);
        
        emit ContractIntegrationUpdated(buybackBurnAddress, address(revenueStreamIntegrator));
    }
    
    function setRevenueStreamIntegrator(address revenueStreamAddress) external override onlyRole(PLATFORM_MANAGER_ROLE) {
        require(revenueStreamAddress != address(0), "PlatformFeeRouter: invalid revenue stream address");
        
        revenueStreamIntegrator = IRevenueStreamIntegrator(revenueStreamAddress);
        
        emit ContractIntegrationUpdated(address(buybackBurnContract), revenueStreamAddress);
    }
    
    function emergencyWithdraw(uint256 amount) external override onlyRole(EMERGENCY_ROLE) nonReentrant returns (uint256 withdrawnAmount) {
        uint256 balance = address(this).balance;
        withdrawnAmount = (amount == 0 || amount > balance) ? balance : amount;
        
        require(withdrawnAmount > 0, "PlatformFeeRouter: no funds to withdraw");
        
        (bool success, ) = msg.sender.call{value: withdrawnAmount}("");
        require(success, "PlatformFeeRouter: withdrawal failed");
        
        return withdrawnAmount;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    function updateUserPremiumStatus(address user, bool isPremium) external onlyRole(PLATFORM_MANAGER_ROLE) {
        userFeeProfiles[user].isPremiumSubscriber = isPremium;
    }
    
    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {
        // Accept ETH deposits for fee collection
    }
}
