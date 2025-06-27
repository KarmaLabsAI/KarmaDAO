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
 */
contract SaleManager is ISaleManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ CONSTANTS ============
    
    // Role definitions
    bytes32 public constant SALE_MANAGER_ROLE = keccak256("SALE_MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant WHITELIST_MANAGER_ROLE = keccak256("WHITELIST_MANAGER_ROLE");
    
    // Precision for price calculations (18 decimals)
    uint256 private constant PRICE_PRECISION = 1e18;
    
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
    
    // Purchase tracking
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
    }
    
    // ============ PHASE MANAGEMENT ============
    
    function startSalePhase(SalePhase phase, PhaseConfig memory config) 
        external 
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
    
    function endCurrentPhase() external onlySaleManager {
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
    
    function getCurrentPhase() external view returns (SalePhase) {
        return currentPhase;
    }
    
    function getPhaseConfig(SalePhase phase) external view returns (PhaseConfig memory) {
        return _phaseConfigs[phase];
    }
    
    // ============ PURCHASE PROCESSING ============
    
    function purchaseTokens(bytes32[] memory merkleProof) 
        external 
        payable 
        phaseActive 
        whenNotPaused 
        nonReentrant 
    {
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
        
        // Calculate token amount
        uint256 tokenAmount = calculateTokenAmount(msg.value);
        require(
            _phaseTokensSold[currentPhase] + tokenAmount <= config.tokenAllocation,
            "SaleManager: token allocation exceeded"
        );
        
        // Create purchase record
        uint256 purchaseId = totalPurchases++;
        Purchase storage purchase = _purchases[purchaseId];
        purchase.buyer = msg.sender;
        purchase.ethAmount = msg.value;
        purchase.tokenAmount = tokenAmount;
        purchase.phase = currentPhase;
        purchase.timestamp = block.timestamp;
        
        // Determine if tokens should be vested (private sale only)
        bool shouldVest = (currentPhase == SalePhase.PRIVATE);
        purchase.vested = shouldVest;
        
        // Update participant data
        Participant storage participant = _participants[msg.sender];
        if (!_hasParticipated[msg.sender]) {
            _hasParticipated[msg.sender] = true;
            totalParticipants++;
            _phaseParticipants[currentPhase]++;
            _phaseParticipantList[currentPhase].push(msg.sender);
            participant.kycStatus = KYCStatus.PENDING; // Initialize if new participant
        }
        
        participant.totalEthSpent += msg.value;
        participant.totalTokensBought += tokenAmount;
        participant.lastPurchaseTime = block.timestamp;
        participant.purchaseIds.push(purchaseId);
        
        // Update phase statistics
        _phaseEthRaised[currentPhase] += msg.value;
        _phaseTokensSold[currentPhase] += tokenAmount;
        
        // Update rate limiting
        _lastPurchaseTime[msg.sender] = block.timestamp;
        
        // Distribute tokens
        if (shouldVest) {
            // Mint tokens to this contract first
            karmaToken.mint(address(this), tokenAmount);
            
            // Approve VestingVault to take tokens
            karmaToken.approve(address(vestingVault), tokenAmount);
            
            // Create vesting schedule (6-month linear for private sale)
            vestingVault.createVestingSchedule(
                msg.sender,
                tokenAmount,
                block.timestamp, // Start immediately
                0, // No cliff for private sale
                180 days, // 6 months
                "PRIVATE_SALE"
            );
        } else {
            // Direct token distribution for pre-sale and public sale
            if (currentPhase == SalePhase.PRE_SALE) {
                // 50% immediate, 50% vested for pre-sale
                uint256 immediateAmount = tokenAmount / 2;
                uint256 vestedAmount = tokenAmount - immediateAmount;
                
                // Mint immediate tokens directly to buyer
                karmaToken.mint(msg.sender, immediateAmount);
                
                // Mint vested tokens to this contract and create vesting schedule
                karmaToken.mint(address(this), vestedAmount);
                karmaToken.approve(address(vestingVault), vestedAmount);
                
                vestingVault.createVestingSchedule(
                    msg.sender,
                    vestedAmount,
                    block.timestamp,
                    0, // No cliff
                    90 days, // 3 months for pre-sale vesting
                    "PRE_SALE"
                );
            } else {
                // 100% immediate for public sale
                karmaToken.mint(msg.sender, tokenAmount);
            }
        }
        
        emit TokenPurchase(msg.sender, purchaseId, currentPhase, msg.value, tokenAmount, shouldVest);
    }
    
    function calculateTokenAmount(uint256 ethAmount) public view returns (uint256) {
        if (currentPhase == SalePhase.NOT_STARTED || currentPhase == SalePhase.ENDED) {
            return 0;
        }
        
        PhaseConfig memory config = _phaseConfigs[currentPhase];
        return (ethAmount * PRICE_PRECISION) / config.price;
    }
    
    function getPurchase(uint256 purchaseId) external view returns (Purchase memory) {
        require(purchaseId < totalPurchases, "SaleManager: invalid purchase ID");
        return _purchases[purchaseId];
    }
    
    // ============ WHITELIST AND ACCESS CONTROL ============
    
    function updateWhitelist(SalePhase phase, bytes32 merkleRoot) 
        external 
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
    ) public view returns (bool) {
        bytes32 merkleRoot = _phaseConfigs[phase].merkleRoot;
        if (merkleRoot == bytes32(0)) {
            return true; // No whitelist required
        }
        
        bytes32 leaf = keccak256(abi.encodePacked(participant));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
    
    function updateKYCStatus(address participant, KYCStatus status) 
        external 
        onlyKYCManager 
    {
        _participants[participant].kycStatus = status;
        emit KYCStatusUpdated(participant, status);
    }
    
    function setAccreditedStatus(address participant, bool isAccredited) 
        external 
        onlyKYCManager 
    {
        _participants[participant].isAccredited = isAccredited;
    }
    
    // ============ PARTICIPANT MANAGEMENT ============
    
    function getParticipant(address participant) external view returns (Participant memory) {
        return _participants[participant];
    }
    
    function getParticipantPurchases(address participant) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return _participants[participant].purchaseIds;
    }
    
    // ============ ANALYTICS AND REPORTING ============
    
    function getPhaseStatistics(SalePhase phase) 
        external 
        view 
        returns (uint256 totalEthRaised, uint256 totalTokensSold, uint256 participantCount) 
    {
        return (_phaseEthRaised[phase], _phaseTokensSold[phase], _phaseParticipants[phase]);
    }
    
    function getOverallStatistics() 
        external 
        view 
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
    
    // ============ ADMIN FUNCTIONS ============
    
    function withdrawFunds(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
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
    
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit EmergencyPause(msg.sender);
    }
    
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit EmergencyUnpause(msg.sender);
    }
    
    function emergencyTokenRecovery(address token, uint256 amount) 
        external 
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