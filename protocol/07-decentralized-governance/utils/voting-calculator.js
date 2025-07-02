const { ethers } = require("ethers");

/**
 * Voting Calculator Utilities for Karma DAO Governance
 * Provides voting power and weight calculation functions
 */

class VotingCalculator {
    constructor(quadraticVotingEnabled = true) {
        this.quadraticVotingEnabled = quadraticVotingEnabled;
        this.baseWeight = ethers.parseEther("1"); // 1.0 multiplier
        this.scalingFactor = ethers.parseEther("0.5"); // 0.5 for square root
        this.maxWeight = ethers.parseEther("100000"); // 100K max weight
        this.minStakeRequired = ethers.parseEther("100"); // 100 KARMA minimum
    }
    
    /**
     * Calculate linear voting weight (1:1 with staked amount)
     * @param {BigNumber} stakedAmount - Amount of tokens staked
     * @returns {BigNumber} Linear voting weight
     */
    calculateLinearWeight(stakedAmount) {
        return stakedAmount;
    }
    
    /**
     * Calculate quadratic voting weight (square root based)
     * @param {BigNumber} stakedAmount - Amount of tokens staked
     * @returns {BigNumber} Quadratic voting weight
     */
    calculateQuadraticWeight(stakedAmount) {
        if (!this.quadraticVotingEnabled) {
            return stakedAmount;
        }
        
        // Calculate square root of staked amount
        const sqrtAmount = this.sqrt(stakedAmount);
        
        // Apply scaling factor
        const quadraticWeight = (sqrtAmount * this.scalingFactor) / ethers.parseEther("1");
        
        // Apply maximum cap
        return quadraticWeight > this.maxWeight ? this.maxWeight : quadraticWeight;
    }
    
    /**
     * Calculate both linear and quadratic weights
     * @param {BigNumber} stakedAmount - Amount of tokens staked
     * @returns {Object} {linearWeight, quadraticWeight}
     */
    calculateVotingWeights(stakedAmount) {
        if (stakedAmount < this.minStakeRequired) {
            throw new Error("Insufficient stake amount");
        }
        
        const linearWeight = this.calculateLinearWeight(stakedAmount);
        const quadraticWeight = this.calculateQuadraticWeight(stakedAmount);
        
        return {
            linearWeight,
            quadraticWeight,
            advantageReduction: this.calculateAdvantageReduction(stakedAmount)
        };
    }
    
    /**
     * Calculate how much quadratic voting reduces whale advantage
     * @param {BigNumber} whaleStake - Large stake amount
     * @param {BigNumber} smallStake - Small stake amount for comparison
     * @returns {Number} Advantage reduction ratio
     */
    calculateAdvantageReduction(whaleStake, smallStake = ethers.parseEther("100000")) {
        const linearAdvantage = Number(whaleStake) / Number(smallStake);
        
        const whaleQuadratic = this.calculateQuadraticWeight(whaleStake);
        const smallQuadratic = this.calculateQuadraticWeight(smallStake);
        const quadraticAdvantage = Number(whaleQuadratic) / Number(smallQuadratic);
        
        return quadraticAdvantage / linearAdvantage; // Ratio showing reduction
    }
    
    /**
     * Calculate quorum requirements
     * @param {BigNumber} totalSupply - Total token supply
     * @param {Number} quorumPercentage - Required quorum percentage
     * @returns {BigNumber} Required voting power for quorum
     */
    calculateQuorumRequirement(totalSupply, quorumPercentage) {
        return (totalSupply * BigInt(quorumPercentage)) / BigInt(100);
    }
    
    /**
     * Simulate voting outcome with multiple voters
     * @param {Array} voters - Array of {stake, vote} objects
     * @returns {Object} Voting results
     */
    simulateVoting(voters) {
        let forVotes = BigInt(0);
        let againstVotes = BigInt(0);
        let abstainVotes = BigInt(0);
        
        const voterResults = voters.map(voter => {
            const weights = this.calculateVotingWeights(voter.stake);
            const votingWeight = this.quadraticVotingEnabled ? 
                weights.quadraticWeight : weights.linearWeight;
            
            if (voter.vote === 'for') {
                forVotes += votingWeight;
            } else if (voter.vote === 'against') {
                againstVotes += votingWeight;
            } else {
                abstainVotes += votingWeight;
            }
            
            return {
                address: voter.address,
                stake: voter.stake,
                vote: voter.vote,
                linearWeight: weights.linearWeight,
                quadraticWeight: weights.quadraticWeight,
                effectiveWeight: votingWeight
            };
        });
        
        const totalVotes = forVotes + againstVotes + abstainVotes;
        
        return {
            forVotes,
            againstVotes,
            abstainVotes,
            totalVotes,
            forPercentage: totalVotes > 0 ? Number(forVotes * BigInt(100) / totalVotes) : 0,
            againstPercentage: totalVotes > 0 ? Number(againstVotes * BigInt(100) / totalVotes) : 0,
            abstainPercentage: totalVotes > 0 ? Number(abstainVotes * BigInt(100) / totalVotes) : 0,
            voterResults
        };
    }
    
    /**
     * Calculate optimal staking amount for desired voting power
     * @param {BigNumber} targetWeight - Desired voting weight
     * @returns {BigNumber} Required stake amount
     */
    calculateRequiredStake(targetWeight) {
        if (!this.quadraticVotingEnabled) {
            return targetWeight;
        }
        
        // Reverse calculation: stake = (weight / scalingFactor)^2
        const weightRatio = (targetWeight * ethers.parseEther("1")) / this.scalingFactor;
        return weightRatio * weightRatio; // Square the ratio
    }
    
    /**
     * Calculate integer square root using Newton's method
     * @param {BigNumber} value - Value to calculate square root of
     * @returns {BigNumber} Square root
     */
    sqrt(value) {
        if (value === BigInt(0)) return BigInt(0);
        
        let z = value;
        let x = value / BigInt(2) + BigInt(1);
        
        while (x < z) {
            z = x;
            x = (value / x + x) / BigInt(2);
        }
        
        return z;
    }
    
    /**
     * Format voting weight for display
     * @param {BigNumber} weight - Voting weight to format
     * @returns {String} Formatted weight string
     */
    formatWeight(weight) {
        return ethers.formatEther(weight);
    }
    
    /**
     * Update calculator configuration
     * @param {Object} config - New configuration parameters
     */
    updateConfig(config) {
        if (config.quadraticVotingEnabled !== undefined) {
            this.quadraticVotingEnabled = config.quadraticVotingEnabled;
        }
        if (config.baseWeight) {
            this.baseWeight = config.baseWeight;
        }
        if (config.scalingFactor) {
            this.scalingFactor = config.scalingFactor;
        }
        if (config.maxWeight) {
            this.maxWeight = config.maxWeight;
        }
        if (config.minStakeRequired) {
            this.minStakeRequired = config.minStakeRequired;
        }
    }
}

module.exports = {
    VotingCalculator,
    
    // Utility functions
    calculateLinearWeight: (stakedAmount) => {
        return stakedAmount;
    },
    
    calculateQuadraticWeight: (stakedAmount, scalingFactor = ethers.parseEther("0.5")) => {
        const calculator = new VotingCalculator();
        return calculator.calculateQuadraticWeight(stakedAmount);
    },
    
    simulateProposal: (voters, quorumPercentage = 5, totalSupply = ethers.parseEther("1000000000")) => {
        const calculator = new VotingCalculator();
        const results = calculator.simulateVoting(voters);
        const quorumRequired = calculator.calculateQuorumRequirement(totalSupply, quorumPercentage);
        
        return {
            ...results,
            quorumRequired,
            quorumMet: results.totalVotes >= quorumRequired,
            passed: results.forVotes > results.againstVotes && results.totalVotes >= quorumRequired
        };
    }
}; 