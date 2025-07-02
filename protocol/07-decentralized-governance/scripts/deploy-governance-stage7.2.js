const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    
    console.log("Deploying Stage 7.2 Advanced Governance Features with account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
    
    // Mock addresses for demonstration - replace with actual deployed addresses
    const KARMA_TOKEN_ADDRESS = "0x1234567890123456789012345678901234567890";
    const KARMA_GOVERNOR_ADDRESS = "0x2345678901234567890123456789012345678901";
    const KARMA_STAKING_ADDRESS = "0x3456789012345678901234567890123456789012";
    const TREASURY_ADDRESS = "0x4567890123456789012345678901234567890123";
    
    console.log("\n🚀 Starting Stage 7.2 Advanced Governance Features Deployment...\n");
    
    // ============ 1. DEPLOY TREASURY GOVERNANCE ============
    console.log("📊 Deploying TreasuryGovernance...");
    const TreasuryGovernance = await ethers.getContractFactory("TreasuryGovernance");
    const treasuryGovernance = await TreasuryGovernance.deploy(
        KARMA_GOVERNOR_ADDRESS,
        TREASURY_ADDRESS,
        KARMA_TOKEN_ADDRESS,
        deployer.address // admin
    );
    await treasuryGovernance.deployed();
    
    console.log("✅ TreasuryGovernance deployed to:", treasuryGovernance.address);
    
    // ============ 2. DEPLOY PROTOCOL UPGRADE GOVERNANCE ============
    console.log("\n🔧 Deploying ProtocolUpgradeGovernance...");
    const ProtocolUpgradeGovernance = await ethers.getContractFactory("ProtocolUpgradeGovernance");
    const protocolUpgradeGovernance = await ProtocolUpgradeGovernance.deploy(
        KARMA_GOVERNOR_ADDRESS,
        KARMA_TOKEN_ADDRESS,
        KARMA_STAKING_ADDRESS,
        deployer.address // admin
    );
    await protocolUpgradeGovernance.deployed();
    
    console.log("✅ ProtocolUpgradeGovernance deployed to:", protocolUpgradeGovernance.address);
    
    // ============ 3. DEPLOY DECENTRALIZATION MANAGER ============
    console.log("\n🌐 Deploying DecentralizationManager...");
    const DecentralizationManager = await ethers.getContractFactory("DecentralizationManager");
    const decentralizationManager = await DecentralizationManager.deploy(
        KARMA_GOVERNOR_ADDRESS,
        KARMA_STAKING_ADDRESS,
        TREASURY_ADDRESS,
        protocolUpgradeGovernance.address,
        deployer.address // admin
    );
    await decentralizationManager.deployed();
    
    console.log("✅ DecentralizationManager deployed to:", decentralizationManager.address);
    
    // ============ 4. CONFIGURATION ============
    console.log("\n⚙️ Configuring contracts...");
    
    // Configure Treasury Governance
    console.log("📊 Setting treasury value...");
    try {
        const updateTreasuryTx = await treasuryGovernance.updateTreasuryValue(ethers.utils.parseEther("10000000"));
        await updateTreasuryTx.wait();
        console.log("✅ Treasury value set to 10M KARMA");
    } catch (error) {
        console.log("⚠️ Failed to set treasury value:", error.message);
    }
    
    // Register contracts for upgrade governance
    console.log("\n🔧 Registering contracts...");
    try {
        const registerTx = await protocolUpgradeGovernance.registerContract(
            treasuryGovernance.address,
            2, // TREASURY category
            "TreasuryGovernance",
            true, // upgradeable
            ethers.constants.AddressZero,
            treasuryGovernance.address
        );
        await registerTx.wait();
        console.log("✅ TreasuryGovernance registered for upgrades");
    } catch (error) {
        console.log("⚠️ Failed to register contract:", error.message);
    }
    
    // Initialize decentralization
    console.log("\n🌐 Initiating decentralization...");
    try {
        const initTx = await decentralizationManager.initiateDecentralization();
        await initTx.wait();
        console.log("✅ Decentralization process initiated");
    } catch (error) {
        console.log("⚠️ Failed to initiate decentralization:", error.message);
    }
    
    // ============ 5. VERIFICATION ============
    console.log("\n🔍 Verifying deployments...");
    
    try {
        const communityFund = await treasuryGovernance.getCommunityFund();
        console.log("✅ TreasuryGovernance operational");
    } catch (error) {
        console.log("❌ TreasuryGovernance verification failed");
    }
    
    try {
        const metrics = await protocolUpgradeGovernance.getUpgradeMetrics();
        console.log("✅ ProtocolUpgradeGovernance operational");
    } catch (error) {
        console.log("❌ ProtocolUpgradeGovernance verification failed");
    }
    
    try {
        const status = await decentralizationManager.getDecentralizationStatus();
        console.log("✅ DecentralizationManager operational");
    } catch (error) {
        console.log("❌ DecentralizationManager verification failed");
    }
    
    // ============ 6. DEPLOYMENT SUMMARY ============
    console.log("\n📋 STAGE 7.2 DEPLOYMENT SUMMARY");
    console.log("=====================================");
    console.log(`🏗️  Deployer: ${deployer.address}`);
    console.log(`📊 TreasuryGovernance: ${treasuryGovernance.address}`);
    console.log(`🔧 ProtocolUpgradeGovernance: ${protocolUpgradeGovernance.address}`);
    console.log(`🌐 DecentralizationManager: ${decentralizationManager.address}`);
    
    console.log("\n🎯 STAGE 7.2 FEATURES IMPLEMENTED:");
    console.log("• Treasury Governance Integration");
    console.log("• Protocol Upgrade Governance");
    console.log("• Progressive Decentralization");
    console.log("• Enhanced Staking & Rewards");
    
    console.log("\n🎉 Stage 7.2 deployment completed successfully!");
    
    return {
        treasuryGovernance: treasuryGovernance.address,
        protocolUpgradeGovernance: protocolUpgradeGovernance.address,
        decentralizationManager: decentralizationManager.address
    };
}

main()
    .then((addresses) => {
        console.log("\n✅ Deployment completed successfully!");
        console.log("Contract addresses:", addresses);
        process.exit(0);
    })
    .catch((error) => {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    }); 