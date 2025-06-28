// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title KarmaBugBountyManager
 * @dev Stage 9.1 Bug Bounty Program Development Implementation
 * 
 * Implements:
 * - Bug bounty program infrastructure on Immunefi
 * - Vulnerability classification and reward structures
 * - Responsible disclosure processes and patch management
 * - Community security researcher engagement programs
 */
contract KarmaBugBountyManager is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant BOUNTY_MANAGER_ROLE = keccak256("BOUNTY_MANAGER_ROLE");
    bytes32 public constant VULNERABILITY_REVIEWER_ROLE = keccak256("VULNERABILITY_REVIEWER_ROLE");
    bytes32 public constant PATCH_MANAGER_ROLE = keccak256("PATCH_MANAGER_ROLE");
    bytes32 public constant DISCLOSURE_MANAGER_ROLE = keccak256("DISCLOSURE_MANAGER_ROLE");
    bytes32 public constant COMMUNITY_MANAGER_ROLE = keccak256("COMMUNITY_MANAGER_ROLE");
    bytes32 public constant IMMUNEFI_INTEGRATOR_ROLE = keccak256("IMMUNEFI_INTEGRATOR_ROLE");
    
    uint256 public constant MAX_BOUNTY_REWARD = 200000 * 1e6; // $200K max (USDC 6 decimals)
    uint256 public constant MIN_BOUNTY_REWARD = 100 * 1e6; // $100 min
    uint256 public constant RESPONSE_TIME_TARGET = 24 hours; // 24 hour response target
    uint256 public constant PATCH_TIME_TARGET = 7 days; // 7 day patch target
    uint256 public constant DISCLOSURE_PERIOD = 90 days; // 90 day responsible disclosure
    uint256 public constant REPUTATION_DECAY_PERIOD = 365 days; // 1 year reputation decay
    
    // ============ ENUMS ============
    
    enum VulnerabilityCategory {
        ACCESS_CONTROL,
        REENTRANCY,
        ARITHMETIC_OVERFLOW,
        FRONT_RUNNING,
        DENIAL_OF_SERVICE,
        FLASH_LOAN_ATTACK,
        GOVERNANCE_MANIPULATION,
        ORACLE_MANIPULATION,
        MEV_EXPLOITATION,
        ECONOMIC_ATTACK,
        LOGIC_ERROR,
        IMPLEMENTATION_BUG
    }
    
    enum SeverityLevel {
        INFORMATIONAL, // 0-10% of max bounty
        LOW,          // 10-25% of max bounty
        MEDIUM,       // 25-50% of max bounty
        HIGH,         // 50-75% of max bounty
        CRITICAL      // 75-100% of max bounty
    }
    
    enum ReportStatus {
        SUBMITTED,
        UNDER_REVIEW,
        TRIAGING,
        CONFIRMED,
        PATCHING,
        PATCHED,
        DISCLOSED,
        REJECTED,
        INVALID,
        DUPLICATE
    }
    
    enum DisclosureStatus {
        PRIVATE,
        COORDINATED,
        PUBLIC,
        FULL_DISCLOSURE,
        EMBARGO
    }
    
    enum ResearcherTier {
        NEWCOMER,     // 0-100 reputation
        CONTRIBUTOR,  // 100-500 reputation
        VETERAN,      // 500-1500 reputation
        EXPERT,       // 1500-5000 reputation
        LEGEND        // 5000+ reputation
    }
    
    // ============ STRUCTS ============
    
    struct VulnerabilityReport {
        uint256 reportId;
        address reporter;
        VulnerabilityCategory category;
        SeverityLevel severity;
        string title;
        string description;
        bytes32 proofOfConceptHash;
        address[] affectedContracts;
        uint256 submittedAt;
        uint256 responseDeadline;
        uint256 patchDeadline;
        uint256 disclosureDeadline;
        ReportStatus status;
        DisclosureStatus disclosureStatus;
        uint256 bountyAmount;
        bool isPaid;
        uint256 paidAt;
        address reviewer;
        uint256 reviewedAt;
        string reviewNotes;
        bytes32 patchHash;
        uint256 patchedAt;
        address patcher;
        string publicDisclosure;
        uint256 disclosedAt;
    }
    
    struct BugBountyProgram {
        uint256 programId;
        string programName;
        bool isActive;
        uint256 totalFunding;
        uint256 availableFunding;
        uint256 maxReward;
        uint256 minReward;
        address[] targetContracts;
        mapping(VulnerabilityCategory => uint256) categoryRewards;
        mapping(SeverityLevel => uint256) severityMultipliers;
        uint256 startTime;
        uint256 endTime;
        uint256 responseTimeTarget;
        uint256 totalReports;
        uint256 validReports;
        uint256 totalPaid;
        bool immunefiIntegrated;
        string immunefiProgramId;
    }
    
    struct SecurityResearcher {
        address researcherAddress;
        string handle;
        string email;
        ResearcherTier tier;
        uint256 reputation;
        uint256 totalEarnings;
        uint256 validReports;
        uint256 invalidReports;
        uint256 lastActivityAt;
        bool isVerified;
        bool isBlacklisted;
        string[] specializations; // VulnerabilityCategory names
        uint256 joinedAt;
        mapping(VulnerabilityCategory => uint256) categoryExpertise;
        uint256[] reportHistory;
        uint256 longestStreak;
        uint256 currentStreak;
    }
    
    struct DisclosureTimeline {
        uint256 reportId;
        uint256 reportSubmitted;
        uint256 initialResponse;
        uint256 triageCompleted;
        uint256 vulnerabilityConfirmed;
        uint256 patchDeveloped;
        uint256 patchDeployed;
        uint256 publicDisclosure;
        uint256 coordinatedDisclosure;
        uint256 fullDisclosure;
        bool isCompleted;
        string[] milestones;
        address[] stakeholders;
    }
    
    struct ImmunefiIntegration {
        bool isActive;
        string apiEndpoint;
        bytes32 apiKeyHash;
        uint256 lastSyncAt;
        uint256 totalSynced;
        mapping(string => uint256) immunefiReportMapping; // Immunefi ID to internal ID
        string[] activeProgramIds;
        uint256 integrationFee;
        bool autoSync;
    }
    
    struct CommunityMetrics {
        uint256 totalResearchers;
        uint256 activeResearchers; // Active in last 30 days
        uint256 totalReports;
        uint256 validReports;
        uint256 totalBountiesPaid;
        uint256 averageResponseTime;
        uint256 averagePatchTime;
        uint256 averageBountyAmount;
        mapping(VulnerabilityCategory => uint256) categoryDistribution;
        mapping(SeverityLevel => uint256) severityDistribution;
        mapping(ResearcherTier => uint256) tierDistribution;
    }
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    IERC20 public usdcToken;
    IERC20 public karmaToken;
    
    // Bug bounty programs
    mapping(uint256 => BugBountyProgram) private _bugBountyPrograms;
    mapping(string => uint256) public programNameToId;
    uint256 public totalBugBountyPrograms;
    uint256[] public activeProgramIds;
    
    // Vulnerability reports
    mapping(uint256 => VulnerabilityReport) private _vulnerabilityReports;
    mapping(address => uint256[]) public reportsByReporter;
    mapping(VulnerabilityCategory => uint256[]) public reportsByCategory;
    mapping(SeverityLevel => uint256[]) public reportsBySeverity;
    mapping(ReportStatus => uint256[]) public reportsByStatus;
    mapping(address => uint256[]) public reportsByContract;
    uint256 public totalVulnerabilityReports;
    
    // Security researchers
    mapping(address => SecurityResearcher) private _securityResearchers;
    mapping(string => address) public handleToAddress;
    address[] public registeredResearchers;
    mapping(ResearcherTier => address[]) public researchersByTier;
    
    // Disclosure management
    mapping(uint256 => DisclosureTimeline) private _disclosureTimelines;
    mapping(uint256 => bool) public isDisclosureComplete;
    
    // Immunefi integration
    ImmunefiIntegration private _immunefiIntegration;
    
    // Community metrics
    CommunityMetrics private _communityMetrics;
    
    // Patch management
    mapping(uint256 => bytes32) public reportPatchHashes;
    mapping(bytes32 => bool) public isValidPatch;
    mapping(address => bool) public authorizedPatchers;
    
    // Responsible disclosure
    mapping(uint256 => uint256) public disclosureEmbargoUntil;
    mapping(uint256 => string) public disclosureCoordinators;
    
    // ============ EVENTS ============
    
    event BugBountyProgramCreated(
        uint256 indexed programId,
        string programName,
        uint256 totalFunding,
        uint256 maxReward,
        bool immunefiIntegrated
    );
    
    event VulnerabilityReportSubmitted(
        uint256 indexed reportId,
        address indexed reporter,
        VulnerabilityCategory indexed category,
        SeverityLevel severity,
        uint256 responseDeadline
    );
    
    event VulnerabilityReportReviewed(
        uint256 indexed reportId,
        ReportStatus indexed status,
        uint256 bountyAmount,
        address indexed reviewer,
        uint256 timestamp
    );
    
    event SecurityResearcherRegistered(
        address indexed researcher,
        string handle,
        ResearcherTier tier,
        uint256 timestamp
    );
    
    event ResearcherTierUpdated(
        address indexed researcher,
        ResearcherTier oldTier,
        ResearcherTier newTier,
        uint256 newReputation
    );
    
    event BountyPaid(
        uint256 indexed reportId,
        address indexed researcher,
        uint256 amount,
        SeverityLevel severity,
        uint256 timestamp
    );
    
    event VulnerabilityPatched(
        uint256 indexed reportId,
        bytes32 patchHash,
        address indexed patcher,
        uint256 timestamp
    );
    
    event VulnerabilityDisclosed(
        uint256 indexed reportId,
        DisclosureStatus disclosureType,
        string publicDisclosure,
        uint256 timestamp
    );
    
    event ImmunefiIntegrationEnabled(
        string apiEndpoint,
        uint256 integrationFee,
        bool autoSync,
        uint256 timestamp
    );
    
    event ImmunefiReportSynced(
        string immunefiId,
        uint256 internalReportId,
        uint256 timestamp
    );
    
    event CommunityMetricsUpdated(
        uint256 totalResearchers,
        uint256 totalReports,
        uint256 totalBountiesPaid,
        uint256 timestamp
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyBountyManager() {
        require(hasRole(BOUNTY_MANAGER_ROLE, msg.sender), "KarmaBugBountyManager: caller is not bounty manager");
        _;
    }
    
    modifier onlyVulnerabilityReviewer() {
        require(hasRole(VULNERABILITY_REVIEWER_ROLE, msg.sender), "KarmaBugBountyManager: caller is not vulnerability reviewer");
        _;
    }
    
    modifier onlyPatchManager() {
        require(hasRole(PATCH_MANAGER_ROLE, msg.sender), "KarmaBugBountyManager: caller is not patch manager");
        _;
    }
    
    modifier onlyDisclosureManager() {
        require(hasRole(DISCLOSURE_MANAGER_ROLE, msg.sender), "KarmaBugBountyManager: caller is not disclosure manager");
        _;
    }
    
    modifier onlyCommunityManager() {
        require(hasRole(COMMUNITY_MANAGER_ROLE, msg.sender), "KarmaBugBountyManager: caller is not community manager");
        _;
    }
    
    modifier onlyImmunefiIntegrator() {
        require(hasRole(IMMUNEFI_INTEGRATOR_ROLE, msg.sender), "KarmaBugBountyManager: caller is not immunefi integrator");
        _;
    }
    
    modifier validReportId(uint256 reportId) {
        require(reportId > 0 && reportId <= totalVulnerabilityReports, "KarmaBugBountyManager: invalid report ID");
        _;
    }
    
    modifier validProgramId(uint256 programId) {
        require(programId > 0 && programId <= totalBugBountyPrograms, "KarmaBugBountyManager: invalid program ID");
        _;
    }
    
    modifier registeredResearcher() {
        require(_securityResearchers[msg.sender].researcherAddress != address(0), "KarmaBugBountyManager: researcher not registered");
        require(!_securityResearchers[msg.sender].isBlacklisted, "KarmaBugBountyManager: researcher is blacklisted");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _usdcToken,
        address _karmaToken,
        address _admin
    ) {
        require(_usdcToken != address(0), "KarmaBugBountyManager: invalid USDC token");
        require(_karmaToken != address(0), "KarmaBugBountyManager: invalid KARMA token");
        require(_admin != address(0), "KarmaBugBountyManager: invalid admin");
        
        usdcToken = IERC20(_usdcToken);
        karmaToken = IERC20(_karmaToken);
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(BOUNTY_MANAGER_ROLE, _admin);
        _grantRole(VULNERABILITY_REVIEWER_ROLE, _admin);
        _grantRole(PATCH_MANAGER_ROLE, _admin);
        _grantRole(DISCLOSURE_MANAGER_ROLE, _admin);
        _grantRole(COMMUNITY_MANAGER_ROLE, _admin);
        _grantRole(IMMUNEFI_INTEGRATOR_ROLE, _admin);
        
        // Initialize community metrics
        _communityMetrics.averageResponseTime = RESPONSE_TIME_TARGET;
        _communityMetrics.averagePatchTime = PATCH_TIME_TARGET;
    }
    
    // ============ BUG BOUNTY PROGRAM MANAGEMENT ============
    
    /**
     * @dev Create bug bounty program
     */
    function createBugBountyProgram(
        string calldata programName,
        uint256 totalFunding,
        uint256 maxReward,
        address[] calldata targetContracts,
        uint256[] calldata categoryRewards, // 12 categories
        uint256[] calldata severityMultipliers, // 5 severity levels
        uint256 duration,
        bool immunefiIntegrated,
        string calldata immunefiProgramId
    ) external onlyBountyManager whenNotPaused nonReentrant returns (uint256 programId) {
        require(bytes(programName).length > 0, "KarmaBugBountyManager: invalid program name");
        require(totalFunding > 0, "KarmaBugBountyManager: invalid total funding");
        require(maxReward >= MIN_BOUNTY_REWARD && maxReward <= MAX_BOUNTY_REWARD, "KarmaBugBountyManager: invalid max reward");
        require(targetContracts.length > 0, "KarmaBugBountyManager: no target contracts");
        require(categoryRewards.length == 12, "KarmaBugBountyManager: invalid category rewards length");
        require(severityMultipliers.length == 5, "KarmaBugBountyManager: invalid severity multipliers length");
        require(duration > 0, "KarmaBugBountyManager: invalid duration");
        
        totalBugBountyPrograms++;
        programId = totalBugBountyPrograms;
        
        BugBountyProgram storage program = _bugBountyPrograms[programId];
        program.programId = programId;
        program.programName = programName;
        program.isActive = true;
        program.totalFunding = totalFunding;
        program.availableFunding = totalFunding;
        program.maxReward = maxReward;
        program.minReward = MIN_BOUNTY_REWARD;
        program.targetContracts = targetContracts;
        program.startTime = block.timestamp;
        program.endTime = block.timestamp + duration;
        program.responseTimeTarget = RESPONSE_TIME_TARGET;
        program.immunefiIntegrated = immunefiIntegrated;
        program.immunefiProgramId = immunefiProgramId;
        
        // Set category rewards
        for (uint256 i = 0; i < categoryRewards.length; i++) {
            program.categoryRewards[VulnerabilityCategory(i)] = categoryRewards[i];
        }
        
        // Set severity multipliers
        for (uint256 i = 0; i < severityMultipliers.length; i++) {
            program.severityMultipliers[SeverityLevel(i)] = severityMultipliers[i];
        }
        
        // Update mappings
        programNameToId[programName] = programId;
        activeProgramIds.push(programId);
        
        // Transfer funding
        usdcToken.safeTransferFrom(msg.sender, address(this), totalFunding);
        
        // Immunefi integration
        if (immunefiIntegrated) {
            _immunefiIntegration.activeProgramIds.push(immunefiProgramId);
        }
        
        emit BugBountyProgramCreated(programId, programName, totalFunding, maxReward, immunefiIntegrated);
    }
    
    // ============ VULNERABILITY REPORTING ============
    
    /**
     * @dev Submit vulnerability report
     */
    function submitVulnerabilityReport(
        VulnerabilityCategory category,
        SeverityLevel severity,
        string calldata title,
        string calldata description,
        bytes32 proofOfConceptHash,
        address[] calldata affectedContracts
    ) external registeredResearcher whenNotPaused nonReentrant returns (uint256 reportId) {
        require(bytes(title).length > 0, "KarmaBugBountyManager: invalid title");
        require(bytes(description).length > 0, "KarmaBugBountyManager: invalid description");
        require(proofOfConceptHash != bytes32(0), "KarmaBugBountyManager: invalid proof hash");
        require(affectedContracts.length > 0, "KarmaBugBountyManager: no affected contracts");
        
        totalVulnerabilityReports++;
        reportId = totalVulnerabilityReports;
        
        uint256 responseDeadline = block.timestamp + RESPONSE_TIME_TARGET;
        uint256 patchDeadline = block.timestamp + PATCH_TIME_TARGET;
        uint256 disclosureDeadline = block.timestamp + DISCLOSURE_PERIOD;
        
        VulnerabilityReport storage report = _vulnerabilityReports[reportId];
        report.reportId = reportId;
        report.reporter = msg.sender;
        report.category = category;
        report.severity = severity;
        report.title = title;
        report.description = description;
        report.proofOfConceptHash = proofOfConceptHash;
        report.affectedContracts = affectedContracts;
        report.submittedAt = block.timestamp;
        report.responseDeadline = responseDeadline;
        report.patchDeadline = patchDeadline;
        report.disclosureDeadline = disclosureDeadline;
        report.status = ReportStatus.SUBMITTED;
        report.disclosureStatus = DisclosureStatus.PRIVATE;
        
        // Update mappings
        reportsByReporter[msg.sender].push(reportId);
        reportsByCategory[category].push(reportId);
        reportsBySeverity[severity].push(reportId);
        reportsByStatus[ReportStatus.SUBMITTED].push(reportId);
        
        for (uint256 i = 0; i < affectedContracts.length; i++) {
            reportsByContract[affectedContracts[i]].push(reportId);
        }
        
        // Update researcher metrics
        SecurityResearcher storage researcher = _securityResearchers[msg.sender];
        researcher.reportHistory.push(reportId);
        researcher.lastActivityAt = block.timestamp;
        researcher.categoryExpertise[category]++;
        
        // Initialize disclosure timeline
        DisclosureTimeline storage timeline = _disclosureTimelines[reportId];
        timeline.reportId = reportId;
        timeline.reportSubmitted = block.timestamp;
        timeline.milestones.push("Report Submitted");
        timeline.stakeholders.push(msg.sender);
        
        // Update community metrics
        _communityMetrics.totalReports++;
        _communityMetrics.categoryDistribution[category]++;
        _communityMetrics.severityDistribution[severity]++;
        
        emit VulnerabilityReportSubmitted(reportId, msg.sender, category, severity, responseDeadline);
    }
    
    /**
     * @dev Review vulnerability report
     */
    function reviewVulnerabilityReport(
        uint256 reportId,
        ReportStatus newStatus,
        uint256 bountyAmount,
        string calldata reviewNotes
    ) external onlyVulnerabilityReviewer validReportId(reportId) whenNotPaused nonReentrant {
        VulnerabilityReport storage report = _vulnerabilityReports[reportId];
        require(report.status == ReportStatus.SUBMITTED || report.status == ReportStatus.UNDER_REVIEW, 
                "KarmaBugBountyManager: report not reviewable");
        
        if (newStatus == ReportStatus.CONFIRMED) {
            require(bountyAmount >= MIN_BOUNTY_REWARD && bountyAmount <= MAX_BOUNTY_REWARD, 
                    "KarmaBugBountyManager: invalid bounty amount");
            
            // Find suitable program with funding
            uint256 programId = _findSuitableBountyProgram(bountyAmount, report.affectedContracts);
            require(programId > 0, "KarmaBugBountyManager: no suitable program found");
            
            BugBountyProgram storage program = _bugBountyPrograms[programId];
            require(program.availableFunding >= bountyAmount, "KarmaBugBountyManager: insufficient program funding");
            
            // Update report
            report.status = newStatus;
            report.bountyAmount = bountyAmount;
            report.reviewer = msg.sender;
            report.reviewedAt = block.timestamp;
            report.reviewNotes = reviewNotes;
            
            // Update program funding
            program.availableFunding -= bountyAmount;
            program.validReports++;
            program.totalPaid += bountyAmount;
            
            // Update researcher metrics
            SecurityResearcher storage researcher = _securityResearchers[report.reporter];
            researcher.validReports++;
            researcher.totalEarnings += bountyAmount;
            researcher.currentStreak++;
            if (researcher.currentStreak > researcher.longestStreak) {
                researcher.longestStreak = researcher.currentStreak;
            }
            
            // Update community metrics
            _communityMetrics.validReports++;
            _communityMetrics.totalBountiesPaid += bountyAmount;
            _communityMetrics.averageBountyAmount = _communityMetrics.totalBountiesPaid / _communityMetrics.validReports;
            
            // Pay bounty
            usdcToken.safeTransfer(report.reporter, bountyAmount);
            report.isPaid = true;
            report.paidAt = block.timestamp;
            
            // Update researcher tier
            _updateResearcherTier(report.reporter);
            
            // Update disclosure timeline
            DisclosureTimeline storage timeline = _disclosureTimelines[reportId];
            timeline.vulnerabilityConfirmed = block.timestamp;
            timeline.milestones.push("Vulnerability Confirmed");
            timeline.stakeholders.push(msg.sender);
            
            emit BountyPaid(reportId, report.reporter, bountyAmount, report.severity, block.timestamp);
            
        } else if (newStatus == ReportStatus.REJECTED || newStatus == ReportStatus.INVALID || newStatus == ReportStatus.DUPLICATE) {
            // Update researcher metrics for invalid reports
            SecurityResearcher storage researcher = _securityResearchers[report.reporter];
            researcher.invalidReports++;
            researcher.currentStreak = 0; // Reset streak for invalid reports
        }
        
        report.status = newStatus;
        report.reviewer = msg.sender;
        report.reviewedAt = block.timestamp;
        report.reviewNotes = reviewNotes;
        
        // Update status mapping
        reportsByStatus[newStatus].push(reportId);
        
        emit VulnerabilityReportReviewed(reportId, newStatus, bountyAmount, msg.sender, block.timestamp);
    }
    
    // ============ SECURITY RESEARCHER MANAGEMENT ============
    
    /**
     * @dev Register security researcher
     */
    function registerSecurityResearcher(
        string calldata handle,
        string calldata email,
        string[] calldata specializations
    ) external whenNotPaused returns (bool) {
        require(_securityResearchers[msg.sender].researcherAddress == address(0), "KarmaBugBountyManager: already registered");
        require(bytes(handle).length > 0, "KarmaBugBountyManager: invalid handle");
        require(handleToAddress[handle] == address(0), "KarmaBugBountyManager: handle already taken");
        require(specializations.length > 0, "KarmaBugBountyManager: no specializations");
        
        SecurityResearcher storage researcher = _securityResearchers[msg.sender];
        researcher.researcherAddress = msg.sender;
        researcher.handle = handle;
        researcher.email = email;
        researcher.tier = ResearcherTier.NEWCOMER;
        researcher.reputation = 0;
        researcher.specializations = specializations;
        researcher.joinedAt = block.timestamp;
        researcher.lastActivityAt = block.timestamp;
        researcher.isVerified = false;
        researcher.isBlacklisted = false;
        
        // Update mappings
        handleToAddress[handle] = msg.sender;
        registeredResearchers.push(msg.sender);
        researchersByTier[ResearcherTier.NEWCOMER].push(msg.sender);
        
        // Update community metrics
        _communityMetrics.totalResearchers++;
        _communityMetrics.tierDistribution[ResearcherTier.NEWCOMER]++;
        
        emit SecurityResearcherRegistered(msg.sender, handle, ResearcherTier.NEWCOMER, block.timestamp);
        
        return true;
    }
    
    /**
     * @dev Verify security researcher
     */
    function verifySecurityResearcher(address researcher) external onlyCommunityManager {
        require(_securityResearchers[researcher].researcherAddress != address(0), "KarmaBugBountyManager: researcher not registered");
        
        _securityResearchers[researcher].isVerified = true;
    }
    
    /**
     * @dev Blacklist security researcher
     */
    function blacklistSecurityResearcher(address researcher, bool blacklisted) external onlyCommunityManager {
        require(_securityResearchers[researcher].researcherAddress != address(0), "KarmaBugBountyManager: researcher not registered");
        
        _securityResearchers[researcher].isBlacklisted = blacklisted;
    }
    
    // ============ PATCH MANAGEMENT ============
    
    /**
     * @dev Submit patch for vulnerability
     */
    function submitPatch(
        uint256 reportId,
        bytes32 patchHash,
        string calldata patchDescription
    ) external onlyPatchManager validReportId(reportId) whenNotPaused {
        VulnerabilityReport storage report = _vulnerabilityReports[reportId];
        require(report.status == ReportStatus.CONFIRMED, "KarmaBugBountyManager: report not confirmed");
        require(patchHash != bytes32(0), "KarmaBugBountyManager: invalid patch hash");
        
        report.patchHash = patchHash;
        report.patchedAt = block.timestamp;
        report.patcher = msg.sender;
        report.status = ReportStatus.PATCHED;
        
        // Mark patch as valid
        isValidPatch[patchHash] = true;
        reportPatchHashes[reportId] = patchHash;
        
        // Update disclosure timeline
        DisclosureTimeline storage timeline = _disclosureTimelines[reportId];
        timeline.patchDeployed = block.timestamp;
        timeline.milestones.push("Patch Deployed");
        timeline.stakeholders.push(msg.sender);
        
        // Update community metrics
        uint256 patchTime = block.timestamp - report.submittedAt;
        _communityMetrics.averagePatchTime = (_communityMetrics.averagePatchTime + patchTime) / 2;
        
        emit VulnerabilityPatched(reportId, patchHash, msg.sender, block.timestamp);
    }
    
    // ============ RESPONSIBLE DISCLOSURE ============
    
    /**
     * @dev Coordinate responsible disclosure
     */
    function coordinateDisclosure(
        uint256 reportId,
        DisclosureStatus disclosureType,
        string calldata publicDisclosure,
        uint256 embargoUntil
    ) external onlyDisclosureManager validReportId(reportId) whenNotPaused {
        VulnerabilityReport storage report = _vulnerabilityReports[reportId];
        require(report.status == ReportStatus.PATCHED, "KarmaBugBountyManager: vulnerability not patched");
        
        if (disclosureType == DisclosureStatus.EMBARGO) {
            require(embargoUntil > block.timestamp, "KarmaBugBountyManager: invalid embargo time");
            disclosureEmbargoUntil[reportId] = embargoUntil;
        }
        
        report.disclosureStatus = disclosureType;
        report.publicDisclosure = publicDisclosure;
        report.disclosedAt = block.timestamp;
        report.status = ReportStatus.DISCLOSED;
        
        // Update disclosure timeline
        DisclosureTimeline storage timeline = _disclosureTimelines[reportId];
        timeline.coordinatedDisclosure = block.timestamp;
        timeline.milestones.push("Coordinated Disclosure");
        timeline.isCompleted = true;
        
        // Mark disclosure as complete
        isDisclosureComplete[reportId] = true;
        
        emit VulnerabilityDisclosed(reportId, disclosureType, publicDisclosure, block.timestamp);
    }
    
    // ============ IMMUNEFI INTEGRATION ============
    
    /**
     * @dev Enable Immunefi integration
     */
    function enableImmunefiIntegration(
        string calldata apiEndpoint,
        bytes32 apiKeyHash,
        uint256 integrationFee,
        bool autoSync
    ) external onlyImmunefiIntegrator whenNotPaused {
        require(bytes(apiEndpoint).length > 0, "KarmaBugBountyManager: invalid API endpoint");
        require(apiKeyHash != bytes32(0), "KarmaBugBountyManager: invalid API key hash");
        
        _immunefiIntegration.isActive = true;
        _immunefiIntegration.apiEndpoint = apiEndpoint;
        _immunefiIntegration.apiKeyHash = apiKeyHash;
        _immunefiIntegration.integrationFee = integrationFee;
        _immunefiIntegration.autoSync = autoSync;
        _immunefiIntegration.lastSyncAt = block.timestamp;
        
        emit ImmunefiIntegrationEnabled(apiEndpoint, integrationFee, autoSync, block.timestamp);
    }
    
    /**
     * @dev Sync report with Immunefi
     */
    function syncWithImmunefi(
        string calldata immunefiId,
        uint256 internalReportId
    ) external onlyImmunefiIntegrator validReportId(internalReportId) {
        require(_immunefiIntegration.isActive, "KarmaBugBountyManager: Immunefi integration not active");
        require(bytes(immunefiId).length > 0, "KarmaBugBountyManager: invalid Immunefi ID");
        
        _immunefiIntegration.immunefiReportMapping[immunefiId] = internalReportId;
        _immunefiIntegration.totalSynced++;
        _immunefiIntegration.lastSyncAt = block.timestamp;
        
        emit ImmunefiReportSynced(immunefiId, internalReportId, block.timestamp);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get vulnerability report details
     */
    function getVulnerabilityReport(uint256 reportId) 
        external view validReportId(reportId) returns (VulnerabilityReport memory) {
        return _vulnerabilityReports[reportId];
    }
    
    /**
     * @dev Get security researcher details
     */
    function getSecurityResearcher(address researcher) external view returns (
        string memory handle,
        ResearcherTier tier,
        uint256 reputation,
        uint256 totalEarnings,
        uint256 validReports,
        uint256 invalidReports,
        bool isVerified,
        bool isBlacklisted
    ) {
        SecurityResearcher storage r = _securityResearchers[researcher];
        return (r.handle, r.tier, r.reputation, r.totalEarnings, r.validReports, r.invalidReports, r.isVerified, r.isBlacklisted);
    }
    
    /**
     * @dev Get bug bounty program details
     */
    function getBugBountyProgram(uint256 programId) external view validProgramId(programId) returns (
        string memory programName,
        bool isActive,
        uint256 totalFunding,
        uint256 availableFunding,
        uint256 maxReward,
        uint256 totalReports,
        uint256 validReports,
        uint256 totalPaid,
        bool immunefiIntegrated
    ) {
        BugBountyProgram storage program = _bugBountyPrograms[programId];
        return (
            program.programName,
            program.isActive,
            program.totalFunding,
            program.availableFunding,
            program.maxReward,
            program.totalReports,
            program.validReports,
            program.totalPaid,
            program.immunefiIntegrated
        );
    }
    
    /**
     * @dev Get community metrics
     */
    function getCommunityMetrics() external view returns (
        uint256 totalResearchers,
        uint256 activeResearchers,
        uint256 totalReports,
        uint256 validReports,
        uint256 totalBountiesPaid,
        uint256 averageResponseTime,
        uint256 averagePatchTime,
        uint256 averageBountyAmount
    ) {
        // Calculate active researchers (active in last 30 days)
        uint256 activeCount = 0;
        uint256 thirtyDaysAgo = block.timestamp - 30 days;
        for (uint256 i = 0; i < registeredResearchers.length; i++) {
            if (_securityResearchers[registeredResearchers[i]].lastActivityAt >= thirtyDaysAgo) {
                activeCount++;
            }
        }
        
        return (
            _communityMetrics.totalResearchers,
            activeCount,
            _communityMetrics.totalReports,
            _communityMetrics.validReports,
            _communityMetrics.totalBountiesPaid,
            _communityMetrics.averageResponseTime,
            _communityMetrics.averagePatchTime,
            _communityMetrics.averageBountyAmount
        );
    }
    
    /**
     * @dev Get disclosure timeline
     */
    function getDisclosureTimeline(uint256 reportId) 
        external view validReportId(reportId) returns (DisclosureTimeline memory) {
        return _disclosureTimelines[reportId];
    }
    
    /**
     * @dev Get reports by researcher
     */
    function getReportsByResearcher(address researcher) external view returns (uint256[] memory) {
        return reportsByReporter[researcher];
    }
    
    /**
     * @dev Get active bug bounty programs
     */
    function getActiveBugBountyPrograms() external view returns (uint256[] memory) {
        return activeProgramIds;
    }
    
    // ============ INTERNAL HELPER FUNCTIONS ============
    
    function _findSuitableBountyProgram(uint256 bountyAmount, address[] memory affectedContracts) 
        internal view returns (uint256) {
        for (uint256 i = 0; i < activeProgramIds.length; i++) {
            uint256 programId = activeProgramIds[i];
            BugBountyProgram storage program = _bugBountyPrograms[programId];
            
            if (program.isActive && 
                program.availableFunding >= bountyAmount && 
                block.timestamp <= program.endTime) {
                
                // Check if any affected contract is in target contracts
                for (uint256 j = 0; j < affectedContracts.length; j++) {
                    for (uint256 k = 0; k < program.targetContracts.length; k++) {
                        if (affectedContracts[j] == program.targetContracts[k]) {
                            return programId;
                        }
                    }
                }
            }
        }
        return 0;
    }
    
    function _updateResearcherTier(address researcher) internal {
        SecurityResearcher storage r = _securityResearchers[researcher];
        ResearcherTier oldTier = r.tier;
        ResearcherTier newTier = oldTier;
        
        // Calculate reputation based on earnings and report quality
        uint256 baseReputation = r.totalEarnings / 1e6; // $1 = 1 reputation point
        uint256 qualityBonus = r.validReports * 10;
        uint256 qualityPenalty = r.invalidReports * 5;
        
        r.reputation = baseReputation + qualityBonus - qualityPenalty;
        
        // Determine new tier
        if (r.reputation >= 5000) {
            newTier = ResearcherTier.LEGEND;
        } else if (r.reputation >= 1500) {
            newTier = ResearcherTier.EXPERT;
        } else if (r.reputation >= 500) {
            newTier = ResearcherTier.VETERAN;
        } else if (r.reputation >= 100) {
            newTier = ResearcherTier.CONTRIBUTOR;
        }
        
        if (newTier != oldTier) {
            r.tier = newTier;
            
            // Update tier mappings
            _communityMetrics.tierDistribution[oldTier]--;
            _communityMetrics.tierDistribution[newTier]++;
            
            emit ResearcherTierUpdated(researcher, oldTier, newTier, r.reputation);
        }
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Emergency pause
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Withdraw funds (admin only)
     */
    function emergencyWithdraw(address recipient, uint256 amount) 
        external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(recipient != address(0), "KarmaBugBountyManager: invalid recipient");
        require(amount <= usdcToken.balanceOf(address(this)), "KarmaBugBountyManager: insufficient balance");
        
        usdcToken.safeTransfer(recipient, amount);
    }
} 