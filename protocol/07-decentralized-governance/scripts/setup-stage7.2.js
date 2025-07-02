const { ethers } = require("hardhat");
const config = require("../config/stage7.2-config.json");

async function main() {
    console.log("⚙️  Setting up Stage 7.2: Advanced Governance Features");
    
    const [deployer, admin] = await ethers.getSigners();
    console.log("Setup by:", deployer.address);
    
    // Get deployed contract addresses
    const TREASURY_GOVERNANCE_ADDRESS = process.env.TREASURY_GOVERNANCE_ADDRESS || "0x...";
    const PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS = process.env.PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS || "0x...";
    const DECENTRALIZATION_MANAGER_ADDRESS = process.env.DECENTRALIZATION_MANAGER_ADDRESS || "0x...";
    const GOVERNANCE_STAKING_ADDRESS = process.env.GOVERNANCE_STAKING_ADDRESS || "0x...";
    
    console.log("\n📋 Setting up Advanced Governance...");
    
    // Connect to contracts
    const treasuryGovernance = await ethers.getContractAt("TreasuryGovernance", TREASURY_GOVERNANCE_ADDRESS);
    const protocolUpgradeGovernance = await ethers.getContractAt("ProtocolUpgradeGovernance", PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS);
    const decentralizationManager = await ethers.getContractAt("DecentralizationManager", DECENTRALIZATION_MANAGER_ADDRESS);
    const governanceStaking = await ethers.getContractAt("GovernanceStaking", GOVERNANCE_STAKING_ADDRESS);
    
    console.log("\n💰 Configuring Treasury Governance...");
    
    try {
        // Set up treasury governance parameters
        await treasuryGovernance.connect(admin).updateFundAllocationLimit(
            ethers.parseEther("10000000") // 10M KARMA limit
        );
        
        await treasuryGovernance.connect(admin).setCommunityFundPercentage(
            config.treasuryGovernance.communityFundPercentage
        );
        
        console.log("✅ Treasury governance configured");
    } catch (error) {
        console.log("⚠️  Treasury governance setup error:", error.message);
    }
    
    console.log("\n🔧 Configuring Protocol Upgrade Governance...");
    
    try {
        // Set up protocol upgrade parameters
        await protocolUpgradeGovernance.connect(admin).updateUpgradeThreshold(
            ethers.parseEther("2000000") // 2M KARMA threshold for upgrades
        );
        
        console.log("✅ Protocol upgrade governance configured");
    } catch (error) {
        console.log("⚠️  Protocol upgrade governance setup error:", error.message);
    }
    
    console.log("\n🏛️  Configuring Decentralization Manager...");
    
    try {
        // Initialize decentralization transition
        await decentralizationManager.connect(admin).initializeTransition(
            config.decentralization.transitionPeriod,
            config.decentralization.finalCommunityControl
        );
        
        console.log("✅ Decentralization manager configured");
    } catch (error) {
        console.log("⚠️  Decentralization manager setup error:", error.message);
    }
    
    console.log("\n🎯 Configuring Staking Rewards...");
    
    try {
        // Set up governance staking rewards
        await governanceStaking.connect(admin).initializeStage72Features(admin.address);
        
        console.log("✅ Staking rewards configured");
    } catch (error) {
        console.log("⚠️  Staking rewards setup error:", error.message);
    }
    
    console.log("\n🎉 Stage 7.2 setup completed successfully!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Setup failed:", error);
        process.exit(1);
    }); 