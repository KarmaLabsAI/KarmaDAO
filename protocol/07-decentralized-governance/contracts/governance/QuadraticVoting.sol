// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title QuadraticVoting
 * @dev Implementation of quadratic voting mechanisms for the Karma DAO
 * @notice Provides vote weight calculation and whale dominance prevention
 */
contract QuadraticVoting is AccessControl, ReentrancyGuard {
    bytes32 public constant VOTE_CALCULATOR_ROLE = keccak256("VOTE_CALCULATOR_ROLE");
    bytes32 public constant CONFIG_MANAGER_ROLE = keccak256("CONFIG_MANAGER_ROLE");
    
    // ============ EVENTS ============
    
    event QuadraticConfigUpdated(
        uint256 baseWeight,
        uint256 scalingFactor,
        uint256 maxWeight,
        bool enabled
    );
    
    event VoteWeightCalculated(
        address indexed voter,
        uint256 stakedAmount,
        uint256 linearWeight,
        uint256 quadraticWeight
    );
    
    // ============ STRUCTS ============
    
    struct QuadraticConfig {
        uint256 baseWeight;        // Base weight multiplier (1e18)
        uint256 scalingFactor;     // Quadratic scaling factor (1e18)
        uint256 maxWeight;         // Maximum weight cap (prevents extreme dominance)
        uint256 minStakeRequired;  // Minimum stake to participate
        bool enabled;              // Enable/disable quadratic voting
    }
    
    struct VoteRecord {
        address voter;
        uint256 stakedAmount;
        uint256 linearWeight;
        uint256 quadraticWeight;
        uint256 timestamp;
    }
    
    // ============ STATE VARIABLES ============
    
    QuadraticConfig public quadraticConfig;
    
    // Mapping of proposal ID to voter to vote record
    mapping(uint256 => mapping(address => VoteRecord)) public voteRecords;
    
    // Total vote weights per proposal
    mapping(uint256 => uint256) public totalLinearWeight;
    mapping(uint256 => uint256) public totalQuadraticWeight;
    
    // Voter statistics
    mapping(address => uint256) public totalVotesCast;
    mapping(address => uint256) public totalWeight;
    
    uint256 public totalVoters;
    uint256 public totalVotesProcessed;
    
    // ============ CONSTRUCTOR ============
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_MANAGER_ROLE, admin);
        _grantRole(VOTE_CALCULATOR_ROLE, admin);
        
        // Initialize default quadratic configuration
        quadraticConfig = QuadraticConfig({
            baseWeight: 1e18,           // 1.0 base multiplier
            scalingFactor: 5e17,        // 0.5 scaling factor for square root
            maxWeight: 100000e18,       // Max 100K weight (prevents whale dominance)
            minStakeRequired: 100e18,   // Minimum 100 KARMA to vote
            enabled: true
        });
    }
    
    // ============ CORE QUADRATIC VOTING FUNCTIONS ============
    
    /**
     * @dev Calculate quadratic voting weight based on staked amount
     * @param stakedAmount Amount of tokens staked by the voter
     * @return linearWeight Standard linear voting weight
     * @return quadraticWeight Quadratic voting weight (square root based)
     */
    function calculateVotingWeight(uint256 stakedAmount) 
        external 
        view 
        returns (uint256 linearWeight, uint256 quadraticWeight) 
    {
        require(stakedAmount >= quadraticConfig.minStakeRequired, "Insufficient stake");
        
        linearWeight = stakedAmount;
        
        if (!quadraticConfig.enabled) {
            quadraticWeight = linearWeight;
        } else {
            uint256 sqrtAmount = Math.sqrt(stakedAmount);
            quadraticWeight = (sqrtAmount * quadraticConfig.scalingFactor) / 1e18;
            
            if (quadraticWeight > quadraticConfig.maxWeight) {
                quadraticWeight = quadraticConfig.maxWeight;
            }
            
            if (quadraticWeight == 0) {
                quadraticWeight = 1;
            }
        }
    }
    
    /**
     * @dev Record a vote with quadratic weighting
     * @param proposalId The proposal being voted on
     * @param voter The address of the voter
     * @param stakedAmount Amount of tokens staked by the voter
     * @return linearWeight The linear voting weight applied
     * @return quadraticWeight The quadratic voting weight applied
     */
    function recordVote(
        uint256 proposalId,
        address voter,
        uint256 stakedAmount
    ) 
        external 
        onlyRole(VOTE_CALCULATOR_ROLE)
        nonReentrant
        returns (uint256 linearWeight, uint256 quadraticWeight) 
    {
        require(voter != address(0), "QuadraticVoting: invalid voter");
        require(stakedAmount >= quadraticConfig.minStakeRequired, "QuadraticVoting: insufficient stake");
        
        // Calculate voting weights
        (linearWeight, quadraticWeight) = this.calculateVotingWeight(stakedAmount);
        
        // Record vote
        VoteRecord storage record = voteRecords[proposalId][voter];
        
        // Update record if this is a new vote
        if (record.timestamp == 0) {
            totalVoters++;
        } else {
            // Subtract previous weights if changing vote
            totalLinearWeight[proposalId] -= record.linearWeight;
            totalQuadraticWeight[proposalId] -= record.quadraticWeight;
        }
        
        record.voter = voter;
        record.stakedAmount = stakedAmount;
        record.linearWeight = linearWeight;
        record.quadraticWeight = quadraticWeight;
        record.timestamp = block.timestamp;
        
        // Update totals
        totalLinearWeight[proposalId] += linearWeight;
        totalQuadraticWeight[proposalId] += quadraticWeight;
        totalVotesCast[voter]++;
        totalWeight[voter] += quadraticWeight;
        totalVotesProcessed++;
        
        emit VoteWeightCalculated(voter, stakedAmount, linearWeight, quadraticWeight);
        
        return (linearWeight, quadraticWeight);
    }
    
    /**
     * @dev Get voting weight for a specific voter on a proposal
     * @param proposalId The proposal ID
     * @param voter The voter address
     * @return The vote record for the voter
     */
    function getVoteRecord(uint256 proposalId, address voter) 
        external 
        view 
        returns (VoteRecord memory) 
    {
        return voteRecords[proposalId][voter];
    }
    
    /**
     * @dev Get total voting weights for a proposal
     * @param proposalId The proposal ID
     * @return linearTotal Total linear voting weight
     * @return quadraticTotal Total quadratic voting weight
     */
    function getProposalWeights(uint256 proposalId) 
        external 
        view 
        returns (uint256 linearTotal, uint256 quadraticTotal) 
    {
        return (totalLinearWeight[proposalId], totalQuadraticWeight[proposalId]);
    }
    
    // ============ CONFIGURATION FUNCTIONS ============
    
    /**
     * @dev Update quadratic voting configuration
     * @param newConfig New configuration parameters
     */
    function updateQuadraticConfig(QuadraticConfig memory newConfig) 
        external 
        onlyRole(CONFIG_MANAGER_ROLE) 
    {
        require(newConfig.baseWeight > 0, "QuadraticVoting: invalid base weight");
        require(newConfig.scalingFactor > 0, "QuadraticVoting: invalid scaling factor");
        require(newConfig.maxWeight > newConfig.minStakeRequired, "QuadraticVoting: invalid max weight");
        
        quadraticConfig = newConfig;
        
        emit QuadraticConfigUpdated(
            newConfig.baseWeight,
            newConfig.scalingFactor,
            newConfig.maxWeight,
            newConfig.enabled
        );
    }
    
    /**
     * @dev Toggle quadratic voting on/off
     * @param enabled Whether to enable quadratic voting
     */
    function setQuadraticVotingEnabled(bool enabled) 
        external 
        onlyRole(CONFIG_MANAGER_ROLE) 
    {
        quadraticConfig.enabled = enabled;
        
        emit QuadraticConfigUpdated(
            quadraticConfig.baseWeight,
            quadraticConfig.scalingFactor,
            quadraticConfig.maxWeight,
            enabled
        );
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Calculate theoretical quadratic advantage
     * @param smallStake Smaller stake amount
     * @param largeStake Larger stake amount
     * @return The ratio of voting power advantage (scaled by 1e18)
     */
    function calculateVotingAdvantage(uint256 smallStake, uint256 largeStake) 
        external 
        view 
        returns (uint256) 
    {
        if (smallStake == 0 || largeStake <= smallStake) {
            return 1e18; // 1.0 ratio
        }
        
        (, uint256 smallWeight) = this.calculateVotingWeight(smallStake);
        (, uint256 largeWeight) = this.calculateVotingWeight(largeStake);
        
        // Linear advantage would be largeStake / smallStake
        uint256 linearAdvantage = (largeStake * 1e18) / smallStake;
        
        // Quadratic advantage is largeWeight / smallWeight
        uint256 quadraticAdvantage = (largeWeight * 1e18) / smallWeight;
        
        // Return reduction ratio (how much quadratic voting reduces whale advantage)
        return (quadraticAdvantage * 1e18) / linearAdvantage;
    }
    
    /**
     * @dev Get comprehensive voting statistics
     * @return Statistics about the quadratic voting system
     */
    function getVotingStatistics() 
        external 
        view 
        returns (
            uint256 totalVotersCount,
            uint256 totalVotesCount,
            uint256 averageWeight,
            bool quadraticEnabled
        ) 
    {
        totalVotersCount = totalVoters;
        totalVotesCount = totalVotesProcessed;
        averageWeight = totalVoters > 0 ? totalVotesProcessed / totalVoters : 0;
        quadraticEnabled = quadraticConfig.enabled;
    }
    
    /**
     * @dev Get voter participation history
     * @param voter The voter address
     * @return voteCount Number of votes cast
     * @return totalWeightUsed Total voting weight used
     */
    function getVoterStats(address voter) 
        external 
        view 
        returns (uint256 voteCount, uint256 totalWeightUsed) 
    {
        return (totalVotesCast[voter], totalWeight[voter]);
    }
    
    // ============ SIMULATION FUNCTIONS ============
    
    /**
     * @dev Simulate voting weight for testing purposes
     * @param stakedAmount Amount to simulate
     * @return The voting weights that would be calculated
     */
    function simulateVotingWeight(uint256 stakedAmount) 
        external 
        view 
        returns (uint256 linearWeight, uint256 quadraticWeight) 
    {
        if (stakedAmount < quadraticConfig.minStakeRequired) {
            return (0, 0);
        }
        
        return this.calculateVotingWeight(stakedAmount);
    }
    
    /**
     * @dev Batch simulate voting weights for multiple stakes
     * @param stakedAmounts Array of amounts to simulate
     * @return linearWeights Linear voting weights
     * @return quadraticWeights Quadratic voting weights
     */
    function simulateBatchVotingWeights(uint256[] memory stakedAmounts) 
        external 
        view 
        returns (uint256[] memory linearWeights, uint256[] memory quadraticWeights) 
    {
        linearWeights = new uint256[](stakedAmounts.length);
        quadraticWeights = new uint256[](stakedAmounts.length);
        
        for (uint256 i = 0; i < stakedAmounts.length; i++) {
            if (stakedAmounts[i] >= quadraticConfig.minStakeRequired) {
                (linearWeights[i], quadraticWeights[i]) = this.calculateVotingWeight(stakedAmounts[i]);
            }
        }
    }
} 