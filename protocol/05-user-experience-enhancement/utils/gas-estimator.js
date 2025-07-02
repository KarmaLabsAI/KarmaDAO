/**
 * @title Gas Estimator Utility
 * @dev Utility functions for gas estimation and optimization in Paymaster operations
 */

const { ethers } = require('ethers');

/**
 * Gas overhead constants for ERC-4337 operations
 */
const GAS_OVERHEADS = {
    BASE_TX: 21000,              // Base transaction cost
    VALIDATION: 50000,           // UserOp validation overhead
    POSTOP: 30000,              // PostOp execution overhead
    PAYMASTER_VALIDATION: 25000,  // Paymaster validation overhead
    ACCOUNT_FACTORY: 100000,     // Account creation overhead
    STORAGE_WRITE: 20000,        // Storage write operation
    STORAGE_READ: 800,           // Storage read operation
    SLOAD: 800,                  // SLOAD opcode
    SSTORE: 20000                // SSTORE opcode
};

/**
 * User tier gas limits and multipliers
 */
const TIER_MULTIPLIERS = {
    STANDARD: 1.0,    // Base tier
    VIP: 2.0,         // 2x gas limits
    STAKER: 1.5,      // 1.5x gas limits
    PREMIUM: 3.0      // 3x gas limits
};

/**
 * Default gas limits per tier (in gas units)
 */
const DEFAULT_GAS_LIMITS = {
    DAILY_BASE: 1000000,     // 1M gas per day for standard users
    MONTHLY_BASE: 25000000,  // 25M gas per month for standard users
    MAX_PER_OP: 500000       // 500K gas per operation
};

/**
 * Gas price optimization constants
 */
const GAS_PRICE_CONFIG = {
    PRIORITY_FEE_MULTIPLIER: 1.1,  // 10% buffer for priority fees
    MAX_FEE_MULTIPLIER: 1.2,       // 20% buffer for max fees
    OPTIMIZATION_THRESHOLD: 0.9,    // Optimize when 90% of target gas price
    MIN_GAS_PRICE: 1e9,            // 1 gwei minimum
    MAX_GAS_PRICE: 100e9           // 100 gwei maximum
};

/**
 * Estimate total gas cost for a UserOperation
 * @param {Object} userOp - UserOperation object
 * @param {Object} options - Estimation options
 * @returns {Object} Gas estimation breakdown
 */
function estimateUserOpGas(userOp, options = {}) {
    const {
        hasAccount = true,
        hasPaymaster = true,
        isComplexOp = false,
        networkMultiplier = 1.0
    } = options;

    let totalGas = 0;
    
    // Base transaction gas
    totalGas += GAS_OVERHEADS.BASE_TX;
    
    // Verification gas (from UserOp)
    totalGas += parseInt(userOp.verificationGasLimit || 100000);
    
    // Call gas (from UserOp)
    totalGas += parseInt(userOp.callGasLimit || 100000);
    
    // Pre-verification gas (from UserOp)
    totalGas += parseInt(userOp.preVerificationGas || 21000);
    
    // Account creation overhead (if new account)
    if (!hasAccount) {
        totalGas += GAS_OVERHEADS.ACCOUNT_FACTORY;
    }
    
    // Paymaster validation overhead
    if (hasPaymaster) {
        totalGas += GAS_OVERHEADS.PAYMASTER_VALIDATION;
        totalGas += GAS_OVERHEADS.POSTOP;
    }
    
    // Complex operation overhead
    if (isComplexOp) {
        totalGas += GAS_OVERHEADS.STORAGE_WRITE * 3; // Multiple storage writes
    }
    
    // Network-specific multiplier
    totalGas = Math.ceil(totalGas * networkMultiplier);
    
    const gasPrice = BigInt(userOp.maxFeePerGas || 20000000000); // 20 gwei default
    const totalCost = BigInt(totalGas) * gasPrice;
    
    return {
        totalGas,
        totalCost: totalCost.toString(),
        breakdown: {
            baseTx: GAS_OVERHEADS.BASE_TX,
            verification: parseInt(userOp.verificationGasLimit || 100000),
            execution: parseInt(userOp.callGasLimit || 100000),
            preVerification: parseInt(userOp.preVerificationGas || 21000),
            paymaster: hasPaymaster ? GAS_OVERHEADS.PAYMASTER_VALIDATION : 0,
            postOp: hasPaymaster ? GAS_OVERHEADS.POSTOP : 0,
            overhead: totalGas - (
                GAS_OVERHEADS.BASE_TX + 
                parseInt(userOp.verificationGasLimit || 100000) + 
                parseInt(userOp.callGasLimit || 100000) + 
                parseInt(userOp.preVerificationGas || 21000)
            )
        },
        gasPrice: gasPrice.toString(),
        formattedCost: ethers.formatEther(totalCost)
    };
}

/**
 * Calculate gas limits for user tier
 * @param {number} tier - User tier (0=STANDARD, 1=VIP, 2=STAKER, 3=PREMIUM)
 * @returns {Object} Gas limits for the tier
 */
function calculateTierGasLimits(tier) {
    const tierNames = ['STANDARD', 'VIP', 'STAKER', 'PREMIUM'];
    const tierName = tierNames[tier] || 'STANDARD';
    const multiplier = TIER_MULTIPLIERS[tierName];
    
    return {
        tier,
        tierName,
        multiplier,
        dailyLimit: Math.floor(DEFAULT_GAS_LIMITS.DAILY_BASE * multiplier),
        monthlyLimit: Math.floor(DEFAULT_GAS_LIMITS.MONTHLY_BASE * multiplier),
        maxPerOperation: Math.floor(DEFAULT_GAS_LIMITS.MAX_PER_OP * multiplier)
    };
}

/**
 * Check if gas usage is within limits
 * @param {Object} userGasUsage - Current user gas usage
 * @param {number} requestedGas - Gas requested for new operation
 * @param {number} tier - User tier
 * @returns {Object} Rate limit check result
 */
function checkRateLimit(userGasUsage, requestedGas, tier) {
    const limits = calculateTierGasLimits(tier);
    const currentTime = Math.floor(Date.now() / 1000);
    
    // Check daily limit
    const dailyResetTime = currentTime - (currentTime % 86400); // Start of current day
    const dailyUsed = userGasUsage.lastDailyReset === dailyResetTime 
        ? userGasUsage.dailyGasUsed 
        : 0;
    
    const newDailyUsage = dailyUsed + requestedGas;
    const dailyWithinLimit = newDailyUsage <= limits.dailyLimit;
    
    // Check monthly limit
    const monthlyResetTime = currentTime - (currentTime % 2592000); // Start of current month (30 days)
    const monthlyUsed = userGasUsage.lastMonthlyReset === monthlyResetTime 
        ? userGasUsage.monthlyGasUsed 
        : 0;
    
    const newMonthlyUsage = monthlyUsed + requestedGas;
    const monthlyWithinLimit = newMonthlyUsage <= limits.monthlyLimit;
    
    // Check per-operation limit
    const perOpWithinLimit = requestedGas <= limits.maxPerOperation;
    
    const withinLimits = dailyWithinLimit && monthlyWithinLimit && perOpWithinLimit;
    
    return {
        withinLimits,
        limits,
        usage: {
            daily: {
                used: newDailyUsage,
                limit: limits.dailyLimit,
                remaining: Math.max(0, limits.dailyLimit - newDailyUsage),
                withinLimit: dailyWithinLimit
            },
            monthly: {
                used: newMonthlyUsage,
                limit: limits.monthlyLimit,
                remaining: Math.max(0, limits.monthlyLimit - newMonthlyUsage),
                withinLimit: monthlyWithinLimit
            },
            perOperation: {
                requested: requestedGas,
                limit: limits.maxPerOperation,
                withinLimit: perOpWithinLimit
            }
        },
        resetTimes: {
            dailyReset: dailyResetTime + 86400,
            monthlyReset: monthlyResetTime + 2592000
        }
    };
}

/**
 * Optimize gas price based on network conditions
 * @param {Object} networkConditions - Current network gas conditions
 * @param {Object} options - Optimization options
 * @returns {Object} Optimized gas price recommendation
 */
function optimizeGasPrice(networkConditions, options = {}) {
    const {
        urgency = 'normal', // 'low', 'normal', 'high'
        maxGasPrice = GAS_PRICE_CONFIG.MAX_GAS_PRICE,
        targetGasPrice = 20000000000 // 20 gwei default
    } = options;
    
    const currentBaseFee = BigInt(networkConditions.baseFeePerGas || 10000000000); // 10 gwei default
    const currentPriorityFee = BigInt(networkConditions.priorityFeePerGas || 2000000000); // 2 gwei default
    
    // Urgency multipliers
    const urgencyMultipliers = {
        'low': 0.8,     // 20% discount for low urgency
        'normal': 1.0,  // Standard pricing
        'high': 1.5     // 50% premium for high urgency
    };
    
    const multiplier = urgencyMultipliers[urgency] || 1.0;
    
    // Calculate optimized fees
    const optimizedPriorityFee = BigInt(Math.floor(
        Number(currentPriorityFee) * multiplier * GAS_PRICE_CONFIG.PRIORITY_FEE_MULTIPLIER
    ));
    
    const optimizedMaxFee = currentBaseFee * 2n + optimizedPriorityFee; // EIP-1559 formula
    
    // Apply caps
    const cappedMaxFee = optimizedMaxFee > BigInt(maxGasPrice) 
        ? BigInt(maxGasPrice) 
        : optimizedMaxFee;
    
    const cappedPriorityFee = optimizedPriorityFee > cappedMaxFee 
        ? cappedMaxFee 
        : optimizedPriorityFee;
    
    // Calculate potential savings
    const standardCost = BigInt(targetGasPrice);
    const optimizedCost = cappedMaxFee;
    const savings = standardCost > optimizedCost 
        ? standardCost - optimizedCost 
        : 0n;
    
    return {
        optimized: {
            maxFeePerGas: cappedMaxFee.toString(),
            maxPriorityFeePerGas: cappedPriorityFee.toString()
        },
        current: {
            baseFeePerGas: currentBaseFee.toString(),
            priorityFeePerGas: currentPriorityFee.toString()
        },
        savings: {
            absolute: savings.toString(),
            percentage: standardCost > 0n 
                ? Math.floor(Number(savings * 10000n / standardCost)) / 100 
                : 0,
            formattedSavings: ethers.formatEther(savings)
        },
        recommendation: urgency,
        multiplier
    };
}

/**
 * Calculate sponsorship cost for a gas amount
 * @param {number} gasUsed - Amount of gas used
 * @param {bigint} gasPrice - Gas price in wei
 * @param {Object} options - Calculation options
 * @returns {Object} Sponsorship cost breakdown
 */
function calculateSponsorshipCost(gasUsed, gasPrice, options = {}) {
    const {
        includeOverhead = true,
        paymasterFeePercent = 0, // Additional fee percentage
        subsidyPercent = 100     // Percentage of cost to sponsor (100% = full sponsorship)
    } = options;
    
    let totalGas = gasUsed;
    
    // Add paymaster overhead if requested
    if (includeOverhead) {
        totalGas += GAS_OVERHEADS.PAYMASTER_VALIDATION + GAS_OVERHEADS.POSTOP;
    }
    
    const baseCost = BigInt(totalGas) * BigInt(gasPrice);
    const paymasterFee = baseCost * BigInt(paymasterFeePercent) / 100n;
    const totalCost = baseCost + paymasterFee;
    const sponsoredAmount = totalCost * BigInt(subsidyPercent) / 100n;
    const userPortion = totalCost - sponsoredAmount;
    
    return {
        gasUsed,
        totalGas,
        gasPrice: gasPrice.toString(),
        costs: {
            base: baseCost.toString(),
            paymasterFee: paymasterFee.toString(),
            total: totalCost.toString(),
            sponsored: sponsoredAmount.toString(),
            userPortion: userPortion.toString()
        },
        formatted: {
            base: ethers.formatEther(baseCost),
            total: ethers.formatEther(totalCost),
            sponsored: ethers.formatEther(sponsoredAmount),
            userPortion: ethers.formatEther(userPortion)
        },
        subsidyPercent,
        paymasterFeePercent
    };
}

/**
 * Detect potential abuse patterns in gas usage
 * @param {Array} recentOperations - Array of recent user operations
 * @param {Object} thresholds - Abuse detection thresholds
 * @returns {Object} Abuse detection result
 */
function detectAbuse(recentOperations, thresholds = {}) {
    const {
        maxOpsPerHour = 50,
        maxGasPerHour = 5000000,
        suspiciousPatternThreshold = 0.9, // 90% similarity threshold
        timeWindowHours = 24
    } = thresholds;
    
    const currentTime = Math.floor(Date.now() / 1000);
    const hourlyWindow = 3600;
    const dailyWindow = timeWindowHours * 3600;
    
    // Filter recent operations
    const recentOps = recentOperations.filter(
        op => currentTime - op.timestamp <= dailyWindow
    );
    
    // Check hourly limits
    const lastHourOps = recentOps.filter(
        op => currentTime - op.timestamp <= hourlyWindow
    );
    
    const hourlyOpCount = lastHourOps.length;
    const hourlyGasUsage = lastHourOps.reduce((sum, op) => sum + op.gasUsed, 0);
    
    // Pattern analysis
    const gasUsagePattern = recentOps.map(op => op.gasUsed);
    const isRepetitivePattern = analyzePatternSimilarity(gasUsagePattern) > suspiciousPatternThreshold;
    
    // Risk scoring
    let riskScore = 0;
    const riskFactors = [];
    
    if (hourlyOpCount > maxOpsPerHour) {
        riskScore += 30;
        riskFactors.push(`High operation frequency: ${hourlyOpCount} ops/hour`);
    }
    
    if (hourlyGasUsage > maxGasPerHour) {
        riskScore += 40;
        riskFactors.push(`High gas usage: ${hourlyGasUsage} gas/hour`);
    }
    
    if (isRepetitivePattern) {
        riskScore += 20;
        riskFactors.push('Repetitive gas usage pattern detected');
    }
    
    const isAbuse = riskScore >= 50; // 50+ risk score indicates potential abuse
    const severity = riskScore >= 80 ? 'high' : riskScore >= 50 ? 'medium' : 'low';
    
    return {
        isAbuse,
        riskScore,
        severity,
        riskFactors,
        metrics: {
            hourlyOps: hourlyOpCount,
            hourlyGasUsage,
            dailyOps: recentOps.length,
            averageGasPerOp: recentOps.length > 0 
                ? Math.floor(recentOps.reduce((sum, op) => sum + op.gasUsed, 0) / recentOps.length)
                : 0
        },
        thresholds: {
            maxOpsPerHour,
            maxGasPerHour,
            suspiciousPatternThreshold
        }
    };
}

/**
 * Analyze similarity in gas usage patterns
 * @param {Array} gasUsageArray - Array of gas usage values
 * @returns {number} Similarity score (0-1)
 */
function analyzePatternSimilarity(gasUsageArray) {
    if (gasUsageArray.length < 3) return 0;
    
    const mean = gasUsageArray.reduce((sum, val) => sum + val, 0) / gasUsageArray.length;
    const variance = gasUsageArray.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / gasUsageArray.length;
    const standardDeviation = Math.sqrt(variance);
    
    // Low standard deviation indicates repetitive pattern
    const coefficientOfVariation = standardDeviation / mean;
    
    // Convert to similarity score (lower variation = higher similarity)
    return Math.max(0, 1 - coefficientOfVariation);
}

/**
 * Calculate funding requirements for paymaster
 * @param {Object} projectedUsage - Projected usage statistics
 * @param {Object} pricing - Gas pricing information
 * @returns {Object} Funding requirement analysis
 */
function calculateFundingRequirements(projectedUsage, pricing) {
    const {
        dailyOperations = 1000,
        averageGasPerOp = 300000,
        growthRateMonthly = 0.2, // 20% monthly growth
        reserveMultiplier = 2.0  // 2x reserve for safety
    } = projectedUsage;
    
    const {
        averageGasPrice = 20000000000, // 20 gwei
        gasPriceVolatility = 0.5 // 50% price volatility buffer
    } = pricing;
    
    // Calculate base requirements
    const dailyGasUsage = dailyOperations * averageGasPerOp;
    const monthlyGasUsage = dailyGasUsage * 30;
    
    // Apply growth projections
    const projectedMonthlyGas = monthlyGasUsage * (1 + growthRateMonthly);
    
    // Calculate costs with volatility buffer
    const baseCostPerMonth = BigInt(Math.floor(projectedMonthlyGas)) * BigInt(averageGasPrice);
    const volatilityBuffer = baseCostPerMonth * BigInt(Math.floor(gasPriceVolatility * 100)) / 100n;
    const totalMonthlyRequirement = baseCostPerMonth + volatilityBuffer;
    
    // Apply reserve multiplier
    const recommendedBalance = BigInt(Math.floor(Number(totalMonthlyRequirement) * reserveMultiplier));
    
    return {
        projections: {
            dailyOperations,
            dailyGasUsage,
            monthlyGasUsage: projectedMonthlyGas,
            growthRate: growthRateMonthly
        },
        costs: {
            baseCostPerMonth: baseCostPerMonth.toString(),
            volatilityBuffer: volatilityBuffer.toString(),
            totalMonthlyRequirement: totalMonthlyRequirement.toString(),
            recommendedBalance: recommendedBalance.toString()
        },
        formatted: {
            baseCostPerMonth: ethers.formatEther(baseCostPerMonth),
            totalMonthlyRequirement: ethers.formatEther(totalMonthlyRequirement),
            recommendedBalance: ethers.formatEther(recommendedBalance)
        },
        parameters: {
            averageGasPrice,
            gasPriceVolatility,
            reserveMultiplier
        }
    };
}

module.exports = {
    GAS_OVERHEADS,
    TIER_MULTIPLIERS,
    DEFAULT_GAS_LIMITS,
    GAS_PRICE_CONFIG,
    estimateUserOpGas,
    calculateTierGasLimits,
    checkRateLimit,
    optimizeGasPrice,
    calculateSponsorshipCost,
    detectAbuse,
    calculateFundingRequirements
}; 