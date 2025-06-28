// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITreasury
 * @dev Interface for the Karma Labs Treasury contract
 * 
 * Stage 4.1 Requirements:
 * - Fund Collection and Storage with multisig controls
 * - Withdrawal and Distribution Engine with timelock
 * - Allocation Management with percentage enforcement
 * - Emergency mechanisms and historical tracking
 * 
 * Stage 4.2 Requirements:
 * - Token Distribution System (community rewards, airdrops, staking, engagement)
 * - External Contract Integration (Paymaster, BuybackBurn)
 * - Transparency and Governance (enhanced reporting, proposal funding)
 */
interface ITreasury {
    
    // ============ ENUMS ============
    
    enum AllocationCategory {
        MARKETING,  // 30%
        KOL,        // 20% 
        DEVELOPMENT, // 30%
        BUYBACK     // 20%
    }
    
    enum WithdrawalStatus {
        PENDING,
        APPROVED,
        EXECUTED,
        CANCELLED
    }
    
    enum ProposalType {
        WITHDRAWAL,
        ALLOCATION_CHANGE,
        EMERGENCY_WITHDRAWAL,
        BATCH_DISTRIBUTION,
        TOKEN_DISTRIBUTION,     // Stage 4.2
        EXTERNAL_FUNDING,       // Stage 4.2
        GOVERNANCE_PROPOSAL     // Stage 4.2
    }
    
    // Stage 4.2: Token Distribution Types
    enum TokenDistributionType {
        COMMUNITY_REWARDS,    // 200M allocation
        AIRDROP,             // 20M for early testers
        STAKING_REWARDS,     // 100M over 2 years
        ENGAGEMENT_INCENTIVE // 80M over 2 years
    }
    
    // Stage 4.2: External Contract Types
    enum ExternalContractType {
        PAYMASTER,
        BUYBACK_BURN,
        GOVERNANCE_DAO,
        STAKING_CONTRACT
    }
    
    // ============ STRUCTS ============
    
    struct AllocationConfig {
        uint256 marketingPercentage;    // Basis points (e.g., 3000 = 30%)
        uint256 kolPercentage;          // Basis points
        uint256 developmentPercentage;  // Basis points
        uint256 buybackPercentage;      // Basis points
        uint256 lastUpdated;
    }
    
    struct CategoryAllocation {
        uint256 totalAllocated;
        uint256 totalSpent;
        uint256 available;
        uint256 reserved;
        uint256 lastDistribution;
    }
    
    struct WithdrawalRequest {
        uint256 id;
        address proposer;
        address recipient;
        uint256 amount;
        AllocationCategory category;
        string description;
        uint256 timestamp;
        uint256 executionTime;
        WithdrawalStatus status;
        uint256 approvalCount;
        mapping(address => bool) hasApproved;
        bool isLargeWithdrawal; // >10% of balance
    }
    
    struct BatchDistribution {
        uint256 id;
        address[] recipients;
        uint256[] amounts;
        AllocationCategory category;
        string description;
        uint256 timestamp;
        bool executed;
        uint256 totalAmount;
    }
    
    struct HistoricalTransaction {
        uint256 timestamp;
        address recipient;
        uint256 amount;
        AllocationCategory category;
        string transactionType;
        uint256 balanceAfter;
    }
    
    struct TreasuryMetrics {
        uint256 totalReceived;
        uint256 totalDistributed;
        uint256 currentBalance;
        uint256 totalWithdrawals;
        uint256 totalAllocations;
        uint256 emergencyWithdrawals;
    }
    
    // ============ STAGE 4.2: TOKEN DISTRIBUTION STRUCTS ============
    
    struct TokenDistributionConfig {
        TokenDistributionType distributionType;
        uint256 totalAllocation;        // Total tokens allocated
        uint256 distributedAmount;      // Amount already distributed
        uint256 vestingDuration;        // Duration for vesting (if applicable)
        uint256 cliffPeriod;           // Cliff period before vesting starts
        bool isActive;                 // Whether distribution is active
        uint256 createdAt;             // Creation timestamp
    }
    
    struct AirdropDistribution {
        uint256 id;
        address[] recipients;
        uint256[] amounts;
        string description;
        uint256 timestamp;
        bool executed;
        uint256 totalTokens;
        bytes32 merkleRoot;            // For large airdrops
    }
    
    struct StakingRewardSchedule {
        uint256 totalRewards;          // Total KARMA allocated for staking rewards
        uint256 distributionPeriod;    // Duration over which to distribute (2 years)
        uint256 rewardsPerSecond;      // Tokens per second
        uint256 lastDistribution;      // Last distribution timestamp
        uint256 distributedAmount;     // Amount already distributed
    }
    
    struct EngagementIncentive {
        uint256 totalIncentive;        // Total KARMA for engagement (80M)
        uint256 distributionPeriod;    // Duration (2 years)
        uint256 baseRewardRate;        // Base tokens per engagement point
        uint256 bonusMultiplier;       // Multiplier for high engagement
        mapping(address => uint256) userEngagementPoints;
        mapping(address => uint256) lastClaim;
    }
    
    // ============ STAGE 4.2: EXTERNAL CONTRACT INTEGRATION STRUCTS ============
    
    struct ExternalContractConfig {
        address contractAddress;
        ExternalContractType contractType;
        uint256 fundingAmount;         // ETH amount allocated
        uint256 fundingFrequency;      // How often to fund (seconds)
        uint256 lastFunding;           // Last funding timestamp
        uint256 minimumBalance;        // Minimum balance to maintain
        bool autoFundingEnabled;       // Whether auto-funding is active
    }
    
    struct GovernanceProposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 requestedAmount;       // ETH requested
        AllocationCategory category;
        uint256 votingPeriod;
        uint256 createdAt;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
    }
    
    // ============ FUND COLLECTION AND STORAGE ============
    
    /**
     * @dev Receive ETH from SaleManager and other authorized sources
     */
    function receiveFromSaleManager() external payable;
    
    /**
     * @dev Receive ETH from external sources with categorization
     * @param category The allocation category for the funds
     * @param description Description of the fund source
     */
    function receiveETH(AllocationCategory category, string calldata description) external payable;
    
    /**
     * @dev Get current ETH balance
     */
    function getBalance() external view returns (uint256);
    
    /**
     * @dev Get allocation breakdown by category
     */
    function getAllocationBreakdown() external view returns (
        uint256 marketing,
        uint256 kol,
        uint256 development,
        uint256 buyback
    );
    
    /**
     * @dev Update allocation percentages (governance controlled)
     * @param newConfig New allocation configuration
     */
    function updateAllocationConfig(AllocationConfig calldata newConfig) external;
    
    // ============ WITHDRAWAL AND DISTRIBUTION ENGINE ============
    
    /**
     * @dev Propose a withdrawal (requires multisig approval)
     * @param recipient Address to receive funds
     * @param amount Amount to withdraw
     * @param category Allocation category
     * @param description Purpose of withdrawal
     * @return proposalId Unique identifier for the proposal
     */
    function proposeWithdrawal(
        address recipient,
        uint256 amount,
        AllocationCategory category,
        string calldata description
    ) external returns (uint256 proposalId);
    
    /**
     * @dev Approve a withdrawal proposal
     * @param proposalId ID of the proposal to approve
     */
    function approveWithdrawal(uint256 proposalId) external;
    
    /**
     * @dev Execute an approved withdrawal
     * @param proposalId ID of the proposal to execute
     */
    function executeWithdrawal(uint256 proposalId) external;
    
    /**
     * @dev Cancel a pending withdrawal proposal
     * @param proposalId ID of the proposal to cancel
     */
    function cancelWithdrawal(uint256 proposalId) external;
    
    /**
     * @dev Propose batch distribution for efficiency
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to distribute
     * @param category Allocation category
     * @param description Purpose of batch distribution
     * @return batchId Unique identifier for the batch
     */
    function proposeBatchDistribution(
        address[] calldata recipients,
        uint256[] calldata amounts,
        AllocationCategory category,
        string calldata description
    ) external returns (uint256 batchId);
    
    /**
     * @dev Execute approved batch distribution
     * @param batchId ID of the batch to execute
     */
    function executeBatchDistribution(uint256 batchId) external;
    
    // ============ EMERGENCY MECHANISMS ============
    
    /**
     * @dev Emergency withdrawal with reduced timelock (24 hours)
     * @param recipient Emergency recipient address
     * @param amount Amount to withdraw
     * @param reason Emergency reason
     */
    function emergencyWithdrawal(
        address recipient,
        uint256 amount,
        string calldata reason
    ) external;
    
    /**
     * @dev Pause all treasury operations
     */
    function pauseTreasury() external;
    
    /**
     * @dev Unpause treasury operations
     */
    function unpauseTreasury() external;
    
    /**
     * @dev Emergency fund recovery to admin
     */
    function emergencyRecovery() external;
    
    // ============ ALLOCATION MANAGEMENT ============
    
    /**
     * @dev Get category allocation details
     * @param category The allocation category
     */
    function getCategoryAllocation(AllocationCategory category) 
        external view returns (CategoryAllocation memory);
    
    /**
     * @dev Check if category has sufficient funds
     * @param category The allocation category
     * @param amount Amount to check
     */
    function hasSufficientFunds(AllocationCategory category, uint256 amount) 
        external view returns (bool);
    
    /**
     * @dev Get spending limit for category
     * @param category The allocation category
     */
    function getCategorySpendingLimit(AllocationCategory category) 
        external view returns (uint256);
    
    /**
     * @dev Reserve funds for future allocation
     * @param category The allocation category
     * @param amount Amount to reserve
     */
    function reserveFunds(AllocationCategory category, uint256 amount) external;
    
    /**
     * @dev Release reserved funds
     * @param category The allocation category
     * @param amount Amount to release
     */
    function releaseReservedFunds(AllocationCategory category, uint256 amount) external;
    
    /**
     * @dev Rebalance allocations across categories
     * @param fromCategory Source category
     * @param toCategory Destination category
     * @param amount Amount to rebalance
     */
    function rebalanceAllocations(
        AllocationCategory fromCategory,
        AllocationCategory toCategory,
        uint256 amount
    ) external;
    
    // ============ STAGE 4.2: TOKEN DISTRIBUTION SYSTEM ============
    
    /**
     * @dev Configure token distribution (200M community rewards, 20M airdrop, 100M staking, 80M engagement)
     * @param distributionType Type of distribution
     * @param totalAllocation Total tokens to allocate
     * @param vestingDuration Vesting duration if applicable
     * @param cliffPeriod Cliff period before vesting starts
     */
    function configureTokenDistribution(
        TokenDistributionType distributionType,
        uint256 totalAllocation,
        uint256 vestingDuration,
        uint256 cliffPeriod
    ) external;
    
    /**
     * @dev Distribute community rewards to recipients
     * @param recipients Array of recipient addresses
     * @param amounts Array of token amounts
     * @param description Purpose of distribution
     */
    function distributeCommunityRewards(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string calldata description
    ) external;
    
    /**
     * @dev Execute airdrop distribution (20M for early testers)
     * @param recipients Array of early tester addresses
     * @param amounts Array of token amounts
     * @param merkleRoot Merkle root for verification (optional)
     */
    function executeAirdrop(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes32 merkleRoot
    ) external returns (uint256 airdropId);
    
    /**
     * @dev Configure staking reward distribution (100M over 2 years)
     * @param totalRewards Total KARMA tokens for staking rewards
     * @param distributionPeriod Period over which to distribute rewards
     */
    function configureStakingRewards(
        uint256 totalRewards,
        uint256 distributionPeriod
    ) external;
    
    /**
     * @dev Distribute staking rewards to stakers
     * @param stakingContract Address of the staking contract
     * @param amount Amount of tokens to transfer for rewards
     */
    function distributeStakingRewards(
        address stakingContract,
        uint256 amount
    ) external;
    
    /**
     * @dev Configure engagement incentive distribution (80M over 2 years)
     * @param totalIncentive Total KARMA tokens for engagement incentives
     * @param distributionPeriod Distribution period
     * @param baseRewardRate Base reward rate per engagement point
     */
    function configureEngagementIncentives(
        uint256 totalIncentive,
        uint256 distributionPeriod,
        uint256 baseRewardRate
    ) external;
    
    /**
     * @dev Distribute engagement incentives based on user activity
     * @param users Array of user addresses
     * @param engagementPoints Array of engagement points
     */
    function distributeEngagementIncentives(
        address[] calldata users,
        uint256[] calldata engagementPoints
    ) external;
    
    /**
     * @dev Get token distribution configuration
     * @param distributionType Type of distribution to query
     */
    function getTokenDistributionConfig(TokenDistributionType distributionType)
        external view returns (TokenDistributionConfig memory);
    
    // ============ STAGE 4.2: EXTERNAL CONTRACT INTEGRATION ============
    
    /**
     * @dev Configure external contract for automatic funding
     * @param contractAddress Address of external contract
     * @param contractType Type of external contract
     * @param fundingAmount Initial ETH funding amount
     * @param fundingFrequency How often to fund (seconds)
     * @param minimumBalance Minimum balance to maintain
     */
    function configureExternalContract(
        address contractAddress,
        ExternalContractType contractType,
        uint256 fundingAmount,
        uint256 fundingFrequency,
        uint256 minimumBalance
    ) external;
    
    /**
     * @dev Fund Paymaster contract ($100K ETH initial allocation)
     * @param paymasterAddress Address of the Paymaster contract
     * @param amount Amount of ETH to transfer
     */
    function fundPaymaster(
        address paymasterAddress,
        uint256 amount
    ) external;
    
    /**
     * @dev Fund BuybackBurn contract (20% of treasury allocations)
     * @param buybackBurnAddress Address of the BuybackBurn contract
     * @param amount Amount of ETH to transfer
     */
    function fundBuybackBurn(
        address buybackBurnAddress,
        uint256 amount
    ) external;
    
    /**
     * @dev Check and trigger automatic funding for external contracts
     */
    function triggerAutomaticFunding() external;
    
    /**
     * @dev Monitor external contract balances and alert if below threshold
     * @param contractAddress Address to monitor
     * @return currentBalance Current balance of the contract
     * @return belowThreshold Whether balance is below minimum threshold
     */
    function monitorExternalBalance(address contractAddress) 
        external view returns (uint256 currentBalance, bool belowThreshold);
    
    /**
     * @dev Get external contract configuration
     * @param contractAddress Address of the external contract
     */
    function getExternalContractConfig(address contractAddress)
        external view returns (ExternalContractConfig memory);
    
    // ============ STAGE 4.2: TRANSPARENCY AND GOVERNANCE ============
    
    /**
     * @dev Create governance proposal for treasury funding
     * @param title Proposal title
     * @param description Proposal description
     * @param requestedAmount ETH amount requested
     * @param category Allocation category
     * @param votingPeriod Duration for voting
     * @return proposalId Unique proposal identifier
     */
    function createGovernanceProposal(
        string calldata title,
        string calldata description,
        uint256 requestedAmount,
        AllocationCategory category,
        uint256 votingPeriod
    ) external returns (uint256 proposalId);
    
    /**
     * @dev Execute approved governance proposal
     * @param proposalId ID of the proposal to execute
     */
    function executeGovernanceProposal(uint256 proposalId) external;
    
    /**
     * @dev Get comprehensive monthly treasury report
     * @param month Month number (1-12)
     * @param year Year
     */
    function getDetailedMonthlyReport(uint256 month, uint256 year)
        external view returns (
            uint256 totalReceived,
            uint256 totalDistributed,
            uint256 tokenDistributions,
            uint256 externalFunding,
            uint256 governanceProposals,
            uint256 emergencyWithdrawals,
            uint256[] memory categoryBreakdown
        );
    
    /**
     * @dev Get public fund tracking analytics
     */
    function getPublicAnalytics() external view returns (
        uint256 totalTreasuryValue,
        uint256 monthlyInflow,
        uint256 monthlyOutflow,
        uint256[] memory allocationPercentages,
        uint256 tokensDistributed,
        uint256 activeProposals
    );
    
    /**
     * @dev Export transaction history for transparency
     * @param fromTimestamp Start timestamp
     * @param toTimestamp End timestamp
     * @param transactionType Filter by transaction type
     * @return transactions Array of filtered transactions
     */
    function exportTransactionHistory(
        uint256 fromTimestamp,
        uint256 toTimestamp,
        string calldata transactionType
    ) external view returns (HistoricalTransaction[] memory transactions);
    
    /**
     * @dev Get real-time treasury dashboard data
     */
    function getTreasuryDashboard() external view returns (
        uint256 currentETHBalance,
        uint256 currentTokenBalance,
        uint256 pendingWithdrawals,
        uint256 activeDistributions,
        uint256 externalContractsCount,
        uint256 monthlyBurn,
        uint256[] memory allocationStatus
    );
    
    // ============ REPORTING AND ANALYTICS ============
    
    /**
     * @dev Get comprehensive treasury metrics
     */
    function getTreasuryMetrics() external view returns (TreasuryMetrics memory);
    
    /**
     * @dev Get historical transactions for a time period
     * @param fromTimestamp Start time
     * @param toTimestamp End time
     */
    function getHistoricalTransactions(uint256 fromTimestamp, uint256 toTimestamp) 
        external view returns (HistoricalTransaction[] memory);
    
    /**
     * @dev Get monthly treasury report
     * @param month Month number (1-12)
     * @param year Year
     */
    function getMonthlyReport(uint256 month, uint256 year) 
        external view returns (
            uint256 totalReceived,
            uint256 totalDistributed,
            uint256 categoryBreakdown,
            uint256 emergencyWithdrawals
        );
    
    /**
     * @dev Get withdrawal proposal details
     * @param proposalId ID of the proposal
     */
    function getWithdrawalProposal(uint256 proposalId) 
        external view returns (
            address proposer,
            address recipient,
            uint256 amount,
            AllocationCategory category,
            string memory description,
            WithdrawalStatus status,
            uint256 approvalCount,
            bool isLargeWithdrawal
        );
    
    /**
     * @dev Get batch distribution details
     * @param batchId ID of the batch
     */
    function getBatchDistribution(uint256 batchId) 
        external view returns (BatchDistribution memory);
    
    // ============ CONFIGURATION ============
    
    /**
     * @dev Set multisig threshold for approvals
     * @param threshold New threshold requirement
     */
    function setMultisigThreshold(uint256 threshold) external;
    
    /**
     * @dev Set timelock duration for large withdrawals
     * @param duration New duration in seconds
     */
    function setTimelockDuration(uint256 duration) external;
    
    /**
     * @dev Set large withdrawal threshold (percentage of balance)
     * @param thresholdBps Threshold in basis points
     */
    function setLargeWithdrawalThreshold(uint256 thresholdBps) external;
    
    /**
     * @dev Update authorized SaleManager address
     * @param newSaleManager New SaleManager address
     */
    function updateSaleManager(address newSaleManager) external;
    
    /**
     * @dev Set KarmaToken contract address for token distributions
     * @param tokenAddress Address of the KarmaToken contract
     */
    function setKarmaToken(address tokenAddress) external;
    
    // ============ EVENTS ============
    
    // Stage 4.1 Events
    event FundsReceived(address indexed from, uint256 amount, AllocationCategory category);
    event WithdrawalProposed(uint256 indexed proposalId, address indexed proposer, uint256 amount);
    event WithdrawalApproved(uint256 indexed proposalId, address indexed approver);
    event WithdrawalExecuted(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event WithdrawalCancelled(uint256 indexed proposalId, address indexed canceller);
    event BatchDistributionProposed(uint256 indexed batchId, uint256 totalAmount);
    event BatchDistributionExecuted(uint256 indexed batchId, uint256 totalAmount);
    event EmergencyWithdrawal(address indexed recipient, uint256 amount, string reason);
    event AllocationConfigUpdated(AllocationConfig newConfig);
    event FundsRebalanced(AllocationCategory fromCategory, AllocationCategory toCategory, uint256 amount);
    event FundsReserved(AllocationCategory category, uint256 amount);
    event ReservedFundsReleased(AllocationCategory category, uint256 amount);
    event TreasuryPaused(address indexed pauser);
    event TreasuryUnpaused(address indexed unpauser);
    event MultisigThresholdUpdated(uint256 newThreshold);
    event TimelockDurationUpdated(uint256 newDuration);
    event LargeWithdrawalThresholdUpdated(uint256 newThresholdBps);
    event SaleManagerUpdated(address indexed oldSaleManager, address indexed newSaleManager);
    
    // ============ STAGE 4.2 EVENTS ============
    
    // Token Distribution Events
    event TokenDistributionConfigured(TokenDistributionType distributionType, uint256 totalAllocation);
    event CommunityRewardsDistributed(address[] recipients, uint256[] amounts, uint256 totalDistributed);
    event AirdropExecuted(uint256 indexed airdropId, address[] recipients, uint256 totalTokens);
    event StakingRewardsConfigured(uint256 totalRewards, uint256 distributionPeriod);
    event StakingRewardsDistributed(address indexed stakingContract, uint256 amount);
    event EngagementIncentivesConfigured(uint256 totalIncentive, uint256 distributionPeriod);
    event EngagementIncentivesDistributed(address[] users, uint256[] amounts, uint256 totalDistributed);
    
    // External Contract Integration Events
    event ExternalContractConfigured(address indexed contractAddress, ExternalContractType contractType);
    event PaymasterFunded(address indexed paymasterAddress, uint256 amount);
    event BuybackBurnFunded(address indexed buybackBurnAddress, uint256 amount);
    event AutomaticFundingTriggered(address indexed contractAddress, uint256 amount);
    event ExternalBalanceAlert(address indexed contractAddress, uint256 currentBalance, uint256 threshold);
    
    // Governance and Transparency Events
    event GovernanceProposalCreated(uint256 indexed proposalId, address indexed proposer, uint256 requestedAmount);
    event GovernanceProposalExecuted(uint256 indexed proposalId, uint256 amount);
    event MonthlyReportGenerated(uint256 month, uint256 year, uint256 totalActivity);
    event TransactionHistoryExported(uint256 fromTimestamp, uint256 toTimestamp, uint256 transactionCount);
    event KarmaTokenSet(address indexed oldToken, address indexed newToken);
} 