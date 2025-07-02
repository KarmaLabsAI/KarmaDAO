// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title KarmaLabsIntegration
 * @dev KarmaLabs Asset Platform Integration with advanced NFT marketplace
 * @notice Comprehensive NFT marketplace with AI-generated asset verification
 */
contract KarmaLabsIntegration is 
    ERC721, 
    ERC721URIStorage, 
    ERC721Royalty,
    AccessControl, 
    ReentrancyGuard, 
    Pausable 
{
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MARKETPLACE_MANAGER_ROLE = keccak256("MARKETPLACE_MANAGER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
    // ============ EVENTS ============
    
    event AssetMinted(
        uint256 indexed tokenId,
        address indexed creator,
        string contentHash,
        AssetType assetType,
        bool isAIGenerated
    );
    
    event AssetVerified(
        uint256 indexed tokenId,
        address indexed verifier,
        VerificationStatus status,
        string verificationHash
    );
    
    event AssetListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price,
        PaymentMethod paymentMethod
    );
    
    event AssetSold(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 marketplaceFee,
        uint256 royaltyFee
    );
    
    event BulkOperationCompleted(
        address indexed operator,
        BulkOperationType operationType,
        uint256 itemsProcessed,
        uint256 totalValue
    );
    
    event CreatorRoyaltyDistributed(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 royaltyAmount
    );
    
    event MarketplaceFeeCollected(
        uint256 indexed tokenId,
        uint256 feeAmount,
        address feeRecipient
    );
    
    // ============ ENUMS ============
    
    enum AssetType {
        IMAGE,
        VIDEO,
        AUDIO,
        DOCUMENT,
        MODEL_3D,
        ANIMATION,
        INTERACTIVE,
        OTHER
    }
    
    enum VerificationStatus {
        UNVERIFIED,
        PENDING,
        VERIFIED,
        REJECTED,
        DISPUTED
    }
    
    enum PaymentMethod {
        ETH,
        KARMA,
        BOTH
    }
    
    enum BulkOperationType {
        MINT,
        TRANSFER,
        LIST,
        DELIST,
        VERIFY
    }
    
    enum ListingStatus {
        INACTIVE,
        ACTIVE,
        SOLD,
        CANCELLED
    }
    
    // ============ STRUCTS ============
    
    struct AssetMetadata {
        uint256 tokenId;
        address creator;
        string title;
        string description;
        string contentHash;
        AssetType assetType;
        bool isAIGenerated;
        string aiModel;
        string generationPrompt;
        VerificationStatus verificationStatus;
        string verificationHash;
        uint256 createdAt;
        uint256 fileSize;
        string[] tags;
    }
    
    struct MarketplaceListing {
        uint256 tokenId;
        address seller;
        uint256 priceETH;
        uint256 priceKarma;
        PaymentMethod paymentMethod;
        ListingStatus status;
        uint256 listedAt;
        uint256 expiresAt;
        bool isAuction;
        uint256 highestBid;
        address highestBidder;
    }
    
    struct CreatorProfile {
        address creator;
        string name;
        string bio;
        string profileImage;
        uint256 totalAssets;
        uint256 totalSales;
        uint256 totalRoyalties;
        bool isVerified;
        uint256 reputationScore;
    }
    
    struct MarketplaceConfig {
        uint256 marketplaceFeePercentage;    // In basis points (100 = 1%)
        uint256 maxRoyaltyPercentage;        // In basis points (1000 = 10%)
        uint256 minListingDuration;          // In seconds
        uint256 maxListingDuration;          // In seconds
        address feeRecipient;
        bool bulkOperationsEnabled;
        uint256 verificationReward;          // Reward for verifying assets
    }
    
    // ============ STATE VARIABLES ============
    
    IERC20 public karmaToken;
    Counters.Counter private _tokenIdCounter;
    MarketplaceConfig public marketplaceConfig;
    
    // Asset management
    mapping(uint256 => AssetMetadata) public assetMetadata;
    mapping(uint256 => MarketplaceListing) public marketplaceListings;
    mapping(address => CreatorProfile) public creatorProfiles;
    
    // Marketplace functionality
    mapping(uint256 => mapping(address => uint256)) public auctionBids;
    mapping(address => uint256[]) public userOwnedAssets;
    mapping(address => uint256[]) public userCreatedAssets;
    mapping(address => uint256[]) public userListedAssets;
    
    // AI verification system
    mapping(string => bool) public verifiedAIModels;
    mapping(uint256 => address[]) public assetVerifiers;
    mapping(address => uint256) public verifierReputationScore;
    
    // Fee collection
    uint256 public totalFeesCollected;
    uint256 public totalRoyaltiesDistributed;
    mapping(address => uint256) public creatorEarnings;
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _admin,
        address _feeRecipient
    ) ERC721("KarmaLabs Asset", "KLABS") {
        require(_karmaToken != address(0), "KarmaLabsIntegration: Invalid karma token");
        require(_admin != address(0), "KarmaLabsIntegration: Invalid admin");
        require(_feeRecipient != address(0), "KarmaLabsIntegration: Invalid fee recipient");
        
        karmaToken = IERC20(_karmaToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(MARKETPLACE_MANAGER_ROLE, _admin);
        _grantRole(VERIFIER_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
        
        // Initialize marketplace configuration
        marketplaceConfig = MarketplaceConfig({
            marketplaceFeePercentage: 250,      // 2.5%
            maxRoyaltyPercentage: 1000,         // 10%
            minListingDuration: 1 hours,
            maxListingDuration: 30 days,
            feeRecipient: _feeRecipient,
            bulkOperationsEnabled: true,
            verificationReward: 10 ether        // 10 KARMA
        });
        
        // Initialize verified AI models
        verifiedAIModels["stable-diffusion-v1.5"] = true;
        verifiedAIModels["dall-e-3"] = true;
        verifiedAIModels["midjourney-v6"] = true;
        verifiedAIModels["leonardo-ai"] = true;
    }
    
    // ============ MODIFIERS ============
    
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "KarmaLabsIntegration: Not token owner");
        _;
    }
    
    modifier onlyTokenCreator(uint256 tokenId) {
        require(assetMetadata[tokenId].creator == msg.sender, "KarmaLabsIntegration: Not token creator");
        _;
    }
    
    modifier validTokenId(uint256 tokenId) {
        require(_exists(tokenId), "KarmaLabsIntegration: Token does not exist");
        _;
    }
    
    modifier onlyMarketplaceManager() {
        require(hasRole(MARKETPLACE_MANAGER_ROLE, msg.sender), "KarmaLabsIntegration: Not marketplace manager");
        _;
    }
    
    modifier onlyVerifier() {
        require(hasRole(VERIFIER_ROLE, msg.sender), "KarmaLabsIntegration: Not verifier");
        _;
    }
    
    // ============ ASSET MINTING AND MANAGEMENT ============
    
    /**
     * @dev Mint new asset with comprehensive metadata
     * @param creator Asset creator address
     * @param title Asset title
     * @param description Asset description
     * @param contentHash IPFS/0G hash of the asset
     * @param assetType Type of asset being minted
     * @param isAIGenerated Whether asset was AI-generated
     * @param aiModel AI model used (if applicable)
     * @param generationPrompt Prompt used for generation (if applicable)
     * @param royaltyPercentage Royalty percentage in basis points
     * @param tags Array of tags for categorization
     * @return tokenId Minted token ID
     */
    function mintAsset(
        address creator,
        string memory title,
        string memory description,
        string memory contentHash,
        AssetType assetType,
        bool isAIGenerated,
        string memory aiModel,
        string memory generationPrompt,
        uint96 royaltyPercentage,
        string[] memory tags
    ) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        require(creator != address(0), "KarmaLabsIntegration: Invalid creator");
        require(bytes(title).length > 0, "KarmaLabsIntegration: Empty title");
        require(bytes(contentHash).length > 0, "KarmaLabsIntegration: Empty content hash");
        require(royaltyPercentage <= marketplaceConfig.maxRoyaltyPercentage, "KarmaLabsIntegration: Royalty too high");
        
        if (isAIGenerated) {
            require(verifiedAIModels[aiModel], "KarmaLabsIntegration: AI model not verified");
            require(bytes(generationPrompt).length > 0, "KarmaLabsIntegration: Empty generation prompt");
        }
        
        _tokenIdCounter.increment();
        tokenId = _tokenIdCounter.current();
        
        // Mint NFT
        _mint(creator, tokenId);
        _setTokenURI(tokenId, contentHash);
        
        // Set royalty
        if (royaltyPercentage > 0) {
            _setTokenRoyalty(tokenId, creator, royaltyPercentage);
        }
        
        // Store metadata
        assetMetadata[tokenId] = AssetMetadata({
            tokenId: tokenId,
            creator: creator,
            title: title,
            description: description,
            contentHash: contentHash,
            assetType: assetType,
            isAIGenerated: isAIGenerated,
            aiModel: aiModel,
            generationPrompt: generationPrompt,
            verificationStatus: VerificationStatus.UNVERIFIED,
            verificationHash: "",
            createdAt: block.timestamp,
            fileSize: 0, // Would be set by oracle or off-chain service
            tags: tags
        });
        
        // Update creator profile
        CreatorProfile storage profile = creatorProfiles[creator];
        if (profile.creator == address(0)) {
            profile.creator = creator;
        }
        profile.totalAssets++;
        userCreatedAssets[creator].push(tokenId);
        userOwnedAssets[creator].push(tokenId);
        
        emit AssetMinted(tokenId, creator, contentHash, assetType, isAIGenerated);
        
        return tokenId;
    }
    
    /**
     * @dev Batch mint multiple assets for efficiency
     * @param requests Array of mint requests
     * @return tokenIds Array of minted token IDs
     */
    function batchMintAssets(
        MintRequest[] memory requests
    ) external onlyRole(MINTER_ROLE) returns (uint256[] memory tokenIds) {
        require(marketplaceConfig.bulkOperationsEnabled, "KarmaLabsIntegration: Bulk operations disabled");
        require(requests.length > 0 && requests.length <= 50, "KarmaLabsIntegration: Invalid batch size");
        
        tokenIds = new uint256[](requests.length);
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < requests.length; i++) {
            tokenIds[i] = mintAsset(
                requests[i].creator,
                requests[i].title,
                requests[i].description,
                requests[i].contentHash,
                requests[i].assetType,
                requests[i].isAIGenerated,
                requests[i].aiModel,
                requests[i].generationPrompt,
                requests[i].royaltyPercentage,
                requests[i].tags
            );
            totalValue += 1; // Count of items
        }
        
        emit BulkOperationCompleted(msg.sender, BulkOperationType.MINT, requests.length, totalValue);
        
        return tokenIds;
    }
    
    struct MintRequest {
        address creator;
        string title;
        string description;
        string contentHash;
        AssetType assetType;
        bool isAIGenerated;
        string aiModel;
        string generationPrompt;
        uint96 royaltyPercentage;
        string[] tags;
    }
    
    // ============ AI VERIFICATION SYSTEM ============
    
    /**
     * @dev Verify asset authenticity and quality
     * @param tokenId Token ID to verify
     * @param status Verification status
     * @param verificationHash Hash of verification data
     */
    function verifyAsset(
        uint256 tokenId,
        VerificationStatus status,
        string memory verificationHash
    ) external onlyVerifier validTokenId(tokenId) {
        AssetMetadata storage metadata = assetMetadata[tokenId];
        require(metadata.verificationStatus != VerificationStatus.VERIFIED, "KarmaLabsIntegration: Already verified");
        
        metadata.verificationStatus = status;
        metadata.verificationHash = verificationHash;
        
        assetVerifiers[tokenId].push(msg.sender);
        verifierReputationScore[msg.sender]++;
        
        // Reward verifier with KARMA tokens
        if (status == VerificationStatus.VERIFIED && marketplaceConfig.verificationReward > 0) {
            require(
                karmaToken.balanceOf(address(this)) >= marketplaceConfig.verificationReward,
                "KarmaLabsIntegration: Insufficient reward balance"
            );
            karmaToken.safeTransfer(msg.sender, marketplaceConfig.verificationReward);
        }
        
        emit AssetVerified(tokenId, msg.sender, status, verificationHash);
    }
    
    /**
     * @dev Add verified AI model
     * @param modelName AI model name
     */
    function addVerifiedAIModel(string memory modelName) external onlyRole(VERIFIER_ROLE) {
        verifiedAIModels[modelName] = true;
    }
    
    // ============ MARKETPLACE FUNCTIONALITY ============
    
    /**
     * @dev List asset for sale
     * @param tokenId Token ID to list
     * @param priceETH Price in ETH (0 if not accepting ETH)
     * @param priceKarma Price in KARMA (0 if not accepting KARMA)
     * @param duration Listing duration in seconds
     * @param isAuction Whether this is an auction listing
     */
    function listAsset(
        uint256 tokenId,
        uint256 priceETH,
        uint256 priceKarma,
        uint256 duration,
        bool isAuction
    ) external onlyTokenOwner(tokenId) validTokenId(tokenId) {
        require(priceETH > 0 || priceKarma > 0, "KarmaLabsIntegration: Invalid pricing");
        require(duration >= marketplaceConfig.minListingDuration, "KarmaLabsIntegration: Duration too short");
        require(duration <= marketplaceConfig.maxListingDuration, "KarmaLabsIntegration: Duration too long");
        
        MarketplaceListing storage listing = marketplaceListings[tokenId];
        require(listing.status != ListingStatus.ACTIVE, "KarmaLabsIntegration: Already listed");
        
        PaymentMethod paymentMethod;
        if (priceETH > 0 && priceKarma > 0) {
            paymentMethod = PaymentMethod.BOTH;
        } else if (priceETH > 0) {
            paymentMethod = PaymentMethod.ETH;
        } else {
            paymentMethod = PaymentMethod.KARMA;
        }
        
        listing.tokenId = tokenId;
        listing.seller = msg.sender;
        listing.priceETH = priceETH;
        listing.priceKarma = priceKarma;
        listing.paymentMethod = paymentMethod;
        listing.status = ListingStatus.ACTIVE;
        listing.listedAt = block.timestamp;
        listing.expiresAt = block.timestamp + duration;
        listing.isAuction = isAuction;
        listing.highestBid = 0;
        listing.highestBidder = address(0);
        
        userListedAssets[msg.sender].push(tokenId);
        
        emit AssetListed(tokenId, msg.sender, priceETH > 0 ? priceETH : priceKarma, paymentMethod);
    }
    
    /**
     * @dev Purchase listed asset with ETH
     * @param tokenId Token ID to purchase
     */
    function purchaseAssetWithETH(uint256 tokenId) 
        external 
        payable 
        nonReentrant 
        validTokenId(tokenId) 
    {
        MarketplaceListing storage listing = marketplaceListings[tokenId];
        require(listing.status == ListingStatus.ACTIVE, "KarmaLabsIntegration: Not for sale");
        require(block.timestamp <= listing.expiresAt, "KarmaLabsIntegration: Listing expired");
        require(!listing.isAuction, "KarmaLabsIntegration: Use bid function for auctions");
        require(listing.paymentMethod == PaymentMethod.ETH || listing.paymentMethod == PaymentMethod.BOTH, "KarmaLabsIntegration: ETH not accepted");
        require(msg.value >= listing.priceETH, "KarmaLabsIntegration: Insufficient payment");
        
        _processSale(tokenId, msg.sender, listing.priceETH, true);
    }
    
    /**
     * @dev Purchase listed asset with KARMA tokens
     * @param tokenId Token ID to purchase
     */
    function purchaseAssetWithKarma(uint256 tokenId) 
        external 
        nonReentrant 
        validTokenId(tokenId) 
    {
        MarketplaceListing storage listing = marketplaceListings[tokenId];
        require(listing.status == ListingStatus.ACTIVE, "KarmaLabsIntegration: Not for sale");
        require(block.timestamp <= listing.expiresAt, "KarmaLabsIntegration: Listing expired");
        require(!listing.isAuction, "KarmaLabsIntegration: Use bid function for auctions");
        require(listing.paymentMethod == PaymentMethod.KARMA || listing.paymentMethod == PaymentMethod.BOTH, "KarmaLabsIntegration: KARMA not accepted");
        require(karmaToken.balanceOf(msg.sender) >= listing.priceKarma, "KarmaLabsIntegration: Insufficient KARMA balance");
        
        karmaToken.safeTransferFrom(msg.sender, address(this), listing.priceKarma);
        _processSale(tokenId, msg.sender, listing.priceKarma, false);
    }
    
    /**
     * @dev Process asset sale and distribute payments
     * @param tokenId Token ID being sold
     * @param buyer Buyer address
     * @param price Sale price
     * @param isETH Whether payment is in ETH (true) or KARMA (false)
     */
    function _processSale(
        uint256 tokenId,
        address buyer,
        uint256 price,
        bool isETH
    ) internal {
        MarketplaceListing storage listing = marketplaceListings[tokenId];
        address seller = listing.seller;
        
        // Calculate fees
        uint256 marketplaceFee = (price * marketplaceConfig.marketplaceFeePercentage) / 10000;
        uint256 royaltyAmount = 0;
        address royaltyRecipient = address(0);
        
        // Get royalty information
        (royaltyRecipient, royaltyAmount) = royaltyInfo(tokenId, price);
        
        uint256 sellerAmount = price - marketplaceFee - royaltyAmount;
        
        // Transfer NFT to buyer
        _transfer(seller, buyer, tokenId);
        
        // Update ownership tracking
        _removeFromUserAssets(seller, tokenId);
        userOwnedAssets[buyer].push(tokenId);
        
        // Distribute payments
        if (isETH) {
            // Transfer to seller
            payable(seller).transfer(sellerAmount);
            
            // Transfer marketplace fee
            payable(marketplaceConfig.feeRecipient).transfer(marketplaceFee);
            
            // Transfer royalty
            if (royaltyAmount > 0 && royaltyRecipient != address(0)) {
                payable(royaltyRecipient).transfer(royaltyAmount);
            }
            
            // Refund excess
            if (msg.value > price) {
                payable(buyer).transfer(msg.value - price);
            }
        } else {
            // Transfer KARMA to seller
            karmaToken.safeTransfer(seller, sellerAmount);
            
            // Transfer marketplace fee
            karmaToken.safeTransfer(marketplaceConfig.feeRecipient, marketplaceFee);
            
            // Transfer royalty
            if (royaltyAmount > 0 && royaltyRecipient != address(0)) {
                karmaToken.safeTransfer(royaltyRecipient, royaltyAmount);
            }
        }
        
        // Update statistics
        totalFeesCollected += marketplaceFee;
        totalRoyaltiesDistributed += royaltyAmount;
        creatorEarnings[seller] += sellerAmount;
        
        CreatorProfile storage sellerProfile = creatorProfiles[seller];
        sellerProfile.totalSales++;
        
        // Mark listing as sold
        listing.status = ListingStatus.SOLD;
        
        emit AssetSold(tokenId, buyer, seller, price, marketplaceFee, royaltyAmount);
        
        if (royaltyAmount > 0) {
            emit CreatorRoyaltyDistributed(tokenId, royaltyRecipient, royaltyAmount);
        }
        
        emit MarketplaceFeeCollected(tokenId, marketplaceFee, marketplaceConfig.feeRecipient);
    }
    
    // ============ UTILITY FUNCTIONS ============
    
    /**
     * @dev Remove token from user's asset list
     * @param user User address
     * @param tokenId Token ID to remove
     */
    function _removeFromUserAssets(address user, uint256 tokenId) internal {
        uint256[] storage userAssets = userOwnedAssets[user];
        for (uint256 i = 0; i < userAssets.length; i++) {
            if (userAssets[i] == tokenId) {
                userAssets[i] = userAssets[userAssets.length - 1];
                userAssets.pop();
                break;
            }
        }
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get asset metadata
     * @param tokenId Token ID
     * @return Asset metadata
     */
    function getAssetMetadata(uint256 tokenId) 
        external 
        view 
        validTokenId(tokenId) 
        returns (AssetMetadata memory) 
    {
        return assetMetadata[tokenId];
    }
    
    /**
     * @dev Get marketplace listing
     * @param tokenId Token ID
     * @return Marketplace listing
     */
    function getMarketplaceListing(uint256 tokenId) 
        external 
        view 
        validTokenId(tokenId) 
        returns (MarketplaceListing memory) 
    {
        return marketplaceListings[tokenId];
    }
    
    /**
     * @dev Get creator profile
     * @param creator Creator address
     * @return Creator profile
     */
    function getCreatorProfile(address creator) 
        external 
        view 
        returns (CreatorProfile memory) 
    {
        return creatorProfiles[creator];
    }
    
    /**
     * @dev Get user's owned assets
     * @param user User address
     * @return Array of token IDs
     */
    function getUserOwnedAssets(address user) external view returns (uint256[] memory) {
        return userOwnedAssets[user];
    }
    
    /**
     * @dev Get user's created assets
     * @param user User address
     * @return Array of token IDs
     */
    function getUserCreatedAssets(address user) external view returns (uint256[] memory) {
        return userCreatedAssets[user];
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Update marketplace configuration
     * @param marketplaceFeePercentage New marketplace fee percentage
     * @param maxRoyaltyPercentage New max royalty percentage
     * @param feeRecipient New fee recipient
     */
    function updateMarketplaceConfig(
        uint256 marketplaceFeePercentage,
        uint256 maxRoyaltyPercentage,
        address feeRecipient
    ) external onlyRole(FEE_MANAGER_ROLE) {
        require(marketplaceFeePercentage <= 1000, "KarmaLabsIntegration: Fee too high"); // Max 10%
        require(maxRoyaltyPercentage <= 2000, "KarmaLabsIntegration: Royalty too high"); // Max 20%
        require(feeRecipient != address(0), "KarmaLabsIntegration: Invalid fee recipient");
        
        marketplaceConfig.marketplaceFeePercentage = marketplaceFeePercentage;
        marketplaceConfig.maxRoyaltyPercentage = maxRoyaltyPercentage;
        marketplaceConfig.feeRecipient = feeRecipient;
    }
    
    /**
     * @dev Emergency pause marketplace
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Resume marketplace operations
     */
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ OVERRIDE FUNCTIONS ============
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage, ERC721Royalty) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (string memory) 
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
} 