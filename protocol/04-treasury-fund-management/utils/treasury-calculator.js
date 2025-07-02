/**
 * @title Treasury Calculator
 * @dev Utility functions for treasury fund allocation, reporting, and calculations
 */

const { parseEther, formatEther } = require('ethers');

/**
 * Treasury allocation percentages as defined in tokenomics
 */
const ALLOCATION_PERCENTAGES = {
    MARKETING: 30,      // 30% for marketing campaigns
    KOL: 20,           // 20% for KOL partnerships
    DEVELOPMENT: 30,    // 30% for development costs
    BUYBACK: 20        // 20% for buyback and burn
};

/**
 * Category mappings for the Treasury contract
 */
const TREASURY_CATEGORIES = {
    MARKETING: 0,
    KOL: 1,
    DEVELOPMENT: 2,
    BUYBACK: 3
};

/**
 * Time-based constants
 */
const TIME_CONSTANTS = {
    SECONDS_PER_DAY: 86400,
    SECONDS_PER_WEEK: 604800,
    SECONDS_PER_MONTH: 2629746, // 30.44 days average
    SECONDS_PER_YEAR: 31556952  // 365.25 days
};

/**
 * Calculate allocation amounts based on total treasury balance
 * @param {string|bigint} totalBalance - Total treasury balance in wei
 * @returns {Object} Allocation amounts by category
 */
function calculateAllocations(totalBalance) {
    const balance = typeof totalBalance === 'string' ? parseEther(totalBalance) : totalBalance;
    
    return {
        marketing: (balance * BigInt(ALLOCATION_PERCENTAGES.MARKETING)) / BigInt(100),
        kol: (balance * BigInt(ALLOCATION_PERCENTAGES.KOL)) / BigInt(100),
        development: (balance * BigInt(ALLOCATION_PERCENTAGES.DEVELOPMENT)) / BigInt(100),
        buyback: (balance * BigInt(ALLOCATION_PERCENTAGES.BUYBACK)) / BigInt(100)
    };
}

/**
 * Calculate remaining allocation for a specific category
 * @param {bigint} totalBudget - Total budget for the category
 * @param {bigint} spent - Amount already spent
 * @returns {bigint} Remaining allocation
 */
function calculateRemainingAllocation(totalBudget, spent) {
    return totalBudget > spent ? totalBudget - spent : BigInt(0);
}

/**
 * Calculate spending rate per time period
 * @param {bigint} amountSpent - Amount spent
 * @param {number} timeElapsed - Time elapsed in seconds
 * @param {number} periodLength - Period length in seconds (default: 1 month)
 * @returns {bigint} Spending rate per period
 */
function calculateSpendingRate(amountSpent, timeElapsed, periodLength = TIME_CONSTANTS.SECONDS_PER_MONTH) {
    if (timeElapsed === 0) return BigInt(0);
    
    const rate = (amountSpent * BigInt(periodLength)) / BigInt(timeElapsed);
    return rate;
}

/**
 * Calculate withdrawal timelock based on amount and treasury balance
 * @param {bigint} withdrawalAmount - Requested withdrawal amount
 * @param {bigint} treasuryBalance - Current treasury balance
 * @param {number} thresholdPercent - Percentage threshold for timelock (default: 10%)
 * @param {number} timelockDays - Timelock duration in days (default: 7)
 * @returns {Object} Timelock information
 */
function calculateWithdrawalTimelock(
    withdrawalAmount, 
    treasuryBalance, 
    thresholdPercent = 10, 
    timelockDays = 7
) {
    const threshold = (treasuryBalance * BigInt(thresholdPercent)) / BigInt(100);
    const requiresTimelock = withdrawalAmount > threshold;
    
    return {
        requiresTimelock,
        threshold: formatEther(threshold),
        timelockSeconds: timelockDays * TIME_CONSTANTS.SECONDS_PER_DAY,
        timelockDays
    };
}

/**
 * Calculate budget burn rate and runway
 * @param {Object} allocations - Current allocations per category
 * @param {Object} spendingRates - Monthly spending rates per category
 * @returns {Object} Burn rate analysis
 */
function calculateBurnRate(allocations, spendingRates) {
    const totalMonthlyBurn = Object.values(spendingRates).reduce(
        (sum, rate) => sum + rate, 
        BigInt(0)
    );
    
    const totalRemaining = Object.values(allocations).reduce(
        (sum, allocation) => sum + allocation,
        BigInt(0)
    );
    
    const runwayMonths = totalMonthlyBurn > 0 
        ? Number(totalRemaining / totalMonthlyBurn) 
        : Infinity;
    
    return {
        totalMonthlyBurn: formatEther(totalMonthlyBurn),
        totalRemaining: formatEther(totalRemaining),
        runwayMonths,
        burnRateByCategory: {
            marketing: formatEther(spendingRates.marketing || BigInt(0)),
            kol: formatEther(spendingRates.kol || BigInt(0)),
            development: formatEther(spendingRates.development || BigInt(0)),
            buyback: formatEther(spendingRates.buyback || BigInt(0))
        }
    };
}

/**
 * Validate withdrawal request against allocation limits
 * @param {number} category - Treasury category (0-3)
 * @param {bigint} amount - Withdrawal amount
 * @param {bigint} categoryBudget - Available budget for category
 * @param {bigint} categorySpent - Already spent amount for category
 * @returns {Object} Validation result
 */
function validateWithdrawal(category, amount, categoryBudget, categorySpent) {
    const remaining = calculateRemainingAllocation(categoryBudget, categorySpent);
    const isValid = amount <= remaining;
    
    return {
        isValid,
        remaining: formatEther(remaining),
        requested: formatEther(amount),
        category: Object.keys(TREASURY_CATEGORIES)[category],
        error: isValid ? null : `Insufficient allocation: requested ${formatEther(amount)} ETH, available ${formatEther(remaining)} ETH`
    };
}

/**
 * Calculate monthly treasury report data
 * @param {Object} treasuryData - Current treasury state
 * @returns {Object} Monthly report data
 */
function generateMonthlyReport(treasuryData) {
    const { balance, allocations, spent, lastReportTimestamp } = treasuryData;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const timeSinceLastReport = currentTimestamp - lastReportTimestamp;
    
    const spendingRates = {
        marketing: calculateSpendingRate(spent.marketing, timeSinceLastReport),
        kol: calculateSpendingRate(spent.kol, timeSinceLastReport),
        development: calculateSpendingRate(spent.development, timeSinceLastReport),
        buyback: calculateSpendingRate(spent.buyback, timeSinceLastReport)
    };
    
    const burnAnalysis = calculateBurnRate(allocations, spendingRates);
    
    return {
        reportDate: new Date(currentTimestamp * 1000).toISOString(),
        totalBalance: formatEther(balance),
        allocations: {
            marketing: formatEther(allocations.marketing),
            kol: formatEther(allocations.kol),
            development: formatEther(allocations.development),
            buyback: formatEther(allocations.buyback)
        },
        spent: {
            marketing: formatEther(spent.marketing),
            kol: formatEther(spent.kol),
            development: formatEther(spent.development),
            buyback: formatEther(spent.buyback)
        },
        remaining: {
            marketing: formatEther(allocations.marketing - spent.marketing),
            kol: formatEther(allocations.kol - spent.kol),
            development: formatEther(allocations.development - spent.development),
            buyback: formatEther(allocations.buyback - spent.buyback)
        },
        burnAnalysis,
        reportPeriodDays: Math.floor(timeSinceLastReport / TIME_CONSTANTS.SECONDS_PER_DAY)
    };
}

/**
 * Calculate token distribution allocations
 * @param {bigint} totalTokens - Total tokens to distribute
 * @returns {Object} Token distribution breakdown
 */
function calculateTokenDistribution(totalTokens) {
    // Based on tokenomics: 200M community rewards allocation
    return {
        airdrop: (totalTokens * BigInt(10)) / BigInt(100),        // 20M (10% of 200M)
        staking: (totalTokens * BigInt(50)) / BigInt(100),        // 100M (50% of 200M)
        engagement: (totalTokens * BigInt(40)) / BigInt(100)      // 80M (40% of 200M)
    };
}

/**
 * Calculate optimal rebalancing for treasury allocations
 * @param {Object} currentAllocations - Current allocations
 * @param {Object} targetPercentages - Target allocation percentages
 * @param {bigint} totalBalance - Total treasury balance
 * @returns {Object} Rebalancing recommendations
 */
function calculateRebalancing(currentAllocations, targetPercentages, totalBalance) {
    const targetAllocations = calculateAllocations(totalBalance);
    
    const rebalancing = {};
    for (const [category, current] of Object.entries(currentAllocations)) {
        const target = targetAllocations[category];
        const difference = target - current;
        
        rebalancing[category] = {
            current: formatEther(current),
            target: formatEther(target),
            adjustment: formatEther(difference),
            needsIncrease: difference > 0,
            adjustmentPercent: Number((difference * BigInt(10000)) / totalBalance) / 100
        };
    }
    
    return rebalancing;
}

module.exports = {
    ALLOCATION_PERCENTAGES,
    TREASURY_CATEGORIES,
    TIME_CONSTANTS,
    calculateAllocations,
    calculateRemainingAllocation,
    calculateSpendingRate,
    calculateWithdrawalTimelock,
    calculateBurnRate,
    validateWithdrawal,
    generateMonthlyReport,
    calculateTokenDistribution,
    calculateRebalancing
}; 