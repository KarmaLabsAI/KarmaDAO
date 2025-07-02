/**
 * Stage 1.2 - Administrative Control System Deployment Script
 * Deploys the administrative control infrastructure
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Load configuration
const config = require("../config/stage1.2-config.json");
const constants = require("../utils/constants.js");

async function main() {
    console.log("🚀 Starting Stage 1.2 Deployment: Administrative Control System");
    console.log("=" .repeat(60));

    // Get deployment accounts
    const [deployer, admin, emergencyAdmin, signer1, signer2, signer3, signer4, signer5] = await ethers.getSigners();
    
    console.log("📋 Deployment Configuration:");
    console.log(`Network: ${network.name}`);
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log(`Emergency Admin: ${emergencyAdmin.address}`);
    console.log("");

    // Deployment tracking
    const deploymentLog = {
        stage: "1.2",
        timestamp: new Date().toISOString(),
        network: network.name,
        deployer: deployer.address,
        contracts: {},
        gasUsed: {},
        transactions: []
    };

    try {
        // Step 1: Deploy KarmaMultiSigManager
        console.log("📦 Step 1: Deploying KarmaMultiSigManager");
        console.log("-".repeat(40));
        
        const signers = [signer1.address, signer2.address, signer3.address, signer4.address, signer5.address];
        const requiredSignatures = config.contracts.KarmaMultiSigManager.requiredSignatures;
        
        const KarmaMultiSigManager = await ethers.getContractFactory("KarmaMultiSigManager");
        const multiSigManager = await KarmaMultiSigManager.deploy(
            signers,
            requiredSignatures
        );

        const multiSigTx = await multiSigManager.deployTransaction.wait();
        
        deploymentLog.contracts.KarmaMultiSigManager = multiSigManager.address;
        deploymentLog.gasUsed.KarmaMultiSigManager = multiSigTx.gasUsed.toString();

        console.log(`✅ KarmaMultiSigManager deployed to: ${multiSigManager.address}`);
        console.log(`⛽ Gas used: ${multiSigTx.gasUsed.toString()}`);
        console.log("");

        // Step 2: Deploy KarmaTimelock
        console.log("📦 Step 2: Deploying KarmaTimelock");
        console.log("-".repeat(40));
        
        const minDelay = config.contracts.KarmaTimelock.minDelay;
        const proposers = [admin.address];
        const executors = [admin.address];
        
        const KarmaTimelock = await ethers.getContractFactory("KarmaTimelock");
        const timelock = await KarmaTimelock.deploy(
            minDelay,
            proposers,
            executors
        );

        const timelockTx = await timelock.deployTransaction.wait();
        
        deploymentLog.contracts.KarmaTimelock = timelock.address;
        deploymentLog.gasUsed.KarmaTimelock = timelockTx.gasUsed.toString();

        console.log(`✅ KarmaTimelock deployed to: ${timelock.address}`);
        console.log(`⛽ Gas used: ${timelockTx.gasUsed.toString()}`);
        console.log("");

        // Step 3: Deploy AdminControl
        console.log("📦 Step 3: Deploying AdminControl");
        console.log("-".repeat(40));
        
        const emergencyPauseDuration = config.contracts.AdminControl.emergencyPauseDuration;
        
        const AdminControl = await ethers.getContractFactory("AdminControl");
        const adminControl = await AdminControl.deploy(
            multiSigManager.address,
            timelock.address,
            emergencyPauseDuration
        );

        const adminControlTx = await adminControl.deployTransaction.wait();
        
        deploymentLog.contracts.AdminControl = adminControl.address;
        deploymentLog.gasUsed.AdminControl = adminControlTx.gasUsed.toString();

        console.log(`✅ AdminControl deployed to: ${adminControl.address}`);
        console.log(`⛽ Gas used: ${adminControlTx.gasUsed.toString()}`);
        console.log("");

        // Step 4: Setup roles and permissions
        console.log("🔐 Step 4: Setting up roles and permissions");
        console.log("-".repeat(40));

        // Grant emergency admin role
        const emergencyAdminRoleTx = await adminControl.grantRole(
            constants.ADMIN_CONSTANTS.ROLES.EMERGENCY_ADMIN_ROLE,
            emergencyAdmin.address
        );
        await emergencyAdminRoleTx.wait();

        console.log(`✅ Granted EMERGENCY_ADMIN_ROLE to: ${emergencyAdmin.address}`);

        // Authorize the AdminControl contract in the timelock
        const authorizeTx = await adminControl.authorizeContract(timelock.address);
        await authorizeTx.wait();

        console.log(`✅ Authorized contract: ${timelock.address}`);
        console.log("");

        // Step 5: Save deployment artifacts
        console.log("💾 Step 5: Saving deployment artifacts");
        console.log("-".repeat(40));

        const artifacts = {
            stage: "1.2",
            contracts: {
                KarmaMultiSigManager: {
                    address: multiSigManager.address,
                    abi: KarmaMultiSigManager.interface.format("json")
                },
                KarmaTimelock: {
                    address: timelock.address,
                    abi: KarmaTimelock.interface.format("json")
                },
                AdminControl: {
                    address: adminControl.address,
                    abi: AdminControl.interface.format("json")
                }
            },
            configuration: {
                signers: signers,
                requiredSignatures: requiredSignatures,
                minDelay: minDelay,
                emergencyPauseDuration: emergencyPauseDuration
            }
        };

        const artifactsPath = path.join(__dirname, "../artifacts/stage1.2-contracts.json");
        fs.writeFileSync(artifactsPath, JSON.stringify(artifacts, null, 2));

        const logsPath = path.join(__dirname, "../logs/stage1.2-deployment.log");
        fs.writeFileSync(logsPath, JSON.stringify(deploymentLog, null, 2));

        console.log(`✅ Artifacts saved to: ${artifactsPath}`);
        console.log(`✅ Deployment log saved to: ${logsPath}`);
        console.log("");

        console.log("🎉 Stage 1.2 Deployment Completed Successfully!");
        console.log("=" .repeat(60));
        console.log(`MultiSig Manager: ${multiSigManager.address}`);
        console.log(`Timelock: ${timelock.address}`);
        console.log(`Admin Control: ${adminControl.address}`);
        console.log("");

        return {
            multiSigManager: multiSigManager.address,
            timelock: timelock.address,
            adminControl: adminControl.address,
            deploymentLog
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