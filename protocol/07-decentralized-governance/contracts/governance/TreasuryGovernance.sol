// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../../interfaces/IKarmaGovernor.sol";

/**
 * @title TreasuryGovernance
 * @dev Stage 7.2 Treasury Governance Integration
 * 
 * Requirements:
 * - Create proposal types for Treasury fund allocation
 * - Implement spending limit controls and budget management
 * - Build proposal impact assessment and fund tracking
 * - Add community treasury allocation mechanisms (10% of funds)
 */
contract TreasuryGovernance is AccessControl, Pausable, ReentrancyGuard {
    using Math for uint256;
    
    // ============ CONSTANTS ============
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant COMMUNITY_ALLOCATION_BPS = 1000; // 10% of funds
    uint256 public constant MAX_SPENDING_LIMIT_BPS = 2000; // 20% max per proposal
    uint256 public constant BUDGET_PERIOD = 30 days; // Monthly budget cycles
    uint256 public constant EMERGENCY_THRESHOLD_BPS = 500; // 5% emergency threshold
    
    // Role definitions
    bytes32 public constant TREASURY_GOVERNANCE_MANAGER_ROLE = keccak256("TREASURY_GOVERNANCE_MANAGER_ROLE");
    bytes32 public constant BUDGET_MANAGER_ROLE = keccak256("BUDGET_MANAGER_ROLE");
    bytes32 public constant COMMUNITY_FUND_MANAGER_ROLE = keccak256("COMMUNITY_FUND_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_TREASURY_ROLE = keccak256("EMERGENCY_TREASURY_ROLE");
    
    // ============ ENUMS ============
    
    enum TreasuryProposalType {
        GENERAL_SPENDING,     // General treasury spending
        COMMUNITY_FUNDING,    // Community project funding
        EMERGENCY_ALLOCATION, // Emergency fund allocation
        BUDGET_ADJUSTMENT,    // Budget limit adjustments
        FUND_REALLOCATION    // Moving funds between categories
    }
    
    enum AllocationCategory {
        MARKETING,       // Marketing and growth
        DEVELOPMENT,     // Development and engineering
        OPERATIONS,      // Operations and management
        COMMUNITY,       // Community initiatives
        PARTNERSHIPS,    // Strategic partnerships
        RESERVES,        // Emergency reserves
        BUYBACK         // Token buyback fund
    }
    
    enum ProposalStatus {
        PENDING,         // Awaiting governance vote
        APPROVED,        // Approved by governance
        EXECUTED,        // Successfully executed
        REJECTED,        // Rejected by governance
        EXPIRED,         // Expired without execution
        CANCELLED        // Cancelled by emergency action
    }
    
    // ============ STRUCTS ============
    
    struct TreasuryProposal {
        uint256 proposalId;           // Governance proposal ID
        TreasuryProposalType proposalType;
        AllocationCategory category;
        uint256 amount;               // Amount requested
        address recipient;            // Recipient address
        string description;           // Proposal description
        uint256 timestamp;            // Creation timestamp
        ProposalStatus status;        // Current status
        uint256 executionDeadline;    // Deadline for execution
        mapping(address => bool) hasVoted; // Voting tracking
        uint256 votesFor;             // Votes in favor
        uint256 votesAgainst;         // Votes against
        bytes32 impactHash;           // Hash of impact assessment
    }
    
    struct BudgetAllocation {
        AllocationCategory category;
        uint256 totalBudget;          // Total budget for period
        uint256 spentAmount;          // Amount already spent
        uint256 pendingAmount;        // Amount in pending proposals
        uint256 lastUpdateTime;       // Last budget update
        uint256 spendingLimit;        // Maximum spending per proposal
        bool isActive;                // Whether category is active
    }
    
    struct CommunityFund {
        uint256 totalAllocated;       // Total community allocation
        uint256 availableBalance;     // Available for allocation
        uint256 reservedAmount;       // Reserved for approved proposals
        uint256 distributedAmount;    // Already distributed
        uint256 lastAllocationTime;   // Last allocation timestamp
        mapping(address => uint256) allocations; // Individual allocations
    }
    
    struct ProposalImpactAssessment {
        uint256 estimatedROI;         // Return on investment estimate
        uint256 riskScore;            // Risk assessment score (1-100)
        uint256 timeToRealization;    // Expected time to see results
        string[] metrics;             // Success metrics
        string riskMitigation;        // Risk mitigation strategies
        uint256 assessmentTimestamp;  // When assessment was created
        address assessor;             // Who performed the assessment
    }
    
    struct SpendingAnalytics {
        uint256 totalSpent;           // Total treasury spending
        uint256 communitySpent;       // Community fund spending
        uint256 averageProposalSize;  // Average proposal amount
        uint256 successfulProposals;  // Number of executed proposals
        uint256 rejectedProposals;    // Number of rejected proposals
        mapping(AllocationCategory => uint256) categorySpending;
        mapping(uint256 => uint256) monthlySpending; // month => amount
    }
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaGovernor;
    address public treasury;
    address public karmaToken;
    
    // Treasury governance data
    mapping(uint256 => TreasuryProposal) private _treasuryProposals;
    mapping(AllocationCategory => BudgetAllocation) private _budgetAllocations;
    mapping(uint256 => ProposalImpactAssessment) private _impactAssessments;
    
    CommunityFund private _communityFund;
    SpendingAnalytics private _spendingAnalytics;
    
    // Proposal tracking
    uint256[] public allProposalIds;
    mapping(address => uint256[]) public proposalsByProposer;
    mapping(AllocationCategory => uint256[]) public proposalsByCategory;
    
    // Budget management
    uint256 public currentBudgetPeriod;
    uint256 public totalTreasuryValue;
    mapping(uint256 => uint256) public budgetPeriodStart; // period => timestamp
    
    // Spending controls
    mapping(address => uint256) public lastProposalTime;
    mapping(address => uint256) public proposalCount;
    uint256 public constant PROPOSAL_COOLDOWN = 24 hours;
    uint256 public constant MAX_PROPOSALS_PER_MONTH = 5;
    
    // ============ EVENTS ============
    
    event TreasuryProposalCreated(
        uint256 indexed proposalId,
        TreasuryProposalType indexed proposalType,
        AllocationCategory indexed category,
        uint256 amount,
        address recipient,
        string description
    );
    
    event TreasuryProposalExecuted(
        uint256 indexed proposalId,
        uint256 amount,
        address recipient,
        AllocationCategory category
    );
    
    event BudgetAllocationUpdated(
        AllocationCategory indexed category,
        uint256 oldBudget,
        uint256 newBudget,
        uint256 period
    );
    
    event CommunityFundDistributed(
        address indexed recipient,
        uint256 amount,
        string purpose
    );
    
    event ImpactAssessmentCreated(
        uint256 indexed proposalId,
        uint256 estimatedROI,
        uint256 riskScore,
        address assessor
    );
    
    event EmergencySpendingApproved(
        uint256 indexed proposalId,
        uint256 amount,
        string reason
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyTreasuryGovernanceManager() {
        require(hasRole(TREASURY_GOVERNANCE_MANAGER_ROLE, msg.sender), "TreasuryGovernance: caller is not treasury governance manager");
        _;
    }
    
    modifier onlyBudgetManager() {
        require(hasRole(BUDGET_MANAGER_ROLE, msg.sender), "TreasuryGovernance: caller is not budget manager");
        _;
    }
    
    modifier onlyCommunityFundManager() {
        require(hasRole(COMMUNITY_FUND_MANAGER_ROLE, msg.sender), "TreasuryGovernance: caller is not community fund manager");
        _;
    }
    
    modifier onlyEmergencyTreasuryRole() {
        require(hasRole(EMERGENCY_TREASURY_ROLE, msg.sender), "TreasuryGovernance: caller does not have emergency treasury role");
        _;
    }
    
    modifier validProposal(uint256 proposalId) {
        require(_treasuryProposals[proposalId].proposalId != 0, "TreasuryGovernance: proposal does not exist");
        _;
    }
    
    modifier respectsCooldown() {
        require(
            block.timestamp >= lastProposalTime[msg.sender] + PROPOSAL_COOLDOWN,
            "TreasuryGovernance: proposal cooldown not met"
        );
        _;
    }
    
    modifier respectsRateLimit() {
        uint256 monthStart = (block.timestamp / 30 days) * 30 days;
        require(
            proposalCount[msg.sender] < MAX_PROPOSALS_PER_MONTH,
            "TreasuryGovernance: monthly proposal limit exceeded"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaGovernor,
        address _treasury,
        address _karmaToken,
        address _admin
    ) {
        require(_karmaGovernor != address(0), "TreasuryGovernance: invalid governor address");
        require(_treasury != address(0), "TreasuryGovernance: invalid treasury address");
        require(_karmaToken != address(0), "TreasuryGovernance: invalid token address");
        require(_admin != address(0), "TreasuryGovernance: invalid admin address");
        
        karmaGovernor = _karmaGovernor;
        treasury = _treasury;
        karmaToken = _karmaToken;
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(TREASURY_GOVERNANCE_MANAGER_ROLE, _admin);
        _grantRole(BUDGET_MANAGER_ROLE, _admin);
        _grantRole(COMMUNITY_FUND_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_TREASURY_ROLE, _admin);
        
        // Initialize budget period
        currentBudgetPeriod = block.timestamp / BUDGET_PERIOD;
        budgetPeriodStart[currentBudgetPeriod] = block.timestamp;
        
        // Initialize community fund
        _communityFund.lastAllocationTime = block.timestamp;
        
        _initializeBudgetAllocations();
    }
    
    // ============ TREASURY PROPOSAL FUNCTIONS ============
    
    /**
     * @dev Create a treasury spending proposal
     */
    function createTreasuryProposal(
        TreasuryProposalType proposalType,
        AllocationCategory category,
        uint256 amount,
        address recipient,
        string memory description
    ) external respectsCooldown respectsRateLimit whenNotPaused nonReentrant returns (uint256) {
        require(amount > 0, "TreasuryGovernance: amount must be greater than zero");
        require(recipient != address(0), "TreasuryGovernance: invalid recipient");
        require(bytes(description).length > 0, "TreasuryGovernance: description required");
        
        // Validate spending limits
        _validateSpendingLimits(category, amount);
        
        // Create governance proposal
        uint256 proposalId = _createGovernanceProposal(proposalType, category, amount, recipient, description);
        
        // Store treasury proposal data
        TreasuryProposal storage proposal = _treasuryProposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposalType = proposalType;
        proposal.category = category;
        proposal.amount = amount;
        proposal.recipient = recipient;
        proposal.description = description;
        proposal.timestamp = block.timestamp;
        proposal.status = ProposalStatus.PENDING;
        proposal.executionDeadline = block.timestamp + 30 days;
        
        // Track proposal
        allProposalIds.push(proposalId);
        proposalsByProposer[msg.sender].push(proposalId);
        proposalsByCategory[category].push(proposalId);
        
        // Update rate limiting
        lastProposalTime[msg.sender] = block.timestamp;
        proposalCount[msg.sender]++;
        
        // Update budget allocation
        _budgetAllocations[category].pendingAmount += amount;
        
        emit TreasuryProposalCreated(proposalId, proposalType, category, amount, recipient, description);
        
        return proposalId;
    }
    
    /**
     * @dev Execute approved treasury proposal
     */
    function executeTreasuryProposal(uint256 proposalId) external validProposal(proposalId) whenNotPaused nonReentrant {
        TreasuryProposal storage proposal = _treasuryProposals[proposalId];
        require(proposal.status == ProposalStatus.APPROVED, "TreasuryGovernance: proposal not approved");
        require(block.timestamp <= proposal.executionDeadline, "TreasuryGovernance: proposal expired");
        
        // Update proposal status
        proposal.status = ProposalStatus.EXECUTED;
        
        // Execute treasury transfer
        _executeTreasuryTransfer(proposal.amount, proposal.recipient, proposal.category);
        
        // Update budget tracking
        _updateBudgetSpending(proposal.category, proposal.amount);
        
        // Update analytics
        _spendingAnalytics.totalSpent += proposal.amount;
        _spendingAnalytics.successfulProposals++;
        _spendingAnalytics.categorySpending[proposal.category] += proposal.amount;
        
        uint256 currentMonth = block.timestamp / 30 days;
        _spendingAnalytics.monthlySpending[currentMonth] += proposal.amount;
        
        emit TreasuryProposalExecuted(proposalId, proposal.amount, proposal.recipient, proposal.category);
    }
    
    // ============ BUDGET MANAGEMENT FUNCTIONS ============
    
    /**
     * @dev Set budget allocation for category
     */
    function setBudgetAllocation(
        AllocationCategory category,
        uint256 budget,
        uint256 spendingLimit
    ) external onlyBudgetManager {
        require(budget > 0, "TreasuryGovernance: budget must be greater than zero");
        require(spendingLimit <= budget.mulDiv(MAX_SPENDING_LIMIT_BPS, BASIS_POINTS), "TreasuryGovernance: spending limit too high");
        
        BudgetAllocation storage allocation = _budgetAllocations[category];
        uint256 oldBudget = allocation.totalBudget;
        
        allocation.totalBudget = budget;
        allocation.spendingLimit = spendingLimit;
        allocation.lastUpdateTime = block.timestamp;
        allocation.isActive = true;
        
        emit BudgetAllocationUpdated(category, oldBudget, budget, currentBudgetPeriod);
    }
    
    /**
     * @dev Initialize new budget period
     */
    function initializeBudgetPeriod() external onlyBudgetManager {
        uint256 newPeriod = block.timestamp / BUDGET_PERIOD;
        require(newPeriod > currentBudgetPeriod, "TreasuryGovernance: period not ready for update");
        
        currentBudgetPeriod = newPeriod;
        budgetPeriodStart[newPeriod] = block.timestamp;
        
        // Reset spending amounts for new period
        for (uint256 i = 0; i < 7; i++) {
            AllocationCategory category = AllocationCategory(i);
            _budgetAllocations[category].spentAmount = 0;
            _budgetAllocations[category].pendingAmount = 0;
        }
        
        // Update community fund allocation (10% of treasury)
        _updateCommunityFundAllocation();
    }
    
    // ============ COMMUNITY FUND FUNCTIONS ============
    
    /**
     * @dev Distribute community funds
     */
    function distributeCommunityFunds(
        address recipient,
        uint256 amount,
        string memory purpose
    ) external onlyCommunityFundManager whenNotPaused nonReentrant {
        require(recipient != address(0), "TreasuryGovernance: invalid recipient");
        require(amount > 0, "TreasuryGovernance: amount must be greater than zero");
        require(amount <= _communityFund.availableBalance, "TreasuryGovernance: insufficient community funds");
        require(bytes(purpose).length > 0, "TreasuryGovernance: purpose required");
        
        // Update community fund tracking
        _communityFund.availableBalance -= amount;
        _communityFund.distributedAmount += amount;
        _communityFund.allocations[recipient] += amount;
        
        // Execute transfer
        _executeTreasuryTransfer(amount, recipient, AllocationCategory.COMMUNITY);
        
        // Update analytics
        _spendingAnalytics.communitySpent += amount;
        
        emit CommunityFundDistributed(recipient, amount, purpose);
    }
    
    // ============ IMPACT ASSESSMENT FUNCTIONS ============
    
    /**
     * @dev Create impact assessment for proposal
     */
    function createImpactAssessment(
        uint256 proposalId,
        uint256 estimatedROI,
        uint256 riskScore,
        uint256 timeToRealization,
        string[] memory metrics,
        string memory riskMitigation
    ) external validProposal(proposalId) {
        require(riskScore <= 100, "TreasuryGovernance: risk score must be 0-100");
        require(estimatedROI > 0, "TreasuryGovernance: ROI must be positive");
        
        ProposalImpactAssessment storage assessment = _impactAssessments[proposalId];
        assessment.estimatedROI = estimatedROI;
        assessment.riskScore = riskScore;
        assessment.timeToRealization = timeToRealization;
        assessment.metrics = metrics;
        assessment.riskMitigation = riskMitigation;
        assessment.assessmentTimestamp = block.timestamp;
        assessment.assessor = msg.sender;
        
        // Store hash for integrity
        bytes32 assessmentHash = keccak256(abi.encodePacked(
            estimatedROI, riskScore, timeToRealization, riskMitigation, block.timestamp
        ));
        _treasuryProposals[proposalId].impactHash = assessmentHash;
        
        emit ImpactAssessmentCreated(proposalId, estimatedROI, riskScore, msg.sender);
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency spending approval
     */
    function emergencySpending(
        uint256 amount,
        address recipient,
        string memory reason
    ) external onlyEmergencyTreasuryRole whenNotPaused nonReentrant {
        require(amount <= totalTreasuryValue.mulDiv(EMERGENCY_THRESHOLD_BPS, BASIS_POINTS), "TreasuryGovernance: amount exceeds emergency threshold");
        require(recipient != address(0), "TreasuryGovernance: invalid recipient");
        require(bytes(reason).length > 0, "TreasuryGovernance: reason required");
        
        // Create emergency proposal record
        uint256 proposalId = allProposalIds.length + 1;
        TreasuryProposal storage proposal = _treasuryProposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposalType = TreasuryProposalType.EMERGENCY_ALLOCATION;
        proposal.category = AllocationCategory.RESERVES;
        proposal.amount = amount;
        proposal.recipient = recipient;
        proposal.description = string(abi.encodePacked("Emergency: ", reason));
        proposal.timestamp = block.timestamp;
        proposal.status = ProposalStatus.EXECUTED;
        
        // Execute transfer
        _executeTreasuryTransfer(amount, recipient, AllocationCategory.RESERVES);
        
        // Update analytics
        _spendingAnalytics.totalSpent += amount;
        
        emit EmergencySpendingApproved(proposalId, amount, reason);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get treasury proposal details
     */
    function getTreasuryProposal(uint256 proposalId) external view validProposal(proposalId) returns (
        TreasuryProposalType proposalType,
        AllocationCategory category,
        uint256 amount,
        address recipient,
        string memory description,
        ProposalStatus status,
        uint256 timestamp,
        uint256 executionDeadline
    ) {
        TreasuryProposal storage proposal = _treasuryProposals[proposalId];
        return (
            proposal.proposalType,
            proposal.category,
            proposal.amount,
            proposal.recipient,
            proposal.description,
            proposal.status,
            proposal.timestamp,
            proposal.executionDeadline
        );
    }
    
    /**
     * @dev Get budget allocation for category
     */
    function getBudgetAllocation(AllocationCategory category) external view returns (BudgetAllocation memory) {
        return _budgetAllocations[category];
    }
    
    /**
     * @dev Get community fund status
     */
    function getCommunityFund() external view returns (
        uint256 totalAllocated,
        uint256 availableBalance,
        uint256 reservedAmount,
        uint256 distributedAmount
    ) {
        return (
            _communityFund.totalAllocated,
            _communityFund.availableBalance,
            _communityFund.reservedAmount,
            _communityFund.distributedAmount
        );
    }
    
    /**
     * @dev Get spending analytics
     */
    function getSpendingAnalytics() external view returns (
        uint256 totalSpent,
        uint256 communitySpent,
        uint256 averageProposalSize,
        uint256 successfulProposals,
        uint256 rejectedProposals
    ) {
        return (
            _spendingAnalytics.totalSpent,
            _spendingAnalytics.communitySpent,
            _spendingAnalytics.averageProposalSize,
            _spendingAnalytics.successfulProposals,
            _spendingAnalytics.rejectedProposals
        );
    }
    
    /**
     * @dev Get impact assessment
     */
    function getImpactAssessment(uint256 proposalId) external view validProposal(proposalId) returns (ProposalImpactAssessment memory) {
        return _impactAssessments[proposalId];
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _initializeBudgetAllocations() internal {
        // Initialize default budget allocations
        _budgetAllocations[AllocationCategory.MARKETING] = BudgetAllocation({
            category: AllocationCategory.MARKETING,
            totalBudget: 0,
            spentAmount: 0,
            pendingAmount: 0,
            lastUpdateTime: block.timestamp,
            spendingLimit: 0,
            isActive: true
        });
        
        // Initialize other categories...
        for (uint256 i = 1; i < 7; i++) {
            AllocationCategory category = AllocationCategory(i);
            _budgetAllocations[category] = BudgetAllocation({
                category: category,
                totalBudget: 0,
                spentAmount: 0,
                pendingAmount: 0,
                lastUpdateTime: block.timestamp,
                spendingLimit: 0,
                isActive: true
            });
        }
    }
    
    function _validateSpendingLimits(AllocationCategory category, uint256 amount) internal view {
        BudgetAllocation storage allocation = _budgetAllocations[category];
        require(allocation.isActive, "TreasuryGovernance: category not active");
        require(amount <= allocation.spendingLimit, "TreasuryGovernance: amount exceeds spending limit");
        require(
            allocation.spentAmount + allocation.pendingAmount + amount <= allocation.totalBudget,
            "TreasuryGovernance: would exceed budget"
        );
    }
    
    function _createGovernanceProposal(
        TreasuryProposalType proposalType,
        AllocationCategory category,
        uint256 amount,
        address recipient,
        string memory description
    ) internal returns (uint256) {
        // This would integrate with the KarmaGovernor to create the actual governance proposal
        // For now, returning a mock proposal ID
        return allProposalIds.length + 1;
    }
    
    function _executeTreasuryTransfer(uint256 amount, address recipient, AllocationCategory category) internal {
        // This would call the Treasury contract to execute the transfer
        // Implementation would depend on Treasury contract interface
    }
    
    function _updateBudgetSpending(AllocationCategory category, uint256 amount) internal {
        BudgetAllocation storage allocation = _budgetAllocations[category];
        allocation.spentAmount += amount;
        allocation.pendingAmount -= amount;
        allocation.lastUpdateTime = block.timestamp;
    }
    
    function _updateCommunityFundAllocation() internal {
        // Update community fund with 10% of current treasury value
        uint256 newAllocation = totalTreasuryValue.mulDiv(COMMUNITY_ALLOCATION_BPS, BASIS_POINTS);
        _communityFund.totalAllocated = newAllocation;
        _communityFund.availableBalance = newAllocation - _communityFund.distributedAmount - _communityFund.reservedAmount;
        _communityFund.lastAllocationTime = block.timestamp;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Update treasury value for calculations
     */
    function updateTreasuryValue(uint256 newValue) external onlyTreasuryGovernanceManager {
        totalTreasuryValue = newValue;
        _updateCommunityFundAllocation();
    }
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyEmergencyTreasuryRole {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyEmergencyTreasuryRole {
        _unpause();
    }
} 