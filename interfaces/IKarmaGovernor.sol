// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKarmaGovernor
 * @dev Simplified interface for the Karma Labs DAO governance system
 * 
 * Stage 7.1 Requirements:
 * - OpenZeppelin Governor framework with customizations
 * - Proposal lifecycle management (creation, voting, execution)
 * - Proposal categorization system (Treasury, Protocol, Emergency)
 * - Voting period configuration and enforcement (7-day standard)
 * - Quadratic voting implementation with staked token amounts
 * - Vote delegation mechanisms for representative governance
 * - Timelock controller integration (3-day execution delay)
 * - Participation requirements (0.1% stake threshold = 1M $KARMA)
 * - Reputation and participation tracking systems
 * - Anti-spam mechanisms and proposal quality controls
 */
interface IKarmaGovernor {
    
    // ============ ENUMS ============
    
    enum ProposalCategory {
        TREASURY,     // Treasury fund allocations and spending
        PROTOCOL,     // Smart contract upgrades and parameter changes
        EMERGENCY,    // Emergency protocol changes
        GOVERNANCE    // Governance system modifications
    }
    
    // ============ STRUCTS ============
    
    struct GovernanceConfig {
        uint256 votingDelay;          // Delay before voting starts (1 day)
        uint256 votingPeriod;         // Length of voting period (7 days) 
        uint256 proposalThreshold;    // Min tokens to create proposal (1M KARMA)
        uint256 quorumNumerator;      // Quorum percentage (4% of total staked)
        uint256 timelockDelay;        // Execution delay (3 days)
        uint256 maxActions;           // Max actions per proposal (10)
        bool quadraticVotingEnabled;  // Whether quadratic voting is active
        uint256 gracePeriod;          // Grace period for execution (14 days)
    }
    
    struct DelegationInfo {
        address delegate;          // Current delegate
        uint256 delegatedVotes;    // Votes delegated to this address
        uint256 lastDelegation;    // Timestamp of last delegation change
        address[] delegators;      // Addresses delegating to this delegate
    }
    
    struct ParticipationMetrics {
        uint256 proposalsCreated;
        uint256 proposalsVoted;
        uint256 totalVoteWeight;
        uint256 lastActivity;
        uint256 reputationScore;
        bool isActive;
    }
    
    struct QuadraticVotingCalculation {
        uint256 stakedAmount;      // Amount of tokens staked
        uint256 linearVotes;       // One token = one vote
        uint256 quadraticVotes;    // sqrt(staked amount) for quadratic component
        uint256 finalVotingPower;  // Combined voting power
        uint256 maxVotingPower;    // Cap to prevent whale dominance
    }
    
    struct GovernanceAnalytics {
        uint256 totalProposals;
        uint256 activeProposals;
        uint256 totalParticipants;
        uint256 averageParticipation;
        uint256 totalVotingPower;
    }
    
    // ============ EVENTS ============
    
    event ProposalCreatedWithCategory(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalCategory indexed category,
        string description
    );
    
    event QuadraticVoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight,
        uint256 quadraticWeight,
        string reason
    );
    
    event GovernanceConfigUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumNumerator
    );
    
    event ParticipationUpdated(
        address indexed account,
        uint256 proposalsCreated,
        uint256 proposalsVoted,
        uint256 reputationScore
    );
    
    event EmergencyActionTriggered(
        uint256 indexed proposalId,
        address indexed actor,
        string reason
    );
    
    // ============ GOVERNANCE FUNCTIONS ============
    
    /**
     * @dev Propose a new governance action with categorization
     */
    function proposeWithCategory(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description,
        ProposalCategory category
    ) external returns (uint256 proposalId);
    
    /**
     * @dev Cast vote with quadratic calculation
     */
    function castQuadraticVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) external returns (uint256 balance);
    
    /**
     * @dev Get quadratic voting power for an account
     */
    function getQuadraticVotingPower(address account, uint256 blockNumber)
        external view returns (uint256);
    
    /**
     * @dev Get governance configuration
     */
    function getGovernanceConfig() external view returns (GovernanceConfig memory);
    
    /**
     * @dev Get delegation information
     */
    function getDelegationInfo(address account) external view returns (DelegationInfo memory);
    
    /**
     * @dev Get participation metrics
     */
    function getParticipationMetrics(address account) external view returns (ParticipationMetrics memory);
    
    /**
     * @dev Get governance analytics
     */
    function getGovernanceAnalytics() external view returns (GovernanceAnalytics memory);
    
    /**
     * @dev Update governance configuration
     */
    function updateGovernanceConfig(GovernanceConfig memory newConfig) external;
    
    /**
     * @dev Emergency functions
     */
    function emergencyPause() external;
    function emergencyUnpause() external;
    function emergencyCancel(uint256 proposalId, string memory reason) external;
} 