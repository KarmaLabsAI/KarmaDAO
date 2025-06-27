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
     * @dev Calculate token amount for given ETH amount in current phase
     * @param ethAmount ETH amount to convert
     * @return tokenAmount Equivalent token amount
     */
    function calculateTokenAmount(uint256 ethAmount) external view returns (uint256 tokenAmount);
    
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
} 