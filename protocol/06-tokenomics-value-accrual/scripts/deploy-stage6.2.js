/**
 * @title Stage 6.2 Deployment Script - Revenue Stream Integration
 * @desc Deploy comprehensive revenue capture feeding tokenomics engine
 */

const { ethers } = require("hardhat");

async function main() {
    console.log("=== Stage 6.2: Revenue Stream Integration ===\n");
    
    const [deployer, admin, oracle, user1, user2] = await ethers.getSigners();
    
    console.log("🚀 Deployment Details:");
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log(`Oracle: ${oracle.address}\n`);

    // Deploy dependencies
    console.log("1. Deploying Dependencies...");
    
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const karmaToken = await MockERC20.deploy("Karma Token", "KARMA", 18);
    console.log("   ✅ KarmaToken deployed");

    const MockTreasury = await ethers.getContractFactory("MockTreasury");
    const treasury = await MockTreasury.deploy();
    console.log("   ✅ Treasury deployed");

    const BuybackBurn = await ethers.getContractFactory("BuybackBurn");
    const buybackBurn = await BuybackBurn.deploy(
        admin.address,
        await karmaToken.getAddress(),
        await treasury.getAddress()
    );
    console.log("   ✅ BuybackBurn deployed");

    // Deploy FeeCollector
    console.log("\n2. Deploying Revenue Stream Integration...");
    
    const FeeCollector = await ethers.getContractFactory("RevenueStreamIntegrator");
    const feeCollector = await FeeCollector.deploy(
        admin.address,
        await karmaToken.getAddress(),
        await treasury.getAddress(),
        await buybackBurn.getAddress(),
        oracle.address
    );
    
    console.log("   ✅ FeeCollector (RevenueStreamIntegrator) deployed");

    return {
        feeCollector: await feeCollector.getAddress(),
        buybackBurn: await buybackBurn.getAddress(),
        karmaToken: await karmaToken.getAddress(),
        treasury: await treasury.getAddress()
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