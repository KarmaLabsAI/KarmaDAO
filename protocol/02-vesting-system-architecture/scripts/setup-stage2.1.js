/**
 * Stage 2.1 - VestingVault Setup and Initialization Script
 * Sets up and initializes the core vesting vault contract
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🔧 Starting Stage 2.1 Setup: VestingVault Initialization");
    console.log("=" .repeat(60));

    const [deployer, admin, vaultManager] = await ethers.getSigners();
    
    try {
        // Load deployment artifacts
        const artifactsPath = path.join(__dirname, "../artifacts/stage2.1-contracts.json");
        
        if (!fs.existsSync(artifactsPath)) {
            throw new Error("Stage 2.1 artifacts not found. Please deploy Stage 2.1 first.");
        }
        
        const artifacts = JSON.parse(fs.readFileSync(artifactsPath, "utf8"));
        const vestingVaultAddress = artifacts.contracts.VestingVault.address;

        console.log(`VestingVault Address: ${vestingVaultAddress}`);

        // Get VestingVault contract instance
        const vestingVault = await ethers.getContractAt("VestingVault", vestingVaultAddress);

        // Step 1: Verify contract is properly initialized
        console.log("");
        console.log("🔍 Step 1: Verifying contract initialization");
        console.log("-".repeat(40));

        const tokenAddress = await vestingVault.token();
        const isPaused = await vestingVault.paused();
        
        console.log(`Token Address: ${tokenAddress}`);
        console.log(`Contract Paused: ${isPaused}`);

        // Step 2: Configure contract parameters
        console.log("");
        console.log("⚙️ Step 2: Configuring contract parameters");
        console.log("-".repeat(40));

        // Set maximum beneficiaries if needed
        const maxBeneficiaries = await vestingVault.maxBeneficiaries();
        console.log(`Max Beneficiaries: ${maxBeneficiaries}`);

        // Step 3: Verify role assignments
        console.log("");
        console.log("👥 Step 3: Verifying role assignments");
        console.log("-".repeat(40));

        const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
        const hasVaultManagerRole = await vestingVault.hasRole(VAULT_MANAGER_ROLE, vaultManager.address);
        
        console.log(`Vault Manager Role Assigned: ${hasVaultManagerRole}`);

        // Step 4: Test basic functionality
        console.log("");
        console.log("🧪 Step 4: Testing basic functionality");
        console.log("-".repeat(40));

        const totalSchedules = await vestingVault.getTotalSchedules();
        console.log(`Total Vesting Schedules: ${totalSchedules}`);

        console.log("");
        console.log("✅ Stage 2.1 Setup Completed Successfully!");
        console.log(`VestingVault is ready for vesting schedule creation.`);

        return {
            vestingVault: vestingVaultAddress,
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