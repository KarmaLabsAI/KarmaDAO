const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Stage 3.3: Revenue and Fund Management Tests", function () {
    let saleManager, karmaToken, vestingVault, treasury;
    let deployer, admin, buyer1, buyer2, treasuryMultisig;
    let merkleTree, merkleRoot;
    
    beforeEach(async function () {
        [deployer, admin, buyer1, buyer2, treasuryMultisig] = await ethers.getSigners();
        
        // Deploy contracts
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy();
        await karmaToken.waitForDeployment();
        
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress());
        await vestingVault.waitForDeployment();
        
        // Deploy Treasury mock
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy();
        await treasury.waitForDeployment();
        
        const SaleManager = await ethers.getContractFactory("SaleManager");
        saleManager = await SaleManager.deploy(
            await karmaToken.getAddress(),
            await vestingVault.getAddress(),
            admin.address
        );
        await saleManager.waitForDeployment();
        
        // Set treasury address
        await saleManager.setTreasuryAddress(await treasury.getAddress());
        
        // Setup roles
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
        
        await karmaToken.grantRole(MINTER_ROLE, await saleManager.getAddress());
        await vestingVault.grantRole(VAULT_MANAGER_ROLE, await saleManager.getAddress());
        
        // Create simple whitelist
        const whitelist = [buyer1.address, buyer2.address];
        const { MerkleTree } = require('merkletreejs');
        const keccak256 = require('keccak256');
        
        const leaves = whitelist.map(addr => keccak256(addr));
        merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        merkleRoot = merkleTree.getHexRoot();
    });
    
    describe("Treasury Integration", function () {
        it("Should forward ETH to Treasury contract automatically", async function () {
            // Configure and start a sale
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("3");
            const treasuryBalanceBefore = await ethers.provider.getBalance(await treasury.getAddress());
            
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            
            const treasuryBalanceAfter = await ethers.provider.getBalance(await treasury.getAddress());
            expect(treasuryBalanceAfter).to.be.gt(treasuryBalanceBefore);
        });
        
        it("Should track fund allocation per Treasury categories", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("5");
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            
            // Verify allocation tracking
            const allocations = await saleManager.getAllocationBreakdown();
            expect(allocations.marketing).to.be.gt(0);   // 30%
            expect(allocations.kol).to.be.gt(0);         // 20%
            expect(allocations.development).to.be.gt(0); // 30%
            expect(allocations.buyback).to.be.gt(0);     // 20%
        });
        
        it("Should emit transparent events for all fund transfers", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("3");
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount })
            ).to.emit(saleManager, "FundsForwarded")
            .withArgs(await treasury.getAddress(), purchaseAmount);
        });
        
        it("Should handle treasury forwarding failures gracefully", async function () {
            // Deploy a treasury that rejects ETH
            const RejectingTreasury = await ethers.getContractFactory("RejectingTreasury");
            const rejectingTreasury = await RejectingTreasury.deploy();
            await rejectingTreasury.waitForDeployment();
            
            await saleManager.setTreasuryAddress(await rejectingTreasury.getAddress());
            
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("3");
            
            // Should still complete the purchase but hold funds in contract
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount })
            ).to.not.be.reverted;
            
            // Funds should be held in sale manager
            const contractBalance = await ethers.provider.getBalance(await saleManager.getAddress());
            expect(contractBalance).to.equal(purchaseAmount);
        });
    });
    
    describe("Emergency Fund Recovery", function () {
        it("Should allow emergency fund recovery by admin", async function () {
            // Send some ETH to the contract
            await buyer1.sendTransaction({
                to: await saleManager.getAddress(),
                value: ethers.parseEther("10")
            });
            
            const adminBalanceBefore = await ethers.provider.getBalance(admin.address);
            const contractBalance = await ethers.provider.getBalance(await saleManager.getAddress());
            
            const tx = await saleManager.connect(admin).emergencyWithdraw();
            const receipt = await tx.wait();
            const gasUsed = receipt.gasUsed * receipt.gasPrice;
            
            const adminBalanceAfter = await ethers.provider.getBalance(admin.address);
            const expectedBalance = adminBalanceBefore.add(contractBalance).sub(gasUsed);
            
            expect(adminBalanceAfter).to.be.closeTo(expectedBalance, ethers.parseEther("0.01"));
        });
        
        it("Should prevent unauthorized emergency withdrawals", async function () {
            await expect(
                saleManager.connect(buyer1).emergencyWithdraw()
            ).to.be.reverted;
        });
        
        it("Should allow emergency token recovery", async function () {
            // Send some tokens to the contract
            await karmaToken.transfer(await saleManager.getAddress(), ethers.parseEther("1000"));
            
            const adminBalanceBefore = await karmaToken.balanceOf(admin.address);
            const contractBalance = await karmaToken.balanceOf(await saleManager.getAddress());
            
            await saleManager.connect(admin).emergencyTokenWithdraw(
                await karmaToken.getAddress(),
                contractBalance
            );
            
            const adminBalanceAfter = await karmaToken.balanceOf(admin.address);
            expect(adminBalanceAfter).to.equal(adminBalanceBefore.add(contractBalance));
        });
    });
    
    describe("Security and Anti-Abuse", function () {
        beforeEach(async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
        });
        
        it("Should prevent reentrancy attacks", async function () {
            // Deploy reentrancy attacker contract
            const ReentrancyAttacker = await ethers.getContractFactory("ReentrancyAttacker");
            const attacker = await ReentrancyAttacker.deploy(await saleManager.getAddress());
            await attacker.waitForDeployment();
            
            // Attempt reentrancy attack
            await expect(
                attacker.attack({ value: ethers.parseEther("1") })
            ).to.be.revertedWith("ReentrancyGuard: reentrant call");
        });
        
        it("Should prevent front-running through rate limiting", async function () {
            const purchaseAmount = ethers.parseEther("1");
            
            // First purchase should succeed
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            
            // Immediate second purchase should be rate limited
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount })
            ).to.be.revertedWith("Rate limit exceeded");
        });
        
        it("Should detect and prevent unusual purchase patterns", async function () {
            // This would test for patterns like:
            // - Multiple purchases from same address in short timeframe
            // - Coordinated purchases from multiple addresses
            // - Purchases that exceed reasonable gas price thresholds
            
            const highGasPrice = ethers.parseUnits("1000", "gwei");
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], {
                    value: ethers.parseEther("1"),
                    gasPrice: highGasPrice
                })
            ).to.be.revertedWith("Suspicious transaction detected");
        });
        
        it("Should allow emergency pause during suspicious activity", async function () {
            await saleManager.pause();
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: ethers.parseEther("1") })
            ).to.be.revertedWith("Pausable: paused");
        });
    });
    
    describe("Reporting and Analytics", function () {
        beforeEach(async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
        });
        
        it("Should track real-time sale progress", async function () {
            const purchaseAmount = ethers.parseEther("2");
            
            const progressBefore = await saleManager.getSaleProgress();
            
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            await saleManager.connect(buyer2).purchaseTokens([], { value: purchaseAmount });
            
            const progressAfter = await saleManager.getSaleProgress();
            
            expect(progressAfter.totalRaised).to.be.gt(progressBefore.totalRaised);
            expect(progressAfter.participantCount).to.equal(2);
            expect(progressAfter.averagePurchase).to.equal(purchaseAmount);
        });
        
        it("Should generate participant analytics", async function () {
            await saleManager.connect(buyer1).purchaseTokens([], { value: ethers.parseEther("3") });
            await saleManager.connect(buyer2).purchaseTokens([], { value: ethers.parseEther("2") });
            
            const analytics = await saleManager.getParticipantAnalytics(buyer1.address);
            
            expect(analytics.totalPurchased).to.equal(ethers.parseEther("3"));
            expect(analytics.purchaseCount).to.equal(1);
            expect(analytics.firstPurchaseTime).to.be.gt(0);
            expect(analytics.totalTokensReceived).to.be.gt(0);
        });
        
        it("Should provide compliance reporting data", async function () {
            await saleManager.connect(buyer1).purchaseTokens([], { value: ethers.parseEther("4") });
            
            const report = await saleManager.getComplianceReport();
            
            expect(report.totalParticipants).to.equal(1);
            expect(report.totalRaised).to.equal(ethers.parseEther("4"));
            expect(report.averageContribution).to.equal(ethers.parseEther("4"));
            expect(report.phaseBreakdown.length).to.be.gt(0);
        });
        
        it("Should support data export for external analytics", async function () {
            await saleManager.connect(buyer1).purchaseTokens([], { value: ethers.parseEther("1") });
            await saleManager.connect(buyer2).purchaseTokens([], { value: ethers.parseEther("2") });
            
            const exportData = await saleManager.exportParticipantData();
            
            expect(exportData.length).to.equal(2);
            expect(exportData[0].participant).to.equal(buyer1.address);
            expect(exportData[1].participant).to.equal(buyer2.address);
        });
    });
    
    describe("Fund Allocation Transparency", function () {
        it("Should provide detailed allocation breakdown", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("10");
            await saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount });
            
            const breakdown = await saleManager.getAllocationBreakdown();
            
            // 30% marketing, 20% KOL, 30% development, 20% buyback
            const expectedMarketing = purchaseAmount.mul(30).div(100);
            const expectedKOL = purchaseAmount.mul(20).div(100);
            const expectedDevelopment = purchaseAmount.mul(30).div(100);
            const expectedBuyback = purchaseAmount.mul(20).div(100);
            
            expect(breakdown.marketing).to.equal(expectedMarketing);
            expect(breakdown.kol).to.equal(expectedKOL);
            expect(breakdown.development).to.equal(expectedDevelopment);
            expect(breakdown.buyback).to.equal(expectedBuyback);
        });
        
        it("Should emit allocation events for transparency", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            const purchaseAmount = ethers.parseEther("5");
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount })
            ).to.emit(saleManager, "FundsAllocated");
        });
    });
    
    describe("Integration with External Systems", function () {
        it("Should integrate with external analytics platforms", async function () {
            // This would test webhook or API integration for external reporting
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            // Set analytics endpoint
            await saleManager.setAnalyticsEndpoint("https://analytics.karmalabs.com/webhook");
            
            const purchaseAmount = ethers.parseEther("3");
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens([], { value: purchaseAmount })
            ).to.emit(saleManager, "AnalyticsDataSent");
        });
        
        it("Should support compliance reporting for regulatory requirements", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePublicSale(startTime, {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            });
            
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(3, await saleManager.getPhaseConfig(3));
            
            await saleManager.connect(buyer1).purchaseTokens([], { value: ethers.parseEther("2") });
            
            // Generate compliance report for specific time period
            const report = await saleManager.generateComplianceReport(
                await time.latest() - 3600, // Start time (1 hour ago)
                await time.latest()          // End time (now)
            );
            
            expect(report.periodStart).to.be.gt(0);
            expect(report.periodEnd).to.be.gt(report.periodStart);
            expect(report.transactions.length).to.equal(1);
        });
    });
}); 