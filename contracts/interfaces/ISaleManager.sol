// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISaleManager
 * @dev Interface for the SaleManager contract implementing multi-phase token sales
 * 
 * This interface defines the standard sale functionality including:
 * - Multi-phase sale management (Private, Pre-Sale, Public)
 * - Purchase processing with ETH to KARMA conversion
 * - Whitelist verification using Merkle trees
 * - KYC integration and access controls
 * - Community engagement scoring (Stage 3.2)
 * - Referral system for pre-sale (Stage 3.2)
 * - Uniswap V3 integration for public sale (Stage 3.2)
 */
interface ISaleManager {
    
    // ============ ENUMS ============
    
    /**
     * @dev Sale phase enumeration
     */
    enum SalePhase {
        NOT_STARTED,    // Sale not yet started
        PRIVATE,        // Private sale phase
        PRE_SALE,       // Pre-sale phase
        PUBLIC,         // Public sale phase
        ENDED           // Sale ended
    }
    
    /**
     * @dev KYC status enumeration
     */
    enum KYCStatus {
        PENDING,        // KYC verification pending
        APPROVED,       // KYC approved
        REJECTED        // KYC rejected
    }
    
    // ============ STRUCTS ============
    
    /**
     * @dev Phase configuration structure
     */
    struct PhaseConfig {
        uint256 price;              // Token price in wei per token
        uint256 minPurchase;        // Minimum purchase amount in wei
        uint256 maxPurchase;        // Maximum purchase amount in wei
        uint256 hardCap;            // Maximum ETH to raise in phase
        uint256 tokenAllocation;    // Maximum tokens allocated for phase
        uint256 startTime;          // Phase start timestamp
        uint256 endTime;            // Phase end timestamp
        bool whitelistRequired;     // Whether whitelist is required
        bool kycRequired;           // Whether KYC is required
        bytes32 merkleRoot;         // Merkle root for whitelist verification
    }
    
    /**
     * @dev Purchase record structure
     */
    struct Purchase {
        address buyer;              // Buyer address
        uint256 ethAmount;          // ETH amount spent
        uint256 tokenAmount;        // Tokens purchased
        SalePhase phase;            // Phase when purchase was made
        uint256 timestamp;          // Purchase timestamp
        bool vested;                // Whether tokens are vested
        address referrer;           // Referrer address (Stage 3.2)
        uint256 bonusTokens;        // Bonus tokens from referral/engagement (Stage 3.2)
    }
    
    /**
     * @dev Participant information
     */
    struct Participant {
        uint256 totalEthSpent;      // Total ETH spent across all phases
        uint256 totalTokensBought;  // Total tokens purchased
        KYCStatus kycStatus;        // KYC verification status
        bool isAccredited;          // Whether participant is accredited investor
        uint256 lastPurchaseTime;   // Timestamp of last purchase
        uint256[] purchaseIds;      // Array of purchase IDs
        uint256 engagementScore;    // Community engagement score (Stage 3.2)
        uint256 referralCount;      // Number of successful referrals (Stage 3.2)
        uint256 referralBonus;      // Total referral bonus earned (Stage 3.2)
        bool isPrivateSaleParticipant; // Eligible for pre-sale referral system (Stage 3.2)
    }
    
    /**
     * @dev Community engagement data structure (Stage 3.2)
     */
    struct EngagementData {
        uint256 discordActivity;    // Discord engagement score
        uint256 twitterActivity;    // Twitter engagement score  
        uint256 githubActivity;     // GitHub contribution score
        uint256 forumActivity;      // Forum participation score
        uint256 lastUpdated;       // Last score update timestamp
        bool verified;              // Whether engagement is verified
    }
    
    /**
     * @dev Liquidity pool configuration for public sale (Stage 3.2)
     */
    struct LiquidityConfig {
        address uniswapV3Factory;   // Uniswap V3 factory address
        address uniswapV3Router;    // Uniswap V3 router address
        address wethAddress;        // WETH token address
        uint24 poolFee;             // Pool fee tier (500, 3000, 10000)
        uint256 liquidityEth;       // ETH amount for initial liquidity
        uint256 liquidityTokens;    // Token amount for initial liquidity
        int24 tickLower;            // Lower tick for liquidity range
        int24 tickUpper;            // Upper tick for liquidity range
    }
    
    // ============ EVENTS ============
    
    event SalePhaseStarted(SalePhase indexed phase, uint256 startTime, uint256 endTime);
    event SalePhaseEnded(SalePhase indexed phase, uint256 endTime);
    event PhaseConfigUpdated(SalePhase indexed phase, uint256 price, uint256 hardCap);
    
    event TokenPurchase(
        address indexed buyer,
        uint256 indexed purchaseId,
        SalePhase indexed phase,
        uint256 ethAmount,
        uint256 tokenAmount,
        bool vested
    );
    
    event WhitelistUpdated(SalePhase indexed phase, bytes32 merkleRoot);
    event KYCStatusUpdated(address indexed participant, KYCStatus status);
    
    event FundsWithdrawn(address indexed to, uint256 amount);
    event EmergencyPause(address indexed admin);
    event EmergencyUnpause(address indexed admin);
    
    // Stage 3.2 Events
    event EngagementScoreUpdated(address indexed participant, uint256 oldScore, uint256 newScore);
    event ReferralRegistered(address indexed referrer, address indexed referee, uint256 bonus);
    event LiquidityPoolCreated(address indexed poolAddress, uint256 ethAmount, uint256 tokenAmount);
    event MEVProtectionEnabled(address indexed participant, uint256 maxSlippage);
    
    // ============ PHASE MANAGEMENT ============
    
    /**
     * @dev Start a specific sale phase
     * @param phase Phase to start
     * @param config Phase configuration
     */
    function startSalePhase(SalePhase phase, PhaseConfig memory config) external;
    
    /**
     * @dev End the current sale phase
     */
    function endCurrentPhase() external;
    
    /**
     * @dev Update phase configuration (only before phase starts)
     * @param phase Phase to update
     * @param config New configuration
     */
    function updatePhaseConfig(SalePhase phase, PhaseConfig memory config) external;
    
    /**
     * @dev Get current active sale phase
     * @return phase Current sale phase
     */
    function getCurrentPhase() external view returns (SalePhase phase);
    
    /**
     * @dev Get phase configuration
     * @param phase Phase to query
     * @return config Phase configuration
     */
    function getPhaseConfig(SalePhase phase) external view returns (PhaseConfig memory config);
    
    // ============ PURCHASE PROCESSING ============
    
    /**
     * @dev Purchase tokens with ETH
     * @param merkleProof Merkle proof for whitelist verification (if required)
     */
    function purchaseTokens(bytes32[] memory merkleProof) external payable;
    
    /**
     * @dev Purchase tokens with referral (Stage 3.2)
     * @param merkleProof Merkle proof for whitelist verification
     * @param referrer Address of referring participant (must be private sale participant)
     */
    function purchaseTokensWithReferral(bytes32[] memory merkleProof, address referrer) external payable;
    
    /**
     * @dev Calculate token amount for given ETH amount in current phase
     * @param ethAmount ETH amount to convert
     * @return tokenAmount Equivalent token amount
     */
    function calculateTokenAmount(uint256 ethAmount) external view returns (uint256 tokenAmount);
    
    /**
     * @dev Calculate bonus tokens from engagement and referrals (Stage 3.2)
     * @param participant Address of participant
     * @param baseTokens Base token amount from purchase
     * @return bonusTokens Additional bonus tokens
     */
    function calculateBonusTokens(address participant, uint256 baseTokens) external view returns (uint256 bonusTokens);
    
    /**
     * @dev Get purchase details
     * @param purchaseId ID of the purchase
     * @return purchase Purchase details
     */
    function getPurchase(uint256 purchaseId) external view returns (Purchase memory purchase);
    
    // ============ WHITELIST AND ACCESS CONTROL ============
    
    /**
     * @dev Update whitelist for a phase
     * @param phase Phase to update
     * @param merkleRoot New Merkle root
     */
    function updateWhitelist(SalePhase phase, bytes32 merkleRoot) external;
    
    /**
     * @dev Verify whitelist eligibility
     * @param participant Address to verify
     * @param phase Phase to check
     * @param merkleProof Merkle proof
     * @return eligible Whether participant is whitelisted
     */
    function verifyWhitelist(
        address participant,
        SalePhase phase,
        bytes32[] memory merkleProof
    ) external view returns (bool eligible);
    
    /**
     * @dev Update KYC status for participant
     * @param participant Address of participant
     * @param status New KYC status
     */
    function updateKYCStatus(address participant, KYCStatus status) external;
    
    /**
     * @dev Set accredited investor status
     * @param participant Address of participant
     * @param isAccredited Whether participant is accredited
     */
    function setAccreditedStatus(address participant, bool isAccredited) external;
    
    // ============ STAGE 3.2: COMMUNITY ENGAGEMENT SCORING ============
    
    /**
     * @dev Update community engagement score for participant
     * @param participant Address of participant
     * @param engagementData New engagement data
     */
    function updateEngagementScore(address participant, EngagementData memory engagementData) external;
    
    /**
     * @dev Get engagement data for participant
     * @param participant Address to query
     * @return data Engagement data
     */
    function getEngagementData(address participant) external view returns (EngagementData memory data);
    
    /**
     * @dev Calculate total engagement score
     * @param participant Address to calculate for
     * @return score Total engagement score (0-10000 basis points)
     */
    function calculateEngagementScore(address participant) external view returns (uint256 score);
    
    // ============ STAGE 3.2: REFERRAL SYSTEM ============
    
    /**
     * @dev Register referral relationship
     * @param referrer Address of referrer (must be private sale participant)
     * @param referee Address of referee
     */
    function registerReferral(address referrer, address referee) external;
    
    /**
     * @dev Get referral bonus rate for referrer
     * @param referrer Address of referrer
     * @return bonusRate Bonus rate in basis points (e.g., 500 = 5%)
     */
    function getReferralBonusRate(address referrer) external view returns (uint256 bonusRate);
    
    /**
     * @dev Get referees for a referrer
     * @param referrer Address of referrer
     * @return referees Array of referee addresses
     */
    function getReferees(address referrer) external view returns (address[] memory referees);
    
    // ============ STAGE 3.2: UNISWAP V3 INTEGRATION ============
    
    /**
     * @dev Configure Uniswap V3 liquidity pool for public sale
     * @param config Liquidity pool configuration
     */
    function configureLiquidityPool(LiquidityConfig memory config) external;
    
    /**
     * @dev Create Uniswap V3 liquidity pool (called automatically at public sale start)
     * @return poolAddress Address of created pool
     */
    function createLiquidityPool() external returns (address poolAddress);
    
    /**
     * @dev Get liquidity pool configuration
     * @return config Current liquidity configuration
     */
    function getLiquidityConfig() external view returns (LiquidityConfig memory config);
    
    // ============ STAGE 3.2: MEV PROTECTION ============
    
    /**
     * @dev Enable MEV protection for participant
     * @param maxSlippageBps Maximum allowed slippage in basis points
     */
    function enableMEVProtection(uint256 maxSlippageBps) external;
    
    /**
     * @dev Purchase tokens with MEV protection (public sale only)
     * @param merkleProof Merkle proof for whitelist verification
     * @param minTokensOut Minimum tokens expected (slippage protection)
     * @param deadline Transaction deadline
     */
    function purchaseTokensWithMEVProtection(
        bytes32[] memory merkleProof,
        uint256 minTokensOut,
        uint256 deadline
    ) external payable;
    
    // ============ PARTICIPANT MANAGEMENT ============
    
    /**
     * @dev Get participant information
     * @param participant Address to query
     * @return info Participant information
     */
    function getParticipant(address participant) external view returns (Participant memory info);
    
    /**
     * @dev Get participant's purchases
     * @param participant Address to query
     * @return purchaseIds Array of purchase IDs
     */
    function getParticipantPurchases(address participant) 
        external 
        view 
        returns (uint256[] memory purchaseIds);
    
    // ============ ANALYTICS AND REPORTING ============
    
    /**
     * @dev Get sale statistics for a phase
     * @param phase Phase to query
     * @return totalEthRaised Total ETH raised in phase
     * @return totalTokensSold Total tokens sold in phase
     * @return participantCount Number of participants in phase
     */
    function getPhaseStatistics(SalePhase phase) 
        external 
        view 
        returns (
            uint256 totalEthRaised,
            uint256 totalTokensSold,
            uint256 participantCount
        );
    
    /**
     * @dev Get overall sale statistics
     * @return totalEthRaised Total ETH raised across all phases
     * @return totalTokensSold Total tokens sold across all phases
     * @return totalParticipants Total unique participants
     */
    function getOverallStatistics() 
        external 
        view 
        returns (
            uint256 totalEthRaised,
            uint256 totalTokensSold,
            uint256 totalParticipants
        );
    
    /**
     * @dev Get referral statistics (Stage 3.2)
     * @return totalReferrals Total number of referrals
     * @return totalReferralBonus Total bonus tokens distributed
     * @return activeReferrers Number of active referrers
     */
    function getReferralStatistics()
        external
        view
        returns (
            uint256 totalReferrals,
            uint256 totalReferralBonus,
            uint256 activeReferrers
        );
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Withdraw raised funds to treasury
     * @param amount Amount to withdraw (0 for all)
     */
    function withdrawFunds(uint256 amount) external;
    
    /**
     * @dev Emergency pause all sale operations
     */
    function emergencyPause() external;
    
    /**
     * @dev Emergency unpause sale operations
     */
    function emergencyUnpause() external;
    
    /**
     * @dev Emergency token recovery (admin only)
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to recover
     */
    function emergencyTokenRecovery(address token, uint256 amount) external;
    
    // ============ STAGE 3.2: PHASE CONFIGURATION HELPERS ============
    
    /**
     * @dev Configure private sale with exact business parameters
     * @param startTime When to start private sale
     * @param merkleRoot Whitelist for accredited investors
     */
    function configurePrivateSale(uint256 startTime, bytes32 merkleRoot) external;
    
    /**
     * @dev Configure pre-sale with exact business parameters
     * @param startTime When to start pre-sale
     * @param merkleRoot Whitelist for pre-sale participants
     */
    function configurePreSale(uint256 startTime, bytes32 merkleRoot) external;
    
    /**
     * @dev Configure public sale with exact business parameters
     * @param startTime When to start public sale
     * @param liquidityConfig Uniswap V3 configuration
     */
    function configurePublicSale(uint256 startTime, LiquidityConfig memory liquidityConfig) external;
} 