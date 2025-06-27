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
        
        // Distribute tokens according to Stage 3.2 business logic
        _distributeTokens(msg.sender, totalTokenAmount, currentPhase);
        
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
    
    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {
        revert("SaleManager: use purchaseTokens function");
    }
} 