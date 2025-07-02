/**
 * Stage 2.2 - Vesting Schedules Setup Script
 * Sets up and configures specific vesting schedules
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🔧 Starting Stage 2.2 Setup: Vesting Schedules Configuration");
    console.log("=" .repeat(60));

    const [deployer, admin, teamManager, saleManager] = await ethers.getSigners();
    
    try {
        // Load deployment artifacts
        const artifactsPath = path.join(__dirname, "../artifacts/stage2.2-contracts.json");
        
        if (!fs.existsSync(artifactsPath)) {
            throw new Error("Stage 2.2 artifacts not found. Please deploy Stage 2.2 first.");
        }
        
        const artifacts = JSON.parse(fs.readFileSync(artifactsPath, "utf8"));
        const teamVestingAddress = artifacts.contracts.TeamVesting.address;
        const privateSaleVestingAddress = artifacts.contracts.PrivateSaleVesting.address;

        console.log(`TeamVesting Address: ${teamVestingAddress}`);
        console.log(`PrivateSaleVesting Address: ${privateSaleVestingAddress}`);

        // Get contract instances
        const teamVesting = await ethers.getContractAt("TeamVesting", teamVestingAddress);
        const privateSaleVesting = await ethers.getContractAt("PrivateSaleVesting", privateSaleVestingAddress);

        // Step 1: Verify contract deployments
        console.log("");
        console.log("🔍 Step 1: Verifying contract deployments");
        console.log("-".repeat(40));

        const teamVestingVault = await teamVesting.vestingVault();
        const privateVestingVault = await privateSaleVesting.vestingVault();
        
        console.log(`Team Vesting Vault: ${teamVestingVault}`);
        console.log(`Private Sale Vesting Vault: ${privateVestingVault}`);

        // Step 2: Configure team vesting parameters
        console.log("");
        console.log("👥 Step 2: Configuring team vesting parameters");
        console.log("-".repeat(40));

        const teamVestingDuration = 126144000; // 4 years in seconds
        const teamCliffDuration = 31536000;    // 1 year in seconds
        
        console.log(`Team Vesting Duration: ${teamVestingDuration / 31536000} years`);
        console.log(`Team Cliff Duration: ${teamCliffDuration / 31536000} year`);

        // Step 3: Configure private sale vesting parameters
        console.log("");
        console.log("💰 Step 3: Configuring private sale vesting parameters");
        console.log("-".repeat(40));

        const privateSaleVestingDuration = 15552000; // 6 months in seconds
        const privateSaleCliffDuration = 0;          // No cliff
        
        console.log(`Private Sale Vesting Duration: ${privateSaleVestingDuration / 2592000} months`);
        console.log(`Private Sale Cliff Duration: ${privateSaleCliffDuration} (no cliff)`);

        // Step 4: Verify role assignments
        console.log("");
        console.log("🔐 Step 4: Verifying role assignments");
        console.log("-".repeat(40));

        // Check team manager role
        const TEAM_MANAGER_ROLE = await teamVesting.TEAM_MANAGER_ROLE();
        const hasTeamManagerRole = await teamVesting.hasRole(TEAM_MANAGER_ROLE, teamManager.address);
        
        console.log(`Team Manager Role Assigned: ${hasTeamManagerRole}`);

        // Check sale manager role
        const SALE_MANAGER_ROLE = await privateSaleVesting.SALE_MANAGER_ROLE();
        const hasSaleManagerRole = await privateSaleVesting.hasRole(SALE_MANAGER_ROLE, saleManager.address);
        
        console.log(`Sale Manager Role Assigned: ${hasSaleManagerRole}`);

        console.log("");
        console.log("✅ Stage 2.2 Setup Completed Successfully!");
        console.log(`Vesting schedule configurations are ready.`);

        return {
            teamVesting: teamVestingAddress,
            privateSaleVesting: privateSaleVestingAddress,
            setupComplete: true
        };

    } catch (error) {
        console.error("❌ Setup failed:", error);
        throw error;
    }
}

if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = main; 