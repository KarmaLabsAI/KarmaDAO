const { ethers } = require("hardhat");
const config = require("../config/stage7.1-config.json");

async function main() {
    console.log("⚙️  Setting up Stage 7.1: KarmaDAO Core Governance System");
    
    const [deployer, admin] = await ethers.getSigners();
    console.log("Setup by:", deployer.address);
    
    // Get deployed contract addresses (these would be loaded from deployment artifacts)
    const KARMA_TOKEN_ADDRESS = process.env.KARMA_TOKEN_ADDRESS || "0x...";
    const KARMA_DAO_ADDRESS = process.env.KARMA_DAO_ADDRESS || "0x...";
    const GOVERNANCE_STAKING_ADDRESS = process.env.GOVERNANCE_STAKING_ADDRESS || "0x...";
    const QUADRATIC_VOTING_ADDRESS = process.env.QUADRATIC_VOTING_ADDRESS || "0x...";
    const TIMELOCK_CONTROLLER_ADDRESS = process.env.TIMELOCK_CONTROLLER_ADDRESS || "0x...";
    
    // Connect to deployed contracts
    const karmaDAO = await ethers.getContractAt("KarmaDAO", KARMA_DAO_ADDRESS);
    const governanceStaking = await ethers.getContractAt("GovernanceStaking", GOVERNANCE_STAKING_ADDRESS);
    const quadraticVoting = await ethers.getContractAt("QuadraticVoting", QUADRATIC_VOTING_ADDRESS);
    const timelockController = await ethers.getContractAt("TimelockController", TIMELOCK_CONTROLLER_ADDRESS);
    
    console.log("\n📋 Configuring Governance Parameters...");
    
    // Configure governance parameters
    const governanceConfig = {
        proposalThreshold: ethers.parseEther("1000000"), // 1M KARMA
        quorumPercentage: config.governance.quorumPercentage,
        votingDelay: config.governance.votingDelay,
        votingPeriod: config.governance.votingPeriod,
        executionDelay: config.governance.executionDelay,
        maxActions: config.governance.maxActions,
        quadraticVotingEnabled: config.governance.quadraticVotingEnabled
    };
    
    try {
        await karmaDAO.connect(admin).updateGovernanceConfig(governanceConfig);
        console.log("✅ Governance configuration updated");
    } catch (error) {
        console.log("⚠️  Governance config already set or error:", error.message);
    }
    
    console.log("\n🔄 Configuring Quadratic Voting...");
    
    // Configure quadratic voting parameters
    const quadraticConfig = {
        baseWeight: ethers.parseEther("1"),
        scalingFactor: ethers.parseEther("0.5"),
        maxWeight: ethers.parseEther("100000"),
        minStakeRequired: ethers.parseEther("100"),
        enabled: true
    };
    
    try {
        await quadraticVoting.connect(admin).updateQuadraticConfig(quadraticConfig);
        console.log("✅ Quadratic voting configuration updated");
    } catch (error) {
        console.log("⚠️  Quadratic voting config already set or error:", error.message);
    }
    
    console.log("\n🔐 Setting up Role Permissions...");
    
    // Grant necessary roles to the DAO contract
    const PROPOSER_ROLE = await timelockController.PROPOSER_ROLE();
    const EXECUTOR_ROLE = await timelockController.EXECUTOR_ROLE();
    const CANCELLER_ROLE = await timelockController.CANCELLER_ROLE();
    
    try {
        // Grant roles to the DAO contract
        await timelockController.connect(admin).grantRole(PROPOSER_ROLE, karmaDAO.target);
        await timelockController.connect(admin).grantRole(EXECUTOR_ROLE, karmaDAO.target);
        await timelockController.connect(admin).grantRole(CANCELLER_ROLE, karmaDAO.target);
        
        console.log("✅ DAO roles configured in timelock");
    } catch (error) {
        console.log("⚠️  Roles already set or error:", error.message);
    }
    
    console.log("\n🎯 Setting Staking Integration...");
    
    try {
        await karmaDAO.connect(admin).setStakingContract(governanceStaking.target);
        console.log("✅ Staking contract integrated with DAO");
    } catch (error) {
        console.log("⚠️  Staking integration already set or error:", error.message);
    }
    
    console.log("\n📊 Verifying Setup...");
    
    // Verify configurations
    const currentConfig = await karmaDAO.getGovernanceConfig();
    console.log("Current proposal threshold:", ethers.formatEther(currentConfig.proposalThreshold), "KARMA");
    console.log("Current quorum percentage:", currentConfig.quorumPercentage.toString(), "%");
    console.log("Current voting period:", (Number(currentConfig.votingPeriod) / 86400).toString(), "days");
    console.log("Quadratic voting enabled:", currentConfig.quadraticVotingEnabled);
    
    const stakingContract = await karmaDAO.stakingContract();
    console.log("Staking contract:", stakingContract);
    
    console.log("\n🎉 Stage 7.1 setup completed successfully!");
    console.log("\n📝 Next Steps:");
    console.log("1. Verify all contract integrations");
    console.log("2. Set up initial governance proposals");
    console.log("3. Enable community participation");
    console.log("4. Deploy monitoring and analytics");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Setup failed:", error);
        process.exit(1);
    }); 