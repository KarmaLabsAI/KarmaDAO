// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../../../interfaces/ISillyPortPlatform.sol";
import "../../../interfaces/IAIInferencePayment.sol";
import "../../../interfaces/IMetadataStorage.sol";
import "../../../interfaces/IPlatformFeeRouter.sol";

/**
 * @title SillyPortPlatform
 * @dev Implementation of SillyPort Platform Integration
 * Stage 8.2 - SillyPort Integration Implementation
 */
contract SillyPortPlatform is ISillyPortPlatform, ERC721, ERC721URIStorage, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant CONTENT_MODERATOR_ROLE = keccak256("CONTENT_MODERATOR_ROLE");
    bytes32 public constant AI_EXECUTOR_ROLE = keccak256("AI_EXECUTOR_ROLE");
    bytes32 public constant SUBSCRIPTION_MANAGER_ROLE = keccak256("SUBSCRIPTION_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant BASIC_MONTHLY_FEE = 5 * 1e6; // $5 in USD (6 decimal precision)
    uint256 public constant PREMIUM_MONTHLY_FEE = 15 * 1e6; // $15 in USD
    uint256 public constant ENTERPRISE_MONTHLY_FEE = 50 * 1e6; // $50 in USD
    
    uint256 public constant FREE_TOKENS_LIMIT = 1000;
    uint256 public constant BASIC_TOKENS_LIMIT = 10000;
    uint256 public constant PREMIUM_TOKENS_LIMIT = 50000;
    uint256 public constant ENTERPRISE_TOKENS_LIMIT = 200000;
    
    uint256 public constant FREE_API_LIMIT = 100;
    uint256 public constant BASIC_API_LIMIT = 1000;
    uint256 public constant PREMIUM_API_LIMIT = 10000;
    uint256 public constant ENTERPRISE_API_LIMIT = 50000;
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    IERC20 public karmaToken;
    IAIInferencePayment public aiInferencePayment;
    IMetadataStorage public metadataStorage;
    IPlatformFeeRouter public feeRouter;
    
    // Counters
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _requestIdCounter;
    Counters.Counter private _sessionIdCounter;
    Counters.Counter private _contentIdCounter;
    
    // Subscriptions
    mapping(address => SubscriptionInfo) public subscriptions;
    mapping(SubscriptionTier => uint256) public tierMonthlyfees;
    mapping(SubscriptionTier => uint256) public tierTokenLimits;
    mapping(SubscriptionTier => uint256) public tierApiLimits;
    
    // iNFT minting
    mapping(bytes32 => iNFTMintRequest) private _mintRequests;
    mapping(address => bytes32[]) public requestsByUser;
    mapping(ContentType => bytes32[]) public requestsByType;
    
    // AI chat sessions
    mapping(bytes32 => AIChatSession) private _chatSessions;
    mapping(address => bytes32[]) public sessionsByUser;
    mapping(ContentType => bytes32[]) public sessionsByType;
    
    // User generated content
    mapping(bytes32 => UserGeneratedContent) private _userContent;
    mapping(address => bytes32[]) public contentByCreator;
    mapping(AccessLevel => bytes32[]) public contentByAccessLevel;
    
    // Premium features
    mapping(uint256 => PremiumFeature) public premiumFeatures;
    mapping(address => mapping(uint256 => bool)) public userFeatureAccess;
    uint256 public nextFeatureId;
    
    // Platform statistics
    uint256 public totalUsers;
    uint256 public totalRevenue;
    uint256 public totalINFTsMinted;
    uint256 public totalChatSessions;
    uint256 public totalContentCreated;
    
    // User statistics
    mapping(address => uint256) public userChatSessions;
    mapping(address => uint256) public userINFTsMinted;
    mapping(address => uint256) public userContentCreated;
    mapping(address => uint256) public userKarmaSpent;
    
    // Fee configuration
    uint256 public platformFeePercentage = 500; // 5%
    uint256 public contentMonetizationFee = 250; // 2.5%
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _admin,
        address _karmaToken,
        address _aiInferencePayment,
        address _metadataStorage,
        address _feeRouter
    ) ERC721("SillyPort iNFT", "SPINFT") {
        require(_admin != address(0), "SillyPortPlatform: invalid admin address");
        require(_karmaToken != address(0), "SillyPortPlatform: invalid karma token address");
        require(_aiInferencePayment != address(0), "SillyPortPlatform: invalid ai inference address");
        require(_metadataStorage != address(0), "SillyPortPlatform: invalid metadata storage address");
        require(_feeRouter != address(0), "SillyPortPlatform: invalid fee router address");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PLATFORM_MANAGER_ROLE, _admin);
        _grantRole(CONTENT_MODERATOR_ROLE, _admin);
        _grantRole(AI_EXECUTOR_ROLE, _admin);
        _grantRole(SUBSCRIPTION_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        karmaToken = IERC20(_karmaToken);
        aiInferencePayment = IAIInferencePayment(_aiInferencePayment);
        metadataStorage = IMetadataStorage(_metadataStorage);
        feeRouter = IPlatformFeeRouter(_feeRouter);
        
        _initializeTierConfiguration();
        _initializePremiumFeatures();
    }
    
    // ============ INITIALIZATION ============
    
    function _initializeTierConfiguration() internal {
        tierMonthlyfees[SubscriptionTier.FREE] = 0;
        tierMonthlyfees[SubscriptionTier.BASIC] = BASIC_MONTHLY_FEE;
        tierMonthlyfees[SubscriptionTier.PREMIUM] = PREMIUM_MONTHLY_FEE;
        tierMonthlyfees[SubscriptionTier.ENTERPRISE] = ENTERPRISE_MONTHLY_FEE;
        
        tierTokenLimits[SubscriptionTier.FREE] = FREE_TOKENS_LIMIT;
        tierTokenLimits[SubscriptionTier.BASIC] = BASIC_TOKENS_LIMIT;
        tierTokenLimits[SubscriptionTier.PREMIUM] = PREMIUM_TOKENS_LIMIT;
        tierTokenLimits[SubscriptionTier.ENTERPRISE] = ENTERPRISE_TOKENS_LIMIT;
        
        tierApiLimits[SubscriptionTier.FREE] = FREE_API_LIMIT;
        tierApiLimits[SubscriptionTier.BASIC] = BASIC_API_LIMIT;
        tierApiLimits[SubscriptionTier.PREMIUM] = PREMIUM_API_LIMIT;
        tierApiLimits[SubscriptionTier.ENTERPRISE] = ENTERPRISE_API_LIMIT;
    }
    
    function _initializePremiumFeatures() internal {
        // Advanced AI Models
        premiumFeatures[1] = PremiumFeature({
            featureId: 1,
            featureName: "Advanced AI Models",
            accessLevel: AccessLevel.PREMIUM_ONLY,
            karmaRequired: 1000 * 1e18,
            usageCount: 0,
            isActive: true,
            minTier: SubscriptionTier.PREMIUM
        });
        
        // Bulk Operations
        premiumFeatures[2] = PremiumFeature({
            featureId: 2,
            featureName: "Bulk Operations",
            accessLevel: AccessLevel.PREMIUM_ONLY,
            karmaRequired: 500 * 1e18,
            usageCount: 0,
            isActive: true,
            minTier: SubscriptionTier.PREMIUM
        });
        
        // API Access
        premiumFeatures[3] = PremiumFeature({
            featureId: 3,
            featureName: "API Access",
            accessLevel: AccessLevel.TOKEN_HOLDER_ONLY,
            karmaRequired: 10000 * 1e18,
            usageCount: 0,
            isActive: true,
            minTier: SubscriptionTier.BASIC
        });
        
        // Priority Support
        premiumFeatures[4] = PremiumFeature({
            featureId: 4,
            featureName: "Priority Support",
            accessLevel: AccessLevel.PREMIUM_ONLY,
            karmaRequired: 100 * 1e18,
            usageCount: 0,
            isActive: true,
            minTier: SubscriptionTier.ENTERPRISE
        });
        
        nextFeatureId = 5;
    }
    
    // ============ INFT MINTING FUNCTIONS ============
    
    function requestINFTMint(
        string calldata prompt,
        ContentType contentType,
        string calldata aiModel
    ) external payable override nonReentrant whenNotPaused returns (bytes32 requestId) {
        require(bytes(prompt).length > 0, "SillyPortPlatform: empty prompt");
        require(bytes(aiModel).length > 0, "SillyPortPlatform: empty ai model");
        
        // Check user subscription and limits
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        require(userSub.isActive || userSub.tier == SubscriptionTier.FREE, "SillyPortPlatform: no active subscription");
        
        // Generate request ID
        _requestIdCounter.increment();
        requestId = keccak256(abi.encodePacked("INFT_MINT", _requestIdCounter.current(), msg.sender, block.timestamp));
        
        // Calculate KARMA payment required
        uint256 karmaPayment = _calculateINFTMintCost(contentType, aiModel);
        require(karmaToken.balanceOf(msg.sender) >= karmaPayment, "SillyPortPlatform: insufficient KARMA balance");
        
        // Transfer KARMA tokens
        require(karmaToken.transferFrom(msg.sender, address(this), karmaPayment), "SillyPortPlatform: KARMA transfer failed");
        
        // Create mint request
        _mintRequests[requestId] = iNFTMintRequest({
            requestId: requestId,
            requester: msg.sender,
            prompt: prompt,
            contentType: contentType,
            karmaPayment: karmaPayment,
            timestamp: block.timestamp,
            aiModel: aiModel,
            isCompleted: false,
            metadataURI: "",
            tokenId: 0
        });
        
        requestsByUser[msg.sender].push(requestId);
        requestsByType[contentType].push(requestId);
        
        // Collect platform fees
        uint256 feeAmount = (karmaPayment * platformFeePercentage) / 10000;
        if (msg.value > 0) {
            feeRouter.collectFee{value: msg.value}(
                IPlatformFeeRouter.PlatformType.SILLY_PORT,
                IPlatformFeeRouter.FeeType.TRANSACTION,
                karmaPayment,
                msg.sender
            );
        }
        
        emit INFTMintRequested(requestId, msg.sender, prompt, karmaPayment);
        
        return requestId;
    }
    
    function completeINFTMint(
        bytes32 requestId,
        string calldata metadataURI,
        uint256 tokenId
    ) external override onlyRole(AI_EXECUTOR_ROLE) {
        require(_mintRequests[requestId].requestId == requestId, "SillyPortPlatform: invalid request ID");
        require(!_mintRequests[requestId].isCompleted, "SillyPortPlatform: request already completed");
        require(bytes(metadataURI).length > 0, "SillyPortPlatform: empty metadata URI");
        
        iNFTMintRequest storage request = _mintRequests[requestId];
        
        // Mint NFT
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _safeMint(request.requester, newTokenId);
        _setTokenURI(newTokenId, metadataURI);
        
        // Update request
        request.isCompleted = true;
        request.metadataURI = metadataURI;
        request.tokenId = newTokenId;
        
        // Update statistics
        totalINFTsMinted++;
        userINFTsMinted[request.requester]++;
        userKarmaSpent[request.requester] += request.karmaPayment;
        
        emit INFTMinted(requestId, request.requester, newTokenId, metadataURI);
    }
    
    function getINFTMintRequest(bytes32 requestId) external view override returns (iNFTMintRequest memory request) {
        return _mintRequests[requestId];
    }
    
    function _calculateINFTMintCost(ContentType contentType, string memory aiModel) internal pure returns (uint256) {
        uint256 baseCost = 100 * 1e18; // 100 KARMA base cost
        
        // Adjust based on content type
        if (contentType == ContentType.AI_CHAT_SESSION) {
            baseCost = baseCost * 150 / 100; // 1.5x for chat sessions
        } else if (contentType == ContentType.PREMIUM_FEATURE) {
            baseCost = baseCost * 200 / 100; // 2x for premium features
        }
        
        // Adjust based on AI model complexity (simplified)
        bytes32 modelHash = keccak256(bytes(aiModel));
        if (modelHash == keccak256("gpt-4") || modelHash == keccak256("dall-e-3")) {
            baseCost = baseCost * 300 / 100; // 3x for advanced models
        } else if (modelHash == keccak256("gpt-3.5-turbo") || modelHash == keccak256("dall-e-2")) {
            baseCost = baseCost * 150 / 100; // 1.5x for standard models
        }
        
        return baseCost;
    }
    
    // ============ AI CHAT SESSION FUNCTIONS ============
    
    function startAIChatSession(ContentType sessionType) external override nonReentrant whenNotPaused returns (bytes32 sessionId) {
        // Check user subscription and limits
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        require(userSub.isActive || userSub.tier == SubscriptionTier.FREE, "SillyPortPlatform: no active subscription");
        require(userSub.apiCallsUsed < userSub.apiCallsLimit, "SillyPortPlatform: API limit exceeded");
        
        // Generate session ID
        _sessionIdCounter.increment();
        sessionId = keccak256(abi.encodePacked("AI_CHAT", _sessionIdCounter.current(), msg.sender, block.timestamp));
        
        // Create chat session
        _chatSessions[sessionId] = AIChatSession({
            sessionId: sessionId,
            user: msg.sender,
            startTime: block.timestamp,
            endTime: 0,
            messagesCount: 0,
            tokensUsed: 0,
            karmaSpent: 0,
            isActive: true,
            sessionType: sessionType
        });
        
        sessionsByUser[msg.sender].push(sessionId);
        sessionsByType[sessionType].push(sessionId);
        
        // Update user subscription usage
        userSub.apiCallsUsed++;
        
        // Update statistics
        totalChatSessions++;
        userChatSessions[msg.sender]++;
        
        emit AIChatSessionStarted(sessionId, msg.sender, sessionType);
        
        return sessionId;
    }
    
    function processAIChatMessage(
        bytes32 sessionId,
        string calldata message,
        uint256 tokensUsed
    ) external override nonReentrant whenNotPaused returns (uint256 karmaSpent) {
        require(_chatSessions[sessionId].sessionId == sessionId, "SillyPortPlatform: invalid session ID");
        require(_chatSessions[sessionId].isActive, "SillyPortPlatform: session not active");
        require(_chatSessions[sessionId].user == msg.sender, "SillyPortPlatform: not session owner");
        require(bytes(message).length > 0, "SillyPortPlatform: empty message");
        require(tokensUsed > 0, "SillyPortPlatform: invalid token usage");
        
        AIChatSession storage session = _chatSessions[sessionId];
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        
        // Check token limits
        require(userSub.tokensUsed + tokensUsed <= userSub.tokensLimit, "SillyPortPlatform: token limit exceeded");
        
        // Calculate KARMA cost
        karmaSpent = _calculateChatMessageCost(tokensUsed, session.sessionType, userSub.tier);
        require(karmaToken.balanceOf(msg.sender) >= karmaSpent, "SillyPortPlatform: insufficient KARMA balance");
        
        // Transfer KARMA tokens
        require(karmaToken.transferFrom(msg.sender, address(this), karmaSpent), "SillyPortPlatform: KARMA transfer failed");
        
        // Update session
        session.messagesCount++;
        session.tokensUsed += tokensUsed;
        session.karmaSpent += karmaSpent;
        
        // Update user subscription usage
        userSub.tokensUsed += tokensUsed;
        
        // Update statistics
        userKarmaSpent[msg.sender] += karmaSpent;
        
        return karmaSpent;
    }
    
    function endAIChatSession(bytes32 sessionId) external override {
        require(_chatSessions[sessionId].sessionId == sessionId, "SillyPortPlatform: invalid session ID");
        require(_chatSessions[sessionId].user == msg.sender, "SillyPortPlatform: not session owner");
        require(_chatSessions[sessionId].isActive, "SillyPortPlatform: session already ended");
        
        AIChatSession storage session = _chatSessions[sessionId];
        session.isActive = false;
        session.endTime = block.timestamp;
        
        emit AIChatSessionEnded(sessionId, msg.sender, session.tokensUsed, session.karmaSpent);
    }
    
    function getAIChatSession(bytes32 sessionId) external view override returns (AIChatSession memory session) {
        return _chatSessions[sessionId];
    }
    
    function _calculateChatMessageCost(uint256 tokensUsed, ContentType sessionType, SubscriptionTier tier) internal pure returns (uint256) {
        uint256 baseCostPerToken = 1e15; // 0.001 KARMA per token
        
        // Adjust based on session type
        if (sessionType == ContentType.PREMIUM_FEATURE) {
            baseCostPerToken = baseCostPerToken * 200 / 100; // 2x for premium features
        }
        
        // Apply tier discounts
        if (tier == SubscriptionTier.PREMIUM) {
            baseCostPerToken = baseCostPerToken * 80 / 100; // 20% discount
        } else if (tier == SubscriptionTier.ENTERPRISE) {
            baseCostPerToken = baseCostPerToken * 70 / 100; // 30% discount
        }
        
        return tokensUsed * baseCostPerToken;
    }
    
    // ============ PREMIUM FEATURE ACCESS FUNCTIONS ============
    
    function accessPremiumFeature(uint256 featureId) external payable override nonReentrant whenNotPaused returns (uint256 karmaSpent) {
        require(featureId > 0 && featureId < nextFeatureId, "SillyPortPlatform: invalid feature ID");
        require(premiumFeatures[featureId].isActive, "SillyPortPlatform: feature not active");
        
        PremiumFeature storage feature = premiumFeatures[featureId];
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        
        // Check access requirements
        require(userSub.tier >= feature.minTier, "SillyPortPlatform: insufficient subscription tier");
        
        if (feature.accessLevel == AccessLevel.TOKEN_HOLDER_ONLY) {
            require(karmaToken.balanceOf(msg.sender) >= feature.karmaRequired, "SillyPortPlatform: insufficient KARMA holdings");
        }
        
        karmaSpent = feature.karmaRequired;
        
        if (karmaSpent > 0) {
            require(karmaToken.transferFrom(msg.sender, address(this), karmaSpent), "SillyPortPlatform: KARMA transfer failed");
        }
        
        // Grant access and update usage
        userFeatureAccess[msg.sender][featureId] = true;
        feature.usageCount++;
        userKarmaSpent[msg.sender] += karmaSpent;
        
        // Collect platform fees
        if (msg.value > 0) {
            feeRouter.collectFee{value: msg.value}(
                IPlatformFeeRouter.PlatformType.SILLY_PORT,
                IPlatformFeeRouter.FeeType.PREMIUM_FEATURE,
                karmaSpent,
                msg.sender
            );
        }
        
        emit PremiumFeatureAccessed(msg.sender, featureId, karmaSpent);
        
        return karmaSpent;
    }
    
    function checkPremiumAccess(address user, uint256 featureId) external view override returns (bool hasAccess) {
        if (featureId == 0 || featureId >= nextFeatureId) return false;
        if (!premiumFeatures[featureId].isActive) return false;
        
        PremiumFeature storage feature = premiumFeatures[featureId];
        SubscriptionInfo storage userSub = subscriptions[user];
        
        // Check subscription tier
        if (userSub.tier < feature.minTier) return false;
        
        // Check access level requirements
        if (feature.accessLevel == AccessLevel.TOKEN_HOLDER_ONLY) {
            return karmaToken.balanceOf(user) >= feature.karmaRequired;
        } else if (feature.accessLevel == AccessLevel.PREMIUM_ONLY) {
            return userSub.tier >= SubscriptionTier.PREMIUM;
        } else if (feature.accessLevel == AccessLevel.SUBSCRIBER_ONLY) {
            return userSub.isActive;
        }
        
        return true; // PUBLIC access
    }
    
    function getPremiumFeature(uint256 featureId) external view override returns (PremiumFeature memory feature) {
        return premiumFeatures[featureId];
    }
    
    // ============ USER GENERATED CONTENT FUNCTIONS ============
    
    function createUserContent(
        ContentType contentType,
        string calldata contentURI,
        AccessLevel accessLevel,
        uint256 karmaRequired
    ) external override nonReentrant whenNotPaused returns (bytes32 contentId) {
        require(bytes(contentURI).length > 0, "SillyPortPlatform: empty content URI");
        
        // Generate content ID
        _contentIdCounter.increment();
        contentId = keccak256(abi.encodePacked("USER_CONTENT", _contentIdCounter.current(), msg.sender, block.timestamp));
        
        // Create user content
        _userContent[contentId] = UserGeneratedContent({
            contentId: contentId,
            creator: msg.sender,
            contentType: contentType,
            contentURI: contentURI,
            timestamp: block.timestamp,
            viewCount: 0,
            revenueGenerated: 0,
            accessLevel: accessLevel,
            karmaRequired: karmaRequired,
            isMonetized: false
        });
        
        contentByCreator[msg.sender].push(contentId);
        contentByAccessLevel[accessLevel].push(contentId);
        
        // Update statistics
        totalContentCreated++;
        userContentCreated[msg.sender]++;
        
        emit UserContentCreated(contentId, msg.sender, contentType, contentURI);
        
        return contentId;
    }
    
    function accessUserContent(bytes32 contentId) external payable override nonReentrant whenNotPaused returns (string memory contentURI) {
        require(_userContent[contentId].contentId == contentId, "SillyPortPlatform: invalid content ID");
        
        UserGeneratedContent storage content = _userContent[contentId];
        
        // Check access requirements
        if (content.accessLevel == AccessLevel.TOKEN_HOLDER_ONLY) {
            require(karmaToken.balanceOf(msg.sender) >= content.karmaRequired, "SillyPortPlatform: insufficient KARMA holdings");
        } else if (content.accessLevel == AccessLevel.SUBSCRIBER_ONLY) {
            require(subscriptions[msg.sender].isActive, "SillyPortPlatform: no active subscription");
        } else if (content.accessLevel == AccessLevel.PREMIUM_ONLY) {
            require(subscriptions[msg.sender].tier >= SubscriptionTier.PREMIUM, "SillyPortPlatform: insufficient subscription tier");
        }
        
        // Process payment if required
        if (content.karmaRequired > 0 && content.isMonetized) {
            require(karmaToken.transferFrom(msg.sender, address(this), content.karmaRequired), "SillyPortPlatform: KARMA transfer failed");
            
            // Calculate revenue split
            uint256 platformFee = (content.karmaRequired * contentMonetizationFee) / 10000;
            uint256 creatorRevenue = content.karmaRequired - platformFee;
            
            // Transfer to creator
            require(karmaToken.transfer(content.creator, creatorRevenue), "SillyPortPlatform: creator payment failed");
            
            content.revenueGenerated += creatorRevenue;
            
            emit UserContentMonetized(contentId, content.creator, creatorRevenue);
        }
        
        // Update view count
        content.viewCount++;
        
        return content.contentURI;
    }
    
    function setContentMonetization(bytes32 contentId, bool isMonetized) external override {
        require(_userContent[contentId].contentId == contentId, "SillyPortPlatform: invalid content ID");
        require(_userContent[contentId].creator == msg.sender, "SillyPortPlatform: not content creator");
        
        _userContent[contentId].isMonetized = isMonetized;
    }
    
    function getUserContent(bytes32 contentId) external view override returns (UserGeneratedContent memory content) {
        return _userContent[contentId];
    }
    
    // ============ SUBSCRIPTION MANAGEMENT FUNCTIONS ============
    
    function subscribe(SubscriptionTier tier) external payable override nonReentrant whenNotPaused returns (bool success) {
        require(tier != SubscriptionTier.FREE, "SillyPortPlatform: cannot subscribe to free tier");
        require(tier <= SubscriptionTier.ENTERPRISE, "SillyPortPlatform: invalid tier");
        
        uint256 monthlyFee = tierMonthlyfees[tier];
        require(msg.value >= monthlyFee, "SillyPortPlatform: insufficient payment");
        
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        
        // Set up new subscription
        userSub.tier = tier;
        userSub.startTime = block.timestamp;
        userSub.endTime = block.timestamp + 30 days;
        userSub.monthlyFee = monthlyFee;
        userSub.isActive = true;
        userSub.tokensUsed = 0;
        userSub.tokensLimit = tierTokenLimits[tier];
        userSub.apiCallsUsed = 0;
        userSub.apiCallsLimit = tierApiLimits[tier];
        
        // If this is a new user, increment counter
        if (userChatSessions[msg.sender] == 0 && userINFTsMinted[msg.sender] == 0 && userContentCreated[msg.sender] == 0) {
            totalUsers++;
        }
        
        // Collect subscription fees
        feeRouter.collectFee{value: msg.value}(
            IPlatformFeeRouter.PlatformType.SILLY_PORT,
            IPlatformFeeRouter.FeeType.SUBSCRIPTION,
            monthlyFee,
            msg.sender
        );
        
        totalRevenue += monthlyFee;
        
        emit SubscriptionCreated(msg.sender, tier, monthlyFee);
        
        return true;
    }
    
    function renewSubscription(SubscriptionTier tier) external payable override nonReentrant whenNotPaused returns (bool success) {
        require(tier != SubscriptionTier.FREE, "SillyPortPlatform: cannot renew free tier");
        require(subscriptions[msg.sender].tier == tier, "SillyPortPlatform: tier mismatch");
        
        uint256 monthlyFee = tierMonthlyfees[tier];
        require(msg.value >= monthlyFee, "SillyPortPlatform: insufficient payment");
        
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        
        // Extend subscription
        if (userSub.endTime > block.timestamp) {
            userSub.endTime += 30 days; // Extend from current end time
        } else {
            userSub.endTime = block.timestamp + 30 days; // Renew from now
        }
        
        userSub.isActive = true;
        userSub.tokensUsed = 0; // Reset monthly usage
        userSub.apiCallsUsed = 0; // Reset monthly usage
        
        // Collect renewal fees
        feeRouter.collectFee{value: msg.value}(
            IPlatformFeeRouter.PlatformType.SILLY_PORT,
            IPlatformFeeRouter.FeeType.SUBSCRIPTION,
            monthlyFee,
            msg.sender
        );
        
        totalRevenue += monthlyFee;
        
        emit SubscriptionRenewed(msg.sender, tier, monthlyFee);
        
        return true;
    }
    
    function upgradeSubscription(SubscriptionTier newTier) external payable override nonReentrant whenNotPaused returns (bool success) {
        require(newTier != SubscriptionTier.FREE, "SillyPortPlatform: cannot upgrade to free tier");
        require(newTier > subscriptions[msg.sender].tier, "SillyPortPlatform: not an upgrade");
        
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        SubscriptionTier oldTier = userSub.tier;
        
        uint256 newMonthlyFee = tierMonthlyfees[newTier];
        uint256 oldMonthlyFee = tierMonthlyfees[oldTier];
        uint256 upgradeFee = newMonthlyFee - oldMonthlyFee;
        
        require(msg.value >= upgradeFee, "SillyPortPlatform: insufficient upgrade payment");
        
        // Upgrade subscription
        userSub.tier = newTier;
        userSub.monthlyFee = newMonthlyFee;
        userSub.tokensLimit = tierTokenLimits[newTier];
        userSub.apiCallsLimit = tierApiLimits[newTier];
        
        // Collect upgrade fees
        feeRouter.collectFee{value: msg.value}(
            IPlatformFeeRouter.PlatformType.SILLY_PORT,
            IPlatformFeeRouter.FeeType.SUBSCRIPTION,
            upgradeFee,
            msg.sender
        );
        
        totalRevenue += upgradeFee;
        
        emit SubscriptionUpgraded(msg.sender, oldTier, newTier);
        
        return true;
    }
    
    function cancelSubscription() external override returns (bool success) {
        require(subscriptions[msg.sender].isActive, "SillyPortPlatform: no active subscription");
        
        SubscriptionInfo storage userSub = subscriptions[msg.sender];
        SubscriptionTier tier = userSub.tier;
        
        userSub.isActive = false;
        userSub.tier = SubscriptionTier.FREE;
        userSub.tokensLimit = tierTokenLimits[SubscriptionTier.FREE];
        userSub.apiCallsLimit = tierApiLimits[SubscriptionTier.FREE];
        
        emit SubscriptionCancelled(msg.sender, tier);
        
        return true;
    }
    
    function getSubscription(address user) external view override returns (SubscriptionInfo memory subscription) {
        return subscriptions[user];
    }
    
    function hasActiveSubscription(address user, SubscriptionTier tier) external view override returns (bool hasAccess) {
        SubscriptionInfo storage userSub = subscriptions[user];
        return userSub.isActive && userSub.tier >= tier && userSub.endTime > block.timestamp;
    }
    
    // ============ ANALYTICS AND REPORTING FUNCTIONS ============
    
    function getPlatformStats() external view override returns (
        uint256 _totalUsers,
        uint256 activeSubscriptions,
        uint256 _totalRevenue,
        uint256 inftsMinted
    ) {
        // Count active subscriptions (simplified - in production would use more efficient tracking)
        activeSubscriptions = 0; // Would need proper tracking
        
        return (totalUsers, activeSubscriptions, totalRevenue, totalINFTsMinted);
    }
    
    function getUserStats(address user) external view override returns (
        uint256 chatSessions,
        uint256 inftsMinted,
        uint256 contentCreated,
        uint256 karmaSpent
    ) {
        return (
            userChatSessions[user],
            userINFTsMinted[user],
            userContentCreated[user],
            userKarmaSpent[user]
        );
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function addPremiumFeature(
        string calldata featureName,
        AccessLevel accessLevel,
        uint256 karmaRequired,
        SubscriptionTier minTier
    ) external onlyRole(PLATFORM_MANAGER_ROLE) {
        premiumFeatures[nextFeatureId] = PremiumFeature({
            featureId: nextFeatureId,
            featureName: featureName,
            accessLevel: accessLevel,
            karmaRequired: karmaRequired,
            usageCount: 0,
            isActive: true,
            minTier: minTier
        });
        
        nextFeatureId++;
    }
    
    function updatePlatformFees(uint256 _platformFeePercentage, uint256 _contentMonetizationFee) 
        external onlyRole(PLATFORM_MANAGER_ROLE) {
        require(_platformFeePercentage <= 1000, "SillyPortPlatform: fee too high"); // Max 10%
        require(_contentMonetizationFee <= 1000, "SillyPortPlatform: fee too high"); // Max 10%
        
        platformFeePercentage = _platformFeePercentage;
        contentMonetizationFee = _contentMonetizationFee;
    }
    
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    function emergencyWithdraw(address token, uint256 amount) 
        external onlyRole(EMERGENCY_ROLE) nonReentrant {
        if (token == address(0)) {
            // Withdraw ETH
            uint256 balance = address(this).balance;
            uint256 withdrawAmount = (amount == 0) ? balance : amount;
            require(withdrawAmount <= balance, "SillyPortPlatform: insufficient ETH balance");
            
            (bool success, ) = msg.sender.call{value: withdrawAmount}("");
            require(success, "SillyPortPlatform: ETH withdrawal failed");
        } else {
            // Withdraw ERC-20 tokens
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            uint256 withdrawAmount = (amount == 0) ? balance : amount;
            require(withdrawAmount <= balance, "SillyPortPlatform: insufficient token balance");
            
            require(tokenContract.transfer(msg.sender, withdrawAmount), "SillyPortPlatform: token withdrawal failed");
        }
    }
    
    // ============ REQUIRED OVERRIDES ============
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    // ============ RECEIVE FUNCTION ============
    
    receive() external payable {
        // Accept ETH deposits for subscription payments
    }
}
