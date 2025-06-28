// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMaintenanceUpgradeManager
 * @dev Interface for Maintenance and Upgrade Management
 * Stage 9.2 - Maintenance and Upgrades Implementation
 */
interface IMaintenanceUpgradeManager {
    
    // ============ ENUMS ============
    
    enum UpgradeType {
        MINOR_PATCH,         // Minor bug fixes
        MAJOR_UPDATE,        // Major feature updates
        SECURITY_PATCH,      // Security-related patches
        EMERGENCY_FIX,       // Emergency fixes
        GOVERNANCE_UPGRADE   // Governance system upgrades
    }
    
    enum UpgradeStatus {
        PROPOSED,            // Upgrade proposed
        UNDER_REVIEW,        // Under community review
        APPROVED,            // Approved by governance
        SCHEDULED,           // Scheduled for deployment
        IN_PROGRESS,         // Currently deploying
        COMPLETED,           // Successfully completed
        FAILED,              // Upgrade failed
        ROLLED_BACK         // Rolled back
    }
    
    enum MaintenanceType {
        ROUTINE,             // Routine maintenance
        EMERGENCY,           // Emergency maintenance
        SCHEDULED,           // Scheduled maintenance
        PREVENTIVE          // Preventive maintenance
    }
    
    enum MaintenanceStatus {
        PENDING,             // Pending execution
        IN_PROGRESS,         // Currently in progress
        COMPLETED,           // Successfully completed
        FAILED              // Maintenance failed
    }
    
    enum ProposalCategory {
        TECHNICAL,           // Technical improvements
        ECONOMIC,            // Economic parameter changes
        GOVERNANCE,          // Governance modifications
        SECURITY,            // Security enhancements
        OPERATIONAL         // Operational improvements
    }
    
    enum ProposalStatus {
        DRAFT,               // Draft proposal
        SUBMITTED,           // Submitted for review
        UNDER_REVIEW,        // Under technical review
        VOTING,              // Community voting
        APPROVED,            // Approved for implementation
        REJECTED,            // Rejected by community
        IMPLEMENTED,         // Successfully implemented
        EXPIRED             // Proposal expired
    }
    
    // ============ STRUCTS ============
    
    struct UpgradeProposal {
        bytes32 proposalId;
        UpgradeType upgradeType;
        UpgradeStatus status;
        address proposer;
        address[] targetContracts;
        address[] newImplementations;
        bytes[] upgradeCalls;
        string title;
        string description;
        uint256 proposalTime;
        uint256 reviewDeadline;
        uint256 scheduledTime;
        uint256 gasEstimate;
        bool requiresGovernance;
        string version;
    }
    
    struct MaintenanceTask {
        bytes32 taskId;
        MaintenanceType maintenanceType;
        MaintenanceStatus status;
        address executor;
        address[] targetContracts;
        bytes[] maintenanceCalls;
        string title;
        string description;
        uint256 scheduledTime;
        uint256 executionTime;
        uint256 completionTime;
        uint256 gasUsed;
        bool isRecurring;
        uint256 recurringInterval;
    }
    
    struct EmergencyResponse {
        bytes32 responseId;
        string incidentType;
        address[] affectedContracts;
        bytes[] emergencyActions;
        address responder;
        uint256 detectionTime;
        uint256 responseTime;
        uint256 resolutionTime;
        bool isResolved;
        string description;
        string resolution;
    }
    
    struct CommunityProposal {
        bytes32 proposalId;
        ProposalCategory category;
        ProposalStatus status;
        address proposer;
        string title;
        string description;
        string specification;
        uint256 submissionTime;
        uint256 reviewDeadline;
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 implementationDeadline;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool isImplemented;
        string implementationDetails;
    }
    
    struct TechnicalReview {
        bytes32 reviewId;
        bytes32 proposalId;
        address reviewer;
        string reviewType;
        bool isApproved;
        string[] requirements;
        string[] concerns;
        string[] recommendations;
        uint256 reviewTime;
        string summary;
    }
    
    struct SystemEvolution {
        bytes32 evolutionId;
        string phase;
        uint256 startTime;
        uint256 expectedDuration;
        string[] milestones;
        mapping(string => bool) milestoneCompletion;
        uint256 progressPercentage;
        string description;
        bool isActive;
    }
    
    struct SustainabilityPlan {
        bytes32 planId;
        string name;
        uint256 timeframe;
        string[] objectives;
        mapping(string => uint256) resourceAllocations;
        uint256 budgetRequirement;
        string[] stakeholders;
        bool isActive;
        uint256 creationTime;
        string description;
    }
    
    // ============ EVENTS ============
    
    event UpgradeProposed(bytes32 indexed proposalId, UpgradeType indexed upgradeType, address indexed proposer);
    event UpgradeApproved(bytes32 indexed proposalId, uint256 scheduledTime);
    event UpgradeExecuted(bytes32 indexed proposalId, address[] targetContracts, uint256 gasUsed);
    event UpgradeFailed(bytes32 indexed proposalId, string reason);
    event MaintenanceScheduled(bytes32 indexed taskId, MaintenanceType indexed maintenanceType, uint256 scheduledTime);
    event MaintenanceCompleted(bytes32 indexed taskId, uint256 gasUsed);
    event EmergencyResponseTriggered(bytes32 indexed responseId, string incidentType, address[] affectedContracts);
    event EmergencyResolved(bytes32 indexed responseId, uint256 resolutionTime);
    event CommunityProposalSubmitted(bytes32 indexed proposalId, ProposalCategory indexed category, address indexed proposer);
    event ProposalStatusChanged(bytes32 indexed proposalId, ProposalStatus indexed oldStatus, ProposalStatus indexed newStatus);
    event TechnicalReviewCompleted(bytes32 indexed reviewId, bytes32 indexed proposalId, bool isApproved);
    event SystemEvolutionStarted(bytes32 indexed evolutionId, string phase);
    event MilestoneCompleted(bytes32 indexed evolutionId, string milestone);
    event SustainabilityPlanCreated(bytes32 indexed planId, string name, uint256 budgetRequirement);
    
    // ============ UPGRADE MANAGEMENT ============
    
    function proposeUpgrade(
        UpgradeType upgradeType,
        address[] calldata targetContracts,
        address[] calldata newImplementations,
        bytes[] calldata upgradeCalls,
        string calldata title,
        string calldata description,
        uint256 reviewDeadline,
        bool requiresGovernance,
        string calldata version
    ) external returns (bytes32 proposalId);
    
    function reviewUpgradeProposal(bytes32 proposalId, bool approve) external returns (bool success);
    function scheduleUpgrade(bytes32 proposalId, uint256 scheduledTime) external returns (bool success);
    function executeUpgrade(bytes32 proposalId) external returns (bool success);
    function rollbackUpgrade(bytes32 proposalId, string calldata reason) external returns (bool success);
    
    function getUpgradeProposal(bytes32 proposalId) external view returns (UpgradeProposal memory proposal);
    function getUpgradesByStatus(UpgradeStatus status) external view returns (UpgradeProposal[] memory proposals);
    function getUpgradesByType(UpgradeType upgradeType) external view returns (UpgradeProposal[] memory proposals);
    
    // ============ PATCH MANAGEMENT ============
    
    function createSecurityPatch(
        address[] calldata targetContracts,
        bytes[] calldata patchCalls,
        string calldata description,
        bool isEmergency
    ) external returns (bytes32 patchId);
    
    function deployPatch(bytes32 patchId) external returns (bool success);
    function validatePatchDeployment(bytes32 patchId) external view returns (bool isValid, string[] memory issues);
    
    // ============ MAINTENANCE SCHEDULING ============
    
    function scheduleMaintenanceTask(
        MaintenanceType maintenanceType,
        address[] calldata targetContracts,
        bytes[] calldata maintenanceCalls,
        string calldata title,
        string calldata description,
        uint256 scheduledTime,
        bool isRecurring,
        uint256 recurringInterval
    ) external returns (bytes32 taskId);
    
    function executeMaintenanceTask(bytes32 taskId) external returns (bool success);
    function rescheduleMaintenanceTask(bytes32 taskId, uint256 newScheduledTime) external returns (bool success);
    function cancelMaintenanceTask(bytes32 taskId) external returns (bool success);
    
    function getMaintenanceTask(bytes32 taskId) external view returns (MaintenanceTask memory task);
    function getScheduledMaintenanceTasks() external view returns (MaintenanceTask[] memory tasks);
    function getMaintenanceHistory() external view returns (MaintenanceTask[] memory tasks);
    
    // ============ EMERGENCY RESPONSE ============
    
    function triggerEmergencyResponse(
        string calldata incidentType,
        address[] calldata affectedContracts,
        bytes[] calldata emergencyActions,
        string calldata description
    ) external returns (bytes32 responseId);
    
    function executeEmergencyAction(bytes32 responseId) external returns (bool success);
    function resolveEmergency(bytes32 responseId, string calldata resolution) external returns (bool success);
    
    function getEmergencyResponse(bytes32 responseId) external view returns (EmergencyResponse memory response);
    function getActiveEmergencies() external view returns (EmergencyResponse[] memory responses);
    function getEmergencyHistory() external view returns (EmergencyResponse[] memory responses);
    
    // ============ COMMUNITY PROPOSALS ============
    
    function submitCommunityProposal(
        ProposalCategory category,
        string calldata title,
        string calldata description,
        string calldata specification,
        uint256 reviewDeadline,
        uint256 implementationDeadline
    ) external returns (bytes32 proposalId);
    
    function submitTechnicalReview(
        bytes32 proposalId,
        string calldata reviewType,
        bool isApproved,
        string[] calldata requirements,
        string[] calldata concerns,
        string[] calldata recommendations,
        string calldata summary
    ) external returns (bytes32 reviewId);
    
    function startProposalVoting(bytes32 proposalId, uint256 votingDuration) external returns (bool success);
    function voteOnProposal(bytes32 proposalId, bool support, uint256 weight) external returns (bool success);
    function finalizeProposalVoting(bytes32 proposalId) external returns (bool success);
    function implementProposal(bytes32 proposalId, string calldata implementationDetails) external returns (bool success);
    
    function getCommunityProposal(bytes32 proposalId) external view returns (CommunityProposal memory proposal);
    function getProposalsByCategory(ProposalCategory category) external view returns (CommunityProposal[] memory proposals);
    function getProposalsByStatus(ProposalStatus status) external view returns (CommunityProposal[] memory proposals);
    function getTechnicalReview(bytes32 reviewId) external view returns (TechnicalReview memory review);
    function getProposalReviews(bytes32 proposalId) external view returns (TechnicalReview[] memory reviews);
    
    // ============ LONG-TERM SUSTAINABILITY ============
    
    function initiateSystemEvolution(
        string calldata phase,
        uint256 expectedDuration,
        string[] calldata milestones,
        string calldata description
    ) external returns (bytes32 evolutionId);
    
    function updateEvolutionProgress(bytes32 evolutionId, uint256 progressPercentage) external returns (bool success);
    function completeMilestone(bytes32 evolutionId, string calldata milestone) external returns (bool success);
    function finalizeSystemEvolution(bytes32 evolutionId) external returns (bool success);
    
    function createSustainabilityPlan(
        string calldata name,
        uint256 timeframe,
        string[] calldata objectives,
        uint256 budgetRequirement,
        string[] calldata stakeholders,
        string calldata description
    ) external returns (bytes32 planId);
    
    function allocateResourcesToPlan(
        bytes32 planId,
        string[] calldata resourceTypes,
        uint256[] calldata amounts
    ) external returns (bool success);
    
    function activateSustainabilityPlan(bytes32 planId) external returns (bool success);
    function evaluatePlanProgress(bytes32 planId) external view returns (uint256 progressPercentage, string[] memory achievements);
    
    function getSystemEvolution(bytes32 evolutionId) external view returns (
        string memory phase,
        uint256 startTime,
        uint256 expectedDuration,
        uint256 progressPercentage,
        bool isActive
    );
    
    function getSustainabilityPlan(bytes32 planId) external view returns (
        string memory name,
        uint256 timeframe,
        uint256 budgetRequirement,
        bool isActive,
        uint256 creationTime
    );
    
    // ============ GOVERNANCE INTEGRATION ============
    
    function setGovernanceContract(address governanceContract) external returns (bool success);
    function requireGovernanceApproval(bytes32 proposalId) external returns (bool success);
    function processGovernanceDecision(bytes32 proposalId, bool approved) external returns (bool success);
    
    // ============ ANALYTICS AND REPORTING ============
    
    function getUpgradeStatistics() external view returns (
        uint256 totalUpgrades,
        uint256 successfulUpgrades,
        uint256 failedUpgrades,
        uint256 averageUpgradeTime
    );
    
    function getMaintenanceStatistics() external view returns (
        uint256 totalTasks,
        uint256 completedTasks,
        uint256 failedTasks,
        uint256 averageExecutionTime
    );
    
    function getCommunityEngagementMetrics() external view returns (
        uint256 totalProposals,
        uint256 approvedProposals,
        uint256 implementedProposals,
        uint256 averageVotingParticipation
    );
    
    function generateMaintenanceReport(uint256 startTime, uint256 endTime) external view returns (
        string memory summary,
        uint256 upgradesCompleted,
        uint256 maintenanceTasksCompleted,
        uint256 emergencyResponsesHandled
    );
} 