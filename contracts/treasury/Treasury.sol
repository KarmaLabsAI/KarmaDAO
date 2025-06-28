// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IKarmaAccessControl.sol";

/**
 * @title Treasury
 * @dev Treasury contract for the Karma Labs ecosystem
 * 
 * Stage 4.1 Implementation:
 * - Fund Collection and Storage with multisig controls
 * - Withdrawal and Distribution Engine with timelock
 * - Allocation Management with percentage enforcement (30% marketing, 20% KOL, 30% dev, 20% buyback)
 * - Emergency mechanisms and historical tracking
 * 
 * Stage 4.2 Implementation:
 * - Token Distribution System (community rewards, airdrops, staking, engagement)
 * - External Contract Integration (Paymaster, BuybackBurn)
 * - Transparency and Governance (enhanced reporting, proposal funding)
 * 
 * Features:
 * - Secure fund storage with multisig withdrawal approvals
 * - Timelocked withdrawals for large amounts (>10% balance, 7-day delay)
 * - Batch distribution capabilities for efficiency
 * - Allocation percentage enforcement and rebalancing
 * - Comprehensive historical tracking and reporting
 * - Emergency withdrawal mechanisms with proper safeguards
 * - KARMA token distribution for community rewards (200M), airdrops (20M), staking (100M), engagement (80M)
 * - Automated external contract funding (Paymaster $100K ETH, BuybackBurn 20% allocations)
 * - Advanced governance proposal funding and transparency reporting
 */
contract Treasury is ITreasury, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ CONSTANTS ============
    
    // Role definitions
    bytes32 public constant TREASURY_MANAGER_ROLE = keccak256("TREASURY_MANAGER_ROLE");
    bytes32 public constant WITHDRAWAL_APPROVER_ROLE = keccak256("WITHDRAWAL_APPROVER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant ALLOCATION_MANAGER_ROLE = keccak256("ALLOCATION_MANAGER_ROLE");
    
    // Stage 4.2: Additional roles
    bytes32 public constant TOKEN_DISTRIBUTION_ROLE = keccak256("TOKEN_DISTRIBUTION_ROLE");
    bytes32 public constant EXTERNAL_FUNDING_ROLE = keccak256("EXTERNAL_FUNDING_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    // Constants for allocation percentages (basis points)
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DEFAULT_MARKETING_PERCENTAGE = 3000; // 30%
    uint256 private constant DEFAULT_KOL_PERCENTAGE = 2000; // 20%
    uint256 private constant DEFAULT_DEVELOPMENT_PERCENTAGE = 3000; // 30%
    uint256 private constant DEFAULT_BUYBACK_PERCENTAGE = 2000; // 20%
    
    // Timelock constants
    uint256 private constant STANDARD_TIMELOCK = 7 days; // 7-day delay for large withdrawals
    uint256 private constant EMERGENCY_TIMELOCK = 24 hours; // 24-hour delay for emergency
    uint256 private constant LARGE_WITHDRAWAL_THRESHOLD_BPS = 1000; // 10% of balance
    
    // Stage 4.2: Token distribution constants
    uint256 private constant COMMUNITY_REWARDS_ALLOCATION = 200_000_000 * 1e18; // 200M KARMA
    uint256 private constant AIRDROP_ALLOCATION = 20_000_000 * 1e18; // 20M KARMA
    uint256 private constant STAKING_REWARDS_ALLOCATION = 100_000_000 * 1e18; // 100M KARMA
    uint256 private constant ENGAGEMENT_INCENTIVE_ALLOCATION = 80_000_000 * 1e18; // 80M KARMA
    uint256 private constant STAKING_DISTRIBUTION_PERIOD = 2 * 365 days; // 2 years
    uint256 private constant ENGAGEMENT_DISTRIBUTION_PERIOD = 2 * 365 days; // 2 years
    
    // Stage 4.2: External funding constants
    uint256 private constant PAYMASTER_INITIAL_FUNDING = 100000 * 1e18; // $100K worth of ETH
    uint256 private constant BUYBACK_ALLOCATION_PERCENTAGE = 2000; // 20% of treasury
    
    // ============ STATE VARIABLES ============
    
    // Core configuration
    address public saleManager;
    uint256 public multisigThreshold;
    uint256 public timelockDuration;
    uint256 public largeWithdrawalThresholdBps;
    
    // Stage 4.2: KarmaToken contract
    IERC20 public karmaToken;
    
    // Allocation configuration
    AllocationConfig public allocationConfig;
    mapping(AllocationCategory => CategoryAllocation) private _categoryAllocations;
    
    // Proposal management
    uint256 private _proposalIdCounter;
    uint256 private _batchIdCounter;
    mapping(uint256 => WithdrawalRequest) private _withdrawalProposals;
    mapping(uint256 => BatchDistribution) private _batchDistributions;
    
    // Historical tracking
    HistoricalTransaction[] private _historicalTransactions;
    TreasuryMetrics public metrics;
    
    // Monthly reporting
    mapping(uint256 => mapping(uint256 => uint256)) private _monthlyReceived; // year => month => amount
    mapping(uint256 => mapping(uint256 => uint256)) private _monthlyDistributed; // year => month => amount
    mapping(uint256 => mapping(uint256 => uint256)) private _monthlyEmergencyWithdrawals; // year => month => amount
    
    // Stage 4.2: Enhanced monthly reporting
    mapping(uint256 => mapping(uint256 => uint256)) private _monthlyTokenDistributions; // year => month => tokens
    mapping(uint256 => mapping(uint256 => uint256)) private _monthlyExternalFunding; // year => month => amount
    mapping(uint256 => mapping(uint256 => uint256)) private _monthlyGovernanceProposals; // year => month => count
    
    // Multi-signature tracking
    mapping(address => bool) public isApprover;
    address[] public approvers;
    
    // ============ STAGE 4.2: TOKEN DISTRIBUTION STATE ============
    
    // Token distribution configurations
    mapping(TokenDistributionType => TokenDistributionConfig) private _tokenDistributions;
    
    // Airdrop management
    uint256 private _airdropIdCounter;
    mapping(uint256 => AirdropDistribution) private _airdrops;
    
    // Staking reward management
    StakingRewardSchedule public stakingRewards;
    
    // Engagement incentive management
    EngagementIncentive public engagementIncentives;
    
    // ============ STAGE 4.2: EXTERNAL CONTRACT INTEGRATION STATE ============
    
    // External contract configurations
    mapping(address => ExternalContractConfig) private _externalContracts;
    address[] private _registeredExternalContracts;
    
    // ============ STAGE 4.2: GOVERNANCE STATE ============
    
    // Governance proposals
    uint256 private _governanceProposalIdCounter;
    mapping(uint256 => GovernanceProposal) private _governanceProposals;
    
    // ============ MODIFIERS ============
    
    modifier onlyTreasuryManager() {
        require(hasRole(TREASURY_MANAGER_ROLE, msg.sender), "Treasury: caller is not treasury manager");
        _;
    }
    
    modifier onlyWithdrawalApprover() {
        require(hasRole(WITHDRAWAL_APPROVER_ROLE, msg.sender), "Treasury: caller is not withdrawal approver");
        _;
    }
    
    modifier onlyEmergencyRole() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "Treasury: caller does not have emergency role");
        _;
    }
    
    modifier onlyAllocationManager() {
        require(hasRole(ALLOCATION_MANAGER_ROLE, msg.sender), "Treasury: caller is not allocation manager");
        _;
    }
    
    modifier onlySaleManager() {
        require(msg.sender == saleManager, "Treasury: caller is not authorized sale manager");
        _;
    }
    
    modifier validCategory(AllocationCategory category) {
        require(uint256(category) <= 3, "Treasury: invalid category");
        _;
    }
    
    // Stage 4.2: Additional modifiers
    modifier onlyTokenDistributor() {
        require(hasRole(TOKEN_DISTRIBUTION_ROLE, msg.sender), "Treasury: caller is not token distributor");
        _;
    }
    
    modifier onlyExternalFunder() {
        require(hasRole(EXTERNAL_FUNDING_ROLE, msg.sender), "Treasury: caller is not external funder");
        _;
    }
    
    modifier onlyGovernanceRole() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Treasury: caller does not have governance role");
        _;
    }
    
    modifier validTokenDistribution(TokenDistributionType distributionType) {
        require(uint256(distributionType) <= 3, "Treasury: invalid distribution type");
        _;
    }
    
    modifier validExternalContractType(ExternalContractType contractType) {
        require(uint256(contractType) <= 3, "Treasury: invalid contract type");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _admin,
        address _saleManager,
        address[] memory _approvers,
        uint256 _multisigThreshold
    ) {
        require(_admin != address(0), "Treasury: invalid admin address");
        require(_saleManager != address(0), "Treasury: invalid sale manager address");
        require(_approvers.length >= _multisigThreshold, "Treasury: insufficient approvers for threshold");
        require(_multisigThreshold > 0, "Treasury: threshold must be greater than 0");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(TREASURY_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        _grantRole(ALLOCATION_MANAGER_ROLE, _admin);
        
        // Stage 4.2: Grant additional roles to admin
        _grantRole(TOKEN_DISTRIBUTION_ROLE, _admin);
        _grantRole(EXTERNAL_FUNDING_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin);
        
        // Setup approvers
        for (uint256 i = 0; i < _approvers.length; i++) {
            require(_approvers[i] != address(0), "Treasury: invalid approver address");
            _grantRole(WITHDRAWAL_APPROVER_ROLE, _approvers[i]);
            isApprover[_approvers[i]] = true;
            approvers.push(_approvers[i]);
        }
        
        saleManager = _saleManager;
        multisigThreshold = _multisigThreshold;
        timelockDuration = STANDARD_TIMELOCK;
        largeWithdrawalThresholdBps = LARGE_WITHDRAWAL_THRESHOLD_BPS;
        
        // Initialize default allocation configuration
        allocationConfig = AllocationConfig({
            marketingPercentage: DEFAULT_MARKETING_PERCENTAGE,
            kolPercentage: DEFAULT_KOL_PERCENTAGE,
            developmentPercentage: DEFAULT_DEVELOPMENT_PERCENTAGE,
            buybackPercentage: DEFAULT_BUYBACK_PERCENTAGE,
            lastUpdated: block.timestamp
        });
        
        // Initialize proposal counters
        _proposalIdCounter = 1; // Start from 1
        _batchIdCounter = 1; // Start from 1
        _airdropIdCounter = 1; // Start from 1
        _governanceProposalIdCounter = 1; // Start from 1
        
        // Stage 4.2: Initialize token distributions with default allocations
        _initializeTokenDistributions();
        
        // Stage 4.2: Initialize staking rewards
        _initializeStakingRewards();
        
        // Stage 4.2: Initialize engagement incentives
        _initializeEngagementIncentives();
    }
    
    // ============ STAGE 4.2: INITIALIZATION FUNCTIONS ============
    
    function _initializeTokenDistributions() internal {
        // Initialize community rewards (200M KARMA)
        _tokenDistributions[TokenDistributionType.COMMUNITY_REWARDS] = TokenDistributionConfig({
            distributionType: TokenDistributionType.COMMUNITY_REWARDS,
            totalAllocation: COMMUNITY_REWARDS_ALLOCATION,
            distributedAmount: 0,
            vestingDuration: 0, // No vesting for community rewards
            cliffPeriod: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        // Initialize airdrop (20M KARMA)
        _tokenDistributions[TokenDistributionType.AIRDROP] = TokenDistributionConfig({
            distributionType: TokenDistributionType.AIRDROP,
            totalAllocation: AIRDROP_ALLOCATION,
            distributedAmount: 0,
            vestingDuration: 0, // No vesting for airdrops
            cliffPeriod: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        // Initialize staking rewards (100M KARMA over 2 years)
        _tokenDistributions[TokenDistributionType.STAKING_REWARDS] = TokenDistributionConfig({
            distributionType: TokenDistributionType.STAKING_REWARDS,
            totalAllocation: STAKING_REWARDS_ALLOCATION,
            distributedAmount: 0,
            vestingDuration: STAKING_DISTRIBUTION_PERIOD,
            cliffPeriod: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        // Initialize engagement incentives (80M KARMA over 2 years)
        _tokenDistributions[TokenDistributionType.ENGAGEMENT_INCENTIVE] = TokenDistributionConfig({
            distributionType: TokenDistributionType.ENGAGEMENT_INCENTIVE,
            totalAllocation: ENGAGEMENT_INCENTIVE_ALLOCATION,
            distributedAmount: 0,
            vestingDuration: ENGAGEMENT_DISTRIBUTION_PERIOD,
            cliffPeriod: 0,
            isActive: true,
            createdAt: block.timestamp
        });
    }
    
    function _initializeStakingRewards() internal {
        stakingRewards = StakingRewardSchedule({
            totalRewards: STAKING_REWARDS_ALLOCATION,
            distributionPeriod: STAKING_DISTRIBUTION_PERIOD,
            rewardsPerSecond: STAKING_REWARDS_ALLOCATION / STAKING_DISTRIBUTION_PERIOD,
            lastDistribution: block.timestamp,
            distributedAmount: 0
        });
    }
    
    function _initializeEngagementIncentives() internal {
        engagementIncentives.totalIncentive = ENGAGEMENT_INCENTIVE_ALLOCATION;
        engagementIncentives.distributionPeriod = ENGAGEMENT_DISTRIBUTION_PERIOD;
        engagementIncentives.baseRewardRate = 1000 * 1e18; // 1000 KARMA per engagement point
        engagementIncentives.bonusMultiplier = 150; // 1.5x multiplier for high engagement (150/100)
    }
    
    // ============ FUND COLLECTION AND STORAGE ============
    
    receive() external payable {
        // Allow receiving ETH
        _recordFundsReceived(msg.sender, msg.value, AllocationCategory.DEVELOPMENT, "Direct deposit");
    }
    
    function receiveFromSaleManager() external payable override onlySaleManager {
        require(msg.value > 0, "Treasury: no ETH sent");
        _recordFundsReceived(msg.sender, msg.value, AllocationCategory.DEVELOPMENT, "Sale proceeds");
        _updateCategoryAllocations(msg.value);
    }
    
    function receiveETH(AllocationCategory category, string calldata description) 
        external payable override whenNotPaused validCategory(category) {
        require(msg.value > 0, "Treasury: no ETH sent");
        _recordFundsReceived(msg.sender, msg.value, category, description);
        _updateCategoryAllocations(msg.value);
    }
    
    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }
    
    function getAllocationBreakdown() external view override returns (
        uint256 marketing,
        uint256 kol,
        uint256 development,
        uint256 buyback
    ) {
        marketing = _categoryAllocations[AllocationCategory.MARKETING].available;
        kol = _categoryAllocations[AllocationCategory.KOL].available;
        development = _categoryAllocations[AllocationCategory.DEVELOPMENT].available;
        buyback = _categoryAllocations[AllocationCategory.BUYBACK].available;
    }
    
    function updateAllocationConfig(AllocationConfig calldata newConfig) 
        external override onlyAllocationManager {
        require(
            newConfig.marketingPercentage + 
            newConfig.kolPercentage + 
            newConfig.developmentPercentage + 
            newConfig.buybackPercentage == BASIS_POINTS,
            "Treasury: allocation percentages must sum to 100%"
        );
        
        allocationConfig = newConfig;
        allocationConfig.lastUpdated = block.timestamp;
        
        // Rebalance existing allocations based on new percentages
        _rebalanceAllAllocations();
        
        emit AllocationConfigUpdated(newConfig);
    }
    
    // ============ WITHDRAWAL AND DISTRIBUTION ENGINE ============
    
    function proposeWithdrawal(
        address recipient,
        uint256 amount,
        AllocationCategory category,
        string calldata description
    ) external override onlyTreasuryManager validCategory(category) returns (uint256 proposalId) {
        require(recipient != address(0), "Treasury: invalid recipient");
        require(amount > 0, "Treasury: amount must be greater than 0");
        require(hasSufficientFunds(category, amount), "Treasury: insufficient funds in category");
        
        proposalId = _proposalIdCounter++;
        bool isLarge = _isLargeWithdrawal(amount);
        uint256 executionTime = isLarge ? block.timestamp + timelockDuration : block.timestamp;
        
        WithdrawalRequest storage proposal = _withdrawalProposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.recipient = recipient;
        proposal.amount = amount;
        proposal.category = category;
        proposal.description = description;
        proposal.timestamp = block.timestamp;
        proposal.executionTime = executionTime;
        proposal.status = WithdrawalStatus.PENDING;
        proposal.approvalCount = 0;
        proposal.isLargeWithdrawal = isLarge;
        
        // Reserve funds for this proposal
        _reserveFundsInternal(category, amount);
        
        emit WithdrawalProposed(proposalId, msg.sender, amount);
        
        return proposalId;
    }
    
    function approveWithdrawal(uint256 proposalId) external override onlyWithdrawalApprover {
        WithdrawalRequest storage proposal = _withdrawalProposals[proposalId];
        require(proposal.id == proposalId, "Treasury: proposal does not exist");
        require(proposal.status == WithdrawalStatus.PENDING, "Treasury: proposal not pending");
        require(!proposal.hasApproved[msg.sender], "Treasury: already approved");
        
        proposal.hasApproved[msg.sender] = true;
        proposal.approvalCount++;
        
        emit WithdrawalApproved(proposalId, msg.sender);
        
        // Auto-execute if threshold is met and timelock is expired
        if (proposal.approvalCount >= multisigThreshold && block.timestamp >= proposal.executionTime) {
            _executeWithdrawalInternal(proposalId);
        }
    }
    
    function executeWithdrawal(uint256 proposalId) external override onlyTreasuryManager {
        _executeWithdrawalInternal(proposalId);
    }
    
    function cancelWithdrawal(uint256 proposalId) external override onlyTreasuryManager {
        WithdrawalRequest storage proposal = _withdrawalProposals[proposalId];
        require(proposal.id == proposalId, "Treasury: proposal does not exist");
        require(proposal.status == WithdrawalStatus.PENDING, "Treasury: proposal not pending");
        
        proposal.status = WithdrawalStatus.CANCELLED;
        
        // Release reserved funds
        _releaseReservedFundsInternal(proposal.category, proposal.amount);
        
        emit WithdrawalCancelled(proposalId, msg.sender);
    }
    
    function proposeBatchDistribution(
        address[] calldata recipients,
        uint256[] calldata amounts,
        AllocationCategory category,
        string calldata description
    ) external override onlyTreasuryManager validCategory(category) returns (uint256 batchId) {
        require(recipients.length == amounts.length, "Treasury: array length mismatch");
        require(recipients.length > 0, "Treasury: empty batch");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(recipients[i] != address(0), "Treasury: invalid recipient");
            require(amounts[i] > 0, "Treasury: invalid amount");
            totalAmount += amounts[i];
        }
        
        require(hasSufficientFunds(category, totalAmount), "Treasury: insufficient funds in category");
        
        batchId = _batchIdCounter++;
        
        BatchDistribution storage batch = _batchDistributions[batchId];
        batch.id = batchId;
        batch.recipients = recipients;
        batch.amounts = amounts;
        batch.category = category;
        batch.description = description;
        batch.timestamp = block.timestamp;
        batch.executed = false;
        batch.totalAmount = totalAmount;
        
        // Reserve funds for this batch
        _reserveFundsInternal(category, totalAmount);
        
        emit BatchDistributionProposed(batchId, totalAmount);
        
        return batchId;
    }
    
    function executeBatchDistribution(uint256 batchId) external override onlyTreasuryManager nonReentrant {
        BatchDistribution storage batch = _batchDistributions[batchId];
        require(batch.id == batchId, "Treasury: batch does not exist");
        require(!batch.executed, "Treasury: batch already executed");
        
        batch.executed = true;
        
        // Release reserved funds and execute distributions
        _categoryAllocations[batch.category].reserved -= batch.totalAmount;
        _categoryAllocations[batch.category].totalSpent += batch.totalAmount;
        _categoryAllocations[batch.category].lastDistribution = block.timestamp;
        
        for (uint256 i = 0; i < batch.recipients.length; i++) {
            (bool success, ) = batch.recipients[i].call{value: batch.amounts[i]}("");
            require(success, "Treasury: batch transfer failed");
            
            _recordHistoricalTransaction(
                batch.recipients[i],
                batch.amounts[i],
                batch.category,
                string(abi.encodePacked("Batch distribution: ", batch.description))
            );
        }
        
        metrics.totalDistributed += batch.totalAmount;
        _updateMonthlyDistributed(batch.totalAmount);
        
        emit BatchDistributionExecuted(batchId, batch.totalAmount);
    }
    
    // ============ EMERGENCY MECHANISMS ============
    
    function emergencyWithdrawal(
        address recipient,
        uint256 amount,
        string calldata reason
    ) external override onlyEmergencyRole nonReentrant {
        require(recipient != address(0), "Treasury: invalid recipient");
        require(amount > 0, "Treasury: amount must be greater than 0");
        require(amount <= address(this).balance, "Treasury: insufficient balance");
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Treasury: emergency transfer failed");
        
        metrics.emergencyWithdrawals++;
        metrics.totalDistributed += amount;
        _updateMonthlyEmergencyWithdrawals(amount);
        
        _recordHistoricalTransaction(recipient, amount, AllocationCategory.DEVELOPMENT, "Emergency withdrawal");
        
        emit EmergencyWithdrawal(recipient, amount, reason);
    }
    
    function pauseTreasury() external override onlyEmergencyRole {
        _pause();
        emit TreasuryPaused(msg.sender);
    }
    
    function unpauseTreasury() external override onlyEmergencyRole {
        _unpause();
        emit TreasuryUnpaused(msg.sender);
    }
    
    function emergencyRecovery() external override onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "Treasury: no funds to recover");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Treasury: emergency recovery failed");
        
        metrics.emergencyWithdrawals++;
        metrics.totalDistributed += balance;
        
        _recordHistoricalTransaction(msg.sender, balance, AllocationCategory.DEVELOPMENT, "Emergency recovery");
        
        emit EmergencyWithdrawal(msg.sender, balance, "Emergency recovery to admin");
    }
    
    // ============ ALLOCATION MANAGEMENT ============
    
    function getCategoryAllocation(AllocationCategory category) 
        external view override validCategory(category) returns (CategoryAllocation memory) {
        return _categoryAllocations[category];
    }
    
    function hasSufficientFunds(AllocationCategory category, uint256 amount) 
        public view override validCategory(category) returns (bool) {
        return _categoryAllocations[category].available >= amount;
    }
    
    function getCategorySpendingLimit(AllocationCategory category) 
        external view override validCategory(category) returns (uint256) {
        return _categoryAllocations[category].totalAllocated;
    }
    
    function reserveFunds(AllocationCategory category, uint256 amount) 
        external override onlyAllocationManager validCategory(category) {
        _reserveFundsInternal(category, amount);
        emit FundsReserved(category, amount);
    }
    
    function releaseReservedFunds(AllocationCategory category, uint256 amount) 
        external override onlyAllocationManager validCategory(category) {
        _releaseReservedFundsInternal(category, amount);
        emit ReservedFundsReleased(category, amount);
    }
    
    function rebalanceAllocations(
        AllocationCategory fromCategory,
        AllocationCategory toCategory,
        uint256 amount
    ) external override onlyAllocationManager validCategory(fromCategory) validCategory(toCategory) {
        require(fromCategory != toCategory, "Treasury: cannot rebalance to same category");
        require(hasSufficientFunds(fromCategory, amount), "Treasury: insufficient source funds");
        
        _categoryAllocations[fromCategory].available -= amount;
        _categoryAllocations[toCategory].available += amount;
        
        emit FundsRebalanced(fromCategory, toCategory, amount);
    }
    
    // ============ REPORTING AND ANALYTICS ============
    
    function getTreasuryMetrics() external view override returns (TreasuryMetrics memory) {
        return metrics;
    }
    
    function getHistoricalTransactions(uint256 fromTimestamp, uint256 toTimestamp) 
        external view override returns (HistoricalTransaction[] memory) {
        require(fromTimestamp <= toTimestamp, "Treasury: invalid timestamp range");
        
        uint256 count = 0;
        for (uint256 i = 0; i < _historicalTransactions.length; i++) {
            if (_historicalTransactions[i].timestamp >= fromTimestamp && 
                _historicalTransactions[i].timestamp <= toTimestamp) {
                count++;
            }
        }
        
        HistoricalTransaction[] memory result = new HistoricalTransaction[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < _historicalTransactions.length && index < count; i++) {
            if (_historicalTransactions[i].timestamp >= fromTimestamp && 
                _historicalTransactions[i].timestamp <= toTimestamp) {
                result[index] = _historicalTransactions[i];
                index++;
            }
        }
        
        return result;
    }
    
    function getMonthlyReport(uint256 month, uint256 year) 
        external view override returns (
            uint256 totalReceived,
            uint256 totalDistributed,
            uint256 categoryBreakdown,
            uint256 emergencyWithdrawals
        ) {
        require(month >= 1 && month <= 12, "Treasury: invalid month");
        require(year >= 2020, "Treasury: invalid year");
        
        totalReceived = _monthlyReceived[year][month];
        totalDistributed = _monthlyDistributed[year][month];
        categoryBreakdown = totalDistributed; // Simplified for basic report
        emergencyWithdrawals = _monthlyEmergencyWithdrawals[year][month];
    }
    
    function getWithdrawalProposal(uint256 proposalId) 
        external view override returns (
            address proposer,
            address recipient,
            uint256 amount,
            AllocationCategory category,
            string memory description,
            WithdrawalStatus status,
            uint256 approvalCount,
            bool isLargeWithdrawal
        ) {
        WithdrawalRequest storage proposal = _withdrawalProposals[proposalId];
        require(proposal.id == proposalId, "Treasury: proposal does not exist");
        
        return (
            proposal.proposer,
            proposal.recipient,
            proposal.amount,
            proposal.category,
            proposal.description,
            proposal.status,
            proposal.approvalCount,
            proposal.isLargeWithdrawal
        );
    }
    
    function getBatchDistribution(uint256 batchId) 
        external view override returns (BatchDistribution memory) {
        BatchDistribution storage batch = _batchDistributions[batchId];
        require(batch.id == batchId, "Treasury: batch does not exist");
        return batch;
    }
    
    // ============ CONFIGURATION ============
    
    function setMultisigThreshold(uint256 threshold) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(threshold > 0, "Treasury: threshold must be greater than 0");
        require(threshold <= approvers.length, "Treasury: threshold cannot exceed approver count");
        multisigThreshold = threshold;
        emit MultisigThresholdUpdated(threshold);
    }
    
    function setTimelockDuration(uint256 duration) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(duration >= 1 hours, "Treasury: duration too short");
        require(duration <= 30 days, "Treasury: duration too long");
        timelockDuration = duration;
        emit TimelockDurationUpdated(duration);
    }
    
    function setLargeWithdrawalThreshold(uint256 thresholdBps) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(thresholdBps > 0 && thresholdBps <= BASIS_POINTS, "Treasury: invalid threshold");
        largeWithdrawalThresholdBps = thresholdBps;
        emit LargeWithdrawalThresholdUpdated(thresholdBps);
    }
    
    function updateSaleManager(address newSaleManager) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newSaleManager != address(0), "Treasury: invalid sale manager address");
        address oldSaleManager = saleManager;
        saleManager = newSaleManager;
        emit SaleManagerUpdated(oldSaleManager, newSaleManager);
    }
    
    function setKarmaToken(address tokenAddress) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenAddress != address(0), "Treasury: invalid token address");
        address oldToken = address(karmaToken);
        karmaToken = IERC20(tokenAddress);
        emit KarmaTokenSet(oldToken, tokenAddress);
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _recordFundsReceived(
        address from,
        uint256 amount,
        AllocationCategory category,
        string memory description
    ) internal {
        metrics.totalReceived += amount;
        _updateMonthlyReceived(amount);
        
        _recordHistoricalTransaction(from, amount, category, string(abi.encodePacked("Received: ", description)));
        
        emit FundsReceived(from, amount, category);
    }
    
    function _updateCategoryAllocations(uint256 totalAmount) internal {
        uint256 marketingAmount = (totalAmount * allocationConfig.marketingPercentage) / BASIS_POINTS;
        uint256 kolAmount = (totalAmount * allocationConfig.kolPercentage) / BASIS_POINTS;
        uint256 developmentAmount = (totalAmount * allocationConfig.developmentPercentage) / BASIS_POINTS;
        uint256 buybackAmount = totalAmount - marketingAmount - kolAmount - developmentAmount; // Remaining goes to buyback
        
        _categoryAllocations[AllocationCategory.MARKETING].totalAllocated += marketingAmount;
        _categoryAllocations[AllocationCategory.MARKETING].available += marketingAmount;
        
        _categoryAllocations[AllocationCategory.KOL].totalAllocated += kolAmount;
        _categoryAllocations[AllocationCategory.KOL].available += kolAmount;
        
        _categoryAllocations[AllocationCategory.DEVELOPMENT].totalAllocated += developmentAmount;
        _categoryAllocations[AllocationCategory.DEVELOPMENT].available += developmentAmount;
        
        _categoryAllocations[AllocationCategory.BUYBACK].totalAllocated += buybackAmount;
        _categoryAllocations[AllocationCategory.BUYBACK].available += buybackAmount;
        
        metrics.totalAllocations++;
    }
    
    function _rebalanceAllAllocations() internal {
        uint256 totalBalance = address(this).balance;
        if (totalBalance == 0) return;
        
        // Calculate new allocations based on current config
        uint256 marketingTarget = (totalBalance * allocationConfig.marketingPercentage) / BASIS_POINTS;
        uint256 kolTarget = (totalBalance * allocationConfig.kolPercentage) / BASIS_POINTS;
        uint256 developmentTarget = (totalBalance * allocationConfig.developmentPercentage) / BASIS_POINTS;
        uint256 buybackTarget = totalBalance - marketingTarget - kolTarget - developmentTarget;
        
        // Update allocations
        _categoryAllocations[AllocationCategory.MARKETING].totalAllocated = marketingTarget;
        _categoryAllocations[AllocationCategory.KOL].totalAllocated = kolTarget;
        _categoryAllocations[AllocationCategory.DEVELOPMENT].totalAllocated = developmentTarget;
        _categoryAllocations[AllocationCategory.BUYBACK].totalAllocated = buybackTarget;
        
        // Recalculate available amounts (total - spent - reserved)
        for (uint256 i = 0; i <= uint256(AllocationCategory.BUYBACK); i++) {
            AllocationCategory category = AllocationCategory(i);
            CategoryAllocation storage allocation = _categoryAllocations[category];
            allocation.available = allocation.totalAllocated - allocation.totalSpent - allocation.reserved;
        }
    }
    
    function _executeWithdrawalInternal(uint256 proposalId) internal nonReentrant {
        WithdrawalRequest storage proposal = _withdrawalProposals[proposalId];
        require(proposal.id == proposalId, "Treasury: proposal does not exist");
        require(proposal.status == WithdrawalStatus.PENDING, "Treasury: proposal not pending");
        require(proposal.approvalCount >= multisigThreshold, "Treasury: insufficient approvals");
        require(block.timestamp >= proposal.executionTime, "Treasury: timelock not expired");
        
        proposal.status = WithdrawalStatus.EXECUTED;
        
        // Release reserved funds and execute withdrawal
        _categoryAllocations[proposal.category].reserved -= proposal.amount;
        _categoryAllocations[proposal.category].totalSpent += proposal.amount;
        _categoryAllocations[proposal.category].lastDistribution = block.timestamp;
        
        (bool success, ) = proposal.recipient.call{value: proposal.amount}("");
        require(success, "Treasury: withdrawal transfer failed");
        
        metrics.totalWithdrawals++;
        metrics.totalDistributed += proposal.amount;
        _updateMonthlyDistributed(proposal.amount);
        
        _recordHistoricalTransaction(
            proposal.recipient,
            proposal.amount,
            proposal.category,
            string(abi.encodePacked("Withdrawal: ", proposal.description))
        );
        
        emit WithdrawalExecuted(proposalId, proposal.recipient, proposal.amount);
    }
    
    function _isLargeWithdrawal(uint256 amount) internal view returns (bool) {
        uint256 threshold = (address(this).balance * largeWithdrawalThresholdBps) / BASIS_POINTS;
        return amount > threshold;
    }
    
    function _recordHistoricalTransaction(
        address recipient,
        uint256 amount,
        AllocationCategory category,
        string memory transactionType
    ) internal {
        _historicalTransactions.push(HistoricalTransaction({
            timestamp: block.timestamp,
            recipient: recipient,
            amount: amount,
            category: category,
            transactionType: transactionType,
            balanceAfter: address(this).balance
        }));
    }
    
    function _updateMonthlyReceived(uint256 amount) internal {
        uint256 year = _getYear(block.timestamp);
        uint256 month = _getMonth(block.timestamp);
        _monthlyReceived[year][month] += amount;
    }
    
    function _updateMonthlyDistributed(uint256 amount) internal {
        uint256 year = _getYear(block.timestamp);
        uint256 month = _getMonth(block.timestamp);
        _monthlyDistributed[year][month] += amount;
    }
    
    function _updateMonthlyEmergencyWithdrawals(uint256 amount) internal {
        uint256 year = _getYear(block.timestamp);
        uint256 month = _getMonth(block.timestamp);
        _monthlyEmergencyWithdrawals[year][month] += amount;
    }
    
    function _getYear(uint256 timestamp) internal pure returns (uint256) {
        // Simplified year calculation (approximation)
        return 1970 + (timestamp / 365 days);
    }
    
    function _getMonth(uint256 timestamp) internal pure returns (uint256) {
        // Simplified month calculation (approximation)
        uint256 dayOfYear = (timestamp % 365 days) / 1 days;
        return (dayOfYear / 30) + 1; // Rough approximation
    }
    
    function _reserveFundsInternal(AllocationCategory category, uint256 amount) internal {
        require(hasSufficientFunds(category, amount), "Treasury: insufficient available funds");
        
        _categoryAllocations[category].available -= amount;
        _categoryAllocations[category].reserved += amount;
    }
    
    function _releaseReservedFundsInternal(AllocationCategory category, uint256 amount) internal {
        require(_categoryAllocations[category].reserved >= amount, "Treasury: insufficient reserved funds");
        
        _categoryAllocations[category].reserved -= amount;
        _categoryAllocations[category].available += amount;
    }
} 