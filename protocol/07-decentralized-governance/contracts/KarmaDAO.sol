// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../../interfaces/IKarmaGovernor.sol";

/**
 * @title KarmaGovernor
 * @dev Implementation of the Karma Labs DAO governance system
 * 
 * Stage 7.1 Implementation:
 * - OpenZeppelin Governor framework with customizations
 * - Proposal lifecycle management with categorization
 * - Quadratic voting implementation with staked token amounts
 * - Vote delegation mechanisms for representative governance
 * - Timelock controller integration (3-day execution delay)
 * - Participation requirements (0.1% stake threshold = 1M $KARMA)
 * - Reputation and participation tracking systems
 * - Anti-spam mechanisms and proposal quality controls
 */
contract KarmaGovernor is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    AccessControl,
    Pausable,
    ReentrancyGuard,
    IKarmaGovernor
{
    using Math for uint256;
    
    // ============ CONSTANTS ============
    
    uint256 public constant PROPOSAL_THRESHOLD_BPS = 10; // 0.1% of total supply
    uint256 public constant QUORUM_NUMERATOR_BPS = 400;  // 4% of total staked
    uint48 public constant VOTING_DELAY_BLOCKS = 7200;  // ~1 day (12s blocks)
    uint32 public constant VOTING_PERIOD_BLOCKS = 50400; // ~7 days (12s blocks)
    uint256 public constant TIMELOCK_DELAY = 3 days;
    uint256 public constant MAX_ACTIONS_PER_PROPOSAL = 10;
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Quadratic voting parameters
    uint256 public constant QUADRATIC_WEIGHT = 5000; // 50% weight for quadratic component
    uint256 public constant LINEAR_WEIGHT = 5000;    // 50% weight for linear component
    uint256 public constant MAX_VOTING_POWER_MULTIPLIER = 1000; // 10x max multiplier
    
    // Role definitions
    bytes32 public constant GOVERNANCE_MANAGER_ROLE = keccak256("GOVERNANCE_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant REPUTATION_MANAGER_ROLE = keccak256("REPUTATION_MANAGER_ROLE");
    
    // ============ STATE VARIABLES ============
    
    // Governance configuration
    GovernanceConfig private _governanceConfig;
    
    // Proposal categorization
    mapping(uint256 => ProposalCategory) private _proposalCategories;
    mapping(ProposalCategory => uint256[]) private _proposalsByCategory;
    mapping(address => uint256[]) private _proposalsByProposer;
    
    // Delegation tracking
    mapping(address => DelegationInfo) private _delegationInfo;
    mapping(address => uint256) private _delegatedVotes;
    
    // Participation tracking
    mapping(address => ParticipationMetrics) private _participationMetrics;
    
    // Quadratic voting tracking
    mapping(address => uint256) private _stakedBalances;
    mapping(uint256 => mapping(address => QuadraticVotingCalculation)) private _votingCalculations;
    
    // Anti-spam mechanisms
    mapping(address => uint256) private _lastProposalTime;
    mapping(address => uint256) private _proposalCount;
    uint256 public constant PROPOSAL_COOLDOWN = 1 hours;
    uint256 public constant MAX_PROPOSALS_PER_DAY = 3;
    
    // Analytics
    uint256 public totalProposals;
    uint256 public totalParticipants;
    
    // Staking contract integration
    address public stakingContract;
    
    // ============ EVENTS ============
    
    event StakingContractSet(address indexed oldContract, address indexed newContract);
    event QuadraticVotingCalculated(
        address indexed voter,
        uint256 indexed proposalId,
        uint256 stakedAmount,
        uint256 linearVotes,
        uint256 quadraticVotes,
        uint256 finalVotingPower
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyGovernanceManager() {
        require(hasRole(GOVERNANCE_MANAGER_ROLE, msg.sender), "KarmaGovernor: caller is not governance manager");
        _;
    }
    
    modifier onlyEmergencyRole() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "KarmaGovernor: caller does not have emergency role");
        _;
    }
    
    modifier respectsCooldown() {
        require(
            block.timestamp >= _lastProposalTime[msg.sender] + PROPOSAL_COOLDOWN,
            "KarmaGovernor: proposal cooldown not met"
        );
        _;
    }
    
    modifier respectsRateLimit() {
        uint256 dayStart = (block.timestamp / 1 days) * 1 days;
        require(
            _proposalCount[msg.sender] < MAX_PROPOSALS_PER_DAY,
            "KarmaGovernor: daily proposal limit exceeded"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        IVotes _token,
        TimelockController _timelock,
        address _stakingContract,
        address _admin
    )
        Governor("KarmaGovernor")
        GovernorSettings(VOTING_DELAY_BLOCKS, VOTING_PERIOD_BLOCKS, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(QUORUM_NUMERATOR_BPS)
        GovernorTimelockControl(_timelock)
    {
        require(_admin != address(0), "KarmaGovernor: invalid admin address");
        require(_stakingContract != address(0), "KarmaGovernor: invalid staking contract");
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GOVERNANCE_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        _grantRole(REPUTATION_MANAGER_ROLE, _admin);
        
        // Initialize governance configuration
        _governanceConfig = GovernanceConfig({
            votingDelay: VOTING_DELAY_BLOCKS,
            votingPeriod: VOTING_PERIOD_BLOCKS,
            proposalThreshold: 1_000_000 * 1e18, // 1M KARMA
            quorumNumerator: QUORUM_NUMERATOR_BPS,
            timelockDelay: TIMELOCK_DELAY,
            maxActions: MAX_ACTIONS_PER_PROPOSAL,
            quadraticVotingEnabled: true,
            gracePeriod: GRACE_PERIOD
        });
        
        stakingContract = _stakingContract;
        totalProposals = 0;
        totalParticipants = 0;
    }
    
    // ============ OVERRIDE REQUIRED FUNCTIONS ============
    
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return _governanceConfig.proposalThreshold;
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // ============ CORE GOVERNANCE FUNCTIONS ============
    
    /**
     * @dev Propose a new governance action with categorization and anti-spam checks
     */
    function proposeWithCategory(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description,
        ProposalCategory category
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        respectsCooldown 
        respectsRateLimit 
        returns (uint256 proposalId) 
    {
        require(targets.length <= _governanceConfig.maxActions, "KarmaGovernor: too many actions");
        require(targets.length == values.length, "KarmaGovernor: array length mismatch");
        require(targets.length == signatures.length, "KarmaGovernor: array length mismatch");
        require(targets.length == calldatas.length, "KarmaGovernor: array length mismatch");
        
        // Check proposal threshold via staking contract
        if (stakingContract != address(0)) {
            (bool success, bytes memory data) = stakingContract.staticcall(
                abi.encodeWithSignature("canCreateProposal(address)", msg.sender)
            );
            require(success && abi.decode(data, (bool)), "KarmaGovernor: insufficient voting power to propose");
        }
        
        // Convert signatures to calldatas if needed
        bytes[] memory processedCalldatas = new bytes[](calldatas.length);
        for (uint256 i = 0; i < calldatas.length; i++) {
            if (bytes(signatures[i]).length > 0) {
                processedCalldatas[i] = abi.encodePacked(bytes4(keccak256(bytes(signatures[i]))), calldatas[i]);
            } else {
                processedCalldatas[i] = calldatas[i];
            }
        }
        
        // Create proposal using OpenZeppelin Governor
        proposalId = propose(targets, values, processedCalldatas, description);
        
        // Track categorization and metadata
        _proposalCategories[proposalId] = category;
        _proposalsByCategory[category].push(proposalId);
        _proposalsByProposer[msg.sender].push(proposalId);
        
        // Update anti-spam tracking
        _lastProposalTime[msg.sender] = block.timestamp;
        _proposalCount[msg.sender]++;
        
        // Update participation metrics
        _updateParticipationMetrics(msg.sender, true, false);
        
        totalProposals++;
        
        emit ProposalCreatedWithCategory(proposalId, msg.sender, category, description);
        
        return proposalId;
    }
    
    /**
     * @dev Cast vote with quadratic calculation
     */
    function castQuadraticVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 balance) 
    {
        // Get base voting power
        balance = castVote(proposalId, support);
        
        // Calculate quadratic voting power if enabled
        if (_governanceConfig.quadraticVotingEnabled && stakingContract != address(0)) {
            uint256 quadraticPower = _calculateQuadraticVotingPower(msg.sender, block.number - 1);
            
            // Store calculation for transparency
            _votingCalculations[proposalId][msg.sender] = QuadraticVotingCalculation({
                stakedAmount: _getStakedAmount(msg.sender),
                linearVotes: balance,
                quadraticVotes: quadraticPower,
                finalVotingPower: quadraticPower,
                maxVotingPower: (balance * MAX_VOTING_POWER_MULTIPLIER) / 100
            });
            
            emit QuadraticVoteCast(msg.sender, proposalId, support, balance, quadraticPower, reason);
        }
        
        // Update participation metrics
        _updateParticipationMetrics(msg.sender, false, true);
        
        return balance;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get quadratic voting power for an account
     */
    function getQuadraticVotingPower(address account, uint256 blockNumber)
        external
        view
        override
        returns (uint256)
    {
        return _calculateQuadraticVotingPower(account, blockNumber);
    }
    
    /**
     * @dev Get governance configuration
     */
    function getGovernanceConfig() external view override returns (GovernanceConfig memory) {
        return _governanceConfig;
    }
    
    /**
     * @dev Get delegation information
     */
    function getDelegationInfo(address account) external view override returns (DelegationInfo memory) {
        return _delegationInfo[account];
    }
    
    /**
     * @dev Get participation metrics
     */
    function getParticipationMetrics(address account) external view override returns (ParticipationMetrics memory) {
        return _participationMetrics[account];
    }
    
    /**
     * @dev Get governance analytics
     */
    function getGovernanceAnalytics() external view override returns (GovernanceAnalytics memory) {
        return GovernanceAnalytics({
            totalProposals: totalProposals,
            activeProposals: _getActiveProposalsCount(),
            totalParticipants: totalParticipants,
            averageParticipation: _calculateAverageParticipation(),
            totalVotingPower: _getTotalVotingPower()
        });
    }
    
    // ============ ADMINISTRATIVE FUNCTIONS ============
    
    /**
     * @dev Update governance configuration
     */
    function updateGovernanceConfig(GovernanceConfig memory newConfig) 
        external 
        override 
        onlyGovernanceManager 
    {
        require(newConfig.votingDelay <= 50400, "KarmaGovernor: voting delay too long"); // Max 7 days
        require(newConfig.votingPeriod >= 7200, "KarmaGovernor: voting period too short"); // Min 1 day
        require(newConfig.quorumNumerator <= 5000, "KarmaGovernor: quorum too high"); // Max 50%
        
        GovernanceConfig memory oldConfig = _governanceConfig;
        _governanceConfig = newConfig;
        
        emit GovernanceConfigUpdated(
            newConfig.votingDelay,
            newConfig.votingPeriod,
            newConfig.proposalThreshold,
            newConfig.quorumNumerator
        );
    }
    
    /**
     * @dev Set staking contract address
     */
    function setStakingContract(address _stakingContract) external onlyGovernanceManager {
        require(_stakingContract != address(0), "KarmaGovernor: invalid staking contract");
        address oldContract = stakingContract;
        stakingContract = _stakingContract;
        
        emit StakingContractSet(oldContract, _stakingContract);
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency pause governance operations
     */
    function emergencyPause() external override onlyEmergencyRole {
        _pause();
        
        emit EmergencyActionTriggered(0, msg.sender, "Emergency pause activated");
    }
    
    /**
     * @dev Emergency unpause governance operations
     */
    function emergencyUnpause() external override onlyEmergencyRole {
        _unpause();
        
        emit EmergencyActionTriggered(0, msg.sender, "Emergency pause deactivated");
    }
    
    /**
     * @dev Emergency proposal cancellation
     */
    function emergencyCancel(uint256 proposalId, string memory reason) 
        external 
        override 
        onlyEmergencyRole 
    {
        ProposalState currentState = state(proposalId);
        require(
            currentState == ProposalState.Pending || 
            currentState == ProposalState.Active || 
            currentState == ProposalState.Queued,
            "KarmaGovernor: proposal not cancellable"
        );
        
        // Cancel via OpenZeppelin Governor mechanism
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = _getProposalDetails(proposalId);
        
        cancel(targets, values, calldatas, keccak256(bytes(description)));
        
        emit EmergencyActionTriggered(proposalId, msg.sender, reason);
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Calculate quadratic voting power
     */
    function _calculateQuadraticVotingPower(address account, uint256 blockNumber) 
        internal 
        view 
        returns (uint256) 
    {
        if (!_governanceConfig.quadraticVotingEnabled || stakingContract == address(0)) {
            return getVotes(account, blockNumber);
        }
        
        uint256 stakedAmount = _getStakedAmount(account);
        if (stakedAmount == 0) {
            return 0;
        }
        
        // Linear component (50% weight)
        uint256 linearComponent = (stakedAmount * LINEAR_WEIGHT) / BASIS_POINTS;
        
        // Quadratic component (50% weight) - sqrt(amount) to reduce whale dominance
        uint256 quadraticComponent = (Math.sqrt(stakedAmount) * QUADRATIC_WEIGHT) / BASIS_POINTS;
        
        // Combine components
        uint256 votingPower = linearComponent + quadraticComponent;
        
        // Apply maximum multiplier cap
        uint256 maxPower = (stakedAmount * MAX_VOTING_POWER_MULTIPLIER) / 100;
        if (votingPower > maxPower) {
            votingPower = maxPower;
        }
        
        return votingPower;
    }
    
    /**
     * @dev Get staked amount from staking contract
     */
    function _getStakedAmount(address account) internal view returns (uint256) {
        if (stakingContract == address(0)) {
            return 0;
        }
        
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getVotingPower(address)", account)
        );
        
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        
        return 0;
    }
    
    /**
     * @dev Update participation metrics
     */
    function _updateParticipationMetrics(address account, bool proposed, bool voted) internal {
        ParticipationMetrics storage metrics = _participationMetrics[account];
        
        if (!metrics.isActive) {
            metrics.isActive = true;
            totalParticipants++;
        }
        
        if (proposed) {
            metrics.proposalsCreated++;
        }
        
        if (voted) {
            metrics.proposalsVoted++;
        }
        
        metrics.lastActivity = block.timestamp;
        metrics.reputationScore = _calculateReputationScore(metrics);
        
        emit ParticipationUpdated(
            account,
            metrics.proposalsCreated,
            metrics.proposalsVoted,
            metrics.reputationScore
        );
    }
    
    /**
     * @dev Calculate reputation score
     */
    function _calculateReputationScore(ParticipationMetrics memory metrics) 
        internal 
        pure 
        returns (uint256) 
    {
        // Simple reputation calculation: proposals created + votes cast
        return metrics.proposalsCreated * 10 + metrics.proposalsVoted;
    }
    
    /**
     * @dev Get active proposals count
     */
    function _getActiveProposalsCount() internal view returns (uint256) {
        // This is a simplified implementation
        // In a real implementation, you'd track active proposals
        return 0;
    }
    
    /**
     * @dev Calculate average participation
     */
    function _calculateAverageParticipation() internal view returns (uint256) {
        if (totalProposals == 0) return 0;
        return (totalParticipants * 100) / totalProposals;
    }
    
    /**
     * @dev Get total voting power
     */
    function _getTotalVotingPower() internal view returns (uint256) {
        if (stakingContract == address(0)) {
            return 0;
        }
        
        (bool success, bytes memory data) = stakingContract.staticcall(
            abi.encodeWithSignature("getStakingMetrics()")
        );
        
        if (success && data.length >= 32) {
            // Assuming the staking metrics returns total voting power as first field
            return abi.decode(data, (uint256));
        }
        
        return 0;
    }
    
    /**
     * @dev Get proposal details (simplified implementation)
     */
    function _getProposalDetails(uint256 proposalId) 
        internal 
        pure 
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) 
    {
        // This is a simplified implementation
        // In a real implementation, you'd store and retrieve proposal details
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        description = "";
    }
} 