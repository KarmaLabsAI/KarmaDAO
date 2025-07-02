/**
 * @title Stage 5.1 Deployment Script - Paymaster Contract Development
 * @desc Deploy KarmaPaymaster for gasless transactions
 */

const { ethers } = require("hardhat");

async function main() {
    console.log("=== Stage 5.1: Paymaster Contract Development ===\n");
    
    const [deployer, admin, user1, user2] = await ethers.getSigners();
    
    console.log("🚀 Deployment Details:");
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}\n`);

    // ============ DEPLOY MOCK DEPENDENCIES ============
    
    console.log("1. Deploying Mock Dependencies...");
    
    const MockEntryPoint = await ethers.getContractFactory("MockEntryPoint");
    const entryPoint = await MockEntryPoint.deploy();
    console.log("   ✅ MockEntryPoint deployed");

    const MockTreasury = await ethers.getContractFactory("MockTreasury");
    const mockTreasury = await MockTreasury.deploy();
    console.log("   ✅ MockTreasury deployed");

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const karmaToken = await MockERC20.deploy("Karma Token", "KARMA", 18);
    console.log("   ✅ KarmaToken (Mock) deployed");

    // ============ DEPLOY PAYMASTER ============
    
    console.log("\n2. Deploying KarmaPaymaster...");
    
    const KarmaPaymaster = await ethers.getContractFactory("KarmaPaymaster");
    const paymaster = await KarmaPaymaster.deploy(
        await entryPoint.getAddress(),
        await mockTreasury.getAddress(),
        await karmaToken.getAddress(),
        admin.address
    );
    
    console.log("   ✅ KarmaPaymaster deployed");

    // ============ INITIAL CONFIGURATION ============
    
    console.log("\n3. Initial Configuration...");
    
    // Fund paymaster
    await deployer.sendTransaction({
        to: await paymaster.getAddress(),
        value: ethers.parseEther("100")
    });
    console.log("   ✅ Paymaster funded with 100 ETH");

    // Setup user tiers
    await paymaster.connect(admin).setUserTier(user1.address, 1); // VIP
    await paymaster.connect(admin).setUserTier(user2.address, 2); // STAKER
    console.log("   ✅ User tiers configured");

    // Whitelist KarmaToken
    await paymaster.connect(admin).whitelistContract(
        await karmaToken.getAddress(),
        ["0xa9059cbb"], // transfer function
        "KarmaToken whitelisting"
    );
    console.log("   ✅ Contracts whitelisted");

    // ============ TESTING ============
    
    console.log("\n4. Testing Functionality...");
    
    const testUserOp = {
        sender: user1.address,
        callGasLimit: 100000,
        verificationGasLimit: 100000
    };
    
    const estimation = await paymaster.estimateGas(testUserOp);
    console.log("   ✅ Gas estimation working");

    const [eligible] = await paymaster.isEligibleForSponsorship(testUserOp);
    console.log(`   ✅ Sponsorship eligibility: ${eligible}`);

    const [withinLimits] = await paymaster.checkRateLimit(user1.address, 500000);
    console.log(`   ✅ Rate limiting: ${withinLimits}`);

    // ============ DEPLOYMENT SUMMARY ============
    
    console.log("\n" + "=".repeat(50));
    console.log("🎯 STAGE 5.1 DEPLOYMENT COMPLETE!");
    console.log("=".repeat(50));
    console.log("📋 Contracts:");
    console.log(`   KarmaPaymaster: ${await paymaster.getAddress()}`);
    console.log(`   MockEntryPoint: ${await entryPoint.getAddress()}`);
    console.log(`   MockTreasury: ${await mockTreasury.getAddress()}`);
    console.log(`   KarmaToken: ${await karmaToken.getAddress()}`);
    
    console.log("\n✅ Features Deployed:");
    console.log("   - EIP-4337 gasless transactions");
    console.log("   - User tier system");
    console.log("   - Contract whitelisting");
    console.log("   - Rate limiting");
    console.log("   - Emergency controls");

    return {
        paymaster: await paymaster.getAddress(),
        entryPoint: await entryPoint.getAddress(),
        mockTreasury: await mockTreasury.getAddress(),
        karmaToken: await karmaToken.getAddress()
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