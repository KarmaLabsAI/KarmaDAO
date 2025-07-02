// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../../../interfaces/ISillyHotelPlatform.sol";
import "../../../interfaces/IPlatformFeeRouter.sol";

/**
 * @title SillyHotelPlatform
 * @dev Implementation of SillyHotel Game Integration
 * Stage 8.2 - SillyHotel Integration Implementation
 */
contract SillyHotelPlatform is ISillyHotelPlatform, ERC721, ERC721URIStorage, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // ============ CONSTANTS ============
    
    bytes32 public constant GAME_MANAGER_ROLE = keccak256("GAME_MANAGER_ROLE");
    bytes32 public constant GUILD_MANAGER_ROLE = keccak256("GUILD_MANAGER_ROLE");
    bytes32 public constant MARKETPLACE_MANAGER_ROLE = keccak256("MARKETPLACE_MANAGER_ROLE");
    bytes32 public constant RENTAL_MANAGER_ROLE = keccak256("RENTAL_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MARKETPLACE_FEE_PERCENTAGE = 250; // 2.5%
    uint256 public constant RENTAL_FEE_PERCENTAGE = 100; // 1%
    uint256 public constant GUILD_REVENUE_SHARE_MAX = 3000; // 30% max
    
    // ============ STATE VARIABLES ============
    
    // Core contracts
    IERC20 public karmaToken;
    IPlatformFeeRouter public feeRouter;
    
    // Counters
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _itemIdCounter;
    Counters.Counter private _listingIdCounter;
    Counters.Counter private _agreementIdCounter;
    Counters.Counter private _guildIdCounter;
    
    // Game items
    mapping(uint256 => GameItem) public gameItems;
    mapping(GameItemType => uint256[]) public itemsByType;
    mapping(CharacterRarity => uint256[]) public itemsByRarity;
    
    // Character NFTs
    mapping(uint256 => CharacterNFT) private _characters;
    mapping(address => uint256[]) public charactersByOwner;
    mapping(CharacterRarity => uint256[]) public charactersByRarity;
    
    // Rental system
    mapping(bytes32 => RentalAgreement) private _rentalAgreements;
    mapping(address => bytes32[]) public rentalsByOwner;
    mapping(address => bytes32[]) public rentalsByRenter;
    mapping(uint256 => bytes32) public activeRentalByToken;
    
    // Marketplace
    mapping(uint256 => MarketplaceListing) public marketplaceListings;
    mapping(address => uint256[]) public listingsBySeller;
    mapping(GameItemType => uint256[]) public listingsByType;
    uint256[] public activeListings;
    
    // Guilds
    mapping(bytes32 => Guild) private _guilds;
    mapping(address => bytes32) public userGuild;
    mapping(bytes32 => address[]) public guildMembers;
    mapping(bytes32 => uint256) public guildRevenue;
    mapping(bytes32 => mapping(address => uint256)) public guildMemberShares;
    bytes32[] public allGuilds;
    
    // Platform statistics
    uint256 public totalPlayers;
    uint256 public totalCharacters;
    uint256 public totalRevenue;
    uint256 public totalSales;
    uint256 public totalVolume;
    uint256 public totalFees;
    uint256 public activeGuilds;
    
    // User statistics
    mapping(address => uint256) public playerStats_charactersOwned;
    mapping(address => uint256) public playerStats_totalSpent;
    mapping(address => uint256) public playerStats_totalEarned;
    mapping(address => uint256) public playerStats_guildRevenue;
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _admin,
        address _karmaToken,
        address _feeRouter
    ) ERC721("SillyHotel Character", "SHCHAR") {
        require(_admin != address(0), "SillyHotelPlatform: invalid admin address");
        require(_karmaToken != address(0), "SillyHotelPlatform: invalid karma token address");
        require(_feeRouter != address(0), "SillyHotelPlatform: invalid fee router address");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GAME_MANAGER_ROLE, _admin);
        _grantRole(GUILD_MANAGER_ROLE, _admin);
        _grantRole(MARKETPLACE_MANAGER_ROLE, _admin);
        _grantRole(RENTAL_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        karmaToken = IERC20(_karmaToken);
        feeRouter = IPlatformFeeRouter(_feeRouter);
        
        _initializeGameItems();
    }
    
    // ============ INITIALIZATION ============
    
    function _initializeGameItems() internal {
        // Initialize basic game items
        _itemIdCounter.increment();
        gameItems[_itemIdCounter.current()] = GameItem({
            itemId: _itemIdCounter.current(),
            itemType: GameItemType.CHARACTER,
            name: "Basic Character Mint",
            description: "Mint a basic character NFT",
            karmaPrice: 1000 * 1e18,
            ethPrice: 0.01 ether,
            maxSupply: 10000,
            currentSupply: 0,
            isActive: true,
            rarity: CharacterRarity.COMMON,
            stats: new uint256[](0)
        });
        
        _itemIdCounter.increment();
        gameItems[_itemIdCounter.current()] = GameItem({
            itemId: _itemIdCounter.current(),
            itemType: GameItemType.EQUIPMENT,
            name: "Basic Sword",
            description: "A basic sword for combat",
            karmaPrice: 100 * 1e18,
            ethPrice: 0.001 ether,
            maxSupply: 50000,
            currentSupply: 0,
            isActive: true,
            rarity: CharacterRarity.COMMON,
            stats: [uint256(10), uint256(0), uint256(0), uint256(0)] // Attack, Defense, Speed, Magic
        });
        
        _itemIdCounter.increment();
        gameItems[_itemIdCounter.current()] = GameItem({
            itemId: _itemIdCounter.current(),
            itemType: GameItemType.COSMETIC,
            name: "Cool Hat",
            description: "A fashionable hat",
            karmaPrice: 50 * 1e18,
            ethPrice: 0.0005 ether,
            maxSupply: 100000,
            currentSupply: 0,
            isActive: true,
            rarity: CharacterRarity.COMMON,
            stats: new uint256[](0)
        });
    }
    
    // ============ GAME ITEM FUNCTIONS ============
    
    function purchaseGameItem(uint256 itemId, uint256 quantity) external payable override nonReentrant whenNotPaused returns (bool success) {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "SillyHotelPlatform: invalid item ID");
        require(quantity > 0, "SillyHotelPlatform: invalid quantity");
        
        GameItem storage item = gameItems[itemId];
        require(item.isActive, "SillyHotelPlatform: item not active");
        require(item.currentSupply + quantity <= item.maxSupply, "SillyHotelPlatform: exceeds max supply");
        
        uint256 totalEthCost = item.ethPrice * quantity;
        require(msg.value >= totalEthCost, "SillyHotelPlatform: insufficient ETH payment");
        
        // Update supply
        item.currentSupply += quantity;
        
        // Process character minting if it's a character item
        if (item.itemType == GameItemType.CHARACTER) {
            for (uint256 i = 0; i < quantity; i++) {
                _mintCharacter(msg.sender, item.rarity, item.name);
            }
        }
        
        // Update player statistics
        if (playerStats_charactersOwned[msg.sender] == 0) {
            totalPlayers++;
        }
        playerStats_totalSpent[msg.sender] += totalEthCost;
        
        // Collect platform fees
        uint256 feeAmount = (totalEthCost * MARKETPLACE_FEE_PERCENTAGE) / 10000;
        feeRouter.collectFee{value: feeAmount}(
            IPlatformFeeRouter.PlatformType.SILLY_HOTEL,
            IPlatformFeeRouter.FeeType.TRANSACTION,
            totalEthCost,
            msg.sender
        );
        
        totalRevenue += totalEthCost;
        totalFees += feeAmount;
        
        emit GameItemPurchased(msg.sender, itemId, item.itemType, 0, totalEthCost);
        
        return true;
    }
    
    function purchaseGameItemWithKarma(uint256 itemId, uint256 quantity) external override nonReentrant whenNotPaused returns (bool success) {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "SillyHotelPlatform: invalid item ID");
        require(quantity > 0, "SillyHotelPlatform: invalid quantity");
        
        GameItem storage item = gameItems[itemId];
        require(item.isActive, "SillyHotelPlatform: item not active");
        require(item.currentSupply + quantity <= item.maxSupply, "SillyHotelPlatform: exceeds max supply");
        
        uint256 totalKarmaCost = item.karmaPrice * quantity;
        require(karmaToken.balanceOf(msg.sender) >= totalKarmaCost, "SillyHotelPlatform: insufficient KARMA balance");
        
        // Transfer KARMA tokens
        require(karmaToken.transferFrom(msg.sender, address(this), totalKarmaCost), "SillyHotelPlatform: KARMA transfer failed");
        
        // Update supply
        item.currentSupply += quantity;
        
        // Process character minting if it's a character item
        if (item.itemType == GameItemType.CHARACTER) {
            for (uint256 i = 0; i < quantity; i++) {
                _mintCharacter(msg.sender, item.rarity, item.name);
            }
        }
        
        // Update player statistics
        if (playerStats_charactersOwned[msg.sender] == 0) {
            totalPlayers++;
        }
        playerStats_totalSpent[msg.sender] += totalKarmaCost;
        
        emit GameItemPurchased(msg.sender, itemId, item.itemType, totalKarmaCost, 0);
        
        return true;
    }
    
    function addGameItem(GameItem calldata item) external override onlyRole(GAME_MANAGER_ROLE) {
        _itemIdCounter.increment();
        uint256 newItemId = _itemIdCounter.current();
        
        gameItems[newItemId] = GameItem({
            itemId: newItemId,
            itemType: item.itemType,
            name: item.name,
            description: item.description,
            karmaPrice: item.karmaPrice,
            ethPrice: item.ethPrice,
            maxSupply: item.maxSupply,
            currentSupply: 0,
            isActive: true,
            rarity: item.rarity,
            stats: item.stats
        });
        
        itemsByType[item.itemType].push(newItemId);
        itemsByRarity[item.rarity].push(newItemId);
    }
    
    function updateGameItem(uint256 itemId, GameItem calldata item) external override onlyRole(GAME_MANAGER_ROLE) {
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "SillyHotelPlatform: invalid item ID");
        
        GameItem storage existingItem = gameItems[itemId];
        existingItem.name = item.name;
        existingItem.description = item.description;
        existingItem.karmaPrice = item.karmaPrice;
        existingItem.ethPrice = item.ethPrice;
        existingItem.isActive = item.isActive;
        existingItem.stats = item.stats;
    }
    
    function getGameItem(uint256 itemId) external view override returns (GameItem memory item) {
        return gameItems[itemId];
    }
    
    function getGameItemsByType(GameItemType itemType) external view override returns (GameItem[] memory items) {
        uint256[] memory itemIds = itemsByType[itemType];
        items = new GameItem[](itemIds.length);
        
        for (uint256 i = 0; i < itemIds.length; i++) {
            items[i] = gameItems[itemIds[i]];
        }
        
        return items;
    }
    
    // ============ CHARACTER NFT FUNCTIONS ============
    
    function mintCharacter(CharacterRarity rarity, string calldata name) external payable override nonReentrant whenNotPaused returns (uint256 tokenId) {
        uint256 mintCost = _calculateMintCost(rarity);
        require(msg.value >= mintCost, "SillyHotelPlatform: insufficient payment");
        
        tokenId = _mintCharacter(msg.sender, rarity, name);
        
        // Collect fees
        uint256 feeAmount = (mintCost * MARKETPLACE_FEE_PERCENTAGE) / 10000;
        feeRouter.collectFee{value: feeAmount}(
            IPlatformFeeRouter.PlatformType.SILLY_HOTEL,
            IPlatformFeeRouter.FeeType.TRANSACTION,
            mintCost,
            msg.sender
        );
        
        totalRevenue += mintCost;
        totalFees += feeAmount;
        
        return tokenId;
    }
    
    function _mintCharacter(address to, CharacterRarity rarity, string memory name) internal returns (uint256 tokenId) {
        _tokenIdCounter.increment();
        tokenId = _tokenIdCounter.current();
        
        _safeMint(to, tokenId);
        
        // Initialize character data
        uint256[] memory initialStats = _generateInitialStats(rarity);
        uint256[] memory emptyEquipment = new uint256[](0);
        
        _characters[tokenId] = CharacterNFT({
            tokenId: tokenId,
            owner: to,
            name: name,
            rarity: rarity,
            level: 1,
            experience: 0,
            stats: initialStats,
            equipment: emptyEquipment,
            isForSale: false,
            isForRent: false,
            salePrice: 0,
            rentalPricePerDay: 0,
            rentalStatus: RentalStatus.AVAILABLE,
            rentalEndTime: 0,
            currentRenter: address(0)
        });
        
        charactersByOwner[to].push(tokenId);
        charactersByRarity[rarity].push(tokenId);
        
        totalCharacters++;
        playerStats_charactersOwned[to]++;
        
        emit CharacterMinted(to, tokenId, rarity);
        
        return tokenId;
    }
    
    function _generateInitialStats(CharacterRarity rarity) internal pure returns (uint256[] memory stats) {
        stats = new uint256[](4); // Attack, Defense, Speed, Magic
        
        uint256 baseValue = 10;
        uint256 rarityMultiplier = 1;
        
        if (rarity == CharacterRarity.UNCOMMON) {
            rarityMultiplier = 2;
        } else if (rarity == CharacterRarity.RARE) {
            rarityMultiplier = 3;
        } else if (rarity == CharacterRarity.EPIC) {
            rarityMultiplier = 5;
        } else if (rarity == CharacterRarity.LEGENDARY) {
            rarityMultiplier = 8;
        }
        
        stats[0] = baseValue * rarityMultiplier; // Attack
        stats[1] = baseValue * rarityMultiplier; // Defense
        stats[2] = baseValue * rarityMultiplier; // Speed
        stats[3] = baseValue * rarityMultiplier; // Magic
        
        return stats;
    }
    
    function _calculateMintCost(CharacterRarity rarity) internal pure returns (uint256) {
        if (rarity == CharacterRarity.COMMON) return 0.01 ether;
        if (rarity == CharacterRarity.UNCOMMON) return 0.025 ether;
        if (rarity == CharacterRarity.RARE) return 0.05 ether;
        if (rarity == CharacterRarity.EPIC) return 0.1 ether;
        if (rarity == CharacterRarity.LEGENDARY) return 0.25 ether;
        
        return 0.01 ether; // Default to common
    }
    
    function upgradeCharacter(uint256 tokenId, uint256[] calldata statIncreases) external payable override nonReentrant whenNotPaused returns (bool success) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        require(ownerOf(tokenId) == msg.sender, "SillyHotelPlatform: not character owner");
        require(statIncreases.length == 4, "SillyHotelPlatform: invalid stat increases length");
        
        CharacterNFT storage character = _characters[tokenId];
        
        uint256 upgradeCost = _calculateUpgradeCost(statIncreases);
        require(msg.value >= upgradeCost, "SillyHotelPlatform: insufficient payment");
        
        // Apply stat increases
        for (uint256 i = 0; i < 4; i++) {
            character.stats[i] += statIncreases[i];
        }
        
        // Increase level if significant upgrade
        uint256 totalIncrease = statIncreases[0] + statIncreases[1] + statIncreases[2] + statIncreases[3];
        if (totalIncrease >= 10) {
            character.level++;
            character.experience += totalIncrease * 10;
        }
        
        playerStats_totalSpent[msg.sender] += upgradeCost;
        totalRevenue += upgradeCost;
        
        return true;
    }
    
    function _calculateUpgradeCost(uint256[] calldata statIncreases) internal pure returns (uint256) {
        uint256 totalIncrease = statIncreases[0] + statIncreases[1] + statIncreases[2] + statIncreases[3];
        return totalIncrease * 0.001 ether; // 0.001 ETH per stat point
    }
    
    function equipItem(uint256 tokenId, uint256 itemId) external override returns (bool success) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        require(ownerOf(tokenId) == msg.sender, "SillyHotelPlatform: not character owner");
        require(itemId > 0 && itemId <= _itemIdCounter.current(), "SillyHotelPlatform: invalid item ID");
        
        GameItem storage item = gameItems[itemId];
        require(item.itemType == GameItemType.EQUIPMENT, "SillyHotelPlatform: not equipment item");
        
        CharacterNFT storage character = _characters[tokenId];
        character.equipment.push(itemId);
        
        // Apply equipment stats to character
        for (uint256 i = 0; i < item.stats.length && i < character.stats.length; i++) {
            character.stats[i] += item.stats[i];
        }
        
        return true;
    }
    
    function getCharacter(uint256 tokenId) external view override returns (CharacterNFT memory character) {
        return _characters[tokenId];
    }
    
    function getCharactersByOwner(address owner) external view override returns (CharacterNFT[] memory characters) {
        uint256[] memory tokenIds = charactersByOwner[owner];
        characters = new CharacterNFT[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            characters[i] = _characters[tokenIds[i]];
        }
        
        return characters;
    }
    
    // ============ TRADING FUNCTIONS ============
    
    function listCharacterForSale(uint256 tokenId, uint256 price) external override returns (bool success) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        require(ownerOf(tokenId) == msg.sender, "SillyHotelPlatform: not character owner");
        require(price > 0, "SillyHotelPlatform: invalid price");
        
        CharacterNFT storage character = _characters[tokenId];
        require(!character.isForRent, "SillyHotelPlatform: character is listed for rent");
        
        character.isForSale = true;
        character.salePrice = price;
        
        // Create marketplace listing
        _listingIdCounter.increment();
        uint256 listingId = _listingIdCounter.current();
        
        marketplaceListings[listingId] = MarketplaceListing({
            listingId: listingId,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            timestamp: block.timestamp,
            isActive: true,
            itemType: GameItemType.CHARACTER,
            marketplaceFee: (price * MARKETPLACE_FEE_PERCENTAGE) / 10000
        });
        
        listingsBySeller[msg.sender].push(listingId);
        listingsByType[GameItemType.CHARACTER].push(listingId);
        activeListings.push(listingId);
        
        emit CharacterListedForSale(tokenId, msg.sender, price);
        
        return true;
    }
    
    function buyCharacter(uint256 tokenId) external payable override nonReentrant whenNotPaused returns (bool success) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        
        CharacterNFT storage character = _characters[tokenId];
        require(character.isForSale, "SillyHotelPlatform: character not for sale");
        require(msg.value >= character.salePrice, "SillyHotelPlatform: insufficient payment");
        
        address seller = ownerOf(tokenId);
        uint256 salePrice = character.salePrice;
        
        // Calculate fees
        uint256 marketplaceFee = (salePrice * MARKETPLACE_FEE_PERCENTAGE) / 10000;
        uint256 sellerAmount = salePrice - marketplaceFee;
        
        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);
        
        // Update character data
        character.owner = msg.sender;
        character.isForSale = false;
        character.salePrice = 0;
        
        // Update owner arrays
        _removeFromOwnerArray(seller, tokenId);
        charactersByOwner[msg.sender].push(tokenId);
        
        // Transfer payment to seller
        (bool success1, ) = seller.call{value: sellerAmount}("");
        require(success1, "SillyHotelPlatform: seller payment failed");
        
        // Collect marketplace fees
        feeRouter.collectFee{value: marketplaceFee}(
            IPlatformFeeRouter.PlatformType.SILLY_HOTEL,
            IPlatformFeeRouter.FeeType.MARKETPLACE,
            salePrice,
            msg.sender
        );
        
        // Update statistics
        playerStats_totalSpent[msg.sender] += salePrice;
        playerStats_totalEarned[seller] += sellerAmount;
        playerStats_charactersOwned[msg.sender]++;
        playerStats_charactersOwned[seller]--;
        
        totalSales++;
        totalVolume += salePrice;
        totalFees += marketplaceFee;
        
        emit CharacterSold(tokenId, seller, msg.sender, salePrice);
        
        return true;
    }
    
    function cancelSale(uint256 tokenId) external override returns (bool success) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        require(ownerOf(tokenId) == msg.sender, "SillyHotelPlatform: not character owner");
        
        CharacterNFT storage character = _characters[tokenId];
        require(character.isForSale, "SillyHotelPlatform: character not for sale");
        
        character.isForSale = false;
        character.salePrice = 0;
        
        // Note: In production, would also remove from marketplace listings
        
        return true;
    }
    
    function getMarketplaceListings() external view override returns (MarketplaceListing[] memory listings) {
        listings = new MarketplaceListing[](activeListings.length);
        
        for (uint256 i = 0; i < activeListings.length; i++) {
            listings[i] = marketplaceListings[activeListings[i]];
        }
        
        return listings;
    }
    
    function getMarketplaceListingsByType(GameItemType itemType) external view override returns (MarketplaceListing[] memory listings) {
        uint256[] memory listingIds = listingsByType[itemType];
        listings = new MarketplaceListing[](listingIds.length);
        
        for (uint256 i = 0; i < listingIds.length; i++) {
            listings[i] = marketplaceListings[listingIds[i]];
        }
        
        return listings;
    }
    
    function _removeFromOwnerArray(address owner, uint256 tokenId) internal {
        uint256[] storage tokens = charactersByOwner[owner];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }
    
    // ============ RENTAL FUNCTIONS ============
    
    function listCharacterForRent(uint256 tokenId, uint256 dailyRate) external override returns (bool success) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        require(ownerOf(tokenId) == msg.sender, "SillyHotelPlatform: not character owner");
        require(dailyRate > 0, "SillyHotelPlatform: invalid daily rate");
        
        CharacterNFT storage character = _characters[tokenId];
        require(!character.isForSale, "SillyHotelPlatform: character is listed for sale");
        require(character.rentalStatus == RentalStatus.AVAILABLE, "SillyHotelPlatform: character not available for rent");
        
        character.isForRent = true;
        character.rentalPricePerDay = dailyRate;
        
        emit CharacterListedForRent(tokenId, msg.sender, dailyRate);
        
        return true;
    }
    
    function rentCharacter(uint256 tokenId, uint256 durationDays) external payable override nonReentrant whenNotPaused returns (bytes32 agreementId) {
        require(_exists(tokenId), "SillyHotelPlatform: character does not exist");
        require(durationDays > 0, "SillyHotelPlatform: invalid duration");
        
        CharacterNFT storage character = _characters[tokenId];
        require(character.isForRent, "SillyHotelPlatform: character not for rent");
        require(character.rentalStatus == RentalStatus.AVAILABLE, "SillyHotelPlatform: character not available");
        
        address owner = ownerOf(tokenId);
        require(owner != msg.sender, "SillyHotelPlatform: cannot rent own character");
        
        uint256 totalAmount = character.rentalPricePerDay * durationDays;
        require(msg.value >= totalAmount, "SillyHotelPlatform: insufficient payment");
        
        // Generate agreement ID
        _agreementIdCounter.increment();
        agreementId = keccak256(abi.encodePacked("RENTAL", _agreementIdCounter.current(), tokenId, msg.sender, block.timestamp));
        
        // Create rental agreement
        _rentalAgreements[agreementId] = RentalAgreement({
            agreementId: agreementId,
            tokenId: tokenId,
            owner: owner,
            renter: msg.sender,
            dailyRate: character.rentalPricePerDay,
            startTime: block.timestamp,
            endTime: block.timestamp + (durationDays * 1 days),
            totalAmount: totalAmount,
            isActive: true,
            isCompleted: false
        });
        
        // Update character rental status
        character.rentalStatus = RentalStatus.RENTED;
        character.rentalEndTime = block.timestamp + (durationDays * 1 days);
        character.currentRenter = msg.sender;
        
        // Update tracking arrays
        rentalsByOwner[owner].push(agreementId);
        rentalsByRenter[msg.sender].push(agreementId);
        activeRentalByToken[tokenId] = agreementId;
        
        // Calculate and transfer fees
        uint256 rentalFee = (totalAmount * RENTAL_FEE_PERCENTAGE) / 10000;
        uint256 ownerAmount = totalAmount - rentalFee;
        
        // Transfer payment to owner
        (bool success1, ) = owner.call{value: ownerAmount}("");
        require(success1, "SillyHotelPlatform: owner payment failed");
        
        // Collect rental fees
        feeRouter.collectFee{value: rentalFee}(
            IPlatformFeeRouter.PlatformType.SILLY_HOTEL,
            IPlatformFeeRouter.FeeType.TRANSACTION,
            totalAmount,
            msg.sender
        );
        
        // Update statistics
        playerStats_totalSpent[msg.sender] += totalAmount;
        playerStats_totalEarned[owner] += ownerAmount;
        totalRevenue += totalAmount;
        totalFees += rentalFee;
        
        emit CharacterRented(agreementId, tokenId, msg.sender, totalAmount);
        
        return agreementId;
    }
    
    function returnCharacter(bytes32 agreementId) external override returns (bool success) {
        require(_rentalAgreements[agreementId].agreementId == agreementId, "SillyHotelPlatform: invalid agreement ID");
        
        RentalAgreement storage agreement = _rentalAgreements[agreementId];
        require(agreement.isActive, "SillyHotelPlatform: agreement not active");
        require(msg.sender == agreement.renter || msg.sender == agreement.owner, "SillyHotelPlatform: not authorized");
        
        CharacterNFT storage character = _characters[agreement.tokenId];
        
        // End rental
        agreement.isActive = false;
        agreement.isCompleted = true;
        
        character.rentalStatus = RentalStatus.AVAILABLE;
        character.rentalEndTime = 0;
        character.currentRenter = address(0);
        
        delete activeRentalByToken[agreement.tokenId];
        
        emit RentalCompleted(agreementId, agreement.tokenId);
        
        return true;
    }
    
    function getRentalAgreement(bytes32 agreementId) external view override returns (RentalAgreement memory agreement) {
        return _rentalAgreements[agreementId];
    }
    
    function getActiveRentals(address user) external view override returns (RentalAgreement[] memory agreements) {
        bytes32[] memory rentalIds = rentalsByRenter[user];
        uint256 activeCount = 0;
        
        // Count active rentals
        for (uint256 i = 0; i < rentalIds.length; i++) {
            if (_rentalAgreements[rentalIds[i]].isActive) {
                activeCount++;
            }
        }
        
        // Populate active rentals
        agreements = new RentalAgreement[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < rentalIds.length; i++) {
            if (_rentalAgreements[rentalIds[i]].isActive) {
                agreements[index] = _rentalAgreements[rentalIds[i]];
                index++;
            }
        }
        
        return agreements;
    }
    
    // ============ GUILD FUNCTIONS ============
    
    function createGuild(string calldata name, uint256 revenueSharePercentage) external override returns (bytes32 guildId) {
        require(bytes(name).length > 0, "SillyHotelPlatform: empty guild name");
        require(revenueSharePercentage <= GUILD_REVENUE_SHARE_MAX, "SillyHotelPlatform: revenue share too high");
        require(userGuild[msg.sender] == bytes32(0), "SillyHotelPlatform: already in guild");
        
        _guildIdCounter.increment();
        guildId = keccak256(abi.encodePacked("GUILD", _guildIdCounter.current(), msg.sender, block.timestamp));
        
        // Initialize guild data (note: simplified for storage limitations)
        guildMembers[guildId].push(msg.sender);
        guildRevenue[guildId] = 0;
        guildMemberShares[guildId][msg.sender] = 10000; // 100% initially
        
        userGuild[msg.sender] = guildId;
        allGuilds.push(guildId);
        activeGuilds++;
        
        emit GuildCreated(guildId, name, msg.sender);
        
        return guildId;
    }
    
    function joinGuild(bytes32 guildId) external override returns (bool success) {
        require(guildId != bytes32(0), "SillyHotelPlatform: invalid guild ID");
        require(userGuild[msg.sender] == bytes32(0), "SillyHotelPlatform: already in guild");
        require(guildMembers[guildId].length > 0, "SillyHotelPlatform: guild does not exist");
        
        guildMembers[guildId].push(msg.sender);
        userGuild[msg.sender] = guildId;
        
        // Initialize member share (simplified)
        guildMemberShares[guildId][msg.sender] = 1000; // 10% default
        
        emit GuildMemberAdded(guildId, msg.sender, GuildRole.MEMBER);
        
        return true;
    }
    
    function leaveGuild(bytes32 guildId) external override returns (bool success) {
        require(userGuild[msg.sender] == guildId, "SillyHotelPlatform: not in specified guild");
        
        // Remove from guild
        userGuild[msg.sender] = bytes32(0);
        guildMemberShares[guildId][msg.sender] = 0;
        
        // Remove from members array (simplified)
        address[] storage members = guildMembers[guildId];
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == msg.sender) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
        
        return true;
    }
    
    function promoteGuildMember(bytes32 guildId, address member, GuildRole newRole) external override returns (bool success) {
        require(userGuild[msg.sender] == guildId, "SillyHotelPlatform: not in guild");
        require(userGuild[member] == guildId, "SillyHotelPlatform: member not in guild");
        
        // In a full implementation, would check permissions based on caller's role
        // For now, simplified to just emit event
        
        emit GuildMemberAdded(guildId, member, newRole);
        
        return true;
    }
    
    function distributeGuildRevenue(bytes32 guildId) external override returns (bool success) {
        require(guildId != bytes32(0), "SillyHotelPlatform: invalid guild ID");
        require(guildMembers[guildId].length > 0, "SillyHotelPlatform: guild does not exist");
        
        uint256 totalRevenue = guildRevenue[guildId];
        require(totalRevenue > 0, "SillyHotelPlatform: no revenue to distribute");
        
        // Reset revenue counter
        guildRevenue[guildId] = 0;
        
        emit GuildRevenueDistributed(guildId, totalRevenue);
        
        return true;
    }
    
    function getGuildInfo(bytes32 guildId) external view override returns (
        string memory name,
        address leader,
        uint256 memberCount,
        uint256 totalRevenue
    ) {
        require(guildMembers[guildId].length > 0, "SillyHotelPlatform: guild does not exist");
        
        name = "Guild"; // Simplified
        leader = guildMembers[guildId].length > 0 ? guildMembers[guildId][0] : address(0);
        memberCount = guildMembers[guildId].length;
        totalRevenue = guildRevenue[guildId];
        
        return (name, leader, memberCount, totalRevenue);
    }
    
    function getGuildMembers(bytes32 guildId) external view override returns (
        address[] memory members,
        GuildRole[] memory roles
    ) {
        members = guildMembers[guildId];
        roles = new GuildRole[](members.length);
        
        // Simplified: all members have MEMBER role except first (leader)
        for (uint256 i = 0; i < members.length; i++) {
            roles[i] = (i == 0) ? GuildRole.LEADER : GuildRole.MEMBER;
        }
        
        return (members, roles);
    }
    
    // ============ REVENUE SHARING FUNCTIONS ============
    
    function setGuildRevenueShare(bytes32 guildId, uint256 percentage) external override returns (bool success) {
        require(userGuild[msg.sender] == guildId, "SillyHotelPlatform: not in guild");
        require(percentage <= GUILD_REVENUE_SHARE_MAX, "SillyHotelPlatform: percentage too high");
        
        // In full implementation, would update guild revenue share percentage
        // For now, simplified to just return success
        
        return true;
    }
    
    function withdrawGuildRevenue(bytes32 guildId) external override returns (uint256 amount) {
        require(userGuild[msg.sender] == guildId, "SillyHotelPlatform: not in guild");
        
        amount = guildRevenue[guildId];
        if (amount > 0) {
            guildRevenue[guildId] = 0;
            playerStats_guildRevenue[msg.sender] += amount;
        }
        
        return amount;
    }
    
    function getGuildRevenue(bytes32 guildId) external view override returns (
        uint256 totalRevenue,
        uint256 availableForWithdrawal
    ) {
        totalRevenue = guildRevenue[guildId];
        availableForWithdrawal = totalRevenue; // Simplified
        
        return (totalRevenue, availableForWithdrawal);
    }
    
    // ============ MARKETPLACE FUNCTIONS ============
    
    function setMarketplaceFee(uint256 feePercentage) external override onlyRole(MARKETPLACE_MANAGER_ROLE) {
        require(feePercentage <= 1000, "SillyHotelPlatform: fee too high"); // Max 10%
        // Update marketplace fee (simplified)
    }
    
    function collectMarketplaceFees() external override onlyRole(MARKETPLACE_MANAGER_ROLE) returns (uint256 amount) {
        amount = address(this).balance;
        if (amount > 0) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "SillyHotelPlatform: fee collection failed");
            
            emit MarketplaceFeesCollected(address(this), amount);
        }
        
        return amount;
    }
    
    function getMarketplaceStats() external view override returns (
        uint256 _totalSales,
        uint256 _totalVolume,
        uint256 _totalFees
    ) {
        return (totalSales, totalVolume, totalFees);
    }
    
    // ============ ANALYTICS FUNCTIONS ============
    
    function getPlayerStats(address player) external view override returns (
        uint256 charactersOwned,
        uint256 totalSpent,
        uint256 totalEarned,
        uint256 guildRevenueEarned
    ) {
        return (
            playerStats_charactersOwned[player],
            playerStats_totalSpent[player],
            playerStats_totalEarned[player],
            playerStats_guildRevenue[player]
        );
    }
    
    function getPlatformStats() external view override returns (
        uint256 _totalPlayers,
        uint256 _totalCharacters,
        uint256 _totalRevenue,
        uint256 _activeGuilds
    ) {
        return (totalPlayers, totalCharacters, totalRevenue, activeGuilds);
    }
    
    // ============ ADMIN FUNCTIONS ============
    
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
            require(withdrawAmount <= balance, "SillyHotelPlatform: insufficient ETH balance");
            
            (bool success, ) = msg.sender.call{value: withdrawAmount}("");
            require(success, "SillyHotelPlatform: ETH withdrawal failed");
        } else {
            // Withdraw ERC-20 tokens
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            uint256 withdrawAmount = (amount == 0) ? balance : amount;
            require(withdrawAmount <= balance, "SillyHotelPlatform: insufficient token balance");
            
            require(tokenContract.transfer(msg.sender, withdrawAmount), "SillyHotelPlatform: token withdrawal failed");
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
        // Accept ETH deposits for game purchases
    }
}
