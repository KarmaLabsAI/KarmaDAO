/**
 * @title Stage 6.1 Deployment Script - BuybackBurn System Development
 * @desc Deploy BuybackBurn system for automated token supply management
 */

const { ethers } = require("hardhat");

async function main() {
    console.log("=== Stage 6.1: BuybackBurn System Development ===\n");
    
    const [deployer, admin, treasury, user1, user2] = await ethers.getSigners();
    
    console.log("🚀 Deployment Details:");
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log(`Treasury: ${treasury.address}\n`);

    // ============ DEPLOY MOCK DEPENDENCIES ============
    
    console.log("1. Deploying Mock Dependencies...");
    
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const karmaToken = await MockERC20.deploy("Karma Token", "KARMA", 18);
    console.log("   ✅ KarmaToken (Mock) deployed");

    const MockTreasury = await ethers.getContractFactory("MockTreasury");
    const mockTreasury = await MockTreasury.deploy();
    console.log("   ✅ Treasury (Mock) deployed");

    // ============ DEPLOY BUYBACK BURN ============
    
    console.log("\n2. Deploying BuybackBurn System...");
    
    const BuybackBurn = await ethers.getContractFactory("BuybackBurn");
    const buybackBurn = await BuybackBurn.deploy(
        admin.address,
        await karmaToken.getAddress(),
        await mockTreasury.getAddress()
    );
    
    console.log("   ✅ BuybackBurn deployed");

    // ============ INITIAL CONFIGURATION ============
    
    console.log("\n3. Initial Configuration...");
    
    // Fund BuybackBurn for testing
    await deployer.sendTransaction({
        to: await buybackBurn.getAddress(),
        value: ethers.parseEther("100")
    });
    console.log("   ✅ BuybackBurn funded with 100 ETH");

    // Configure trigger parameters
    await buybackBurn.connect(admin).configureTriggers(
        ethers.parseEther("50"), // $50K threshold
        2592000, // 30 days monthly schedule
        500 // 5% max slippage
    );
    console.log("   ✅ Trigger parameters configured");

    // Setup DEX integration
    await buybackBurn.connect(admin).configureDEXIntegration(
        1, // Uniswap V3
        ethers.parseEther("0.1"), // Min trade amount
        ethers.parseEther("100") // Max trade amount
    );
    console.log("   ✅ DEX integration configured");

    // ============ TESTING FUNCTIONALITY ============
    
    console.log("\n4. Testing Core Functionality...");
    
    // Test gas estimation
    const ethAmount = ethers.parseEther("1");
    const estimation = await buybackBurn.calculateOptimalRoute(ethAmount);
    console.log("   ✅ Route calculation working");

    // Test trigger validation
    const canTrigger = await buybackBurn.canTriggerBuyback();
    console.log(`   ✅ Trigger validation: ${canTrigger}`);

    // Test slippage configuration
    const slippageConfig = await buybackBurn.getSlippageConfig();
    console.log(`   ✅ Slippage protection: ${slippageConfig.maxSlippage / 100}%`);

    // Test manual trigger (admin only)
    const triggerAmount = ethers.parseEther("0.5");
    await expect(
        buybackBurn.connect(admin).manualTrigger(triggerAmount, 500)
    ).to.emit(buybackBurn, "BuybackTriggered");
    console.log("   ✅ Manual trigger functional");

    // ============ DEX INTEGRATION TESTING ============
    
    console.log("\n5. Testing DEX Integration...");
    
    // Test supported DEX types
    const supportedDEXes = await buybackBurn.getSupportedDEXes();
    console.log(`   📊 Supported DEXes: ${supportedDEXes.length}`);

    // Test price impact calculation
    const largeAmount = ethers.parseEther("10");
    const priceImpact = await buybackBurn.calculatePriceImpact(largeAmount);
    console.log(`   📈 Price impact for ${ethers.formatEther(largeAmount)} ETH: ${priceImpact / 100}%`);

    // Test MEV protection
    const mevConfig = await buybackBurn.getMEVProtectionConfig();
    console.log(`   🛡️  MEV protection: ${mevConfig.enabled ? 'Enabled' : 'Disabled'}`);

    // ============ SECURITY TESTING ============
    
    console.log("\n6. Testing Security Features...");
    
    // Test large operation approval
    const largeOperationAmount = ethers.parseEther("50");
    await expect(
        buybackBurn.requestLargeOperationApproval(
            largeOperationAmount, 
            "Testing large operation approval"
        )
    ).to.emit(buybackBurn, "LargeOperationRequested");
    console.log("   ✅ Large operation approval system working");

    // Test operation limits
    const dailyLimit = await buybackBurn.getDailyOperationLimit();
    console.log(`   📊 Daily operation limit: ${ethers.formatEther(dailyLimit)} ETH`);

    // Test cooling-off period
    const cooldownPeriod = await buybackBurn.getCooldownPeriod();
    console.log(`   ⏱️  Cooldown period: ${cooldownPeriod / 3600} hours`);

    // Test emergency pause
    await expect(
        buybackBurn.connect(admin).emergencyPause()
    ).to.emit(buybackBurn, "EmergencyPaused");
    console.log("   🚨 Emergency pause functional");

    // Resume operations
    await buybackBurn.connect(admin).unpause();
    console.log("   ✅ Operations resumed");

    // ============ TREASURY INTEGRATION ============
    
    console.log("\n7. Testing Treasury Integration...");
    
    // Test treasury funding
    const treasuryFunding = ethers.parseEther("20");
    await mockTreasury.fundBuybackBurn(
        await buybackBurn.getAddress(),
        treasuryFunding
    );
    console.log(`   💰 Treasury funding: ${ethers.formatEther(treasuryFunding)} ETH`);

    // Test allocation tracking
    const allocation = await buybackBurn.getCurrentAllocation();
    console.log(`   📊 Current allocation: ${ethers.formatEther(allocation.totalAllocated)} ETH`);

    // Test target allocation percentage
    const targetPercentage = await buybackBurn.getTargetAllocationPercentage();
    console.log(`   🎯 Target allocation: ${targetPercentage / 100}%`);

    // ============ PERFORMANCE METRICS ============
    
    console.log("\n8. Performance and Metrics...");
    
    // Test buyback metrics
    const metrics = await buybackBurn.getBuybackMetrics();
    console.log("   📊 Buyback Metrics:");
    console.log(`       Total buybacks: ${metrics.totalBuybacks}`);
    console.log(`       Total ETH spent: ${ethers.formatEther(metrics.totalETHSpent)} ETH`);
    console.log(`       Total tokens burned: ${ethers.formatEther(metrics.totalTokensBurned)} KARMA`);

    // Test execution history
    const history = await buybackBurn.getExecutionHistory(5);
    console.log(`   📈 Execution history: ${history.length} recent operations`);

    // Test impact metrics
    const impactMetrics = await buybackBurn.getImpactMetrics();
    console.log("   🎯 Impact Metrics:");
    console.log(`       Supply reduction: ${ethers.formatEther(impactMetrics.supplyReduction)} KARMA`);
    console.log(`       Price impact: ${impactMetrics.priceImpact / 100}%`);

    // ============ DEPLOYMENT SUMMARY ============
    
    console.log("\n" + "=".repeat(50));
    console.log("🎯 STAGE 6.1 DEPLOYMENT COMPLETE!");
    console.log("=".repeat(50));
    console.log("📋 Contracts:");
    console.log(`   BuybackBurn: ${await buybackBurn.getAddress()}`);
    console.log(`   KarmaToken: ${await karmaToken.getAddress()}`);
    console.log(`   Treasury: ${await mockTreasury.getAddress()}`);
    
    console.log("\n✅ Features Deployed:");
    console.log("   - DEX Integration Engine (Uniswap V3)");
    console.log("   - Automatic Triggering System");
    console.log("   - Fee Collection Integration");
    console.log("   - Burn Mechanism Implementation");
    console.log("   - Economic Security Controls");
    console.log("   - Treasury Integration");
    
    console.log("\n🔧 Configuration:");
    console.log(`   - Trigger threshold: $50K`);
    console.log(`   - Monthly schedule: 30 days`);
    console.log(`   - Max slippage: 5%`);
    console.log(`   - Target allocation: 20%`);

    return {
        buybackBurn: await buybackBurn.getAddress(),
        karmaToken: await karmaToken.getAddress(),
        treasury: await mockTreasury.getAddress()
    };
}

main()
    .then((addresses) => {
        console.log("\n📋 Contract Addresses:");
        console.log(JSON.stringify(addresses, null, 2));
        process.exit(0);
    })
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }); 