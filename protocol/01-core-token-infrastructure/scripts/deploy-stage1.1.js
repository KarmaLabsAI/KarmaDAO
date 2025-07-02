/**
 * Stage 1.1 - KarmaToken Contract Development Deployment Script
 * Deploys the core ERC-20 token with enhanced features
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Load configuration
const config = require("../config/stage1.1-config.json");
const constants = require("../utils/constants.js");

async function main() {
    console.log("🚀 Starting Stage 1.1 Deployment: KarmaToken Contract Development");
    console.log("=" .repeat(60));

    // Get deployment accounts
    const [deployer, admin, minter, pauser] = await ethers.getSigners();
    
    console.log("📋 Deployment Configuration:");
    console.log(`Network: ${network.name}`);
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log(`Minter: ${minter.address}`);
    console.log(`Pauser: ${pauser.address}`);
    console.log("");

    // Deployment tracking
    const deploymentLog = {
        stage: "1.1",
        timestamp: new Date().toISOString(),
        network: network.name,
        deployer: deployer.address,
        contracts: {},
        gasUsed: {},
        transactions: []
    };

    try {
        // Step 1: Deploy KarmaToken
        console.log("📦 Step 1: Deploying KarmaToken Contract");
        console.log("-".repeat(40));
        
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        const karmaToken = await KarmaToken.deploy(
            config.contracts.KarmaToken.name,
            config.contracts.KarmaToken.symbol,
            config.contracts.KarmaToken.maxSupply,
            admin.address
        );

        const deployTx = await karmaToken.deployTransaction.wait();
        
        deploymentLog.contracts.KarmaToken = karmaToken.address;
        deploymentLog.gasUsed.KarmaToken = deployTx.gasUsed.toString();
        deploymentLog.transactions.push({
            contract: "KarmaToken",
            txHash: deployTx.transactionHash,
            gasUsed: deployTx.gasUsed.toString()
        });

        console.log(`✅ KarmaToken deployed to: ${karmaToken.address}`);
        console.log(`⛽ Gas used: ${deployTx.gasUsed.toString()}`);
        console.log("");

        // Step 2: Grant initial roles
        console.log("🔐 Step 2: Setting up initial roles");
        console.log("-".repeat(40));

        // Grant MINTER_ROLE to minter account
        const minterRoleTx = await karmaToken.connect(admin).grantRole(
            constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE,
            minter.address
        );
        await minterRoleTx.wait();
        
        deploymentLog.transactions.push({
            action: "grantMinterRole",
            txHash: minterRoleTx.hash,
            recipient: minter.address
        });

        console.log(`✅ Granted MINTER_ROLE to: ${minter.address}`);

        // Grant PAUSER_ROLE to pauser account
        const pauserRoleTx = await karmaToken.connect(admin).grantRole(
            constants.TOKEN_CONSTANTS.ROLES.PAUSER_ROLE,
            pauser.address
        );
        await pauserRoleTx.wait();
        
        deploymentLog.transactions.push({
            action: "grantPauserRole",
            txHash: pauserRoleTx.hash,
            recipient: pauser.address
        });

        console.log(`✅ Granted PAUSER_ROLE to: ${pauser.address}`);

        // Grant BURNER_ROLE to admin (for buyback-and-burn)
        const burnerRoleTx = await karmaToken.connect(admin).grantRole(
            constants.TOKEN_CONSTANTS.ROLES.BURNER_ROLE,
            admin.address
        );
        await burnerRoleTx.wait();
        
        deploymentLog.transactions.push({
            action: "grantBurnerRole",
            txHash: burnerRoleTx.hash,
            recipient: admin.address
        });

        console.log(`✅ Granted BURNER_ROLE to: ${admin.address}`);
        console.log("");

        // Step 3: Verify contract setup
        console.log("🔍 Step 3: Verifying contract setup");
        console.log("-".repeat(40));

        const tokenInfo = await karmaToken.getTokenInfo();
        const maxSupply = await karmaToken.maxSupply();
        const totalSupply = await karmaToken.totalSupply();
        
        console.log(`Name: ${tokenInfo.name}`);
        console.log(`Symbol: ${tokenInfo.symbol}`);
        console.log(`Decimals: ${tokenInfo.decimals}`);
        console.log(`Max Supply: ${ethers.utils.formatEther(maxSupply)} KARMA`);
        console.log(`Total Supply: ${ethers.utils.formatEther(totalSupply)} KARMA`);
        console.log(`Is Paused: ${tokenInfo.isPaused}`);
        console.log("");

        // Step 4: Save deployment artifacts
        console.log("💾 Step 4: Saving deployment artifacts");
        console.log("-".repeat(40));

        const artifacts = {
            stage: "1.1",
            contracts: {
                KarmaToken: {
                    address: karmaToken.address,
                    abi: KarmaToken.interface.format("json"),
                    bytecode: KarmaToken.bytecode
                }
            },
            roles: {
                admin: admin.address,
                minter: minter.address,
                pauser: pauser.address
            },
            configuration: config
        };

        // Save artifacts
        const artifactsPath = path.join(__dirname, "../artifacts/stage1.1-contracts.json");
        fs.writeFileSync(artifactsPath, JSON.stringify(artifacts, null, 2));

        // Save deployment log
        const logsPath = path.join(__dirname, "../logs/stage1.1-deployment.log");
        fs.writeFileSync(logsPath, JSON.stringify(deploymentLog, null, 2));

        console.log(`✅ Artifacts saved to: ${artifactsPath}`);
        console.log(`✅ Deployment log saved to: ${logsPath}`);
        console.log("");

        // Step 5: Contract verification (if enabled)
        if (config.verification.enabled && network.name !== "hardhat") {
            console.log("🔍 Step 5: Contract verification");
            console.log("-".repeat(40));

            console.log("⏳ Waiting for verification delay...");
            await new Promise(resolve => setTimeout(resolve, config.verification.delay));

            try {
                await hre.run("verify:verify", {
                    address: karmaToken.address,
                    constructorArguments: [
                        config.contracts.KarmaToken.name,
                        config.contracts.KarmaToken.symbol,
                        config.contracts.KarmaToken.maxSupply,
                        admin.address
                    ],
                });

                console.log(`✅ Contract verified on Etherscan`);
                
                const verificationData = {
                    stage: "1.1",
                    timestamp: new Date().toISOString(),
                    network: network.name,
                    contracts: {
                        KarmaToken: {
                            address: karmaToken.address,
                            verified: true,
                            verificationTime: new Date().toISOString()
                        }
                    }
                };

                const verificationPath = path.join(__dirname, "../verification/stage1.1-verification.json");
                fs.writeFileSync(verificationPath, JSON.stringify(verificationData, null, 2));
                
            } catch (error) {
                console.log(`⚠️  Verification failed: ${error.message}`);
            }
        }

        console.log("");
        console.log("🎉 Stage 1.1 Deployment Completed Successfully!");
        console.log("=" .repeat(60));
        console.log(`KarmaToken Address: ${karmaToken.address}`);
        console.log(`Total Gas Used: ${Object.values(deploymentLog.gasUsed).reduce((a, b) => parseInt(a) + parseInt(b), 0)}`);
        console.log("");

        return {
            karmaToken: karmaToken.address,
            admin: admin.address,
            deploymentLog
        };

    } catch (error) {
        console.error("❌ Deployment failed:", error);
        
        // Save error log
        const errorLog = {
            stage: "1.1",
            timestamp: new Date().toISOString(),
            error: error.message,
            stack: error.stack,
            deploymentLog
        };
        
        const errorPath = path.join(__dirname, "../logs/stage1.1-deployment-error.log");
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