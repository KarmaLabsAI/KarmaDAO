// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IKarmaDAO
 * @dev Interface for the Karma Labs DAO governance system
 * @notice Defines the core governance functions, quadratic voting, and proposal management
 */
interface IKarmaDAO {
    // ============ EVENTS ============
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalCategory indexed category,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 weight,
        uint256 quadraticWeight,
        string reason
    );
    
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    
    event GovernanceConfigUpdated(
        uint256 proposalThreshold,
        uint256 quorumPercentage,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 executionDelay,
        bool quadraticVotingEnabled
    );
    
    event StakingContractUpdated(address indexed oldContract, address indexed newContract);
    event EmergencyPause(address indexed admin, string reason);
    event EmergencyUnpause(address indexed admin);
    
    // ============ ENUMS ============
    
    enum ProposalCategory {
        TREASURY,           // Treasury fund allocation
        PROTOCOL,           // Protocol parameter changes
        EMERGENCY,          // Emergency actions
        UPGRADE             // Contract upgrades
    }
    
    enum ProposalState {
        PENDING,
        ACTIVE,
        CANCELED,
        DEFEATED,
        SUCCEEDED,
        QUEUED,
        EXPIRED,
        EXECUTED
    }
    
    // ============ STRUCTS ============
    
    struct GovernanceConfig {
        uint256 proposalThreshold;      // Minimum tokens to create proposal (1M KARMA)
        uint256 quorumPercentage;       // Minimum participation (5%)
        uint256 votingDelay;            // Delay before voting starts (1 day)
        uint256 votingPeriod;           // Voting duration (7 days)
        uint256 executionDelay;         // Delay before execution (3 days)
        uint256 maxActions;             // Maximum actions per proposal (10)
        bool quadraticVotingEnabled;    // Enable quadratic voting
    }
    
    struct ProposalDetails {
        uint256 id;
        address proposer;
        ProposalCategory category;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
    }
    
    struct GovernanceAnalytics {
        uint256 totalProposals;
        uint256 activeProposals;
        uint256 executedProposals;
        uint256 totalVoters;
        uint256 totalVotesCast;
        uint256 averageParticipation;
        uint256 treasuryProposals;
        uint256 protocolProposals;
    }
    
    // ============ CORE GOVERNANCE FUNCTIONS ============
    
    /**
     * @dev Propose a new governance action
     * @param targets Array of target contract addresses
     * @param values Array of ETH values to send
     * @param calldatas Array of function calls to execute
     * @param description Proposal description
     * @param category Proposal category
     * @return proposalId The ID of the created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalCategory category
    ) external returns (uint256 proposalId);
    
    /**
     * @dev Cast a vote on a proposal with quadratic weighting
     * @param proposalId The proposal to vote on
     * @param support Vote direction (0=against, 1=for, 2=abstain)
     * @param reason Optional reason for the vote
     * @return weight The voting weight applied
     */
    function castVote(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 weight);
    
    /**
     * @dev Execute a proposal that has passed
     * @param proposalId The proposal to execute
     */
    function execute(uint256 proposalId) external payable;
    
    /**
     * @dev Cancel a proposal (only by proposer or admin)
     * @param proposalId The proposal to cancel
     */
    function cancel(uint256 proposalId) external;
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get proposal state
     * @param proposalId The proposal ID
     * @return Current state of the proposal
     */
    function state(uint256 proposalId) external view returns (ProposalState);
    
    /**
     * @dev Get proposal details
     * @param proposalId The proposal ID
     * @return Detailed proposal information
     */
    function getProposal(uint256 proposalId) external view returns (ProposalDetails memory);
    
    /**
     * @dev Get voting power for an address at a specific block
     * @param account The address to check
     * @param blockNumber The block number to check at
     * @return The voting power
     */
    function getVotes(address account, uint256 blockNumber) external view returns (uint256);
    
    /**
     * @dev Calculate quadratic voting weight
     * @param stakedAmount The amount of tokens staked
     * @return The quadratic voting weight
     */
    function calculateQuadraticWeight(uint256 stakedAmount) external pure returns (uint256);
    
    /**
     * @dev Get governance configuration
     * @return Current governance configuration
     */
    function getGovernanceConfig() external view returns (GovernanceConfig memory);
    
    /**
     * @dev Get governance analytics
     * @return Analytics data for the governance system
     */
    function getGovernanceAnalytics() external view returns (GovernanceAnalytics memory);
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Update governance configuration
     * @param newConfig New configuration parameters
     */
    function updateGovernanceConfig(GovernanceConfig memory newConfig) external;
    
    /**
     * @dev Set staking contract for voting power
     * @param stakingContract Address of the staking contract
     */
    function setStakingContract(address stakingContract) external;
    
    /**
     * @dev Emergency pause governance operations
     * @param reason Reason for the pause
     */
    function emergencyPause(string calldata reason) external;
    
    /**
     * @dev Emergency unpause governance operations
     */
    function emergencyUnpause() external;
} 