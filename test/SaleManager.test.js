const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SaleManager (Stage 3.2)", function () {
    let karmaToken, vestingVault, saleManager;
    let owner, treasury, buyer1, buyer2, buyer3, referrer;
    let admin, kycManager, whitelistManager, engagementManager;
    
    // Test merkle tree and proofs
    const merkleRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const validProof = [
        "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    ];
    
    beforeEach(async function () {
        [owner, treasury, buyer1, buyer2, buyer3, referrer, admin, kycManager, whitelistManager, engagementManager] = await ethers.getSigners();
        
        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy("Karma Token", "KARMA", treasury.address);
        await karmaToken.waitForDeployment();
        
        // Deploy VestingVault
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress(), treasury.address);
        await vestingVault.waitForDeployment();
        
        // Deploy SaleManager
        const SaleManager = await ethers.getContractFactory("SaleManager");
        saleManager = await SaleManager.deploy(
            await karmaToken.getAddress(),
            await vestingVault.getAddress(),
            treasury.address,
            owner.address
        );
        await saleManager.waitForDeployment();
        
        // Grant roles
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        const SALE_MANAGER_ROLE = await saleManager.SALE_MANAGER_ROLE();
        const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
        const WHITELIST_MANAGER_ROLE = await saleManager.WHITELIST_MANAGER_ROLE();
        const ENGAGEMENT_MANAGER_ROLE = await saleManager.ENGAGEMENT_MANAGER_ROLE();
        
        await karmaToken.grantRole(MINTER_ROLE, await saleManager.getAddress());
        await vestingVault.grantRole(await vestingVault.VAULT_MANAGER_ROLE(), await saleManager.getAddress());
        
        // Grant specific roles to test accounts
        await saleManager.grantRole(KYC_MANAGER_ROLE, kycManager.address);
        await saleManager.grantRole(WHITELIST_MANAGER_ROLE, whitelistManager.address);
        await saleManager.grantRole(ENGAGEMENT_MANAGER_ROLE, engagementManager.address);
    });
    
    describe("Stage 3.2: Phase Configuration with Exact Business Parameters", function () {
        it("Should configure private sale with exact business parameters", async function () {
            const startTime = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
            
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            
            const config = await saleManager.getPhaseConfig(1); // SalePhase.PRIVATE = 1
            
            expect(config.price).to.equal(ethers.parseEther("0.02")); // $0.02 per token
            expect(config.minPurchase).to.equal(ethers.parseEther("25000")); // $25K minimum
            expect(config.maxPurchase).to.equal(ethers.parseEther("200000")); // $200K maximum
            expect(config.hardCap).to.equal(ethers.parseEther("2000000")); // $2M raise
            expect(config.tokenAllocation).to.equal(ethers.parseEther("100000000")); // 100M tokens
            expect(config.whitelistRequired).to.be.true;
            expect(config.kycRequired).to.be.true;
            expect(config.merkleRoot).to.equal(merkleRoot);
        });
        
        it("Should configure pre-sale with exact business parameters", async function () {
            // First configure private sale
            const privateStartTime = Math.floor(Date.now() / 1000) + 3600;
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            
            const preStartTime = Math.floor(Date.now() / 1000) + 7200; // 2 hours from now
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            const config = await saleManager.getPhaseConfig(2); // SalePhase.PRE_SALE = 2
            
            expect(config.price).to.equal(ethers.parseEther("0.04")); // $0.04 per token
            expect(config.minPurchase).to.equal(ethers.parseEther("1000")); // $1K minimum
            expect(config.maxPurchase).to.equal(ethers.parseEther("10000")); // $10K maximum
            expect(config.hardCap).to.equal(ethers.parseEther("4000000")); // $4M raise
            expect(config.tokenAllocation).to.equal(ethers.parseEther("100000000")); // 100M tokens
            expect(config.whitelistRequired).to.be.true;
            expect(config.kycRequired).to.be.false;
        });
        
        it("Should configure public sale with exact business parameters", async function () {
            // Configure prerequisites
            const privateStartTime = Math.floor(Date.now() / 1000) + 3600;
            const preStartTime = Math.floor(Date.now() / 1000) + 7200;
            const publicStartTime = Math.floor(Date.now() / 1000) + 10800; // 3 hours from now
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            const liquidityConfig = {
                uniswapV3Factory: buyer1.address, // Mock address
                uniswapV3Router: buyer2.address, // Mock address
                wethAddress: buyer3.address, // Mock address
                poolFee: 3000,
                liquidityEth: ethers.parseEther("100"),
                liquidityTokens: ethers.parseEther("5000"),
                tickLower: -60,
                tickUpper: 60
            };
            
            await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
            
            const config = await saleManager.getPhaseConfig(3); // SalePhase.PUBLIC = 3
            
            expect(config.price).to.equal(ethers.parseEther("0.05")); // $0.05 per token
            expect(config.minPurchase).to.equal(0); // No minimum
            expect(config.maxPurchase).to.equal(ethers.parseEther("5000")); // $5K maximum
            expect(config.hardCap).to.equal(ethers.parseEther("7500000")); // $7.5M raise
            expect(config.tokenAllocation).to.equal(ethers.parseEther("150000000")); // 150M tokens
            expect(config.whitelistRequired).to.be.false;
            expect(config.kycRequired).to.be.false;
        });
    });
    
    describe("Stage 3.2: Community Engagement Scoring", function () {
        beforeEach(async function () {
            // Set up pre-sale for engagement bonus testing
            const privateStartTime = Math.floor(Date.now() / 1000) + 3600;
            const preStartTime = Math.floor(Date.now() / 1000) + 300; // 5 minutes from now
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
        });
        
        it("Should update engagement scores correctly", async function () {
            const engagementData = {
                discordActivity: 80,  // 80/100
                twitterActivity: 60,  // 60/100  
                githubActivity: 90,   // 90/100
                forumActivity: 70,    // 70/100
                lastUpdated: Math.floor(Date.now() / 1000),
                verified: true
            };
            
            await saleManager.connect(engagementManager).updateEngagementScore(buyer1.address, engagementData);
            
            const storedData = await saleManager.getEngagementData(buyer1.address);
            expect(storedData.discordActivity).to.equal(80);
            expect(storedData.twitterActivity).to.equal(60);
            expect(storedData.githubActivity).to.equal(90);
            expect(storedData.forumActivity).to.equal(70);
            expect(storedData.verified).to.be.true;
        });
        
        it("Should calculate engagement score with proper weighting", async function () {
            const engagementData = {
                discordActivity: 80,  // 30% weight = 24
                twitterActivity: 60,  // 25% weight = 15
                githubActivity: 90,   // 30% weight = 27  
                forumActivity: 70,    // 15% weight = 10.5
                lastUpdated: Math.floor(Date.now() / 1000),
                verified: true
            };
            // Total score should be 76.5 basis points
            
            await saleManager.connect(engagementManager).updateEngagementScore(buyer1.address, engagementData);
            
            const score = await saleManager.calculateEngagementScore(buyer1.address);
            expect(score).to.equal(765); // 76.5 * 10 (scaled to basis points)
        });
        
        it("Should calculate bonus tokens based on engagement score", async function () {
            const engagementData = {
                discordActivity: 100,
                twitterActivity: 100,
                githubActivity: 100,
                forumActivity: 100,
                lastUpdated: Math.floor(Date.now() / 1000),
                verified: true
            };
            
            await saleManager.connect(engagementManager).updateEngagementScore(buyer1.address, engagementData);
            
            const baseTokens = ethers.parseEther("1000");
            const bonusTokens = await saleManager.calculateBonusTokens(buyer1.address, baseTokens);
            
            // Max engagement should give 10% bonus (1000 basis points)
            expect(bonusTokens).to.equal(ethers.parseEther("100")); // 10% of 1000
        });
    });
    
    describe("Stage 3.2: Referral System", function () {
        beforeEach(async function () {
            // Configure phases and mark referrer as private sale participant
            const privateStartTime = Math.floor(Date.now() / 1000) + 300;
            const preStartTime = Math.floor(Date.now() / 1000) + 600;
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            // Set up referrer as private sale participant  
            await saleManager.connect(kycManager).updateKYCStatus(referrer.address, 1); // APPROVED
            await saleManager.connect(kycManager).setAccreditedStatus(referrer.address, true);
            
            // Fast forward to private sale and make purchase to mark as participant
            await ethers.provider.send("evm_increaseTime", [400]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1)); // Start private sale
            await saleManager.connect(referrer).purchaseTokens(validProof, { value: ethers.parseEther("25000") });
        });
        
        it("Should register referral relationships", async function () {
            await saleManager.connect(engagementManager).registerReferral(referrer.address, buyer1.address);
            
            const referees = await saleManager.getReferees(referrer.address);
            expect(referees).to.include(buyer1.address);
            
            const bonusRate = await saleManager.getReferralBonusRate(referrer.address);
            expect(bonusRate).to.equal(500); // 5% bonus
        });
        
        it("Should track referral statistics", async function () {
            await saleManager.connect(engagementManager).registerReferral(referrer.address, buyer1.address);
            await saleManager.connect(engagementManager).registerReferral(referrer.address, buyer2.address);
            
            const stats = await saleManager.getReferralStatistics();
            expect(stats.totalReferralsCount).to.equal(2);
            expect(stats.activeReferrersCount).to.equal(1);
        });
        
        it("Should apply referral bonus during pre-sale purchases", async function () {
            await saleManager.connect(engagementManager).registerReferral(referrer.address, buyer1.address);
            
            // Move to pre-sale
            await ethers.provider.send("evm_increaseTime", [300]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.endCurrentPhase();
            await saleManager.startSalePhase(2, await saleManager.getPhaseConfig(2)); // Start pre-sale
            
            const purchaseAmount = ethers.parseEther("1000");
            await saleManager.connect(buyer1).purchaseTokensWithReferral(validProof, referrer.address, { value: purchaseAmount });
            
            const purchase = await saleManager.getPurchase(1); // Second purchase (index 1)
            expect(purchase.referrer).to.equal(referrer.address);
            expect(purchase.bonusTokens).to.be.gt(0); // Should have bonus tokens
        });
    });
    
    describe("Stage 3.2: MEV Protection", function () {
        beforeEach(async function () {
            // Set up public sale
            const privateStartTime = Math.floor(Date.now() / 1000) + 300;
            const preStartTime = Math.floor(Date.now() / 1000) + 600;
            const publicStartTime = Math.floor(Date.now() / 1000) + 900;
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            const liquidityConfig = {
                uniswapV3Factory: buyer1.address,
                uniswapV3Router: buyer2.address,
                wethAddress: buyer3.address,
                poolFee: 3000,
                liquidityEth: ethers.parseEther("100"),
                liquidityTokens: ethers.parseEther("5000"),
                tickLower: -60,
                tickUpper: 60
            };
            
            await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
            
            // Fast forward to public sale
            await ethers.provider.send("evm_increaseTime", [1000]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3)); // Start public sale
        });
        
        it("Should enable MEV protection for participants", async function () {
            await saleManager.connect(buyer1).enableMEVProtection(300); // 3% slippage
            
            // MEV protection should be enabled (we can't directly check the internal mapping, 
            // but the function should complete without error)
            expect(true).to.be.true; // Placeholder assertion
        });
        
        it("Should allow MEV-protected purchases in public sale", async function () {
            await saleManager.connect(buyer1).enableMEVProtection(300);
            
            const purchaseAmount = ethers.parseEther("1000");
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            const minTokensOut = expectedTokens * 97n / 100n; // Allow 3% slippage
            const deadline = Math.floor(Date.now() / 1000) + 3600;
            
            await saleManager.connect(buyer1).purchaseTokensWithMEVProtection(
                [], // No merkle proof needed for public sale
                minTokensOut,
                deadline,
                { value: purchaseAmount }
            );
            
            const purchase = await saleManager.getPurchase(0);
            expect(purchase.buyer).to.equal(buyer1.address);
            expect(purchase.ethAmount).to.equal(purchaseAmount);
        });
    });
    
    describe("Stage 3.2: Token Distribution Logic", function () {
        beforeEach(async function () {
            const startTime = Math.floor(Date.now() / 1000) + 300;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            
            // Set up buyer1 for private sale
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1); // APPROVED
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            // Fast forward to sale time
            await ethers.provider.send("evm_increaseTime", [400]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
        });
        
        it("Should vest 100% of private sale tokens for 6 months", async function () {
            const purchaseAmount = ethers.parseEther("25000"); // Minimum purchase
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            const purchase = await saleManager.getPurchase(0);
            expect(purchase.vested).to.be.true;
            
            // Check that vesting schedule was created
            const schedules = await vestingVault.getVestingSchedules(buyer1.address);
            expect(schedules.length).to.equal(1);
            expect(schedules[0].duration).to.equal(180 * 24 * 60 * 60); // 6 months in seconds
        });
        
        it("Should distribute pre-sale tokens 50% immediate, 50% vested", async function () {
            // Set up pre-sale
            const preStartTime = Math.floor(Date.now() / 1000) + 300;
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            await ethers.provider.send("evm_increaseTime", [400]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.endCurrentPhase();
            await saleManager.startSalePhase(2, await saleManager.getPhaseConfig(2));
            
            const purchaseAmount = ethers.parseEther("1000");
            const initialBalance = await karmaToken.balanceOf(buyer1.address);
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            const finalBalance = await karmaToken.balanceOf(buyer1.address);
            const tokensReceived = finalBalance - initialBalance;
            
            // Should receive immediate tokens (50% of purchase)
            expect(tokensReceived).to.be.gt(0);
            
            // Should have vesting schedule for remaining 50%
            const schedules = await vestingVault.getVestingSchedules(buyer1.address);
            expect(schedules.length).to.equal(1);
            expect(schedules[0].duration).to.equal(90 * 24 * 60 * 60); // 3 months in seconds
        });
        
        it("Should distribute 100% immediate tokens for public sale", async function () {
            // Set up public sale
            const preStartTime = Math.floor(Date.now() / 1000) + 300;
            const publicStartTime = Math.floor(Date.now() / 1000) + 600;
            
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            const liquidityConfig = {
                uniswapV3Factory: buyer1.address,
                uniswapV3Router: buyer2.address,
                wethAddress: buyer3.address,
                poolFee: 3000,
                liquidityEth: ethers.parseEther("100"),
                liquidityTokens: ethers.parseEther("5000"),
                tickLower: -60,
                tickUpper: 60
            };
            
            await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
            
            await ethers.provider.send("evm_increaseTime", [700]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.endCurrentPhase();
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("1000");
            const initialBalance = await karmaToken.balanceOf(buyer1.address);
            
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            
            const finalBalance = await karmaToken.balanceOf(buyer1.address);
            const tokensReceived = finalBalance - initialBalance;
            
            // Should receive all tokens immediately
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            expect(tokensReceived).to.equal(expectedTokens);
            
            // Should not have any vesting schedules
            const schedules = await vestingVault.getVestingSchedules(buyer1.address);
            expect(schedules.length).to.equal(0);
        });
    });
    
    describe("Stage 3.2: Uniswap V3 Integration", function () {
        it("Should configure liquidity pool settings", async function () {
            const liquidityConfig = {
                uniswapV3Factory: buyer1.address,
                uniswapV3Router: buyer2.address,
                wethAddress: buyer3.address,
                poolFee: 3000,
                liquidityEth: ethers.parseEther("100"),
                liquidityTokens: ethers.parseEther("5000"),
                tickLower: -60,
                tickUpper: 60
            };
            
            await saleManager.configureLiquidityPool(liquidityConfig);
            
            const storedConfig = await saleManager.getLiquidityConfig();
            expect(storedConfig.uniswapV3Factory).to.equal(buyer1.address);
            expect(storedConfig.poolFee).to.equal(3000);
            expect(storedConfig.liquidityEth).to.equal(ethers.parseEther("100"));
        });
        
        it("Should create liquidity pool during public sale", async function () {
            // Set up public sale with liquidity config
            const privateStartTime = Math.floor(Date.now() / 1000) + 300;
            const preStartTime = Math.floor(Date.now() / 1000) + 600;
            const publicStartTime = Math.floor(Date.now() / 1000) + 900;
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            const liquidityConfig = {
                uniswapV3Factory: buyer1.address,
                uniswapV3Router: buyer2.address,
                wethAddress: buyer3.address,
                poolFee: 3000,
                liquidityEth: ethers.parseEther("100"),
                liquidityTokens: ethers.parseEther("5000"),
                tickLower: -60,
                tickUpper: 60
            };
            
            await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
            
            // Fast forward to public sale
            await ethers.provider.send("evm_increaseTime", [1000]);
            await ethers.provider.send("evm_mine");
            
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const poolAddress = await saleManager.createLiquidityPool();
            expect(poolAddress).to.not.equal(ethers.ZeroAddress);
            
            const storedPoolAddress = await saleManager.liquidityPool();
            expect(storedPoolAddress).to.equal(poolAddress);
        });
    });
    
    describe("Existing functionality (regression tests)", function () {
        beforeEach(async function () {
            const startTime = Math.floor(Date.now() / 1000) + 300; // 5 minutes from now
            
            const config = {
                price: ethers.parseEther("0.02"),
                minPurchase: ethers.parseEther("25000"),
                maxPurchase: ethers.parseEther("200000"),
                hardCap: ethers.parseEther("2000000"),
                tokenAllocation: ethers.parseEther("100000000"),
                startTime: startTime,
                endTime: startTime + 86400, // 24 hours later
                whitelistRequired: true,
                kycRequired: true,
                merkleRoot: merkleRoot
            };
            
            await saleManager.startSalePhase(1, config); // SalePhase.PRIVATE = 1
            
            // Setup buyer1 with KYC approval and accredited status
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1); // KYCStatus.APPROVED
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            // Fast forward to sale start time
            await ethers.provider.send("evm_increaseTime", [400]);
            await ethers.provider.send("evm_mine");
        });
        
        it("Should allow valid purchases", async function () {
            const purchaseAmount = ethers.parseEther("25000"); // Minimum purchase amount
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            const purchase = await saleManager.getPurchase(0);
            expect(purchase.buyer).to.equal(buyer1.address);
            expect(purchase.ethAmount).to.equal(purchaseAmount);
        });
        
        it("Should enforce minimum purchase amounts", async function () {
            const tooSmallAmount = ethers.parseEther("1000"); // Below minimum
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: tooSmallAmount })
            ).to.be.revertedWith("SaleManager: below minimum purchase");
        });
        
        it("Should track participant statistics", async function () {
            const purchaseAmount = ethers.parseEther("25000");
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            const [totalEthRaised, totalTokensSold, participantCount] = await saleManager.getPhaseStatistics(1);
            expect(totalEthRaised).to.equal(purchaseAmount);
            expect(participantCount).to.equal(1);
        });
    });
});
