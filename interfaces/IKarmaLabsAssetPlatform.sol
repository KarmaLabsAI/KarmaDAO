// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKarmaLabsAssetPlatform
 * @dev Interface for KarmaLabs Asset Platform Integration
 * Stage 8.2 - KarmaLabs Asset Platform Requirements
 */
interface IKarmaLabsAssetPlatform {
    
    // ============ ENUMS ============
    
    enum AssetType {
        AI_ART,             // AI-generated artwork
        AI_MUSIC,           // AI-generated music
        AI_VIDEO,           // AI-generated videos
        AI_TEXT,            // AI-generated text content
        AI_CODE,            // AI-generated code
        AI_3D_MODEL,        // AI-generated 3D models
        TRAINING_DATA,      // AI training datasets
        AI_MODEL           // Trained AI models
    }
    
    enum VerificationStatus {
        PENDING,            // Pending verification
        VERIFIED,           // Verified as AI-generated
        REJECTED,           // Verification rejected
        DISPUTED,           // Under dispute
        AUTHENTIC          // Verified authentic
    }
    
    enum ListingStatus {
        DRAFT,              // Draft listing
        ACTIVE,             // Active listing
        SOLD,               // Sold
        CANCELLED,          // Cancelled
        EXPIRED            // Expired
    }
    
    enum LicenseType {
        PERSONAL,           // Personal use only
        COMMERCIAL,         // Commercial use allowed
        ROYALTY_FREE,       // Royalty-free commercial use
        EXCLUSIVE,          // Exclusive rights
        CUSTOM             // Custom license terms
    }
    
    // ============ STRUCTS ============
    
    struct Asset {
        uint256 assetId;
        address creator;
        AssetType assetType;
        string title;
        string description;
        string metadataURI;
        string assetURI;
        uint256 price;
        LicenseType licenseType;
        VerificationStatus verificationStatus;
        ListingStatus listingStatus;
        uint256 createdAt;
        uint256 views;
        uint256 downloads;
        uint256 royaltyPercentage;
        bool isAuthentic;
        string aiModel;
        string generationPrompt;
    }
    
    struct VerificationData {
        bytes32 verificationId;
        uint256 assetId;
        address verifier;
        VerificationStatus status;
        string verificationMethod;
        bytes32 aiModelHash;
        bytes32 promptHash;
        bytes32 outputHash;
        uint256 timestamp;
        string remarks;
    }
    
    struct Listing {
        uint256 listingId;
        uint256 assetId;
        address seller;
        uint256 price;
        LicenseType licenseType;
        ListingStatus status;
        uint256 listedAt;
        uint256 expiresAt;
        uint256 views;
        uint256 favorites;
    }
    
    struct Sale {
        uint256 saleId;
        uint256 assetId;
        uint256 listingId;
        address seller;
        address buyer;
        uint256 price;
        uint256 royaltyAmount;
        uint256 platformFee;
        LicenseType licenseType;
        uint256 timestamp;
    }
    
    struct RoyaltyInfo {
        address creator;
        uint256 percentage;
        uint256 totalEarned;
        uint256 lastPayment;
    }
    
    struct BulkOperation {
        bytes32 operationId;
        address operator;
        uint256[] assetIds;
        string operationType;
        uint256 timestamp;
        bool isCompleted;
        uint256 successCount;
        uint256 failureCount;
    }
    
    struct CreatorProfile {
        address creator;
        string name;
        string bio;
        string profileImageURI;
        uint256 totalAssets;
        uint256 totalSales;
        uint256 totalRoyalties;
        uint256 reputation;
        bool isVerified;
        uint256 joinedAt;
    }
    
    // ============ EVENTS ============
    
    event AssetCreated(uint256 indexed assetId, address indexed creator, AssetType assetType, string title);
    event AssetListed(uint256 indexed listingId, uint256 indexed assetId, address indexed seller, uint256 price);
    event AssetSold(uint256 saleId, uint256 indexed assetId, address indexed seller, address indexed buyer, uint256 price);
    event AssetVerified(uint256 indexed assetId, address indexed verifier, VerificationStatus status);
    event RoyaltyPaid(uint256 indexed assetId, address indexed creator, uint256 amount);
    
    event BulkOperationStarted(bytes32 indexed operationId, address indexed operator, string operationType, uint256 assetCount);
    event BulkOperationCompleted(bytes32 indexed operationId, uint256 successCount, uint256 failureCount);
    
    event CreatorProfileUpdated(address indexed creator, string name);
    event CreatorVerified(address indexed creator);
    
    event PlatformFeesCollected(uint256 amount);
    
    // ============ ASSET CREATION AND MANAGEMENT ============
    
    function createAsset(
        AssetType assetType,
        string calldata title,
        string calldata description,
        string calldata metadataURI,
        string calldata assetURI,
        uint256 royaltyPercentage,
        string calldata aiModel,
        string calldata generationPrompt
    ) external returns (uint256 assetId);
    
    function updateAsset(uint256 assetId, Asset calldata assetData) external returns (bool success);
    function deleteAsset(uint256 assetId) external returns (bool success);
    function getAsset(uint256 assetId) external view returns (Asset memory asset);
    function getAssetsByCreator(address creator) external view returns (Asset[] memory assets);
    function getAssetsByType(AssetType assetType) external view returns (Asset[] memory assets);
    
    // ============ AI VERIFICATION SYSTEM ============
    
    function submitForVerification(uint256 assetId, string calldata verificationMethod) external returns (bytes32 verificationId);
    function verifyAsset(bytes32 verificationId, VerificationStatus status, string calldata remarks) external returns (bool success);
    function disputeVerification(bytes32 verificationId, string calldata reason) external returns (bool success);
    function getVerificationData(bytes32 verificationId) external view returns (VerificationData memory verification);
    function getAssetVerifications(uint256 assetId) external view returns (VerificationData[] memory verifications);
    
    // ============ MARKETPLACE FUNCTIONS ============
    
    function listAsset(uint256 assetId, uint256 price, LicenseType licenseType, uint256 duration) external returns (uint256 listingId);
    function updateListing(uint256 listingId, uint256 newPrice, LicenseType newLicenseType) external returns (bool success);
    function cancelListing(uint256 listingId) external returns (bool success);
    function purchaseAsset(uint256 listingId) external payable returns (uint256 saleId);
    function getListing(uint256 listingId) external view returns (Listing memory listing);
    function getActiveListings() external view returns (Listing[] memory listings);
    function getListingsByType(AssetType assetType) external view returns (Listing[] memory listings);
    
    // ============ ROYALTY DISTRIBUTION ============
    
    function setRoyaltyPercentage(uint256 assetId, uint256 percentage) external returns (bool success);
    function distributeRoyalties(uint256 saleId) external returns (bool success);
    function withdrawRoyalties() external returns (uint256 amount);
    function getRoyaltyInfo(uint256 assetId) external view returns (RoyaltyInfo memory royalty);
    function getCreatorRoyalties(address creator) external view returns (uint256 totalEarned, uint256 availableForWithdrawal);
    
    // ============ BULK OPERATIONS ============
    
    function bulkListAssets(uint256[] calldata assetIds, uint256[] calldata prices, LicenseType[] calldata licenseTypes) external returns (bytes32 operationId);
    function bulkUpdatePrices(uint256[] calldata listingIds, uint256[] calldata newPrices) external returns (bytes32 operationId);
    function bulkCancelListings(uint256[] calldata listingIds) external returns (bytes32 operationId);
    function bulkTransferAssets(uint256[] calldata assetIds, address[] calldata recipients) external returns (bytes32 operationId);
    function getBulkOperation(bytes32 operationId) external view returns (BulkOperation memory operation);
    function getBulkOperationsByOperator(address operator) external view returns (BulkOperation[] memory operations);
    
    // ============ CREATOR PROFILE MANAGEMENT ============
    
    function createCreatorProfile(string calldata name, string calldata bio, string calldata profileImageURI) external returns (bool success);
    function updateCreatorProfile(string calldata name, string calldata bio, string calldata profileImageURI) external returns (bool success);
    function verifyCreator(address creator) external returns (bool success);
    function getCreatorProfile(address creator) external view returns (CreatorProfile memory profile);
    function getTopCreators(uint256 limit) external view returns (CreatorProfile[] memory creators);
    
    // ============ SEARCH AND DISCOVERY ============
    
    function searchAssets(string calldata query, AssetType assetType, uint256 minPrice, uint256 maxPrice) external view returns (Asset[] memory assets);
    function getFeaturedAssets() external view returns (Asset[] memory assets);
    function getTrendingAssets() external view returns (Asset[] memory assets);
    function getRecentAssets(uint256 limit) external view returns (Asset[] memory assets);
    
    // ============ ANALYTICS AND REPORTING ============
    
    function getPlatformStats() external view returns (
        uint256 totalAssets,
        uint256 totalSales,
        uint256 totalVolume,
        uint256 totalCreators
    );
    
    function getCreatorStats(address creator) external view returns (
        uint256 assetsCreated,
        uint256 totalSales,
        uint256 totalRoyalties,
        uint256 reputation
    );
    
    function getAssetStats(uint256 assetId) external view returns (
        uint256 views,
        uint256 downloads,
        uint256 sales,
        uint256 revenue
    );
    
    function getMarketplaceAnalytics() external view returns (
        uint256 averagePrice,
        uint256 totalListings,
        uint256 conversionRate,
        AssetType mostPopularType
    );
}
