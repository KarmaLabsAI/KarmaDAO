const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Starting Karma Labs Stage 6.2 - Revenue Stream Integration Deployment");
    console.log("=" * 80);

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log(`📝 Deploying contracts with account: ${deployer.address}`);
    console.log(`💰 Account balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);

    // Deploy KarmaToken (if not already deployed)
    console.log("\n🪙 Deploying KarmaToken...");
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(deployer.address);
    await karmaToken.waitForDeployment();
    console.log(`✅ KarmaToken deployed to: ${await karmaToken.getAddress()}`);

    // Deploy MockTreasury for testing
    console.log("\n🏦 Deploying MockTreasury...");
    const MockTreasury = await ethers.getContractFactory("contracts/paymaster/MockTreasury.sol:MockTreasury");
    const mockTreasury = await MockTreasury.deploy();
    await mockTreasury.waitForDeployment();
    console.log(`✅ MockTreasury deployed to: ${await mockTreasury.getAddress()}`);

    // Fund the treasury
    console.log("💰 Funding MockTreasury with 100 ETH...");
    await deployer.sendTransaction({
        to: await mockTreasury.getAddress(),
        value: ethers.parseEther("100")
    });

    // Deploy BuybackBurn (required for RevenueStreamIntegrator)
    console.log("\n🔥 Deploying BuybackBurn...");
    const BuybackBurn = await ethers.getContractFactory("BuybackBurn");
    const buybackBurn = await BuybackBurn.deploy(
        deployer.address,
        await karmaToken.getAddress(),
        await mockTreasury.getAddress()
    );
    await buybackBurn.waitForDeployment();
    console.log(`✅ BuybackBurn deployed to: ${await buybackBurn.getAddress()}`);

    // Deploy RevenueStreamIntegrator
    console.log("\n💰 Deploying RevenueStreamIntegrator (Stage 6.2)...");
    const RevenueStreamIntegrator = await ethers.getContractFactory("RevenueStreamIntegrator");
    const revenueIntegrator = await RevenueStreamIntegrator.deploy(
        deployer.address,
        await buybackBurn.getAddress(),
        await mockTreasury.getAddress(),
        await karmaToken.getAddress()
    );
    await revenueIntegrator.waitForDeployment();
    console.log(`✅ RevenueStreamIntegrator deployed to: ${await revenueIntegrator.getAddress()}`);

    console.log("\n🔧 Stage 6.2 Configuration and Testing");
    console.log("=" * 80);

    // ============ PLATFORM FEE COLLECTION SETUP ============
    console.log("\n📱 Configuring Platform Fee Collection...");

    // Configure iNFT Trading Platform (0.5% fee)
    console.log("🎨 Setting up iNFT Trading Platform...");
    const inftPlatformConfig = {
        contractAddress: ethers.ZeroAddress, // Placeholder
        feePercentage: 50, // 0.5%
        isActive: true,
        feeCollector: await revenueIntegrator.getAddress(),
        minCollectionAmount: ethers.parseEther("0.01"),
        totalCollected: 0
    };
    await revenueIntegrator.configurePlatform(0, inftPlatformConfig); // PlatformType.INFT_TRADING
    console.log("✅ iNFT Trading Platform configured (0.5% fee)");

    // Configure SillyHotel Platform (10% fee)
    console.log("🏨 Setting up SillyHotel Platform...");
    const sillyHotelConfig = {
        contractAddress: ethers.ZeroAddress,
        feePercentage: 1000, // 10%
        isActive: true,
        feeCollector: await revenueIntegrator.getAddress(),
        minCollectionAmount: ethers.parseEther("0.005"),
        totalCollected: 0
    };
    await revenueIntegrator.configurePlatform(1, sillyHotelConfig); // PlatformType.SILLY_HOTEL
    console.log("✅ SillyHotel Platform configured (10% fee)");

    // Configure SillyPort Platform (100% subscription fees)
    console.log("🎯 Setting up SillyPort Platform...");
    const sillyPortConfig = {
        contractAddress: ethers.ZeroAddress,
        feePercentage: 10000, // 100%
        isActive: true,
        feeCollector: await revenueIntegrator.getAddress(),
        minCollectionAmount: ethers.parseEther("0.01"),
        totalCollected: 0
    };
    await revenueIntegrator.configurePlatform(2, sillyPortConfig); // PlatformType.SILLY_PORT
    console.log("✅ SillyPort Platform configured (100% subscription fees)");

    // Configure KarmaLabs Assets Platform (2.5% fee)
    console.log("🖼️ Setting up KarmaLabs Assets Platform...");
    const karmaLabsConfig = {
        contractAddress: ethers.ZeroAddress,
        feePercentage: 250, // 2.5%
        isActive: true,
        feeCollector: await revenueIntegrator.getAddress(),
        minCollectionAmount: ethers.parseEther("0.01"),
        totalCollected: 0
    };
    await revenueIntegrator.configurePlatform(3, karmaLabsConfig); // PlatformType.KARMA_LABS_ASSETS
    console.log("✅ KarmaLabs Assets Platform configured (2.5% fee)");

    // ============ CENTRALIZED CREDIT SYSTEM SETUP ============
    console.log("\n💳 Configuring Centralized Credit System...");

    const creditSystemConfig = {
        oracleAddress: deployer.address, // Deployer acts as oracle for demo
        conversionRate: 50 * 1e6, // $0.05 per KARMA token
        minimumPurchase: 10 * 1e6, // $10 minimum
        buybackThreshold: 1000 * 1e6, // $1000 threshold for automatic buyback
        isActive: true,
        totalCreditsIssued: 0
    };

    await revenueIntegrator.configureCreditSystem(creditSystemConfig);
    console.log("✅ Credit System configured:");
    console.log(`   📊 Conversion Rate: $0.05 per KARMA`);
    console.log(`   💵 Minimum Purchase: $10`);
    console.log(`   🎯 Buyback Threshold: $1000`);

    // ============ ECONOMIC SECURITY CONTROLS SETUP ============
    console.log("\n🛡️ Configuring Economic Security Controls...");

    const securityConfig = {
        multisigThreshold: 1000, // 10% of Treasury requires multisig approval
        cooldownPeriod: 86400, // 1 day cooldown between large buybacks
        maxSlippageProtection: 500, // 5% maximum slippage
        sandwichProtection: false, // Start disabled
        flashloanProtection: true, // Enable flashloan protection
        lastLargeBuyback: 0
    };

    await revenueIntegrator.configureSecurityControls(securityConfig);
    console.log("✅ Security Controls configured:");
    console.log(`   🔒 Multisig Threshold: 10% of Treasury`);
    console.log(`   ⏱️ Cooldown Period: 1 day`);
    console.log(`   📉 Max Slippage: 5%`);
    console.log(`   🛡️ Flashloan Protection: Enabled`);

    // Enable MEV Protection
    console.log("🤖 Enabling MEV Protection...");
    await revenueIntegrator.enableMEVProtection(2, ethers.parseUnits("20", "gwei"));
    console.log("✅ MEV Protection enabled (Level 2, 20 gwei max priority fee)");

    // Enable Sandwich Protection
    console.log("🥪 Enabling Sandwich Attack Protection...");
    await revenueIntegrator.enableSandwichProtection(300, 3600); // 3% slippage, 1 hour window
    console.log("✅ Sandwich Protection enabled (3% max slippage, 1 hour frontrun window)");

    console.log("\n🧪 Testing Platform Fee Collection");
    console.log("=" * 80);

    // Test iNFT Trading Fee Collection
    console.log("🎨 Testing iNFT Trading Fee Collection...");
    const tradeAmount = ethers.parseEther("10");
    const iNFTFee = ethers.parseEther("0.05"); // 0.5% of 10 ETH
    
    const trader = deployer; // Use deployer as trader for demo
    await revenueIntegrator.collectINFTTradingFees(tradeAmount, iNFTFee, trader.address, { value: iNFTFee });
    console.log(`✅ Collected ${ethers.formatEther(iNFTFee)} ETH from iNFT trading`);

    // Test SillyHotel Fee Collection
    console.log("🏨 Testing SillyHotel Fee Collection...");
    const purchaseAmount = ethers.parseEther("1");
    const hotelFee = ethers.parseEther("0.1"); // 10% of 1 ETH
    
    await revenueIntegrator.collectSillyHotelFees(purchaseAmount, hotelFee, deployer.address, { value: hotelFee });
    console.log(`✅ Collected ${ethers.formatEther(hotelFee)} ETH from SillyHotel purchases`);

    // Test SillyPort Subscription Fee Collection
    console.log("🎯 Testing SillyPort Subscription Fee Collection...");
    const subscriptionType = 1; // Premium subscription
    const subscriptionFee = ethers.parseEther("0.05"); // $15 equivalent
    
    await revenueIntegrator.collectSillyPortFees(subscriptionType, subscriptionFee, deployer.address, { value: subscriptionFee });
    console.log(`✅ Collected ${ethers.formatEther(subscriptionFee)} ETH from SillyPort subscriptions`);

    // Test KarmaLabs Asset Trading Fee Collection
    console.log("🖼️ Testing KarmaLabs Asset Trading Fee Collection...");
    const assetType = 1;
    const assetTradeAmount = ethers.parseEther("4");
    const assetFee = ethers.parseEther("0.1"); // 2.5% of 4 ETH
    
    await revenueIntegrator.collectKarmaLabsFees(assetType, assetTradeAmount, assetFee, deployer.address, { value: assetFee });
    console.log(`✅ Collected ${ethers.formatEther(assetFee)} ETH from KarmaLabs asset trading`);

    console.log("\n💳 Testing Centralized Credit System");
    console.log("=" * 80);

    // Test Credit Issuance
    console.log("💰 Testing Credit Issuance...");
    const usdAmount = 100 * 1e6; // $100
    const paymentMethod = 1; // STRIPE_CARD
    
    await revenueIntegrator.issueCredits(deployer.address, usdAmount, paymentMethod);
    const creditBalance = await revenueIntegrator.getCreditBalance(deployer.address);
    console.log(`✅ Issued ${creditBalance / 1e6} USD credits to ${deployer.address}`);

    // Test Credit to KARMA Conversion
    console.log("🔄 Testing Credit to KARMA Conversion...");
    const creditsToConvert = 50 * 1e6; // $50 worth
    const expectedKarma = (creditsToConvert * ethers.parseEther("1")) / (50 * 1e6);
    
    await revenueIntegrator.convertCreditsToKarma(creditsToConvert);
    const remainingCredits = await revenueIntegrator.getCreditBalance(deployer.address);
    console.log(`✅ Converted ${creditsToConvert / 1e6} USD credits to ${ethers.formatEther(expectedKarma)} KARMA`);
    console.log(`📊 Remaining credits: ${remainingCredits / 1e6} USD`);

    console.log("\n🔒 Testing Large Buyback Security Controls");
    console.log("=" * 80);

    // Test Large Buyback Approval Request
    console.log("📋 Testing Large Buyback Approval Request...");
    const largeBuybackAmount = ethers.parseEther("15"); // Amount requiring approval
    const justification = "Large buyback for token price support during market volatility";
    
    const tx = await revenueIntegrator.requestLargeBuybackApproval(largeBuybackAmount, justification);
    const receipt = await tx.wait();
    
    // Find the approval ID from events
    const event = receipt.logs.find(log => {
        try {
            const decoded = revenueIntegrator.interface.parseLog(log);
            return decoded.name === "LargeBuybackRequested";
        } catch {
            return false;
        }
    });
    
    if (event) {
        const decoded = revenueIntegrator.interface.parseLog(event);
        const approvalId = decoded.args[0];
        console.log(`✅ Large buyback approval requested (ID: ${approvalId})`);
        console.log(`   💰 Amount: ${ethers.formatEther(largeBuybackAmount)} ETH`);
        console.log(`   📝 Justification: "${justification}"`);

        // Test approval (deployer has multisig approver role)
        console.log("✅ Approving large buyback...");
        await revenueIntegrator.approveLargeBuyback(approvalId);
        console.log(`✅ Large buyback approved by ${deployer.address}`);
    }

    console.log("\n📊 Testing Analytics and Reporting");
    console.log("=" * 80);

    // Get Revenue Metrics
    console.log("📈 Getting Revenue Metrics...");
    const totalPlatformRevenue = await revenueIntegrator.totalPlatformRevenue();
    const totalCreditRevenue = await revenueIntegrator.totalCreditRevenue();
    console.log(`💰 Total Platform Revenue: ${ethers.formatEther(totalPlatformRevenue)} ETH`);
    console.log(`💳 Total Credit Revenue: ${totalCreditRevenue / 1e6} USD`);

    // Get Platform Revenue Breakdown
    console.log("📊 Getting Platform Revenue Breakdown...");
    const [platformRevenues, totalRevenue] = await revenueIntegrator.getPlatformRevenue();
    console.log(`🎨 iNFT Trading: ${ethers.formatEther(platformRevenues[0])} ETH`);
    console.log(`🏨 SillyHotel: ${ethers.formatEther(platformRevenues[1])} ETH`);
    console.log(`🎯 SillyPort: ${ethers.formatEther(platformRevenues[2])} ETH`);
    console.log(`🖼️ KarmaLabs Assets: ${ethers.formatEther(platformRevenues[3])} ETH`);

    // Get Security Configuration
    console.log("🛡️ Getting Security Configuration...");
    const [secConfig, pendingApprovals, lastUpdate] = await revenueIntegrator.getSecurityConfig();
    console.log(`🔒 Multisig Threshold: ${secConfig.multisigThreshold / 100}%`);
    console.log(`⏱️ Cooldown Period: ${secConfig.cooldownPeriod / 86400} days`);
    console.log(`📉 Max Slippage Protection: ${secConfig.maxSlippageProtection / 100}%`);
    console.log(`📋 Pending Approvals: ${pendingApprovals}`);

    // Get Credit System Status
    console.log("💳 Getting Credit System Status...");
    const [creditConfig, totalCredits, conversionRate] = await revenueIntegrator.getCreditSystemStatus();
    console.log(`🎯 Oracle Address: ${creditConfig.oracleAddress}`);
    console.log(`💱 Conversion Rate: $${conversionRate / 1e6} per KARMA`);
    console.log(`💰 Total Credits Issued: ${totalCredits / 1e6} USD`);
    console.log(`📊 Credit System Active: ${creditConfig.isActive}`);

    console.log("\n🎯 Stage 6.2 Revenue Stream Integration Summary");
    console.log("=" * 80);
    console.log("✅ All Stage 6.2 components successfully deployed and configured:");
    console.log("");
    console.log("📱 PLATFORM FEE COLLECTION:");
    console.log(`   🎨 iNFT Trading (0.5% fee): ${ethers.formatEther(platformRevenues[0])} ETH collected`);
    console.log(`   🏨 SillyHotel (10% fee): ${ethers.formatEther(platformRevenues[1])} ETH collected`);
    console.log(`   🎯 SillyPort (100% subs): ${ethers.formatEther(platformRevenues[2])} ETH collected`);
    console.log(`   🖼️ KarmaLabs Assets (2.5%): ${ethers.formatEther(platformRevenues[3])} ETH collected`);
    console.log("");
    console.log("💳 CENTRALIZED CREDIT SYSTEM:");
    console.log(`   💰 Credits Issued: ${totalCredits / 1e6} USD`);
    console.log(`   🔄 Conversion Rate: $0.05 per KARMA`);
    console.log(`   🎯 Buyback Threshold: $1000`);
    console.log(`   ✅ Oracle Integration: Active`);
    console.log("");
    console.log("🛡️ ECONOMIC SECURITY CONTROLS:");
    console.log(`   🔒 Multisig Protection: >10% Treasury requires approval`);
    console.log(`   ⏱️ Cooldown Protection: 1 day between large buybacks`);
    console.log(`   🤖 MEV Protection: Level 2 active`);
    console.log(`   🥪 Sandwich Protection: 3% slippage, 1 hour window`);
    console.log(`   📉 Slippage Protection: 5% maximum`);
    console.log("");
    console.log("📊 ANALYTICS & REPORTING:");
    console.log(`   💰 Total Platform Revenue: ${ethers.formatEther(totalPlatformRevenue)} ETH`);
    console.log(`   💳 Total Credit Revenue: ${totalCreditRevenue / 1e6} USD`);
    console.log(`   📋 Pending Approvals: ${pendingApprovals}`);
    console.log(`   🔄 Real-time Metrics: Available`);

    console.log("\n📋 Contract Addresses:");
    console.log(`🪙 KarmaToken: ${await karmaToken.getAddress()}`);
    console.log(`🏦 MockTreasury: ${await mockTreasury.getAddress()}`);
    console.log(`🔥 BuybackBurn: ${await buybackBurn.getAddress()}`);
    console.log(`💰 RevenueStreamIntegrator: ${await revenueIntegrator.getAddress()}`);

    console.log("\n🎉 Stage 6.2 Revenue Stream Integration deployment completed successfully!");
    console.log("🚀 The Karma Labs ecosystem now has comprehensive revenue capture and tokenomics integration!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }); 