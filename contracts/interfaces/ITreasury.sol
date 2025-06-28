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
        BATCH_DISTRIBUTION
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
    
    // ============ EVENTS ============
    
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
} 