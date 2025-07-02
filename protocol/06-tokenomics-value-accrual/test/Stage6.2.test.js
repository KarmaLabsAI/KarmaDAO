/**
 * @title Stage 6.2 Test Suite - Revenue Stream Integration
 * @dev Test suite for Revenue Stream Integration stage
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 6.2: Revenue Stream Integration", function () {
    let feeCollector, buybackBurn, karmaToken, treasury;
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

        // Deploy FeeCollector (RevenueStreamIntegrator)
        const FeeCollector = await ethers.getContractFactory("RevenueStreamIntegrator");
        feeCollector = await FeeCollector.deploy(
            admin.address,
            await karmaToken.getAddress(),
            await treasury.getAddress(),
            await buybackBurn.getAddress(),
            user1.address // oracle address
        );

        // Fund contracts for testing
        await deployer.sendTransaction({
            to: await feeCollector.getAddress(),
            value: ethers.parseEther("100")
        });
    });

    describe("Platform Fee Collection", function () {
        it("Should collect iNFT trading fees", async function () {
            const feeAmount = ethers.parseEther("0.1");
            
            await expect(
                feeCollector.collectPlatformFees({ value: feeAmount })
            ).to.emit(feeCollector, "PlatformFeesCollected");
        });

        it("Should handle SillyHotel in-game purchase fees", async function () {
            const purchaseFee = ethers.parseEther("0.05");
            
            await expect(
                feeCollector.connect(user1).collectGamePurchaseFees({ value: purchaseFee })
            ).to.emit(feeCollector, "GameFeesCollected");
        });

        it("Should process SillyPort premium feature fees", async function () {
            const premiumFee = ethers.parseEther("0.015"); // $15 equivalent
            
            await expect(
                feeCollector.connect(user2).collectPremiumFeatures({ value: premiumFee })
            ).to.emit(feeCollector, "PremiumFeesCollected");
        });

        it("Should track KarmaLabs asset trading fees", async function () {
            const tradingFee = ethers.parseEther("0.025");
            
            await expect(
                feeCollector.collectAssetTradingFees({ value: tradingFee })
            ).to.emit(feeCollector, "AssetTradingFeesCollected");
        });

        it("Should implement 0.5% iNFT trading fee correctly", async function () {
            const tradeValue = ethers.parseEther("100"); // $100 trade
            const expectedFee = tradeValue * BigInt(5) / BigInt(1000); // 0.5%
            
            const calculatedFee = await feeCollector.calculateTradingFee(tradeValue);
            expect(calculatedFee).to.equal(expectedFee);
        });
    });

    describe("Centralized Credit System Integration", function () {
        it("Should integrate with off-chain payment processing", async function () {
            const creditPurchase = ethers.parseEther("50"); // $50 credit purchase
            const karmaValue = ethers.parseEther("25"); // Equivalent KARMA value
            
            await expect(
                feeCollector.connect(admin).processCreditPurchase(
                    user1.address, 
                    creditPurchase, 
                    karmaValue
                )
            ).to.emit(feeCollector, "CreditPurchaseProcessed");
        });

        it("Should trigger automatic KARMA buybacks from credit purchases", async function () {
            const creditAmount = ethers.parseEther("100");
            
            const tx = await feeCollector.connect(admin).processCreditPurchase(
                user1.address,
                creditAmount,
                ethers.parseEther("50")
            );
            
            // Should trigger buyback
            await expect(tx).to.emit(feeCollector, "AutoBuybackTriggered");
        });

        it("Should implement 10% surcharge collection correctly", async function () {
            const purchaseAmount = ethers.parseEther("100");
            const expectedSurcharge = purchaseAmount * BigInt(10) / BigInt(100); // 10%
            
            const surcharge = await feeCollector.calculateCreditSurcharge(purchaseAmount);
            expect(surcharge).to.equal(expectedSurcharge);
        });

        it("Should handle Stripe/Privy payment integration", async function () {
            const paymentId = "pi_test_12345";
            const amount = ethers.parseEther("25");
            
            await expect(
                feeCollector.connect(admin).confirmStripePayment(paymentId, user1.address, amount)
            ).to.emit(feeCollector, "StripePaymentConfirmed");
        });

        it("Should manage non-transferable credit conversions", async function () {
            const creditBalance = ethers.parseEther("50");
            const conversionRate = 2; // 2:1 credit to KARMA
            
            await expect(
                feeCollector.connect(admin).convertCreditsToKarma(
                    user1.address,
                    creditBalance,
                    conversionRate
                )
            ).to.emit(feeCollector, "CreditsConverted");
        });
    });

    describe("Economic Security and Controls", function () {
        it("Should implement multisig approval for large buybacks", async function () {
            const largeAmount = ethers.parseEther("50"); // Large buyback amount
            
            await expect(
                feeCollector.requestLargeBuybackApproval(largeAmount, "Market volatility support")
            ).to.emit(feeCollector, "LargeBuybackRequested");
        });

        it("Should enforce buyback amount limits", async function () {
            const limit = await feeCollector.getLargeBuybackThreshold();
            expect(limit).to.be.gt(0);
            
            const treasuryBalance = await treasury.getBalance();
            const maxBuyback = treasuryBalance * BigInt(10) / BigInt(100); // 10% max
            
            expect(limit).to.be.lte(maxBuyback);
        });

        it("Should implement cooling-off periods", async function () {
            const cooldownPeriod = await feeCollector.getCooldownPeriod();
            expect(cooldownPeriod).to.equal(86400); // 1 day in seconds
        });

        it("Should prevent MEV attacks on buybacks", async function () {
            const mevConfig = await feeCollector.getMEVProtectionConfig();
            expect(mevConfig.enabled).to.be.true;
            expect(mevConfig.maxSlippage).to.be.lte(500); // 5% max slippage
        });

        it("Should support emergency pause for market manipulation", async function () {
            await expect(
                feeCollector.connect(admin).emergencyPause()
            ).to.emit(feeCollector, "EmergencyPaused");
            
            expect(await feeCollector.paused()).to.be.true;
        });
    });

    describe("Revenue Stream Routing", function () {
        it("Should route fees to BuybackBurn contract correctly", async function () {
            const feeAmount = ethers.parseEther("1");
            
            const initialBalance = await ethers.provider.getBalance(await buybackBurn.getAddress());
            
            await feeCollector.collectPlatformFees({ value: feeAmount });
            
            const finalBalance = await ethers.provider.getBalance(await buybackBurn.getAddress());
            expect(finalBalance).to.be.gt(initialBalance);
        });

        it("Should implement automatic threshold-based routing", async function () {
            const threshold = await feeCollector.getAutoRouteThreshold();
            const feeAmount = threshold + BigInt(1); // Just above threshold
            
            await expect(
                feeCollector.collectPlatformFees({ value: feeAmount })
            ).to.emit(feeCollector, "AutoRouteTriggered");
        });

        it("Should track fee allocation percentages", async function () {
            const allocations = await feeCollector.getFeeAllocations();
            expect(allocations.buybackPercentage).to.be.gt(0);
            expect(allocations.treasuryPercentage).to.be.gt(0);
        });

        it("Should maintain fee routing transparency", async function () {
            const feeAmount = ethers.parseEther("2");
            
            const tx = await feeCollector.collectPlatformFees({ value: feeAmount });
            const receipt = await tx.wait();
            
            // Check for routing events
            let routingEventFound = false;
            for (const log of receipt.logs) {
                try {
                    const parsed = feeCollector.interface.parseLog(log);
                    if (parsed.name === "FeeRouted") {
                        routingEventFound = true;
                        expect(parsed.args.amount).to.be.gt(0);
                        break;
                    }
                } catch (e) {
                    // Not a fee collector event, continue
                }
            }
            expect(routingEventFound).to.be.true;
        });
    });

    describe("Oracle Integration", function () {
        it("Should integrate with price oracles for accurate conversions", async function () {
            const ethPrice = await feeCollector.getETHPriceUSD();
            expect(ethPrice).to.be.gt(0);
            
            const karmaPrice = await feeCollector.getKARMAPriceUSD();
            expect(karmaPrice).to.be.gt(0);
        });

        it("Should handle oracle price updates", async function () {
            const newETHPrice = ethers.parseUnits("2000", 8); // $2000 with 8 decimals
            
            await expect(
                feeCollector.connect(admin).updateETHPrice(newETHPrice)
            ).to.emit(feeCollector, "PriceUpdated");
        });

        it("Should implement price staleness protection", async function () {
            const priceAge = await feeCollector.getPriceAge();
            const maxAge = await feeCollector.getMaxPriceAge();
            
            expect(priceAge).to.be.lt(maxAge);
        });

        it("Should fallback to backup oracles", async function () {
            const backupOracles = await feeCollector.getBackupOracles();
            expect(backupOracles.length).to.be.gt(0);
        });
    });

    describe("Performance Optimization", function () {
        it("Should batch fee collections efficiently", async function () {
            const fees = [
                ethers.parseEther("0.1"),
                ethers.parseEther("0.2"),
                ethers.parseEther("0.3")
            ];
            
            const sources = [0, 1, 2]; // Different fee sources
            
            const tx = await feeCollector.connect(admin).batchCollectFees(fees, sources);
            const receipt = await tx.wait();
            
            // Batch should be more efficient than individual collections
            expect(receipt.gasUsed).to.be.lt(500000); // Less than 500K gas for 3 operations
        });

        it("Should optimize gas usage for routing operations", async function () {
            const feeAmount = ethers.parseEther("1");
            
            const tx = await feeCollector.collectPlatformFees({ value: feeAmount });
            const receipt = await tx.wait();
            
            // Should be reasonably gas efficient
            expect(receipt.gasUsed).to.be.lt(300000); // Less than 300K gas
        });

        it("Should implement efficient storage patterns", async function () {
            // Test multiple fee collections without excessive gas increase
            const baseGas = await feeCollector.estimateGas.collectPlatformFees({ 
                value: ethers.parseEther("0.1") 
            });
            
            // Collect several fees
            for (let i = 0; i < 5; i++) {
                await feeCollector.collectPlatformFees({ 
                    value: ethers.parseEther("0.1") 
                });
            }
            
            const laterGas = await feeCollector.estimateGas.collectPlatformFees({ 
                value: ethers.parseEther("0.1") 
            });
            
            // Gas should not increase significantly
            expect(laterGas).to.be.lt(baseGas * BigInt(12) / BigInt(10)); // Max 20% increase
        });
    });

    describe("Analytics and Reporting", function () {
        it("Should track comprehensive revenue metrics", async function () {
            const metrics = await feeCollector.getRevenueMetrics();
            
            expect(metrics.totalFeesCollected).to.be.gte(0);
            expect(metrics.totalBuybacksTriggered).to.be.gte(0);
            expect(metrics.totalValueRouted).to.be.gte(0);
        });

        it("Should provide fee source breakdown", async function () {
            const breakdown = await feeCollector.getFeeSourceBreakdown();
            
            expect(breakdown.iNFTTradingFees).to.be.gte(0);
            expect(breakdown.creditSurcharges).to.be.gte(0);
            expect(breakdown.premiumSubscriptions).to.be.gte(0);
            expect(breakdown.licensingFees).to.be.gte(0);
        });

        it("Should calculate revenue conversion rates", async function () {
            const conversionRate = await feeCollector.getRevenueConversionRate();
            expect(conversionRate).to.be.gte(0);
            expect(conversionRate).to.be.lte(10000); // Max 100% in basis points
        });

        it("Should track economic impact metrics", async function () {
            const impact = await feeCollector.getEconomicImpact();
            
            expect(impact.supplyReduction).to.be.gte(0);
            expect(impact.buybackEfficiency).to.be.gte(0);
            expect(impact.revenueGrowth).to.be.gte(0);
        });
    });
}); 