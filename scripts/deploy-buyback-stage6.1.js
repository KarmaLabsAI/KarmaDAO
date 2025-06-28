const { ethers } = require("hardhat");

/**
 * Stage 6.1 Deployment Script: BuybackBurn System Development
 */

async function main() {
    console.log("🚀 Stage 6.1 Deployment: BuybackBurn System Development");
    console.log("=" .repeat(80));

    // Get signers
    const [deployer, admin] = await ethers.getSigners();
    
    console.log("📋 Deployment Configuration:");
    console.log(`   Deployer: ${deployer.address}`);
    console.log(`   Admin: ${admin.address}`);

    // Deploy KarmaToken
    console.log("\n🏗️  Deploying Core Contracts...");
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(admin.address);
    await karmaToken.waitForDeployment();
    console.log(`   ✅ KarmaToken deployed: ${await karmaToken.getAddress()}`);

    // Deploy MockTreasury (to avoid contract size issues in testing)
    const MockTreasury = await ethers.getContractFactory("MockTreasury");
    const mockTreasury = await MockTreasury.deploy();
    await mockTreasury.waitForDeployment();
    console.log(`   ✅ MockTreasury deployed: ${await mockTreasury.getAddress()}`);

    // Deploy BuybackBurn
    const BuybackBurn = await ethers.getContractFactory("BuybackBurn");
    const buybackBurn = await BuybackBurn.deploy(
        admin.address, 
        await karmaToken.getAddress(), 
        await mockTreasury.getAddress()
    );
    await buybackBurn.waitForDeployment();
    console.log(`   ✅ BuybackBurn deployed: ${await buybackBurn.getAddress()}`);

    // ============ SETUP ROLES AND PERMISSIONS ============
    console.log("\n🔐 Setting up Roles and Permissions...");

    const BUYBACK_MANAGER_ROLE = await buybackBurn.BUYBACK_MANAGER_ROLE();
    const FEE_COLLECTOR_ROLE = await buybackBurn.FEE_COLLECTOR_ROLE();
    const KEEPER_ROLE = await buybackBurn.KEEPER_ROLE();

    await buybackBurn.connect(admin).grantRole(BUYBACK_MANAGER_ROLE, deployer.address);
    await buybackBurn.connect(admin).grantRole(FEE_COLLECTOR_ROLE, deployer.address);
    await buybackBurn.connect(admin).grantRole(KEEPER_ROLE, deployer.address);

    console.log(`   ✅ Roles granted to deployer for demonstration`);

    // ============ STAGE 6.1: DEX INTEGRATION ENGINE ============
    console.log("\n" + "=".repeat(80));
    console.log("🏪 Stage 6.1 Demo: DEX Integration Engine");
    console.log("=".repeat(80));

    // Configure Uniswap V3
    console.log("\n🦄 Configuring Uniswap V3 Integration...");
    const uniswapConfig = {
        router: deployer.address, // Mock router for demo
        factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984", // Actual Uniswap V3 Factory
        poolFee: 3000, // 0.3%
        isActive: true,
        minLiquidity: ethers.parseEther("100"),
        maxSlippage: 300 // 3%
    };

    await buybackBurn.connect(deployer).configureDEX(0, uniswapConfig); // DEXType.UNISWAP_V3 = 0
    console.log(`   ✅ Uniswap V3 configured with 3% max slippage`);

    // Test optimal routing
    console.log("\n🔄 Testing Optimal Route Calculation...");
    const testAmount = ethers.parseEther("5");
    const [bestDex, expectedTokens, priceImpact] = await buybackBurn.getOptimalRoute(testAmount);
    console.log(`   ✅ Optimal route for ${ethers.formatEther(testAmount)} ETH:`);
    console.log(`      Best DEX: ${bestDex === 0 ? 'Uniswap V3' : 'Other'}`);
    console.log(`      Expected KARMA: ${ethers.formatEther(expectedTokens)}`);
    console.log(`      Price Impact: ${Number(priceImpact) / 100}%`);

    // ============ STAGE 6.1: FEE COLLECTION INTEGRATION ============
    console.log("\n" + "=".repeat(80));
    console.log("💰 Stage 6.1 Demo: Fee Collection Integration");
    console.log("=".repeat(80));

    // Configure fee collection sources
    console.log("\n📊 Configuring Fee Collection Sources...");
    const inftConfig = {
        source: 0, // FeeSource.INFT_TRADES
        collector: deployer.address,
        percentage: 50, // 0.5%
        isActive: true,
        totalCollected: 0
    };
    await buybackBurn.connect(deployer).configureFeeCollection(0, inftConfig);
    console.log(`   ✅ iNFT Trade fees configured: 0.5% collection rate`);

    // Demonstrate fee collection
    console.log("\n💳 Demonstrating Fee Collection...");
    const inftFeeAmount = ethers.parseEther("0.5");
    await buybackBurn.connect(deployer).collectPlatformFees(inftFeeAmount, 0, { value: inftFeeAmount });
    console.log(`   ✅ Collected iNFT trade fees: ${ethers.formatEther(inftFeeAmount)} ETH`);

    const creditSurchargeAmount = ethers.parseEther("1.0");
    await buybackBurn.connect(deployer).collectCreditSurcharge(creditSurchargeAmount, { value: creditSurchargeAmount });
    console.log(`   ✅ Collected credit surcharge fees: ${ethers.formatEther(creditSurchargeAmount)} ETH`);

    // Show total fees
    const [totalFees, feeBreakdown] = await buybackBurn.getTotalFeesCollected();
    console.log(`\n📈 Total Fee Collection Summary:`);
    console.log(`   Total Fees: ${ethers.formatEther(totalFees)} ETH`);
    console.log(`   iNFT Trades: ${ethers.formatEther(feeBreakdown[0])} ETH`);
    console.log(`   Credit Surcharge: ${ethers.formatEther(feeBreakdown[1])} ETH`);

    // ============ STAGE 6.1: BURN MECHANISM IMPLEMENTATION ============
    console.log("\n" + "=".repeat(80));
    console.log("🔥 Stage 6.1 Demo: Burn Mechanism Implementation");
    console.log("=".repeat(80));

    // Mint some KARMA tokens to the contract for burning
    console.log("\n💰 Setting up for Burn Demo...");
    const MINTER_ROLE = await karmaToken.MINTER_ROLE();
    await karmaToken.connect(admin).grantRole(MINTER_ROLE, admin.address);
    
    const tokenAmount = ethers.parseEther("50000");
    await karmaToken.connect(admin).mint(await buybackBurn.getAddress(), tokenAmount);
    console.log(`   ✅ Minted ${ethers.formatEther(tokenAmount)} KARMA tokens to BuybackBurn`);

    // Test optimal burn calculation
    console.log("\n🧮 Testing Optimal Burn Calculation...");
    const availableTokens = ethers.parseEther("10000");
    const [recommendedBurn, reasoning] = await buybackBurn.calculateOptimalBurn(availableTokens);
    console.log(`   ✅ Optimal burn calculation for ${ethers.formatEther(availableTokens)} tokens:`);
    console.log(`      Recommended Burn: ${ethers.formatEther(recommendedBurn)} KARMA`);
    console.log(`      Reasoning: ${reasoning}`);

    // Execute token burn
    console.log("\n🔥 Executing Token Burn...");
    const burnAmount = ethers.parseEther("5000");
    await buybackBurn.connect(deployer).burnTokens(burnAmount);
    console.log(`   ✅ Burned ${ethers.formatEther(burnAmount)} KARMA tokens`);

    // Show burn statistics
    const [totalBurned, burnCount, lastBurn, currentSupply] = await buybackBurn.getBurnStatistics();
    console.log(`   📊 Burn Statistics:`);
    console.log(`      Total Burned: ${ethers.formatEther(totalBurned)} KARMA`);
    console.log(`      Burn Count: ${burnCount}`);
    console.log(`      Current Supply: ${ethers.formatEther(currentSupply)} KARMA`);

    // ============ CONFIGURATION DEMO ============
    console.log("\n" + "=".repeat(80));
    console.log("⚙️  Stage 6.1 Demo: Configuration and Management");
    console.log("=".repeat(80));

    // Configure auto-trigger
    console.log("\n🤖 Configuring Automatic Triggering...");
    const autoTriggerConfig = {
        enabled: true,
        monthlySchedule: 15,
        thresholdAmount: ethers.parseEther("10"), // Lower threshold for demo
        lastExecution: 0,
        cooldownPeriod: 3600 // 1 hour for demo
    };

    await buybackBurn.connect(deployer).configureAutoTrigger(autoTriggerConfig);
    console.log(`   ✅ Auto-trigger configured:`);
    console.log(`      Enabled: ${autoTriggerConfig.enabled}`);
    console.log(`      Monthly Schedule: ${autoTriggerConfig.monthlySchedule}th of each month`);
    console.log(`      Threshold: ${ethers.formatEther(autoTriggerConfig.thresholdAmount)} ETH`);

    // Test trigger condition
    const [shouldExecute, triggerType, ethAmount] = await buybackBurn.checkTriggerCondition();
    console.log(`   ✅ Trigger condition check:`);
    console.log(`      Should Execute: ${shouldExecute}`);
    console.log(`      Trigger Type: ${triggerType}`);
    console.log(`      ETH Amount: ${ethers.formatEther(ethAmount)}`);

    // Get final metrics
    console.log("\n📊 Final System Metrics...");
    const metrics = await buybackBurn.getBuybackMetrics();
    const [ethBalance, karmaBalance, availableForBuyback] = await buybackBurn.getBalanceStatus();

    console.log(`   📈 System Status:`);
    console.log(`      ETH Balance: ${ethers.formatEther(ethBalance)}`);
    console.log(`      KARMA Balance: ${ethers.formatEther(karmaBalance)}`);
    console.log(`      Available for Buyback: ${ethers.formatEther(availableForBuyback)}`);
    console.log(`      Total Executions: ${metrics.totalExecutions}`);

    // ============ FINAL SUMMARY ============
    console.log("\n" + "=".repeat(80));
    console.log("✅ Stage 6.1 Implementation Complete: BuybackBurn System");
    console.log("=".repeat(80));

    console.log("\n🏆 Stage 6.1 Features Successfully Implemented:");
    console.log("   ✅ DEX Integration Engine (Uniswap V3, SushiSwap, Balancer, Curve)");
    console.log("   ✅ Optimal routing algorithms with price impact calculation");
    console.log("   ✅ Slippage protection (max 5% configurable)");
    console.log("   ✅ Automatic Triggering System (monthly + $50K threshold)");
    console.log("   ✅ Fee Collection Integration (iNFT trades, credit surcharges, etc.)");
    console.log("   ✅ Burn Mechanism Implementation with batch capabilities");
    console.log("   ✅ Comprehensive analytics and reporting");
    console.log("   ✅ Role-based access control and emergency mechanisms");

    console.log("\n💎 Contract Addresses:");
    console.log(`   KarmaToken: ${await karmaToken.getAddress()}`);
    console.log(`   MockTreasury: ${await mockTreasury.getAddress()}`);
    console.log(`   BuybackBurn: ${await buybackBurn.getAddress()}`);

    console.log("\n🎉 Stage 6.1 deployment completed successfully!");

    return {
        karmaToken: await karmaToken.getAddress(),
        mockTreasury: await mockTreasury.getAddress(),
        buybackBurn: await buybackBurn.getAddress(),
        deployer: deployer.address,
        timestamp: new Date().toISOString()
    };
}

main().then(() => process.exit(0)).catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
});
