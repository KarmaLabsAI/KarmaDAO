const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RevenueStreamIntegrator - Stage 6.2", function () {
    let RevenueStreamIntegrator, revenueIntegrator;
    let KarmaToken, karmaToken;
    let BuybackBurn, buybackBurn;
    let Treasury, treasury;
    let MockTreasury, mockTreasury;
    let admin, revenueManager, platformCollector, oracle, securityManager, multisigApprover1, multisigApprover2;
    let user1, user2, trader1, player1, subscriber1;

    // Constants for testing
    const BASIS_POINTS = 10000;
    const USD_PRECISION = 1e6;
    const KARMA_PRECISION = ethers.parseEther("1");
    const DEFAULT_CONVERSION_RATE = 50 * USD_PRECISION; // $0.05 per KARMA
    const LARGE_BUYBACK_THRESHOLD = 1000; // 10% in basis points

    beforeEach(async function () {
        [admin, revenueManager, platformCollector, oracle, securityManager, multisigApprover1, multisigApprover2, 
         user1, user2, trader1, player1, subscriber1] = await ethers.getSigners();

        // Deploy KarmaToken first
        KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();

        // Deploy mock Treasury for testing
        MockTreasury = await ethers.getContractFactory("contracts/paymaster/MockTreasury.sol:MockTreasury");
        mockTreasury = await MockTreasury.deploy();
        await mockTreasury.waitForDeployment();

        // Deploy BuybackBurn
        BuybackBurn = await ethers.getContractFactory("BuybackBurn");
        buybackBurn = await BuybackBurn.deploy(
            admin.address,
            await karmaToken.getAddress(),
            await mockTreasury.getAddress()
        );
        await buybackBurn.waitForDeployment();

        // Deploy RevenueStreamIntegrator
        RevenueStreamIntegrator = await ethers.getContractFactory("RevenueStreamIntegrator");
        revenueIntegrator = await RevenueStreamIntegrator.deploy(
            admin.address,
            await buybackBurn.getAddress(),
            await mockTreasury.getAddress(),
            await karmaToken.getAddress()
        );
        await revenueIntegrator.waitForDeployment();

        // Setup roles
        await revenueIntegrator.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("REVENUE_MANAGER_ROLE")), 
            revenueManager.address
        );
        await revenueIntegrator.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("PLATFORM_COLLECTOR_ROLE")), 
            platformCollector.address
        );
        await revenueIntegrator.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE")), 
            oracle.address
        );
        await revenueIntegrator.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("SECURITY_MANAGER_ROLE")), 
            securityManager.address
        );
        await revenueIntegrator.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("MULTISIG_APPROVER_ROLE")), 
            multisigApprover1.address
        );
        await revenueIntegrator.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("MULTISIG_APPROVER_ROLE")), 
            multisigApprover2.address
        );

        // Grant RevenueStreamIntegrator the FEE_COLLECTOR_ROLE in BuybackBurn
        await buybackBurn.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("FEE_COLLECTOR_ROLE")),
            await revenueIntegrator.getAddress()
        );

        // Grant RevenueStreamIntegrator the EMERGENCY_ROLE in BuybackBurn
        await buybackBurn.connect(admin).grantRole(
            ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE")),
            await revenueIntegrator.getAddress()
        );

        // Fund the mock treasury for testing
        await admin.sendTransaction({
            to: await mockTreasury.getAddress(),
            value: ethers.parseEther("100") // 100 ETH
        });
    });

    describe("Deployment and Initialization", function () {
        it("Should deploy with correct initial configuration", async function () {
            expect(await revenueIntegrator.buybackBurn()).to.equal(await buybackBurn.getAddress());
            expect(await revenueIntegrator.treasury()).to.equal(await mockTreasury.getAddress());
            expect(await revenueIntegrator.karmaToken()).to.equal(await karmaToken.getAddress());
            expect(await revenueIntegrator.totalCreditsIssued()).to.equal(0);
            expect(await revenueIntegrator.totalPlatformRevenue()).to.equal(0);
            expect(await revenueIntegrator.totalCreditRevenue()).to.equal(0);
        });

        it("Should have correct role assignments", async function () {
            const REVENUE_MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("REVENUE_MANAGER_ROLE"));
            expect(await revenueIntegrator.hasRole(REVENUE_MANAGER_ROLE, revenueManager.address)).to.be.true;
            
            const PLATFORM_COLLECTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PLATFORM_COLLECTOR_ROLE"));
            expect(await revenueIntegrator.hasRole(PLATFORM_COLLECTOR_ROLE, platformCollector.address)).to.be.true;
        });
    });

    describe("Platform Fee Collection", function () {
        beforeEach(async function () {
            // Configure iNFT trading platform
            const platformConfig = {
                contractAddress: ethers.ZeroAddress,
                feePercentage: 50, // 0.5%
                isActive: true,
                feeCollector: await revenueIntegrator.getAddress(),
                minCollectionAmount: ethers.parseEther("0.01"),
                totalCollected: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configurePlatform(0, platformConfig); // INFT_TRADING = 0
        });

        it("Should configure platform correctly", async function () {
            const config = await revenueIntegrator.getPlatformConfig(0); // INFT_TRADING
            expect(config.feePercentage).to.equal(50);
            expect(config.isActive).to.be.true;
        });

        it("Should collect iNFT trading fees", async function () {
            const tradeAmount = ethers.parseEther("10");
            const feeAmount = ethers.parseEther("0.05"); // 0.5% of 10 ETH
            
            await expect(
                revenueIntegrator.connect(platformCollector).collectINFTTradingFees(
                    tradeAmount, feeAmount, trader1.address, { value: feeAmount }
                )
            ).to.emit(revenueIntegrator, "PlatformFeesCollected")
             .withArgs(0, feeAmount, trader1.address); // PlatformType.INFT_TRADING = 0
            
            expect(await revenueIntegrator.totalPlatformRevenue()).to.equal(feeAmount);
            const [platformRevenue,] = await revenueIntegrator.getPlatformRevenue();
            expect(platformRevenue[0]).to.equal(feeAmount);
        });

        it("Should collect SillyHotel fees", async function () {
            // Configure SillyHotel platform
            const platformConfig = {
                contractAddress: ethers.ZeroAddress,
                feePercentage: 1000, // 10%
                isActive: true,
                feeCollector: await revenueIntegrator.getAddress(),
                minCollectionAmount: ethers.parseEther("0.005"),
                totalCollected: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configurePlatform(1, platformConfig); // SILLY_HOTEL = 1
            
            const purchaseAmount = ethers.parseEther("1");
            const feeAmount = ethers.parseEther("0.1"); // 10% of 1 ETH
            
            await expect(
                revenueIntegrator.connect(platformCollector).collectSillyHotelFees(
                    purchaseAmount, feeAmount, player1.address, { value: feeAmount }
                )
            ).to.emit(revenueIntegrator, "PlatformFeesCollected")
             .withArgs(1, feeAmount, player1.address); // PlatformType.SILLY_HOTEL = 1
        });

        it("Should collect SillyPort subscription fees", async function () {
            // Configure SillyPort platform
            const platformConfig = {
                contractAddress: ethers.ZeroAddress,
                feePercentage: 10000, // 100%
                isActive: true,
                feeCollector: await revenueIntegrator.getAddress(),
                minCollectionAmount: ethers.parseEther("0.01"),
                totalCollected: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configurePlatform(2, platformConfig); // SILLY_PORT = 2
            
            const subscriptionType = 1; // Premium subscription
            const feeAmount = ethers.parseEther("0.05"); // $15 equivalent
            
            await expect(
                revenueIntegrator.connect(platformCollector).collectSillyPortFees(
                    subscriptionType, feeAmount, subscriber1.address, { value: feeAmount }
                )
            ).to.emit(revenueIntegrator, "PlatformFeesCollected")
             .withArgs(2, feeAmount, subscriber1.address); // PlatformType.SILLY_PORT = 2
        });

        it("Should collect KarmaLabs asset trading fees", async function () {
            // Configure KarmaLabs Assets platform
            const platformConfig = {
                contractAddress: ethers.ZeroAddress,
                feePercentage: 250, // 2.5%
                isActive: true,
                feeCollector: await revenueIntegrator.getAddress(),
                minCollectionAmount: ethers.parseEther("0.01"),
                totalCollected: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configurePlatform(3, platformConfig); // KARMA_LABS_ASSETS = 3
            
            const assetType = 1;
            const tradeAmount = ethers.parseEther("4");
            const feeAmount = ethers.parseEther("0.1"); // 2.5% of 4 ETH
            
            await expect(
                revenueIntegrator.connect(platformCollector).collectKarmaLabsFees(
                    assetType, tradeAmount, feeAmount, trader1.address, { value: feeAmount }
                )
            ).to.emit(revenueIntegrator, "PlatformFeesCollected")
             .withArgs(3, feeAmount, trader1.address); // PlatformType.KARMA_LABS_ASSETS = 3
        });

        it("Should reject fee collection from inactive platform", async function () {
            // Configure inactive platform
            const platformConfig = {
                contractAddress: ethers.ZeroAddress,
                feePercentage: 50,
                isActive: false, // Inactive
                feeCollector: await revenueIntegrator.getAddress(),
                minCollectionAmount: ethers.parseEther("0.01"),
                totalCollected: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configurePlatform(0, platformConfig);
            
            const tradeAmount = ethers.parseEther("10");
            const feeAmount = ethers.parseEther("0.05");
            
            await expect(
                revenueIntegrator.connect(platformCollector).collectINFTTradingFees(
                    tradeAmount, feeAmount, trader1.address, { value: feeAmount }
                )
            ).to.be.revertedWith("RevenueStreamIntegrator: platform not active");
        });

        it("Should reject insufficient fee amount", async function () {
            const tradeAmount = ethers.parseEther("10");
            const feeAmount = ethers.parseEther("0.05");
            const insufficientValue = ethers.parseEther("0.01");
            
            await expect(
                revenueIntegrator.connect(platformCollector).collectINFTTradingFees(
                    tradeAmount, feeAmount, trader1.address, { value: insufficientValue }
                )
            ).to.be.revertedWith("RevenueStreamIntegrator: insufficient fee amount");
        });
    });

    describe("Centralized Credit System Integration", function () {
        beforeEach(async function () {
            // Configure and activate credit system
            const creditConfig = {
                oracleAddress: oracle.address,
                conversionRate: DEFAULT_CONVERSION_RATE,
                minimumPurchase: 10 * USD_PRECISION,
                buybackThreshold: 1000 * USD_PRECISION,
                isActive: true,
                totalCreditsIssued: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configureCreditSystem(creditConfig);
        });

        it("Should configure credit system correctly", async function () {
            const [config, totalCredits, conversionRate] = await revenueIntegrator.getCreditSystemStatus();
            expect(config.oracleAddress).to.equal(oracle.address);
            expect(config.conversionRate).to.equal(DEFAULT_CONVERSION_RATE);
            expect(config.isActive).to.be.true;
            expect(totalCredits).to.equal(0);
            expect(conversionRate).to.equal(DEFAULT_CONVERSION_RATE);
        });

        it("Should issue credits for off-chain purchases", async function () {
            const usdAmount = 100 * USD_PRECISION; // $100
            const paymentMethod = 1; // STRIPE_CARD
            
            await expect(
                revenueIntegrator.connect(oracle).issueCredits(user1.address, usdAmount, paymentMethod)
            ).to.emit(revenueIntegrator, "CreditsIssued")
             .withArgs(user1.address, usdAmount, usdAmount);
            
            expect(await revenueIntegrator.getCreditBalance(user1.address)).to.equal(usdAmount);
            expect(await revenueIntegrator.totalCreditsIssued()).to.equal(usdAmount);
        });

        it("Should convert credits to KARMA tokens", async function () {
            // First issue credits
            const usdAmount = 100 * USD_PRECISION; // $100
            await revenueIntegrator.connect(oracle).issueCredits(user1.address, usdAmount, 1);
            
            // Convert credits to KARMA
            const creditsToConvert = 50 * USD_PRECISION; // $50 worth
            const expectedKarma = (creditsToConvert * KARMA_PRECISION) / DEFAULT_CONVERSION_RATE;
            
            await expect(
                revenueIntegrator.connect(user1).convertCreditsToKarma(creditsToConvert)
            ).to.emit(revenueIntegrator, "CreditsConverted")
             .withArgs(user1.address, creditsToConvert, expectedKarma);
            
            expect(await revenueIntegrator.getCreditBalance(user1.address)).to.equal(usdAmount - creditsToConvert);
        });

        it("Should process off-chain revenue with Oracle signature", async function () {
            // Create mock off-chain revenue data
            const offChainRevenue = [{
                amount: 500 * USD_PRECISION, // $500
                method: 1, // STRIPE_CARD
                platform: 0, // INFT_TRADING
                timestamp: Math.floor(Date.now() / 1000),
                transactionHash: ethers.keccak256(ethers.toUtf8Bytes("mock-tx-hash-1")),
                processed: false
            }];
            
            // Create Oracle signature (simplified for testing)
            const dataHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
                ["tuple(uint256,uint8,uint8,uint256,bytes32,bool)[]", "uint256"],
                [offChainRevenue, Math.floor(Date.now() / 1000)]
            ));
            const signature = await oracle.signMessage(ethers.getBytes(dataHash));
            
            await expect(
                revenueIntegrator.connect(oracle).processOffChainRevenue(offChainRevenue, signature)
            ).to.emit(revenueIntegrator, "OffChainRevenueProcessed")
             .withArgs(500 * USD_PRECISION, 1);
            
            expect(await revenueIntegrator.totalCreditRevenue()).to.equal(500 * USD_PRECISION);
        });

        it("Should reject credit conversion with insufficient balance", async function () {
            const creditsToConvert = 100 * USD_PRECISION; // User has 0 credits
            
            await expect(
                revenueIntegrator.connect(user1).convertCreditsToKarma(creditsToConvert)
            ).to.be.revertedWith("RevenueStreamIntegrator: insufficient credit balance");
        });

        it("Should reject credit issuance below minimum", async function () {
            const belowMinAmount = 5 * USD_PRECISION; // Below $10 minimum
            
            await expect(
                revenueIntegrator.connect(oracle).issueCredits(user1.address, belowMinAmount, 1)
            ).to.be.revertedWith("RevenueStreamIntegrator: amount below minimum");
        });
    });

    describe("Economic Security and Controls", function () {
        beforeEach(async function () {
            // Configure security controls
            const securityConfig = {
                multisigThreshold: LARGE_BUYBACK_THRESHOLD, // 10%
                cooldownPeriod: 86400, // 1 day
                maxSlippageProtection: 500, // 5%
                sandwichProtection: false,
                flashloanProtection: true,
                lastLargeBuyback: 0
            };
            
            await revenueIntegrator.connect(securityManager).configureSecurityControls(securityConfig);
        });

        it("Should configure security controls correctly", async function () {
            const [config, pending, lastUpdate] = await revenueIntegrator.getSecurityConfig();
            expect(config.multisigThreshold).to.equal(LARGE_BUYBACK_THRESHOLD);
            expect(config.cooldownPeriod).to.equal(86400);
            expect(config.maxSlippageProtection).to.equal(500);
            expect(config.flashloanProtection).to.be.true;
            expect(pending).to.equal(0);
        });

        it("Should request large buyback approval", async function () {
            const ethAmount = ethers.parseEther("15"); // Large amount requiring approval
            const justification = "Large buyback for token price support";
            
            await expect(
                revenueIntegrator.connect(revenueManager).requestLargeBuybackApproval(ethAmount, justification)
            ).to.emit(revenueIntegrator, "LargeBuybackRequested")
             .withArgs(1, ethAmount, revenueManager.address);
        });

        it("Should approve large buyback operation", async function () {
            // First request approval
            const ethAmount = ethers.parseEther("15");
            await revenueIntegrator.connect(revenueManager).requestLargeBuybackApproval(ethAmount, "Test approval");
            
            // Approve with multisig approver
            await expect(
                revenueIntegrator.connect(multisigApprover1).approveLargeBuyback(1)
            ).to.emit(revenueIntegrator, "LargeBuybackApproved")
             .withArgs(1, multisigApprover1.address);
        });

        it("Should enable sandwich protection", async function () {
            const maxSlippage = 300; // 3%
            const frontrunWindow = 3600; // 1 hour
            
            await expect(
                revenueIntegrator.connect(securityManager).enableSandwichProtection(maxSlippage, frontrunWindow)
            ).to.emit(revenueIntegrator, "SandwichProtectionEnabled")
             .withArgs(maxSlippage, frontrunWindow);
        });

        it("Should enable MEV protection", async function () {
            const protectionLevel = 2;
            const maxPriorityFee = ethers.parseUnits("20", "gwei");
            
            await expect(
                revenueIntegrator.connect(securityManager).enableMEVProtection(protectionLevel, maxPriorityFee)
            ).to.emit(revenueIntegrator, "MEVProtectionEnabled")
             .withArgs(protectionLevel, maxPriorityFee);
        });

        it("Should emergency pause trading", async function () {
            const reason = "Market manipulation detected";
            
            await expect(
                revenueIntegrator.connect(admin).emergencyPauseTrading(reason)
            ).to.emit(revenueIntegrator, "EmergencyTradingPaused")
             .withArgs(reason, admin.address);
            
            expect(await revenueIntegrator.paused()).to.be.true;
        });

        it("Should reject unauthorized large buyback approval", async function () {
            await expect(
                revenueIntegrator.connect(user1).requestLargeBuybackApproval(ethers.parseEther("15"), "Unauthorized")
            ).to.be.revertedWith("RevenueStreamIntegrator: caller is not revenue manager");
        });

        it("Should reject excessive security thresholds", async function () {
            const invalidConfig = {
                multisigThreshold: 3000, // 30% - too high
                cooldownPeriod: 86400,
                maxSlippageProtection: 500,
                sandwichProtection: false,
                flashloanProtection: true,
                lastLargeBuyback: 0
            };
            
            await expect(
                revenueIntegrator.connect(securityManager).configureSecurityControls(invalidConfig)
            ).to.be.revertedWith("RevenueStreamIntegrator: threshold too high");
        });
    });

    describe("Analytics and Reporting", function () {
        beforeEach(async function () {
            // Setup some test data
            const platformConfig = {
                contractAddress: ethers.ZeroAddress,
                feePercentage: 50,
                isActive: true,
                feeCollector: await revenueIntegrator.getAddress(),
                minCollectionAmount: ethers.parseEther("0.01"),
                totalCollected: 0
            };
            
            await revenueIntegrator.connect(revenueManager).configurePlatform(0, platformConfig);
            
            // Collect some fees
            await revenueIntegrator.connect(platformCollector).collectINFTTradingFees(
                ethers.parseEther("10"), ethers.parseEther("0.05"), trader1.address, 
                { value: ethers.parseEther("0.05") }
            );
        });

        it("Should get revenue metrics", async function () {
            const totalRevenue = await revenueIntegrator.getRevenueMetrics(0, Math.floor(Date.now() / 1000));
            expect(totalRevenue).to.equal(ethers.parseEther("0.05"));
        });

        it("Should get revenue breakdown", async function () {
            const [platformBreakdown, paymentBreakdown] = await revenueIntegrator.getRevenueBreakdown();
            expect(platformBreakdown[0]).to.equal(ethers.parseEther("0.05")); // iNFT trading
            expect(platformBreakdown[1]).to.equal(0); // SillyHotel
            expect(platformBreakdown[2]).to.equal(0); // SillyPort
            expect(platformBreakdown[3]).to.equal(0); // KarmaLabs Assets
        });

        it("Should export revenue data", async function () {
            const revenueData = await revenueIntegrator.exportRevenueData(0, Math.floor(Date.now() / 1000));
            expect(revenueData).to.not.equal("0x");
        });

        it("Should get contract balance", async function () {
            const [ethBalance, karmaBalance] = await revenueIntegrator.getContractBalance();
            expect(ethBalance).to.be.gte(0);
            expect(karmaBalance).to.equal(0);
        });
    });

    describe("Administrative Functions", function () {
        it("Should update Oracle address", async function () {
            const newOracle = user2.address;
            
            await expect(
                revenueIntegrator.connect(admin).updateOracle(newOracle)
            ).to.emit(revenueIntegrator, "OracleUpdated");
            
            const [config,,] = await revenueIntegrator.getCreditSystemStatus();
            expect(config.oracleAddress).to.equal(newOracle);
        });

        it("Should update BuybackBurn contract", async function () {
            const newBuybackBurn = user2.address;
            
            await expect(
                revenueIntegrator.connect(admin).updateBuybackBurn(newBuybackBurn)
            ).to.emit(revenueIntegrator, "BuybackBurnUpdated");
            
            expect(await revenueIntegrator.buybackBurn()).to.equal(newBuybackBurn);
        });

        it("Should set operation thresholds", async function () {
            const revenueThreshold = 2000 * USD_PRECISION;
            const creditThreshold = 20 * USD_PRECISION;
            
            await expect(
                revenueIntegrator.connect(revenueManager).setOperationThresholds(revenueThreshold, creditThreshold)
            ).to.emit(revenueIntegrator, "ThresholdsUpdated")
             .withArgs(revenueThreshold, creditThreshold);
        });

        it("Should perform emergency recovery", async function () {
            // Send some ETH to the contract first
            await admin.sendTransaction({
                to: await revenueIntegrator.getAddress(),
                value: ethers.parseEther("1")
            });
            
            const balanceBefore = await ethers.provider.getBalance(admin.address);
            
            await expect(
                revenueIntegrator.connect(admin).emergencyRecovery(ethers.ZeroAddress, 0)
            ).to.emit(revenueIntegrator, "EmergencyRecovery");
            
            // Admin should receive the recovered ETH (minus gas costs)
            const balanceAfter = await ethers.provider.getBalance(admin.address);
            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("Should reject unauthorized admin operations", async function () {
            await expect(
                revenueIntegrator.connect(user1).updateOracle(user2.address)
            ).to.be.revertedWith("AccessControl:");
        });
    });
}); 