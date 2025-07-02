/**
 * Stage 2.2 - Vesting Schedule Configurations Deployment Script
 * Deploys specific vesting patterns for different allocation types
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Load configuration
const config = require("../config/stage2.2-config.json");
const vestingCalc = require("../utils/vesting-calculator.js");

async function main() {
    console.log("🚀 Starting Stage 2.2 Deployment: Vesting Schedule Configurations");
    console.log("=" .repeat(70));

    const [deployer, admin, teamManager, saleManager] = await ethers.getSigners();
    
    console.log("📋 Deployment Configuration:");
    console.log(`Network: ${network.name}`);
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log("");

    try {
        // Step 1: Validate dependencies
        console.log("🔍 Step 1: Validating dependencies");
        console.log("-".repeat(50));
        
        const stage21ArtifactsPath = path.join(__dirname, "../artifacts/stage2.1-contracts.json");
        
        if (!fs.existsSync(stage21ArtifactsPath)) {
            throw new Error("Stage 2.1 artifacts not found. Please deploy Stage 2.1 first.");
        }
        
        const stage21Artifacts = JSON.parse(fs.readFileSync(stage21ArtifactsPath, "utf8"));
        const vestingVaultAddress = stage21Artifacts.contracts.VestingVault.address;
        
        console.log(`✅ VestingVault found at: ${vestingVaultAddress}`);

        // Step 2: Deploy TeamVesting
        console.log("");
        console.log("📦 Step 2: Deploying TeamVesting Contract");
        console.log("-".repeat(50));
        
        const TeamVesting = await ethers.getContractFactory("TeamVesting");
        const teamVesting = await TeamVesting.deploy(
            vestingVaultAddress,
            admin.address
        );

        console.log(`✅ TeamVesting deployed to: ${teamVesting.address}`);

        // Step 3: Deploy PrivateSaleVesting
        console.log("");
        console.log("📦 Step 3: Deploying PrivateSaleVesting Contract");
        console.log("-".repeat(50));
        
        const PrivateSaleVesting = await ethers.getContractFactory("PrivateSaleVesting");
        const privateSaleVesting = await PrivateSaleVesting.deploy(
            vestingVaultAddress,
            admin.address
        );

        console.log(`✅ PrivateSaleVesting deployed to: ${privateSaleVesting.address}`);

        console.log("");
        console.log("🎉 Stage 2.2 Deployment Completed Successfully!");
        console.log(`TeamVesting Address: ${teamVesting.address}`);
        console.log(`PrivateSaleVesting Address: ${privateSaleVesting.address}`);

        return {
            teamVesting: teamVesting.address,
            privateSaleVesting: privateSaleVesting.address
        };

    } catch (error) {
        console.error("❌ Deployment failed:", error);
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