/**
 * Vesting Calculator Utilities
 * Stage 2: Vesting System Architecture
 * 
 * Mathematical functions and calculations for vesting schedules
 */

const { BigNumber } = require("ethers");

// ============ VESTING CONSTANTS ============

const VESTING_CONSTANTS = {
    // Time units in seconds
    TIME_UNITS: {
        SECOND: 1,
        MINUTE: 60,
        HOUR: 3600,
        DAY: 86400,
        WEEK: 604800,
        MONTH: 2592000, // 30 days
        YEAR: 31536000  // 365 days
    },
    
    // Standard vesting periods
    STANDARD_PERIODS: {
        TEAM_VESTING: {
            TOTAL_DURATION: 31536000 * 4, // 4 years
            CLIFF_DURATION: 31536000,      // 1 year
            RELEASE_FREQUENCY: 2592000     // Monthly
        },
        PRIVATE_SALE_VESTING: {
            TOTAL_DURATION: 2592000 * 6,  // 6 months
            CLIFF_DURATION: 0,             // No cliff
            RELEASE_FREQUENCY: 2592000     // Monthly
        },
        ADVISOR_VESTING: {
            TOTAL_DURATION: 31536000 * 2, // 2 years
            CLIFF_DURATION: 2592000 * 6,  // 6 months
            RELEASE_FREQUENCY: 2592000     // Monthly
        }
    }
};

// ============ VESTING CALCULATIONS ============

/**
 * Calculate linear vesting amount based on time elapsed
 * @param {BigNumber} totalAmount - Total amount to be vested
 * @param {number} startTime - Vesting start timestamp
 * @param {number} endTime - Vesting end timestamp
 * @param {number} currentTime - Current timestamp
 * @param {number} cliffTime - Cliff end timestamp (optional)
 * @returns {Object} Vesting calculation result
 */
function calculateLinearVesting(totalAmount, startTime, endTime, currentTime, cliffTime = 0) {
    // Convert to BigNumber for precise calculations
    const total = BigNumber.from(totalAmount.toString());
    
    // Validate inputs
    if (startTime >= endTime) {
        throw new Error("Start time must be before end time");
    }
    
    if (currentTime < startTime) {
        return {
            vestedAmount: BigNumber.from(0),
            releasableAmount: BigNumber.from(0),
            progressPercentage: "0",
            remainingAmount: total,
            isCliffPassed: false,
            nextReleaseTime: cliffTime > startTime ? cliffTime : startTime
        };
    }
    
    // Check if cliff period has passed
    const isCliffPassed = currentTime >= (cliffTime || startTime);
    
    if (!isCliffPassed) {
        return {
            vestedAmount: BigNumber.from(0),
            releasableAmount: BigNumber.from(0),
            progressPercentage: "0",
            remainingAmount: total,
            isCliffPassed: false,
            nextReleaseTime: cliffTime
        };
    }
    
    // Calculate vested amount
    let vestedAmount;
    let progressPercentage;
    
    if (currentTime >= endTime) {
        // Fully vested
        vestedAmount = total;
        progressPercentage = "100";
    } else {
        // Linear vesting calculation
        const totalDuration = endTime - startTime;
        const elapsedTime = currentTime - startTime;
        const progressRatio = elapsedTime / totalDuration;
        
        vestedAmount = total.mul(Math.floor(progressRatio * 10000)).div(10000);
        progressPercentage = (progressRatio * 100).toFixed(2);
    }
    
    return {
        vestedAmount,
        releasableAmount: vestedAmount, // Assume no previous claims for simplicity
        progressPercentage,
        remainingAmount: total.sub(vestedAmount),
        isCliffPassed: true,
        nextReleaseTime: currentTime >= endTime ? null : endTime
    };
}

/**
 * Calculate cliff vesting amount
 * @param {BigNumber} totalAmount - Total amount to be vested
 * @param {number} cliffTime - Cliff end timestamp
 * @param {number} currentTime - Current timestamp
 * @returns {Object} Cliff vesting result
 */
function calculateCliffVesting(totalAmount, cliffTime, currentTime) {
    const total = BigNumber.from(totalAmount.toString());
    
    if (currentTime < cliffTime) {
        return {
            vestedAmount: BigNumber.from(0),
            releasableAmount: BigNumber.from(0),
            progressPercentage: "0",
            remainingAmount: total,
            isCliffPassed: false,
            nextReleaseTime: cliffTime
        };
    }
    
    return {
        vestedAmount: total,
        releasableAmount: total,
        progressPercentage: "100",
        remainingAmount: BigNumber.from(0),
        isCliffPassed: true,
        nextReleaseTime: null
    };
}

/**
 * Calculate team vesting schedule (4 years with 1 year cliff)
 * @param {BigNumber} totalAmount - Total team allocation
 * @param {number} startTime - Vesting start timestamp
 * @param {number} currentTime - Current timestamp
 * @returns {Object} Team vesting calculation
 */
function calculateTeamVesting(totalAmount, startTime, currentTime) {
    const cliffTime = startTime + VESTING_CONSTANTS.STANDARD_PERIODS.TEAM_VESTING.CLIFF_DURATION;
    const endTime = startTime + VESTING_CONSTANTS.STANDARD_PERIODS.TEAM_VESTING.TOTAL_DURATION;
    
    return calculateLinearVesting(totalAmount, startTime, endTime, currentTime, cliffTime);
}

/**
 * Calculate private sale vesting schedule (6 months linear)
 * @param {BigNumber} totalAmount - Total private sale allocation
 * @param {number} startTime - Vesting start timestamp
 * @param {number} currentTime - Current timestamp
 * @returns {Object} Private sale vesting calculation
 */
function calculatePrivateSaleVesting(totalAmount, startTime, currentTime) {
    const endTime = startTime + VESTING_CONSTANTS.STANDARD_PERIODS.PRIVATE_SALE_VESTING.TOTAL_DURATION;
    
    return calculateLinearVesting(totalAmount, startTime, endTime, currentTime, startTime);
}

/**
 * Calculate monthly release amount for linear vesting
 * @param {BigNumber} totalAmount - Total vesting amount
 * @param {number} totalMonths - Total vesting duration in months
 * @returns {BigNumber} Monthly release amount
 */
function calculateMonthlyRelease(totalAmount, totalMonths) {
    const total = BigNumber.from(totalAmount.toString());
    return total.div(totalMonths);
}

/**
 * Generate vesting schedule milestones
 * @param {BigNumber} totalAmount - Total vesting amount
 * @param {number} startTime - Vesting start timestamp
 * @param {number} duration - Total vesting duration in seconds
 * @param {number} frequency - Release frequency in seconds
 * @param {number} cliffDuration - Cliff duration in seconds (optional)
 * @returns {Array} Array of vesting milestones
 */
function generateVestingSchedule(totalAmount, startTime, duration, frequency, cliffDuration = 0) {
    const total = BigNumber.from(totalAmount.toString());
    const schedule = [];
    
    const cliffEnd = startTime + cliffDuration;
    const vestingEnd = startTime + duration;
    const releaseCount = Math.floor(duration / frequency);
    const amountPerRelease = total.div(releaseCount);
    
    for (let i = 0; i <= releaseCount; i++) {
        const releaseTime = startTime + (i * frequency);
        
        if (releaseTime < cliffEnd) {
            continue; // Skip releases before cliff
        }
        
        const cumulativeAmount = amountPerRelease.mul(i);
        const finalAmount = releaseTime >= vestingEnd ? total : cumulativeAmount;
        
        schedule.push({
            releaseTime,
            releaseAmount: i === 0 ? finalAmount : amountPerRelease,
            cumulativeAmount: finalAmount,
            progressPercentage: finalAmount.mul(100).div(total).toString()
        });
        
        if (releaseTime >= vestingEnd) break;
    }
    
    return schedule;
}

/**
 * Validate vesting parameters
 * @param {Object} params - Vesting parameters to validate
 * @returns {Object} Validation result
 */
function validateVestingParameters(params) {
    const errors = [];
    const warnings = [];
    
    // Check required parameters
    if (!params.totalAmount || BigNumber.from(params.totalAmount.toString()).lte(0)) {
        errors.push("Total amount must be greater than zero");
    }
    
    if (!params.startTime || params.startTime <= 0) {
        errors.push("Start time must be a valid timestamp");
    }
    
    if (!params.duration || params.duration <= 0) {
        errors.push("Duration must be greater than zero");
    }
    
    // Check logical constraints
    if (params.cliffDuration && params.cliffDuration >= params.duration) {
        errors.push("Cliff duration cannot be greater than or equal to total duration");
    }
    
    if (params.startTime && params.startTime < Math.floor(Date.now() / 1000)) {
        warnings.push("Start time is in the past");
    }
    
    // Check reasonable ranges
    if (params.duration && params.duration > VESTING_CONSTANTS.TIME_UNITS.YEAR * 10) {
        warnings.push("Vesting duration exceeds 10 years");
    }
    
    return {
        isValid: errors.length === 0,
        errors,
        warnings
    };
}

/**
 * Calculate gas-optimized vesting checkpoints
 * @param {Object} vestingParams - Vesting parameters
 * @returns {Array} Optimized checkpoint schedule
 */
function calculateGasOptimizedCheckpoints(vestingParams) {
    const { totalAmount, startTime, duration, cliffDuration = 0 } = vestingParams;
    
    // Optimize for fewer transactions while maintaining user experience
    const checkpoints = [];
    const cliffEnd = startTime + cliffDuration;
    const vestingEnd = startTime + duration;
    
    // Add cliff checkpoint if exists
    if (cliffDuration > 0) {
        checkpoints.push({
            timestamp: cliffEnd,
            description: "Cliff end - Initial release",
            isCliff: true
        });
    }
    
    // Add monthly checkpoints after cliff
    const monthlyInterval = VESTING_CONSTANTS.TIME_UNITS.MONTH;
    let currentTime = Math.max(cliffEnd, startTime);
    
    while (currentTime < vestingEnd) {
        currentTime += monthlyInterval;
        if (currentTime <= vestingEnd) {
            checkpoints.push({
                timestamp: Math.min(currentTime, vestingEnd),
                description: currentTime >= vestingEnd ? "Final release" : "Monthly release",
                isCliff: false
            });
        }
    }
    
    return checkpoints;
}

// ============ EXPORTS ============

module.exports = {
    VESTING_CONSTANTS,
    calculateLinearVesting,
    calculateCliffVesting,
    calculateTeamVesting,
    calculatePrivateSaleVesting,
    calculateMonthlyRelease,
    generateVestingSchedule,
    validateVestingParameters,
    calculateGasOptimizedCheckpoints
}; 