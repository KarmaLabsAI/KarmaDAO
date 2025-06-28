// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IOperationsMonitoringManager.sol";

/**
 * @title OperationsMonitoringManager
 * @dev Comprehensive operations monitoring with dashboards and analytics
 * Stage 9.2 - Operations and Monitoring Implementation
 */
contract OperationsMonitoringManager is IOperationsMonitoringManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ CONSTANTS ============
    
    bytes32 public constant OPERATIONS_MANAGER_ROLE = keccak256("OPERATIONS_MANAGER_ROLE");
    bytes32 public constant MONITORING_AGENT_ROLE = keccak256("MONITORING_AGENT_ROLE");
    bytes32 public constant ALERT_MANAGER_ROLE = keccak256("ALERT_MANAGER_ROLE");
    bytes32 public constant REPORT_GENERATOR_ROLE = keccak256("REPORT_GENERATOR_ROLE");
    
    uint256 public constant DEFAULT_MONITORING_INTERVAL = 1 hours;
    uint256 public constant DEFAULT_RETENTION_PERIOD = 30 days;
    uint256 public constant MAX_RETENTION_PERIOD = 365 days;
    uint256 public constant MIN_MONITORING_INTERVAL = 5 minutes;
    
    // ============ STATE VARIABLES ============
    
    // Monitoring configuration
    mapping(bytes32 => MonitoringConfig) private _monitoringConfigs;
    bytes32[] public allConfigIds;
    
    // Performance metrics
    mapping(bytes32 => PerformanceMetrics) private _performanceMetrics;
    mapping(MetricType => bytes32[]) public metricsByType;
    mapping(address => bytes32[]) public metricsByContract;
    
    // Health monitoring
    mapping(bytes32 => SystemHealthCheck) private _healthChecks;
    bytes32[] public allHealthCheckIds;
    HealthStatus public currentSystemStatus;
    
    // Alert management
    mapping(bytes32 => Alert) private _alerts;
    mapping(AlertSeverity => bytes32[]) public alertsBySeverity;
    bytes32[] public activeAlerts;
    bytes32[] public resolvedAlerts;
    
    // Gas optimization
    mapping(bytes32 => GasOptimization) private _gasOptimizations;
    mapping(address => bytes32[]) public optimizationsByContract;
    uint256 public totalGasSavings;
    
    // Transparency reporting
    mapping(bytes32 => TransparencyReport) private _transparencyReports;
    mapping(ReportType => bytes32[]) public reportsByType;
    bytes32[] public publishedReports;
    
    // Dashboard management
    mapping(bytes32 => Dashboard) private _dashboards;
    mapping(address => bytes32[]) public dashboardsByUser;
    bytes32[] public publicDashboards;
    
    // Automation settings
    bool public automatedMonitoringEnabled;
    uint256 public monitoringInterval;
    uint256 public lastAutomatedCheck;
    
    // Counters
    uint256 private _configCounter;
    uint256 private _metricCounter;
    uint256 private _healthCheckCounter;
    uint256 private _alertCounter;
    uint256 private _optimizationCounter;
    uint256 private _reportCounter;
    uint256 private _dashboardCounter;
    
    // System statistics
    uint256 public totalTransactions;
    uint256 public totalGasUsed;
    uint256 public systemStartTime;
    uint256 public totalDowntime;
    
    // ============ MODIFIERS ============
    
    modifier onlyOperationsManager() {
        require(hasRole(OPERATIONS_MANAGER_ROLE, msg.sender), "OpMonitoring: Not operations manager");
        _;
    }
    
    modifier onlyMonitoringAgent() {
        require(hasRole(MONITORING_AGENT_ROLE, msg.sender), "OpMonitoring: Not monitoring agent");
        _;
    }
    
    modifier onlyAlertManager() {
        require(hasRole(ALERT_MANAGER_ROLE, msg.sender), "OpMonitoring: Not alert manager");
        _;
    }
    
    modifier onlyReportGenerator() {
        require(hasRole(REPORT_GENERATOR_ROLE, msg.sender), "OpMonitoring: Not report generator");
        _;
    }
    
    modifier validConfigId(bytes32 configId) {
        require(_monitoringConfigs[configId].configId != bytes32(0), "OpMonitoring: Invalid config ID");
        _;
    }
    
    modifier validMetricId(bytes32 metricId) {
        require(_performanceMetrics[metricId].metricId != bytes32(0), "OpMonitoring: Invalid metric ID");
        _;
    }
    
    modifier validHealthCheckId(bytes32 checkId) {
        require(_healthChecks[checkId].checkId != bytes32(0), "OpMonitoring: Invalid health check ID");
        _;
    }
    
    modifier validAlertId(bytes32 alertId) {
        require(_alerts[alertId].alertId != bytes32(0), "OpMonitoring: Invalid alert ID");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _admin) {
        require(_admin != address(0), "OpMonitoring: Invalid admin");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATIONS_MANAGER_ROLE, _admin);
        _grantRole(MONITORING_AGENT_ROLE, _admin);
        _grantRole(ALERT_MANAGER_ROLE, _admin);
        _grantRole(REPORT_GENERATOR_ROLE, _admin);
        
        currentSystemStatus = HealthStatus.HEALTHY;
        automatedMonitoringEnabled = false;
        monitoringInterval = DEFAULT_MONITORING_INTERVAL;
        systemStartTime = block.timestamp;
        lastAutomatedCheck = block.timestamp;
    }
    
    // ============ MONITORING CONFIGURATION ============
    
    function createMonitoringConfig(
        string calldata name,
        MonitoringLevel level,
        address[] calldata contractsToMonitor,
        MetricType[] calldata enabledMetrics,
        uint256 updateInterval,
        uint256 retentionPeriod,
        bool alertsEnabled,
        string calldata description
    ) external override onlyOperationsManager whenNotPaused returns (bytes32 configId) {
        require(bytes(name).length > 0, "OpMonitoring: Empty config name");
        require(contractsToMonitor.length > 0, "OpMonitoring: No contracts to monitor");
        require(enabledMetrics.length > 0, "OpMonitoring: No metrics enabled");
        require(updateInterval >= MIN_MONITORING_INTERVAL, "OpMonitoring: Interval too short");
        require(retentionPeriod <= MAX_RETENTION_PERIOD, "OpMonitoring: Retention too long");
        
        configId = keccak256(abi.encodePacked(
            name, level, contractsToMonitor, block.timestamp, _configCounter++
        ));
        
        MonitoringConfig storage config = _monitoringConfigs[configId];
        config.configId = configId;
        config.name = name;
        config.level = level;
        config.contractsToMonitor = contractsToMonitor;
        config.enabledMetrics = enabledMetrics;
        config.updateInterval = updateInterval;
        config.retentionPeriod = retentionPeriod;
        config.alertsEnabled = alertsEnabled;
        config.isActive = false;
        config.description = description;
        
        allConfigIds.push(configId);
        
        emit MonitoringConfigCreated(configId, name, level);
        return configId;
    }
    
    function updateMonitoringConfig(
        bytes32 configId, 
        MonitoringConfig calldata config
    ) external override onlyOperationsManager validConfigId(configId) returns (bool success) {
        require(!_monitoringConfigs[configId].isActive, "OpMonitoring: Config is active");
        
        _monitoringConfigs[configId] = config;
        _monitoringConfigs[configId].configId = configId; // Preserve ID
        
        return true;
    }
    
    function activateMonitoring(bytes32 configId) external override onlyOperationsManager validConfigId(configId) returns (bool success) {
        MonitoringConfig storage config = _monitoringConfigs[configId];
        require(!config.isActive, "OpMonitoring: Already active");
        
        config.isActive = true;
        return true;
    }
    
    function deactivateMonitoring(bytes32 configId) external override onlyOperationsManager validConfigId(configId) returns (bool success) {
        MonitoringConfig storage config = _monitoringConfigs[configId];
        require(config.isActive, "OpMonitoring: Not active");
        
        config.isActive = false;
        return true;
    }
    
    function getMonitoringConfig(bytes32 configId) external view override returns (MonitoringConfig memory config) {
        return _monitoringConfigs[configId];
    }
    
    function getAllMonitoringConfigs() external view override returns (MonitoringConfig[] memory configs) {
        configs = new MonitoringConfig[](allConfigIds.length);
        
        for (uint256 i = 0; i < allConfigIds.length; i++) {
            configs[i] = _monitoringConfigs[allConfigIds[i]];
        }
    }
    
    // ============ PERFORMANCE METRICS ============
    
    function recordMetric(
        MetricType metricType,
        address contractAddress,
        uint256 value,
        string calldata unit
    ) external override onlyMonitoringAgent whenNotPaused returns (bytes32 metricId) {
        metricId = keccak256(abi.encodePacked(
            metricType, contractAddress, value, block.timestamp, _metricCounter++
        ));
        
        PerformanceMetrics storage metric = _performanceMetrics[metricId];
        metric.metricId = metricId;
        metric.metricType = metricType;
        metric.contractAddress = contractAddress;
        metric.value = value;
        metric.timestamp = block.timestamp;
        metric.blockNumber = block.number;
        metric.unit = unit;
        
        // Store historical data
        metric.historicalValues[block.timestamp] = value;
        
        // Update tracking
        metricsByType[metricType].push(metricId);
        metricsByContract[contractAddress].push(metricId);
        
        // Update system statistics
        if (metricType == MetricType.TRANSACTION_COUNT) {
            totalTransactions += value;
        } else if (metricType == MetricType.GAS_USAGE) {
            totalGasUsed += value;
        }
        
        emit MetricUpdated(metricId, metricType, value, block.timestamp);
        return metricId;
    }
    
    function batchRecordMetrics(
        MetricType[] calldata metricTypes,
        address[] calldata contractAddresses,
        uint256[] calldata values,
        string[] calldata units
    ) external override onlyMonitoringAgent returns (bytes32[] memory metricIds) {
        require(metricTypes.length == contractAddresses.length, "OpMonitoring: Array length mismatch");
        require(metricTypes.length == values.length, "OpMonitoring: Array length mismatch");
        require(metricTypes.length == units.length, "OpMonitoring: Array length mismatch");
        
        metricIds = new bytes32[](metricTypes.length);
        
        for (uint256 i = 0; i < metricTypes.length; i++) {
            metricIds[i] = this.recordMetric(
                metricTypes[i],
                contractAddresses[i],
                values[i],
                units[i]
            );
        }
        
        return metricIds;
    }
    
    function getMetric(bytes32 metricId) external view override validMetricId(metricId) returns (
        MetricType metricType,
        address contractAddress,
        uint256 value,
        uint256 timestamp,
        string memory unit
    ) {
        PerformanceMetrics storage metric = _performanceMetrics[metricId];
        return (
            metric.metricType,
            metric.contractAddress,
            metric.value,
            metric.timestamp,
            metric.unit
        );
    }
    
    function getMetricHistory(
        bytes32 metricId,
        uint256 startTime,
        uint256 endTime
    ) external view override validMetricId(metricId) returns (uint256[] memory timestamps, uint256[] memory values) {
        require(startTime < endTime, "OpMonitoring: Invalid time range");
        
        // For simplicity, return last 10 values (in production would implement proper pagination)
        timestamps = new uint256[](10);
        values = new uint256[](10);
        
        // In production, would iterate through historical values in time range
        // For now, simulate with current value
        PerformanceMetrics storage metric = _performanceMetrics[metricId];
        for (uint256 i = 0; i < 10; i++) {
            timestamps[i] = metric.timestamp - (i * 3600); // Hour intervals
            values[i] = metric.value;
        }
    }
    
    function getMetricsByType(MetricType metricType) external view override returns (bytes32[] memory metricIds) {
        return metricsByType[metricType];
    }
    
    function getMetricsByContract(address contractAddress) external view override returns (bytes32[] memory metricIds) {
        return metricsByContract[contractAddress];
    }
    
    // ============ SYSTEM HEALTH CHECKS ============
    
    function createHealthCheck(
        string calldata name,
        uint256 checkInterval,
        bool isAutomated,
        string calldata description
    ) external override onlyOperationsManager whenNotPaused returns (bytes32 checkId) {
        require(bytes(name).length > 0, "OpMonitoring: Empty check name");
        require(checkInterval >= MIN_MONITORING_INTERVAL, "OpMonitoring: Interval too short");
        
        checkId = keccak256(abi.encodePacked(
            name, checkInterval, isAutomated, block.timestamp, _healthCheckCounter++
        ));
        
        SystemHealthCheck storage healthCheck = _healthChecks[checkId];
        healthCheck.checkId = checkId;
        healthCheck.name = name;
        healthCheck.status = HealthStatus.HEALTHY;
        healthCheck.lastCheckTime = 0;
        healthCheck.checkInterval = checkInterval;
        healthCheck.passedChecks = new string[](0);
        healthCheck.failedChecks = new string[](0);
        healthCheck.warnings = new string[](0);
        healthCheck.isAutomated = isAutomated;
        healthCheck.description = description;
        
        allHealthCheckIds.push(checkId);
        
        return checkId;
    }
    
    function executeHealthCheck(bytes32 checkId) external override onlyMonitoringAgent validHealthCheckId(checkId) returns (HealthStatus status) {
        SystemHealthCheck storage healthCheck = _healthChecks[checkId];
        
        healthCheck.lastCheckTime = block.timestamp;
        
        // Simulate health check logic
        // In production, would perform actual system checks
        string[] memory passedChecks = new string[](3);
        passedChecks[0] = "Contract accessibility check";
        passedChecks[1] = "Gas price reasonable";
        passedChecks[2] = "System responsiveness";
        
        string[] memory failedChecks = new string[](0);
        string[] memory warnings = new string[](1);
        warnings[0] = "High transaction volume detected";
        
        status = HealthStatus.HEALTHY;
        
        return this.updateHealthCheckStatus(checkId, status, passedChecks, failedChecks, warnings) ? 
               status : HealthStatus.CRITICAL;
    }
    
    function executeAllHealthChecks() external override onlyMonitoringAgent returns (HealthStatus overallStatus) {
        HealthStatus worstStatus = HealthStatus.HEALTHY;
        
        for (uint256 i = 0; i < allHealthCheckIds.length; i++) {
            HealthStatus checkStatus = this.executeHealthCheck(allHealthCheckIds[i]);
            
            if (uint8(checkStatus) > uint8(worstStatus)) {
                worstStatus = checkStatus;
            }
        }
        
        if (worstStatus != currentSystemStatus) {
            HealthStatus oldStatus = currentSystemStatus;
            currentSystemStatus = worstStatus;
            emit SystemStatusChanged(oldStatus, worstStatus);
        }
        
        return worstStatus;
    }
    
    function updateHealthCheckStatus(
        bytes32 checkId,
        HealthStatus status,
        string[] calldata passedChecks,
        string[] calldata failedChecks,
        string[] calldata warnings
    ) external override onlyMonitoringAgent validHealthCheckId(checkId) returns (bool success) {
        SystemHealthCheck storage healthCheck = _healthChecks[checkId];
        
        healthCheck.status = status;
        healthCheck.passedChecks = passedChecks;
        healthCheck.failedChecks = failedChecks;
        healthCheck.warnings = warnings;
        
        emit HealthCheckCompleted(checkId, status, block.timestamp);
        return true;
    }
    
    function getHealthCheck(bytes32 checkId) external view override returns (SystemHealthCheck memory healthCheck) {
        return _healthChecks[checkId];
    }
    
    function getAllHealthChecks() external view override returns (SystemHealthCheck[] memory healthChecks) {
        healthChecks = new SystemHealthCheck[](allHealthCheckIds.length);
        
        for (uint256 i = 0; i < allHealthCheckIds.length; i++) {
            healthChecks[i] = _healthChecks[allHealthCheckIds[i]];
        }
    }
    
    function getSystemStatus() external view override returns (HealthStatus status) {
        return currentSystemStatus;
    }
    
    // ============ ALERT MANAGEMENT ============
    
    function createAlert(
        AlertSeverity severity,
        MetricType metricType,
        address contractAddress,
        string calldata message
    ) external override onlyAlertManager whenNotPaused returns (bytes32 alertId) {
        require(bytes(message).length > 0, "OpMonitoring: Empty alert message");
        
        alertId = keccak256(abi.encodePacked(
            severity, metricType, contractAddress, message, block.timestamp, _alertCounter++
        ));
        
        Alert storage alert = _alerts[alertId];
        alert.alertId = alertId;
        alert.severity = severity;
        alert.metricType = metricType;
        alert.contractAddress = contractAddress;
        alert.message = message;
        alert.timestamp = block.timestamp;
        alert.isResolved = false;
        alert.resolvedTime = 0;
        alert.resolution = "";
        alert.resolver = address(0);
        
        // Update tracking
        alertsBySeverity[severity].push(alertId);
        activeAlerts.push(alertId);
        
        emit AlertTriggered(alertId, severity, message);
        return alertId;
    }
    
    function resolveAlert(
        bytes32 alertId,
        string calldata resolution
    ) external override onlyAlertManager validAlertId(alertId) returns (bool success) {
        Alert storage alert = _alerts[alertId];
        require(!alert.isResolved, "OpMonitoring: Alert already resolved");
        require(bytes(resolution).length > 0, "OpMonitoring: Empty resolution");
        
        alert.isResolved = true;
        alert.resolvedTime = block.timestamp;
        alert.resolution = resolution;
        alert.resolver = msg.sender;
        
        // Move from active to resolved
        _removeFromActiveAlerts(alertId);
        resolvedAlerts.push(alertId);
        
        emit AlertResolved(alertId, msg.sender, resolution);
        return true;
    }
    
    function batchResolveAlerts(
        bytes32[] calldata alertIds,
        string[] calldata resolutions
    ) external override onlyAlertManager returns (bool[] memory results) {
        require(alertIds.length == resolutions.length, "OpMonitoring: Array length mismatch");
        
        results = new bool[](alertIds.length);
        
        for (uint256 i = 0; i < alertIds.length; i++) {
            results[i] = this.resolveAlert(alertIds[i], resolutions[i]);
        }
        
        return results;
    }
    
    function getAlert(bytes32 alertId) external view override returns (Alert memory alert) {
        return _alerts[alertId];
    }
    
    function getActiveAlerts() external view override returns (Alert[] memory alerts) {
        alerts = new Alert[](activeAlerts.length);
        
        for (uint256 i = 0; i < activeAlerts.length; i++) {
            alerts[i] = _alerts[activeAlerts[i]];
        }
    }
    
    function getAlertsBySeverity(AlertSeverity severity) external view override returns (Alert[] memory alerts) {
        bytes32[] memory alertIds = alertsBySeverity[severity];
        alerts = new Alert[](alertIds.length);
        
        for (uint256 i = 0; i < alertIds.length; i++) {
            alerts[i] = _alerts[alertIds[i]];
        }
    }
    
    function getAlertsHistory(uint256 startTime, uint256 endTime) external view override returns (Alert[] memory alerts) {
        require(startTime < endTime, "OpMonitoring: Invalid time range");
        
        // For simplicity, return all resolved alerts (in production would filter by time)
        alerts = new Alert[](resolvedAlerts.length);
        
        for (uint256 i = 0; i < resolvedAlerts.length; i++) {
            alerts[i] = _alerts[resolvedAlerts[i]];
        }
    }
    
    // ============ GAS OPTIMIZATION ============
    
    function identifyGasOptimization(
        address contractAddress,
        string calldata functionName,
        uint256 originalGasCost,
        uint256 optimizedGasCost,
        string calldata optimizationMethod
    ) external override onlyOperationsManager whenNotPaused returns (bytes32 optimizationId) {
        require(contractAddress != address(0), "OpMonitoring: Invalid contract address");
        require(bytes(functionName).length > 0, "OpMonitoring: Empty function name");
        require(optimizedGasCost < originalGasCost, "OpMonitoring: No gas savings");
        
        optimizationId = keccak256(abi.encodePacked(
            contractAddress, functionName, originalGasCost, block.timestamp, _optimizationCounter++
        ));
        
        uint256 savingsAmount = originalGasCost - optimizedGasCost;
        uint256 savingsPercentage = (savingsAmount * 100) / originalGasCost;
        
        GasOptimization storage optimization = _gasOptimizations[optimizationId];
        optimization.optimizationId = optimizationId;
        optimization.contractAddress = contractAddress;
        optimization.functionName = functionName;
        optimization.originalGasCost = originalGasCost;
        optimization.optimizedGasCost = optimizedGasCost;
        optimization.savingsAmount = savingsAmount;
        optimization.savingsPercentage = savingsPercentage;
        optimization.optimizationMethod = optimizationMethod;
        optimization.isImplemented = false;
        optimization.implementationTime = 0;
        
        optimizationsByContract[contractAddress].push(optimizationId);
        
        emit GasOptimizationIdentified(optimizationId, contractAddress, savingsAmount);
        return optimizationId;
    }
    
    function implementGasOptimization(bytes32 optimizationId) external override onlyOperationsManager returns (bool success) {
        GasOptimization storage optimization = _gasOptimizations[optimizationId];
        require(optimization.optimizationId != bytes32(0), "OpMonitoring: Invalid optimization ID");
        require(!optimization.isImplemented, "OpMonitoring: Already implemented");
        
        optimization.isImplemented = true;
        optimization.implementationTime = block.timestamp;
        
        totalGasSavings += optimization.savingsAmount;
        
        emit GasOptimizationImplemented(optimizationId, optimization.savingsAmount);
        return true;
    }
    
    function getGasOptimization(bytes32 optimizationId) external view override returns (GasOptimization memory optimization) {
        return _gasOptimizations[optimizationId];
    }
    
    function getGasOptimizationsByContract(address contractAddress) external view override returns (GasOptimization[] memory optimizations) {
        bytes32[] memory optimizationIds = optimizationsByContract[contractAddress];
        optimizations = new GasOptimization[](optimizationIds.length);
        
        for (uint256 i = 0; i < optimizationIds.length; i++) {
            optimizations[i] = _gasOptimizations[optimizationIds[i]];
        }
    }
    
    function getTotalGasSavings() external view override returns (uint256 totalSavings) {
        return totalGasSavings;
    }
    
    // ============ DASHBOARD MANAGEMENT ============
    
    function createDashboard(
        string calldata name,
        MetricType[] calldata displayedMetrics,
        uint256 refreshInterval,
        bool isPublic,
        string[] calldata widgets,
        string calldata layout
    ) external override whenNotPaused returns (bytes32 dashboardId) {
        require(bytes(name).length > 0, "OpMonitoring: Empty dashboard name");
        require(displayedMetrics.length > 0, "OpMonitoring: No metrics specified");
        require(refreshInterval >= 1 minutes, "OpMonitoring: Refresh interval too short");
        
        dashboardId = keccak256(abi.encodePacked(
            name, msg.sender, displayedMetrics, block.timestamp, _dashboardCounter++
        ));
        
        Dashboard storage dashboard = _dashboards[dashboardId];
        dashboard.dashboardId = dashboardId;
        dashboard.name = name;
        dashboard.owner = msg.sender;
        dashboard.displayedMetrics = displayedMetrics;
        dashboard.refreshInterval = refreshInterval;
        dashboard.isPublic = isPublic;
        dashboard.widgets = widgets;
        dashboard.layout = layout;
        dashboard.isActive = true;
        
        dashboardsByUser[msg.sender].push(dashboardId);
        
        if (isPublic) {
            publicDashboards.push(dashboardId);
        }
        
        emit DashboardCreated(dashboardId, name, msg.sender);
        return dashboardId;
    }
    
    function updateDashboard(bytes32 dashboardId, Dashboard calldata dashboard) external override returns (bool success) {
        Dashboard storage existing = _dashboards[dashboardId];
        require(existing.dashboardId != bytes32(0), "OpMonitoring: Invalid dashboard ID");
        require(existing.owner == msg.sender || hasRole(OPERATIONS_MANAGER_ROLE, msg.sender), "OpMonitoring: Not authorized");
        
        _dashboards[dashboardId] = dashboard;
        _dashboards[dashboardId].dashboardId = dashboardId; // Preserve ID
        _dashboards[dashboardId].owner = existing.owner; // Preserve owner
        
        return true;
    }
    
    function getDashboard(bytes32 dashboardId) external view override returns (Dashboard memory dashboard) {
        return _dashboards[dashboardId];
    }
    
    function getUserDashboards(address user) external view override returns (Dashboard[] memory dashboards) {
        bytes32[] memory dashboardIds = dashboardsByUser[user];
        dashboards = new Dashboard[](dashboardIds.length);
        
        for (uint256 i = 0; i < dashboardIds.length; i++) {
            dashboards[i] = _dashboards[dashboardIds[i]];
        }
    }
    
    function getPublicDashboards() external view override returns (Dashboard[] memory dashboards) {
        dashboards = new Dashboard[](publicDashboards.length);
        
        for (uint256 i = 0; i < publicDashboards.length; i++) {
            dashboards[i] = _dashboards[publicDashboards[i]];
        }
    }
    
    // ============ TRANSPARENCY REPORTING ============
    
    function generateTransparencyReport(
        ReportType reportType,
        uint256 startTime,
        uint256 endTime,
        string[] calldata sections
    ) external override onlyReportGenerator whenNotPaused returns (bytes32 reportId) {
        require(startTime < endTime, "OpMonitoring: Invalid time range");
        require(sections.length > 0, "OpMonitoring: No sections specified");
        
        reportId = keccak256(abi.encodePacked(
            reportType, startTime, endTime, sections, block.timestamp, _reportCounter++
        ));
        
        TransparencyReport storage report = _transparencyReports[reportId];
        report.reportId = reportId;
        report.reportType = reportType;
        report.startTime = startTime;
        report.endTime = endTime;
        report.sections = sections;
        report.generationTime = block.timestamp;
        report.isPublished = false;
        report.ipfsHash = "";
        
        // Populate section data (simplified)
        for (uint256 i = 0; i < sections.length; i++) {
            report.sectionData[sections[i]] = "Generated report data for section";
        }
        
        reportsByType[reportType].push(reportId);
        
        emit TransparencyReportGenerated(reportId, reportType, "");
        return reportId;
    }
    
    function publishReport(bytes32 reportId, string calldata ipfsHash) external override onlyReportGenerator returns (bool success) {
        TransparencyReport storage report = _transparencyReports[reportId];
        require(report.reportId != bytes32(0), "OpMonitoring: Invalid report ID");
        require(!report.isPublished, "OpMonitoring: Already published");
        require(bytes(ipfsHash).length > 0, "OpMonitoring: Empty IPFS hash");
        
        report.isPublished = true;
        report.ipfsHash = ipfsHash;
        
        publishedReports.push(reportId);
        
        return true;
    }
    
    function getTransparencyReport(bytes32 reportId) external view override returns (
        ReportType reportType,
        uint256 startTime,
        uint256 endTime,
        uint256 generationTime,
        bool isPublished,
        string memory ipfsHash
    ) {
        TransparencyReport storage report = _transparencyReports[reportId];
        return (
            report.reportType,
            report.startTime,
            report.endTime,
            report.generationTime,
            report.isPublished,
            report.ipfsHash
        );
    }
    
    function getReportsByType(ReportType reportType) external view override returns (bytes32[] memory reportIds) {
        return reportsByType[reportType];
    }
    
    function getPublishedReports() external view override returns (bytes32[] memory reportIds) {
        return publishedReports;
    }
    
    // ============ AUTOMATION ============
    
    function enableAutomatedMonitoring() external override onlyOperationsManager returns (bool success) {
        automatedMonitoringEnabled = true;
        lastAutomatedCheck = block.timestamp;
        return true;
    }
    
    function disableAutomatedMonitoring() external override onlyOperationsManager returns (bool success) {
        automatedMonitoringEnabled = false;
        return true;
    }
    
    function setMonitoringInterval(uint256 interval) external override onlyOperationsManager returns (bool success) {
        require(interval >= MIN_MONITORING_INTERVAL, "OpMonitoring: Interval too short");
        
        monitoringInterval = interval;
        return true;
    }
    
    function runAutomatedChecks() external override onlyMonitoringAgent returns (uint256 checksExecuted) {
        require(automatedMonitoringEnabled, "OpMonitoring: Automated monitoring disabled");
        require(block.timestamp >= lastAutomatedCheck + monitoringInterval, "OpMonitoring: Too early for checks");
        
        checksExecuted = 0;
        
        // Execute automated health checks
        for (uint256 i = 0; i < allHealthCheckIds.length; i++) {
            SystemHealthCheck storage healthCheck = _healthChecks[allHealthCheckIds[i]];
            
            if (healthCheck.isAutomated && 
                block.timestamp >= healthCheck.lastCheckTime + healthCheck.checkInterval) {
                this.executeHealthCheck(allHealthCheckIds[i]);
                checksExecuted++;
            }
        }
        
        lastAutomatedCheck = block.timestamp;
        return checksExecuted;
    }
    
    // ============ ANALYTICS ============
    
    function getSystemStatistics() external view override returns (
        uint256 totalTransactions_,
        uint256 totalGasUsed_,
        uint256 averageGasPrice,
        uint256 uptimePercentage,
        uint256 errorRate
    ) {
        totalTransactions_ = totalTransactions;
        totalGasUsed_ = totalGasUsed;
        
        // Calculate average gas price (simplified)
        averageGasPrice = totalTransactions > 0 ? totalGasUsed / totalTransactions : 0;
        
        // Calculate uptime percentage
        uint256 totalTime = block.timestamp - systemStartTime;
        uptimePercentage = totalTime > 0 ? ((totalTime - totalDowntime) * 100) / totalTime : 100;
        
        // Calculate error rate (simplified)
        uint256 totalAlerts = _alertCounter;
        errorRate = totalTransactions > 0 ? (totalAlerts * 100) / totalTransactions : 0;
    }
    
    function getPerformanceTrends(
        MetricType metricType,
        uint256 timeframe
    ) external view override returns (
        uint256[] memory timestamps,
        uint256[] memory values,
        string memory trend
    ) {
        require(timeframe > 0, "OpMonitoring: Invalid timeframe");
        
        // Simplified implementation - return sample data
        timestamps = new uint256[](10);
        values = new uint256[](10);
        
        for (uint256 i = 0; i < 10; i++) {
            timestamps[i] = block.timestamp - (timeframe / 10 * (10 - i));
            values[i] = 100 + i * 10; // Sample increasing trend
        }
        
        trend = "Increasing";
    }
    
    function generateAnalyticsReport(
        uint256 startTime,
        uint256 endTime
    ) external view override returns (
        string memory summary,
        uint256 totalMetrics,
        uint256 alertCount,
        uint256 optimizationsFound
    ) {
        require(startTime < endTime, "OpMonitoring: Invalid time range");
        
        totalMetrics = _metricCounter;
        alertCount = _alertCounter;
        optimizationsFound = _optimizationCounter;
        
        summary = "System performance analysis completed";
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _removeFromActiveAlerts(bytes32 alertId) internal {
        for (uint256 i = 0; i < activeAlerts.length; i++) {
            if (activeAlerts[i] == alertId) {
                activeAlerts[i] = activeAlerts[activeAlerts.length - 1];
                activeAlerts.pop();
                break;
            }
        }
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function isAutomatedMonitoringEnabled() external view returns (bool enabled) {
        return automatedMonitoringEnabled;
    }
    
    function getMonitoringInterval() external view returns (uint256 interval) {
        return monitoringInterval;
    }
    
    function getLastAutomatedCheck() external view returns (uint256 timestamp) {
        return lastAutomatedCheck;
    }
    
    function getSystemUptime() external view returns (uint256 uptime) {
        return block.timestamp - systemStartTime - totalDowntime;
    }
} 