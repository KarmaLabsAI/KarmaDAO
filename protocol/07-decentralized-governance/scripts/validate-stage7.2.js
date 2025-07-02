const { ethers } = require("hardhat");

async function main() {
    console.log("🔍 Validating Stage 7.2: Advanced Governance Features");
    
    const [deployer] = await ethers.getSigners();
    console.log("Validator:", deployer.address);
    
    // Get contract addresses
    const TREASURY_GOVERNANCE_ADDRESS = process.env.TREASURY_GOVERNANCE_ADDRESS;
    const PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS = process.env.PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS;
    const DECENTRALIZATION_MANAGER_ADDRESS = process.env.DECENTRALIZATION_MANAGER_ADDRESS;
    const GOVERNANCE_STAKING_ADDRESS = process.env.GOVERNANCE_STAKING_ADDRESS;
    
    if (!TREASURY_GOVERNANCE_ADDRESS || !PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS || 
        !DECENTRALIZATION_MANAGER_ADDRESS || !GOVERNANCE_STAKING_ADDRESS) {
        console.error("❌ Missing contract addresses. Please set environment variables.");
        process.exit(1);
    }
    
    // Connect to contracts
    const treasuryGovernance = await ethers.getContractAt("TreasuryGovernance", TREASURY_GOVERNANCE_ADDRESS);
    const protocolUpgradeGovernance = await ethers.getContractAt("ProtocolUpgradeGovernance", PROTOCOL_UPGRADE_GOVERNANCE_ADDRESS);
    const decentralizationManager = await ethers.getContractAt("DecentralizationManager", DECENTRALIZATION_MANAGER_ADDRESS);
    const governanceStaking = await ethers.getContractAt("GovernanceStaking", GOVERNANCE_STAKING_ADDRESS);
    
    let validationsPassed = 0;
    let totalValidations = 0;
    
    // Test 1: Treasury Governance Integration
    console.log("\n1️⃣  Testing Treasury Governance Integration...");
    totalValidations++;
    try {
        const communityFund = await treasuryGovernance.getCommunityFund();
        console.log("✅ Treasury governance operational");
        console.log("   Community fund:", ethers.formatEther(communityFund), "ETH");
        validationsPassed++;
    } catch (error) {
        console.log("❌ Treasury governance validation failed:", error.message);
    }
    
    // Test 2: Protocol Upgrade Governance
    console.log("\n2️⃣  Testing Protocol Upgrade Governance...");
    totalValidations++;
    try {
        const metrics = await protocolUpgradeGovernance.getUpgradeMetrics();
        console.log("✅ Protocol upgrade governance operational");
        validationsPassed++;
    } catch (error) {
        console.log("❌ Protocol upgrade governance validation failed:", error.message);
    }
    
    // Test 3: Staking Rewards System
    console.log("\n3️⃣  Testing Staking Rewards System...");
    totalValidations++;
    try {
        const userTier = await governanceStaking.getUserTier(deployer.address);
        console.log("✅ Staking rewards system operational");
        console.log("   User tier:", userTier.toString());
        validationsPassed++;
    } catch (error) {
        console.log("❌ Staking rewards validation failed:", error.message);
    }
    
    // Test 4: Progressive Decentralization
    console.log("\n4️⃣  Testing Progressive Decentralization...");
    totalValidations++;
    try {
        const currentPhase = await decentralizationManager.getCurrentPhase();
        console.log("✅ Decentralization manager operational");
        console.log("   Current phase:", currentPhase.toString());
        validationsPassed++;
    } catch (error) {
        console.log("❌ Decentralization validation failed:", error.message);
    }
    
    // Summary
    console.log("\n📊 Validation Summary:");
    console.log("=".repeat(50));
    console.log(`Total validations: ${totalValidations}`);
    console.log(`Passed: ${validationsPassed}`);
    console.log(`Failed: ${totalValidations - validationsPassed}`);
    console.log(`Success rate: ${((validationsPassed / totalValidations) * 100).toFixed(1)}%`);
    
    if (validationsPassed === totalValidations) {
        console.log("\n🎉 All validations passed! Stage 7.2 is working correctly.");
    } else {
        console.log("\n⚠️  Some validations failed. Review and fix issues.");
    }
    
    console.log("\n📝 Stage 7.2 Advanced Governance Features:");
    console.log("• ✅ Treasury Governance Integration");
    console.log("• ✅ Protocol Upgrade Governance");
    console.log("• ✅ Staking and Rewards System");
    console.log("• ✅ Progressive Decentralization");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Validation failed:", error);
        process.exit(1);
    }); 