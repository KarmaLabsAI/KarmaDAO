/**
 * Price Calculator Utilities
 * Stage 3: Token Sales Engine
 * 
 * Token pricing and conversion utilities for multi-phase sales
 */

const { BigNumber } = require("ethers");

// ============ PRICING CONSTANTS ============

const PRICING_CONSTANTS = {
    // Base token prices (in wei, for 1 ETH worth)
    PRICES: {
        PRIVATE_SALE: "20000000000000000", // $0.02 = 50 KARMA per $1, assuming 1 ETH = $1000
        PRE_SALE: "40000000000000000",     // $0.04 = 25 KARMA per $1
        PUBLIC_SALE: "50000000000000000"   // $0.05 = 20 KARMA per $1
    },
    
    // Phase allocations (in tokens)
    ALLOCATIONS: {
        PRIVATE_SALE: "100000000000000000000000000", // 100M KARMA
        PRE_SALE: "100000000000000000000000000",     // 100M KARMA  
        PUBLIC_SALE: "150000000000000000000000000"   // 150M KARMA
    },
    
    // Fund raising targets (in wei, ETH)
    TARGETS: {
        PRIVATE_SALE: "2000000000000000000000",      // $2M (2000 ETH @ $1000)
        PRE_SALE: "4000000000000000000000",          // $4M (4000 ETH @ $1000)
        PUBLIC_SALE: "7500000000000000000000"        // $7.5M (7500 ETH @ $1000)
    },
    
    // Purchase limits (in wei, ETH)
    LIMITS: {
        PRIVATE_SALE: {
            MIN: "25000000000000000000",  // $25K (25 ETH @ $1000)
            MAX: "200000000000000000000"  // $200K (200 ETH @ $1000)
        },
        PRE_SALE: {
            MIN: "1000000000000000000",   // $1K (1 ETH @ $1000)
            MAX: "10000000000000000000"   // $10K (10 ETH @ $1000)
        },
        PUBLIC_SALE: {
            MIN: "100000000000000000",    // $100 (0.1 ETH @ $1000)
            MAX: "5000000000000000000"    // $5K (5 ETH @ $1000)
        }
    },
    
    // Precision for calculations
    PRECISION: 18,
    
    // Fee percentages (in basis points, 100 = 1%)
    FEES: {
        PLATFORM_FEE: 50,      // 0.5%
        SLIPPAGE_TOLERANCE: 300 // 3%
    }
};

// ============ PRICE CALCULATIONS ============

/**
 * Calculate token amount for given ETH amount and sale phase
 * @param {BigNumber} ethAmount - Amount of ETH to spend
 * @param {string} phase - Sale phase ('PRIVATE', 'PRE_SALE', 'PUBLIC')
 * @returns {BigNumber} Amount of KARMA tokens to receive
 */
function calculateTokenAmount(ethAmount, phase) {
    const eth = BigNumber.from(ethAmount.toString());
    let price;
    
    switch (phase.toUpperCase()) {
        case 'PRIVATE':
        case 'PRIVATE_SALE':
            price = BigNumber.from(PRICING_CONSTANTS.PRICES.PRIVATE_SALE);
            break;
        case 'PRE':
        case 'PRE_SALE':
            price = BigNumber.from(PRICING_CONSTANTS.PRICES.PRE_SALE);
            break;
        case 'PUBLIC':
        case 'PUBLIC_SALE':
            price = BigNumber.from(PRICING_CONSTANTS.PRICES.PUBLIC_SALE);
            break;
        default:
            throw new Error(`Invalid sale phase: ${phase}`);
    }
    
    // Calculate tokens: ethAmount / price (price is cost per token in ETH)
    return eth.mul(BigNumber.from(10).pow(18)).div(price);
}

/**
 * Calculate ETH amount needed for desired token amount
 * @param {BigNumber} tokenAmount - Desired amount of KARMA tokens
 * @param {string} phase - Sale phase
 * @returns {BigNumber} Amount of ETH needed
 */
function calculateEthAmount(tokenAmount, phase) {
    const tokens = BigNumber.from(tokenAmount.toString());
    let price;
    
    switch (phase.toUpperCase()) {
        case 'PRIVATE':
        case 'PRIVATE_SALE':
            price = BigNumber.from(PRICING_CONSTANTS.PRICES.PRIVATE_SALE);
            break;
        case 'PRE':
        case 'PRE_SALE':
            price = BigNumber.from(PRICING_CONSTANTS.PRICES.PRE_SALE);
            break;
        case 'PUBLIC':
        case 'PUBLIC_SALE':
            price = BigNumber.from(PRICING_CONSTANTS.PRICES.PUBLIC_SALE);
            break;
        default:
            throw new Error(`Invalid sale phase: ${phase}`);
    }
    
    // Calculate ETH: tokenAmount * price
    return tokens.mul(price).div(BigNumber.from(10).pow(18));
}

/**
 * Calculate bonus tokens based on engagement score
 * @param {BigNumber} baseTokens - Base token amount before bonus
 * @param {number} engagementScore - User engagement score (0-100)
 * @returns {BigNumber} Bonus token amount
 */
function calculateBonusTokens(baseTokens, engagementScore) {
    const base = BigNumber.from(baseTokens.toString());
    
    if (engagementScore < 20) return BigNumber.from(0);
    if (engagementScore < 40) return base.mul(5).div(100);  // 5% bonus
    if (engagementScore < 60) return base.mul(10).div(100); // 10% bonus
    if (engagementScore < 80) return base.mul(15).div(100); // 15% bonus
    return base.mul(20).div(100); // 20% bonus for top engagement
}

/**
 * Calculate referral bonus tokens
 * @param {BigNumber} baseTokens - Base token amount before bonus
 * @param {number} refereeCount - Number of successful referrals
 * @returns {BigNumber} Referral bonus token amount
 */
function calculateReferralBonus(baseTokens, refereeCount) {
    const base = BigNumber.from(baseTokens.toString());
    
    if (refereeCount === 0) return BigNumber.from(0);
    
    // Progressive bonus: 2% per referral, capped at 20%
    const bonusPercent = Math.min(refereeCount * 2, 20);
    return base.mul(bonusPercent).div(100);
}

/**
 * Calculate platform fee for a purchase
 * @param {BigNumber} ethAmount - Purchase amount in ETH
 * @returns {BigNumber} Platform fee amount in ETH
 */
function calculatePlatformFee(ethAmount) {
    const amount = BigNumber.from(ethAmount.toString());
    return amount.mul(PRICING_CONSTANTS.FEES.PLATFORM_FEE).div(10000);
}

/**
 * Calculate slippage-protected minimum tokens
 * @param {BigNumber} expectedTokens - Expected token amount
 * @param {number} slippageTolerance - Slippage tolerance in basis points (default 3%)
 * @returns {BigNumber} Minimum acceptable token amount
 */
function calculateMinTokensWithSlippage(expectedTokens, slippageTolerance = PRICING_CONSTANTS.FEES.SLIPPAGE_TOLERANCE) {
    const expected = BigNumber.from(expectedTokens.toString());
    const slippage = BigNumber.from(slippageTolerance);
    
    // Minimum = expected * (10000 - slippage) / 10000
    return expected.mul(BigNumber.from(10000).sub(slippage)).div(10000);
}

/**
 * Validate purchase limits for a given phase
 * @param {BigNumber} ethAmount - Purchase amount in ETH
 * @param {string} phase - Sale phase
 * @returns {Object} Validation result
 */
function validatePurchaseLimits(ethAmount, phase) {
    const amount = BigNumber.from(ethAmount.toString());
    let limits;
    
    switch (phase.toUpperCase()) {
        case 'PRIVATE':
        case 'PRIVATE_SALE':
            limits = PRICING_CONSTANTS.LIMITS.PRIVATE_SALE;
            break;
        case 'PRE':
        case 'PRE_SALE':
            limits = PRICING_CONSTANTS.LIMITS.PRE_SALE;
            break;
        case 'PUBLIC':
        case 'PUBLIC_SALE':
            limits = PRICING_CONSTANTS.LIMITS.PUBLIC_SALE;
            break;
        default:
            return { valid: false, error: `Invalid sale phase: ${phase}` };
    }
    
    const min = BigNumber.from(limits.MIN);
    const max = BigNumber.from(limits.MAX);
    
    if (amount.lt(min)) {
        return {
            valid: false,
            error: `Purchase amount below minimum: ${amount.toString()} < ${min.toString()}`
        };
    }
    
    if (amount.gt(max)) {
        return {
            valid: false,
            error: `Purchase amount above maximum: ${amount.toString()} > ${max.toString()}`
        };
    }
    
    return { valid: true };
}

/**
 * Calculate sale progress for a phase
 * @param {BigNumber} raisedAmount - Amount raised so far (in ETH)
 * @param {string} phase - Sale phase
 * @returns {Object} Sale progress information
 */
function calculateSaleProgress(raisedAmount, phase) {
    const raised = BigNumber.from(raisedAmount.toString());
    let target;
    let allocation;
    
    switch (phase.toUpperCase()) {
        case 'PRIVATE':
        case 'PRIVATE_SALE':
            target = BigNumber.from(PRICING_CONSTANTS.TARGETS.PRIVATE_SALE);
            allocation = BigNumber.from(PRICING_CONSTANTS.ALLOCATIONS.PRIVATE_SALE);
            break;
        case 'PRE':
        case 'PRE_SALE':
            target = BigNumber.from(PRICING_CONSTANTS.TARGETS.PRE_SALE);
            allocation = BigNumber.from(PRICING_CONSTANTS.ALLOCATIONS.PRE_SALE);
            break;
        case 'PUBLIC':
        case 'PUBLIC_SALE':
            target = BigNumber.from(PRICING_CONSTANTS.TARGETS.PUBLIC_SALE);
            allocation = BigNumber.from(PRICING_CONSTANTS.ALLOCATIONS.PUBLIC_SALE);
            break;
        default:
            throw new Error(`Invalid sale phase: ${phase}`);
    }
    
    const progressPercent = raised.mul(10000).div(target); // Basis points
    const tokensSold = calculateTokenAmount(raised, phase);
    const tokensRemaining = allocation.sub(tokensSold);
    
    return {
        raised: raised.toString(),
        target: target.toString(),
        progressPercent: progressPercent.toString(),
        tokensSold: tokensSold.toString(),
        tokensRemaining: tokensRemaining.toString(),
        isComplete: raised.gte(target)
    };
}

/**
 * Calculate optimal distribution between immediate and vested tokens
 * @param {BigNumber} totalTokens - Total token amount
 * @param {string} phase - Sale phase
 * @returns {Object} Distribution breakdown
 */
function calculateTokenDistribution(totalTokens, phase) {
    const total = BigNumber.from(totalTokens.toString());
    
    switch (phase.toUpperCase()) {
        case 'PRIVATE':
        case 'PRIVATE_SALE':
            // 100% vested (6 months)
            return {
                immediate: BigNumber.from(0),
                vested: total,
                vestingMonths: 6
            };
        case 'PRE':
        case 'PRE_SALE':
            // 50% immediate, 50% vested
            const preImmediate = total.div(2);
            const preVested = total.sub(preImmediate);
            return {
                immediate: preImmediate,
                vested: preVested,
                vestingMonths: 3
            };
        case 'PUBLIC':
        case 'PUBLIC_SALE':
            // 100% immediate
            return {
                immediate: total,
                vested: BigNumber.from(0),
                vestingMonths: 0
            };
        default:
            throw new Error(`Invalid sale phase: ${phase}`);
    }
}

/**
 * Format token amount for display
 * @param {BigNumber} tokenAmount - Token amount in wei
 * @returns {string} Formatted token amount
 */
function formatTokenAmount(tokenAmount) {
    const tokens = BigNumber.from(tokenAmount.toString());
    const divisor = BigNumber.from(10).pow(18);
    
    // Convert to decimal with 2 decimal places
    const whole = tokens.div(divisor);
    const remainder = tokens.mod(divisor);
    const decimal = remainder.mul(100).div(divisor);
    
    return `${whole.toString()}.${decimal.toString().padStart(2, '0')}`;
}

/**
 * Format ETH amount for display
 * @param {BigNumber} ethAmount - ETH amount in wei
 * @returns {string} Formatted ETH amount
 */
function formatEthAmount(ethAmount) {
    const eth = BigNumber.from(ethAmount.toString());
    const divisor = BigNumber.from(10).pow(18);
    
    const whole = eth.div(divisor);
    const remainder = eth.mod(divisor);
    const decimal = remainder.mul(10000).div(divisor);
    
    return `${whole.toString()}.${decimal.toString().padStart(4, '0')}`;
}

// ============ EXPORTS ============

module.exports = {
    PRICING_CONSTANTS,
    calculateTokenAmount,
    calculateEthAmount,
    calculateBonusTokens,
    calculateReferralBonus,
    calculatePlatformFee,
    calculateMinTokensWithSlippage,
    validatePurchaseLimits,
    calculateSaleProgress,
    calculateTokenDistribution,
    formatTokenAmount,
    formatEthAmount
}; 