/**
 * Stage 2.1 - VestingVault Core Development Deployment Script
 * Deploys the core vesting contract with flexible scheduling
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Load configuration
const config = require("../config/stage2.1-config.json");
const vestingCalc = require("../utils/vesting-calculator.js");

async function main() {
    console.log("🚀 Starting Stage 2.1 Deployment: VestingVault Core Development");
    console.log("=" .repeat(70));

    // Get deployment accounts
    const [deployer, admin, vaultManager, pauser, beneficiary1, beneficiary2, emergency] = await ethers.getSigners();
    
    console.log("📋 Deployment Configuration:");
    console.log(`Network: ${network.name}`);
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log(`Vault Manager: ${vaultManager.address}`);
    console.log(`Pauser: ${pauser.address}`);
    console.log("");

    // Deployment tracking
    const deploymentLog = {
        stage: "2.1",
        timestamp: new Date().toISOString(),
        network: network.name,
        deployer: deployer.address,
        contracts: {},
        gasUsed: {},
        transactions: []
    };

    try {
        // Step 1: Validate dependencies
        console.log("🔍 Step 1: Validating dependencies");
        console.log("-".repeat(50));
        
        // Check if Stage 1 artifacts exist
        const stage1ArtifactsPath = path.join(__dirname, "../../01-core-token-infrastructure/artifacts/stage1.1-contracts.json");
        
        if (!fs.existsSync(stage1ArtifactsPath)) {
            throw new Error("Stage 1 artifacts not found. Please deploy Stage 1 first.");
        }
        
        const stage1Artifacts = JSON.parse(fs.readFileSync(stage1ArtifactsPath, "utf8"));
        const karmaTokenAddress = stage1Artifacts.contracts.KarmaToken.address;
        
        console.log(`✅ KarmaToken found at: ${karmaTokenAddress}`);

        // Step 2: Deploy VestingVault
        console.log("");
        console.log("📦 Step 2: Deploying VestingVault Contract");
        console.log("-".repeat(50));
        
        const VestingVault = await ethers.getContractFactory("VestingVault");
        const vestingVault = await VestingVault.deploy(
            karmaTokenAddress,
            admin.address
        );

        const deployTx = await vestingVault.deployTransaction.wait();
        
        deploymentLog.contracts.VestingVault = vestingVault.address;
        deploymentLog.gasUsed.VestingVault = deployTx.gasUsed.toString();
        deploymentLog.transactions.push({
            contract: "VestingVault",
            txHash: deployTx.transactionHash,
            gasUsed: deployTx.gasUsed.toString()
        });

        console.log(`✅ VestingVault deployed to: ${vestingVault.address}`);
        console.log(`⛽ Gas used: ${deployTx.gasUsed.toString()}`);

        // Step 3: Setup roles and permissions
        console.log("");
        console.log("🔐 Step 3: Setting up roles and permissions");
        console.log("-".repeat(50));

        // Grant VAULT_MANAGER_ROLE to vault manager
        const vaultManagerRoleTx = await vestingVault.connect(admin).grantRole(
            config.contracts.VestingVault.roles.vaultManagerRole,
            vaultManager.address
        );
        await vaultManagerRoleTx.wait();
        
        deploymentLog.transactions.push({
            action: "grantVaultManagerRole",
            txHash: vaultManagerRoleTx.hash,
            recipient: vaultManager.address
        });

        console.log(`✅ Granted VAULT_MANAGER_ROLE to: ${vaultManager.address}`);

        // Grant PAUSER_ROLE to pauser
        const pauserRoleTx = await vestingVault.connect(admin).grantRole(
            config.contracts.VestingVault.roles.pauserRole,
            pauser.address
        );
        await pauserRoleTx.wait();
        
        deploymentLog.transactions.push({
            action: "grantPauserRole",
            txHash: pauserRoleTx.hash,
            recipient: pauser.address
        });

        console.log(`✅ Granted PAUSER_ROLE to: ${pauser.address}`);

        // Grant EMERGENCY_ROLE to emergency admin
        const emergencyRoleTx = await vestingVault.connect(admin).grantRole(
            config.contracts.VestingVault.roles.emergencyRole,
            emergency.address
        );
        await emergencyRoleTx.wait();
        
        deploymentLog.transactions.push({
            action: "grantEmergencyRole",
            txHash: emergencyRoleTx.hash,
            recipient: emergency.address
        });

        console.log(`✅ Granted EMERGENCY_ROLE to: ${emergency.address}`);

        // Step 4: Test core vesting functionality
        console.log("");
        console.log("🧪 Step 4: Testing core vesting functionality");
        console.log("-".repeat(50));

        // Create a test vesting schedule
        const testAmount = ethers.utils.parseEther("1000");
        const currentTime = Math.floor(Date.now() / 1000);
        const startTime = currentTime + 86400; // Start in 1 day
        const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6; // 6 months
        const cliffDuration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH; // 1 month cliff

        try {
            // Validate vesting parameters using our calculator
            const validationResult = vestingCalc.validateVestingParameters({
                totalAmount: testAmount,
                startTime,
                duration,
                cliffDuration
            });

            if (!validationResult.isValid) {
                console.log(`⚠️  Validation warnings: ${validationResult.warnings.join(", ")}`);
            } else {
                console.log(`✅ Vesting parameters validated successfully`);
            }

            // Generate vesting schedule
            const schedule = vestingCalc.generateVestingSchedule(
                testAmount,
                startTime,
                duration,
                vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH,
                cliffDuration
            );

            console.log(`✅ Generated vesting schedule with ${schedule.length} milestones`);
            
        } catch (error) {
            console.log(`⚠️  Test vesting calculation failed: ${error.message}`);
        }

        // Step 5: Verify contract configuration
        console.log("");
        console.log("🔍 Step 5: Verifying contract configuration");
        console.log("-".repeat(50));

        const tokenAddress = await vestingVault.token();
        const hasVaultManagerRole = await vestingVault.hasRole(
            config.contracts.VestingVault.roles.vaultManagerRole,
            vaultManager.address
        );
        const hasPauserRole = await vestingVault.hasRole(
            config.contracts.VestingVault.roles.pauserRole,
            pauser.address
        );

        console.log(`Token Address: ${tokenAddress}`);
        console.log(`Vault Manager Role: ${hasVaultManagerRole}`);
        console.log(`Pauser Role: ${hasPauserRole}`);
        console.log(`Contract Paused: ${await vestingVault.paused()}`);

        // Step 6: Save deployment artifacts
        console.log("");
        console.log("💾 Step 6: Saving deployment artifacts");
        console.log("-".repeat(50));

        const artifacts = {
            stage: "2.1",
            contracts: {
                VestingVault: {
                    address: vestingVault.address,
                    abi: VestingVault.interface.format("json"),
                    bytecode: VestingVault.bytecode
                }
            },
            roles: {
                admin: admin.address,
                vaultManager: vaultManager.address,
                pauser: pauser.address,
                emergency: emergency.address
            },
            dependencies: {
                karmaToken: karmaTokenAddress
            },
            configuration: config
        };

        // Save artifacts
        const artifactsPath = path.join(__dirname, "../artifacts/stage2.1-contracts.json");
        fs.writeFileSync(artifactsPath, JSON.stringify(artifacts, null, 2));

        // Save deployment log
        const logsPath = path.join(__dirname, "../logs/stage2.1-deployment.log");
        fs.writeFileSync(logsPath, JSON.stringify(deploymentLog, null, 2));

        console.log(`✅ Artifacts saved to: ${artifactsPath}`);
        console.log(`✅ Deployment log saved to: ${logsPath}`);

        // Step 7: Contract verification (if enabled)
        if (config.verification.enabled && network.name !== "hardhat") {
            console.log("");
            console.log("🔍 Step 7: Contract verification");
            console.log("-".repeat(50));

            console.log("⏳ Waiting for verification delay...");
            await new Promise(resolve => setTimeout(resolve, config.verification.delay));

            try {
                await hre.run("verify:verify", {
                    address: vestingVault.address,
                    constructorArguments: [
                        karmaTokenAddress,
                        admin.address
                    ],
                });

                console.log(`✅ Contract verified on Etherscan`);
                
                const verificationData = {
                    stage: "2.1",
                    timestamp: new Date().toISOString(),
                    network: network.name,
                    contracts: {
                        VestingVault: {
                            address: vestingVault.address,
                            verified: true,
                            verificationTime: new Date().toISOString()
                        }
                    }
                };

                const verificationPath = path.join(__dirname, "../verification/stage2.1-verification.json");
                fs.writeFileSync(verificationPath, JSON.stringify(verificationData, null, 2));
                
            } catch (error) {
                console.log(`⚠️  Verification failed: ${error.message}`);
            }
        }

        console.log("");
        console.log("🎉 Stage 2.1 Deployment Completed Successfully!");
        console.log("=" .repeat(70));
        console.log(`VestingVault Address: ${vestingVault.address}`);
        console.log(`Total Gas Used: ${Object.values(deploymentLog.gasUsed).reduce((a, b) => parseInt(a) + parseInt(b), 0)}`);
        console.log("");
        console.log("📋 Next Steps:");
        console.log("1. Deploy Stage 2.2 (Vesting Schedule Configurations)");
        console.log("2. Configure team and private sale vesting schedules");
        console.log("3. Integrate with Stage 3 (Token Sales Engine)");
        console.log("");

        return {
            vestingVault: vestingVault.address,
            admin: admin.address,
            vaultManager: vaultManager.address,
            deploymentLog
        };

    } catch (error) {
        console.error("❌ Deployment failed:", error);
        
        // Save error log
        const errorLog = {
            stage: "2.1",
            timestamp: new Date().toISOString(),
            error: error.message,
            stack: error.stack,
            deploymentLog
        };
        
        const errorPath = path.join(__dirname, "../logs/stage2.1-deployment-error.log");
        fs.writeFileSync(errorPath, JSON.stringify(errorLog, null, 2));
        
        throw error;
    }
}

// Allow script to be run directly
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = main; 