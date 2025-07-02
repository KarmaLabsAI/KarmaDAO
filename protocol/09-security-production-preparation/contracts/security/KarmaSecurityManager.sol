// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../interfaces/ISecurityManager.sol";
import "../../../interfaces/ITreasury.sol";

/**
 * @title KarmaSecurityManager
 * @dev Stage 9.1 Security Audit and Hardening Implementation
 * 
 * Comprehensive security management system implementing:
 * - Audit preparation and remediation
 * - Bug bounty program development
 * - Insurance and risk management
 * - Security infrastructure and monitoring
 */
contract KarmaSecurityManager is ISecurityManager, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant SECURITY_MANAGER_ROLE = keccak256("SECURITY_MANAGER_ROLE");
    bytes32 public constant AUDIT_MANAGER_ROLE = keccak256("AUDIT_MANAGER_ROLE");
    bytes32 public constant BOUNTY_MANAGER_ROLE = keccak256("BOUNTY_MANAGER_ROLE");
    bytes32 public constant INSURANCE_MANAGER_ROLE = keccak256("INSURANCE_MANAGER_ROLE");
    bytes32 public constant MONITORING_MANAGER_ROLE = keccak256("MONITORING_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_RESPONSE_ROLE = keccak256("EMERGENCY_RESPONSE_ROLE");
    bytes32 public constant FORENSIC_ANALYST_ROLE = keccak256("FORENSIC_ANALYST_ROLE");
    
    uint256 public constant INSURANCE_FUND_TARGET = 675000 * 1e6; // $675K in USDC (6 decimals)
    uint256 public constant MAX_BOUNTY_REWARD = 200000 * 1e6; // $200K max bounty
    uint256 public constant MIN_BOUNTY_REWARD = 100 * 1e6; // $100 min bounty
    uint256 public constant RESPONSE_TIME_TARGET = 24 hours; // 24 hour response target
    uint256 public constant CLAIM_REVIEW_PERIOD = 7 days; // 7 day claim review period
    uint256 public constant THREAT_MODEL_VALIDITY = 90 days; // 90 day threat model validity
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    ITreasury public treasury;
    IERC20 public karmaToken;
    IERC20 public usdcToken;
    
    // Security tracking
    SecurityMetrics private _securityMetrics;
    uint256 public totalThreatModels;
    uint256 public totalVulnerabilityReports;
    uint256 public totalBugBountyPrograms;
    uint256 public totalInsuranceClaims;
    uint256 public totalSecurityEvents;
    uint256 public totalForensicAnalyses;
    
    // Bug bounty programs
    mapping(uint256 => BugBountyProgram) private _bugBountyPrograms;
    mapping(uint256 => bool) public activeBountyPrograms;
    uint256[] private _activeProgramIds;
    
    // Vulnerability reports
    mapping(uint256 => VulnerabilityReport) private _vulnerabilityReports;
    mapping(address => uint256[]) public reportsByReporter;
    mapping(VulnerabilityCategory => uint256[]) public reportsByCategory;
    mapping(SecurityLevel => uint256[]) public reportsBySeverity;
    
    // Insurance claims
    mapping(uint256 => InsuranceClaim) private _insuranceClaims;
    mapping(address => uint256[]) public claimsByClaimant;
    uint256 public insuranceFundBalance;
    uint256 public totalInsurancePaid;
    
    // Security events
    mapping(uint256 => SecurityEvent) private _securityEvents;
    mapping(address => uint256[]) public eventsByContract;
    mapping(SecurityEventType => uint256[]) public eventsByType;
    
    // Threat models
    mapping(uint256 => ThreatModel) private _threatModels;
    mapping(address => uint256) public contractThreatModels;
    
    // Whitehat hackers
    mapping(address => bool) public registeredWhitehats;
    mapping(address => uint256) public whitehatReputation;
    mapping(address => uint256) public whitehatBountiesEarned;
    address[] public whitehatList;
    
    // Monitoring and forensics
    mapping(address => bool) public authorizedMonitoringSystems;
    mapping(uint256 => bytes32) public forensicAnalyses;
    mapping(uint256 => bool) public activeAnalyses;
    
    // Insurance protocol integration
    mapping(address => bool) public integratedInsuranceProtocols;
    mapping(address => uint256) public protocolCoverage;
    
    // Emergency response
    mapping(string => uint256) public emergencyResponseCount;
    mapping(address => bool) public emergencyContacts;
    uint256 public lastEmergencyResponse;
    
    // Automated testing
    mapping(string => bool) public activeTestSuites;
    mapping(address => uint256) public contractTestResults;
    
    // ============ EVENTS ============
    
    event SecuritySystemInitialized(
        address indexed treasury,
        address indexed karmaToken,
        address indexed usdcToken,
        uint256 timestamp
    );
    
    event InsuranceFundDeposited(
        uint256 amount,
        uint256 newBalance,
        address indexed depositor
    );
    
    event WhitehatReputationUpdated(
        address indexed whitehat,
        uint256 oldReputation,
        uint256 newReputation,
        string reason
    );
    
    event MonitoringSystemAuthorized(
        address indexed monitoringSystem,
        bytes configuration,
        uint256 timestamp
    );
    
    event InsuranceProtocolAdded(
        address indexed protocolAddress,
        uint256 coverageAmount,
        uint256 timestamp
    );
    
    // ============ MODIFIERS ============
    
    modifier onlySecurityManager() {
        require(hasRole(SECURITY_MANAGER_ROLE, msg.sender), "KarmaSecurityManager: caller is not security manager");
        _;
    }
    
    modifier onlyAuditManager() {
        require(hasRole(AUDIT_MANAGER_ROLE, msg.sender), "KarmaSecurityManager: caller is not audit manager");
        _;
    }
    
    modifier onlyBountyManager() {
        require(hasRole(BOUNTY_MANAGER_ROLE, msg.sender), "KarmaSecurityManager: caller is not bounty manager");
        _;
    }
    
    modifier onlyInsuranceManager() {
        require(hasRole(INSURANCE_MANAGER_ROLE, msg.sender), "KarmaSecurityManager: caller is not insurance manager");
        _;
    }
    
    modifier onlyMonitoringManager() {
        require(hasRole(MONITORING_MANAGER_ROLE, msg.sender), "KarmaSecurityManager: caller is not monitoring manager");
        _;
    }
    
    modifier onlyEmergencyResponse() {
        require(hasRole(EMERGENCY_RESPONSE_ROLE, msg.sender), "KarmaSecurityManager: caller is not emergency response");
        _;
    }
    
    modifier onlyForensicAnalyst() {
        require(hasRole(FORENSIC_ANALYST_ROLE, msg.sender), "KarmaSecurityManager: caller is not forensic analyst");
        _;
    }
    
    modifier validReportId(uint256 reportId) {
        require(reportId > 0 && reportId <= totalVulnerabilityReports, "KarmaSecurityManager: invalid report ID");
        _;
    }
    
    modifier validClaimId(uint256 claimId) {
        require(claimId > 0 && claimId <= totalInsuranceClaims, "KarmaSecurityManager: invalid claim ID");
        _;
    }
    
    modifier validProgramId(uint256 programId) {
        require(programId > 0 && programId <= totalBugBountyPrograms, "KarmaSecurityManager: invalid program ID");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _treasury,
        address _karmaToken,
        address _usdcToken,
        address _admin
    ) {
        require(_treasury != address(0), "KarmaSecurityManager: invalid treasury");
        require(_karmaToken != address(0), "KarmaSecurityManager: invalid karma token");
        require(_usdcToken != address(0), "KarmaSecurityManager: invalid USDC token");
        require(_admin != address(0), "KarmaSecurityManager: invalid admin");
        
        treasury = ITreasury(_treasury);
        karmaToken = IERC20(_karmaToken);
        usdcToken = IERC20(_usdcToken);
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SECURITY_MANAGER_ROLE, _admin);
        _grantRole(AUDIT_MANAGER_ROLE, _admin);
        _grantRole(BOUNTY_MANAGER_ROLE, _admin);
        _grantRole(INSURANCE_MANAGER_ROLE, _admin);
        _grantRole(MONITORING_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_RESPONSE_ROLE, _admin);
        _grantRole(FORENSIC_ANALYST_ROLE, _admin);
        
        // Initialize security metrics
        _securityMetrics.lastSecurityReview = block.timestamp;
        _securityMetrics.securityScore = 750; // Initial score of 75%
        
        emit SecuritySystemInitialized(_treasury, _karmaToken, _usdcToken, block.timestamp);
    }
    
    // ============ AUDIT PREPARATION AND REMEDIATION ============
    
    /**
     * @dev Create comprehensive threat model for contract
     */
    function createThreatModel(
        address targetContract,
        string[] calldata attackVectors,
        SecurityLevel[] calldata riskLevels,
        string[] calldata mitigations
    ) external override onlyAuditManager whenNotPaused nonReentrant returns (uint256 modelId) {
        require(targetContract != address(0), "KarmaSecurityManager: invalid target contract");
        require(attackVectors.length == riskLevels.length, "KarmaSecurityManager: length mismatch");
        require(attackVectors.length == mitigations.length, "KarmaSecurityManager: length mismatch");
        require(attackVectors.length > 0, "KarmaSecurityManager: no attack vectors provided");
        
        totalThreatModels++;
        modelId = totalThreatModels;
        
        // Create model hash for integrity
        bytes32 modelHash = keccak256(abi.encodePacked(
            targetContract,
            keccak256(abi.encode(attackVectors)),
            keccak256(abi.encode(riskLevels)),
            keccak256(abi.encode(mitigations)),
            block.timestamp,
            msg.sender
        ));
        
        ThreatModel storage model = _threatModels[modelId];
        model.targetContract = targetContract;
        model.attackVectors = attackVectors;
        model.riskLevels = riskLevels;
        model.mitigations = mitigations;
        model.lastUpdated = block.timestamp;
        model.analyst = msg.sender;
        model.modelHash = modelHash;
        
        // Update mapping
        contractThreatModels[targetContract] = modelId;
        
        emit ThreatModelCreated(modelId, targetContract, msg.sender, modelHash);
    }
    
    /**
     * @dev Generate audit preparation documentation
     */
    function generateAuditDocumentation(address[] calldata contractAddresses) 
        external override onlyAuditManager whenNotPaused returns (bytes32 documentHash) {
        require(contractAddresses.length > 0, "KarmaSecurityManager: no contracts provided");
        
        // Generate documentation hash
        documentHash = keccak256(abi.encodePacked(
            keccak256(abi.encode(contractAddresses)),
            block.timestamp,
            _securityMetrics.totalVulnerabilities,
            _securityMetrics.securityScore,
            msg.sender
        ));
        
        emit AuditDocumentationGenerated(documentHash, contractAddresses, block.timestamp);
    }
    
    /**
     * @dev Implement security measures based on findings
     */
    function implementSecurityMeasures(
        string[] calldata findings,
        SecurityLevel[] calldata priorities
    ) external override onlyAuditManager whenNotPaused {
        require(findings.length == priorities.length, "KarmaSecurityManager: length mismatch");
        require(findings.length > 0, "KarmaSecurityManager: no findings provided");
        
        for (uint256 i = 0; i < findings.length; i++) {
            emit SecurityMeasureImplemented(findings[i], priorities[i], msg.sender, block.timestamp);
        }
        
        // Update security metrics
        _securityMetrics.lastSecurityReview = block.timestamp;
        _updateSecurityScore();
    }
    
    /**
     * @dev Start automated security testing
     */
    function startAutomatedTesting(
        string calldata testSuite,
        address[] calldata targetContracts
    ) external override onlyAuditManager whenNotPaused {
        require(bytes(testSuite).length > 0, "KarmaSecurityManager: invalid test suite");
        require(targetContracts.length > 0, "KarmaSecurityManager: no contracts provided");
        
        activeTestSuites[testSuite] = true;
        
        for (uint256 i = 0; i < targetContracts.length; i++) {
            contractTestResults[targetContracts[i]] = block.timestamp;
        }
        
        emit AutomatedTestingStarted(testSuite, targetContracts, block.timestamp);
    }
    
    // ============ BUG BOUNTY PROGRAM DEVELOPMENT ============
    
    /**
     * @dev Create bug bounty program
     */
    function createBugBountyProgram(
        uint256 maxReward,
        uint256[] calldata categoryRewards,
        uint256[] calldata severityMultipliers
    ) external override onlyBountyManager whenNotPaused nonReentrant returns (uint256 programId) {
        require(maxReward >= MIN_BOUNTY_REWARD && maxReward <= MAX_BOUNTY_REWARD, "KarmaSecurityManager: invalid max reward");
        require(categoryRewards.length == 10, "KarmaSecurityManager: invalid category rewards length"); // 10 vulnerability categories
        require(severityMultipliers.length == 4, "KarmaSecurityManager: invalid severity multipliers length"); // 4 security levels
        
        totalBugBountyPrograms++;
        programId = totalBugBountyPrograms;
        
        BugBountyProgram storage program = _bugBountyPrograms[programId];
        program.programId = programId;
        program.isActive = true;
        program.maxReward = maxReward;
        program.minReward = MIN_BOUNTY_REWARD;
        program.totalFunding = maxReward * 50; // Fund for 50 max rewards
        program.availableFunding = program.totalFunding;
        program.responseTimeTarget = RESPONSE_TIME_TARGET;
        
        // Set category rewards
        for (uint256 i = 0; i < categoryRewards.length; i++) {
            program.categoryRewards[VulnerabilityCategory(i)] = categoryRewards[i];
        }
        
        // Set severity multipliers
        for (uint256 i = 0; i < severityMultipliers.length; i++) {
            program.severityMultipliers[SecurityLevel(i)] = severityMultipliers[i];
        }
        
        activeBountyPrograms[programId] = true;
        _activeProgramIds.push(programId);
        
        // Transfer funding from treasury
        usdcToken.safeTransferFrom(address(treasury), address(this), program.totalFunding);
        
        emit BugBountyProgramCreated(programId, maxReward, program.totalFunding);
    }
    
    /**
     * @dev Submit vulnerability report
     */
    function submitVulnerabilityReport(
        VulnerabilityCategory category,
        SecurityLevel severity,
        string calldata title,
        string calldata description,
        bytes32 proofHash
    ) external override whenNotPaused nonReentrant returns (uint256 reportId) {
        require(bytes(title).length > 0, "KarmaSecurityManager: invalid title");
        require(bytes(description).length > 0, "KarmaSecurityManager: invalid description");
        require(proofHash != bytes32(0), "KarmaSecurityManager: invalid proof hash");
        
        totalVulnerabilityReports++;
        reportId = totalVulnerabilityReports;
        
        VulnerabilityReport storage report = _vulnerabilityReports[reportId];
        report.reportId = reportId;
        report.reporter = msg.sender;
        report.category = category;
        report.severity = severity;
        report.title = title;
        report.description = description;
        report.proofHash = proofHash;
        report.reportedAt = block.timestamp;
        
        // Update mappings
        reportsByReporter[msg.sender].push(reportId);
        reportsByCategory[category].push(reportId);
        reportsBySeverity[severity].push(reportId);
        
        // Update metrics
        _securityMetrics.totalVulnerabilities++;
        if (severity == SecurityLevel.CRITICAL) {
            _securityMetrics.criticalVulnerabilities++;
        }
        
        emit VulnerabilityReported(reportId, msg.sender, category, severity);
    }
    
    /**
     * @dev Verify and process vulnerability report
     */
    function processVulnerabilityReport(
        uint256 reportId,
        bool isValid,
        uint256 bountyAmount
    ) external override onlyBountyManager validReportId(reportId) whenNotPaused nonReentrant {
        VulnerabilityReport storage report = _vulnerabilityReports[reportId];
        require(!report.isVerified, "KarmaSecurityManager: report already verified");
        
        if (isValid) {
            require(bountyAmount >= MIN_BOUNTY_REWARD, "KarmaSecurityManager: bounty too low");
            require(bountyAmount <= MAX_BOUNTY_REWARD, "KarmaSecurityManager: bounty too high");
            
            // Find active program with sufficient funding
            uint256 programId = _findSuitableBountyProgram(bountyAmount);
            require(programId > 0, "KarmaSecurityManager: no suitable bounty program");
            
            BugBountyProgram storage program = _bugBountyPrograms[programId];
            require(program.availableFunding >= bountyAmount, "KarmaSecurityManager: insufficient program funding");
            
            // Update program funding
            program.availableFunding -= bountyAmount;
            
            // Update report
            report.isVerified = true;
            report.bountyAmount = bountyAmount;
            
            // Update metrics
            _securityMetrics.totalBountyPaid += bountyAmount;
            _securityMetrics.activeBounties++;
            
            // Update whitehat reputation
            whitehatBountiesEarned[report.reporter] += bountyAmount;
            _updateWhitehatReputation(report.reporter, report.severity);
            
            // Pay bounty
            usdcToken.safeTransfer(report.reporter, bountyAmount);
        }
        
        emit VulnerabilityVerified(reportId, isValid, bountyAmount, msg.sender);
    }
    
    /**
     * @dev Register whitehat hacker
     */
    function registerWhitehatHacker(address hacker, uint256 reputation) 
        external override onlyBountyManager whenNotPaused {
        require(hacker != address(0), "KarmaSecurityManager: invalid hacker address");
        require(reputation <= 1000, "KarmaSecurityManager: reputation too high");
        
        if (!registeredWhitehats[hacker]) {
            registeredWhitehats[hacker] = true;
            whitehatList.push(hacker);
        }
        
        uint256 oldReputation = whitehatReputation[hacker];
        whitehatReputation[hacker] = reputation;
        
        emit WhitehatHackerRegistered(hacker, reputation, block.timestamp);
        emit WhitehatReputationUpdated(hacker, oldReputation, reputation, "Initial registration");
    }
    
    // ============ INSURANCE AND RISK MANAGEMENT ============
    
    /**
     * @dev Allocate insurance fund (5% of raised proceeds = $675K)
     */
    function allocateInsuranceFund(uint256 amount, string calldata coverage) 
        external override onlyInsuranceManager whenNotPaused nonReentrant {
        require(amount > 0, "KarmaSecurityManager: invalid amount");
        require(bytes(coverage).length > 0, "KarmaSecurityManager: invalid coverage");
        
        // Transfer funds from treasury
        usdcToken.safeTransferFrom(address(treasury), address(this), amount);
        insuranceFundBalance += amount;
        
        emit InsuranceFundAllocated(amount, coverage, block.timestamp);
        emit InsuranceFundDeposited(amount, insuranceFundBalance, msg.sender);
    }
    
    /**
     * @dev Submit insurance claim
     */
    function submitInsuranceClaim(
        uint256 amount,
        string calldata description,
        bytes32 evidenceHash
    ) external override whenNotPaused nonReentrant returns (uint256 claimId) {
        require(amount > 0, "KarmaSecurityManager: invalid amount");
        require(bytes(description).length > 0, "KarmaSecurityManager: invalid description");
        require(evidenceHash != bytes32(0), "KarmaSecurityManager: invalid evidence hash");
        
        totalInsuranceClaims++;
        claimId = totalInsuranceClaims;
        
        InsuranceClaim storage claim = _insuranceClaims[claimId];
        claim.claimId = claimId;
        claim.claimant = msg.sender;
        claim.amount = amount;
        claim.description = description;
        claim.evidenceHash = evidenceHash;
        claim.status = InsuranceClaimStatus.PENDING;
        claim.submittedAt = block.timestamp;
        
        // Update mappings
        claimsByClaimant[msg.sender].push(claimId);
        
        // Update metrics
        _securityMetrics.insuranceClaims++;
        
        emit InsuranceClaimSubmitted(claimId, msg.sender, amount);
    }
    
    /**
     * @dev Process insurance claim
     */
    function processInsuranceClaim(
        uint256 claimId,
        bool approved,
        uint256 payoutAmount
    ) external override onlyInsuranceManager validClaimId(claimId) whenNotPaused nonReentrant {
        InsuranceClaim storage claim = _insuranceClaims[claimId];
        require(claim.status == InsuranceClaimStatus.PENDING, "KarmaSecurityManager: claim not pending");
        require(block.timestamp >= claim.submittedAt + CLAIM_REVIEW_PERIOD, "KarmaSecurityManager: review period not elapsed");
        
        if (approved) {
            require(payoutAmount > 0 && payoutAmount <= claim.amount, "KarmaSecurityManager: invalid payout amount");
            require(insuranceFundBalance >= payoutAmount, "KarmaSecurityManager: insufficient insurance fund");
            
            claim.status = InsuranceClaimStatus.APPROVED;
            claim.resolvedAt = block.timestamp;
            claim.reviewer = msg.sender;
            
            // Update balances
            insuranceFundBalance -= payoutAmount;
            totalInsurancePaid += payoutAmount;
            _securityMetrics.totalInsurancePaid += payoutAmount;
            
            // Pay claim
            usdcToken.safeTransfer(claim.claimant, payoutAmount);
            claim.status = InsuranceClaimStatus.PAID;
        } else {
            claim.status = InsuranceClaimStatus.REJECTED;
            claim.resolvedAt = block.timestamp;
            claim.reviewer = msg.sender;
        }
        
        emit InsuranceClaimProcessed(claimId, approved, payoutAmount, msg.sender);
    }
    
    /**
     * @dev Integrate with Nexus Mutual or similar protocols
     */
    function integrateInsuranceProtocol(
        address protocolAddress,
        uint256 coverageAmount
    ) external override onlyInsuranceManager whenNotPaused {
        require(protocolAddress != address(0), "KarmaSecurityManager: invalid protocol address");
        require(coverageAmount > 0, "KarmaSecurityManager: invalid coverage amount");
        
        integratedInsuranceProtocols[protocolAddress] = true;
        protocolCoverage[protocolAddress] = coverageAmount;
        
        emit InsuranceProtocolIntegrated(protocolAddress, coverageAmount, block.timestamp);
        emit InsuranceProtocolAdded(protocolAddress, coverageAmount, block.timestamp);
    }
    
    /**
     * @dev Execute emergency response procedure
     */
    function executeEmergencyResponse(
        string calldata incident,
        string[] calldata actions
    ) external override onlyEmergencyResponse whenNotPaused {
        require(bytes(incident).length > 0, "KarmaSecurityManager: invalid incident");
        require(actions.length > 0, "KarmaSecurityManager: no actions provided");
        
        emergencyResponseCount[incident]++;
        lastEmergencyResponse = block.timestamp;
        
        // Record security event
        _recordSecurityEvent(
            address(this),
            SecurityEventType.EMERGENCY_TRIGGERED,
            SecurityLevel.CRITICAL,
            incident
        );
        
        emit EmergencyResponseExecuted(incident, actions, msg.sender, block.timestamp);
    }
    
    // ============ SECURITY INFRASTRUCTURE ============
    
    /**
     * @dev Configure monitoring system (Forta, Defender, etc.)
     */
    function configureMonitoring(
        address monitoringSystem,
        bytes calldata configuration
    ) external override onlyMonitoringManager whenNotPaused {
        require(monitoringSystem != address(0), "KarmaSecurityManager: invalid monitoring system");
        require(configuration.length > 0, "KarmaSecurityManager: invalid configuration");
        
        authorizedMonitoringSystems[monitoringSystem] = true;
        
        emit MonitoringConfigured(monitoringSystem, configuration, block.timestamp);
        emit MonitoringSystemAuthorized(monitoringSystem, configuration, block.timestamp);
    }
    
    /**
     * @dev Report security anomaly
     */
    function reportSecurityAnomaly(
        address contractAddress,
        SecurityEventType anomalyType,
        SecurityLevel severity,
        string calldata description
    ) external override whenNotPaused returns (uint256 eventId) {
        require(
            authorizedMonitoringSystems[msg.sender] || hasRole(MONITORING_MANAGER_ROLE, msg.sender),
            "KarmaSecurityManager: unauthorized reporter"
        );
        require(contractAddress != address(0), "KarmaSecurityManager: invalid contract address");
        require(bytes(description).length > 0, "KarmaSecurityManager: invalid description");
        
        eventId = _recordSecurityEvent(contractAddress, anomalyType, severity, description);
        
        // Update metrics
        _securityMetrics.securityIncidents++;
        
        emit SecurityAnomalyReported(eventId, contractAddress, anomalyType, severity);
    }
    
    /**
     * @dev Trigger automatic response to threat
     */
    function triggerAutomaticResponse(
        SecurityLevel threatLevel,
        address targetContract,
        string[] calldata responseActions
    ) external override onlyMonitoringManager whenNotPaused {
        require(targetContract != address(0), "KarmaSecurityManager: invalid target contract");
        require(responseActions.length > 0, "KarmaSecurityManager: no response actions");
        
        // Record the automatic response
        string memory incident = string(abi.encodePacked("Automatic response to ", _securityLevelToString(threatLevel), " threat"));
        emergencyResponseCount[incident]++;
        
        emit AutomaticResponseTriggered(threatLevel, targetContract, responseActions, block.timestamp);
    }
    
    /**
     * @dev Create security dashboard entry
     */
    function updateSecurityDashboard(
        SecurityMetrics calldata metrics,
        string[] calldata alerts
    ) external override onlyMonitoringManager whenNotPaused {
        require(alerts.length > 0, "KarmaSecurityManager: no alerts provided");
        
        // Update internal metrics
        _securityMetrics = metrics;
        
        emit SecurityDashboardUpdated(metrics, alerts, block.timestamp);
    }
    
    /**
     * @dev Enable forensic analysis
     */
    function enableForensicAnalysis(
        uint256 incident,
        string calldata analysisType
    ) external override onlyForensicAnalyst whenNotPaused returns (uint256 analysisId) {
        require(incident > 0 && incident <= totalSecurityEvents, "KarmaSecurityManager: invalid incident");
        require(bytes(analysisType).length > 0, "KarmaSecurityManager: invalid analysis type");
        
        totalForensicAnalyses++;
        analysisId = totalForensicAnalyses;
        
        bytes32 analysisHash = keccak256(abi.encodePacked(incident, analysisType, block.timestamp, msg.sender));
        forensicAnalyses[analysisId] = analysisHash;
        activeAnalyses[analysisId] = true;
        
        emit ForensicAnalysisEnabled(analysisId, incident, analysisType, block.timestamp);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get security metrics
     */
    function getSecurityMetrics() external view override returns (SecurityMetrics memory metrics) {
        return _securityMetrics;
    }
    
    /**
     * @dev Get vulnerability report
     */
    function getVulnerabilityReport(uint256 reportId) 
        external view override validReportId(reportId) returns (VulnerabilityReport memory report) {
        return _vulnerabilityReports[reportId];
    }
    
    /**
     * @dev Get active bug bounty programs
     */
    function getActiveBugBountyPrograms() external view override returns (uint256[] memory programIds) {
        return _activeProgramIds;
    }
    
    /**
     * @dev Get insurance claim details
     */
    function getInsuranceClaim(uint256 claimId) 
        external view override validClaimId(claimId) returns (InsuranceClaim memory claim) {
        return _insuranceClaims[claimId];
    }
    
    /**
     * @dev Get security events in time range
     */
    function getSecurityEvents(uint256 startTime, uint256 endTime) 
        external view override returns (SecurityEvent[] memory events) {
        require(endTime >= startTime, "KarmaSecurityManager: invalid time range");
        
        // Count events in range
        uint256 count = 0;
        for (uint256 i = 1; i <= totalSecurityEvents; i++) {
            if (_securityEvents[i].timestamp >= startTime && _securityEvents[i].timestamp <= endTime) {
                count++;
            }
        }
        
        // Create array
        events = new SecurityEvent[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= totalSecurityEvents; i++) {
            if (_securityEvents[i].timestamp >= startTime && _securityEvents[i].timestamp <= endTime) {
                events[index] = _securityEvents[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Get threat model for contract
     */
    function getThreatModel(address contractAddress) 
        external view override returns (ThreatModel memory model) {
        uint256 modelId = contractThreatModels[contractAddress];
        require(modelId > 0, "KarmaSecurityManager: no threat model for contract");
        return _threatModels[modelId];
    }
    
    // ============ INTERNAL HELPER FUNCTIONS ============
    
    function _findSuitableBountyProgram(uint256 bountyAmount) internal view returns (uint256) {
        for (uint256 i = 0; i < _activeProgramIds.length; i++) {
            uint256 programId = _activeProgramIds[i];
            BugBountyProgram storage program = _bugBountyPrograms[programId];
            if (program.isActive && program.availableFunding >= bountyAmount) {
                return programId;
            }
        }
        return 0;
    }
    
    function _updateWhitehatReputation(address whitehat, SecurityLevel severity) internal {
        uint256 reputationBonus;
        if (severity == SecurityLevel.CRITICAL) {
            reputationBonus = 100;
        } else if (severity == SecurityLevel.HIGH) {
            reputationBonus = 50;
        } else if (severity == SecurityLevel.MEDIUM) {
            reputationBonus = 25;
        } else {
            reputationBonus = 10;
        }
        
        uint256 oldReputation = whitehatReputation[whitehat];
        uint256 newReputation = oldReputation + reputationBonus;
        if (newReputation > 1000) newReputation = 1000;
        
        whitehatReputation[whitehat] = newReputation;
        
        emit WhitehatReputationUpdated(whitehat, oldReputation, newReputation, "Vulnerability report reward");
    }
    
    function _recordSecurityEvent(
        address contractAddress,
        SecurityEventType eventType,
        SecurityLevel severity,
        string memory description
    ) internal returns (uint256 eventId) {
        totalSecurityEvents++;
        eventId = totalSecurityEvents;
        
        bytes32 dataHash = keccak256(abi.encodePacked(description, block.timestamp, msg.sender));
        
        SecurityEvent storage securityEvent = _securityEvents[eventId];
        securityEvent.eventId = eventId;
        securityEvent.eventType = eventType;
        securityEvent.severity = severity;
        securityEvent.contractAddress = contractAddress;
        securityEvent.description = description;
        securityEvent.dataHash = dataHash;
        securityEvent.timestamp = block.timestamp;
        
        // Update mappings
        eventsByContract[contractAddress].push(eventId);
        eventsByType[eventType].push(eventId);
    }
    
    function _updateSecurityScore() internal {
        uint256 newScore = 750; // Base score
        
        // Adjust based on metrics
        if (_securityMetrics.criticalVulnerabilities == 0) {
            newScore += 100;
        } else {
            newScore -= (_securityMetrics.criticalVulnerabilities * 50);
        }
        
        if (_securityMetrics.patchedVulnerabilities > _securityMetrics.totalVulnerabilities / 2) {
            newScore += 50;
        }
        
        if (block.timestamp - _securityMetrics.lastSecurityReview < 30 days) {
            newScore += 25;
        }
        
        // Ensure score is within bounds
        if (newScore > 1000) newScore = 1000;
        if (newScore < 100) newScore = 100;
        
        _securityMetrics.securityScore = newScore;
    }
    
    function _securityLevelToString(SecurityLevel level) internal pure returns (string memory) {
        if (level == SecurityLevel.LOW) return "LOW";
        if (level == SecurityLevel.MEDIUM) return "MEDIUM";
        if (level == SecurityLevel.HIGH) return "HIGH";
        if (level == SecurityLevel.CRITICAL) return "CRITICAL";
        return "UNKNOWN";
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyEmergencyResponse {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyEmergencyResponse {
        _unpause();
    }
    
    /**
     * @dev Withdraw insurance funds (emergency only)
     */
    function emergencyWithdrawInsurance(address recipient, uint256 amount) 
        external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(recipient != address(0), "KarmaSecurityManager: invalid recipient");
        require(amount <= insuranceFundBalance, "KarmaSecurityManager: insufficient balance");
        
        insuranceFundBalance -= amount;
        usdcToken.safeTransfer(recipient, amount);
    }
} 