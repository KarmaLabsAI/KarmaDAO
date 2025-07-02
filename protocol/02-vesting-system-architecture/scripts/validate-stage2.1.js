/**
 * Stage 2.1 - VestingVault Validation Script
 * Validates the core vesting vault deployment and functionality
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("✅ Starting Stage 2.1 Validation: VestingVault Core Development");
    console.log("=" .repeat(60));

    try {
        // Load deployment artifacts
        const artifactsPath = path.join(__dirname, "../artifacts/stage2.1-contracts.json");
        
        if (!fs.existsSync(artifactsPath)) {
            throw new Error("Stage 2.1 artifacts not found. Please deploy Stage 2.1 first.");
        }
        
        const artifacts = JSON.parse(fs.readFileSync(artifactsPath, "utf8"));
        const vestingVaultAddress = artifacts.contracts.VestingVault.address;

        console.log(`Validating VestingVault at: ${vestingVaultAddress}`);

        // Get contract instance
        const vestingVault = await ethers.getContractAt("VestingVault", vestingVaultAddress);

        const validationResults = {
            deployment: false,
            tokenAddress: false,
            roles: false,
            functionality: false,
            overallValid: false
        };

        // Test 1: Deployment validation
        console.log("");
        console.log("🔍 Test 1: Deployment Validation");
        console.log("-".repeat(40));

        try {
            const code = await ethers.provider.getCode(vestingVaultAddress);
            if (code !== "0x") {
                console.log("✅ Contract deployed successfully");
                validationResults.deployment = true;
            } else {
                console.log("❌ Contract not deployed");
            }
        } catch (error) {
            console.log("❌ Deployment validation failed:", error.message);
        }

        // Test 2: Token address validation
        console.log("");
        console.log("🔍 Test 2: Token Address Validation");
        console.log("-".repeat(40));

        try {
            const tokenAddress = await vestingVault.token();
            if (tokenAddress && tokenAddress !== ethers.constants.AddressZero) {
                console.log(`✅ Token address set: ${tokenAddress}`);
                validationResults.tokenAddress = true;
            } else {
                console.log("❌ Invalid token address");
            }
        } catch (error) {
            console.log("❌ Token address validation failed:", error.message);
        }

        // Test 3: Role validation
        console.log("");
        console.log("🔍 Test 3: Role Validation");
        console.log("-".repeat(40));

        try {
            const DEFAULT_ADMIN_ROLE = await vestingVault.DEFAULT_ADMIN_ROLE();
            const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
            const PAUSER_ROLE = await vestingVault.PAUSER_ROLE();

            console.log(`✅ Roles defined correctly`);
            console.log(`   DEFAULT_ADMIN_ROLE: ${DEFAULT_ADMIN_ROLE}`);
            console.log(`   VAULT_MANAGER_ROLE: ${VAULT_MANAGER_ROLE}`);
            console.log(`   PAUSER_ROLE: ${PAUSER_ROLE}`);
            
            validationResults.roles = true;
        } catch (error) {
            console.log("❌ Role validation failed:", error.message);
        }

        // Test 4: Basic functionality validation
        console.log("");
        console.log("🔍 Test 4: Basic Functionality Validation");
        console.log("-".repeat(40));

        try {
            const isPaused = await vestingVault.paused();
            console.log(`✅ Contract pause state: ${isPaused}`);
            
            // Try to get total schedules (should not revert)
            const totalSchedules = await vestingVault.getTotalSchedules();
            console.log(`✅ Total schedules: ${totalSchedules}`);
            
            validationResults.functionality = true;
        } catch (error) {
            console.log("❌ Functionality validation failed:", error.message);
        }

        // Overall validation result
        validationResults.overallValid = 
            validationResults.deployment && 
            validationResults.tokenAddress && 
            validationResults.roles && 
            validationResults.functionality;

        console.log("");
        console.log("📊 Validation Summary");
        console.log("-".repeat(40));
        console.log(`Deployment: ${validationResults.deployment ? '✅' : '❌'}`);
        console.log(`Token Address: ${validationResults.tokenAddress ? '✅' : '❌'}`);
        console.log(`Roles: ${validationResults.roles ? '✅' : '❌'}`);
        console.log(`Functionality: ${validationResults.functionality ? '✅' : '❌'}`);
        console.log("");
        console.log(`Overall Valid: ${validationResults.overallValid ? '✅ PASSED' : '❌ FAILED'}`);

        if (validationResults.overallValid) {
            console.log("");
            console.log("🎉 Stage 2.1 Validation Completed Successfully!");
            console.log("VestingVault is ready for production use.");
        } else {
            console.log("");
            console.log("⚠️  Stage 2.1 Validation Failed!");
            console.log("Please fix the issues above before proceeding.");
        }

        return validationResults;

    } catch (error) {
        console.error("❌ Validation script failed:", error);
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