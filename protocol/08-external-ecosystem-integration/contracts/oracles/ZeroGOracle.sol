// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../interfaces/I0GOracle.sol";

/**
 * @title Karma0GOracle
 * @dev 0G usage reporting oracle and cross-chain settlement system
 * Stage 8.1 - Oracle and Settlement Implementation
 */
contract Karma0GOracle is I0GOracle, AccessControl, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant USAGE_REPORTER_ROLE = keccak256("USAGE_REPORTER_ROLE");
    bytes32 public constant PRICE_ORACLE_ROLE = keccak256("PRICE_ORACLE_ROLE");
    bytes32 public constant SETTLEMENT_VALIDATOR_ROLE = keccak256("SETTLEMENT_VALIDATOR_ROLE");
    bytes32 public constant DISPUTE_RESOLVER_ROLE = keccak256("DISPUTE_RESOLVER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MIN_REPORTING_THRESHOLD = 0.001 ether;
    uint256 public constant VALIDATION_PERIOD = 24 hours;
    uint256 public constant DISPUTE_PERIOD = 7 days;
    uint256 public constant SETTLEMENT_THRESHOLD = 1 ether;
    uint256 public constant MAX_SETTLEMENT_DELAY = 30 days;
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    address public karmaToken;
    address public bridge;
    address public treasury;
    address public aiInferencePayment;
    address public metadataStorage;
    
    // Oracle configuration
    OracleConfig private _oracleConfig;
    
    // Usage reports
    mapping(bytes32 => UsageReport) private _usageReports;
    mapping(address => bytes32[]) public reportsByUser;
    mapping(address => bytes32[]) public reportsByReporter;
    mapping(DataStatus => bytes32[]) public reportsByStatus;
    mapping(string => bytes32[]) public reportsByService;
    
    // Settlement requests
    mapping(bytes32 => SettlementRequest) private _settlementRequests;
    mapping(address => bytes32[]) public settlementsByUser;
    mapping(SettlementStatus => bytes32[]) public settlementsByStatus;
    mapping(bytes32 => mapping(address => bool)) public settlementValidations;
    mapping(bytes32 => uint256) public settlementValidationCount;
    
    // Dispute cases
    mapping(bytes32 => DisputeCase) private _disputeCases;
    mapping(address => bytes32[]) public disputesByUser;
    mapping(bytes32 => mapping(address => bool)) public disputeVotes;
    mapping(bytes32 => uint256) public disputeVoteCount;
    
    // Price data
    PriceData private _currentPrices;
    mapping(uint256 => PriceData) public priceHistory; // timestamp => PriceData
    uint256[] public priceTimestamps;
    
    // Oracle management
    address[] public usageReporters;
    address[] public priceOracles;
    address[] public settlementValidators;
    address[] public disputeResolvers;
    
    mapping(address => bool) public isUsageReporter;
    mapping(address => bool) public isPriceOracle;
    mapping(address => bool) public isSettlementValidator;
    mapping(address => bool) public isDisputeResolver;
    
    mapping(address => uint256) public reporterStake;
    mapping(address => uint256) public reporterReputationScore;
    mapping(address => uint256) public reporterSuccessfulReports;
    mapping(address => uint256) public reporterDisputedReports;
    
    // Automatic settlement
    mapping(address => uint256) public userTotalUsage;
    mapping(address => uint256) public userLastSettlement;
    mapping(address => bool) public hasAutomaticSettlement;
    uint256 public totalPendingSettlements;
    
    // Report counters
    uint256 private _reportCounter;
    uint256 private _settlementCounter;
    uint256 private _disputeCounter;
    
    // ============ EVENTS ============
    
    event ReporterAdded(address indexed reporter, uint256 stake);
    event ReporterRemoved(address indexed reporter);
    event ReputationUpdated(address indexed reporter, uint256 newScore);
    event AutomaticSettlementTriggered(address indexed user, uint256 amount);
    event SettlementValidated(bytes32 indexed settlementId, address indexed validator);
    event OracleConfigUpdated(uint256 reportingThreshold, uint256 settlementThreshold);
    
    // ============ MODIFIERS ============
    
    modifier onlyOracleManager() {
        require(hasRole(ORACLE_MANAGER_ROLE, msg.sender), "Oracle: Not oracle manager");
        _;
    }
    
    modifier onlyUsageReporter() {
        require(hasRole(USAGE_REPORTER_ROLE, msg.sender), "Oracle: Not usage reporter");
        _;
    }
    
    modifier onlyPriceOracle() {
        require(hasRole(PRICE_ORACLE_ROLE, msg.sender), "Oracle: Not price oracle");
        _;
    }
    
    modifier onlySettlementValidator() {
        require(hasRole(SETTLEMENT_VALIDATOR_ROLE, msg.sender), "Oracle: Not settlement validator");
        _;
    }
    
    modifier onlyDisputeResolver() {
        require(hasRole(DISPUTE_RESOLVER_ROLE, msg.sender), "Oracle: Not dispute resolver");
        _;
    }
    
    modifier validReportId(bytes32 reportId) {
        require(_usageReports[reportId].reportId != bytes32(0), "Oracle: Invalid report ID");
        _;
    }
    
    modifier validSettlementId(bytes32 settlementId) {
        require(_settlementRequests[settlementId].settlementId != bytes32(0), "Oracle: Invalid settlement ID");
        _;
    }
    
    modifier validDisputeId(bytes32 disputeId) {
        require(_disputeCases[disputeId].disputeId != bytes32(0), "Oracle: Invalid dispute ID");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _bridge,
        address _treasury,
        address _admin
    ) {
        karmaToken = _karmaToken;
        bridge = _bridge;
        treasury = _treasury;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ORACLE_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize oracle configuration
        _oracleConfig = OracleConfig({
            reportingThreshold: MIN_REPORTING_THRESHOLD,
            validationPeriod: VALIDATION_PERIOD,
            disputePeriod: DISPUTE_PERIOD,
            settlementThreshold: SETTLEMENT_THRESHOLD,
            oracleFee: 0.001 ether,
            isActive: true
        });
        
        // Initialize price data
        _currentPrices = PriceData({
            karmaPrice: 0.05 ether, // $0.05 initial price
            computePrice: 0.0001 ether,
            storagePrice: 0.00001 ether,
            transferPrice: 0.000001 ether,
            timestamp: block.timestamp,
            blockNumber: block.number,
            reporter: _admin
        });
    }
    
    // ============ EXTERNAL FUNCTIONS ============
    
    /**
     * @dev Report usage data from 0G blockchain
     */
    function reportUsage(
        address user,
        uint256 computeUnits,
        uint256 storageUsed,
        uint256 dataTransferred,
        string calldata serviceType,
        bytes calldata proof
    ) external onlyUsageReporter whenNotPaused returns (bytes32 reportId) {
        require(_oracleConfig.isActive, "Oracle: Oracle not active");
        require(user != address(0), "Oracle: Invalid user");
        require(computeUnits > 0 || storageUsed > 0 || dataTransferred > 0, "Oracle: No usage reported");
        require(proof.length > 0, "Oracle: Invalid proof");
        
        // Calculate cost based on current prices
        uint256 cost = _calculateUsageCost(computeUnits, storageUsed, dataTransferred);
        require(cost >= _oracleConfig.reportingThreshold, "Oracle: Below reporting threshold");
        
        // Generate report ID
        reportId = keccak256(
            abi.encodePacked(
                user,
                computeUnits,
                storageUsed,
                dataTransferred,
                serviceType,
                msg.sender,
                _reportCounter++,
                block.timestamp
            )
        );
        
        // Create usage report
        UsageReport storage report = _usageReports[reportId];
        report.reportId = reportId;
        report.reporter = msg.sender;
        report.user = user;
        report.computeUnits = computeUnits;
        report.storageUsed = storageUsed;
        report.dataTransferred = dataTransferred;
        report.timestamp = block.timestamp;
        report.blockNumber = block.number;
        report.status = DataStatus.PENDING;
        report.proofHash = keccak256(proof);
        report.cost = cost;
        report.serviceType = serviceType;
        
        // Track report
        reportsByUser[user].push(reportId);
        reportsByReporter[msg.sender].push(reportId);
        reportsByStatus[DataStatus.PENDING].push(reportId);
        reportsByService[serviceType].push(reportId);
        
        // Update user total usage
        userTotalUsage[user] += cost;
        
        // Update reporter metrics
        reporterSuccessfulReports[msg.sender]++;
        
        // Check for automatic settlement trigger
        if (hasAutomaticSettlement[user] && 
            userTotalUsage[user] >= _oracleConfig.settlementThreshold) {
            _triggerAutomaticSettlement(user);
        }
        
        emit UsageReported(reportId, msg.sender, user, computeUnits, cost);
    }
    
    /**
     * @dev Request settlement based on usage reports
     */
    function requestSettlement(
        address recipient,
        bytes32[] calldata reportIds,
        bool isAutomatic
    ) external whenNotPaused returns (bytes32 settlementId) {
        require(recipient != address(0), "Oracle: Invalid recipient");
        require(reportIds.length > 0, "Oracle: No reports provided");
        
        // Validate all reports belong to the requester and are validated
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < reportIds.length; i++) {
            UsageReport memory report = _usageReports[reportIds[i]];
            require(report.reportId != bytes32(0), "Oracle: Invalid report");
            require(report.user == msg.sender || hasRole(ORACLE_MANAGER_ROLE, msg.sender), "Oracle: Not authorized");
            require(report.status == DataStatus.VALIDATED, "Oracle: Report not validated");
            totalAmount += report.cost;
        }
        
        require(totalAmount >= _oracleConfig.settlementThreshold || isAutomatic, "Oracle: Below settlement threshold");
        
        // Generate settlement ID
        settlementId = keccak256(
            abi.encodePacked(
                msg.sender,
                recipient,
                reportIds,
                _settlementCounter++,
                block.timestamp
            )
        );
        
        // Create settlement request
        SettlementRequest storage settlement = _settlementRequests[settlementId];
        settlement.settlementId = settlementId;
        settlement.requester = msg.sender;
        settlement.recipient = recipient;
        settlement.amount = totalAmount;
        settlement.usageReports = reportIds;
        settlement.timestamp = block.timestamp;
        settlement.status = SettlementStatus.PENDING;
        settlement.deadline = block.timestamp + MAX_SETTLEMENT_DELAY;
        settlement.isAutomatic = isAutomatic;
        
        // Track settlement
        settlementsByUser[msg.sender].push(settlementId);
        settlementsByStatus[SettlementStatus.PENDING].push(settlementId);
        totalPendingSettlements += totalAmount;
        
        emit SettlementRequested(settlementId, msg.sender, recipient, totalAmount);
    }
    
    /**
     * @dev Process automatic settlement
     */
    function processAutomaticSettlement(
        bytes32 settlementId
    ) external onlySettlementValidator validSettlementId(settlementId) {
        SettlementRequest storage settlement = _settlementRequests[settlementId];
        require(settlement.status == SettlementStatus.PENDING, "Oracle: Not pending");
        require(settlement.isAutomatic, "Oracle: Not automatic settlement");
        require(block.timestamp <= settlement.deadline, "Oracle: Settlement expired");
        
        // Update status
        settlement.status = SettlementStatus.PROCESSING;
        _updateSettlementStatus(settlementId, SettlementStatus.PENDING, SettlementStatus.PROCESSING);
        
        // Execute settlement (simplified - would integrate with actual payment system)
        _executeSettlement(settlementId);
    }
    
    /**
     * @dev Validate usage report
     */
    function validateReport(
        bytes32 reportId,
        bool isValid,
        bytes calldata validationProof
    ) external onlySettlementValidator validReportId(reportId) {
        UsageReport storage report = _usageReports[reportId];
        require(report.status == DataStatus.PENDING, "Oracle: Not pending validation");
        require(validationProof.length > 0, "Oracle: Invalid validation proof");
        
        if (isValid) {
            report.status = DataStatus.VALIDATED;
            _updateReportStatus(reportId, DataStatus.PENDING, DataStatus.VALIDATED);
            
            // Update reporter reputation
            reporterReputationScore[report.reporter] += 10;
        } else {
            report.status = DataStatus.REJECTED;
            _updateReportStatus(reportId, DataStatus.PENDING, DataStatus.REJECTED);
            
            // Penalize reporter
            if (reporterReputationScore[report.reporter] >= 5) {
                reporterReputationScore[report.reporter] -= 5;
            }
            reporterDisputedReports[report.reporter]++;
        }
        
        emit ReputationUpdated(report.reporter, reporterReputationScore[report.reporter]);
    }
    
    /**
     * @dev Raise dispute for usage report
     */
    function raiseDispute(
        bytes32 reportId,
        string calldata reason,
        bytes calldata evidence
    ) external validReportId(reportId) returns (bytes32 disputeId) {
        UsageReport memory report = _usageReports[reportId];
        require(
            report.user == msg.sender || 
            report.reporter == msg.sender || 
            hasRole(DISPUTE_RESOLVER_ROLE, msg.sender),
            "Oracle: Not authorized to dispute"
        );
        require(
            report.status == DataStatus.VALIDATED || report.status == DataStatus.PENDING,
            "Oracle: Cannot dispute this report"
        );
        require(
            block.timestamp <= report.timestamp + _oracleConfig.disputePeriod,
            "Oracle: Dispute period expired"
        );
        require(bytes(reason).length > 0, "Oracle: Invalid reason");
        require(evidence.length > 0, "Oracle: No evidence provided");
        
        // Generate dispute ID
        disputeId = keccak256(
            abi.encodePacked(
                reportId,
                msg.sender,
                reason,
                _disputeCounter++,
                block.timestamp
            )
        );
        
        // Create dispute case
        DisputeCase storage dispute = _disputeCases[disputeId];
        dispute.disputeId = disputeId;
        dispute.originalReportId = reportId;
        dispute.disputer = msg.sender;
        dispute.defendant = report.reporter;
        dispute.reason = reason;
        dispute.evidence = evidence;
        dispute.timestamp = block.timestamp;
        dispute.resolutionDeadline = block.timestamp + DISPUTE_PERIOD;
        dispute.resolution = DataStatus.DISPUTED;
        
        // Update report status
        _usageReports[reportId].status = DataStatus.DISPUTED;
        _updateReportStatus(reportId, report.status, DataStatus.DISPUTED);
        
        // Track dispute
        disputesByUser[msg.sender].push(disputeId);
        
        emit DisputeRaised(disputeId, reportId, msg.sender, reason);
    }
    
    /**
     * @dev Resolve dispute
     */
    function resolveDispute(
        bytes32 disputeId,
        DataStatus resolution,
        bytes calldata resolutionData
    ) external onlyDisputeResolver validDisputeId(disputeId) {
        DisputeCase storage dispute = _disputeCases[disputeId];
        require(dispute.resolution == DataStatus.DISPUTED, "Oracle: Dispute already resolved");
        require(block.timestamp <= dispute.resolutionDeadline, "Oracle: Resolution deadline passed");
        require(
            resolution == DataStatus.VALIDATED || resolution == DataStatus.REJECTED,
            "Oracle: Invalid resolution"
        );
        
        // Update dispute
        dispute.resolution = resolution;
        dispute.resolver = msg.sender;
        
        // Update original report
        UsageReport storage report = _usageReports[dispute.originalReportId];
        DataStatus oldStatus = report.status;
        report.status = resolution;
        _updateReportStatus(dispute.originalReportId, oldStatus, resolution);
        
        // Apply penalties/rewards based on resolution
        if (resolution == DataStatus.REJECTED) {
            // Penalize the reporter
            dispute.penalty = reporterStake[dispute.defendant] * 10 / 100; // 10% penalty
            if (reporterReputationScore[dispute.defendant] >= 20) {
                reporterReputationScore[dispute.defendant] -= 20;
            }
        } else {
            // Reward the reporter and penalize false disputer
            reporterReputationScore[dispute.defendant] += 5;
        }
        
        emit DisputeResolved(disputeId, resolution, msg.sender);
    }
    
    /**
     * @dev Update price data
     */
    function updatePrices(
        uint256 karmaPrice,
        uint256 computePrice,
        uint256 storagePrice,
        uint256 transferPrice,
        bytes calldata priceProof
    ) external onlyPriceOracle {
        require(priceProof.length > 0, "Oracle: Invalid price proof");
        require(karmaPrice > 0 && computePrice > 0 && storagePrice > 0 && transferPrice > 0, "Oracle: Invalid prices");
        
        // Store current prices in history
        priceHistory[block.timestamp] = _currentPrices;
        priceTimestamps.push(block.timestamp);
        
        // Update current prices
        _currentPrices = PriceData({
            karmaPrice: karmaPrice,
            computePrice: computePrice,
            storagePrice: storagePrice,
            transferPrice: transferPrice,
            timestamp: block.timestamp,
            blockNumber: block.number,
            reporter: msg.sender
        });
        
        emit PriceUpdated(karmaPrice, computePrice, storagePrice, msg.sender);
    }
    
    /**
     * @dev Get usage report
     */
    function getUsageReport(bytes32 reportId) external view returns (UsageReport memory) {
        return _usageReports[reportId];
    }
    
    /**
     * @dev Get settlement request
     */
    function getSettlementRequest(bytes32 settlementId) external view returns (SettlementRequest memory) {
        return _settlementRequests[settlementId];
    }
    
    /**
     * @dev Get current prices
     */
    function getCurrentPrices() external view returns (PriceData memory) {
        return _currentPrices;
    }
    
    /**
     * @dev Calculate settlement amount
     */
    function calculateSettlementAmount(
        bytes32[] calldata reportIds
    ) external view returns (uint256 totalAmount) {
        for (uint256 i = 0; i < reportIds.length; i++) {
            UsageReport memory report = _usageReports[reportIds[i]];
            require(report.reportId != bytes32(0), "Oracle: Invalid report");
            totalAmount += report.cost;
        }
    }
    
    /**
     * @dev Get oracle configuration
     */
    function getOracleConfig() external view returns (OracleConfig memory) {
        return _oracleConfig;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Add usage reporter
     */
    function addUsageReporter(address reporter, uint256 stake) external onlyOracleManager {
        require(!isUsageReporter[reporter], "Oracle: Already a reporter");
        require(stake > 0, "Oracle: Invalid stake");
        
        usageReporters.push(reporter);
        isUsageReporter[reporter] = true;
        reporterStake[reporter] = stake;
        reporterReputationScore[reporter] = 100; // Starting reputation
        
        _grantRole(USAGE_REPORTER_ROLE, reporter);
        
        emit ReporterAdded(reporter, stake);
    }
    
    /**
     * @dev Remove usage reporter
     */
    function removeUsageReporter(address reporter) external onlyOracleManager {
        require(isUsageReporter[reporter], "Oracle: Not a reporter");
        
        isUsageReporter[reporter] = false;
        reporterStake[reporter] = 0;
        reporterReputationScore[reporter] = 0;
        
        _revokeRole(USAGE_REPORTER_ROLE, reporter);
        
        // Remove from array
        for (uint256 i = 0; i < usageReporters.length; i++) {
            if (usageReporters[i] == reporter) {
                usageReporters[i] = usageReporters[usageReporters.length - 1];
                usageReporters.pop();
                break;
            }
        }
        
        emit ReporterRemoved(reporter);
    }
    
    /**
     * @dev Update oracle configuration
     */
    function updateOracleConfig(
        uint256 reportingThreshold,
        uint256 validationPeriod,
        uint256 disputePeriod,
        uint256 settlementThreshold,
        uint256 oracleFee,
        bool isActive
    ) external onlyOracleManager {
        _oracleConfig.reportingThreshold = reportingThreshold;
        _oracleConfig.validationPeriod = validationPeriod;
        _oracleConfig.disputePeriod = disputePeriod;
        _oracleConfig.settlementThreshold = settlementThreshold;
        _oracleConfig.oracleFee = oracleFee;
        _oracleConfig.isActive = isActive;
        
        emit OracleConfigUpdated(reportingThreshold, settlementThreshold);
    }
    
    /**
     * @dev Set automatic settlement for user
     */
    function setAutomaticSettlement(address user, bool enabled) external onlyOracleManager {
        hasAutomaticSettlement[user] = enabled;
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Calculate usage cost based on current prices
     */
    function _calculateUsageCost(
        uint256 computeUnits,
        uint256 storageUsed,
        uint256 dataTransferred
    ) internal view returns (uint256 cost) {
        cost = computeUnits * _currentPrices.computePrice;
        cost += storageUsed * _currentPrices.storagePrice;
        cost += dataTransferred * _currentPrices.transferPrice;
    }
    
    /**
     * @dev Trigger automatic settlement for user
     */
    function _triggerAutomaticSettlement(address user) internal {
        // Create report IDs array for user's validated reports
        bytes32[] memory userReports = reportsByUser[user];
        bytes32[] memory validatedReports = new bytes32[](userReports.length);
        uint256 validatedCount = 0;
        
        for (uint256 i = 0; i < userReports.length; i++) {
            if (_usageReports[userReports[i]].status == DataStatus.VALIDATED) {
                validatedReports[validatedCount] = userReports[i];
                validatedCount++;
            }
        }
        
        if (validatedCount > 0) {
            // Resize array to actual count
            bytes32[] memory finalReports = new bytes32[](validatedCount);
            for (uint256 i = 0; i < validatedCount; i++) {
                finalReports[i] = validatedReports[i];
            }
            
            // Create automatic settlement - this would need to be called externally
            // For now, emit event to trigger external settlement
            emit AutomaticSettlementTriggered(user, userTotalUsage[user]);
            
            // Reset user total usage
            userTotalUsage[user] = 0;
            userLastSettlement[user] = block.timestamp;
        }
    }
    
    /**
     * @dev Execute settlement (simplified implementation)
     */
    function _executeSettlement(bytes32 settlementId) internal {
        SettlementRequest storage settlement = _settlementRequests[settlementId];
        
        // Update status
        settlement.status = SettlementStatus.COMPLETED;
        _updateSettlementStatus(settlementId, SettlementStatus.PROCESSING, SettlementStatus.COMPLETED);
        
        // Update totals
        totalPendingSettlements -= settlement.amount;
        
        // In production, would execute actual payment
        emit SettlementCompleted(settlementId, settlement.recipient, settlement.amount);
    }
    
    /**
     * @dev Update report status tracking
     */
    function _updateReportStatus(
        bytes32 reportId,
        DataStatus oldStatus,
        DataStatus newStatus
    ) internal {
        // Remove from old status array
        bytes32[] storage oldArray = reportsByStatus[oldStatus];
        for (uint256 i = 0; i < oldArray.length; i++) {
            if (oldArray[i] == reportId) {
                oldArray[i] = oldArray[oldArray.length - 1];
                oldArray.pop();
                break;
            }
        }
        
        // Add to new status array
        reportsByStatus[newStatus].push(reportId);
    }
    
    /**
     * @dev Update settlement status tracking
     */
    function _updateSettlementStatus(
        bytes32 settlementId,
        SettlementStatus oldStatus,
        SettlementStatus newStatus
    ) internal {
        // Remove from old status array
        bytes32[] storage oldArray = settlementsByStatus[oldStatus];
        for (uint256 i = 0; i < oldArray.length; i++) {
            if (oldArray[i] == settlementId) {
                oldArray[i] = oldArray[oldArray.length - 1];
                oldArray.pop();
                break;
            }
        }
        
        // Add to new status array
        settlementsByStatus[newStatus].push(settlementId);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get usage reports by user
     */
    function getUserReports(address user) external view returns (bytes32[] memory) {
        return reportsByUser[user];
    }
    
    /**
     * @dev Get settlements by user
     */
    function getUserSettlements(address user) external view returns (bytes32[] memory) {
        return settlementsByUser[user];
    }
    
    /**
     * @dev Get reporter statistics
     */
    function getReporterStats(address reporter) external view returns (
        uint256 stake,
        uint256 reputation,
        uint256 successfulReports,
        uint256 disputedReports
    ) {
        return (
            reporterStake[reporter],
            reporterReputationScore[reporter],
            reporterSuccessfulReports[reporter],
            reporterDisputedReports[reporter]
        );
    }
    
    /**
     * @dev Get price history
     */
    function getPriceHistory(uint256 fromTimestamp, uint256 toTimestamp) 
        external view returns (PriceData[] memory prices) {
        
        uint256 count = 0;
        for (uint256 i = 0; i < priceTimestamps.length; i++) {
            if (priceTimestamps[i] >= fromTimestamp && priceTimestamps[i] <= toTimestamp) {
                count++;
            }
        }
        
        prices = new PriceData[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < priceTimestamps.length; i++) {
            if (priceTimestamps[i] >= fromTimestamp && priceTimestamps[i] <= toTimestamp) {
                prices[index] = priceHistory[priceTimestamps[i]];
                index++;
            }
        }
    }
} 