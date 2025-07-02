// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../interfaces/ITreasury.sol";

/**
 * @title KarmaInsuranceManager
 * @dev Stage 9.1 Insurance and Risk Management Implementation
 * 
 * Manages:
 * - Insurance fund allocation (5% of raised proceeds = $675K)
 * - Nexus Mutual integration
 * - Emergency procedures
 * - Comprehensive monitoring and alerting
 */
contract KarmaInsuranceManager is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant INSURANCE_MANAGER_ROLE = keccak256("INSURANCE_MANAGER_ROLE");
    bytes32 public constant CLAIMS_PROCESSOR_ROLE = keccak256("CLAIMS_PROCESSOR_ROLE");
    bytes32 public constant EMERGENCY_RESPONSE_ROLE = keccak256("EMERGENCY_RESPONSE_ROLE");
    bytes32 public constant RISK_ASSESSOR_ROLE = keccak256("RISK_ASSESSOR_ROLE");
    bytes32 public constant PROTOCOL_INTEGRATOR_ROLE = keccak256("PROTOCOL_INTEGRATOR_ROLE");
    
    uint256 public constant INSURANCE_FUND_TARGET = 675000 * 1e6; // $675K USDC (6 decimals)
    uint256 public constant MIN_CLAIM_AMOUNT = 1000 * 1e6; // $1K minimum claim
    uint256 public constant MAX_CLAIM_AMOUNT = 100000 * 1e6; // $100K maximum single claim
    uint256 public constant CLAIM_PROCESSING_PERIOD = 7 days; // 7 day review period
    uint256 public constant EMERGENCY_RESPONSE_TIMEOUT = 24 hours; // 24 hour response timeout
    uint256 public constant RISK_ASSESSMENT_VALIDITY = 30 days; // 30 day risk assessment validity
    
    // ============ ENUMS ============
    
    enum ClaimStatus {
        SUBMITTED,
        UNDER_REVIEW,
        APPROVED,
        REJECTED,
        PAID,
        DISPUTED,
        CANCELLED
    }
    
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    enum EmergencyType {
        EXPLOIT,
        GOVERNANCE_ATTACK,
        ORACLE_MANIPULATION,
        FLASH_LOAN_ATTACK,
        ECONOMIC_ATTACK,
        ACCESS_CONTROL_BREACH,
        INFRASTRUCTURE_FAILURE
    }
    
    enum CoverageType {
        SMART_CONTRACT_RISK,
        ORACLE_RISK,
        GOVERNANCE_RISK,
        ECONOMIC_RISK,
        INFRASTRUCTURE_RISK,
        REGULATORY_RISK
    }
    
    // ============ STRUCTS ============
    
    struct InsuranceClaim {
        uint256 claimId;
        address claimant;
        uint256 amount;
        CoverageType coverageType;
        string description;
        bytes32 evidenceHash;
        ClaimStatus status;
        uint256 submittedAt;
        uint256 reviewDeadline;
        uint256 processedAt;
        address processor;
        string processingNotes;
        uint256 payoutAmount;
        bool disputed;
        uint256 disputeDeadline;
    }
    
    struct RiskAssessment {
        uint256 assessmentId;
        address targetContract;
        RiskLevel riskLevel;
        CoverageType[] coverageTypes;
        uint256 coverageAmount;
        uint256 premium;
        uint256 assessedAt;
        uint256 validUntil;
        address assessor;
        string riskFactors;
        string mitigationMeasures;
        bytes32 assessmentHash;
    }
    
    struct EmergencyIncident {
        uint256 incidentId;
        EmergencyType emergencyType;
        address affectedContract;
        RiskLevel severity;
        string description;
        uint256 reportedAt;
        uint256 responseDeadline;
        bool isActive;
        bool isResolved;
        uint256 resolvedAt;
        address responder;
        string[] responseActions;
        uint256 estimatedLoss;
        uint256 actualLoss;
    }
    
    struct InsuranceProtocol {
        address protocolAddress;
        string protocolName;
        bool isActive;
        uint256 coverageAmount;
        uint256 premium;
        CoverageType[] supportedCoverage;
        uint256 integratedAt;
        uint256 lastClaimAt;
        uint256 totalClaims;
        uint256 totalPayouts;
    }
    
    struct MonitoringAlert {
        uint256 alertId;
        address monitoringSystem;
        RiskLevel severity;
        string alertType;
        string description;
        bytes alertData;
        uint256 triggeredAt;
        bool isAcknowledged;
        uint256 acknowledgedAt;
        address acknowledgedBy;
        bool isResolved;
        uint256 resolvedAt;
    }
    
    struct InsuranceFundMetrics {
        uint256 totalAllocated;
        uint256 availableBalance;
        uint256 totalClaims;
        uint256 totalPayouts;
        uint256 pendingClaims;
        uint256 pendingAmount;
        uint256 reserveRatio; // Percentage of fund kept in reserve
        uint256 lastFundingAt;
        uint256 lastPayoutAt;
        uint256 averageClaimAmount;
        uint256 successfulClaims;
        uint256 rejectedClaims;
    }
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    ITreasury public treasury;
    IERC20 public usdcToken;
    IERC20 public karmaToken;
    
    // Insurance fund management
    InsuranceFundMetrics public fundMetrics;
    uint256 public reserveRatio = 2000; // 20% reserve ratio
    
    // Claims management
    mapping(uint256 => InsuranceClaim) public claims;
    mapping(address => uint256[]) public claimsByClaimant;
    mapping(CoverageType => uint256[]) public claimsByCoverage;
    mapping(ClaimStatus => uint256[]) public claimsByStatus;
    uint256 public totalClaims;
    
    // Risk assessments
    mapping(uint256 => RiskAssessment) public riskAssessments;
    mapping(address => uint256) public contractRiskAssessments;
    uint256 public totalRiskAssessments;
    
    // Emergency incidents
    mapping(uint256 => EmergencyIncident) public emergencyIncidents;
    mapping(EmergencyType => uint256[]) public incidentsByType;
    mapping(address => uint256[]) public incidentsByContract;
    uint256 public totalEmergencyIncidents;
    
    // Insurance protocol integration
    mapping(address => InsuranceProtocol) public insuranceProtocols;
    mapping(CoverageType => address[]) public protocolsByCoverage;
    address[] public integratedProtocols;
    
    // Monitoring and alerting
    mapping(uint256 => MonitoringAlert) public monitoringAlerts;
    mapping(address => bool) public authorizedMonitoringSystems;
    mapping(address => uint256[]) public alertsBySystem;
    uint256 public totalMonitoringAlerts;
    
    // Emergency response tracking
    mapping(address => bool) public emergencyContacts;
    mapping(uint256 => bool) public activeEmergencies;
    uint256 public lastEmergencyResponse;
    
    // ============ EVENTS ============
    
    event InsuranceFundDeposited(
        uint256 amount,
        uint256 newBalance,
        address indexed depositor,
        uint256 timestamp
    );
    
    event InsuranceClaimSubmitted(
        uint256 indexed claimId,
        address indexed claimant,
        uint256 amount,
        CoverageType indexed coverageType,
        uint256 reviewDeadline
    );
    
    event InsuranceClaimProcessed(
        uint256 indexed claimId,
        ClaimStatus indexed status,
        uint256 payoutAmount,
        address indexed processor,
        uint256 timestamp
    );
    
    event RiskAssessmentCompleted(
        uint256 indexed assessmentId,
        address indexed targetContract,
        RiskLevel indexed riskLevel,
        uint256 coverageAmount,
        address assessor
    );
    
    event EmergencyIncidentReported(
        uint256 indexed incidentId,
        EmergencyType indexed emergencyType,
        address indexed affectedContract,
        RiskLevel severity,
        uint256 responseDeadline
    );
    
    event EmergencyIncidentResolved(
        uint256 indexed incidentId,
        uint256 actualLoss,
        address indexed responder,
        uint256 timestamp
    );
    
    event InsuranceProtocolIntegrated(
        address indexed protocolAddress,
        string protocolName,
        uint256 coverageAmount,
        uint256 timestamp
    );
    
    event MonitoringAlertTriggered(
        uint256 indexed alertId,
        address indexed monitoringSystem,
        RiskLevel indexed severity,
        string alertType,
        uint256 timestamp
    );
    
    event MonitoringAlertAcknowledged(
        uint256 indexed alertId,
        address indexed acknowledgedBy,
        uint256 timestamp
    );
    
    event EmergencyResponseExecuted(
        uint256 indexed incidentId,
        string[] responseActions,
        address indexed responder,
        uint256 timestamp
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyInsuranceManager() {
        require(hasRole(INSURANCE_MANAGER_ROLE, msg.sender), "KarmaInsuranceManager: caller is not insurance manager");
        _;
    }
    
    modifier onlyClaimsProcessor() {
        require(hasRole(CLAIMS_PROCESSOR_ROLE, msg.sender), "KarmaInsuranceManager: caller is not claims processor");
        _;
    }
    
    modifier onlyEmergencyResponse() {
        require(hasRole(EMERGENCY_RESPONSE_ROLE, msg.sender), "KarmaInsuranceManager: caller is not emergency response");
        _;
    }
    
    modifier onlyRiskAssessor() {
        require(hasRole(RISK_ASSESSOR_ROLE, msg.sender), "KarmaInsuranceManager: caller is not risk assessor");
        _;
    }
    
    modifier onlyProtocolIntegrator() {
        require(hasRole(PROTOCOL_INTEGRATOR_ROLE, msg.sender), "KarmaInsuranceManager: caller is not protocol integrator");
        _;
    }
    
    modifier validClaimId(uint256 claimId) {
        require(claimId > 0 && claimId <= totalClaims, "KarmaInsuranceManager: invalid claim ID");
        _;
    }
    
    modifier validAssessmentId(uint256 assessmentId) {
        require(assessmentId > 0 && assessmentId <= totalRiskAssessments, "KarmaInsuranceManager: invalid assessment ID");
        _;
    }
    
    modifier validIncidentId(uint256 incidentId) {
        require(incidentId > 0 && incidentId <= totalEmergencyIncidents, "KarmaInsuranceManager: invalid incident ID");
        _;
    }
    
    modifier authorizedMonitoring() {
        require(
            authorizedMonitoringSystems[msg.sender] || hasRole(INSURANCE_MANAGER_ROLE, msg.sender),
            "KarmaInsuranceManager: unauthorized monitoring system"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _treasury,
        address _usdcToken,
        address _karmaToken,
        address _admin
    ) {
        require(_treasury != address(0), "KarmaInsuranceManager: invalid treasury");
        require(_usdcToken != address(0), "KarmaInsuranceManager: invalid USDC token");
        require(_karmaToken != address(0), "KarmaInsuranceManager: invalid KARMA token");
        require(_admin != address(0), "KarmaInsuranceManager: invalid admin");
        
        treasury = ITreasury(_treasury);
        usdcToken = IERC20(_usdcToken);
        karmaToken = IERC20(_karmaToken);
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(INSURANCE_MANAGER_ROLE, _admin);
        _grantRole(CLAIMS_PROCESSOR_ROLE, _admin);
        _grantRole(EMERGENCY_RESPONSE_ROLE, _admin);
        _grantRole(RISK_ASSESSOR_ROLE, _admin);
        _grantRole(PROTOCOL_INTEGRATOR_ROLE, _admin);
        
        // Initialize fund metrics
        fundMetrics.lastFundingAt = block.timestamp;
        fundMetrics.reserveRatio = reserveRatio;
    }
    
    // ============ INSURANCE FUND MANAGEMENT ============
    
    /**
     * @dev Allocate insurance fund (5% of raised proceeds = $675K)
     */
    function allocateInsuranceFund(uint256 amount) 
        external onlyInsuranceManager whenNotPaused nonReentrant {
        require(amount > 0, "KarmaInsuranceManager: invalid amount");
        require(
            fundMetrics.totalAllocated + amount <= INSURANCE_FUND_TARGET,
            "KarmaInsuranceManager: exceeds target allocation"
        );
        
        // Transfer funds from treasury
        usdcToken.safeTransferFrom(address(treasury), address(this), amount);
        
        // Update metrics
        fundMetrics.totalAllocated += amount;
        fundMetrics.availableBalance += amount;
        fundMetrics.lastFundingAt = block.timestamp;
        
        emit InsuranceFundDeposited(amount, fundMetrics.availableBalance, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Set reserve ratio for fund management
     */
    function setReserveRatio(uint256 newReserveRatio) external onlyInsuranceManager {
        require(newReserveRatio <= 5000, "KarmaInsuranceManager: reserve ratio too high"); // Max 50%
        
        reserveRatio = newReserveRatio;
        fundMetrics.reserveRatio = newReserveRatio;
    }
    
    /**
     * @dev Get available funds for claims (excluding reserve)
     */
    function getAvailableClaimFunds() public view returns (uint256) {
        uint256 reserveAmount = (fundMetrics.availableBalance * reserveRatio) / 10000;
        return fundMetrics.availableBalance > reserveAmount ? 
               fundMetrics.availableBalance - reserveAmount : 0;
    }
    
    // ============ CLAIMS MANAGEMENT ============
    
    /**
     * @dev Submit insurance claim
     */
    function submitInsuranceClaim(
        uint256 amount,
        CoverageType coverageType,
        string calldata description,
        bytes32 evidenceHash
    ) external whenNotPaused nonReentrant returns (uint256 claimId) {
        require(amount >= MIN_CLAIM_AMOUNT && amount <= MAX_CLAIM_AMOUNT, "KarmaInsuranceManager: invalid claim amount");
        require(bytes(description).length > 0, "KarmaInsuranceManager: invalid description");
        require(evidenceHash != bytes32(0), "KarmaInsuranceManager: invalid evidence hash");
        
        totalClaims++;
        claimId = totalClaims;
        
        uint256 reviewDeadline = block.timestamp + CLAIM_PROCESSING_PERIOD;
        
        InsuranceClaim storage claim = claims[claimId];
        claim.claimId = claimId;
        claim.claimant = msg.sender;
        claim.amount = amount;
        claim.coverageType = coverageType;
        claim.description = description;
        claim.evidenceHash = evidenceHash;
        claim.status = ClaimStatus.SUBMITTED;
        claim.submittedAt = block.timestamp;
        claim.reviewDeadline = reviewDeadline;
        
        // Update mappings
        claimsByClaimant[msg.sender].push(claimId);
        claimsByCoverage[coverageType].push(claimId);
        claimsByStatus[ClaimStatus.SUBMITTED].push(claimId);
        
        // Update metrics
        fundMetrics.totalClaims++;
        fundMetrics.pendingClaims++;
        fundMetrics.pendingAmount += amount;
        
        emit InsuranceClaimSubmitted(claimId, msg.sender, amount, coverageType, reviewDeadline);
    }
    
    /**
     * @dev Process insurance claim
     */
    function processInsuranceClaim(
        uint256 claimId,
        ClaimStatus newStatus,
        uint256 payoutAmount,
        string calldata processingNotes
    ) external onlyClaimsProcessor validClaimId(claimId) whenNotPaused nonReentrant {
        InsuranceClaim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.SUBMITTED || claim.status == ClaimStatus.UNDER_REVIEW, 
                "KarmaInsuranceManager: claim not processable");
        require(block.timestamp <= claim.reviewDeadline, "KarmaInsuranceManager: review deadline passed");
        
        if (newStatus == ClaimStatus.APPROVED) {
            require(payoutAmount > 0 && payoutAmount <= claim.amount, "KarmaInsuranceManager: invalid payout amount");
            require(getAvailableClaimFunds() >= payoutAmount, "KarmaInsuranceManager: insufficient funds");
            
            // Update claim
            claim.status = ClaimStatus.APPROVED;
            claim.payoutAmount = payoutAmount;
            claim.processedAt = block.timestamp;
            claim.processor = msg.sender;
            claim.processingNotes = processingNotes;
            
            // Update fund metrics
            fundMetrics.availableBalance -= payoutAmount;
            fundMetrics.totalPayouts += payoutAmount;
            fundMetrics.successfulClaims++;
            fundMetrics.pendingClaims--;
            fundMetrics.pendingAmount -= claim.amount;
            fundMetrics.lastPayoutAt = block.timestamp;
            fundMetrics.averageClaimAmount = fundMetrics.totalPayouts / fundMetrics.successfulClaims;
            
            // Transfer payout
            usdcToken.safeTransfer(claim.claimant, payoutAmount);
            
            // Update claim status to paid
            claim.status = ClaimStatus.PAID;
            
        } else if (newStatus == ClaimStatus.REJECTED) {
            claim.status = ClaimStatus.REJECTED;
            claim.processedAt = block.timestamp;
            claim.processor = msg.sender;
            claim.processingNotes = processingNotes;
            
            // Update metrics
            fundMetrics.rejectedClaims++;
            fundMetrics.pendingClaims--;
            fundMetrics.pendingAmount -= claim.amount;
            
        } else if (newStatus == ClaimStatus.UNDER_REVIEW) {
            claim.status = ClaimStatus.UNDER_REVIEW;
            claim.processor = msg.sender;
            claim.processingNotes = processingNotes;
        }
        
        // Update status mapping
        _updateClaimStatusMapping(claimId, claim.status);
        
        emit InsuranceClaimProcessed(claimId, newStatus, payoutAmount, msg.sender, block.timestamp);
    }
    
    // ============ RISK ASSESSMENT ============
    
    /**
     * @dev Create risk assessment for contract
     */
    function createRiskAssessment(
        address targetContract,
        RiskLevel riskLevel,
        CoverageType[] calldata coverageTypes,
        uint256 coverageAmount,
        uint256 premium,
        string calldata riskFactors,
        string calldata mitigationMeasures
    ) external onlyRiskAssessor whenNotPaused nonReentrant returns (uint256 assessmentId) {
        require(targetContract != address(0), "KarmaInsuranceManager: invalid target contract");
        require(coverageTypes.length > 0, "KarmaInsuranceManager: no coverage types");
        require(coverageAmount > 0, "KarmaInsuranceManager: invalid coverage amount");
        require(bytes(riskFactors).length > 0, "KarmaInsuranceManager: invalid risk factors");
        
        totalRiskAssessments++;
        assessmentId = totalRiskAssessments;
        
        uint256 validUntil = block.timestamp + RISK_ASSESSMENT_VALIDITY;
        
        // Create assessment hash
        bytes32 assessmentHash = keccak256(abi.encodePacked(
            targetContract,
            riskLevel,
            keccak256(abi.encode(coverageTypes)),
            coverageAmount,
            premium,
            riskFactors,
            mitigationMeasures,
            block.timestamp,
            msg.sender
        ));
        
        RiskAssessment storage assessment = riskAssessments[assessmentId];
        assessment.assessmentId = assessmentId;
        assessment.targetContract = targetContract;
        assessment.riskLevel = riskLevel;
        assessment.coverageTypes = coverageTypes;
        assessment.coverageAmount = coverageAmount;
        assessment.premium = premium;
        assessment.assessedAt = block.timestamp;
        assessment.validUntil = validUntil;
        assessment.assessor = msg.sender;
        assessment.riskFactors = riskFactors;
        assessment.mitigationMeasures = mitigationMeasures;
        assessment.assessmentHash = assessmentHash;
        
        // Update mapping
        contractRiskAssessments[targetContract] = assessmentId;
        
        emit RiskAssessmentCompleted(assessmentId, targetContract, riskLevel, coverageAmount, msg.sender);
    }
    
    // ============ EMERGENCY INCIDENT MANAGEMENT ============
    
    /**
     * @dev Report emergency incident
     */
    function reportEmergencyIncident(
        EmergencyType emergencyType,
        address affectedContract,
        RiskLevel severity,
        string calldata description,
        uint256 estimatedLoss
    ) external authorizedMonitoring whenNotPaused nonReentrant returns (uint256 incidentId) {
        require(affectedContract != address(0), "KarmaInsuranceManager: invalid affected contract");
        require(bytes(description).length > 0, "KarmaInsuranceManager: invalid description");
        
        totalEmergencyIncidents++;
        incidentId = totalEmergencyIncidents;
        
        uint256 responseDeadline = block.timestamp + EMERGENCY_RESPONSE_TIMEOUT;
        
        EmergencyIncident storage incident = emergencyIncidents[incidentId];
        incident.incidentId = incidentId;
        incident.emergencyType = emergencyType;
        incident.affectedContract = affectedContract;
        incident.severity = severity;
        incident.description = description;
        incident.reportedAt = block.timestamp;
        incident.responseDeadline = responseDeadline;
        incident.isActive = true;
        incident.estimatedLoss = estimatedLoss;
        
        // Update mappings
        incidentsByType[emergencyType].push(incidentId);
        incidentsByContract[affectedContract].push(incidentId);
        activeEmergencies[incidentId] = true;
        
        emit EmergencyIncidentReported(incidentId, emergencyType, affectedContract, severity, responseDeadline);
    }
    
    /**
     * @dev Execute emergency response
     */
    function executeEmergencyResponse(
        uint256 incidentId,
        string[] calldata responseActions
    ) external onlyEmergencyResponse validIncidentId(incidentId) whenNotPaused nonReentrant {
        EmergencyIncident storage incident = emergencyIncidents[incidentId];
        require(incident.isActive, "KarmaInsuranceManager: incident not active");
        require(block.timestamp <= incident.responseDeadline, "KarmaInsuranceManager: response deadline passed");
        require(responseActions.length > 0, "KarmaInsuranceManager: no response actions");
        
        incident.responder = msg.sender;
        incident.responseActions = responseActions;
        lastEmergencyResponse = block.timestamp;
        
        emit EmergencyResponseExecuted(incidentId, responseActions, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Resolve emergency incident
     */
    function resolveEmergencyIncident(
        uint256 incidentId,
        uint256 actualLoss
    ) external onlyEmergencyResponse validIncidentId(incidentId) whenNotPaused {
        EmergencyIncident storage incident = emergencyIncidents[incidentId];
        require(incident.isActive, "KarmaInsuranceManager: incident not active");
        
        incident.isActive = false;
        incident.isResolved = true;
        incident.resolvedAt = block.timestamp;
        incident.actualLoss = actualLoss;
        
        // Remove from active emergencies
        activeEmergencies[incidentId] = false;
        
        emit EmergencyIncidentResolved(incidentId, actualLoss, msg.sender, block.timestamp);
    }
    
    // ============ INSURANCE PROTOCOL INTEGRATION ============
    
    /**
     * @dev Integrate with Nexus Mutual or similar protocols
     */
    function integrateInsuranceProtocol(
        address protocolAddress,
        string calldata protocolName,
        uint256 coverageAmount,
        uint256 premium,
        CoverageType[] calldata supportedCoverage
    ) external onlyProtocolIntegrator whenNotPaused {
        require(protocolAddress != address(0), "KarmaInsuranceManager: invalid protocol address");
        require(bytes(protocolName).length > 0, "KarmaInsuranceManager: invalid protocol name");
        require(coverageAmount > 0, "KarmaInsuranceManager: invalid coverage amount");
        require(supportedCoverage.length > 0, "KarmaInsuranceManager: no supported coverage");
        
        InsuranceProtocol storage protocol = insuranceProtocols[protocolAddress];
        protocol.protocolAddress = protocolAddress;
        protocol.protocolName = protocolName;
        protocol.isActive = true;
        protocol.coverageAmount = coverageAmount;
        protocol.premium = premium;
        protocol.supportedCoverage = supportedCoverage;
        protocol.integratedAt = block.timestamp;
        
        // Update mappings
        integratedProtocols.push(protocolAddress);
        for (uint256 i = 0; i < supportedCoverage.length; i++) {
            protocolsByCoverage[supportedCoverage[i]].push(protocolAddress);
        }
        
        emit InsuranceProtocolIntegrated(protocolAddress, protocolName, coverageAmount, block.timestamp);
    }
    
    // ============ MONITORING AND ALERTING ============
    
    /**
     * @dev Add authorized monitoring system
     */
    function addMonitoringSystem(address monitoringSystem) external onlyInsuranceManager {
        require(monitoringSystem != address(0), "KarmaInsuranceManager: invalid monitoring system");
        
        authorizedMonitoringSystems[monitoringSystem] = true;
    }
    
    /**
     * @dev Trigger monitoring alert
     */
    function triggerMonitoringAlert(
        RiskLevel severity,
        string calldata alertType,
        string calldata description,
        bytes calldata alertData
    ) external authorizedMonitoring whenNotPaused returns (uint256 alertId) {
        require(bytes(alertType).length > 0, "KarmaInsuranceManager: invalid alert type");
        require(bytes(description).length > 0, "KarmaInsuranceManager: invalid description");
        
        totalMonitoringAlerts++;
        alertId = totalMonitoringAlerts;
        
        MonitoringAlert storage alert = monitoringAlerts[alertId];
        alert.alertId = alertId;
        alert.monitoringSystem = msg.sender;
        alert.severity = severity;
        alert.alertType = alertType;
        alert.description = description;
        alert.alertData = alertData;
        alert.triggeredAt = block.timestamp;
        
        // Update mappings
        alertsBySystem[msg.sender].push(alertId);
        
        emit MonitoringAlertTriggered(alertId, msg.sender, severity, alertType, block.timestamp);
    }
    
    /**
     * @dev Acknowledge monitoring alert
     */
    function acknowledgeMonitoringAlert(uint256 alertId) external onlyInsuranceManager {
        require(alertId > 0 && alertId <= totalMonitoringAlerts, "KarmaInsuranceManager: invalid alert ID");
        
        MonitoringAlert storage alert = monitoringAlerts[alertId];
        require(!alert.isAcknowledged, "KarmaInsuranceManager: alert already acknowledged");
        
        alert.isAcknowledged = true;
        alert.acknowledgedAt = block.timestamp;
        alert.acknowledgedBy = msg.sender;
        
        emit MonitoringAlertAcknowledged(alertId, msg.sender, block.timestamp);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get insurance fund metrics
     */
    function getInsuranceFundMetrics() external view returns (InsuranceFundMetrics memory) {
        return fundMetrics;
    }
    
    /**
     * @dev Get claim details
     */
    function getClaim(uint256 claimId) external view validClaimId(claimId) returns (InsuranceClaim memory) {
        return claims[claimId];
    }
    
    /**
     * @dev Get risk assessment
     */
    function getRiskAssessment(uint256 assessmentId) 
        external view validAssessmentId(assessmentId) returns (RiskAssessment memory) {
        return riskAssessments[assessmentId];
    }
    
    /**
     * @dev Get emergency incident
     */
    function getEmergencyIncident(uint256 incidentId) 
        external view validIncidentId(incidentId) returns (EmergencyIncident memory) {
        return emergencyIncidents[incidentId];
    }
    
    /**
     * @dev Get insurance protocol details
     */
    function getInsuranceProtocol(address protocolAddress) external view returns (InsuranceProtocol memory) {
        return insuranceProtocols[protocolAddress];
    }
    
    /**
     * @dev Get monitoring alert
     */
    function getMonitoringAlert(uint256 alertId) external view returns (MonitoringAlert memory) {
        require(alertId > 0 && alertId <= totalMonitoringAlerts, "KarmaInsuranceManager: invalid alert ID");
        return monitoringAlerts[alertId];
    }
    
    /**
     * @dev Get claims by claimant
     */
    function getClaimsByClaimant(address claimant) external view returns (uint256[] memory) {
        return claimsByClaimant[claimant];
    }
    
    /**
     * @dev Get active emergency incidents
     */
    function getActiveEmergencyIncidents() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= totalEmergencyIncidents; i++) {
            if (activeEmergencies[i]) {
                count++;
            }
        }
        
        uint256[] memory activeIncidents = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= totalEmergencyIncidents; i++) {
            if (activeEmergencies[i]) {
                activeIncidents[index] = i;
                index++;
            }
        }
        
        return activeIncidents;
    }
    
    // ============ INTERNAL HELPER FUNCTIONS ============
    
    function _updateClaimStatusMapping(uint256 claimId, ClaimStatus newStatus) internal {
        // Remove from old status mapping (if needed)
        // Add to new status mapping
        claimsByStatus[newStatus].push(claimId);
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
     * @dev Emergency withdraw (admin only)
     */
    function emergencyWithdraw(address recipient, uint256 amount) 
        external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(recipient != address(0), "KarmaInsuranceManager: invalid recipient");
        require(amount <= fundMetrics.availableBalance, "KarmaInsuranceManager: insufficient balance");
        
        fundMetrics.availableBalance -= amount;
        usdcToken.safeTransfer(recipient, amount);
    }
} 