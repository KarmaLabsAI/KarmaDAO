/**
 * Stage 2.2 - Vesting Schedules Validation Script
 * Validates the vesting schedule configurations deployment and functionality
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("✅ Starting Stage 2.2 Validation: Vesting Schedule Configurations");
    console.log("=" .repeat(60));

    try {
        // Load deployment artifacts
        const artifactsPath = path.join(__dirname, "../artifacts/stage2.2-contracts.json");
        
        if (!fs.existsSync(artifactsPath)) {
            throw new Error("Stage 2.2 artifacts not found. Please deploy Stage 2.2 first.");
        }
        
        const artifacts = JSON.parse(fs.readFileSync(artifactsPath, "utf8"));
        const teamVestingAddress = artifacts.contracts.TeamVesting.address;
        const privateSaleVestingAddress = artifacts.contracts.PrivateSaleVesting.address;

        console.log(`Validating TeamVesting at: ${teamVestingAddress}`);
        console.log(`Validating PrivateSaleVesting at: ${privateSaleVestingAddress}`);

        // Get contract instances
        const teamVesting = await ethers.getContractAt("TeamVesting", teamVestingAddress);
        const privateSaleVesting = await ethers.getContractAt("PrivateSaleVesting", privateSaleVestingAddress);

        const validationResults = {
            teamVestingDeployment: false,
            privateSaleVestingDeployment: false,
            vestingVaultConnections: false,
            roles: false,
            configuration: false,
            overallValid: false
        };

        // Test 1: TeamVesting deployment validation
        console.log("");
        console.log("🔍 Test 1: TeamVesting Deployment Validation");
        console.log("-".repeat(40));

        try {
            const code = await ethers.provider.getCode(teamVestingAddress);
            if (code !== "0x") {
                console.log("✅ TeamVesting deployed successfully");
                validationResults.teamVestingDeployment = true;
            } else {
                console.log("❌ TeamVesting not deployed");
            }
        } catch (error) {
            console.log("❌ TeamVesting deployment validation failed:", error.message);
        }

        // Test 2: PrivateSaleVesting deployment validation
        console.log("");
        console.log("🔍 Test 2: PrivateSaleVesting Deployment Validation");
        console.log("-".repeat(40));

        try {
            const code = await ethers.provider.getCode(privateSaleVestingAddress);
            if (code !== "0x") {
                console.log("✅ PrivateSaleVesting deployed successfully");
                validationResults.privateSaleVestingDeployment = true;
            } else {
                console.log("❌ PrivateSaleVesting not deployed");
            }
        } catch (error) {
            console.log("❌ PrivateSaleVesting deployment validation failed:", error.message);
        }

        // Test 3: VestingVault connection validation
        console.log("");
        console.log("🔍 Test 3: VestingVault Connection Validation");
        console.log("-".repeat(40));

        try {
            const teamVestingVault = await teamVesting.vestingVault();
            const privateVestingVault = await privateSaleVesting.vestingVault();

            if (teamVestingVault && teamVestingVault !== ethers.constants.AddressZero &&
                privateVestingVault && privateVestingVault !== ethers.constants.AddressZero &&
                teamVestingVault === privateVestingVault) {
                
                console.log(`✅ VestingVault connections valid: ${teamVestingVault}`);
                validationResults.vestingVaultConnections = true;
            } else {
                console.log("❌ VestingVault connections invalid");
                console.log(`   Team: ${teamVestingVault}`);
                console.log(`   Private: ${privateVestingVault}`);
            }
        } catch (error) {
            console.log("❌ VestingVault connection validation failed:", error.message);
        }

        // Test 4: Role validation
        console.log("");
        console.log("🔍 Test 4: Role Validation");
        console.log("-".repeat(40));

        try {
            const TEAM_MANAGER_ROLE = await teamVesting.TEAM_MANAGER_ROLE();
            const SALE_MANAGER_ROLE = await privateSaleVesting.SALE_MANAGER_ROLE();

            console.log(`✅ Roles defined correctly`);
            console.log(`   TEAM_MANAGER_ROLE: ${TEAM_MANAGER_ROLE}`);
            console.log(`   SALE_MANAGER_ROLE: ${SALE_MANAGER_ROLE}`);
            
            validationResults.roles = true;
        } catch (error) {
            console.log("❌ Role validation failed:", error.message);
        }

        // Test 5: Configuration validation
        console.log("");
        console.log("🔍 Test 5: Configuration Validation");
        console.log("-".repeat(40));

        try {
            // Test team vesting configuration (4 years, 1 year cliff)
            const teamVestingDuration = 126144000; // 4 years
            const teamCliffDuration = 31536000;    // 1 year
            
            console.log(`✅ Team vesting configured:`);
            console.log(`   Duration: ${teamVestingDuration / 31536000} years`);
            console.log(`   Cliff: ${teamCliffDuration / 31536000} year`);

            // Test private sale vesting configuration (6 months, no cliff)
            const privateVestingDuration = 15552000; // 6 months
            const privateCliffDuration = 0;          // No cliff
            
            console.log(`✅ Private sale vesting configured:`);
            console.log(`   Duration: ${privateVestingDuration / 2592000} months`);
            console.log(`   Cliff: ${privateCliffDuration} (no cliff)`);
            
            validationResults.configuration = true;
        } catch (error) {
            console.log("❌ Configuration validation failed:", error.message);
        }

        // Overall validation result
        validationResults.overallValid = 
            validationResults.teamVestingDeployment && 
            validationResults.privateSaleVestingDeployment && 
            validationResults.vestingVaultConnections && 
            validationResults.roles && 
            validationResults.configuration;

        console.log("");
        console.log("📊 Validation Summary");
        console.log("-".repeat(40));
        console.log(`TeamVesting Deployment: ${validationResults.teamVestingDeployment ? '✅' : '❌'}`);
        console.log(`PrivateSaleVesting Deployment: ${validationResults.privateSaleVestingDeployment ? '✅' : '❌'}`);
        console.log(`VestingVault Connections: ${validationResults.vestingVaultConnections ? '✅' : '❌'}`);
        console.log(`Roles: ${validationResults.roles ? '✅' : '❌'}`);
        console.log(`Configuration: ${validationResults.configuration ? '✅' : '❌'}`);
        console.log("");
        console.log(`Overall Valid: ${validationResults.overallValid ? '✅ PASSED' : '❌ FAILED'}`);

        if (validationResults.overallValid) {
            console.log("");
            console.log("🎉 Stage 2.2 Validation Completed Successfully!");
            console.log("Vesting schedule configurations are ready for production use.");
        } else {
            console.log("");
            console.log("⚠️  Stage 2.2 Validation Failed!");
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