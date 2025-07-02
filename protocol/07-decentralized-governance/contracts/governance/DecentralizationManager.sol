// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DecentralizationManager
 * @dev Stage 7.2 Progressive Decentralization
 * 
 * Requirements:
 * - Create transition mechanisms from team control to community control
 * - Implement gradual governance power transfer over time
 * - Build emergency intervention capabilities with community override
 * - Add governance analytics and participation tracking
 */
contract DecentralizationManager is AccessControl, Pausable, ReentrancyGuard {
    using Math for uint256;
    
    // ============ CONSTANTS ============
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DECENTRALIZATION_DURATION = 365 days; // 1 year transition
    uint256 public constant PHASE_DURATION = 90 days; // 3 months per phase
    uint256 public constant MIN_COMMUNITY_PARTICIPATION = 1000; // 10% participation
    uint256 public constant EMERGENCY_INTERVENTION_COOLDOWN = 30 days;
    uint256 public constant GOVERNANCE_MILESTONE_THRESHOLD = 5000; // 50% community control
    
    // Role definitions
    bytes32 public constant DECENTRALIZATION_MANAGER_ROLE = keccak256("DECENTRALIZATION_MANAGER_ROLE");
    bytes32 public constant TEAM_CONTROL_ROLE = keccak256("TEAM_CONTROL_ROLE");
    bytes32 public constant COMMUNITY_REPRESENTATIVE_ROLE = keccak256("COMMUNITY_REPRESENTATIVE_ROLE");
    bytes32 public constant EMERGENCY_INTERVENTION_ROLE = keccak256("EMERGENCY_INTERVENTION_ROLE");
    bytes32 public constant ANALYTICS_MANAGER_ROLE = keccak256("ANALYTICS_MANAGER_ROLE");
    
    // ============ ENUMS ============
    
    enum DecentralizationPhase {
        TEAM_CONTROL,        // Phase 0: Full team control (0-3 months)
        INITIAL_TRANSITION,  // Phase 1: 25% community control (3-6 months)
        BALANCED_CONTROL,    // Phase 2: 50% community control (6-9 months)
        COMMUNITY_MAJORITY,  // Phase 3: 75% community control (9-12 months)
        FULL_DECENTRALIZATION // Phase 4: 95% community control (12+ months)
    }
    
    enum ControlType {
        TREASURY_CONTROL,    // Control over treasury operations
        GOVERNANCE_CONTROL,  // Control over governance parameters
        UPGRADE_CONTROL,     // Control over contract upgrades
        PARAMETER_CONTROL,   // Control over system parameters
        EMERGENCY_CONTROL,   // Emergency intervention capabilities
        ROLE_MANAGEMENT     // Control over role assignments
    }
    
    enum InterventionType {
        EMERGENCY_PAUSE,     // Emergency pause intervention
        GOVERNANCE_OVERRIDE, // Override governance decision
        PARAMETER_RESET,     // Reset critical parameters
        ROLE_REVOCATION,     // Emergency role revocation
        FUND_PROTECTION     // Protect treasury funds
    }
    
    // ============ STRUCTS ============
    
    struct DecentralizationMilestone {
        DecentralizationPhase phase;
        uint256 startTime;
        uint256 endTime;
        uint256 teamControlPercentage;
        uint256 communityControlPercentage;
        bool isActive;
        bool isCompleted;
        string[] requirements;
        string[] achievements;
    }
    
    struct ControlTransition {
        ControlType controlType;
        uint256 transitionId;
        address fromController;
        address toController;
        uint256 transferAmount; // Percentage of control being transferred
        uint256 scheduledTime;
        uint256 executedTime;
        bool isExecuted;
        bool requiresCommunityApproval;
        uint256 communityVotes;
        uint256 requiredVotes;
        string justification;
    }
    
    struct EmergencyIntervention {
        uint256 interventionId;
        InterventionType interventionType;
        address executor;
        address targetContract;
        bytes interventionData;
        string reason;
        uint256 timestamp;
        uint256 expirationTime;
        bool isExecuted;
        bool isCommunityOverridden;
        uint256 communityOverrideVotes;
        uint256 requiredOverrideVotes;
    }
    
    struct GovernanceMetrics {
        uint256 totalProposals;
        uint256 communityProposals;
        uint256 teamProposals;
        uint256 totalVotes;
        uint256 uniqueVoters;
        uint256 averageParticipationRate;
        uint256 communityEngagementScore;
        uint256 decentralizationScore;
    }
    
    struct CommunityReadiness {
        uint256 participationRate;
        uint256 governanceExperience;
        uint256 stakingParticipation;
        uint256 proposalQuality;
        uint256 votingConsistency;
        uint256 overallScore;
        bool isReady;
        string[] improvementAreas;
    }
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaGovernor;
    address public stakingContract;
    address public treasury;
    address public upgradeGovernance;
    
    // Decentralization data
    mapping(uint256 => DecentralizationMilestone) private _milestones;
    mapping(uint256 => ControlTransition) private _controlTransitions;
    mapping(uint256 => EmergencyIntervention) private _emergencyInterventions;
    mapping(uint256 => mapping(address => bool)) private _hasVotedIntervention;
    mapping(ControlType => mapping(uint256 => uint256)) private _controlDistribution;
    mapping(uint256 => uint256) private _monthlyActivity;
    mapping(address => uint256) private _userParticipation;
    
    GovernanceMetrics private _governanceMetrics;
    CommunityReadiness private _communityReadiness;
    
    // Current state
    DecentralizationPhase public currentPhase;
    uint256 public decentralizationStartTime;
    uint256 public currentMilestone;
    uint256 public totalControlTransitions;
    uint256 public totalEmergencyInterventions;
    
    // Control distribution
    mapping(ControlType => uint256) public teamControlPercentage;
    mapping(ControlType => uint256) public communityControlPercentage;
    mapping(ControlType => mapping(address => uint256)) public controllerPower;
    
    // Emergency tracking
    mapping(address => uint256) public lastInterventionTime;
    mapping(uint256 => bool) public interventionApprovals;
    uint256 public totalInterventionCount;
    
    // Analytics tracking
    mapping(address => uint256) public userGovernanceScore;
    mapping(address => uint256) public lastActivityTime;
    mapping(uint256 => uint256) public phaseTransitionTimes;
    
    // ============ EVENTS ============
    
    event DecentralizationPhaseChanged(
        DecentralizationPhase indexed oldPhase,
        DecentralizationPhase indexed newPhase,
        uint256 timestamp
    );
    
    event ControlTransitionScheduled(
        uint256 indexed transitionId,
        ControlType indexed controlType,
        address fromController,
        address toController,
        uint256 transferAmount,
        uint256 scheduledTime
    );
    
    event ControlTransitionExecuted(
        uint256 indexed transitionId,
        ControlType indexed controlType,
        address fromController,
        address toController,
        uint256 transferAmount
    );
    
    event EmergencyInterventionExecuted(
        uint256 indexed interventionId,
        InterventionType indexed interventionType,
        address indexed executor,
        address targetContract,
        string reason
    );
    
    event CommunityOverride(
        uint256 indexed interventionId,
        uint256 overrideVotes,
        uint256 requiredVotes
    );
    
    event MilestoneCompleted(
        uint256 indexed milestoneId,
        DecentralizationPhase phase,
        uint256 completionTime
    );
    
    event GovernanceMetricsUpdated(
        uint256 totalProposals,
        uint256 uniqueVoters,
        uint256 participationRate,
        uint256 decentralizationScore
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyDecentralizationManager() {
        require(hasRole(DECENTRALIZATION_MANAGER_ROLE, msg.sender), "DecentralizationManager: caller is not decentralization manager");
        _;
    }
    
    modifier onlyTeamControl() {
        require(hasRole(TEAM_CONTROL_ROLE, msg.sender), "DecentralizationManager: caller does not have team control");
        _;
    }
    
    modifier onlyCommunityRepresentative() {
        require(hasRole(COMMUNITY_REPRESENTATIVE_ROLE, msg.sender), "DecentralizationManager: caller is not community representative");
        _;
    }
    
    modifier onlyEmergencyIntervention() {
        require(hasRole(EMERGENCY_INTERVENTION_ROLE, msg.sender), "DecentralizationManager: caller does not have emergency intervention role");
        _;
    }
    
    modifier onlyAnalyticsManager() {
        require(hasRole(ANALYTICS_MANAGER_ROLE, msg.sender), "DecentralizationManager: caller is not analytics manager");
        _;
    }
    
    modifier validTransition(uint256 transitionId) {
        require(transitionId > 0 && transitionId <= totalControlTransitions, "DecentralizationManager: invalid transition ID");
        _;
    }
    
    modifier validIntervention(uint256 interventionId) {
        require(interventionId > 0 && interventionId <= totalEmergencyInterventions, "DecentralizationManager: invalid intervention ID");
        _;
    }
    
    modifier respectsInterventionCooldown() {
        require(
            block.timestamp >= lastInterventionTime[msg.sender] + EMERGENCY_INTERVENTION_COOLDOWN,
            "DecentralizationManager: intervention cooldown not met"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaGovernor,
        address _stakingContract,
        address _treasury,
        address _upgradeGovernance,
        address _admin
    ) {
        require(_karmaGovernor != address(0), "DecentralizationManager: invalid governor address");
        require(_stakingContract != address(0), "DecentralizationManager: invalid staking contract");
        require(_treasury != address(0), "DecentralizationManager: invalid treasury address");
        require(_upgradeGovernance != address(0), "DecentralizationManager: invalid upgrade governance address");
        require(_admin != address(0), "DecentralizationManager: invalid admin address");
        
        karmaGovernor = _karmaGovernor;
        stakingContract = _stakingContract;
        treasury = _treasury;
        upgradeGovernance = _upgradeGovernance;
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DECENTRALIZATION_MANAGER_ROLE, _admin);
        _grantRole(TEAM_CONTROL_ROLE, _admin);
        _grantRole(EMERGENCY_INTERVENTION_ROLE, _admin);
        _grantRole(ANALYTICS_MANAGER_ROLE, _admin);
        
        // Initialize decentralization
        currentPhase = DecentralizationPhase.TEAM_CONTROL;
        decentralizationStartTime = block.timestamp;
        currentMilestone = 0;
        
        _initializeControlDistribution();
        _initializeMilestones();
    }
    
    // ============ PHASE MANAGEMENT FUNCTIONS ============
    
    /**
     * @dev Initiate decentralization process
     */
    function initiateDecentralization() external onlyDecentralizationManager {
        require(currentPhase == DecentralizationPhase.TEAM_CONTROL, "DecentralizationManager: decentralization already initiated");
        
        decentralizationStartTime = block.timestamp;
        
        emit DecentralizationPhaseChanged(currentPhase, DecentralizationPhase.INITIAL_TRANSITION, block.timestamp);
    }
    
    /**
     * @dev Advance to next decentralization phase
     */
    function advancePhase() external onlyDecentralizationManager {
        require(currentPhase != DecentralizationPhase.FULL_DECENTRALIZATION, "DecentralizationManager: already fully decentralized");
        require(_checkPhaseRequirements(currentPhase), "DecentralizationManager: phase requirements not met");
        
        DecentralizationPhase oldPhase = currentPhase;
        currentPhase = DecentralizationPhase(uint256(currentPhase) + 1);
        
        // Complete current milestone
        _milestones[currentMilestone].isCompleted = true;
        
        // Start next milestone
        currentMilestone++;
        _milestones[currentMilestone].isActive = true;
        _milestones[currentMilestone].startTime = block.timestamp;
        
        phaseTransitionTimes[uint256(currentPhase)] = block.timestamp;
        
        // Execute phase transition logic
        _executePhaseTransition(oldPhase, currentPhase);
        
        emit DecentralizationPhaseChanged(oldPhase, currentPhase, block.timestamp);
        emit MilestoneCompleted(currentMilestone - 1, oldPhase, block.timestamp);
    }
    
    // ============ CONTROL TRANSITION FUNCTIONS ============
    
    /**
     * @dev Schedule control transition
     */
    function scheduleControlTransition(
        ControlType controlType,
        address fromController,
        address toController,
        uint256 transferAmount,
        uint256 scheduledTime,
        bool requiresCommunityApproval,
        string memory justification
    ) external onlyDecentralizationManager returns (uint256) {
        require(transferAmount > 0 && transferAmount <= BASIS_POINTS, "DecentralizationManager: invalid transfer amount");
        require(scheduledTime > block.timestamp, "DecentralizationManager: invalid scheduled time");
        require(bytes(justification).length > 0, "DecentralizationManager: justification required");
        
        totalControlTransitions++;
        uint256 transitionId = totalControlTransitions;
        
        ControlTransition storage transition = _controlTransitions[transitionId];
        transition.controlType = controlType;
        transition.transitionId = transitionId;
        transition.fromController = fromController;
        transition.toController = toController;
        transition.transferAmount = transferAmount;
        transition.scheduledTime = scheduledTime;
        transition.requiresCommunityApproval = requiresCommunityApproval;
        transition.justification = justification;
        
        if (requiresCommunityApproval) {
            transition.requiredVotes = _calculateRequiredVotes();
        }
        
        emit ControlTransitionScheduled(transitionId, controlType, fromController, toController, transferAmount, scheduledTime);
        
        return transitionId;
    }
    
    /**
     * @dev Execute control transition
     */
    function executeControlTransition(uint256 transitionId) external validTransition(transitionId) onlyDecentralizationManager {
        ControlTransition storage transition = _controlTransitions[transitionId];
        require(!transition.isExecuted, "DecentralizationManager: transition already executed");
        require(block.timestamp >= transition.scheduledTime, "DecentralizationManager: transition not ready for execution");
        
        if (transition.requiresCommunityApproval) {
            require(transition.communityVotes >= transition.requiredVotes, "DecentralizationManager: insufficient community approval");
        }
        
        // Execute the transition
        _executeControlTransfer(transition);
        
        transition.isExecuted = true;
        transition.executedTime = block.timestamp;
        
        emit ControlTransitionExecuted(
            transitionId,
            transition.controlType,
            transition.fromController,
            transition.toController,
            transition.transferAmount
        );
    }
    
    // ============ EMERGENCY INTERVENTION FUNCTIONS ============
    
    /**
     * @dev Execute emergency intervention
     */
    function executeEmergencyIntervention(
        InterventionType interventionType,
        address targetContract,
        bytes memory interventionData,
        string memory reason
    ) external onlyEmergencyIntervention respectsInterventionCooldown whenNotPaused nonReentrant returns (uint256) {
        require(targetContract != address(0), "DecentralizationManager: invalid target contract");
        require(bytes(reason).length > 0, "DecentralizationManager: reason required");
        
        totalEmergencyInterventions++;
        uint256 interventionId = totalEmergencyInterventions;
        
        EmergencyIntervention storage intervention = _emergencyInterventions[interventionId];
        intervention.interventionId = interventionId;
        intervention.interventionType = interventionType;
        intervention.executor = msg.sender;
        intervention.targetContract = targetContract;
        intervention.interventionData = interventionData;
        intervention.reason = reason;
        intervention.timestamp = block.timestamp;
        intervention.expirationTime = block.timestamp + 7 days;
        intervention.requiredOverrideVotes = _calculateRequiredOverrideVotes();
        intervention.isExecuted = true;
        
        // Update tracking
        lastInterventionTime[msg.sender] = block.timestamp;
        totalInterventionCount++;
        
        emit EmergencyInterventionExecuted(interventionId, interventionType, msg.sender, targetContract, reason);
        
        return interventionId;
    }
    
    /**
     * @dev Community override of emergency intervention
     */
    function overrideEmergencyIntervention(uint256 interventionId) external validIntervention(interventionId) {
        EmergencyIntervention storage intervention = _emergencyInterventions[interventionId];
        require(intervention.isExecuted, "DecentralizationManager: intervention not executed");
        require(!intervention.isCommunityOverridden, "DecentralizationManager: already overridden");
        require(block.timestamp <= intervention.expirationTime, "DecentralizationManager: override period expired");
        require(!_hasVotedIntervention[interventionId][msg.sender], "DecentralizationManager: already voted");
        
        uint256 votingPower = _getVotingPower(msg.sender);
        require(votingPower > 0, "DecentralizationManager: no voting power");
        
        _hasVotedIntervention[interventionId][msg.sender] = true;
        intervention.communityOverrideVotes += votingPower;
        
        if (intervention.communityOverrideVotes >= intervention.requiredOverrideVotes) {
            intervention.isCommunityOverridden = true;
            
            emit CommunityOverride(interventionId, intervention.communityOverrideVotes, intervention.requiredOverrideVotes);
        }
        
        // Update user governance score
        userGovernanceScore[msg.sender] += 15; // Higher score for oversight
        lastActivityTime[msg.sender] = block.timestamp;
    }
    
    // ============ ANALYTICS AND TRACKING FUNCTIONS ============
    
    /**
     * @dev Update governance metrics
     */
    function updateGovernanceMetrics(
        uint256 totalProposals,
        uint256 communityProposals,
        uint256 totalVotes,
        uint256 uniqueVoters
    ) external onlyAnalyticsManager {
        _governanceMetrics.totalProposals = totalProposals;
        _governanceMetrics.communityProposals = communityProposals;
        _governanceMetrics.totalVotes = totalVotes;
        _governanceMetrics.uniqueVoters = uniqueVoters;
        
        if (totalProposals > 0) {
            _governanceMetrics.averageParticipationRate = (uniqueVoters * BASIS_POINTS) / totalProposals;
        }
        
        // Calculate community engagement score
        _governanceMetrics.communityEngagementScore = _calculateCommunityEngagement();
        
        // Calculate decentralization score
        _governanceMetrics.decentralizationScore = _calculateDecentralizationScore();
        
        // Update monthly activity
        uint256 currentMonth = block.timestamp / 30 days;
        _monthlyActivity[currentMonth] = _governanceMetrics.communityEngagementScore;
        
        emit GovernanceMetricsUpdated(
            totalProposals,
            uniqueVoters,
            _governanceMetrics.averageParticipationRate,
            _governanceMetrics.decentralizationScore
        );
    }
    
    /**
     * @dev Update user participation
     */
    function updateUserParticipation(address user, uint256 participationScore) external onlyAnalyticsManager {
        _userParticipation[user] = participationScore;
        userGovernanceScore[user] = participationScore;
        lastActivityTime[user] = block.timestamp;
        
        // Update community readiness assessment
        _updateCommunityReadiness();
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get current decentralization status
     */
    function getDecentralizationStatus() external view returns (
        DecentralizationPhase phase,
        uint256 startTime,
        uint256 currentMilestoneId,
        uint256 teamControl,
        uint256 communityControl,
        uint256 decentralizationScore
    ) {
        return (
            currentPhase,
            decentralizationStartTime,
            currentMilestone,
            _getAverageTeamControl(),
            _getAverageCommunityControl(),
            _governanceMetrics.decentralizationScore
        );
    }
    
    /**
     * @dev Get control distribution for specific type
     */
    function getControlDistribution(ControlType controlType) external view returns (
        uint256 teamPercentage,
        uint256 communityPercentage
    ) {
        return (
            teamControlPercentage[controlType],
            communityControlPercentage[controlType]
        );
    }
    
    /**
     * @dev Get control transition details
     */
    function getControlTransition(uint256 transitionId) external view validTransition(transitionId) returns (ControlTransition memory) {
        return _controlTransitions[transitionId];
    }
    
    /**
     * @dev Get governance metrics
     */
    function getGovernanceMetrics() external view returns (GovernanceMetrics memory) {
        return _governanceMetrics;
    }
    
    /**
     * @dev Get community readiness assessment
     */
    function getCommunityReadiness() external view returns (CommunityReadiness memory) {
        return _communityReadiness;
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _initializeControlDistribution() internal {
        // Initialize with full team control
        for (uint256 i = 0; i < 6; i++) {
            ControlType controlType = ControlType(i);
            teamControlPercentage[controlType] = BASIS_POINTS; // 100%
            communityControlPercentage[controlType] = 0;
        }
    }
    
    function _initializeMilestones() internal {
        // Create milestone structure for each phase
        for (uint256 i = 0; i < 5; i++) {
            DecentralizationPhase phase = DecentralizationPhase(i);
            DecentralizationMilestone storage milestone = _milestones[i];
            milestone.phase = phase;
            milestone.startTime = decentralizationStartTime + (i * PHASE_DURATION);
            milestone.endTime = milestone.startTime + PHASE_DURATION;
            
            if (i == 0) {
                milestone.teamControlPercentage = BASIS_POINTS;
                milestone.communityControlPercentage = 0;
                milestone.isActive = true;
            } else if (i == 1) {
                milestone.teamControlPercentage = 7500; // 75%
                milestone.communityControlPercentage = 2500; // 25%
            } else if (i == 2) {
                milestone.teamControlPercentage = 5000; // 50%
                milestone.communityControlPercentage = 5000; // 50%
            } else if (i == 3) {
                milestone.teamControlPercentage = 2500; // 25%
                milestone.communityControlPercentage = 7500; // 75%
            } else {
                milestone.teamControlPercentage = 500; // 5%
                milestone.communityControlPercentage = 9500; // 95%
            }
        }
    }
    
    function _executePhaseTransition(DecentralizationPhase oldPhase, DecentralizationPhase newPhase) internal {
        // Execute control transfers for the new phase
        for (uint256 i = 0; i < 6; i++) {
            ControlType controlType = ControlType(i);
            uint256 transferAmount = _getTransferAmount(newPhase, controlType);
            
            if (transferAmount > 0) {
                teamControlPercentage[controlType] -= transferAmount;
                communityControlPercentage[controlType] += transferAmount;
            }
        }
    }
    
    function _executeControlTransfer(ControlTransition storage transition) internal {
        // Update control percentages
        controllerPower[transition.controlType][transition.fromController] -= transition.transferAmount;
        controllerPower[transition.controlType][transition.toController] += transition.transferAmount;
        
        // Update global percentages if transferring between team and community
        if (hasRole(TEAM_CONTROL_ROLE, transition.fromController) && 
            hasRole(COMMUNITY_REPRESENTATIVE_ROLE, transition.toController)) {
            teamControlPercentage[transition.controlType] -= transition.transferAmount;
            communityControlPercentage[transition.controlType] += transition.transferAmount;
        }
    }
    
    function _checkPhaseRequirements(DecentralizationPhase phase) internal view returns (bool) {
        // Check if requirements for advancing from current phase are met
        if (phase == DecentralizationPhase.TEAM_CONTROL) {
            return _governanceMetrics.averageParticipationRate >= MIN_COMMUNITY_PARTICIPATION;
        } else if (phase == DecentralizationPhase.INITIAL_TRANSITION) {
            return _communityReadiness.overallScore >= 6000; // 60%
        } else if (phase == DecentralizationPhase.BALANCED_CONTROL) {
            return _communityReadiness.overallScore >= 7500; // 75%
        } else if (phase == DecentralizationPhase.COMMUNITY_MAJORITY) {
            return _communityReadiness.overallScore >= 9000; // 90%
        }
        return true;
    }
    
    function _getTransferAmount(DecentralizationPhase phase, ControlType controlType) internal pure returns (uint256) {
        // Calculate transfer amount based on phase and control type
        if (phase == DecentralizationPhase.INITIAL_TRANSITION) {
            return 2500; // 25% transfer
        } else if (phase == DecentralizationPhase.BALANCED_CONTROL) {
            return 2500; // Another 25% transfer
        } else if (phase == DecentralizationPhase.COMMUNITY_MAJORITY) {
            return 2500; // Another 25% transfer
        } else if (phase == DecentralizationPhase.FULL_DECENTRALIZATION) {
            return 2000; // Final 20% transfer (keeping 5% for emergency)
        }
        return 0;
    }
    
    function _getVotingPower(address user) internal view returns (uint256) {
        // Get voting power from staking contract
        // This would integrate with the actual staking contract
        return userGovernanceScore[user];
    }
    
    function _calculateRequiredVotes() internal view returns (uint256) {
        // Calculate required votes based on current community participation
        uint256 totalStaked = 1000000 * 1e18; // Placeholder - would get from staking contract
        return totalStaked.mulDiv(GOVERNANCE_MILESTONE_THRESHOLD, BASIS_POINTS);
    }
    
    function _calculateRequiredOverrideVotes() internal view returns (uint256) {
        // Higher threshold for overriding emergency interventions
        uint256 totalStaked = 1000000 * 1e18; // Placeholder
        return totalStaked.mulDiv(7500, BASIS_POINTS); // 75% threshold
    }
    
    function _calculateCommunityEngagement() internal view returns (uint256) {
        if (_governanceMetrics.totalProposals == 0) return 0;
        
        uint256 proposalRatio = _governanceMetrics.communityProposals.mulDiv(BASIS_POINTS, _governanceMetrics.totalProposals);
        uint256 participationScore = _governanceMetrics.averageParticipationRate;
        
        return (proposalRatio + participationScore) / 2;
    }
    
    function _calculateDecentralizationScore() internal view returns (uint256) {
        uint256 avgCommunityControl = _getAverageCommunityControl();
        uint256 engagementScore = _governanceMetrics.communityEngagementScore;
        uint256 readinessScore = _communityReadiness.overallScore;
        
        return (avgCommunityControl + engagementScore + readinessScore) / 3;
    }
    
    function _getAverageTeamControl() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < 6; i++) {
            total += teamControlPercentage[ControlType(i)];
        }
        return total / 6;
    }
    
    function _getAverageCommunityControl() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < 6; i++) {
            total += communityControlPercentage[ControlType(i)];
        }
        return total / 6;
    }
    
    function _updateCommunityReadiness() internal {
        // Update community readiness assessment based on current metrics
        _communityReadiness.participationRate = _governanceMetrics.averageParticipationRate;
        _communityReadiness.governanceExperience = _governanceMetrics.totalProposals > 10 ? 8000 : 4000;
        _communityReadiness.stakingParticipation = 7000; // Placeholder - would get from staking
        _communityReadiness.proposalQuality = 6000; // Placeholder - would assess proposal quality
        _communityReadiness.votingConsistency = 7500; // Placeholder - would track voting patterns
        
        _communityReadiness.overallScore = (
            _communityReadiness.participationRate +
            _communityReadiness.governanceExperience +
            _communityReadiness.stakingParticipation +
            _communityReadiness.proposalQuality +
            _communityReadiness.votingConsistency
        ) / 5;
        
        _communityReadiness.isReady = _communityReadiness.overallScore >= 7000; // 70% threshold
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyEmergencyIntervention {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyEmergencyIntervention {
        _unpause();
    }
} 