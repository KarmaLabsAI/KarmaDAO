// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KarmaSecurityMonitoring
 * @dev Stage 9.1 Security Infrastructure Implementation
 * 
 * Implements:
 * - Advanced monitoring via Forta, Defender, or similar
 * - Anomaly detection and automatic response systems
 * - Security dashboard and real-time threat monitoring
 * - Forensic capabilities for post-incident analysis
 */
contract KarmaSecurityMonitoring is AccessControl, Pausable, ReentrancyGuard {
    
    // ============ CONSTANTS ============
    
    bytes32 public constant MONITORING_MANAGER_ROLE = keccak256("MONITORING_MANAGER_ROLE");
    bytes32 public constant THREAT_ANALYST_ROLE = keccak256("THREAT_ANALYST_ROLE");
    bytes32 public constant RESPONSE_COORDINATOR_ROLE = keccak256("RESPONSE_COORDINATOR_ROLE");
    bytes32 public constant DASHBOARD_OPERATOR_ROLE = keccak256("DASHBOARD_OPERATOR_ROLE");
    bytes32 public constant FORENSIC_INVESTIGATOR_ROLE = keccak256("FORENSIC_INVESTIGATOR_ROLE");
    bytes32 public constant EXTERNAL_MONITOR_ROLE = keccak256("EXTERNAL_MONITOR_ROLE");
    
    uint256 public constant THREAT_RESPONSE_TIMEOUT = 30 minutes; // 30 min response timeout
    uint256 public constant ANOMALY_THRESHOLD = 3; // 3 anomalies trigger alert
    uint256 public constant MONITORING_INTERVAL = 1 hours; // 1 hour monitoring cycles
    uint256 public constant FORENSIC_RETENTION_PERIOD = 365 days; // 1 year retention
    uint256 public constant DASHBOARD_UPDATE_INTERVAL = 5 minutes; // 5 min dashboard updates
    
    // ============ ENUMS ============
    
    enum ThreatLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL,
        EMERGENCY
    }
    
    enum MonitoringSystemType {
        FORTA,
        DEFENDER,
        CHAINLINK_KEEPERS,
        CUSTOM_MONITOR,
        THIRD_PARTY
    }
    
    enum AnomalyType {
        UNUSUAL_TRANSACTION_VOLUME,
        SUSPICIOUS_ADDRESS_ACTIVITY,
        GOVERNANCE_MANIPULATION,
        ORACLE_DEVIATION,
        LIQUIDITY_DRAIN,
        FLASH_LOAN_ATTACK,
        FRONT_RUNNING,
        MEV_EXPLOITATION,
        ACCESS_CONTROL_VIOLATION,
        ECONOMIC_ATTACK
    }
    
    enum ResponseAction {
        PAUSE_CONTRACT,
        BLOCK_ADDRESS,
        ALERT_ADMINS,
        TRIGGER_EMERGENCY,
        ADJUST_PARAMETERS,
        INITIATE_RECOVERY,
        CONTACT_AUTHORITIES,
        COORDINATE_DISCLOSURE
    }
    
    enum IncidentStatus {
        DETECTED,
        INVESTIGATING,
        CONFIRMED,
        RESPONDING,
        CONTAINED,
        RESOLVED,
        POST_MORTEM
    }
    
    enum ForensicType {
        TRANSACTION_ANALYSIS,
        ADDRESS_TRACKING,
        FUND_FLOW_ANALYSIS,
        VULNERABILITY_ASSESSMENT,
        ATTACK_RECONSTRUCTION,
        EVIDENCE_COLLECTION,
        TIMELINE_ANALYSIS,
        ATTRIBUTION_ANALYSIS
    }
    
    // ============ STRUCTS ============
    
    struct MonitoringSystem {
        uint256 systemId;
        MonitoringSystemType systemType;
        string name;
        address systemAddress;
        bool isActive;
        uint256 priority; // 1-10 priority level
        string[] monitoredContracts;
        string[] alertTypes;
        uint256 lastHeartbeat;
        uint256 alertsTriggered;
        uint256 falsePositives;
        uint256 validAlerts;
        string configuration;
        bytes configurationData;
        uint256 integrationDate;
    }
    
    struct ThreatDetection {
        uint256 detectionId;
        address monitoringSystem;
        ThreatLevel threatLevel;
        AnomalyType anomalyType;
        address targetContract;
        string description;
        bytes evidenceData;
        uint256 detectedAt;
        uint256 responseDeadline;
        bool isConfirmed;
        uint256 confirmedAt;
        address confirmedBy;
        bool isResolved;
        uint256 resolvedAt;
        string resolution;
        uint256 riskScore; // 0-1000 scale
    }
    
    struct SecurityIncident {
        uint256 incidentId;
        ThreatLevel severity;
        IncidentStatus status;
        string title;
        string description;
        address[] affectedContracts;
        uint256 detectedAt;
        uint256 respondedAt;
        uint256 resolvedAt;
        address[] responders;
        ResponseAction[] actionsTriggered;
        uint256 estimatedImpact; // USD value
        uint256 actualImpact;
        bool requiresForensics;
        uint256 forensicId;
        string[] lessons;
        bytes32 incidentHash;
    }
    
    struct AutomatedResponse {
        uint256 responseId;
        ThreatLevel triggerLevel;
        AnomalyType[] triggerTypes;
        ResponseAction[] actions;
        bool isActive;
        uint256 cooldownPeriod;
        uint256 lastTriggered;
        uint256 successfulTriggers;
        uint256 failedTriggers;
        string[] conditions;
        address[] authorizedExecutors;
        uint256 maxExecutionsPerHour;
        uint256 executionsThisHour;
        uint256 currentHourStart;
    }
    
    struct SecurityDashboard {
        uint256 lastUpdated;
        ThreatLevel currentThreatLevel;
        uint256 activeThreats;
        uint256 totalIncidents;
        uint256 resolvedIncidents;
        uint256 averageResponseTime;
        uint256 systemUptime;
        uint256 monitoringSystems;
        uint256 activeMonitors;
        mapping(ThreatLevel => uint256) threatsByLevel;
        mapping(AnomalyType => uint256) anomaliesByType;
        mapping(IncidentStatus => uint256) incidentsByStatus;
        string[] activeAlerts;
        uint256[] criticalContracts;
        uint256 securityScore; // 0-1000 scale
    }
    
    struct ForensicInvestigation {
        uint256 investigationId;
        uint256 incidentId;
        ForensicType investigationType;
        address investigator;
        uint256 startedAt;
        uint256 completedAt;
        bool isActive;
        string findings;
        bytes32[] evidenceHashes;
        address[] suspiciousAddresses;
        uint256[] relatedTransactions;
        string methodology;
        string conclusions;
        uint256 confidenceLevel; // 0-100 scale
        bool isPublic;
        uint256 disclosureDate;
    }
    
    struct MonitoringMetrics {
        uint256 totalDetections;
        uint256 falsePositives;
        uint256 truePositives;
        uint256 averageResponseTime;
        uint256 systemUptime;
        uint256 averageIncidentResolutionTime;
        uint256 criticalIncidents;
        uint256 preventedAttacks;
        uint256 totalForensicInvestigations;
        uint256 publicDisclosures;
        mapping(MonitoringSystemType => uint256) systemTypeMetrics;
        mapping(ThreatLevel => uint256) threatLevelMetrics;
        mapping(AnomalyType => uint256) anomalyTypeMetrics;
    }
    
    // ============ STATE VARIABLES ============
    
    // Monitoring systems
    mapping(uint256 => MonitoringSystem) private _monitoringSystems;
    mapping(address => uint256) public systemAddressToId;
    mapping(MonitoringSystemType => uint256[]) public systemsByType;
    uint256 public totalMonitoringSystems;
    uint256[] public activeSystemIds;
    
    // Threat detection
    mapping(uint256 => ThreatDetection) private _threatDetections;
    mapping(address => uint256[]) public detectionsByContract;
    mapping(ThreatLevel => uint256[]) public detectionsByLevel;
    mapping(AnomalyType => uint256[]) public detectionsByAnomaly;
    uint256 public totalThreatDetections;
    
    // Security incidents
    mapping(uint256 => SecurityIncident) private _securityIncidents;
    mapping(IncidentStatus => uint256[]) public incidentsByStatus;
    mapping(ThreatLevel => uint256[]) public incidentsByLevel;
    uint256 public totalSecurityIncidents;
    
    // Automated responses
    mapping(uint256 => AutomatedResponse) private _automatedResponses;
    mapping(ThreatLevel => uint256[]) public responsesByTriggerLevel;
    uint256 public totalAutomatedResponses;
    
    // Security dashboard
    SecurityDashboard private _securityDashboard;
    
    // Forensic investigations
    mapping(uint256 => ForensicInvestigation) private _forensicInvestigations;
    mapping(uint256 => uint256) public incidentToForensicId;
    mapping(ForensicType => uint256[]) public investigationsByType;
    uint256 public totalForensicInvestigations;
    
    // Monitoring metrics
    MonitoringMetrics private _monitoringMetrics;
    
    // Configuration
    mapping(address => bool) public authorizedContracts;
    mapping(string => bool) public criticalAlertTypes;
    mapping(address => ThreatLevel) public contractThreatLevels;
    
    // Real-time monitoring
    uint256 public lastMonitoringCycle;
    uint256 public currentThreatLevel; // Encoded as uint256
    bool public isMonitoringActive;
    
    // ============ EVENTS ============
    
    event MonitoringSystemRegistered(
        uint256 indexed systemId,
        MonitoringSystemType indexed systemType,
        address indexed systemAddress,
        string name,
        uint256 timestamp
    );
    
    event ThreatDetected(
        uint256 indexed detectionId,
        address indexed monitoringSystem,
        ThreatLevel indexed threatLevel,
        AnomalyType anomalyType,
        address targetContract,
        uint256 timestamp
    );
    
    event SecurityIncidentCreated(
        uint256 indexed incidentId,
        ThreatLevel indexed severity,
        string title,
        address[] affectedContracts,
        uint256 timestamp
    );
    
    event AutomatedResponseTriggered(
        uint256 indexed responseId,
        uint256 indexed incidentId,
        ResponseAction[] actions,
        uint256 timestamp
    );
    
    event SecurityDashboardUpdated(
        ThreatLevel currentThreatLevel,
        uint256 activeThreats,
        uint256 securityScore,
        uint256 timestamp
    );
    
    event ForensicInvestigationStarted(
        uint256 indexed investigationId,
        uint256 indexed incidentId,
        ForensicType indexed investigationType,
        address investigator,
        uint256 timestamp
    );
    
    event ForensicInvestigationCompleted(
        uint256 indexed investigationId,
        string findings,
        uint256 confidenceLevel,
        bool isPublic,
        uint256 timestamp
    );
    
    event ThreatLevelEscalated(
        uint256 indexed incidentId,
        ThreatLevel oldLevel,
        ThreatLevel newLevel,
        string reason,
        uint256 timestamp
    );
    
    event MonitoringSystemHeartbeat(
        uint256 indexed systemId,
        address indexed systemAddress,
        uint256 timestamp
    );
    
    event EmergencyResponseActivated(
        uint256 indexed incidentId,
        ThreatLevel threatLevel,
        ResponseAction[] actions,
        uint256 timestamp
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyMonitoringManager() {
        require(hasRole(MONITORING_MANAGER_ROLE, msg.sender), "KarmaSecurityMonitoring: caller is not monitoring manager");
        _;
    }
    
    modifier onlyThreatAnalyst() {
        require(hasRole(THREAT_ANALYST_ROLE, msg.sender), "KarmaSecurityMonitoring: caller is not threat analyst");
        _;
    }
    
    modifier onlyResponseCoordinator() {
        require(hasRole(RESPONSE_COORDINATOR_ROLE, msg.sender), "KarmaSecurityMonitoring: caller is not response coordinator");
        _;
    }
    
    modifier onlyDashboardOperator() {
        require(hasRole(DASHBOARD_OPERATOR_ROLE, msg.sender), "KarmaSecurityMonitoring: caller is not dashboard operator");
        _;
    }
    
    modifier onlyForensicInvestigator() {
        require(hasRole(FORENSIC_INVESTIGATOR_ROLE, msg.sender), "KarmaSecurityMonitoring: caller is not forensic investigator");
        _;
    }
    
    modifier onlyExternalMonitor() {
        require(hasRole(EXTERNAL_MONITOR_ROLE, msg.sender), "KarmaSecurityMonitoring: caller is not external monitor");
        _;
    }
    
    modifier validSystemId(uint256 systemId) {
        require(systemId > 0 && systemId <= totalMonitoringSystems, "KarmaSecurityMonitoring: invalid system ID");
        _;
    }
    
    modifier validDetectionId(uint256 detectionId) {
        require(detectionId > 0 && detectionId <= totalThreatDetections, "KarmaSecurityMonitoring: invalid detection ID");
        _;
    }
    
    modifier validIncidentId(uint256 incidentId) {
        require(incidentId > 0 && incidentId <= totalSecurityIncidents, "KarmaSecurityMonitoring: invalid incident ID");
        _;
    }
    
    modifier validInvestigationId(uint256 investigationId) {
        require(investigationId > 0 && investigationId <= totalForensicInvestigations, "KarmaSecurityMonitoring: invalid investigation ID");
        _;
    }
    
    modifier activeMonitoring() {
        require(isMonitoringActive, "KarmaSecurityMonitoring: monitoring is not active");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _admin) {
        require(_admin != address(0), "KarmaSecurityMonitoring: invalid admin");
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MONITORING_MANAGER_ROLE, _admin);
        _grantRole(THREAT_ANALYST_ROLE, _admin);
        _grantRole(RESPONSE_COORDINATOR_ROLE, _admin);
        _grantRole(DASHBOARD_OPERATOR_ROLE, _admin);
        _grantRole(FORENSIC_INVESTIGATOR_ROLE, _admin);
        _grantRole(EXTERNAL_MONITOR_ROLE, _admin);
        
        // Initialize monitoring
        isMonitoringActive = true;
        lastMonitoringCycle = block.timestamp;
        currentThreatLevel = uint256(ThreatLevel.LOW);
        
        // Initialize dashboard
        _securityDashboard.lastUpdated = block.timestamp;
        _securityDashboard.currentThreatLevel = ThreatLevel.LOW;
        _securityDashboard.securityScore = 850; // Initial score of 85%
    }
    
    // ============ MONITORING SYSTEM MANAGEMENT ============
    
    /**
     * @dev Register monitoring system (Forta, Defender, etc.)
     */
    function registerMonitoringSystem(
        MonitoringSystemType systemType,
        string calldata name,
        address systemAddress,
        uint256 priority,
        string[] calldata monitoredContracts,
        string[] calldata alertTypes,
        string calldata configuration,
        bytes calldata configurationData
    ) external onlyMonitoringManager whenNotPaused nonReentrant returns (uint256 systemId) {
        require(bytes(name).length > 0, "KarmaSecurityMonitoring: invalid name");
        require(systemAddress != address(0), "KarmaSecurityMonitoring: invalid system address");
        require(priority >= 1 && priority <= 10, "KarmaSecurityMonitoring: invalid priority");
        require(monitoredContracts.length > 0, "KarmaSecurityMonitoring: no monitored contracts");
        
        totalMonitoringSystems++;
        systemId = totalMonitoringSystems;
        
        MonitoringSystem storage system = _monitoringSystems[systemId];
        system.systemId = systemId;
        system.systemType = systemType;
        system.name = name;
        system.systemAddress = systemAddress;
        system.isActive = true;
        system.priority = priority;
        system.monitoredContracts = monitoredContracts;
        system.alertTypes = alertTypes;
        system.lastHeartbeat = block.timestamp;
        system.configuration = configuration;
        system.configurationData = configurationData;
        system.integrationDate = block.timestamp;
        
        // Update mappings
        systemAddressToId[systemAddress] = systemId;
        systemsByType[systemType].push(systemId);
        activeSystemIds.push(systemId);
        
        // Grant monitoring role to system
        _grantRole(EXTERNAL_MONITOR_ROLE, systemAddress);
        
        // Update metrics
        _monitoringMetrics.systemTypeMetrics[systemType]++;
        _securityDashboard.monitoringSystems++;
        _securityDashboard.activeMonitors++;
        
        emit MonitoringSystemRegistered(systemId, systemType, systemAddress, name, block.timestamp);
    }
    
    /**
     * @dev Send heartbeat from monitoring system
     */
    function sendHeartbeat() external onlyExternalMonitor activeMonitoring {
        uint256 systemId = systemAddressToId[msg.sender];
        require(systemId > 0, "KarmaSecurityMonitoring: system not registered");
        
        MonitoringSystem storage system = _monitoringSystems[systemId];
        system.lastHeartbeat = block.timestamp;
        
        emit MonitoringSystemHeartbeat(systemId, msg.sender, block.timestamp);
    }
    
    // ============ THREAT DETECTION ============
    
    /**
     * @dev Report threat detection
     */
    function reportThreatDetection(
        ThreatLevel threatLevel,
        AnomalyType anomalyType,
        address targetContract,
        string calldata description,
        bytes calldata evidenceData,
        uint256 riskScore
    ) external onlyExternalMonitor activeMonitoring nonReentrant returns (uint256 detectionId) {
        require(targetContract != address(0), "KarmaSecurityMonitoring: invalid target contract");
        require(bytes(description).length > 0, "KarmaSecurityMonitoring: invalid description");
        require(riskScore <= 1000, "KarmaSecurityMonitoring: invalid risk score");
        
        totalThreatDetections++;
        detectionId = totalThreatDetections;
        
        uint256 responseDeadline = block.timestamp + THREAT_RESPONSE_TIMEOUT;
        
        ThreatDetection storage detection = _threatDetections[detectionId];
        detection.detectionId = detectionId;
        detection.monitoringSystem = msg.sender;
        detection.threatLevel = threatLevel;
        detection.anomalyType = anomalyType;
        detection.targetContract = targetContract;
        detection.description = description;
        detection.evidenceData = evidenceData;
        detection.detectedAt = block.timestamp;
        detection.responseDeadline = responseDeadline;
        detection.riskScore = riskScore;
        
        // Update mappings
        detectionsByContract[targetContract].push(detectionId);
        detectionsByLevel[threatLevel].push(detectionId);
        detectionsByAnomaly[anomalyType].push(detectionId);
        
        // Update metrics
        _monitoringMetrics.totalDetections++;
        _monitoringMetrics.anomalyTypeMetrics[anomalyType]++;
        _monitoringMetrics.threatLevelMetrics[threatLevel]++;
        
        // Update dashboard
        _securityDashboard.activeThreats++;
        _securityDashboard.threatsByLevel[threatLevel]++;
        _securityDashboard.anomaliesByType[anomalyType]++;
        
        // Trigger automated responses if configured
        _triggerAutomatedResponses(threatLevel, anomalyType, detectionId);
        
        // Create incident for high-level threats
        if (threatLevel >= ThreatLevel.HIGH) {
            _createSecurityIncident(detectionId, threatLevel, description, targetContract);
        }
        
        emit ThreatDetected(detectionId, msg.sender, threatLevel, anomalyType, targetContract, block.timestamp);
    }
    
    /**
     * @dev Confirm threat detection
     */
    function confirmThreatDetection(
        uint256 detectionId,
        bool isConfirmed,
        string calldata resolution
    ) external onlyThreatAnalyst validDetectionId(detectionId) whenNotPaused {
        ThreatDetection storage detection = _threatDetections[detectionId];
        require(!detection.isConfirmed && !detection.isResolved, "KarmaSecurityMonitoring: detection already processed");
        
        detection.isConfirmed = isConfirmed;
        detection.confirmedAt = block.timestamp;
        detection.confirmedBy = msg.sender;
        
        if (isConfirmed) {
            // Update monitoring system metrics
            uint256 systemId = systemAddressToId[detection.monitoringSystem];
            if (systemId > 0) {
                _monitoringSystems[systemId].validAlerts++;
            }
            
            _monitoringMetrics.truePositives++;
        } else {
            // Mark as false positive
            uint256 systemId = systemAddressToId[detection.monitoringSystem];
            if (systemId > 0) {
                _monitoringSystems[systemId].falsePositives++;
            }
            
            _monitoringMetrics.falsePositives++;
            
            // Resolve as false positive
            detection.isResolved = true;
            detection.resolvedAt = block.timestamp;
            detection.resolution = resolution;
            
            // Update dashboard
            _securityDashboard.activeThreats--;
        }
    }
    
    // ============ SECURITY INCIDENT MANAGEMENT ============
    
    /**
     * @dev Create security incident
     */
    function createSecurityIncident(
        ThreatLevel severity,
        string calldata title,
        string calldata description,
        address[] calldata affectedContracts,
        bool requiresForensics
    ) external onlyResponseCoordinator whenNotPaused nonReentrant returns (uint256 incidentId) {
        require(bytes(title).length > 0, "KarmaSecurityMonitoring: invalid title");
        require(bytes(description).length > 0, "KarmaSecurityMonitoring: invalid description");
        require(affectedContracts.length > 0, "KarmaSecurityMonitoring: no affected contracts");
        
        totalSecurityIncidents++;
        incidentId = totalSecurityIncidents;
        
        // Create incident hash
        bytes32 incidentHash = keccak256(abi.encodePacked(
            title, description, block.timestamp, msg.sender, affectedContracts
        ));
        
        SecurityIncident storage incident = _securityIncidents[incidentId];
        incident.incidentId = incidentId;
        incident.severity = severity;
        incident.status = IncidentStatus.DETECTED;
        incident.title = title;
        incident.description = description;
        incident.affectedContracts = affectedContracts;
        incident.detectedAt = block.timestamp;
        incident.requiresForensics = requiresForensics;
        incident.incidentHash = incidentHash;
        
        // Update mappings
        incidentsByStatus[IncidentStatus.DETECTED].push(incidentId);
        incidentsByLevel[severity].push(incidentId);
        
        // Update metrics
        _securityDashboard.totalIncidents++;
        _securityDashboard.incidentsByStatus[IncidentStatus.DETECTED]++;
        
        if (severity == ThreatLevel.CRITICAL) {
            _monitoringMetrics.criticalIncidents++;
        }
        
        // Start forensic investigation if required
        if (requiresForensics) {
            _startForensicInvestigation(incidentId, ForensicType.VULNERABILITY_ASSESSMENT);
        }
        
        emit SecurityIncidentCreated(incidentId, severity, title, affectedContracts, block.timestamp);
    }
    
    /**
     * @dev Update incident status
     */
    function updateIncidentStatus(
        uint256 incidentId,
        IncidentStatus newStatus,
        string calldata statusUpdate
    ) external onlyResponseCoordinator validIncidentId(incidentId) whenNotPaused {
        SecurityIncident storage incident = _securityIncidents[incidentId];
        IncidentStatus oldStatus = incident.status;
        
        incident.status = newStatus;
        
        if (newStatus == IncidentStatus.RESPONDING && incident.respondedAt == 0) {
            incident.respondedAt = block.timestamp;
            incident.responders.push(msg.sender);
        }
        
        if (newStatus == IncidentStatus.RESOLVED && incident.resolvedAt == 0) {
            incident.resolvedAt = block.timestamp;
            _securityDashboard.resolvedIncidents++;
            
            // Calculate response time
            uint256 responseTime = incident.resolvedAt - incident.detectedAt;
            _monitoringMetrics.averageIncidentResolutionTime = 
                (_monitoringMetrics.averageIncidentResolutionTime + responseTime) / 2;
        }
        
        // Update status mappings
        incidentsByStatus[newStatus].push(incidentId);
        _securityDashboard.incidentsByStatus[oldStatus]--;
        _securityDashboard.incidentsByStatus[newStatus]++;
    }
    
    // ============ AUTOMATED RESPONSE SYSTEM ============
    
    /**
     * @dev Configure automated response
     */
    function configureAutomatedResponse(
        ThreatLevel triggerLevel,
        AnomalyType[] calldata triggerTypes,
        ResponseAction[] calldata actions,
        uint256 cooldownPeriod,
        string[] calldata conditions,
        address[] calldata authorizedExecutors,
        uint256 maxExecutionsPerHour
    ) external onlyResponseCoordinator whenNotPaused nonReentrant returns (uint256 responseId) {
        require(triggerTypes.length > 0, "KarmaSecurityMonitoring: no trigger types");
        require(actions.length > 0, "KarmaSecurityMonitoring: no actions");
        require(cooldownPeriod >= 5 minutes, "KarmaSecurityMonitoring: cooldown too short");
        require(maxExecutionsPerHour > 0, "KarmaSecurityMonitoring: invalid max executions");
        
        totalAutomatedResponses++;
        responseId = totalAutomatedResponses;
        
        AutomatedResponse storage response = _automatedResponses[responseId];
        response.responseId = responseId;
        response.triggerLevel = triggerLevel;
        response.triggerTypes = triggerTypes;
        response.actions = actions;
        response.isActive = true;
        response.cooldownPeriod = cooldownPeriod;
        response.conditions = conditions;
        response.authorizedExecutors = authorizedExecutors;
        response.maxExecutionsPerHour = maxExecutionsPerHour;
        response.currentHourStart = block.timestamp;
        
        // Update mappings
        responsesByTriggerLevel[triggerLevel].push(responseId);
    }
    
    /**
     * @dev Trigger automated response
     */
    function _triggerAutomatedResponses(
        ThreatLevel threatLevel,
        AnomalyType anomalyType,
        uint256 detectionId
    ) internal {
        uint256[] memory responses = responsesByTriggerLevel[threatLevel];
        
        for (uint256 i = 0; i < responses.length; i++) {
            uint256 responseId = responses[i];
            AutomatedResponse storage response = _automatedResponses[responseId];
            
            if (!response.isActive) continue;
            
            // Check cooldown
            if (block.timestamp < response.lastTriggered + response.cooldownPeriod) continue;
            
            // Check hourly limit
            if (block.timestamp >= response.currentHourStart + 1 hours) {
                response.currentHourStart = block.timestamp;
                response.executionsThisHour = 0;
            }
            
            if (response.executionsThisHour >= response.maxExecutionsPerHour) continue;
            
            // Check if anomaly type matches
            bool typeMatches = false;
            for (uint256 j = 0; j < response.triggerTypes.length; j++) {
                if (response.triggerTypes[j] == anomalyType) {
                    typeMatches = true;
                    break;
                }
            }
            
            if (typeMatches) {
                response.lastTriggered = block.timestamp;
                response.executionsThisHour++;
                response.successfulTriggers++;
                
                emit AutomatedResponseTriggered(responseId, detectionId, response.actions, block.timestamp);
            }
        }
    }
    
    // ============ SECURITY DASHBOARD ============
    
    /**
     * @dev Update security dashboard
     */
    function updateSecurityDashboard() external onlyDashboardOperator whenNotPaused {
        _securityDashboard.lastUpdated = block.timestamp;
        
        // Calculate current threat level based on active threats
        ThreatLevel newThreatLevel = _calculateCurrentThreatLevel();
        _securityDashboard.currentThreatLevel = newThreatLevel;
        currentThreatLevel = uint256(newThreatLevel);
        
        // Update system uptime
        _securityDashboard.systemUptime = block.timestamp - lastMonitoringCycle;
        
        // Calculate security score
        _securityDashboard.securityScore = _calculateSecurityScore();
        
        emit SecurityDashboardUpdated(
            newThreatLevel,
            _securityDashboard.activeThreats,
            _securityDashboard.securityScore,
            block.timestamp
        );
    }
    
    // ============ FORENSIC ANALYSIS ============
    
    /**
     * @dev Start forensic investigation
     */
    function startForensicInvestigation(
        uint256 incidentId,
        ForensicType investigationType,
        string calldata methodology
    ) external onlyForensicInvestigator validIncidentId(incidentId) whenNotPaused nonReentrant returns (uint256 investigationId) {
        require(bytes(methodology).length > 0, "KarmaSecurityMonitoring: invalid methodology");
        
        investigationId = _startForensicInvestigation(incidentId, investigationType);
        
        ForensicInvestigation storage investigation = _forensicInvestigations[investigationId];
        investigation.methodology = methodology;
        investigation.investigator = msg.sender;
    }
    
    /**
     * @dev Complete forensic investigation
     */
    function completeForensicInvestigation(
        uint256 investigationId,
        string calldata findings,
        bytes32[] calldata evidenceHashes,
        address[] calldata suspiciousAddresses,
        uint256[] calldata relatedTransactions,
        string calldata conclusions,
        uint256 confidenceLevel,
        bool isPublic
    ) external onlyForensicInvestigator validInvestigationId(investigationId) whenNotPaused {
        require(bytes(findings).length > 0, "KarmaSecurityMonitoring: invalid findings");
        require(confidenceLevel <= 100, "KarmaSecurityMonitoring: invalid confidence level");
        
        ForensicInvestigation storage investigation = _forensicInvestigations[investigationId];
        require(investigation.isActive, "KarmaSecurityMonitoring: investigation not active");
        require(investigation.investigator == msg.sender, "KarmaSecurityMonitoring: not investigation owner");
        
        investigation.completedAt = block.timestamp;
        investigation.isActive = false;
        investigation.findings = findings;
        investigation.evidenceHashes = evidenceHashes;
        investigation.suspiciousAddresses = suspiciousAddresses;
        investigation.relatedTransactions = relatedTransactions;
        investigation.conclusions = conclusions;
        investigation.confidenceLevel = confidenceLevel;
        investigation.isPublic = isPublic;
        
        if (isPublic) {
            investigation.disclosureDate = block.timestamp + 30 days; // 30 day disclosure delay
            _monitoringMetrics.publicDisclosures++;
        }
        
        emit ForensicInvestigationCompleted(
            investigationId,
            findings,
            confidenceLevel,
            isPublic,
            block.timestamp
        );
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get monitoring system details
     */
    function getMonitoringSystem(uint256 systemId) 
        external view validSystemId(systemId) returns (MonitoringSystem memory) {
        return _monitoringSystems[systemId];
    }
    
    /**
     * @dev Get threat detection details
     */
    function getThreatDetection(uint256 detectionId) 
        external view validDetectionId(detectionId) returns (ThreatDetection memory) {
        return _threatDetections[detectionId];
    }
    
    /**
     * @dev Get security incident details
     */
    function getSecurityIncident(uint256 incidentId) 
        external view validIncidentId(incidentId) returns (SecurityIncident memory) {
        return _securityIncidents[incidentId];
    }
    
    /**
     * @dev Get forensic investigation details
     */
    function getForensicInvestigation(uint256 investigationId) 
        external view validInvestigationId(investigationId) returns (ForensicInvestigation memory) {
        return _forensicInvestigations[investigationId];
    }
    
    /**
     * @dev Get security dashboard data
     */
    function getSecurityDashboard() external view returns (
        uint256 lastUpdated,
        ThreatLevel currentThreatLevel,
        uint256 activeThreats,
        uint256 totalIncidents,
        uint256 resolvedIncidents,
        uint256 securityScore
    ) {
        return (
            _securityDashboard.lastUpdated,
            _securityDashboard.currentThreatLevel,
            _securityDashboard.activeThreats,
            _securityDashboard.totalIncidents,
            _securityDashboard.resolvedIncidents,
            _securityDashboard.securityScore
        );
    }
    
    /**
     * @dev Get monitoring metrics
     */
    function getMonitoringMetrics() external view returns (
        uint256 totalDetections,
        uint256 falsePositives,
        uint256 truePositives,
        uint256 averageResponseTime,
        uint256 criticalIncidents,
        uint256 totalForensicInvestigations
    ) {
        return (
            _monitoringMetrics.totalDetections,
            _monitoringMetrics.falsePositives,
            _monitoringMetrics.truePositives,
            _monitoringMetrics.averageResponseTime,
            _monitoringMetrics.criticalIncidents,
            _monitoringMetrics.totalForensicInvestigations
        );
    }
    
    /**
     * @dev Get active monitoring systems
     */
    function getActiveMonitoringSystems() external view returns (uint256[] memory) {
        return activeSystemIds;
    }
    
    /**
     * @dev Get detections by contract
     */
    function getDetectionsByContract(address contractAddress) external view returns (uint256[] memory) {
        return detectionsByContract[contractAddress];
    }
    
    // ============ INTERNAL HELPER FUNCTIONS ============
    
    function _createSecurityIncident(
        uint256 detectionId,
        ThreatLevel severity,
        string memory description,
        address targetContract
    ) internal returns (uint256 incidentId) {
        totalSecurityIncidents++;
        incidentId = totalSecurityIncidents;
        
        address[] memory affectedContracts = new address[](1);
        affectedContracts[0] = targetContract;
        
        bytes32 incidentHash = keccak256(abi.encodePacked(
            "Auto-generated from detection", detectionId, block.timestamp
        ));
        
        SecurityIncident storage incident = _securityIncidents[incidentId];
        incident.incidentId = incidentId;
        incident.severity = severity;
        incident.status = IncidentStatus.DETECTED;
        incident.title = "Threat Detection Incident";
        incident.description = description;
        incident.affectedContracts = affectedContracts;
        incident.detectedAt = block.timestamp;
        incident.incidentHash = incidentHash;
        
        // Update mappings
        incidentsByStatus[IncidentStatus.DETECTED].push(incidentId);
        incidentsByLevel[severity].push(incidentId);
        
        emit SecurityIncidentCreated(incidentId, severity, "Threat Detection Incident", affectedContracts, block.timestamp);
    }
    
    function _startForensicInvestigation(
        uint256 incidentId,
        ForensicType investigationType
    ) internal returns (uint256 investigationId) {
        totalForensicInvestigations++;
        investigationId = totalForensicInvestigations;
        
        ForensicInvestigation storage investigation = _forensicInvestigations[investigationId];
        investigation.investigationId = investigationId;
        investigation.incidentId = incidentId;
        investigation.investigationType = investigationType;
        investigation.startedAt = block.timestamp;
        investigation.isActive = true;
        
        // Update mappings
        incidentToForensicId[incidentId] = investigationId;
        investigationsByType[investigationType].push(investigationId);
        
        // Update incident
        _securityIncidents[incidentId].forensicId = investigationId;
        
        emit ForensicInvestigationStarted(
            investigationId,
            incidentId,
            investigationType,
            msg.sender,
            block.timestamp
        );
    }
    
    function _calculateCurrentThreatLevel() internal view returns (ThreatLevel) {
        if (_securityDashboard.activeThreats == 0) return ThreatLevel.LOW;
        
        // Check for critical threats
        if (_securityDashboard.threatsByLevel[ThreatLevel.CRITICAL] > 0) {
            return ThreatLevel.CRITICAL;
        }
        
        // Check for high threats
        if (_securityDashboard.threatsByLevel[ThreatLevel.HIGH] > 0) {
            return ThreatLevel.HIGH;
        }
        
        // Check for medium threats
        if (_securityDashboard.threatsByLevel[ThreatLevel.MEDIUM] > 2) {
            return ThreatLevel.HIGH; // Multiple medium threats escalate
        } else if (_securityDashboard.threatsByLevel[ThreatLevel.MEDIUM] > 0) {
            return ThreatLevel.MEDIUM;
        }
        
        return ThreatLevel.LOW;
    }
    
    function _calculateSecurityScore() internal view returns (uint256) {
        uint256 baseScore = 850; // 85% base score
        
        // Deduct for active threats
        uint256 threatPenalty = _securityDashboard.activeThreats * 10;
        if (threatPenalty > baseScore) threatPenalty = baseScore;
        
        // Bonus for resolved incidents
        uint256 resolutionBonus = _securityDashboard.resolvedIncidents * 2;
        if (resolutionBonus > 100) resolutionBonus = 100;
        
        // Calculate false positive ratio
        uint256 totalDetections = _monitoringMetrics.totalDetections;
        if (totalDetections > 0) {
            uint256 fpRatio = (_monitoringMetrics.falsePositives * 100) / totalDetections;
            if (fpRatio > 20) {
                baseScore -= (fpRatio - 20) * 2; // Penalty for high false positive rate
            }
        }
        
        uint256 finalScore = baseScore - threatPenalty + resolutionBonus;
        return finalScore > 1000 ? 1000 : finalScore;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        isMonitoringActive = false;
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        isMonitoringActive = true;
        lastMonitoringCycle = block.timestamp;
    }
    
    /**
     * @dev Set monitoring active status
     */
    function setMonitoringActive(bool active) external onlyMonitoringManager {
        isMonitoringActive = active;
        if (active) {
            lastMonitoringCycle = block.timestamp;
        }
    }
} 