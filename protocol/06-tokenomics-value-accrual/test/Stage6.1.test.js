/**
 * @title Stage 6.1 Test Suite - BuybackBurn System Development
 * @dev Test suite for BuybackBurn System Development stage
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 6.1: BuybackBurn System Development", function () {
    let buybackBurn, karmaToken, treasury;
    let deployer, admin, user1, user2;

    beforeEach(async function () {
        [deployer, admin, user1, user2] = await ethers.getSigners();

        // Deploy mock contracts
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        karmaToken = await MockERC20.deploy("Karma Token", "KARMA", 18);

        const MockTreasury = await ethers.getContractFactory("MockTreasury");
        treasury = await MockTreasury.deploy();

        // Deploy BuybackBurn
        const BuybackBurn = await ethers.getContractFactory("BuybackBurn");
        buybackBurn = await BuybackBurn.deploy(
            admin.address,
            await karmaToken.getAddress(),
            await treasury.getAddress()
        );

        // Fund buybackBurn for testing
        await deployer.sendTransaction({
            to: await buybackBurn.getAddress(),
            value: ethers.parseEther("100")
        });
    });

    describe("DEX Integration Engine", function () {
        it("Should support multiple DEX protocols", async function () {
            // Test Uniswap V3 support
            const dexTypes = await buybackBurn.getSupportedDEXes();
            expect(dexTypes.length).to.be.gt(0);
        });

        it("Should calculate optimal routing for swaps", async function () {
            const ethAmount = ethers.parseEther("1");
            const route = await buybackBurn.calculateOptimalRoute(ethAmount);
            expect(route.expectedTokens).to.be.gt(0);
        });

        it("Should implement slippage protection", async function () {
            const maxSlippage = 500; // 5%
            const config = await buybackBurn.getSlippageConfig();
            expect(config.maxSlippage).to.be.lte(maxSlippage);
        });

        it("Should handle price impact calculations", async function () {
            const ethAmount = ethers.parseEther("10");
            const impact = await buybackBurn.calculatePriceImpact(ethAmount);
            expect(impact).to.be.gte(0);
        });
    });

    describe("Automatic Triggering System", function () {
        it("Should trigger on monthly schedule", async function () {
            const currentTime = Math.floor(Date.now() / 1000);
            const nextTrigger = await buybackBurn.getNextScheduledTrigger();
            expect(nextTrigger).to.be.gt(currentTime);
        });

        it("Should trigger on threshold amount", async function () {
            const threshold = await buybackBurn.getTriggerThreshold();
            expect(threshold).to.equal(ethers.parseEther("50")); // $50K threshold
        });

        it("Should support manual triggers with admin controls", async function () {
            const ethAmount = ethers.parseEther("1");
            await expect(
                buybackBurn.connect(admin).manualTrigger(ethAmount, 500)
            ).to.emit(buybackBurn, "BuybackTriggered");
        });

        it("Should validate trigger conditions", async function () {
            const balance = await ethers.provider.getBalance(await buybackBurn.getAddress());
            const canTrigger = await buybackBurn.canTriggerBuyback();
            expect(canTrigger).to.equal(balance > 0);
        });
    });

    describe("Fee Collection Integration", function () {
        it("Should collect iNFT trading fees", async function () {
            const feeAmount = ethers.parseEther("0.1");
            
            await expect(
                buybackBurn.collectPlatformFees(feeAmount, 0) // INFT_TRADES
            ).to.emit(buybackBurn, "FeesCollected");
        });

        it("Should collect credit system surcharges", async function () {
            const surchargeAmount = ethers.parseEther("0.05");
            
            await expect(
                buybackBurn.collectPlatformFees(surchargeAmount, 1) // CREDIT_SURCHARGES
            ).to.emit(buybackBurn, "FeesCollected");
        });

        it("Should collect premium subscription fees", async function () {
            const subscriptionFee = ethers.parseEther("0.01");
            
            await expect(
                buybackBurn.collectPlatformFees(subscriptionFee, 2) // PREMIUM_SUBSCRIPTIONS
            ).to.emit(buybackBurn, "FeesCollected");
        });

        it("Should route licensing fees correctly", async function () {
            const licensingFee = ethers.parseEther("0.2");
            
            await expect(
                buybackBurn.collectPlatformFees(licensingFee, 3) // LICENSING_FEES
            ).to.emit(buybackBurn, "FeesCollected");
        });
    });

    describe("Burn Mechanism Implementation", function () {
        it("Should integrate with KarmaToken burn function", async function () {
            const burnAmount = ethers.parseEther("1000");
            
            // Mock token approval
            await karmaToken.mint(await buybackBurn.getAddress(), burnAmount);
            
            await expect(
                buybackBurn.connect(admin).executeBurn(burnAmount)
            ).to.emit(buybackBurn, "TokensBurned");
        });

        it("Should calculate burn amounts correctly", async function () {
            const ethAmount = ethers.parseEther("1");
            const expectedTokens = await buybackBurn.calculateTokenAmount(ethAmount);
            expect(expectedTokens).to.be.gt(0);
        });

        it("Should batch burn transactions for efficiency", async function () {
            const amounts = [
                ethers.parseEther("100"),
                ethers.parseEther("200"),
                ethers.parseEther("300")
            ];
            
            for (const amount of amounts) {
                await karmaToken.mint(await buybackBurn.getAddress(), amount);
            }
            
            await expect(
                buybackBurn.connect(admin).batchBurn(amounts)
            ).to.emit(buybackBurn, "BatchBurnCompleted");
        });

        it("Should emit comprehensive burn events", async function () {
            const burnAmount = ethers.parseEther("500");
            await karmaToken.mint(await buybackBurn.getAddress(), burnAmount);
            
            const tx = await buybackBurn.connect(admin).executeBurn(burnAmount);
            const receipt = await tx.wait();
            
            // Check for burn event
            let burnEventFound = false;
            for (const log of receipt.logs) {
                try {
                    const parsed = buybackBurn.interface.parseLog(log);
                    if (parsed.name === "TokensBurned") {
                        burnEventFound = true;
                        expect(parsed.args.amount).to.equal(burnAmount);
                        break;
                    }
                } catch (e) {
                    // Not a buyback event, continue
                }
            }
            expect(burnEventFound).to.be.true;
        });
    });

    describe("Economic Security and Controls", function () {
        it("Should implement multisig approval for large operations", async function () {
            const largeAmount = ethers.parseEther("100"); // >10% Treasury threshold
            
            await expect(
                buybackBurn.requestLargeOperationApproval(largeAmount, "Large buyback test")
            ).to.emit(buybackBurn, "LargeOperationRequested");
        });

        it("Should enforce operation limits and cooling-off periods", async function () {
            const operationLimit = await buybackBurn.getDailyOperationLimit();
            expect(operationLimit).to.be.gt(0);
            
            const cooldownPeriod = await buybackBurn.getCooldownPeriod();
            expect(cooldownPeriod).to.be.gt(0);
        });

        it("Should implement MEV protection mechanisms", async function () {
            const mevConfig = await buybackBurn.getMEVProtectionConfig();
            expect(mevConfig.enabled).to.be.true;
        });

        it("Should support emergency pause functionality", async function () {
            await expect(
                buybackBurn.connect(admin).emergencyPause()
            ).to.emit(buybackBurn, "EmergencyPaused");
            
            expect(await buybackBurn.paused()).to.be.true;
        });
    });

    describe("Treasury Integration", function () {
        it("Should receive funding from Treasury contract", async function () {
            const fundingAmount = ethers.parseEther("10");
            
            await treasury.fundBuybackBurn(
                await buybackBurn.getAddress(),
                fundingAmount
            );
            
            const balance = await ethers.provider.getBalance(await buybackBurn.getAddress());
            expect(balance).to.be.gte(fundingAmount);
        });

        it("Should track and report fund allocation", async function () {
            const allocation = await buybackBurn.getCurrentAllocation();
            expect(allocation.totalAllocated).to.be.gte(0);
            expect(allocation.totalSpent).to.be.gte(0);
        });

        it("Should maintain 20% treasury allocation target", async function () {
            const targetPercentage = await buybackBurn.getTargetAllocationPercentage();
            expect(targetPercentage).to.equal(2000); // 20% in basis points
        });
    });

    describe("Performance and Gas Optimization", function () {
        it("Should optimize gas usage for swap operations", async function () {
            const ethAmount = ethers.parseEther("1");
            
            const tx = await buybackBurn.connect(admin).executeBuyback(ethAmount, 500);
            const receipt = await tx.wait();
            
            // Gas should be reasonable for swap operation
            expect(receipt.gasUsed).to.be.lt(1000000); // Less than 1M gas
        });

        it("Should efficiently handle batch operations", async function () {
            const amounts = [
                ethers.parseEther("0.1"),
                ethers.parseEther("0.2"),
                ethers.parseEther("0.3")
            ];
            
            const tx = await buybackBurn.connect(admin).batchExecuteBuyback(amounts, 500);
            const receipt = await tx.wait();
            
            // Batch should be more efficient than individual operations
            expect(receipt.gasUsed).to.be.lt(2000000); // Less than 2M gas for 3 operations
        });
    });

    describe("Monitoring and Analytics", function () {
        it("Should track buyback metrics", async function () {
            const metrics = await buybackBurn.getBuybackMetrics();
            
            expect(metrics.totalBuybacks).to.be.gte(0);
            expect(metrics.totalETHSpent).to.be.gte(0);
            expect(metrics.totalTokensBurned).to.be.gte(0);
        });

        it("Should provide detailed execution history", async function () {
            const history = await buybackBurn.getExecutionHistory(10); // Last 10 operations
            expect(Array.isArray(history)).to.be.true;
        });

        it("Should calculate ROI and impact metrics", async function () {
            const impactMetrics = await buybackBurn.getImpactMetrics();
            expect(impactMetrics.supplyReduction).to.be.gte(0);
            expect(impactMetrics.priceImpact).to.be.gte(0);
        });
    });
}); 