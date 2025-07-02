// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISillyHotelPlatform
 * @dev Interface for SillyHotel Game Integration
 * Stage 8.2 - SillyHotel Integration Requirements
 */
interface ISillyHotelPlatform {
    
    // ============ ENUMS ============
    
    enum GameItemType {
        CHARACTER,          // Character NFTs
        EQUIPMENT,          // Equipment items
        COSMETIC,           // Cosmetic items
        CONSUMABLE,         // Consumable items
        ROOM_UPGRADE,       // Hotel room upgrades
        SPECIAL_ABILITY     // Special abilities
    }
    
    enum CharacterRarity {
        COMMON,             // Common characters
        UNCOMMON,           // Uncommon characters
        RARE,               // Rare characters
        EPIC,               // Epic characters
        LEGENDARY           // Legendary characters
    }
    
    enum RentalStatus {
        AVAILABLE,          // Available for rental
        RENTED,             // Currently rented
        MAINTENANCE,        // Under maintenance
        LOCKED              // Locked by owner
    }
    
    enum GuildRole {
        MEMBER,             // Guild member
        OFFICER,            // Guild officer
        LEADER              // Guild leader
    }
    
    // ============ STRUCTS ============
    
    struct GameItem {
        uint256 itemId;
        GameItemType itemType;
        string name;
        string description;
        uint256 karmaPrice;
        uint256 ethPrice;
        uint256 maxSupply;
        uint256 currentSupply;
        bool isActive;
        CharacterRarity rarity;
        uint256[] stats;
    }
    
    struct CharacterNFT {
        uint256 tokenId;
        address owner;
        string name;
        CharacterRarity rarity;
        uint256 level;
        uint256 experience;
        uint256[] stats;
        uint256[] equipment;
        bool isForSale;
        bool isForRent;
        uint256 salePrice;
        uint256 rentalPricePerDay;
        RentalStatus rentalStatus;
        uint256 rentalEndTime;
        address currentRenter;
    }
    
    struct RentalAgreement {
        bytes32 agreementId;
        uint256 tokenId;
        address owner;
        address renter;
        uint256 dailyRate;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        bool isActive;
        bool isCompleted;
    }
    
    struct Guild {
        bytes32 guildId;
        string name;
        address leader;
        uint256 memberCount;
        uint256 totalRevenue;
        uint256 revenueSharePercentage;
        bool isActive;
        uint256 createdAt;
        mapping(address => GuildRole) memberRoles;
        mapping(address => uint256) memberShares;
    }
    
    struct MarketplaceListing {
        uint256 listingId;
        uint256 tokenId;
        address seller;
        uint256 price;
        uint256 timestamp;
        bool isActive;
        GameItemType itemType;
        uint256 marketplaceFee;
    }
    
    // ============ EVENTS ============
    
    event GameItemPurchased(address indexed buyer, uint256 indexed itemId, GameItemType itemType, uint256 karmaSpent, uint256 ethSpent);
    event CharacterMinted(address indexed owner, uint256 indexed tokenId, CharacterRarity rarity);
    event CharacterListedForSale(uint256 indexed tokenId, address indexed owner, uint256 price);
    event CharacterSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event CharacterListedForRent(uint256 indexed tokenId, address indexed owner, uint256 dailyRate);
    event CharacterRented(bytes32 indexed agreementId, uint256 indexed tokenId, address indexed renter, uint256 totalAmount);
    event RentalCompleted(bytes32 indexed agreementId, uint256 indexed tokenId);
    
    event GuildCreated(bytes32 indexed guildId, string name, address indexed leader);
    event GuildMemberAdded(bytes32 indexed guildId, address indexed member, GuildRole role);
    event GuildRevenueDistributed(bytes32 indexed guildId, uint256 totalAmount);
    
    event MarketplaceFeesCollected(address indexed platform, uint256 amount);
    
    // ============ GAME ITEM FUNCTIONS ============
    
    function purchaseGameItem(uint256 itemId, uint256 quantity) external payable returns (bool success);
    function purchaseGameItemWithKarma(uint256 itemId, uint256 quantity) external returns (bool success);
    function addGameItem(GameItem calldata item) external;
    function updateGameItem(uint256 itemId, GameItem calldata item) external;
    function getGameItem(uint256 itemId) external view returns (GameItem memory item);
    function getGameItemsByType(GameItemType itemType) external view returns (GameItem[] memory items);
    
    // ============ CHARACTER NFT FUNCTIONS ============
    
    function mintCharacter(CharacterRarity rarity, string calldata name) external payable returns (uint256 tokenId);
    function upgradeCharacter(uint256 tokenId, uint256[] calldata statIncreases) external payable returns (bool success);
    function equipItem(uint256 tokenId, uint256 itemId) external returns (bool success);
    function getCharacter(uint256 tokenId) external view returns (CharacterNFT memory character);
    function getCharactersByOwner(address owner) external view returns (CharacterNFT[] memory characters);
    
    // ============ TRADING FUNCTIONS ============
    
    function listCharacterForSale(uint256 tokenId, uint256 price) external returns (bool success);
    function buyCharacter(uint256 tokenId) external payable returns (bool success);
    function cancelSale(uint256 tokenId) external returns (bool success);
    function getMarketplaceListings() external view returns (MarketplaceListing[] memory listings);
    function getMarketplaceListingsByType(GameItemType itemType) external view returns (MarketplaceListing[] memory listings);
    
    // ============ RENTAL FUNCTIONS ============
    
    function listCharacterForRent(uint256 tokenId, uint256 dailyRate) external returns (bool success);
    function rentCharacter(uint256 tokenId, uint256 durationDays) external payable returns (bytes32 agreementId);
    function returnCharacter(bytes32 agreementId) external returns (bool success);
    function getRentalAgreement(bytes32 agreementId) external view returns (RentalAgreement memory agreement);
    function getActiveRentals(address user) external view returns (RentalAgreement[] memory agreements);
    
    // ============ GUILD FUNCTIONS ============
    
    function createGuild(string calldata name, uint256 revenueSharePercentage) external returns (bytes32 guildId);
    function joinGuild(bytes32 guildId) external returns (bool success);
    function leaveGuild(bytes32 guildId) external returns (bool success);
    function promoteGuildMember(bytes32 guildId, address member, GuildRole newRole) external returns (bool success);
    function distributeGuildRevenue(bytes32 guildId) external returns (bool success);
    function getGuildInfo(bytes32 guildId) external view returns (string memory name, address leader, uint256 memberCount, uint256 totalRevenue);
    function getGuildMembers(bytes32 guildId) external view returns (address[] memory members, GuildRole[] memory roles);
    
    // ============ REVENUE SHARING FUNCTIONS ============
    
    function setGuildRevenueShare(bytes32 guildId, uint256 percentage) external returns (bool success);
    function withdrawGuildRevenue(bytes32 guildId) external returns (uint256 amount);
    function getGuildRevenue(bytes32 guildId) external view returns (uint256 totalRevenue, uint256 availableForWithdrawal);
    
    // ============ MARKETPLACE FUNCTIONS ============
    
    function setMarketplaceFee(uint256 feePercentage) external;
    function collectMarketplaceFees() external returns (uint256 amount);
    function getMarketplaceStats() external view returns (uint256 totalSales, uint256 totalVolume, uint256 totalFees);
    
    // ============ ANALYTICS FUNCTIONS ============
    
    function getPlayerStats(address player) external view returns (
        uint256 charactersOwned,
        uint256 totalSpent,
        uint256 totalEarned,
        uint256 guildRevenue
    );
    
    function getPlatformStats() external view returns (
        uint256 totalPlayers,
        uint256 totalCharacters,
        uint256 totalRevenue,
        uint256 activeGuilds
    );
}
