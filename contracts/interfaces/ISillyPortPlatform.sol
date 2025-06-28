// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISillyPortPlatform
 * @dev Interface for SillyPort Platform Integration
 * Stage 8.2 - SillyPort Integration Requirements
 */
interface ISillyPortPlatform {
    
    // ============ ENUMS ============
    
    enum SubscriptionTier {
        FREE,               // Free tier with limited features
        BASIC,              // Basic subscription - $5/month
        PREMIUM,            // Premium subscription - $15/month  
        ENTERPRISE          // Enterprise subscription - $50/month
    }
    
    enum ContentType {
        AI_CHAT_SESSION,    // AI chat sessions
        INFT_METADATA,      // iNFT metadata
        USER_CONTENT,       // User generated content
        PREMIUM_FEATURE,    // Premium feature access
        API_USAGE          // API usage tracking
    }
    
    enum AccessLevel {
        PUBLIC,             // Public access
        SUBSCRIBER_ONLY,    // Requires active subscription
        PREMIUM_ONLY,       // Requires premium subscription
        TOKEN_HOLDER_ONLY   // Requires KARMA token holdings
    }
    
    // ============ STRUCTS ============
    
    struct SubscriptionInfo {
        SubscriptionTier tier;
        uint256 startTime;
        uint256 endTime;
        uint256 monthlyFee;
        bool isActive;
        uint256 tokensUsed;
        uint256 tokensLimit;
        uint256 apiCallsUsed;
        uint256 apiCallsLimit;
    }
    
    struct iNFTMintRequest {
        bytes32 requestId;
        address requester;
        string prompt;
        ContentType contentType;
        uint256 karmaPayment;
        uint256 timestamp;
        string aiModel;
        bool isCompleted;
        string metadataURI;
        uint256 tokenId;
    }
    
    struct AIChatSession {
        bytes32 sessionId;
        address user;
        uint256 startTime;
        uint256 endTime;
        uint256 messagesCount;
        uint256 tokensUsed;
        uint256 karmaSpent;
        bool isActive;
        ContentType sessionType;
    }
    
    struct UserGeneratedContent {
        bytes32 contentId;
        address creator;
        ContentType contentType;
        string contentURI;
        uint256 timestamp;
        uint256 viewCount;
        uint256 revenueGenerated;
        AccessLevel accessLevel;
        uint256 karmaRequired;
        bool isMonetized;
    }
    
    struct PremiumFeature {
        uint256 featureId;
        string featureName;
        AccessLevel accessLevel;
        uint256 karmaRequired;
        uint256 usageCount;
        bool isActive;
        SubscriptionTier minTier;
    }
    
    // ============ EVENTS ============
    
    event SubscriptionCreated(address indexed user, SubscriptionTier tier, uint256 monthlyFee);
    event SubscriptionRenewed(address indexed user, SubscriptionTier tier, uint256 feeAmount);
    event SubscriptionUpgraded(address indexed user, SubscriptionTier oldTier, SubscriptionTier newTier);
    event SubscriptionCancelled(address indexed user, SubscriptionTier tier);
    
    event INFTMintRequested(bytes32 indexed requestId, address indexed requester, string prompt, uint256 karmaPayment);
    event INFTMinted(bytes32 indexed requestId, address indexed requester, uint256 tokenId, string metadataURI);
    
    event AIChatSessionStarted(bytes32 indexed sessionId, address indexed user, ContentType sessionType);
    event AIChatSessionEnded(bytes32 indexed sessionId, address indexed user, uint256 tokensUsed, uint256 karmaSpent);
    
    event UserContentCreated(bytes32 indexed contentId, address indexed creator, ContentType contentType, string contentURI);
    event UserContentMonetized(bytes32 indexed contentId, address indexed creator, uint256 revenueAmount);
    
    event PremiumFeatureAccessed(address indexed user, uint256 featureId, uint256 karmaSpent);
    event FeesCollected(address indexed user, uint256 amount, ContentType contentType);
    
    // ============ FUNCTIONS ============
    
    function requestINFTMint(string calldata prompt, ContentType contentType, string calldata aiModel) external payable returns (bytes32 requestId);
    function completeINFTMint(bytes32 requestId, string calldata metadataURI, uint256 tokenId) external;
    function getINFTMintRequest(bytes32 requestId) external view returns (iNFTMintRequest memory request);
    
    function startAIChatSession(ContentType sessionType) external returns (bytes32 sessionId);
    function processAIChatMessage(bytes32 sessionId, string calldata message, uint256 tokensUsed) external returns (uint256 karmaSpent);
    function endAIChatSession(bytes32 sessionId) external;
    function getAIChatSession(bytes32 sessionId) external view returns (AIChatSession memory session);
    
    function accessPremiumFeature(uint256 featureId) external payable returns (uint256 karmaSpent);
    function checkPremiumAccess(address user, uint256 featureId) external view returns (bool hasAccess);
    function getPremiumFeature(uint256 featureId) external view returns (PremiumFeature memory feature);
    
    function createUserContent(ContentType contentType, string calldata contentURI, AccessLevel accessLevel, uint256 karmaRequired) external returns (bytes32 contentId);
    function accessUserContent(bytes32 contentId) external payable returns (string memory contentURI);
    function setContentMonetization(bytes32 contentId, bool isMonetized) external;
    function getUserContent(bytes32 contentId) external view returns (UserGeneratedContent memory content);
    
    function subscribe(SubscriptionTier tier) external payable returns (bool success);
    function renewSubscription(SubscriptionTier tier) external payable returns (bool success);
    function upgradeSubscription(SubscriptionTier newTier) external payable returns (bool success);
    function cancelSubscription() external returns (bool success);
    function getSubscription(address user) external view returns (SubscriptionInfo memory subscription);
    function hasActiveSubscription(address user, SubscriptionTier tier) external view returns (bool hasAccess);
    
    function getPlatformStats() external view returns (uint256 totalUsers, uint256 activeSubscriptions, uint256 totalRevenue, uint256 inftsMinted);
    function getUserStats(address user) external view returns (uint256 chatSessions, uint256 inftsMinted, uint256 contentCreated, uint256 karmaSpent);
}
