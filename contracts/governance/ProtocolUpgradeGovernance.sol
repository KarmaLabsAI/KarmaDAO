// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ProtocolUpgradeGovernance
 * @dev Stage 7.2 Protocol Upgrade Governance
 * 
 * Requirements:
 * - Create upgrade proposal mechanisms for smart contract improvements
 * - Implement proxy pattern governance for contract upgrades
 * - Build parameter adjustment governance (fees, limits, timeouts)
 * - Add emergency upgrade mechanisms with community oversight
 */
contract ProtocolUpgradeGovernance is AccessControl, Pausable, ReentrancyGuard {
    using Math for uint256;
    
    // ============ CONSTANTS ============
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant UPGRADE_DELAY_MINIMUM = 3 days;
    uint256 public constant UPGRADE_DELAY_MAXIMUM = 30 days;
    uint256 public constant EMERGENCY_UPGRADE_DELAY = 24 hours;
    uint256 public constant PARAMETER_CHANGE_DELAY = 1 days;
    uint256 public constant MAJOR_UPGRADE_THRESHOLD = 7500; // 75% approval needed
    uint256 public constant MINOR_UPGRADE_THRESHOLD = 5000; // 50% approval needed
    uint256 public constant PARAMETER_CHANGE_THRESHOLD = 5000; // 50% approval needed
    
    // Role definitions
    bytes32 public constant UPGRADE_GOVERNANCE_MANAGER_ROLE = keccak256("UPGRADE_GOVERNANCE_MANAGER_ROLE");
    bytes32 public constant UPGRADE_PROPOSER_ROLE = keccak256("UPGRADE_PROPOSER_ROLE");
    bytes32 public constant PARAMETER_MANAGER_ROLE = keccak256("PARAMETER_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_UPGRADE_ROLE = keccak256("EMERGENCY_UPGRADE_ROLE");
    bytes32 public constant COMMUNITY_OVERSIGHT_ROLE = keccak256("COMMUNITY_OVERSIGHT_ROLE");
    
    // ============ ENUMS ============
    
    enum UpgradeType {
        MAJOR_UPGRADE,      // Significant protocol changes
        MINOR_UPGRADE,      // Bug fixes and small improvements
        PARAMETER_CHANGE,   // Parameter adjustments
        EMERGENCY_UPGRADE,  // Emergency security fixes
        PROXY_UPGRADE      // Proxy implementation upgrades
    }
    
    enum UpgradeCategory {
        CORE_TOKEN,         // KarmaToken upgrades
        GOVERNANCE,         // Governance system upgrades
        TREASURY,           // Treasury contract upgrades
        STAKING,            // Staking system upgrades
        VESTING,            // Vesting contract upgrades
        SALE_MANAGEMENT,    // Sale management upgrades
        PAYMASTER,          // Paymaster upgrades
        TOKENOMICS,         // Buyback/burn upgrades
        INFRASTRUCTURE     // Infrastructure upgrades
    }
    
    enum ProposalStatus {
        PENDING,           // Awaiting community review
        VOTING,            // Active voting period
        APPROVED,          // Approved for execution
        QUEUED,            // Queued for execution
        EXECUTED,          // Successfully executed
        REJECTED,          // Rejected by community
        EXPIRED,           // Expired without execution
        CANCELLED,         // Cancelled by emergency
        EMERGENCY_EXECUTED // Emergency execution bypassed normal flow
    }
    
    // ============ STRUCTS ============
    
    struct UpgradeProposal {
        uint256 proposalId;
        UpgradeType upgradeType;
        UpgradeCategory category;
        address targetContract;
        address newImplementation;
        bytes upgradeData;
        string description;
        string technicalSpecification;
        uint256 timestamp;
        uint256 votingDeadline;
        uint256 executionDeadline;
        ProposalStatus status;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVotingPower;
        address proposer;
        bool requiresEmergencyOverride;
    }
    
    struct ParameterChange {
        uint256 proposalId;
        address targetContract;
        string parameterName;
        bytes32 currentValue;
        bytes32 newValue;
        uint256 timestamp;
        uint256 executionTime;
        ProposalStatus status;
        string justification;
        uint256 impactAssessment; // 1-100 scale
    }
    
    struct ContractRegistry {
        address contractAddress;
        address proxyAdmin;
        address implementation;
        UpgradeCategory category;
        bool isUpgradeable;
        bool isActive;
        uint256 lastUpgrade;
        string version;
    }
    
    struct UpgradeMetrics {
        uint256 totalProposals;
        uint256 successfulUpgrades;
        uint256 rejectedUpgrades;
        uint256 emergencyUpgrades;
        uint256 parameterChanges;
        uint256 averageVotingParticipation;
    }
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaGovernor;
    address public karmaToken;
    address public stakingContract;
    
    // Upgrade governance data
    mapping(uint256 => UpgradeProposal) private _upgradeProposals;
    mapping(uint256 => ParameterChange) private _parameterChanges;
    mapping(address => ContractRegistry) private _contractRegistry;
    mapping(string => address) public contractsByName;
    mapping(uint256 => mapping(address => bool)) private _hasVoted;
    mapping(uint256 => mapping(address => uint256)) private _votes;
    mapping(address => mapping(string => bytes32)) private _contractParameters;
    mapping(address => string[]) private _parameterNames;
    
    UpgradeMetrics private _upgradeMetrics;
    
    // Proposal tracking
    uint256 public proposalCounter;
    uint256[] public allUpgradeProposals;
    uint256[] public allParameterChanges;
    mapping(address => uint256[]) public proposalsByProposer;
    mapping(UpgradeCategory => uint256[]) public proposalsByCategory;
    
    // Upgrade scheduling
    mapping(uint256 => uint256) public upgradeSchedule; // proposalId => execution time
    mapping(address => uint256) public lastUpgradeTime;
    uint256 public constant MIN_UPGRADE_INTERVAL = 7 days;
    
    // Emergency controls
    mapping(uint256 => bool) public emergencyOverrides;
    mapping(address => uint256) public emergencyUpgradeCount;
    uint256 public constant MAX_EMERGENCY_UPGRADES_PER_MONTH = 3;
    
    // Community oversight
    mapping(address => bool) public isOversightMember;
    mapping(uint256 => mapping(address => bool)) public proposalReviews;
    mapping(uint256 => uint256) public oversightApprovals;
    uint256 public totalOversightMembers;
    uint256 public minimumOversightApprovals = 3;
    
    // ============ EVENTS ============
    
    event UpgradeProposalCreated(
        uint256 indexed proposalId,
        UpgradeType indexed upgradeType,
        UpgradeCategory indexed category,
        address targetContract,
        address newImplementation,
        address proposer
    );
    
    event UpgradeProposalExecuted(
        uint256 indexed proposalId,
        address indexed targetContract,
        address newImplementation,
        UpgradeType upgradeType
    );
    
    event ParameterChangeProposed(
        uint256 indexed proposalId,
        address indexed targetContract,
        string parameterName,
        bytes32 currentValue,
        bytes32 newValue
    );
    
    event ParameterChangeExecuted(
        uint256 indexed proposalId,
        address indexed targetContract,
        string parameterName,
        bytes32 newValue
    );
    
    event EmergencyUpgradeExecuted(
        uint256 indexed proposalId,
        address indexed targetContract,
        address newImplementation,
        string reason
    );
    
    event ContractRegistered(
        address indexed contractAddress,
        UpgradeCategory indexed category,
        string name,
        bool isUpgradeable
    );
    
    event CommunityOversightAdded(address indexed member);
    event CommunityOversightRemoved(address indexed member);
    
    // ============ MODIFIERS ============
    
    modifier onlyUpgradeGovernanceManager() {
        require(hasRole(UPGRADE_GOVERNANCE_MANAGER_ROLE, msg.sender), "ProtocolUpgradeGovernance: caller is not upgrade governance manager");
        _;
    }
    
    modifier onlyUpgradeProposer() {
        require(hasRole(UPGRADE_PROPOSER_ROLE, msg.sender), "ProtocolUpgradeGovernance: caller is not upgrade proposer");
        _;
    }
    
    modifier onlyParameterManager() {
        require(hasRole(PARAMETER_MANAGER_ROLE, msg.sender), "ProtocolUpgradeGovernance: caller is not parameter manager");
        _;
    }
    
    modifier onlyEmergencyUpgradeRole() {
        require(hasRole(EMERGENCY_UPGRADE_ROLE, msg.sender), "ProtocolUpgradeGovernance: caller does not have emergency upgrade role");
        _;
    }
    
    modifier onlyCommunityOversight() {
        require(hasRole(COMMUNITY_OVERSIGHT_ROLE, msg.sender), "ProtocolUpgradeGovernance: caller does not have community oversight role");
        _;
    }
    
    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCounter, "ProtocolUpgradeGovernance: invalid proposal ID");
        _;
    }
    
    modifier validContract(address contractAddress) {
        require(_contractRegistry[contractAddress].isActive, "ProtocolUpgradeGovernance: contract not registered or inactive");
        _;
    }
    
    modifier respectsUpgradeInterval(address contractAddress) {
        require(
            block.timestamp >= lastUpgradeTime[contractAddress] + MIN_UPGRADE_INTERVAL,
            "ProtocolUpgradeGovernance: minimum upgrade interval not met"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaGovernor,
        address _karmaToken,
        address _stakingContract,
        address _admin
    ) {
        require(_karmaGovernor != address(0), "ProtocolUpgradeGovernance: invalid governor address");
        require(_karmaToken != address(0), "ProtocolUpgradeGovernance: invalid token address");
        require(_stakingContract != address(0), "ProtocolUpgradeGovernance: invalid staking contract");
        require(_admin != address(0), "ProtocolUpgradeGovernance: invalid admin address");
        
        karmaGovernor = _karmaGovernor;
        karmaToken = _karmaToken;
        stakingContract = _stakingContract;
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADE_GOVERNANCE_MANAGER_ROLE, _admin);
        _grantRole(UPGRADE_PROPOSER_ROLE, _admin);
        _grantRole(PARAMETER_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_UPGRADE_ROLE, _admin);
        _grantRole(COMMUNITY_OVERSIGHT_ROLE, _admin);
        
        // Initialize community oversight
        isOversightMember[_admin] = true;
        totalOversightMembers = 1;
        
        proposalCounter = 0;
    }
    
    // ============ CONTRACT REGISTRY FUNCTIONS ============
    
    /**
     * @dev Register a contract for upgrade governance
     */
    function registerContract(
        address contractAddress,
        UpgradeCategory category,
        string memory name,
        bool isUpgradeable,
        address proxyAdmin,
        address implementation
    ) external onlyUpgradeGovernanceManager {
        require(contractAddress != address(0), "ProtocolUpgradeGovernance: invalid contract address");
        require(bytes(name).length > 0, "ProtocolUpgradeGovernance: name required");
        
        ContractRegistry storage registry = _contractRegistry[contractAddress];
        registry.contractAddress = contractAddress;
        registry.proxyAdmin = proxyAdmin;
        registry.implementation = implementation;
        registry.category = category;
        registry.isUpgradeable = isUpgradeable;
        registry.isActive = true;
        registry.lastUpgrade = block.timestamp;
        registry.version = "1.0.0";
        
        contractsByName[name] = contractAddress;
        
        emit ContractRegistered(contractAddress, category, name, isUpgradeable);
    }
    
    /**
     * @dev Update contract parameter
     */
    function updateContractParameter(
        address contractAddress,
        string memory parameterName,
        bytes32 value
    ) external validContract(contractAddress) onlyParameterManager {
        // Add parameter if it doesn't exist
        if (_contractParameters[contractAddress][parameterName] == 0) {
            _parameterNames[contractAddress].push(parameterName);
        }
        
        _contractParameters[contractAddress][parameterName] = value;
    }
    
    // ============ UPGRADE PROPOSAL FUNCTIONS ============
    
    /**
     * @dev Create upgrade proposal
     */
    function createUpgradeProposal(
        UpgradeType upgradeType,
        UpgradeCategory category,
        address targetContract,
        address newImplementation,
        bytes memory upgradeData,
        string memory description,
        string memory technicalSpecification
    ) external onlyUpgradeProposer validContract(targetContract) respectsUpgradeInterval(targetContract) whenNotPaused nonReentrant returns (uint256) {
        require(newImplementation != address(0), "ProtocolUpgradeGovernance: invalid implementation");
        require(bytes(description).length > 0, "ProtocolUpgradeGovernance: description required");
        require(bytes(technicalSpecification).length > 0, "ProtocolUpgradeGovernance: technical specification required");
        require(_contractRegistry[targetContract].isUpgradeable, "ProtocolUpgradeGovernance: contract not upgradeable");
        
        proposalCounter++;
        uint256 proposalId = proposalCounter;
        
        UpgradeProposal storage proposal = _upgradeProposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.upgradeType = upgradeType;
        proposal.category = category;
        proposal.targetContract = targetContract;
        proposal.newImplementation = newImplementation;
        proposal.upgradeData = upgradeData;
        proposal.description = description;
        proposal.technicalSpecification = technicalSpecification;
        proposal.timestamp = block.timestamp;
        proposal.votingDeadline = block.timestamp + _getVotingPeriod(upgradeType);
        proposal.executionDeadline = proposal.votingDeadline + _getExecutionDelay(upgradeType);
        proposal.status = ProposalStatus.PENDING;
        proposal.proposer = msg.sender;
        proposal.requiresEmergencyOverride = (upgradeType == UpgradeType.EMERGENCY_UPGRADE);
        
        // Track proposal
        allUpgradeProposals.push(proposalId);
        proposalsByProposer[msg.sender].push(proposalId);
        proposalsByCategory[category].push(proposalId);
        
        // Update metrics
        _upgradeMetrics.totalProposals++;
        
        emit UpgradeProposalCreated(proposalId, upgradeType, category, targetContract, newImplementation, msg.sender);
        
        return proposalId;
    }
    
    /**
     * @dev Vote on upgrade proposal
     */
    function voteOnUpgrade(uint256 proposalId, bool support, uint256 votingPower) external validProposal(proposalId) whenNotPaused {
        UpgradeProposal storage proposal = _upgradeProposals[proposalId];
        require(proposal.status == ProposalStatus.VOTING || proposal.status == ProposalStatus.PENDING, "ProtocolUpgradeGovernance: proposal not in voting phase");
        require(block.timestamp <= proposal.votingDeadline, "ProtocolUpgradeGovernance: voting period ended");
        require(!_hasVoted[proposalId][msg.sender], "ProtocolUpgradeGovernance: already voted");
        require(votingPower > 0, "ProtocolUpgradeGovernance: no voting power");
        
        _hasVoted[proposalId][msg.sender] = true;
        _votes[proposalId][msg.sender] = votingPower;
        proposal.totalVotingPower += votingPower;
        
        if (support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        // Update status to voting if this is the first vote
        if (proposal.status == ProposalStatus.PENDING) {
            proposal.status = ProposalStatus.VOTING;
        }
        
        // Check if proposal passes threshold
        uint256 threshold = _getApprovalThreshold(proposal.upgradeType);
        uint256 approvalPercentage = proposal.votesFor.mulDiv(BASIS_POINTS, proposal.totalVotingPower);
        
        if (approvalPercentage >= threshold && block.timestamp >= proposal.votingDeadline) {
            proposal.status = ProposalStatus.APPROVED;
            upgradeSchedule[proposalId] = block.timestamp + _getExecutionDelay(proposal.upgradeType);
        }
    }
    
    /**
     * @dev Execute approved upgrade proposal
     */
    function executeUpgradeProposal(uint256 proposalId) external validProposal(proposalId) whenNotPaused nonReentrant {
        UpgradeProposal storage proposal = _upgradeProposals[proposalId];
        require(proposal.status == ProposalStatus.APPROVED, "ProtocolUpgradeGovernance: proposal not approved");
        require(block.timestamp >= upgradeSchedule[proposalId], "ProtocolUpgradeGovernance: execution delay not met");
        require(block.timestamp <= proposal.executionDeadline, "ProtocolUpgradeGovernance: proposal expired");
        
        // Require community oversight approval for major upgrades
        if (proposal.upgradeType == UpgradeType.MAJOR_UPGRADE) {
            require(
                oversightApprovals[proposalId] >= minimumOversightApprovals,
                "ProtocolUpgradeGovernance: insufficient community oversight approvals"
            );
        }
        
        // Update proposal status
        proposal.status = ProposalStatus.EXECUTED;
        
        // Update contract registry
        ContractRegistry storage registry = _contractRegistry[proposal.targetContract];
        registry.implementation = proposal.newImplementation;
        registry.lastUpgrade = block.timestamp;
        registry.version = _incrementVersion(registry.version);
        
        // Update metrics
        _upgradeMetrics.successfulUpgrades++;
        lastUpgradeTime[proposal.targetContract] = block.timestamp;
        
        emit UpgradeProposalExecuted(proposalId, proposal.targetContract, proposal.newImplementation, proposal.upgradeType);
    }
    
    // ============ PARAMETER CHANGE FUNCTIONS ============
    
    /**
     * @dev Propose parameter change
     */
    function proposeParameterChange(
        address targetContract,
        string memory parameterName,
        bytes32 newValue,
        string memory justification,
        uint256 impactAssessment
    ) external onlyParameterManager validContract(targetContract) whenNotPaused returns (uint256) {
        require(bytes(parameterName).length > 0, "ProtocolUpgradeGovernance: parameter name required");
        require(bytes(justification).length > 0, "ProtocolUpgradeGovernance: justification required");
        require(impactAssessment > 0 && impactAssessment <= 100, "ProtocolUpgradeGovernance: invalid impact assessment");
        
        proposalCounter++;
        uint256 proposalId = proposalCounter;
        
        bytes32 currentValue = _contractParameters[targetContract][parameterName];
        
        ParameterChange storage change = _parameterChanges[proposalId];
        change.proposalId = proposalId;
        change.targetContract = targetContract;
        change.parameterName = parameterName;
        change.currentValue = currentValue;
        change.newValue = newValue;
        change.timestamp = block.timestamp;
        change.executionTime = block.timestamp + PARAMETER_CHANGE_DELAY;
        change.status = ProposalStatus.PENDING;
        change.justification = justification;
        change.impactAssessment = impactAssessment;
        
        allParameterChanges.push(proposalId);
        
        emit ParameterChangeProposed(proposalId, targetContract, parameterName, currentValue, newValue);
        
        return proposalId;
    }
    
    /**
     * @dev Execute parameter change
     */
    function executeParameterChange(uint256 proposalId) external onlyParameterManager whenNotPaused {
        ParameterChange storage change = _parameterChanges[proposalId];
        require(change.proposalId != 0, "ProtocolUpgradeGovernance: parameter change does not exist");
        require(change.status == ProposalStatus.PENDING, "ProtocolUpgradeGovernance: parameter change not pending");
        require(block.timestamp >= change.executionTime, "ProtocolUpgradeGovernance: execution delay not met");
        
        // Update parameter
        updateContractParameter(change.targetContract, change.parameterName, change.newValue);
        
        // Update status
        change.status = ProposalStatus.EXECUTED;
        
        // Update metrics
        _upgradeMetrics.parameterChanges++;
        
        emit ParameterChangeExecuted(proposalId, change.targetContract, change.parameterName, change.newValue);
    }
    
    // ============ EMERGENCY UPGRADE FUNCTIONS ============
    
    /**
     * @dev Execute emergency upgrade
     */
    function executeEmergencyUpgrade(
        address targetContract,
        address newImplementation,
        string memory reason
    ) external onlyEmergencyUpgradeRole validContract(targetContract) whenNotPaused nonReentrant {
        require(newImplementation != address(0), "ProtocolUpgradeGovernance: invalid implementation");
        require(bytes(reason).length > 0, "ProtocolUpgradeGovernance: reason required");
        
        // Check emergency upgrade limits
        require(
            emergencyUpgradeCount[msg.sender] < MAX_EMERGENCY_UPGRADES_PER_MONTH,
            "ProtocolUpgradeGovernance: emergency upgrade limit exceeded"
        );
        
        proposalCounter++;
        uint256 proposalId = proposalCounter;
        
        // Create emergency proposal record
        UpgradeProposal storage proposal = _upgradeProposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.upgradeType = UpgradeType.EMERGENCY_UPGRADE;
        proposal.category = _contractRegistry[targetContract].category;
        proposal.targetContract = targetContract;
        proposal.newImplementation = newImplementation;
        proposal.description = string(abi.encodePacked("Emergency: ", reason));
        proposal.timestamp = block.timestamp;
        proposal.status = ProposalStatus.EMERGENCY_EXECUTED;
        proposal.proposer = msg.sender;
        
        // Update contract registry
        ContractRegistry storage registry = _contractRegistry[targetContract];
        registry.implementation = newImplementation;
        registry.lastUpgrade = block.timestamp;
        
        // Update tracking
        emergencyOverrides[proposalId] = true;
        emergencyUpgradeCount[msg.sender]++;
        _upgradeMetrics.emergencyUpgrades++;
        lastUpgradeTime[targetContract] = block.timestamp;
        
        emit EmergencyUpgradeExecuted(proposalId, targetContract, newImplementation, reason);
    }
    
    // ============ COMMUNITY OVERSIGHT FUNCTIONS ============
    
    /**
     * @dev Add community oversight member
     */
    function addCommunityOversight(address member) external onlyUpgradeGovernanceManager {
        require(member != address(0), "ProtocolUpgradeGovernance: invalid member address");
        require(!isOversightMember[member], "ProtocolUpgradeGovernance: member already added");
        
        isOversightMember[member] = true;
        totalOversightMembers++;
        
        // Grant oversight role
        _grantRole(COMMUNITY_OVERSIGHT_ROLE, member);
        
        emit CommunityOversightAdded(member);
    }
    
    /**
     * @dev Approve proposal as community oversight
     */
    function approveAsOversight(uint256 proposalId) external onlyCommunityOversight validProposal(proposalId) {
        require(!proposalReviews[proposalId][msg.sender], "ProtocolUpgradeGovernance: already reviewed");
        
        proposalReviews[proposalId][msg.sender] = true;
        oversightApprovals[proposalId]++;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get upgrade proposal details
     */
    function getUpgradeProposal(uint256 proposalId) external view validProposal(proposalId) returns (
        UpgradeType upgradeType,
        UpgradeCategory category,
        address targetContract,
        address newImplementation,
        string memory description,
        ProposalStatus status,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 totalVotingPower
    ) {
        UpgradeProposal storage proposal = _upgradeProposals[proposalId];
        return (
            proposal.upgradeType,
            proposal.category,
            proposal.targetContract,
            proposal.newImplementation,
            proposal.description,
            proposal.status,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.totalVotingPower
        );
    }
    
    /**
     * @dev Get contract registry info
     */
    function getContractRegistry(address contractAddress) external view returns (ContractRegistry memory) {
        return _contractRegistry[contractAddress];
    }
    
    /**
     * @dev Get upgrade metrics
     */
    function getUpgradeMetrics() external view returns (UpgradeMetrics memory) {
        return _upgradeMetrics;
    }
    
    /**
     * @dev Get parameter change details
     */
    function getParameterChange(uint256 proposalId) external view returns (ParameterChange memory) {
        return _parameterChanges[proposalId];
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _getVotingPeriod(UpgradeType upgradeType) internal pure returns (uint256) {
        if (upgradeType == UpgradeType.MAJOR_UPGRADE) return 7 days;
        if (upgradeType == UpgradeType.MINOR_UPGRADE) return 3 days;
        if (upgradeType == UpgradeType.PARAMETER_CHANGE) return 1 days;
        if (upgradeType == UpgradeType.EMERGENCY_UPGRADE) return 12 hours;
        return 3 days; // Default
    }
    
    function _getExecutionDelay(UpgradeType upgradeType) internal pure returns (uint256) {
        if (upgradeType == UpgradeType.MAJOR_UPGRADE) return UPGRADE_DELAY_MAXIMUM;
        if (upgradeType == UpgradeType.MINOR_UPGRADE) return UPGRADE_DELAY_MINIMUM;
        if (upgradeType == UpgradeType.PARAMETER_CHANGE) return PARAMETER_CHANGE_DELAY;
        if (upgradeType == UpgradeType.EMERGENCY_UPGRADE) return EMERGENCY_UPGRADE_DELAY;
        return UPGRADE_DELAY_MINIMUM; // Default
    }
    
    function _getApprovalThreshold(UpgradeType upgradeType) internal pure returns (uint256) {
        if (upgradeType == UpgradeType.MAJOR_UPGRADE) return MAJOR_UPGRADE_THRESHOLD;
        if (upgradeType == UpgradeType.MINOR_UPGRADE) return MINOR_UPGRADE_THRESHOLD;
        if (upgradeType == UpgradeType.PARAMETER_CHANGE) return PARAMETER_CHANGE_THRESHOLD;
        return MINOR_UPGRADE_THRESHOLD; // Default
    }
    
    function _incrementVersion(string memory currentVersion) internal pure returns (string memory) {
        // Simple version increment - in practice this would be more sophisticated
        return string(abi.encodePacked(currentVersion, ".1"));
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyEmergencyUpgradeRole {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyEmergencyUpgradeRole {
        _unpause();
    }
} 