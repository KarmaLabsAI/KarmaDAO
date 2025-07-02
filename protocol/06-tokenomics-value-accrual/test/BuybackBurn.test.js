const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BuybackBurn Contract - Stage 6.1", function () {
    let buybackBurn, karmaToken, mockTreasury;
    let admin, buybackManager, feeCollector, keeper, user1, user2;
    let DEXType, TriggerType, FeeSource;

    beforeEach(async function () {
        [admin, buybackManager, feeCollector, keeper, user1, user2] = await ethers.getSigners();

        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();

        // Deploy Mock Treasury (much simpler than full Treasury)
        const MockTreasury = await ethers.getContractFactory("MockTreasury");
        mockTreasury = await MockTreasury.deploy();
        await mockTreasury.waitForDeployment();

        // Deploy BuybackBurn
        const BuybackBurn = await ethers.getContractFactory("BuybackBurn");
        buybackBurn = await BuybackBurn.deploy(
            admin.address,
            await karmaToken.getAddress(),
            await mockTreasury.getAddress()
        );
        await buybackBurn.waitForDeployment();

        // Set up roles
        const BUYBACK_MANAGER_ROLE = await buybackBurn.BUYBACK_MANAGER_ROLE();
        const FEE_COLLECTOR_ROLE = await buybackBurn.FEE_COLLECTOR_ROLE();
        const KEEPER_ROLE = await buybackBurn.KEEPER_ROLE();

        await buybackBurn.connect(admin).grantRole(BUYBACK_MANAGER_ROLE, buybackManager.address);
        await buybackBurn.connect(admin).grantRole(FEE_COLLECTOR_ROLE, feeCollector.address);
        await buybackBurn.connect(admin).grantRole(KEEPER_ROLE, keeper.address);

        // Fund the buyback contract for testing
        await admin.sendTransaction({
            to: await buybackBurn.getAddress(),
            value: ethers.parseEther("10")
        });

        // Mint some tokens to the buyback contract for burning tests
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        await karmaToken.connect(admin).grantRole(MINTER_ROLE, admin.address);
        await karmaToken.connect(admin).mint(await buybackBurn.getAddress(), ethers.parseEther("100000"));

        // Define enums
        DEXType = { UNISWAP_V3: 0, SUSHISWAP: 1, BALANCER: 2, CURVE: 3 };
        TriggerType = { MANUAL: 0, SCHEDULED: 1, THRESHOLD: 2, EMERGENCY: 3 };
        FeeSource = { INFT_TRADES: 0, CREDIT_SURCHARGE: 1, PREMIUM_SUBSCRIPTION: 2, LICENSING_FEES: 3 };
    });

    describe("Deployment and Initialization", function () {
        it("Should deploy with correct configuration", async function () {
            expect(await buybackBurn.karmaToken()).to.equal(await karmaToken.getAddress());
            expect(await buybackBurn.treasury()).to.equal(await mockTreasury.getAddress());
            expect(await buybackBurn.minimumThreshold()).to.be.greaterThan(0);
            expect(await buybackBurn.maxSlippage()).to.equal(500); // 5%
        });

        it("Should grant correct roles to admin", async function () {
            const DEFAULT_ADMIN_ROLE = await buybackBurn.DEFAULT_ADMIN_ROLE();
            const BUYBACK_MANAGER_ROLE = await buybackBurn.BUYBACK_MANAGER_ROLE();
            const FEE_COLLECTOR_ROLE = await buybackBurn.FEE_COLLECTOR_ROLE();
            const EMERGENCY_ROLE = await buybackBurn.EMERGENCY_ROLE();
            const KEEPER_ROLE = await buybackBurn.KEEPER_ROLE();

            expect(await buybackBurn.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
            expect(await buybackBurn.hasRole(BUYBACK_MANAGER_ROLE, admin.address)).to.be.true;
            expect(await buybackBurn.hasRole(FEE_COLLECTOR_ROLE, admin.address)).to.be.true;
            expect(await buybackBurn.hasRole(EMERGENCY_ROLE, admin.address)).to.be.true;
            expect(await buybackBurn.hasRole(KEEPER_ROLE, admin.address)).to.be.true;
        });

        it("Should initialize with default auto-trigger configuration", async function () {
            const config = await buybackBurn.getAutoTriggerConfig();
            expect(config.enabled).to.be.false; // Should start disabled
            expect(config.monthlySchedule).to.equal(15); // 15th of month
            expect(config.thresholdAmount).to.be.greaterThan(0);
            expect(config.cooldownPeriod).to.equal(24 * 3600); // 24 hours
        });
    });

    describe("DEX Integration Engine", function () {
        it("Should configure DEX settings", async function () {
            const dexConfig = {
                router: user1.address,
                factory: user2.address,
                poolFee: 3000,
                isActive: true,
                minLiquidity: ethers.parseEther("100"),
                maxSlippage: 300 // 3%
            };

            await expect(buybackBurn.connect(buybackManager).configureDEX(DEXType.UNISWAP_V3, dexConfig))
                .to.emit(buybackBurn, "DEXConfigured")
                .withArgs(DEXType.UNISWAP_V3, user1.address, true);

            const storedConfig = await buybackBurn.getDEXConfig(DEXType.UNISWAP_V3);
            expect(storedConfig.router).to.equal(user1.address);
            expect(storedConfig.factory).to.equal(user2.address);
            expect(storedConfig.poolFee).to.equal(3000);
            expect(storedConfig.isActive).to.be.true;
            expect(storedConfig.minLiquidity).to.equal(ethers.parseEther("100"));
            expect(storedConfig.maxSlippage).to.equal(300);
        });

        it("Should reject invalid DEX configuration", async function () {
            const invalidConfig = {
                router: ethers.ZeroAddress,
                factory: user1.address,
                poolFee: 3000,
                isActive: true,
                minLiquidity: ethers.parseEther("100"),
                maxSlippage: 300
            };

            await expect(buybackBurn.connect(buybackManager).configureDEX(DEXType.UNISWAP_V3, invalidConfig))
                .to.be.revertedWith("BuybackBurn: invalid router address");
        });

        it("Should only allow buyback manager to configure DEX", async function () {
            const dexConfig = {
                router: user1.address,
                factory: user2.address,
                poolFee: 3000,
                isActive: true,
                minLiquidity: ethers.parseEther("100"),
                maxSlippage: 300
            };

            await expect(buybackBurn.connect(user1).configureDEX(DEXType.UNISWAP_V3, dexConfig))
                .to.be.revertedWith("BuybackBurn: caller is not buyback manager");
        });

        it("Should get optimal route for swap", async function () {
            // Configure a DEX first
            const dexConfig = {
                router: user1.address,
                factory: user2.address,
                poolFee: 3000,
                isActive: true,
                minLiquidity: ethers.parseEther("100"),
                maxSlippage: 300
            };

            await buybackBurn.connect(buybackManager).configureDEX(DEXType.UNISWAP_V3, dexConfig);

            const ethAmount = ethers.parseEther("1");
            const [bestDex, expectedTokens, priceImpact] = await buybackBurn.getOptimalRoute(ethAmount);

            expect(bestDex).to.equal(DEXType.UNISWAP_V3);
            expect(expectedTokens).to.be.greaterThan(0);
            expect(priceImpact).to.be.lessThanOrEqual(300); // Should be within max slippage
        });

        it("Should calculate price impact", async function () {
            // Configure a DEX first
            const dexConfig = {
                router: user1.address,
                factory: user2.address,
                poolFee: 3000,
                isActive: true,
                minLiquidity: ethers.parseEther("100"),
                maxSlippage: 300
            };

            await buybackBurn.connect(buybackManager).configureDEX(DEXType.UNISWAP_V3, dexConfig);

            const ethAmount = ethers.parseEther("1");
            const priceImpact = await buybackBurn.calculatePriceImpact(DEXType.UNISWAP_V3, ethAmount);

            expect(priceImpact).to.be.greaterThanOrEqual(0);
            expect(priceImpact).to.be.lessThanOrEqual(10000); // Should be within 100%
        });
    });

    describe("Fee Collection Integration", function () {
        it("Should configure fee collection sources", async function () {
            const config = {
                source: FeeSource.INFT_TRADES,
                collector: feeCollector.address,
                percentage: 50, // 0.5%
                isActive: true,
                totalCollected: 0
            };

            await expect(buybackBurn.connect(buybackManager).configureFeeCollection(FeeSource.INFT_TRADES, config))
                .to.emit(buybackBurn, "FeeCollectionConfigured")
                .withArgs(FeeSource.INFT_TRADES, feeCollector.address, 50);

            const storedConfig = await buybackBurn.getFeeCollectionConfig(FeeSource.INFT_TRADES);
            expect(storedConfig.collector).to.equal(feeCollector.address);
            expect(storedConfig.percentage).to.equal(50);
            expect(storedConfig.isActive).to.be.true;
        });

        it("Should collect platform fees from iNFT trades", async function () {
            const feeAmount = ethers.parseEther("0.1");

            await expect(buybackBurn.connect(feeCollector).collectPlatformFees(feeAmount, FeeSource.INFT_TRADES, { value: feeAmount }))
                .to.emit(buybackBurn, "FeesCollected")
                .withArgs(FeeSource.INFT_TRADES, feeAmount, feeCollector.address);
        });

        it("Should collect credit surcharge fees", async function () {
            const surchargeAmount = ethers.parseEther("0.5");

            await expect(buybackBurn.connect(feeCollector).collectCreditSurcharge(surchargeAmount, { value: surchargeAmount }))
                .to.emit(buybackBurn, "FeesCollected")
                .withArgs(FeeSource.CREDIT_SURCHARGE, surchargeAmount, feeCollector.address);
        });

        it("Should get total fees collected", async function () {
            // Collect some fees first
            await buybackBurn.connect(feeCollector).collectPlatformFees(ethers.parseEther("0.1"), FeeSource.INFT_TRADES, { value: ethers.parseEther("0.1") });
            await buybackBurn.connect(feeCollector).collectCreditSurcharge(ethers.parseEther("0.2"), { value: ethers.parseEther("0.2") });

            const [totalFees, feeBreakdown] = await buybackBurn.getTotalFeesCollected();
            expect(totalFees).to.equal(ethers.parseEther("0.3"));
            expect(feeBreakdown[0]).to.equal(ethers.parseEther("0.1")); // iNFT trades
            expect(feeBreakdown[1]).to.equal(ethers.parseEther("0.2")); // Credit surcharge
        });
    });

    describe("Burn Mechanism Implementation", function () {
        it("Should burn tokens successfully", async function () {
            const burnAmount = ethers.parseEther("1000");
            const initialSupply = await karmaToken.totalSupply();

            await expect(buybackBurn.connect(buybackManager).burnTokens(burnAmount))
                .to.emit(buybackBurn, "TokensBurned")
                .withArgs(burnAmount, initialSupply, await buybackBurn.getAddress());

            const [totalBurned, burnCount, lastBurn, currentSupply] = await buybackBurn.getBurnStatistics();
            expect(totalBurned).to.equal(burnAmount);
            expect(burnCount).to.equal(1);
            expect(lastBurn).to.be.greaterThan(0);
        });

        it("Should calculate optimal burn amount", async function () {
            const availableTokens = ethers.parseEther("10000");
            const [recommendedBurn, reasoning] = await buybackBurn.calculateOptimalBurn(availableTokens);

            expect(recommendedBurn).to.be.greaterThan(0);
            expect(recommendedBurn).to.be.lessThanOrEqual(availableTokens);
            expect(reasoning).to.be.a('string');
            expect(reasoning.length).to.be.greaterThan(0);
        });
    });

    describe("Configuration and Admin Functions", function () {
        it("Should update KarmaToken address", async function () {
            const newTokenAddress = user2.address;

            await expect(buybackBurn.connect(admin).updateKarmaToken(newTokenAddress))
                .to.emit(buybackBurn, "KarmaTokenUpdated")
                .withArgs(await karmaToken.getAddress(), newTokenAddress);

            expect(await buybackBurn.karmaToken()).to.equal(newTokenAddress);
        });

        it("Should set minimum threshold", async function () {
            const newThreshold = ethers.parseEther("25000");
            const oldThreshold = await buybackBurn.minimumThreshold();

            await expect(buybackBurn.connect(buybackManager).setMinimumThreshold(newThreshold))
                .to.emit(buybackBurn, "ThresholdUpdated")
                .withArgs(oldThreshold, newThreshold);

            expect(await buybackBurn.minimumThreshold()).to.equal(newThreshold);
        });

        it("Should emergency pause and unpause", async function () {
            const EMERGENCY_ROLE = await buybackBurn.EMERGENCY_ROLE();
            await buybackBurn.connect(admin).grantRole(EMERGENCY_ROLE, user1.address);

            await expect(buybackBurn.connect(user1).emergencyPause())
                .to.emit(buybackBurn, "BuybackPaused")
                .withArgs(user1.address);

            expect(await buybackBurn.paused()).to.be.true;

            await expect(buybackBurn.connect(user1).emergencyUnpause())
                .to.emit(buybackBurn, "BuybackUnpaused")
                .withArgs(user1.address);

            expect(await buybackBurn.paused()).to.be.false;
        });
    });

    describe("Reporting and Analytics", function () {
        it("Should provide buyback metrics", async function () {
            const metrics = await buybackBurn.getBuybackMetrics();
            expect(metrics.totalETHSpent).to.equal(0); // Initially zero
            expect(metrics.totalTokensBought).to.equal(0);
            expect(metrics.totalTokensBurned).to.equal(0);
            expect(metrics.totalExecutions).to.equal(0);
        });

        it("Should provide balance status", async function () {
            const [ethBalance, karmaBalance, availableForBuyback] = await buybackBurn.getBalanceStatus();
            expect(ethBalance).to.be.greaterThan(0); // Contract was funded
            expect(karmaBalance).to.be.greaterThan(0); // Tokens were minted to contract
            expect(availableForBuyback).to.be.greaterThanOrEqual(0);
        });
    });
}); 