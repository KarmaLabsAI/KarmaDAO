// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOperationsMonitoringManager
 * @dev Interface for Operations and Monitoring Management
 * Stage 9.2 - Operations and Monitoring Implementation
 */
interface IOperationsMonitoringManager {
    
    // ============ ENUMS ============
    
    enum MonitoringLevel {
        BASIC,              // Basic monitoring
        STANDARD,           // Standard monitoring  
        ADVANCED,           // Advanced monitoring
        ENTERPRISE         // Enterprise monitoring
    }
    
    enum AlertSeverity {
        INFO,               // Informational
        WARNING,            // Warning level
        ERROR,              // Error level
        CRITICAL           // Critical level
    }
    
    enum HealthStatus {
        HEALTHY,            // System healthy
        WARNING,            // Warning status
        DEGRADED,           // Degraded performance
        CRITICAL,           // Critical issues
        OFFLINE            // System offline
    }
    
    enum MetricType {
        GAS_USAGE,          // Gas consumption metrics
        TRANSACTION_COUNT,  // Transaction volume
        ERROR_RATE,         // Error rates
        RESPONSE_TIME,      // Response times
        UPTIME,             // System uptime
        PERFORMANCE,        // Performance metrics
        SECURITY,           // Security metrics
        FINANCIAL          // Financial metrics
    }
    
    enum ReportType {
        DAILY,              // Daily reports
        WEEKLY,             // Weekly reports
        MONTHLY,            // Monthly reports
        QUARTERLY,          // Quarterly reports
        INCIDENT,           // Incident reports
        CUSTOM             // Custom reports
    }
    
    // ============ STRUCTS ============
    
    struct MonitoringConfig {
        bytes32 configId;
        string name;
        MonitoringLevel level;
        address[] contractsToMonitor;
        MetricType[] enabledMetrics;
        uint256 updateInterval;
        uint256 retentionPeriod;
        bool alertsEnabled;
        bool isActive;
        string description;
    }
    
    struct PerformanceMetrics {
        bytes32 metricId;
        MetricType metricType;
        address contractAddress;
        uint256 value;
        uint256 timestamp;
        uint256 blockNumber;
        string unit;
        mapping(uint256 => uint256) historicalValues; // timestamp => value
    }
    
    struct SystemHealthCheck {
        bytes32 checkId;
        string name;
        HealthStatus status;
        uint256 lastCheckTime;
        uint256 checkInterval;
        string[] passedChecks;
        string[] failedChecks;
        string[] warnings;
        bool isAutomated;
        string description;
    }
    
    struct Alert {
        bytes32 alertId;
        AlertSeverity severity;
        MetricType metricType;
        address contractAddress;
        string message;
        uint256 timestamp;
        bool isResolved;
        uint256 resolvedTime;
        string resolution;
        address resolver;
    }
    
    struct GasOptimization {
        bytes32 optimizationId;
        address contractAddress;
        string functionName;
        uint256 originalGasCost;
        uint256 optimizedGasCost;
        uint256 savingsAmount;
        uint256 savingsPercentage;
        string optimizationMethod;
        bool isImplemented;
        uint256 implementationTime;
    }
    
    struct TransparencyReport {
        bytes32 reportId;
        ReportType reportType;
        uint256 startTime;
        uint256 endTime;
        string[] sections;
        mapping(string => string) sectionData;
        uint256 generationTime;
        bool isPublished;
        string ipfsHash;
    }
    
    struct Dashboard {
        bytes32 dashboardId;
        string name;
        address owner;
        MetricType[] displayedMetrics;
        uint256 refreshInterval;
        bool isPublic;
        string[] widgets;
        string layout;
        bool isActive;
    }
    
    // ============ EVENTS ============
    
    event MonitoringConfigCreated(bytes32 indexed configId, string name, MonitoringLevel level);
    event MetricUpdated(bytes32 indexed metricId, MetricType indexed metricType, uint256 value, uint256 timestamp);
    event AlertTriggered(bytes32 indexed alertId, AlertSeverity indexed severity, string message);
    event AlertResolved(bytes32 indexed alertId, address indexed resolver, string resolution);
    event HealthCheckCompleted(bytes32 indexed checkId, HealthStatus status, uint256 timestamp);
    event GasOptimizationIdentified(bytes32 indexed optimizationId, address indexed contractAddress, uint256 potentialSavings);
    event GasOptimizationImplemented(bytes32 indexed optimizationId, uint256 actualSavings);
    event TransparencyReportGenerated(bytes32 indexed reportId, ReportType reportType, string ipfsHash);
    event DashboardCreated(bytes32 indexed dashboardId, string name, address indexed owner);
    event SystemStatusChanged(HealthStatus indexed oldStatus, HealthStatus indexed newStatus);
    
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
    ) external returns (bytes32 configId);
    
    function updateMonitoringConfig(bytes32 configId, MonitoringConfig calldata config) external returns (bool success);
    function activateMonitoring(bytes32 configId) external returns (bool success);
    function deactivateMonitoring(bytes32 configId) external returns (bool success);
    function getMonitoringConfig(bytes32 configId) external view returns (MonitoringConfig memory config);
    function getAllMonitoringConfigs() external view returns (MonitoringConfig[] memory configs);
    
    // ============ PERFORMANCE METRICS ============
    
    function recordMetric(
        MetricType metricType,
        address contractAddress,
        uint256 value,
        string calldata unit
    ) external returns (bytes32 metricId);
    
    function batchRecordMetrics(
        MetricType[] calldata metricTypes,
        address[] calldata contractAddresses,
        uint256[] calldata values,
        string[] calldata units
    ) external returns (bytes32[] memory metricIds);
    
    function getMetric(bytes32 metricId) external view returns (
        MetricType metricType,
        address contractAddress,
        uint256 value,
        uint256 timestamp,
        string memory unit
    );
    
    function getMetricHistory(
        bytes32 metricId,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256[] memory timestamps, uint256[] memory values);
    
    function getMetricsByType(MetricType metricType) external view returns (bytes32[] memory metricIds);
    function getMetricsByContract(address contractAddress) external view returns (bytes32[] memory metricIds);
    
    // ============ SYSTEM HEALTH CHECKS ============
    
    function createHealthCheck(
        string calldata name,
        uint256 checkInterval,
        bool isAutomated,
        string calldata description
    ) external returns (bytes32 checkId);
    
    function executeHealthCheck(bytes32 checkId) external returns (HealthStatus status);
    function executeAllHealthChecks() external returns (HealthStatus overallStatus);
    function updateHealthCheckStatus(
        bytes32 checkId,
        HealthStatus status,
        string[] calldata passedChecks,
        string[] calldata failedChecks,
        string[] calldata warnings
    ) external returns (bool success);
    
    function getHealthCheck(bytes32 checkId) external view returns (SystemHealthCheck memory healthCheck);
    function getAllHealthChecks() external view returns (SystemHealthCheck[] memory healthChecks);
    function getSystemStatus() external view returns (HealthStatus status);
    
    // ============ ALERT MANAGEMENT ============
    
    function createAlert(
        AlertSeverity severity,
        MetricType metricType,
        address contractAddress,
        string calldata message
    ) external returns (bytes32 alertId);
    
    function resolveAlert(
        bytes32 alertId,
        string calldata resolution
    ) external returns (bool success);
    
    function batchResolveAlerts(
        bytes32[] calldata alertIds,
        string[] calldata resolutions
    ) external returns (bool[] memory results);
    
    function getAlert(bytes32 alertId) external view returns (Alert memory alert);
    function getActiveAlerts() external view returns (Alert[] memory alerts);
    function getAlertsBySeverity(AlertSeverity severity) external view returns (Alert[] memory alerts);
    function getAlertsHistory(uint256 startTime, uint256 endTime) external view returns (Alert[] memory alerts);
    
    // ============ GAS OPTIMIZATION ============
    
    function identifyGasOptimization(
        address contractAddress,
        string calldata functionName,
        uint256 originalGasCost,
        uint256 optimizedGasCost,
        string calldata optimizationMethod
    ) external returns (bytes32 optimizationId);
    
    function implementGasOptimization(bytes32 optimizationId) external returns (bool success);
    function getGasOptimization(bytes32 optimizationId) external view returns (GasOptimization memory optimization);
    function getGasOptimizationsByContract(address contractAddress) external view returns (GasOptimization[] memory optimizations);
    function getTotalGasSavings() external view returns (uint256 totalSavings);
    
    // ============ DASHBOARD MANAGEMENT ============
    
    function createDashboard(
        string calldata name,
        MetricType[] calldata displayedMetrics,
        uint256 refreshInterval,
        bool isPublic,
        string[] calldata widgets,
        string calldata layout
    ) external returns (bytes32 dashboardId);
    
    function updateDashboard(bytes32 dashboardId, Dashboard calldata dashboard) external returns (bool success);
    function getDashboard(bytes32 dashboardId) external view returns (Dashboard memory dashboard);
    function getUserDashboards(address user) external view returns (Dashboard[] memory dashboards);
    function getPublicDashboards() external view returns (Dashboard[] memory dashboards);
    
    // ============ TRANSPARENCY REPORTING ============
    
    function generateTransparencyReport(
        ReportType reportType,
        uint256 startTime,
        uint256 endTime,
        string[] calldata sections
    ) external returns (bytes32 reportId);
    
    function publishReport(bytes32 reportId, string calldata ipfsHash) external returns (bool success);
    function getTransparencyReport(bytes32 reportId) external view returns (
        ReportType reportType,
        uint256 startTime,
        uint256 endTime,
        uint256 generationTime,
        bool isPublished,
        string memory ipfsHash
    );
    
    function getReportsByType(ReportType reportType) external view returns (bytes32[] memory reportIds);
    function getPublishedReports() external view returns (bytes32[] memory reportIds);
    
    // ============ AUTOMATION ============
    
    function enableAutomatedMonitoring() external returns (bool success);
    function disableAutomatedMonitoring() external returns (bool success);
    function setMonitoringInterval(uint256 interval) external returns (bool success);
    function runAutomatedChecks() external returns (uint256 checksExecuted);
    
    // ============ ANALYTICS ============
    
    function getSystemStatistics() external view returns (
        uint256 totalTransactions,
        uint256 totalGasUsed,
        uint256 averageGasPrice,
        uint256 uptimePercentage,
        uint256 errorRate
    );
    
    function getPerformanceTrends(
        MetricType metricType,
        uint256 timeframe
    ) external view returns (
        uint256[] memory timestamps,
        uint256[] memory values,
        string memory trend
    );
    
    function generateAnalyticsReport(
        uint256 startTime,
        uint256 endTime
    ) external view returns (
        string memory summary,
        uint256 totalMetrics,
        uint256 alertCount,
        uint256 optimizationsFound
    );
} 