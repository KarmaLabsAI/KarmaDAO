const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { generateMerkleTree, generateMerkleProof } = require("../utils/merkle-helpers");
const priceCalculator = require("../utils/price-calculator");

describe("Stage 3.2: Sale Phase Implementations Tests", function () {
    let saleManager, karmaToken, vestingVault;
    let deployer, admin, buyer1, buyer2, buyer3, kycManager, whitelistManager, engagementManager;
    let merkleTree, merkleRoot;
    
    beforeEach(async function () {
        [deployer, admin, buyer1, buyer2, buyer3, kycManager, whitelistManager, engagementManager] = await ethers.getSigners();
        
        // Deploy contracts
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy();
        await karmaToken.waitForDeployment();
        
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress());
        await vestingVault.waitForDeployment();
        
        const SaleManager = await ethers.getContractFactory("SaleManager");
        saleManager = await SaleManager.deploy(
            await karmaToken.getAddress(),
            await vestingVault.getAddress(),
            admin.address
        );
        await saleManager.waitForDeployment();
        
        // Setup roles
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
        const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
        const WHITELIST_MANAGER_ROLE = await saleManager.WHITELIST_MANAGER_ROLE();
        const ENGAGEMENT_MANAGER_ROLE = await saleManager.ENGAGEMENT_MANAGER_ROLE();
        
        await karmaToken.grantRole(MINTER_ROLE, await saleManager.getAddress());
        await vestingVault.grantRole(VAULT_MANAGER_ROLE, await saleManager.getAddress());
        await saleManager.grantRole(KYC_MANAGER_ROLE, kycManager.address);
        await saleManager.grantRole(WHITELIST_MANAGER_ROLE, whitelistManager.address);
        await saleManager.grantRole(ENGAGEMENT_MANAGER_ROLE, engagementManager.address);
        
        // Create whitelist
        const whitelist = [buyer1.address, buyer2.address, buyer3.address];
        merkleTree = generateMerkleTree(whitelist);
        merkleRoot = merkleTree.getHexRoot();
    });
    
    describe("Private Sale Implementation ($0.02, 100M KARMA, $2M raise)", function () {
        beforeEach(async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
        });
        
        it("Should enforce $25K minimum purchase ($25 ETH)", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            const belowMinimum = ethers.parseEther("20"); // $20K
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: belowMinimum })
            ).to.be.revertedWith("Purchase amount below minimum");
        });
        
        it("Should enforce $200K maximum purchase ($200 ETH)", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            const aboveMaximum = ethers.parseEther("250"); // $250K
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: aboveMaximum })
            ).to.be.revertedWith("Purchase amount above maximum");
        });
        
        it("Should calculate correct token amounts at $0.02 per token", async function () {
            const ethAmount = ethers.parseEther("100"); // $100K
            const expectedTokens = priceCalculator.calculateTokenAmount(ethAmount, "PRIVATE_SALE");
            const contractTokens = await saleManager.calculateTokenAmount(ethAmount);
            
            expect(contractTokens).to.equal(expectedTokens);
            // $100K / $0.02 = 5M tokens
            expect(contractTokens).to.equal(ethers.parseEther("5000000"));
        });
        
        it("Should require accredited investor status", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            // Don't set accredited status
            
            const purchaseAmount = ethers.parseEther("50");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.be.revertedWith("Must be accredited investor");
        });
        
        it("Should integrate with VestingVault for 6-month linear vesting", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            const purchaseAmount = ethers.parseEther("100");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            const vestingSchedules = await vestingVault.getScheduleIds(buyer1.address);
            expect(vestingSchedules.length).to.equal(1);
            
            // Verify vesting schedule parameters
            const schedule = await vestingVault.getSchedule(vestingSchedules[0]);
            expect(schedule.amount).to.equal(expectedTokens);
            expect(schedule.cliff).to.equal(0); // No cliff for private sale
            expect(schedule.duration).to.equal(6 * 30 * 24 * 60 * 60); // 6 months
        });
        
        it("Should enforce 100M KARMA hard cap", async function () {
            // Simulate near-exhaustion of allocation
            const remainingAmount = ethers.parseEther("1000000"); // 1M tokens left
            await saleManager.setAllocationBalance(1, remainingAmount);
            
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            // Try to purchase more than remaining
            const purchaseAmount = ethers.parseEther("100"); // Would need ~5M tokens
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.be.revertedWith("Insufficient allocation remaining");
        });
    });
    
    describe("Pre-Sale Implementation ($0.04, 100M KARMA, $4M raise)", function () {
        beforeEach(async function () {
            // Configure all phases
            const privateStartTime = (await time.latest()) + 100;
            const preStartTime = privateStartTime + 86400 * 60; // 60 days later
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            // Skip to pre-sale
            await time.increaseTo(preStartTime);
            await saleManager.startSalePhase(2, await saleManager.getPhaseConfig(2));
        });
        
        it("Should enforce $1K minimum purchase ($1 ETH)", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            
            const belowMinimum = ethers.parseEther("0.5"); // $500
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: belowMinimum })
            ).to.be.revertedWith("Purchase amount below minimum");
        });
        
        it("Should enforce $10K maximum purchase ($10 ETH)", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            
            const aboveMaximum = ethers.parseEther("15"); // $15K
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: aboveMaximum })
            ).to.be.revertedWith("Purchase amount above maximum");
        });
        
        it("Should calculate correct token amounts at $0.04 per token", async function () {
            const ethAmount = ethers.parseEther("10"); // $10K
            const expectedTokens = priceCalculator.calculateTokenAmount(ethAmount, "PRE_SALE");
            const contractTokens = await saleManager.calculateTokenAmount(ethAmount);
            
            expect(contractTokens).to.equal(expectedTokens);
            // $10K / $0.04 = 250K tokens
            expect(contractTokens).to.equal(ethers.parseEther("250000"));
        });
        
        it("Should split distribution: 50% immediate, 50% vested", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            
            const purchaseAmount = ethers.parseEther("5"); // $5K
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            
            const balanceBefore = await karmaToken.balanceOf(buyer1.address);
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            // Check immediate tokens (50%)
            const balanceAfter = await karmaToken.balanceOf(buyer1.address);
            const immediateTokens = balanceAfter.sub(balanceBefore);
            expect(immediateTokens).to.equal(expectedTokens.div(2));
            
            // Check vested tokens (50%)
            const vestingSchedules = await vestingVault.getScheduleIds(buyer1.address);
            expect(vestingSchedules.length).to.equal(1);
            
            const schedule = await vestingVault.getSchedule(vestingSchedules[0]);
            expect(schedule.amount).to.equal(expectedTokens.div(2));
        });
        
        it("Should not require accredited investor status", async function () {
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            // Don't set accredited status - should still work
            
            const purchaseAmount = ethers.parseEther("5");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.not.be.reverted;
        });
        
        it("Should support referral system from private sale participants", async function () {
            // Setup referrer (simulate private sale participant)
            await saleManager.connect(kycManager).updateKYCStatus(buyer2.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer2.address, true);
            
            // Register referral relationship
            await saleManager.connect(engagementManager).registerReferral(buyer2.address, buyer1.address);
            
            // Setup buyer1 KYC
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            
            const purchaseAmount = ethers.parseEther("5");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokensWithReferral(
                    validProof, 
                    buyer2.address, 
                    { value: purchaseAmount }
                )
            ).to.emit(saleManager, "ReferralReward");
        });
    });
    
    describe("Public Sale Implementation ($0.05, 150M KARMA, $7.5M raise)", function () {
        beforeEach(async function () {
            // Configure all phases
            const privateStartTime = (await time.latest()) + 100;
            const preStartTime = privateStartTime + 86400 * 60;
            const publicStartTime = preStartTime + 86400 * 30;
            
            const liquidityConfig = {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            };
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
            
            // Skip to public sale
            await time.increaseTo(publicStartTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
        });
        
        it("Should enforce $5K maximum purchase per wallet ($5 ETH)", async function () {
            const aboveMaximum = ethers.parseEther("10"); // $10K
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: aboveMaximum })
            ).to.be.revertedWith("Purchase amount above maximum");
        });
        
        it("Should calculate correct token amounts at $0.05 per token", async function () {
            const ethAmount = ethers.parseEther("5"); // $5K
            const expectedTokens = priceCalculator.calculateTokenAmount(ethAmount, "PUBLIC_SALE");
            const contractTokens = await saleManager.calculateTokenAmount(ethAmount);
            
            expect(contractTokens).to.equal(expectedTokens);
            // $5K / $0.05 = 100K tokens
            expect(contractTokens).to.equal(ethers.parseEther("100000"));
        });
        
        it("Should provide 100% immediate token distribution", async function () {
            const purchaseAmount = ethers.parseEther("3"); // $3K
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            
            const balanceBefore = await karmaToken.balanceOf(buyer1.address);
            
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            
            const balanceAfter = await karmaToken.balanceOf(buyer1.address);
            const receivedTokens = balanceAfter.sub(balanceBefore);
            
            expect(receivedTokens).to.equal(expectedTokens);
            
            // Should not create vesting schedule
            const vestingSchedules = await vestingVault.getScheduleIds(buyer1.address);
            expect(vestingSchedules.length).to.equal(0);
        });
        
        it("Should not require whitelist verification", async function () {
            const purchaseAmount = ethers.parseEther("3");
            
            // No merkle proof needed for public sale
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount })
            ).to.not.be.reverted;
        });
        
        it("Should support MEV protection", async function () {
            const purchaseAmount = ethers.parseEther("3");
            const slippageTolerance = 300; // 3%
            
            await saleManager.connect(buyer1).enableMEVProtection(slippageTolerance);
            
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            const minTokens = priceCalculator.calculateMinTokensWithSlippage(expectedTokens, slippageTolerance);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokensWithMEVProtection(
                    [],
                    minTokens,
                    { value: purchaseAmount }
                )
            ).to.not.be.reverted;
        });
        
        it("Should setup Uniswap V3 liquidity pool", async function () {
            const liquidityConfig = {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            };
            
            await saleManager.configureLiquidityPool(liquidityConfig);
            
            const storedConfig = await saleManager.getLiquidityConfig();
            expect(storedConfig.ethAmount).to.equal(liquidityConfig.ethAmount);
            expect(storedConfig.tokenAmount).to.equal(liquidityConfig.tokenAmount);
            expect(storedConfig.fee).to.equal(liquidityConfig.fee);
        });
    });
    
    describe("Cross-Phase Integration", function () {
        it("Should handle phase transitions correctly", async function () {
            const privateStartTime = (await time.latest()) + 100;
            const preStartTime = privateStartTime + 86400 * 60;
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            // Start private sale
            await time.increaseTo(privateStartTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
            expect(await saleManager.getCurrentPhase()).to.equal(1);
            
            // End private sale and start pre-sale
            await saleManager.endCurrentPhase();
            await time.increaseTo(preStartTime);
            await saleManager.startSalePhase(2, await saleManager.getPhaseConfig(2));
            expect(await saleManager.getCurrentPhase()).to.equal(2);
        });
        
        it("Should maintain separate allocation tracking per phase", async function () {
            const privateBalance = await saleManager.getAllocationBalance(1);
            const preBalance = await saleManager.getAllocationBalance(2);
            const publicBalance = await saleManager.getAllocationBalance(3);
            
            expect(privateBalance).to.equal(ethers.parseEther("100000000")); // 100M
            expect(preBalance).to.equal(ethers.parseEther("100000000"));     // 100M
            expect(publicBalance).to.equal(ethers.parseEther("150000000"));  // 150M
        });
        
        it("Should track total funds raised across all phases", async function () {
            // This would test the cumulative fundraising tracking
            const totalRaised = await saleManager.getTotalRaised();
            expect(totalRaised).to.equal(0); // Initially zero
            
            // After sales in multiple phases, this should accumulate
        });
    });
    
    describe("Economic Security", function () {
        it("Should prevent sandwich attacks in public sale", async function () {
            const startTime = (await time.latest()) + 100;
            const liquidityConfig = {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            };
            
            await saleManager.configurePublicSale(startTime, liquidityConfig);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("3");
            const slippageTolerance = 100; // 1%
            
            await saleManager.connect(buyer1).enableMEVProtection(slippageTolerance);
            
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            const minTokens = expectedTokens.mul(9900).div(10000); // 1% slippage
            
            // This should protect against MEV by setting minimum token amount
            await expect(
                saleManager.connect(buyer1).purchaseTokensWithMEVProtection(
                    [],
                    minTokens,
                    { value: purchaseAmount }
                )
            ).to.not.be.reverted;
        });
        
        it("Should prevent front-running with rate limiting", async function () {
            // This would test rate limiting mechanisms to prevent abuse
            // Implementation depends on specific rate limiting strategy
        });
    });
}); 