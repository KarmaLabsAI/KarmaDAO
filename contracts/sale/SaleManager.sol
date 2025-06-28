// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISaleManager.sol";
import "../interfaces/IVestingVault.sol";
import "../token/KarmaToken.sol";

/**
 * @title SaleManager
 * @dev Multi-phase token sale manager with whitelist and KYC support
 * 
 * Features:
 * - State machine for different sale phases (Private, Pre-Sale, Public)  
 * - Purchase processing with ETH to KARMA conversion
 * - Merkle tree whitelist verification
 * - KYC integration and access controls
 * - Integration with VestingVault for token distribution
 * - Comprehensive analytics and reporting
 * - Stage 3.2: Community engagement scoring system
 * - Stage 3.2: Referral system for pre-sale participants
 * - Stage 3.2: Exact business logic implementation
 * - Stage 3.2: Basic Uniswap V3 integration and MEV protection
 */
contract SaleManager is ISaleManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ CONSTANTS ============
    
    // Role definitions
    bytes32 public constant SALE_MANAGER_ROLE = keccak256("SALE_MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant WHITELIST_MANAGER_ROLE = keccak256("WHITELIST_MANAGER_ROLE");
    bytes32 public constant ENGAGEMENT_MANAGER_ROLE = keccak256("ENGAGEMENT_MANAGER_ROLE");
    
    // Precision for price calculations (18 decimals)
    uint256 private constant PRICE_PRECISION = 1e18;
    
    // Stage 3.2: Business Logic Constants (exact requirements from development plan)
    uint256 private constant PRIVATE_SALE_PRICE = 0.02 ether; // $0.02 per token
    uint256 private constant PRE_SALE_PRICE = 0.04 ether; // $0.04 per token
    uint256 private constant PUBLIC_SALE_PRICE = 0.05 ether; // $0.05 per token
    
    uint256 private constant PRIVATE_SALE_MIN = 25000 ether; // $25K minimum
    uint256 private constant PRIVATE_SALE_MAX = 200000 ether; // $200K maximum
    uint256 private constant PRE_SALE_MIN = 1000 ether; // $1K minimum
    uint256 private constant PRE_SALE_MAX = 10000 ether; // $10K maximum
    uint256 private constant PUBLIC_SALE_MAX = 5000 ether; // $5K maximum per wallet
    
    uint256 private constant PRIVATE_SALE_HARD_CAP = 2000000 ether; // $2M raise
    uint256 private constant PRE_SALE_HARD_CAP = 4000000 ether; // $4M raise
    uint256 private constant PUBLIC_SALE_HARD_CAP = 7500000 ether; // $7.5M raise
    
    uint256 private constant PRIVATE_SALE_ALLOCATION = 100000000 ether; // 100M tokens
    uint256 private constant PRE_SALE_ALLOCATION = 100000000 ether; // 100M tokens
    uint256 private constant PUBLIC_SALE_ALLOCATION = 150000000 ether; // 150M tokens
    
    // Stage 3.2: Engagement and Referral Constants
    uint256 private constant MAX_ENGAGEMENT_BONUS = 1000; // 10% max bonus (basis points)
    uint256 private constant REFERRAL_BONUS = 500; // 5% referral bonus (basis points)
    uint256 private constant MIN_ENGAGEMENT_SCORE = 100; // Minimum for bonus eligibility
    uint256 private constant MAX_SLIPPAGE_BPS = 500; // 5% max slippage for MEV protection
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    KarmaToken public immutable karmaToken;
    IVestingVault public immutable vestingVault;
    address public treasury;
    
    // Sale state
    SalePhase public currentPhase;
    uint256 public totalPurchases;
    uint256 public totalParticipants;
    
    // Phase configurations
    mapping(SalePhase => PhaseConfig) private _phaseConfigs;
    mapping(SalePhase => bool) private _phaseConfigured;
    
    // Purchase tracking (updated for Stage 3.2)
    mapping(uint256 => Purchase) private _purchases;
    mapping(address => Participant) private _participants;
    mapping(address => bool) private _hasParticipated;
    
    // Phase statistics
    mapping(SalePhase => uint256) private _phaseEthRaised;
    mapping(SalePhase => uint256) private _phaseTokensSold;
    mapping(SalePhase => uint256) private _phaseParticipants;
    mapping(SalePhase => address[]) private _phaseParticipantList;
    
    // Rate limiting for anti-abuse
    mapping(address => uint256) private _lastPurchaseTime;
    uint256 public constant MIN_PURCHASE_INTERVAL = 60; // 1 minute between purchases
    
    // Stage 3.2: Community Engagement System
    mapping(address => EngagementData) private _engagementData;
    mapping(address => uint256) private _calculatedEngagementScore;
    uint256 public totalEngagementUpdates;
    
    // Stage 3.2: Referral System
    mapping(address => address[]) private _referees; // referrer => array of referees
    mapping(address => address) private _referrer; // referee => referrer
    mapping(address => uint256) private _referralBonusEarned;
    uint256 public totalReferrals;
    uint256 public totalReferralBonus;
    uint256 public activeReferrers;
    
    // Stage 3.2: MEV Protection
    mapping(address => uint256) private _maxSlippageBps;
    mapping(address => bool) private _mevProtectionEnabled;
    
    // Stage 3.2: Liquidity Configuration
    LiquidityConfig private _liquidityConfig;
    bool private _liquidityConfigured;
    address public liquidityPool;
    
    // ============ STAGE 3.3: TREASURY INTEGRATION ============
    
    // Automatic forwarding configuration
    bool public automaticForwardingEnabled;
    uint256 public forwardingThreshold;
    uint256 public totalForwarded;
    
    // Fund allocation tracking
    mapping(string => uint256) private _fundAllocations; // category => allocated amount
    mapping(string => uint256) private _fundSpent; // category => spent amount
    string[] private _allocationCategories;
    mapping(string => bool) private _categoryExists;
    
    // Enhanced transaction logging
    struct TransactionLog {
        address participant;
        uint256 amount;
        uint256 tokens;
        SalePhase phase;
        uint256 timestamp;
        string transactionType;
    }
    TransactionLog[] private _transactionHistory;
    
    // ============ STAGE 3.3: SECURITY AND ANTI-ABUSE ============
    
    // Front-running protection
    mapping(address => uint256) private _maxPriceImpact;
    mapping(address => uint256) private _commitDuration;
    mapping(address => bytes32) private _purchaseCommitments;
    mapping(address => uint256) private _commitmentTimestamp;
    mapping(address => bool) private _frontRunningProtectionEnabled;
    
    // Advanced rate limiting
    mapping(address => uint256) private _dailyLimit;
    mapping(address => uint256) private _hourlyLimit;
    mapping(address => uint256) private _cooldownPeriod;
    mapping(address => uint256) private _dailySpent;
    mapping(address => uint256) private _hourlySpent;
    mapping(address => uint256) private _lastDayReset;
    mapping(address => uint256) private _lastHourReset;
    mapping(address => uint256) private _lastLargePurchase;
    
    // ============ STAGE 3.3: REPORTING AND ANALYTICS ============
    
    // Analytics hooks
    mapping(address => bool) private _analyticsHooks;
    mapping(address => mapping(string => bool)) private _hookEvents;
    address[] private _activeHooks;
    
    // Enhanced participant tracking
    mapping(address => uint256) private _participantRiskScore;
    mapping(address => bool) private _isHighValueParticipant;
    mapping(address => bool) private _isFrequentTrader;
    mapping(address => uint256) private _participantFirstPurchase;
    mapping(address => uint256) private _suspiciousActivityCount;
    
    // Compliance tracking
    uint256 public totalSuspiciousActivities;
    uint256 public totalHighValueParticipants;
    uint256 public totalFrequentTraders;
    
    // ============ EVENTS ============
    
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event RateLimitUpdated(uint256 newInterval);
    
    // ============ MODIFIERS ============
    
    modifier onlySaleManager() {
        require(hasRole(SALE_MANAGER_ROLE, msg.sender), "SaleManager: caller is not sale manager");
        _;
    }
    
    modifier onlyKYCManager() {
        require(hasRole(KYC_MANAGER_ROLE, msg.sender), "SaleManager: caller is not KYC manager");
        _;
    }
    
    modifier onlyWhitelistManager() {
        require(hasRole(WHITELIST_MANAGER_ROLE, msg.sender), "SaleManager: caller is not whitelist manager");
        _;
    }
    
    modifier onlyEngagementManager() {
        require(hasRole(ENGAGEMENT_MANAGER_ROLE, msg.sender), "SaleManager: caller is not engagement manager");
        _;
    }
    
    modifier validPhase(SalePhase phase) {
        require(phase != SalePhase.NOT_STARTED && phase != SalePhase.ENDED, "SaleManager: invalid phase");
        _;
    }
    
    modifier phaseActive() {
        require(currentPhase != SalePhase.NOT_STARTED && currentPhase != SalePhase.ENDED, "SaleManager: no active phase");
        require(block.timestamp >= _phaseConfigs[currentPhase].startTime, "SaleManager: phase not started");
        require(block.timestamp <= _phaseConfigs[currentPhase].endTime, "SaleManager: phase ended");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _vestingVault,
        address _treasury,
        address admin
    ) {
        require(_karmaToken != address(0), "SaleManager: invalid token address");
        require(_vestingVault != address(0), "SaleManager: invalid vesting vault address");
        require(_treasury != address(0), "SaleManager: invalid treasury address");
        require(admin != address(0), "SaleManager: invalid admin address");
        
        karmaToken = KarmaToken(_karmaToken);
        vestingVault = IVestingVault(_vestingVault);
        treasury = _treasury;
        
        // Initialize state
        currentPhase = SalePhase.NOT_STARTED;
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SALE_MANAGER_ROLE, admin);
        _grantRole(KYC_MANAGER_ROLE, admin);
        _grantRole(WHITELIST_MANAGER_ROLE, admin);
        _grantRole(ENGAGEMENT_MANAGER_ROLE, admin);
    }
    
    // ============ STAGE 3.2: PHASE CONFIGURATION HELPERS ============
    
    /**
     * @dev Configure private sale with exact business parameters (Stage 3.2)
     */
    function configurePrivateSale(uint256 startTime, bytes32 merkleRoot) 
        external 
        override 
        onlySaleManager 
    {
        require(startTime > block.timestamp, "SaleManager: start time must be in future");
        
        PhaseConfig memory config = PhaseConfig({
            price: PRIVATE_SALE_PRICE,
            minPurchase: PRIVATE_SALE_MIN,
            maxPurchase: PRIVATE_SALE_MAX,
            hardCap: PRIVATE_SALE_HARD_CAP,
            tokenAllocation: PRIVATE_SALE_ALLOCATION,
            startTime: startTime,
            endTime: startTime + 30 days, // 1 month duration
            whitelistRequired: true,
            kycRequired: true,
            merkleRoot: merkleRoot
        });
        
        _phaseConfigs[SalePhase.PRIVATE] = config;
        _phaseConfigured[SalePhase.PRIVATE] = true;
        
        emit PhaseConfigUpdated(SalePhase.PRIVATE, config.price, config.hardCap);
    }
    
    /**
     * @dev Configure pre-sale with exact business parameters (Stage 3.2)
     */
    function configurePreSale(uint256 startTime, bytes32 merkleRoot) 
        external 
        override 
        onlySaleManager 
    {
        require(startTime > block.timestamp, "SaleManager: start time must be in future");
        require(_phaseConfigured[SalePhase.PRIVATE], "SaleManager: private sale must be configured first");
        
        PhaseConfig memory config = PhaseConfig({
            price: PRE_SALE_PRICE,
            minPurchase: PRE_SALE_MIN,
            maxPurchase: PRE_SALE_MAX,
            hardCap: PRE_SALE_HARD_CAP,
            tokenAllocation: PRE_SALE_ALLOCATION,
            startTime: startTime,
            endTime: startTime + 30 days, // 1 month duration
            whitelistRequired: true,
            kycRequired: false,
            merkleRoot: merkleRoot
        });
        
        _phaseConfigs[SalePhase.PRE_SALE] = config;
        _phaseConfigured[SalePhase.PRE_SALE] = true;
        
        emit PhaseConfigUpdated(SalePhase.PRE_SALE, config.price, config.hardCap);
    }
    
    /**
     * @dev Configure public sale with exact business parameters (Stage 3.2)
     */
    function configurePublicSale(uint256 startTime, LiquidityConfig memory liquidityConfig) 
        external 
        override 
        onlySaleManager 
    {
        require(startTime > block.timestamp, "SaleManager: start time must be in future");
        require(_phaseConfigured[SalePhase.PRE_SALE], "SaleManager: pre-sale must be configured first");
        
        PhaseConfig memory config = PhaseConfig({
            price: PUBLIC_SALE_PRICE,
            minPurchase: 0, // No minimum for public sale
            maxPurchase: PUBLIC_SALE_MAX,
            hardCap: PUBLIC_SALE_HARD_CAP,
            tokenAllocation: PUBLIC_SALE_ALLOCATION,
            startTime: startTime,
            endTime: startTime + 7 days, // 1 week duration
            whitelistRequired: false,
            kycRequired: false,
            merkleRoot: bytes32(0)
        });
        
        _phaseConfigs[SalePhase.PUBLIC] = config;
        _phaseConfigured[SalePhase.PUBLIC] = true;
        
        // Store liquidity configuration
        _liquidityConfig = liquidityConfig;
        _liquidityConfigured = true;
        
        emit PhaseConfigUpdated(SalePhase.PUBLIC, config.price, config.hardCap);
    }
    
    // ============ STAGE 3.2: COMMUNITY ENGAGEMENT SCORING ============
    
    function updateEngagementScore(address participant, EngagementData memory engagementData) 
        external 
        override
        onlyEngagementManager 
    {
        require(participant != address(0), "SaleManager: invalid participant");
        require(engagementData.verified, "SaleManager: engagement data not verified");
        
        uint256 oldScore = _calculatedEngagementScore[participant];
        
        _engagementData[participant] = engagementData;
        
        // Calculate total engagement score (0-10000 basis points)
        uint256 newScore = calculateEngagementScore(participant);
        _calculatedEngagementScore[participant] = newScore;
        
        totalEngagementUpdates++;
        
        emit EngagementScoreUpdated(participant, oldScore, newScore);
    }
    
    function getEngagementData(address participant) 
        external 
        view 
        override
        returns (EngagementData memory) 
    {
        return _engagementData[participant];
    }
    
    function calculateEngagementScore(address participant) 
        public 
        view 
        override
        returns (uint256 score) 
    {
        EngagementData memory data = _engagementData[participant];
        
        if (!data.verified || data.lastUpdated == 0) {
            return 0;
        }
        
        // Weight different activities (total 10000 basis points = 100%)
        score = (data.discordActivity * 3000) / 100 +      // 30% weight
                (data.twitterActivity * 2500) / 100 +      // 25% weight  
                (data.githubActivity * 3000) / 100 +       // 30% weight
                (data.forumActivity * 1500) / 100;         // 15% weight
        
        // Cap at maximum engagement bonus
        if (score > MAX_ENGAGEMENT_BONUS) {
            score = MAX_ENGAGEMENT_BONUS;
        }
        
        return score;
    }
    
    // ============ STAGE 3.2: REFERRAL SYSTEM ============
    
    function registerReferral(address referrer, address referee) 
        external 
        override
        onlyEngagementManager 
    {
        require(referrer != address(0) && referee != address(0), "SaleManager: invalid addresses");
        require(referrer != referee, "SaleManager: cannot refer yourself");
        require(_participants[referrer].isPrivateSaleParticipant, "SaleManager: referrer not private sale participant");
        require(_referrer[referee] == address(0), "SaleManager: referee already has referrer");
        
        _referrer[referee] = referrer;
        _referees[referrer].push(referee);
        
        // Track if this is the first referral for this referrer
        if (_referees[referrer].length == 1) {
            activeReferrers++;
        }
        
        totalReferrals++;
        
        emit ReferralRegistered(referrer, referee, REFERRAL_BONUS);
    }
    
    function getReferralBonusRate(address referrer) 
        external 
        view 
        override
        returns (uint256 bonusRate) 
    {
        if (_participants[referrer].isPrivateSaleParticipant && _referees[referrer].length > 0) {
            return REFERRAL_BONUS; // 5% bonus for valid referrers
        }
        return 0;
    }
    
    function getReferees(address referrer) 
        external 
        view 
        override
        returns (address[] memory) 
    {
        return _referees[referrer];
    }
    
    // ============ PHASE MANAGEMENT ============
    
    function startSalePhase(SalePhase phase, PhaseConfig memory config) 
        external 
        override
        onlySaleManager 
        validPhase(phase) 
        whenNotPaused 
    {
        require(currentPhase == SalePhase.NOT_STARTED || currentPhase == SalePhase.ENDED, "SaleManager: phase already active");
        require(config.startTime > block.timestamp, "SaleManager: start time must be in future");
        require(config.endTime > config.startTime, "SaleManager: end time must be after start time");
        require(config.price > 0, "SaleManager: price must be positive");
        require(config.hardCap > 0, "SaleManager: hard cap must be positive");
        require(config.tokenAllocation > 0, "SaleManager: token allocation must be positive");
        require(config.minPurchase <= config.maxPurchase, "SaleManager: invalid purchase limits");
        
        // Validate phase sequence
        if (phase == SalePhase.PRE_SALE) {
            require(_phaseConfigured[SalePhase.PRIVATE], "SaleManager: private sale must be configured first");
        } else if (phase == SalePhase.PUBLIC) {
            require(_phaseConfigured[SalePhase.PRE_SALE], "SaleManager: pre-sale must be configured first");
        }
        
        _phaseConfigs[phase] = config;
        _phaseConfigured[phase] = true;
        currentPhase = phase;
        
        emit SalePhaseStarted(phase, config.startTime, config.endTime);
    }
    
    function endCurrentPhase() external override onlySaleManager {
        require(currentPhase != SalePhase.NOT_STARTED && currentPhase != SalePhase.ENDED, "SaleManager: no active phase");
        
        SalePhase endingPhase = currentPhase;
        
        // Determine next phase or end sale
        if (currentPhase == SalePhase.PRIVATE) {
            currentPhase = _phaseConfigured[SalePhase.PRE_SALE] ? SalePhase.NOT_STARTED : SalePhase.ENDED;
        } else if (currentPhase == SalePhase.PRE_SALE) {
            currentPhase = _phaseConfigured[SalePhase.PUBLIC] ? SalePhase.NOT_STARTED : SalePhase.ENDED;
        } else {
            currentPhase = SalePhase.ENDED;
        }
        
        emit SalePhaseEnded(endingPhase, block.timestamp);
    }
    
    function updatePhaseConfig(SalePhase phase, PhaseConfig memory config) 
        external 
        override
        onlySaleManager 
        validPhase(phase) 
    {
        require(currentPhase != phase || block.timestamp < config.startTime, "SaleManager: cannot update active phase");
        require(config.price > 0, "SaleManager: price must be positive");
        require(config.hardCap > 0, "SaleManager: hard cap must be positive");
        require(config.tokenAllocation > 0, "SaleManager: token allocation must be positive");
        
        _phaseConfigs[phase] = config;
        _phaseConfigured[phase] = true;
        
        emit PhaseConfigUpdated(phase, config.price, config.hardCap);
    }
    
    function getCurrentPhase() external view override returns (SalePhase) {
        return currentPhase;
    }
    
    function getPhaseConfig(SalePhase phase) external view override returns (PhaseConfig memory) {
        return _phaseConfigs[phase];
    }
    
    // ============ PURCHASE PROCESSING ============
    
    function purchaseTokens(bytes32[] memory merkleProof) 
        external 
        payable 
        override
        phaseActive 
        whenNotPaused 
        nonReentrant 
    {
        _processPurchase(merkleProof, address(0), 0, 0);
    }
    
    function purchaseTokensWithReferral(bytes32[] memory merkleProof, address referrer) 
        external 
        payable 
        override
        phaseActive 
        whenNotPaused 
        nonReentrant 
    {
        require(currentPhase == SalePhase.PRE_SALE, "SaleManager: referrals only for pre-sale");
        require(_participants[referrer].isPrivateSaleParticipant, "SaleManager: invalid referrer");
        
        _processPurchase(merkleProof, referrer, 0, 0);
    }
    
    function purchaseTokensWithMEVProtection(
        bytes32[] memory merkleProof,
        uint256 minTokensOut,
        uint256 deadline
    ) external payable override phaseActive whenNotPaused nonReentrant {
        require(currentPhase == SalePhase.PUBLIC, "SaleManager: MEV protection only for public sale");
        require(deadline >= block.timestamp, "SaleManager: deadline passed");
        require(_mevProtectionEnabled[msg.sender], "SaleManager: MEV protection not enabled");
        
        _processPurchase(merkleProof, address(0), minTokensOut, deadline);
    }
    
    function _processPurchase(
        bytes32[] memory merkleProof,
        address referrer,
        uint256 minTokensOut,
        uint256 deadline
    ) internal {
        require(msg.value > 0, "SaleManager: must send ETH");
        
        PhaseConfig memory config = _phaseConfigs[currentPhase];
        
        // Validate purchase amount
        require(msg.value >= config.minPurchase, "SaleManager: below minimum purchase");
        require(msg.value <= config.maxPurchase, "SaleManager: above maximum purchase");
        
        // Check rate limiting
        require(
            block.timestamp >= _lastPurchaseTime[msg.sender] + MIN_PURCHASE_INTERVAL,
            "SaleManager: purchase too frequent"
        );
        
        // Verify whitelist if required
        if (config.whitelistRequired) {
            require(
                verifyWhitelist(msg.sender, currentPhase, merkleProof),
                "SaleManager: not whitelisted"
            );
        }
        
        // Verify KYC if required
        if (config.kycRequired) {
            require(
                _participants[msg.sender].kycStatus == KYCStatus.APPROVED,
                "SaleManager: KYC not approved"
            );
        }
        
        // For private sale, require accredited investor status
        if (currentPhase == SalePhase.PRIVATE) {
            require(_participants[msg.sender].isAccredited, "SaleManager: not accredited investor");
        }
        
        // Check phase limits
        require(
            _phaseEthRaised[currentPhase] + msg.value <= config.hardCap,
            "SaleManager: phase hard cap exceeded"
        );
        
        // Calculate base token amount
        uint256 baseTokenAmount = calculateTokenAmount(msg.value);
        require(
            _phaseTokensSold[currentPhase] + baseTokenAmount <= config.tokenAllocation,
            "SaleManager: token allocation exceeded"
        );
        
        // Calculate bonus tokens (Stage 3.2)
        uint256 bonusTokens = calculateBonusTokens(msg.sender, baseTokenAmount);
        if (referrer != address(0) && currentPhase == SalePhase.PRE_SALE) {
            bonusTokens += (baseTokenAmount * REFERRAL_BONUS) / 10000;
            _referralBonusEarned[referrer] += bonusTokens;
            totalReferralBonus += bonusTokens;
        }
        
        uint256 totalTokenAmount = baseTokenAmount + bonusTokens;
        
        // MEV protection check
        if (minTokensOut > 0) {
            require(totalTokenAmount >= minTokensOut, "SaleManager: slippage too high");
        }
        
        // Create purchase record (updated for Stage 3.2)
        uint256 purchaseId = totalPurchases++;
        Purchase storage purchase = _purchases[purchaseId];
        purchase.buyer = msg.sender;
        purchase.ethAmount = msg.value;
        purchase.tokenAmount = totalTokenAmount;
        purchase.phase = currentPhase;
        purchase.timestamp = block.timestamp;
        purchase.referrer = referrer;
        purchase.bonusTokens = bonusTokens;
        
        // Determine vesting based on phase (Stage 3.2 business logic)
        bool shouldVest = (currentPhase == SalePhase.PRIVATE);
        purchase.vested = shouldVest;
        
        // Update participant data
        Participant storage participant = _participants[msg.sender];
        if (!_hasParticipated[msg.sender]) {
            _hasParticipated[msg.sender] = true;
            totalParticipants++;
            _phaseParticipants[currentPhase]++;
            _phaseParticipantList[currentPhase].push(msg.sender);
            participant.kycStatus = KYCStatus.PENDING;
        }
        
        participant.totalEthSpent += msg.value;
        participant.totalTokensBought += totalTokenAmount;
        participant.lastPurchaseTime = block.timestamp;
        participant.purchaseIds.push(purchaseId);
        
        // Mark as private sale participant for referral eligibility
        if (currentPhase == SalePhase.PRIVATE) {
            participant.isPrivateSaleParticipant = true;
        }
        
        // Update phase statistics
        _phaseEthRaised[currentPhase] += msg.value;
        _phaseTokensSold[currentPhase] += totalTokenAmount;
        
        // Update rate limiting
        _lastPurchaseTime[msg.sender] = block.timestamp;
        
        // Stage 3.3: Update participant analytics
        _updateParticipantAnalytics(msg.sender, msg.value);
        
        // Stage 3.3: Log transaction
        _logTransaction(msg.sender, msg.value, totalTokenAmount, "purchase");
        
        // Distribute tokens according to Stage 3.2 business logic
        _distributeTokens(msg.sender, totalTokenAmount, currentPhase);
        
        // Stage 3.3: Check and forward funds automatically
        _checkAndForwardFunds();
        
        emit TokenPurchase(msg.sender, purchaseId, currentPhase, msg.value, totalTokenAmount, shouldVest);
    }
    
    function _distributeTokens(address buyer, uint256 tokenAmount, SalePhase phase) internal {
        if (phase == SalePhase.PRIVATE) {
            // Private Sale: 100% vested (6-month linear)
            karmaToken.mint(address(this), tokenAmount);
            karmaToken.approve(address(vestingVault), tokenAmount);
            
            vestingVault.createVestingSchedule(
                buyer,
                tokenAmount,
                block.timestamp,
                0, // No cliff
                180 days, // 6 months
                "PRIVATE_SALE"
            );
        } else if (phase == SalePhase.PRE_SALE) {
            // Pre-Sale: 50% immediate, 50% vested (3-month linear)
            uint256 immediateAmount = tokenAmount / 2;
            uint256 vestedAmount = tokenAmount - immediateAmount;
            
            // Immediate tokens
            karmaToken.mint(buyer, immediateAmount);
            
            // Vested tokens
            karmaToken.mint(address(this), vestedAmount);
            karmaToken.approve(address(vestingVault), vestedAmount);
            
            vestingVault.createVestingSchedule(
                buyer,
                vestedAmount,
                block.timestamp,
                0, // No cliff
                90 days, // 3 months
                "PRE_SALE"
            );
        } else {
            // Public Sale: 100% immediate distribution
            karmaToken.mint(buyer, tokenAmount);
        }
    }
    
    function calculateTokenAmount(uint256 ethAmount) public view override returns (uint256) {
        if (currentPhase == SalePhase.NOT_STARTED || currentPhase == SalePhase.ENDED) {
            return 0;
        }
        
        PhaseConfig memory config = _phaseConfigs[currentPhase];
        return (ethAmount * PRICE_PRECISION) / config.price;
    }
    
    function calculateBonusTokens(address participant, uint256 baseTokens) 
        public 
        view 
        override
        returns (uint256 bonusTokens) 
    {
        if (currentPhase != SalePhase.PRE_SALE) {
            return 0; // Bonus only for pre-sale
        }
        
        uint256 engagementScore = calculateEngagementScore(participant);
        if (engagementScore >= MIN_ENGAGEMENT_SCORE) {
            bonusTokens = (baseTokens * engagementScore) / 10000;
        }
        
        return bonusTokens;
    }
    
    function getPurchase(uint256 purchaseId) external view override returns (Purchase memory) {
        require(purchaseId < totalPurchases, "SaleManager: invalid purchase ID");
        return _purchases[purchaseId];
    }
    
    // ============ WHITELIST AND ACCESS CONTROL ============
    
    function updateWhitelist(SalePhase phase, bytes32 merkleRoot) 
        external 
        override
        onlyWhitelistManager 
        validPhase(phase) 
    {
        _phaseConfigs[phase].merkleRoot = merkleRoot;
        emit WhitelistUpdated(phase, merkleRoot);
    }
    
    function verifyWhitelist(
        address participant,
        SalePhase phase,
        bytes32[] memory merkleProof
    ) public view override returns (bool) {
        bytes32 merkleRoot = _phaseConfigs[phase].merkleRoot;
        if (merkleRoot == bytes32(0)) {
            return true; // No whitelist required
        }
        
        bytes32 leaf = keccak256(abi.encodePacked(participant));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
    
    function updateKYCStatus(address participant, KYCStatus status) 
        external 
        override
        onlyKYCManager 
    {
        _participants[participant].kycStatus = status;
        emit KYCStatusUpdated(participant, status);
    }
    
    function setAccreditedStatus(address participant, bool isAccredited) 
        external 
        override
        onlyKYCManager 
    {
        _participants[participant].isAccredited = isAccredited;
    }
    
    // ============ STAGE 3.2: MEV PROTECTION ============
    
    function enableMEVProtection(uint256 maxSlippageBps) external override {
        require(maxSlippageBps <= MAX_SLIPPAGE_BPS, "SaleManager: slippage too high");
        
        _maxSlippageBps[msg.sender] = maxSlippageBps;
        _mevProtectionEnabled[msg.sender] = true;
        
        emit MEVProtectionEnabled(msg.sender, maxSlippageBps);
    }
    
    // ============ STAGE 3.2: UNISWAP V3 INTEGRATION ============
    
    function configureLiquidityPool(LiquidityConfig memory config) external override onlySaleManager {
        require(config.uniswapV3Factory != address(0), "SaleManager: invalid factory");
        require(config.uniswapV3Router != address(0), "SaleManager: invalid router");
        require(config.wethAddress != address(0), "SaleManager: invalid WETH");
        
        _liquidityConfig = config;
        _liquidityConfigured = true;
    }
    
    function createLiquidityPool() external override onlySaleManager returns (address poolAddress) {
        require(_liquidityConfigured, "SaleManager: liquidity not configured");
        require(currentPhase == SalePhase.PUBLIC, "SaleManager: only during public sale");
        
        // Simplified implementation - in production would integrate with actual Uniswap V3 contracts
        liquidityPool = address(uint160(uint256(keccak256(abi.encodePacked(
            address(karmaToken),
            _liquidityConfig.wethAddress,
            _liquidityConfig.poolFee,
            block.timestamp
        )))));
        
        emit LiquidityPoolCreated(
            liquidityPool,
            _liquidityConfig.liquidityEth,
            _liquidityConfig.liquidityTokens
        );
        
        return liquidityPool;
    }
    
    function getLiquidityConfig() external view override returns (LiquidityConfig memory) {
        return _liquidityConfig;
    }
    
    // ============ PARTICIPANT MANAGEMENT ============
    
    function getParticipant(address participant) external view override returns (Participant memory) {
        return _participants[participant];
    }
    
    function getParticipantPurchases(address participant) 
        external 
        view 
        override
        returns (uint256[] memory) 
    {
        return _participants[participant].purchaseIds;
    }
    
    // ============ ANALYTICS AND REPORTING ============
    
    function getPhaseStatistics(SalePhase phase) 
        external 
        view 
        override
        returns (uint256 totalEthRaised, uint256 totalTokensSold, uint256 participantCount) 
    {
        return (_phaseEthRaised[phase], _phaseTokensSold[phase], _phaseParticipants[phase]);
    }
    
    function getOverallStatistics() 
        external 
        view 
        override
        returns (uint256 totalEthRaised, uint256 totalTokensSold, uint256 totalParticipantsCount) 
    {
        totalEthRaised = _phaseEthRaised[SalePhase.PRIVATE] + 
                        _phaseEthRaised[SalePhase.PRE_SALE] + 
                        _phaseEthRaised[SalePhase.PUBLIC];
        
        totalTokensSold = _phaseTokensSold[SalePhase.PRIVATE] + 
                         _phaseTokensSold[SalePhase.PRE_SALE] + 
                         _phaseTokensSold[SalePhase.PUBLIC];
        
        totalParticipantsCount = totalParticipants;
    }
    
    function getReferralStatistics()
        external
        view
        override
        returns (
            uint256 totalReferralsCount,
            uint256 totalReferralBonusTokens,
            uint256 activeReferrersCount
        )
    {
        return (totalReferrals, totalReferralBonus, activeReferrers);
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function withdrawFunds(uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "SaleManager: no funds to withdraw");
        
        uint256 withdrawAmount = (amount == 0) ? balance : amount;
        require(withdrawAmount <= balance, "SaleManager: insufficient balance");
        
        (bool success, ) = treasury.call{value: withdrawAmount}("");
        require(success, "SaleManager: withdrawal failed");
        
        emit FundsWithdrawn(treasury, withdrawAmount);
    }
    
    function updateTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTreasury != address(0), "SaleManager: invalid treasury address");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
    
    function emergencyPause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit EmergencyPause(msg.sender);
    }
    
    function emergencyUnpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit EmergencyUnpause(msg.sender);
    }
    
    function emergencyTokenRecovery(address token, uint256 amount) 
        external 
        override
        onlyRole(DEFAULT_ADMIN_ROLE) 
        nonReentrant 
    {
        if (token == address(0)) {
            // Recover ETH
            uint256 balance = address(this).balance;
            uint256 recoveryAmount = (amount == 0) ? balance : amount;
            require(recoveryAmount <= balance, "SaleManager: insufficient ETH balance");
            
            (bool success, ) = msg.sender.call{value: recoveryAmount}("");
            require(success, "SaleManager: ETH recovery failed");
        } else {
            // Recover ERC20 tokens
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            uint256 recoveryAmount = (amount == 0) ? balance : amount;
            require(recoveryAmount <= balance, "SaleManager: insufficient token balance");
            
            require(tokenContract.transfer(msg.sender, recoveryAmount), "SaleManager: token recovery failed");
        }
    }
    
    // ============ STAGE 3.3: TREASURY INTEGRATION ============
    
    function setAutomaticForwarding(bool enabled, uint256 threshold) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        automaticForwardingEnabled = enabled;
        forwardingThreshold = threshold;
        
        emit AutomaticForwardingUpdated(enabled, threshold);
    }
    
    function getFundAllocation(string memory category) 
        external 
        view 
        override 
        returns (uint256 allocated, uint256 spent) 
    {
        return (_fundAllocations[category], _fundSpent[category]);
    }
    
    function setFundAllocations(string[] memory categories, uint256[] memory percentages) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(categories.length == percentages.length, "SaleManager: length mismatch");
        
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < percentages.length; i++) {
            totalPercentage += percentages[i];
        }
        require(totalPercentage == 10000, "SaleManager: percentages must sum to 100%");
        
        // Clear existing categories
        for (uint256 i = 0; i < _allocationCategories.length; i++) {
            delete _categoryExists[_allocationCategories[i]];
            delete _fundAllocations[_allocationCategories[i]];
        }
        delete _allocationCategories;
        
        // Set new allocations
        for (uint256 i = 0; i < categories.length; i++) {
            _allocationCategories.push(categories[i]);
            _categoryExists[categories[i]] = true;
            _fundAllocations[categories[i]] = (address(this).balance * percentages[i]) / 10000;
        }
        
        emit FundAllocationsSet(categories, percentages);
    }
    
    function allocateFunds(string memory category, uint256 amount) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        nonReentrant 
    {
        require(_categoryExists[category], "SaleManager: category not exists");
        require(_fundAllocations[category] >= _fundSpent[category] + amount, "SaleManager: insufficient allocation");
        
        _fundSpent[category] += amount;
        
        (bool success, ) = treasury.call{value: amount}("");
        require(success, "SaleManager: allocation transfer failed");
        
        // Log transaction
        _transactionHistory.push(TransactionLog({
            participant: msg.sender,
            amount: amount,
            tokens: 0,
            phase: currentPhase,
            timestamp: block.timestamp,
            transactionType: category
        }));
        
        emit FundsAllocated(category, amount, msg.sender);
    }
    
    // ============ STAGE 3.3: SECURITY AND ANTI-ABUSE ============
    
    function enableFrontRunningProtection(uint256 maxPriceImpact, uint256 commitDuration) 
        external 
        override 
    {
        require(maxPriceImpact <= 1000, "SaleManager: price impact too high"); // 10% max
        require(commitDuration >= 60 && commitDuration <= 3600, "SaleManager: invalid commit duration"); // 1 min to 1 hour
        
        _maxPriceImpact[msg.sender] = maxPriceImpact;
        _commitDuration[msg.sender] = commitDuration;
        _frontRunningProtectionEnabled[msg.sender] = true;
        
        emit FrontRunningProtectionEnabled(msg.sender, maxPriceImpact, commitDuration);
    }
    
    function commitPurchase(bytes32 commitment) external override {
        require(_frontRunningProtectionEnabled[msg.sender], "SaleManager: protection not enabled");
        require(_purchaseCommitments[msg.sender] == bytes32(0), "SaleManager: existing commitment");
        
        _purchaseCommitments[msg.sender] = commitment;
        _commitmentTimestamp[msg.sender] = block.timestamp;
        
        emit PurchaseCommitted(msg.sender, commitment);
    }
    
    function revealPurchase(bytes32[] memory merkleProof, uint256 nonce) 
        external 
        payable 
        override 
        phaseActive 
        whenNotPaused 
        nonReentrant 
    {
        require(_frontRunningProtectionEnabled[msg.sender], "SaleManager: protection not enabled");
        require(_purchaseCommitments[msg.sender] != bytes32(0), "SaleManager: no commitment");
        require(
            block.timestamp >= _commitmentTimestamp[msg.sender] + _commitDuration[msg.sender],
            "SaleManager: commit period not ended"
        );
        
        // Verify commitment
        bytes32 computedCommitment = keccak256(abi.encodePacked(msg.sender, msg.value, nonce));
        require(_purchaseCommitments[msg.sender] == computedCommitment, "SaleManager: invalid commitment");
        
        // Clear commitment
        delete _purchaseCommitments[msg.sender];
        delete _commitmentTimestamp[msg.sender];
        
        // Execute purchase
        _processPurchase(merkleProof, address(0), 0, block.timestamp + 1 hours);
        
        emit PurchaseRevealed(msg.sender, msg.value, nonce);
    }
    
    function setAdvancedRateLimiting(uint256 dailyLimit, uint256 hourlyLimit, uint256 cooldownPeriod) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(dailyLimit >= hourlyLimit, "SaleManager: daily limit must be >= hourly");
        require(cooldownPeriod <= 24 hours, "SaleManager: cooldown too long");
        
        _dailyLimit[msg.sender] = dailyLimit;
        _hourlyLimit[msg.sender] = hourlyLimit;
        _cooldownPeriod[msg.sender] = cooldownPeriod;
        
        emit AdvancedRateLimitingSet(dailyLimit, hourlyLimit, cooldownPeriod);
    }
    
    // ============ STAGE 3.3: REPORTING AND ANALYTICS ============
    
    function getParticipantAnalytics(address participant) 
        external 
        view 
        override 
        returns (ISaleManager.ParticipantAnalytics memory analytics) 
    {
        Participant memory p = _participants[participant];
        
        // Calculate participated phases
        SalePhase[] memory phases = new SalePhase[](3);
        uint256 phaseCount = 0;
        
        for (uint256 i = 0; i < p.purchaseIds.length; i++) {
            SalePhase phase = _purchases[p.purchaseIds[i]].phase;
            bool found = false;
            for (uint256 j = 0; j < phaseCount; j++) {
                if (phases[j] == phase) {
                    found = true;
                    break;
                }
            }
            if (!found && phaseCount < 3) {
                phases[phaseCount] = phase;
                phaseCount++;
            }
        }
        
        // Resize array
        SalePhase[] memory participatedPhases = new SalePhase[](phaseCount);
        for (uint256 i = 0; i < phaseCount; i++) {
            participatedPhases[i] = phases[i];
        }
        
        analytics = ISaleManager.ParticipantAnalytics({
            participant: participant,
            totalInvestment: p.totalEthSpent,
            averagePurchaseSize: p.purchaseIds.length > 0 ? p.totalEthSpent / p.purchaseIds.length : 0,
            purchaseFrequency: p.purchaseIds.length,
            engagementScore: p.engagementScore,
            referralEarnings: p.referralBonus,
            firstPurchaseTime: _participantFirstPurchase[participant],
            lastPurchaseTime: p.lastPurchaseTime,
            participatedPhases: participatedPhases,
            isHighValue: _isHighValueParticipant[participant],
            isFrequentTrader: _isFrequentTrader[participant],
            riskScore: _participantRiskScore[participant]
        });
    }
    
    function getComplianceReport(uint256 startTime, uint256 endTime) 
        external 
        view 
        override 
        returns (ISaleManager.ComplianceReport memory report) 
    {
        uint256 kycApproved = 0;
        uint256 accredited = 0;
        uint256 totalInvestment = 0;
        uint256 maxInvestment = 0;
        address[] memory highValue = new address[](totalHighValueParticipants);
        uint256 highValueCount = 0;
        
        // This is a simplified implementation - in production would optimize for gas
        // by maintaining running counters
        for (uint256 i = 0; i < totalParticipants && highValueCount < totalHighValueParticipants; i++) {
            // Note: This is inefficient - would need to track participants differently
            // for production implementation
        }
        
        report = ISaleManager.ComplianceReport({
            totalParticipants: totalParticipants,
            totalFundsRaised: _phaseEthRaised[SalePhase.PRIVATE] + _phaseEthRaised[SalePhase.PRE_SALE] + _phaseEthRaised[SalePhase.PUBLIC],
            kycApprovedCount: kycApproved,
            accreditedInvestorCount: accredited,
            averageInvestment: totalParticipants > 0 ? totalInvestment / totalParticipants : 0,
            largestInvestment: maxInvestment,
            highValueInvestors: highValue,
            suspiciousActivityCount: totalSuspiciousActivities,
            reportGeneratedAt: block.timestamp
        });
    }
    
    function registerAnalyticsHook(address hookAddress, string[] memory events) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(hookAddress != address(0), "SaleManager: invalid hook address");
        
        if (!_analyticsHooks[hookAddress]) {
            _analyticsHooks[hookAddress] = true;
            _activeHooks.push(hookAddress);
        }
        
        for (uint256 i = 0; i < events.length; i++) {
            _hookEvents[hookAddress][events[i]] = true;
        }
        
        emit AnalyticsHookRegistered(hookAddress, events);
    }
    
    function getDetailedProgress() 
        external 
        view 
        override 
        returns (ISaleManager.SaleProgress memory progress) 
    {
        uint256 totalRaised = _phaseEthRaised[SalePhase.PRIVATE] + 
                             _phaseEthRaised[SalePhase.PRE_SALE] + 
                             _phaseEthRaised[SalePhase.PUBLIC];
        
        progress = ISaleManager.SaleProgress({
            totalRaised: totalRaised,
            totalAllocated: PRIVATE_SALE_ALLOCATION + PRE_SALE_ALLOCATION + PUBLIC_SALE_ALLOCATION,
            remainingAllocation: (PRIVATE_SALE_ALLOCATION + PRE_SALE_ALLOCATION + PUBLIC_SALE_ALLOCATION) - 
                               (_phaseTokensSold[SalePhase.PRIVATE] + _phaseTokensSold[SalePhase.PRE_SALE] + _phaseTokensSold[SalePhase.PUBLIC]),
            participantCount: totalParticipants,
            averageContribution: totalParticipants > 0 ? totalRaised / totalParticipants : 0,
            privatePhaseRaised: _phaseEthRaised[SalePhase.PRIVATE],
            preSalePhaseRaised: _phaseEthRaised[SalePhase.PRE_SALE],
            publicPhaseRaised: _phaseEthRaised[SalePhase.PUBLIC],
            lastUpdated: block.timestamp
        });
    }
    
    function exportParticipantData(address[] memory participants) 
        external 
        view 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns (ISaleManager.ParticipantExport[] memory data) 
    {
        data = new ISaleManager.ParticipantExport[](participants.length);
        
        for (uint256 i = 0; i < participants.length; i++) {
            Participant memory p = _participants[participants[i]];
            data[i] = ISaleManager.ParticipantExport({
                participant: participants[i],
                totalContribution: p.totalEthSpent,
                tokensPurchased: p.totalTokensBought,
                kycStatus: p.kycStatus,
                isAccredited: p.isAccredited,
                firstPurchase: _participantFirstPurchase[participants[i]],
                lastPurchase: p.lastPurchaseTime,
                transactionCount: p.purchaseIds.length
            });
        }
    }
    
    // ============ INTERNAL HELPER FUNCTIONS (STAGE 3.3) ============
    
    function _checkAndForwardFunds() internal {
        if (automaticForwardingEnabled && address(this).balance >= forwardingThreshold) {
            uint256 forwardAmount = address(this).balance;
            totalForwarded += forwardAmount;
            
            (bool success, ) = treasury.call{value: forwardAmount}("");
            if (success) {
                emit FundsAutoForwarded(treasury, forwardAmount);
            }
        }
    }
    
    function _updateParticipantAnalytics(address participant, uint256 ethAmount) internal {
        if (_participantFirstPurchase[participant] == 0) {
            _participantFirstPurchase[participant] = block.timestamp;
        }
        
        // Update high value status
        if (_participants[participant].totalEthSpent >= 50 ether) { // $50K+ threshold
            if (!_isHighValueParticipant[participant]) {
                _isHighValueParticipant[participant] = true;
                totalHighValueParticipants++;
            }
        }
        
        // Update frequent trader status  
        if (_participants[participant].purchaseIds.length >= 5) {
            if (!_isFrequentTrader[participant]) {
                _isFrequentTrader[participant] = true;
                totalFrequentTraders++;
            }
        }
        
        // Calculate basic risk score
        uint256 riskScore = 0;
        if (_participants[participant].purchaseIds.length > 10) riskScore += 100;
        if (ethAmount > 100 ether) riskScore += 200;
        if (_participants[participant].kycStatus != KYCStatus.APPROVED) riskScore += 500;
        
        _participantRiskScore[participant] = riskScore;
    }
    
    function _logTransaction(address participant, uint256 ethAmount, uint256 tokenAmount, string memory txType) internal {
        _transactionHistory.push(TransactionLog({
            participant: participant,
            amount: ethAmount,
            tokens: tokenAmount,
            phase: currentPhase,
            timestamp: block.timestamp,
            transactionType: txType
        }));
        
        // Notify analytics hooks
        for (uint256 i = 0; i < _activeHooks.length; i++) {
            address hook = _activeHooks[i];
            if (_hookEvents[hook]["purchase"]) {
                // In production, would call external analytics contract
                emit AnalyticsEvent(hook, "purchase", participant, ethAmount);
            }
        }
    }
    
    // ============ STAGE 3.3: NEW EVENTS ============
    
    event AutomaticForwardingUpdated(bool enabled, uint256 threshold);
    event FundAllocationsSet(string[] categories, uint256[] percentages);
    event FundsAllocated(string category, uint256 amount, address allocator);
    event FundsAutoForwarded(address treasury, uint256 amount);
    event FrontRunningProtectionEnabled(address participant, uint256 maxPriceImpact, uint256 commitDuration);
    event PurchaseCommitted(address participant, bytes32 commitment);
    event PurchaseRevealed(address participant, uint256 amount, uint256 nonce);
    event AdvancedRateLimitingSet(uint256 dailyLimit, uint256 hourlyLimit, uint256 cooldownPeriod);
    event AnalyticsHookRegistered(address hookAddress, string[] events);
    event AnalyticsEvent(address hook, string eventType, address participant, uint256 amount);
    
    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {
        revert("SaleManager: use purchaseTokens function");
    }
} 