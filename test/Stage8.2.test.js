const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 8.2 - Platform Application Integration", function() {
    let deployer, user1, user2, user3, admin, verifier, gameManager;
    let karmaToken, feeRouter;
    let sillyPortPlatform, sillyHotelPlatform, karmaLabsAssetPlatform;
    let aiInferencePayment, metadataStorage;

    beforeEach(async function() {
        [deployer, user1, user2, user3, admin, verifier, gameManager] = await ethers.getSigners();

        // Deploy KarmaToken (mock)
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(
            admin.address, // admin
            ethers.utils.parseEther("1000000000") // 1B initial supply
        );
        await karmaToken.deployed();

        // Deploy Platform Fee Router
        const PlatformFeeRouter = await ethers.getContractFactory("PlatformFeeRouter");
        feeRouter = await PlatformFeeRouter.deploy(
            admin.address,
            karmaToken.address
        );
        await feeRouter.deployed();

        // Deploy mock AI Inference Payment (simplified for testing)
        const MockContract = await ethers.getContractFactory("MockContract");
        aiInferencePayment = await MockContract.deploy();
        await aiInferencePayment.deployed();

        // Deploy mock Metadata Storage (simplified for testing)
        metadataStorage = await MockContract.deploy();
        await metadataStorage.deployed();

        // Deploy SillyPort Platform
        const SillyPortPlatform = await ethers.getContractFactory("SillyPortPlatform");
        sillyPortPlatform = await SillyPortPlatform.deploy(
            admin.address,
            karmaToken.address,
            aiInferencePayment.address,
            metadataStorage.address,
            feeRouter.address
        );
        await sillyPortPlatform.deployed();

        // Deploy SillyHotel Platform
        const SillyHotelPlatform = await ethers.getContractFactory("SillyHotelPlatform");
        sillyHotelPlatform = await SillyHotelPlatform.deploy(
            admin.address,
            karmaToken.address,
            feeRouter.address
        );
        await sillyHotelPlatform.deployed();

        // Deploy KarmaLabs Asset Platform
        const KarmaLabsAssetPlatform = await ethers.getContractFactory("KarmaLabsAssetPlatform");
        karmaLabsAssetPlatform = await KarmaLabsAssetPlatform.deploy(
            admin.address,
            karmaToken.address,
            feeRouter.address
        );
        await karmaLabsAssetPlatform.deployed();

        // Register platforms with fee router
        await feeRouter.connect(admin).registerPlatform(0, sillyPortPlatform.address); // SILLY_PORT
        await feeRouter.connect(admin).registerPlatform(1, sillyHotelPlatform.address); // SILLY_HOTEL
        await feeRouter.connect(admin).registerPlatform(2, karmaLabsAssetPlatform.address); // KARMA_LABS_ASSETS

        // Grant verifier role
        const VERIFIER_ROLE = await karmaLabsAssetPlatform.VERIFIER_ROLE();
        await karmaLabsAssetPlatform.connect(admin).grantRole(VERIFIER_ROLE, verifier.address);

        // Distribute KARMA tokens for testing
        await karmaToken.connect(admin).transfer(user1.address, ethers.utils.parseEther("100000"));
        await karmaToken.connect(admin).transfer(user2.address, ethers.utils.parseEther("50000"));
        await karmaToken.connect(admin).transfer(user3.address, ethers.utils.parseEther("25000"));
    });

    describe("Platform Fee Router", function() {
        it("Should calculate optimal fees with user tiers", async function() {
            const baseAmount = ethers.utils.parseEther("1");
            
            // Basic tier user
            const [optimalFee1, discount1] = await feeRouter.calculateOptimalFee(
                0, // SILLY_PORT
                0, // TRANSACTION
                baseAmount,
                user1.address
            );
            
            expect(optimalFee1).to.be.gt(0);
            expect(discount1).to.equal(0); // Basic tier - no discount initially
        });

        it("Should collect and route fees properly", async function() {
            const baseAmount = ethers.utils.parseEther("1");
            const feeAmount = ethers.utils.parseEther("0.025"); // 2.5%
            
            // Collect fee
            const tx = await feeRouter.connect(admin).collectFee(
                0, // SILLY_PORT
                0, // TRANSACTION
                baseAmount,
                user1.address,
                { value: feeAmount }
            );
            
            const receipt = await tx.wait();
            const feeCollectedEvent = receipt.events?.find(e => e.event === 'FeeCollected');
            expect(feeCollectedEvent).to.not.be.undefined;
            
            const collectionId = feeCollectedEvent.args.collectionId;
            
            // Route fees
            await feeRouter.connect(admin).routeFees([collectionId]);
            
            // Check platform stats
            const [totalCollected, totalRouted] = await feeRouter.getFeeStats(0);
            expect(totalCollected).to.be.gt(0);
        });

        it("Should upgrade user tiers based on spending", async function() {
            // Simulate high spending to trigger tier upgrade
            const highSpendAmount = ethers.utils.parseEther("100");
            const feeAmount = ethers.utils.parseEther("2.5");
            
            await feeRouter.connect(admin).collectFee(
                0, // SILLY_PORT
                0, // TRANSACTION
                highSpendAmount,
                user1.address,
                { value: feeAmount }
            );
            
            const profile = await feeRouter.getUserFeeProfile(user1.address);
            expect(profile.totalSpent).to.be.gt(0);
        });
    });

    describe("SillyPort Platform", function() {
        beforeEach(async function() {
            // Approve KARMA spending
            await karmaToken.connect(user1).approve(sillyPortPlatform.address, ethers.utils.parseEther("10000"));
            await karmaToken.connect(user2).approve(sillyPortPlatform.address, ethers.utils.parseEther("10000"));
        });

        it("Should handle subscription management", async function() {
            const monthlyFee = ethers.utils.parseEther("0.015"); // $15 worth
            
            // Subscribe to premium tier
            await sillyPortPlatform.connect(user1).subscribe(2, { value: monthlyFee }); // PREMIUM
            
            const subscription = await sillyPortPlatform.getSubscription(user1.address);
            expect(subscription.tier).to.equal(2); // PREMIUM
            expect(subscription.isActive).to.be.true;
            
            // Check subscription access
            const hasAccess = await sillyPortPlatform.hasActiveSubscription(user1.address, 2);
            expect(hasAccess).to.be.true;
        });

        it("Should process iNFT mint requests", async function() {
            // Subscribe first
            const monthlyFee = ethers.utils.parseEther("0.005");
            await sillyPortPlatform.connect(user1).subscribe(1, { value: monthlyFee }); // BASIC
            
            // Request iNFT mint
            const tx = await sillyPortPlatform.connect(user1).requestINFTMint(
                "A beautiful AI landscape",
                0, // AI_CHAT_SESSION
                "dall-e-3"
            );
            
            const receipt = await tx.wait();
            const mintRequestEvent = receipt.events?.find(e => e.event === 'INFTMintRequested');
            expect(mintRequestEvent).to.not.be.undefined;
            
            const requestId = mintRequestEvent.args.requestId;
            const mintRequest = await sillyPortPlatform.getINFTMintRequest(requestId);
            expect(mintRequest.requester).to.equal(user1.address);
            expect(mintRequest.prompt).to.equal("A beautiful AI landscape");
        });

        it("Should manage AI chat sessions", async function() {
            // Subscribe first
            const monthlyFee = ethers.utils.parseEther("0.005");
            await sillyPortPlatform.connect(user1).subscribe(1, { value: monthlyFee });
            
            // Start chat session
            const sessionId = await sillyPortPlatform.connect(user1).callStatic.startAIChatSession(0);
            await sillyPortPlatform.connect(user1).startAIChatSession(0);
            
            const session = await sillyPortPlatform.getAIChatSession(sessionId);
            expect(session.user).to.equal(user1.address);
            expect(session.isActive).to.be.true;
            
            // Process chat message
            await sillyPortPlatform.connect(user1).processAIChatMessage(
                sessionId,
                "Hello AI!",
                100 // tokens used
            );
            
            // End session
            await sillyPortPlatform.connect(user1).endAIChatSession(sessionId);
        });

        it("Should handle premium feature access", async function() {
            // Subscribe to premium
            const monthlyFee = ethers.utils.parseEther("0.015");
            await sillyPortPlatform.connect(user1).subscribe(2, { value: monthlyFee });
            
            // Access premium feature
            await sillyPortPlatform.connect(user1).accessPremiumFeature(1); // Advanced AI Models
            
            const hasAccess = await sillyPortPlatform.checkPremiumAccess(user1.address, 1);
            expect(hasAccess).to.be.true;
        });

        it("Should manage user generated content", async function() {
            // Create content
            const contentId = await sillyPortPlatform.connect(user1).callStatic.createUserContent(
                2, // USER_CONTENT
                "ipfs://QmContent123",
                0, // PUBLIC
                0  // No KARMA required
            );
            
            await sillyPortPlatform.connect(user1).createUserContent(
                2, // USER_CONTENT
                "ipfs://QmContent123",
                0, // PUBLIC
                0  // No KARMA required
            );
            
            const content = await sillyPortPlatform.getUserContent(contentId);
            expect(content.creator).to.equal(user1.address);
            expect(content.contentURI).to.equal("ipfs://QmContent123");
            
            // Access content
            const contentURI = await sillyPortPlatform.connect(user2).accessUserContent(contentId);
            expect(contentURI).to.equal("ipfs://QmContent123");
        });
    });

    describe("SillyHotel Platform", function() {
        beforeEach(async function() {
            await karmaToken.connect(user1).approve(sillyHotelPlatform.address, ethers.utils.parseEther("10000"));
            await karmaToken.connect(user2).approve(sillyHotelPlatform.address, ethers.utils.parseEther("10000"));
        });

        it("Should handle game item purchases", async function() {
            const itemPrice = ethers.utils.parseEther("0.01");
            
            // Purchase character with ETH
            await sillyHotelPlatform.connect(user1).purchaseGameItem(1, 1, { value: itemPrice });
            
            const item = await sillyHotelPlatform.getGameItem(1);
            expect(item.currentSupply).to.equal(1);
            
            // Purchase with KARMA
            await sillyHotelPlatform.connect(user1).purchaseGameItemWithKarma(2, 1); // Basic Sword
            
            const swordItem = await sillyHotelPlatform.getGameItem(2);
            expect(swordItem.currentSupply).to.equal(1);
        });

        it("Should mint and manage character NFTs", async function() {
            const mintCost = ethers.utils.parseEther("0.01");
            
            // Mint character
            const tokenId = await sillyHotelPlatform.connect(user1).callStatic.mintCharacter(
                0, // COMMON
                "TestCharacter"
            );
            
            await sillyHotelPlatform.connect(user1).mintCharacter(
                0, // COMMON
                "TestCharacter",
                { value: mintCost }
            );
            
            const character = await sillyHotelPlatform.getCharacter(tokenId);
            expect(character.owner).to.equal(user1.address);
            expect(character.name).to.equal("TestCharacter");
            expect(character.rarity).to.equal(0); // COMMON
        });

        it("Should handle character trading", async function() {
            const mintCost = ethers.utils.parseEther("0.01");
            const salePrice = ethers.utils.parseEther("0.02");
            
            // Mint character
            const tokenId = await sillyHotelPlatform.connect(user1).callStatic.mintCharacter(0, "TradeChar");
            await sillyHotelPlatform.connect(user1).mintCharacter(0, "TradeChar", { value: mintCost });
            
            // List for sale
            await sillyHotelPlatform.connect(user1).listCharacterForSale(tokenId, salePrice);
            
            const character = await sillyHotelPlatform.getCharacter(tokenId);
            expect(character.isForSale).to.be.true;
            expect(character.salePrice).to.equal(salePrice);
            
            // Buy character
            await sillyHotelPlatform.connect(user2).buyCharacter(tokenId, { value: salePrice });
            
            // Verify ownership transfer
            const newOwner = await sillyHotelPlatform.ownerOf(tokenId);
            expect(newOwner).to.equal(user2.address);
        });

        it("Should handle character rentals", async function() {
            const mintCost = ethers.utils.parseEther("0.01");
            const dailyRate = ethers.utils.parseEther("0.001");
            
            // Mint character
            const tokenId = await sillyHotelPlatform.connect(user1).callStatic.mintCharacter(0, "RentChar");
            await sillyHotelPlatform.connect(user1).mintCharacter(0, "RentChar", { value: mintCost });
            
            // List for rent
            await sillyHotelPlatform.connect(user1).listCharacterForRent(tokenId, dailyRate);
            
            // Rent character
            const rentalCost = dailyRate.mul(3); // 3 days
            const agreementId = await sillyHotelPlatform.connect(user2).callStatic.rentCharacter(tokenId, 3);
            await sillyHotelPlatform.connect(user2).rentCharacter(tokenId, 3, { value: rentalCost });
            
            const agreement = await sillyHotelPlatform.getRentalAgreement(agreementId);
            expect(agreement.renter).to.equal(user2.address);
            expect(agreement.isActive).to.be.true;
        });

        it("Should manage guilds", async function() {
            // Create guild
            const guildId = await sillyHotelPlatform.connect(user1).callStatic.createGuild("TestGuild", 2000);
            await sillyHotelPlatform.connect(user1).createGuild("TestGuild", 2000);
            
            const [name, leader, memberCount] = await sillyHotelPlatform.getGuildInfo(guildId);
            expect(leader).to.equal(user1.address);
            expect(memberCount).to.equal(1);
            
            // Join guild
            await sillyHotelPlatform.connect(user2).joinGuild(guildId);
            
            const [, , newMemberCount] = await sillyHotelPlatform.getGuildInfo(guildId);
            expect(newMemberCount).to.equal(2);
        });
    });

    describe("KarmaLabs Asset Platform", function() {
        beforeEach(async function() {
            await karmaToken.connect(user1).approve(karmaLabsAssetPlatform.address, ethers.utils.parseEther("10000"));
            await karmaToken.connect(user2).approve(karmaLabsAssetPlatform.address, ethers.utils.parseEther("10000"));
        });

        it("Should create and manage assets", async function() {
            // Create asset
            const assetId = await karmaLabsAssetPlatform.connect(user1).callStatic.createAsset(
                0, // AI_ART
                "AI Generated Artwork",
                "Beautiful AI-created digital art",
                "ipfs://QmMetadata123",
                "ipfs://QmAsset123",
                500, // 5% royalty
                "dall-e-3",
                "Create a beautiful landscape"
            );
            
            await karmaLabsAssetPlatform.connect(user1).createAsset(
                0, // AI_ART
                "AI Generated Artwork",
                "Beautiful AI-created digital art",
                "ipfs://QmMetadata123",
                "ipfs://QmAsset123",
                500, // 5% royalty
                "dall-e-3",
                "Create a beautiful landscape"
            );
            
            const asset = await karmaLabsAssetPlatform.getAsset(assetId);
            expect(asset.creator).to.equal(user1.address);
            expect(asset.title).to.equal("AI Generated Artwork");
            expect(asset.assetType).to.equal(0); // AI_ART
        });

        it("Should handle asset verification", async function() {
            // Create asset
            const assetId = await karmaLabsAssetPlatform.connect(user1).callStatic.createAsset(
                0, // AI_ART
                "Test Asset",
                "Test Description",
                "ipfs://QmTest",
                "ipfs://QmTestAsset",
                300,
                "gpt-4",
                "Test prompt"
            );
            
            await karmaLabsAssetPlatform.connect(user1).createAsset(
                0, "Test Asset", "Test Description", "ipfs://QmTest", "ipfs://QmTestAsset", 300, "gpt-4", "Test prompt"
            );
            
            // Submit for verification
            const verificationId = await karmaLabsAssetPlatform.connect(user1).callStatic.submitForVerification(
                assetId,
                "AI Model Hash Verification"
            );
            
            await karmaLabsAssetPlatform.connect(user1).submitForVerification(assetId, "AI Model Hash Verification");
            
            // Verify asset
            await karmaLabsAssetPlatform.connect(verifier).verifyAsset(
                verificationId,
                1, // VERIFIED
                "Asset verified successfully"
            );
            
            const asset = await karmaLabsAssetPlatform.getAsset(assetId);
            expect(asset.verificationStatus).to.equal(1); // VERIFIED
            expect(asset.isAuthentic).to.be.true;
        });

        it("Should handle marketplace listings and sales", async function() {
            // Create and verify asset
            const assetId = await karmaLabsAssetPlatform.connect(user1).callStatic.createAsset(
                1, // AI_MUSIC
                "AI Music Track",
                "Electronic music generated by AI",
                "ipfs://QmMusic",
                "ipfs://QmMusicFile",
                1000, // 10% royalty
                "musicgen",
                "Create electronic music"
            );
            
            await karmaLabsAssetPlatform.connect(user1).createAsset(
                1, "AI Music Track", "Electronic music generated by AI", "ipfs://QmMusic", "ipfs://QmMusicFile", 1000, "musicgen", "Create electronic music"
            );
            
            // Submit for verification
            const verificationId = await karmaLabsAssetPlatform.connect(user1).callStatic.submitForVerification(assetId, "AI Verification");
            await karmaLabsAssetPlatform.connect(user1).submitForVerification(assetId, "AI Verification");
            
            // Verify asset
            await karmaLabsAssetPlatform.connect(verifier).verifyAsset(verificationId, 1, "Verified");
            
            // List asset
            const price = ethers.utils.parseEther("0.1");
            const listingId = await karmaLabsAssetPlatform.connect(user1).callStatic.listAsset(
                assetId,
                price,
                1, // COMMERCIAL
                0  // No expiration
            );
            
            await karmaLabsAssetPlatform.connect(user1).listAsset(assetId, price, 1, 0);
            
            const listing = await karmaLabsAssetPlatform.getListing(listingId);
            expect(listing.seller).to.equal(user1.address);
            expect(listing.price).to.equal(price);
            
            // Purchase asset
            await karmaLabsAssetPlatform.connect(user2).purchaseAsset(listingId, { value: price });
            
            const updatedListing = await karmaLabsAssetPlatform.getListing(listingId);
            expect(updatedListing.status).to.equal(2); // SOLD
        });

        it("Should handle royalty distribution", async function() {
            // Create asset with royalties
            const assetId = await karmaLabsAssetPlatform.connect(user1).callStatic.createAsset(
                2, // AI_VIDEO
                "AI Video",
                "AI generated video content",
                "ipfs://QmVideo",
                "ipfs://QmVideoFile",
                800, // 8% royalty
                "runway",
                "Create a video"
            );
            
            await karmaLabsAssetPlatform.connect(user1).createAsset(
                2, "AI Video", "AI generated video content", "ipfs://QmVideo", "ipfs://QmVideoFile", 800, "runway", "Create a video"
            );
            
            const royaltyInfo = await karmaLabsAssetPlatform.getRoyaltyInfo(assetId);
            expect(royaltyInfo.creator).to.equal(user1.address);
            expect(royaltyInfo.percentage).to.equal(800);
        });

        it("Should handle creator profiles", async function() {
            // Create creator profile
            await karmaLabsAssetPlatform.connect(user1).createCreatorProfile(
                "Test Creator",
                "I create AI art",
                "ipfs://QmProfile"
            );
            
            const profile = await karmaLabsAssetPlatform.getCreatorProfile(user1.address);
            expect(profile.name).to.equal("Test Creator");
            expect(profile.bio).to.equal("I create AI art");
            
            // Verify creator
            await karmaLabsAssetPlatform.connect(verifier).verifyCreator(user1.address);
            
            const updatedProfile = await karmaLabsAssetPlatform.getCreatorProfile(user1.address);
            expect(updatedProfile.isVerified).to.be.true;
        });

        it("Should handle bulk operations", async function() {
            // Create multiple assets first
            const assetIds = [];
            const prices = [];
            const licenseTypes = [];
            
            for (let i = 0; i < 3; i++) {
                const assetId = await karmaLabsAssetPlatform.connect(user1).callStatic.createAsset(
                    0, `Asset ${i}`, `Description ${i}`, `ipfs://meta${i}`, `ipfs://asset${i}`, 500, "ai-model", "prompt"
                );
                
                await karmaLabsAssetPlatform.connect(user1).createAsset(
                    0, `Asset ${i}`, `Description ${i}`, `ipfs://meta${i}`, `ipfs://asset${i}`, 500, "ai-model", "prompt"
                );
                
                assetIds.push(assetId);
                prices.push(ethers.utils.parseEther("0.01"));
                licenseTypes.push(1); // COMMERCIAL
            }
            
            // Bulk list assets
            const operationId = await karmaLabsAssetPlatform.connect(user1).callStatic.bulkListAssets(
                assetIds,
                prices,
                licenseTypes
            );
            
            await karmaLabsAssetPlatform.connect(user1).bulkListAssets(assetIds, prices, licenseTypes);
            
            const operation = await karmaLabsAssetPlatform.getBulkOperation(operationId);
            expect(operation.operator).to.equal(user1.address);
            expect(operation.isCompleted).to.be.true;
        });
    });

    describe("Integration Tests", function() {
        it("Should integrate all platforms with fee router", async function() {
            // Test SillyPort integration
            const monthlyFee = ethers.utils.parseEther("0.005");
            await sillyPortPlatform.connect(user1).subscribe(1, { value: monthlyFee });
            
            // Test SillyHotel integration
            const itemPrice = ethers.utils.parseEther("0.01");
            await sillyHotelPlatform.connect(user1).purchaseGameItem(1, 1, { value: itemPrice });
            
            // Test KarmaLabs integration
            await karmaToken.connect(user1).approve(karmaLabsAssetPlatform.address, ethers.utils.parseEther("1000"));
            
            const assetId = await karmaLabsAssetPlatform.connect(user1).callStatic.createAsset(
                0, "Integration Test", "Test asset", "ipfs://test", "ipfs://testasset", 500, "test-ai", "test prompt"
            );
            await karmaLabsAssetPlatform.connect(user1).createAsset(
                0, "Integration Test", "Test asset", "ipfs://test", "ipfs://testasset", 500, "test-ai", "test prompt"
            );
            
            // Verify fee collection across platforms
            const sillyPortStats = await feeRouter.getFeeStats(0); // SILLY_PORT
            const sillyHotelStats = await feeRouter.getFeeStats(1); // SILLY_HOTEL
            
            expect(sillyPortStats.totalCollected).to.be.gt(0);
            expect(sillyHotelStats.totalCollected).to.be.gt(0);
        });

        it("Should demonstrate cross-platform user tier benefits", async function() {
            // Simulate spending across platforms to upgrade tier
            const highValue = ethers.utils.parseEther("1");
            const highFee = ethers.utils.parseEther("0.025");
            
            // Collect high fees to upgrade tier
            await feeRouter.connect(admin).collectFee(0, 0, highValue, user1.address, { value: highFee });
            await feeRouter.connect(admin).collectFee(1, 0, highValue, user1.address, { value: highFee });
            
            // Check tier upgrade
            const newTier = await feeRouter.connect(user1).updateUserTier(user1.address);
            const profile = await feeRouter.getUserFeeProfile(user1.address);
            
            expect(profile.totalSpent).to.be.gt(0);
        });

        it("Should handle platform analytics and reporting", async function() {
            // Generate activity across platforms
            await sillyPortPlatform.connect(user1).subscribe(1, { value: ethers.utils.parseEther("0.005") });
            await sillyHotelPlatform.connect(user1).purchaseGameItem(1, 1, { value: ethers.utils.parseEther("0.01") });
            
            // Check platform statistics
            const [totalUsers, activeSubscriptions, totalRevenue, inftsMinted] = await sillyPortPlatform.getPlatformStats();
            const [totalPlayers, totalCharacters, gameRevenue, activeGuilds] = await sillyHotelPlatform.getPlatformStats();
            const [totalAssets, totalSales, totalVolume, totalCreators] = await karmaLabsAssetPlatform.getPlatformStats();
            
            expect(totalUsers).to.be.gt(0);
            expect(totalPlayers).to.be.gt(0);
            expect(totalCreators).to.be.gt(0);
        });
    });

    describe("Admin and Emergency Functions", function() {
        it("Should handle emergency functions", async function() {
            // Test platform pausing
            await sillyPortPlatform.connect(admin).pause();
            
            await expect(
                sillyPortPlatform.connect(user1).subscribe(1, { value: ethers.utils.parseEther("0.005") })
            ).to.be.revertedWith("Pausable: paused");
            
            await sillyPortPlatform.connect(admin).unpause();
        });

        it("Should handle fee configuration updates", async function() {
            const newFeeConfig = {
                basePercentage: 300, // 3%
                minimumFee: ethers.utils.parseEther("0.002"),
                maximumFee: ethers.utils.parseEther("2"),
                isActive: true,
                lastUpdated: 0
            };
            
            await feeRouter.connect(admin).configureFee(0, 0, newFeeConfig);
            
            const updatedConfig = await feeRouter.getFeeConfig(0, 0);
            expect(updatedConfig.basePercentage).to.equal(300);
        });

        it("Should handle emergency withdrawals", async function() {
            // Add some ETH to contracts first
            await feeRouter.connect(admin).collectFee(
                0, 0, ethers.utils.parseEther("1"), user1.address, 
                { value: ethers.utils.parseEther("0.025") }
            );
            
            const balanceBefore = await admin.getBalance();
            await feeRouter.connect(admin).emergencyWithdraw(0);
            const balanceAfter = await admin.getBalance();
            
            expect(balanceAfter).to.be.gt(balanceBefore);
        });
    });
});
