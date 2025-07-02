const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying VestingVault System...");
    console.log("=====================================\n");
    
    // Get signers
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");
    
    // Deploy KarmaToken fresh for this deployment
    console.log("🔄 Deploying KarmaToken...");
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(deployer.address);
    await karmaToken.waitForDeployment();
    const karmaTokenAddress = await karmaToken.getAddress();
    
    console.log("✅ KarmaToken deployed to:", karmaTokenAddress);
    
    // Mint some tokens for testing
    await karmaToken.mint(deployer.address, ethers.parseEther("1000000000")); // 1B tokens
    console.log("✅ Minted 1B KARMA tokens to deployer");
    
    console.log("\n📋 Deployment Configuration:");
    console.log("- Token Address:", karmaTokenAddress);
    console.log("- Admin Address:", deployer.address);
    
    // Deploy VestingVault
    console.log("\n🔄 Deploying VestingVault...");
    const VestingVault = await ethers.getContractFactory("VestingVault");
    const vestingVault = await VestingVault.deploy(karmaTokenAddress, deployer.address);
    await vestingVault.waitForDeployment();
    
    const vestingVaultAddress = await vestingVault.getAddress();
    console.log("✅ VestingVault deployed to:", vestingVaultAddress);
    
    // Verify roles
    console.log("\n🔐 Verifying Role Assignments:");
    const DEFAULT_ADMIN_ROLE = await vestingVault.DEFAULT_ADMIN_ROLE();
    const VESTING_MANAGER_ROLE = await vestingVault.VESTING_MANAGER_ROLE();
    const EMERGENCY_ROLE = await vestingVault.EMERGENCY_ROLE();
    
    const hasAdminRole = await vestingVault.hasRole(DEFAULT_ADMIN_ROLE, deployer.address);
    const hasVestingRole = await vestingVault.hasRole(VESTING_MANAGER_ROLE, deployer.address);
    const hasEmergencyRole = await vestingVault.hasRole(EMERGENCY_ROLE, deployer.address);
    
    console.log("- Admin Role:", hasAdminRole ? "✅" : "❌");
    console.log("- Vesting Manager Role:", hasVestingRole ? "✅" : "❌");
    console.log("- Emergency Role:", hasEmergencyRole ? "✅" : "❌");
    
    // Fund the vesting vault with tokens
    console.log("\n💰 Funding VestingVault...");
    
    const fundingAmount = ethers.parseEther("500000000"); // 500M tokens for vesting
    
    // Check if we need to mint more tokens
    const deployerBalance = await karmaToken.balanceOf(deployer.address);
    if (deployerBalance < fundingAmount) {
        console.log("⚠️  Insufficient balance, minting more tokens...");
        await karmaToken.mint(deployer.address, fundingAmount);
    }
    
    // Approve and fund the contract
    await karmaToken.approve(vestingVaultAddress, fundingAmount);
    await vestingVault.fundContract(fundingAmount);
    
    const contractBalance = await karmaToken.balanceOf(vestingVaultAddress);
    console.log("✅ VestingVault funded with:", ethers.formatEther(contractBalance), "KARMA tokens");
    
    // Display contract statistics
    console.log("\n📊 Contract Statistics:");
    const stats = await vestingVault.getContractStats();
    console.log("- Total Schedules:", stats[0].toString());
    console.log("- Total Vesting Amount:", ethers.formatEther(stats[1]), "KARMA");
    console.log("- Total Claimed Amount:", ethers.formatEther(stats[2]), "KARMA");
    console.log("- Contract Balance:", ethers.formatEther(stats[3]), "KARMA");
    
    // Create sample vesting schedules for demonstration
    console.log("\n🎯 Creating Sample Vesting Schedules...");
    
    // Get current timestamp and set future start times
    const currentTime = Math.floor(Date.now() / 1000);
    const startTime = currentTime + 86400; // Start in 1 day
    
    // Team vesting (4 years, 1 year cliff)
    const teamAmount = ethers.parseEther("10000000"); // 10M tokens
    const teamCliff = 365 * 24 * 60 * 60; // 1 year
    const teamDuration = 4 * 365 * 24 * 60 * 60; // 4 years
    
    console.log("Creating team vesting schedule...");
    const teamTx = await vestingVault.createVestingSchedule(
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // Account #1 from hardhat
        teamAmount,
        startTime,
        teamCliff,
        teamDuration,
        "TEAM"
    );
    await teamTx.wait();
    console.log("✅ Team vesting schedule created (ID: 1)");
    
    // Private sale vesting (6 months, no cliff)
    const privateSaleAmount = ethers.parseEther("5000000"); // 5M tokens
    const privateSaleDuration = 6 * 30 * 24 * 60 * 60; // 6 months
    
    console.log("Creating private sale vesting schedule...");
    const privateTx = await vestingVault.createVestingSchedule(
        "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", // Account #2 from hardhat
        privateSaleAmount,
        startTime,
        0, // No cliff
        privateSaleDuration,
        "PRIVATE_SALE"
    );
    await privateTx.wait();
    console.log("✅ Private sale vesting schedule created (ID: 2)");
    
    // Update statistics
    const finalStats = await vestingVault.getContractStats();
    console.log("\n📊 Updated Contract Statistics:");
    console.log("- Total Schedules:", finalStats[0].toString());
    console.log("- Total Vesting Amount:", ethers.formatEther(finalStats[1]), "KARMA");
    console.log("- Total Claimed Amount:", ethers.formatEther(finalStats[2]), "KARMA");
    console.log("- Available Balance:", ethers.formatEther(finalStats[3]), "KARMA");
    
    console.log("\n🎉 VestingVault Deployment Complete!");
    console.log("=====================================");
    console.log("📋 Deployment Summary:");
    console.log("- KarmaToken:", karmaTokenAddress);
    console.log("- VestingVault:", vestingVaultAddress);
    console.log("- Admin:", deployer.address);
    console.log("- Initial Funding:", ethers.formatEther(fundingAmount), "KARMA");
    console.log("- Sample Schedules Created: 2");
    
    console.log("\n🔧 Next Steps:");
    console.log("1. Grant additional vesting manager roles if needed");
    console.log("2. Create production vesting schedules");
    console.log("3. Set up monitoring and alerts");
    console.log("4. Consider upgrading to mainnet deployment");
    
    console.log("\n⚠️  Important Notes:");
    console.log("- This is a local/testnet deployment");
    console.log("- Update addresses for mainnet deployment");
    console.log("- Ensure proper role management in production");
    console.log("- Consider multi-sig wallet for admin operations");
    
    return {
        karmaToken: karmaTokenAddress,
        vestingVault: vestingVaultAddress
    };
}

// Handle script execution
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("❌ Deployment failed:", error);
            process.exit(1);
        });
}

module.exports = main; 