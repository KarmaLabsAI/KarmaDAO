// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISecurityManager
 * @dev Stage 9.1 Security Audit and Hardening Interface
 * 
 * Core interface for comprehensive security management across the Karma Labs ecosystem.
 * Coordinates audit preparation, bug bounty programs, insurance management, and security monitoring.
 */
interface ISecurityManager {
    
    // ============ ENUMS ============
    
    enum SecurityLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    enum VulnerabilityCategory {
        ACCESS_CONTROL,
        REENTRANCY,
        ARITHMETIC,
        FRONT_RUNNING,
        DOS,
        FLASH_LOAN,
        GOVERNANCE,
        ORACLE_MANIPULATION,
        MEV_EXPLOITATION,
        ECONOMIC_ATTACK
    }
    
    enum SecurityEventType {
        ANOMALY_DETECTED,
        ATTACK_ATTEMPT,
        VULNERABILITY_REPORTED,
        EMERGENCY_TRIGGERED,
        INSURANCE_CLAIM,
        AUDIT_FINDING
    }
    
    enum InsuranceClaimStatus {
        PENDING,
        UNDER_REVIEW,
        APPROVED,
        REJECTED,
        PAID
    }
    
    // ============ STRUCTS ============
    
    struct SecurityMetrics {
        uint256 totalVulnerabilities;
        uint256 criticalVulnerabilities;
        uint256 patchedVulnerabilities;
        uint256 activeBounties;
        uint256 totalBountyPaid;
        uint256 securityIncidents;
        uint256 insuranceClaims;
        uint256 totalInsurancePaid;
        uint256 lastSecurityReview;
        uint256 securityScore; // 0-1000 scale
    }
    
    struct VulnerabilityReport {
        uint256 reportId;
        address reporter;
        VulnerabilityCategory category;
        SecurityLevel severity;
        string title;
        string description;
        bytes32 proofHash;
        uint256 reportedAt;
        uint256 bountyAmount;
        bool isVerified;
        bool isPatched;
        address patchedBy;
        uint256 patchedAt;
        string publicDisclosure;
    }
    
    struct BugBountyProgram {
        uint256 programId;
        bool isActive;
        uint256 maxReward;
        uint256 minReward;
        uint256 totalFunding;
        uint256 availableFunding;
        mapping(VulnerabilityCategory => uint256) categoryRewards;
        mapping(SecurityLevel => uint256) severityMultipliers;
        uint256 responseTimeTarget; // Hours to respond
        address[] whitehatHackers;
        uint256 participantCount;
    }
    
    struct InsuranceClaim {
        uint256 claimId;
        address claimant;
        uint256 amount;
        string description;
        bytes32 evidenceHash;
        InsuranceClaimStatus status;
        uint256 submittedAt;
        uint256 resolvedAt;
        address reviewer;
        string resolution;
    }
    
    struct SecurityEvent {
        uint256 eventId;
        SecurityEventType eventType;
        SecurityLevel severity;
        address contractAddress;
        string description;
        bytes32 dataHash;
        uint256 timestamp;
        bool isResolved;
        address resolvedBy;
        uint256 resolvedAt;
        string resolution;
    }
    
    struct ThreatModel {
        address targetContract;
        string[] attackVectors;
        SecurityLevel[] riskLevels;
        string[] mitigations;
        uint256 lastUpdated;
        address analyst;
        bytes32 modelHash;
    }
    
    // ============ AUDIT PREPARATION AND REMEDIATION ============
    
    /**
     * @dev Create comprehensive threat model for contract
     * @param targetContract Contract to analyze
     * @param attackVectors Identified attack vectors
     * @param riskLevels Risk level for each vector
     * @param mitigations Mitigation strategies
     * @return modelId Threat model identifier
     */
    function createThreatModel(
        address targetContract,
        string[] calldata attackVectors,
        SecurityLevel[] calldata riskLevels,
        string[] calldata mitigations
    ) external returns (uint256 modelId);
    
    /**
     * @dev Generate audit preparation documentation
     * @param contractAddresses Contracts to audit
     * @return documentHash Hash of generated documentation
     */
    function generateAuditDocumentation(address[] calldata contractAddresses) 
        external returns (bytes32 documentHash);
    
    /**
     * @dev Implement security measures based on findings
     * @param findings Audit findings to implement
     * @param priorities Implementation priorities
     */
    function implementSecurityMeasures(
        string[] calldata findings,
        SecurityLevel[] calldata priorities
    ) external;
    
    /**
     * @dev Start automated security testing
     * @param testSuite Test suite to run
     * @param targetContracts Contracts to test
     */
    function startAutomatedTesting(
        string calldata testSuite,
        address[] calldata targetContracts
    ) external;
    
    // ============ BUG BOUNTY PROGRAM DEVELOPMENT ============
    
    /**
     * @dev Create bug bounty program
     * @param maxReward Maximum reward amount
     * @param categoryRewards Rewards by vulnerability category
     * @param severityMultipliers Multipliers by severity level
     * @return programId Program identifier
     */
    function createBugBountyProgram(
        uint256 maxReward,
        uint256[] calldata categoryRewards,
        uint256[] calldata severityMultipliers
    ) external returns (uint256 programId);
    
    /**
     * @dev Submit vulnerability report
     * @param category Vulnerability category
     * @param severity Security level
     * @param title Report title
     * @param description Detailed description
     * @param proofHash Hash of proof-of-concept
     * @return reportId Report identifier
     */
    function submitVulnerabilityReport(
        VulnerabilityCategory category,
        SecurityLevel severity,
        string calldata title,
        string calldata description,
        bytes32 proofHash
    ) external returns (uint256 reportId);
    
    /**
     * @dev Verify and process vulnerability report
     * @param reportId Report to process
     * @param isValid Whether report is valid
     * @param bountyAmount Bounty to award
     */
    function processVulnerabilityReport(
        uint256 reportId,
        bool isValid,
        uint256 bountyAmount
    ) external;
    
    /**
     * @dev Register whitehat hacker
     * @param hacker Hacker address
     * @param reputation Reputation score
     */
    function registerWhitehatHacker(address hacker, uint256 reputation) external;
    
    // ============ INSURANCE AND RISK MANAGEMENT ============
    
    /**
     * @dev Allocate insurance fund
     * @param amount Amount to allocate (5% of raised proceeds = $675K)
     * @param coverage Coverage details
     */
    function allocateInsuranceFund(uint256 amount, string calldata coverage) external;
    
    /**
     * @dev Submit insurance claim
     * @param amount Claim amount
     * @param description Claim description
     * @param evidenceHash Evidence hash
     * @return claimId Claim identifier
     */
    function submitInsuranceClaim(
        uint256 amount,
        string calldata description,
        bytes32 evidenceHash
    ) external returns (uint256 claimId);
    
    /**
     * @dev Process insurance claim
     * @param claimId Claim to process
     * @param approved Whether claim is approved
     * @param payoutAmount Amount to pay out
     */
    function processInsuranceClaim(
        uint256 claimId,
        bool approved,
        uint256 payoutAmount
    ) external;
    
    /**
     * @dev Integrate with Nexus Mutual or similar protocols
     * @param protocolAddress Insurance protocol address
     * @param coverageAmount Coverage amount
     */
    function integrateInsuranceProtocol(
        address protocolAddress,
        uint256 coverageAmount
    ) external;
    
    /**
     * @dev Execute emergency response procedure
     * @param incident Incident description
     * @param actions Emergency actions to take
     */
    function executeEmergencyResponse(
        string calldata incident,
        string[] calldata actions
    ) external;
    
    // ============ SECURITY INFRASTRUCTURE ============
    
    /**
     * @dev Configure monitoring system (Forta, Defender, etc.)
     * @param monitoringSystem Monitoring system address
     * @param configuration Monitoring configuration
     */
    function configureMonitoring(
        address monitoringSystem,
        bytes calldata configuration
    ) external;
    
    /**
     * @dev Report security anomaly
     * @param contractAddress Contract with anomaly
     * @param anomalyType Type of anomaly
     * @param severity Severity level
     * @param description Anomaly description
     * @return eventId Event identifier
     */
    function reportSecurityAnomaly(
        address contractAddress,
        SecurityEventType anomalyType,
        SecurityLevel severity,
        string calldata description
    ) external returns (uint256 eventId);
    
    /**
     * @dev Trigger automatic response to threat
     * @param threatLevel Threat level
     * @param targetContract Contract under threat
     * @param responseActions Actions to take
     */
    function triggerAutomaticResponse(
        SecurityLevel threatLevel,
        address targetContract,
        string[] calldata responseActions
    ) external;
    
    /**
     * @dev Create security dashboard entry
     * @param metrics Current security metrics
     * @param alerts Active alerts
     */
    function updateSecurityDashboard(
        SecurityMetrics calldata metrics,
        string[] calldata alerts
    ) external;
    
    /**
     * @dev Enable forensic analysis
     * @param incident Incident to analyze
     * @param analysisType Type of analysis
     * @return analysisId Analysis identifier
     */
    function enableForensicAnalysis(
        uint256 incident,
        string calldata analysisType
    ) external returns (uint256 analysisId);
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get security metrics
     * @return metrics Current security metrics
     */
    function getSecurityMetrics() external view returns (SecurityMetrics memory metrics);
    
    /**
     * @dev Get vulnerability report
     * @param reportId Report identifier
     * @return report Vulnerability report details
     */
    function getVulnerabilityReport(uint256 reportId) 
        external view returns (VulnerabilityReport memory report);
    
    /**
     * @dev Get active bug bounty programs
     * @return programIds Array of active program IDs
     */
    function getActiveBugBountyPrograms() external view returns (uint256[] memory programIds);
    
    /**
     * @dev Get insurance claim details
     * @param claimId Claim identifier
     * @return claim Insurance claim details
     */
    function getInsuranceClaim(uint256 claimId) 
        external view returns (InsuranceClaim memory claim);
    
    /**
     * @dev Get security events in time range
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @return events Array of security events
     */
    function getSecurityEvents(uint256 startTime, uint256 endTime) 
        external view returns (SecurityEvent[] memory events);
    
    /**
     * @dev Get threat model for contract
     * @param contractAddress Contract address
     * @return model Threat model details
     */
    function getThreatModel(address contractAddress) 
        external view returns (ThreatModel memory model);
    
    // ============ EVENTS ============
    
    event ThreatModelCreated(
        uint256 indexed modelId,
        address indexed targetContract,
        address indexed analyst,
        bytes32 modelHash
    );
    
    event AuditDocumentationGenerated(
        bytes32 indexed documentHash,
        address[] contracts,
        uint256 timestamp
    );
    
    event SecurityMeasureImplemented(
        string finding,
        SecurityLevel priority,
        address implementer,
        uint256 timestamp
    );
    
    event AutomatedTestingStarted(
        string testSuite,
        address[] targetContracts,
        uint256 timestamp
    );
    
    event BugBountyProgramCreated(
        uint256 indexed programId,
        uint256 maxReward,
        uint256 totalFunding
    );
    
    event VulnerabilityReported(
        uint256 indexed reportId,
        address indexed reporter,
        VulnerabilityCategory indexed category,
        SecurityLevel severity
    );
    
    event VulnerabilityVerified(
        uint256 indexed reportId,
        bool isValid,
        uint256 bountyAmount,
        address verifier
    );
    
    event WhitehatHackerRegistered(
        address indexed hacker,
        uint256 reputation,
        uint256 timestamp
    );
    
    event InsuranceFundAllocated(
        uint256 amount,
        string coverage,
        uint256 timestamp
    );
    
    event InsuranceClaimSubmitted(
        uint256 indexed claimId,
        address indexed claimant,
        uint256 amount
    );
    
    event InsuranceClaimProcessed(
        uint256 indexed claimId,
        bool approved,
        uint256 payoutAmount,
        address reviewer
    );
    
    event InsuranceProtocolIntegrated(
        address indexed protocolAddress,
        uint256 coverageAmount,
        uint256 timestamp
    );
    
    event EmergencyResponseExecuted(
        string incident,
        string[] actions,
        address executor,
        uint256 timestamp
    );
    
    event MonitoringConfigured(
        address indexed monitoringSystem,
        bytes configuration,
        uint256 timestamp
    );
    
    event SecurityAnomalyReported(
        uint256 indexed eventId,
        address indexed contractAddress,
        SecurityEventType indexed anomalyType,
        SecurityLevel severity
    );
    
    event AutomaticResponseTriggered(
        SecurityLevel threatLevel,
        address indexed targetContract,
        string[] responseActions,
        uint256 timestamp
    );
    
    event SecurityDashboardUpdated(
        SecurityMetrics metrics,
        string[] alerts,
        uint256 timestamp
    );
    
    event ForensicAnalysisEnabled(
        uint256 indexed analysisId,
        uint256 indexed incident,
        string analysisType,
        uint256 timestamp
    );
} 