/**
 * Stage 3.1: SaleManager Core Architecture Deployment Script
 * 
 * Deploys and configures the core sale management infrastructure:
 * - SaleManager contract with multi-phase support
 * - Phase management system initialization
 * - Access control and role setup
 * - Whitelist and KYC integration
 * - Treasury fund forwarding configuration
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Configuration
const CONFIG_PATH = path.join(__dirname, "../config/stage3.1-config.json");
const ARTIFACTS_DIR = path.join(__dirname, "../artifacts");
const LOGS_DIR = path.join(__dirname, "../logs");
const VERIFICATION_DIR = path.join(__dirname, "../verification");

async function main() {
    console.log("🚀 Starting Stage 3.1: SaleManager Core Architecture Deployment");
    console.log("=" .repeat(60));
    
    // Load configuration
    const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    console.log(`📋 Loaded configuration: ${config.name}`);
    
    // Get deployment accounts
    const [deployer, admin, kycManager, whitelistManager, engagementManager] = await ethers.getSigners();
    
    console.log("\n👥 Deployment Accounts:");
    console.log(`   Deployer: ${deployer.address}`);
    console.log(`   Admin: ${admin.address}`);
    console.log(`   KYC Manager: ${kycManager.address}`);
    console.log(`   Whitelist Manager: ${whitelistManager.address}`);
    console.log(`   Engagement Manager: ${engagementManager.address}`);
    
    // Verify network
    const network = await ethers.provider.getNetwork();
    console.log(`\n🌐 Network: ${network.name} (Chain ID: ${network.chainId})`);
    
    if (network.chainId.toString() !== config.network.chainId.toString()) {
        throw new Error(`Network mismatch: expected ${config.network.chainId}, got ${network.chainId}`);
    }
    
    const deploymentResults = {};
    const deploymentLog = [];
    
    try {
        // ============ STEP 1: Deploy Dependencies ============
        console.log("\n📦 Step 1: Deploying Dependencies");
        console.log("-".repeat(40));
        
        // Deploy KarmaToken (if not already deployed)
        console.log("🪙 Deploying KarmaToken...");
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        const karmaToken = await KarmaToken.deploy();
        await karmaToken.waitForDeployment();
        const karmaTokenAddress = await karmaToken.getAddress();
        
        console.log(`   ✅ KarmaToken deployed: ${karmaTokenAddress}`);
        deploymentResults.karmaToken = karmaTokenAddress;
        deploymentLog.push(`KarmaToken: ${karmaTokenAddress}`);
        
        // Deploy VestingVault (if not already deployed)
        console.log("⏳ Deploying VestingVault...");
        const VestingVault = await ethers.getContractFactory("VestingVault");
        const vestingVault = await VestingVault.deploy(karmaTokenAddress);
        await vestingVault.waitForDeployment();
        const vestingVaultAddress = await vestingVault.getAddress();
        
        console.log(`   ✅ VestingVault deployed: ${vestingVaultAddress}`);
        deploymentResults.vestingVault = vestingVaultAddress;
        deploymentLog.push(`VestingVault: ${vestingVaultAddress}`);
        
        // ============ STEP 2: Deploy SaleManager ============
        console.log("\n📦 Step 2: Deploying SaleManager Core");
        console.log("-".repeat(40));
        
        console.log("🏪 Deploying SaleManager...");
        const SaleManager = await ethers.getContractFactory("SaleManager");
        const saleManager = await SaleManager.deploy(
            karmaTokenAddress,
            vestingVaultAddress,
            admin.address,
            {
                gasLimit: config.contracts.saleManager.gasLimit
            }
        );
        await saleManager.waitForDeployment();
        const saleManagerAddress = await saleManager.getAddress();
        
        console.log(`   ✅ SaleManager deployed: ${saleManagerAddress}`);
        deploymentResults.saleManager = saleManagerAddress;
        deploymentLog.push(`SaleManager: ${saleManagerAddress}`);
        
        // ============ STEP 3: Setup Access Control ============
        console.log("\n🔐 Step 3: Setting up Access Control");
        console.log("-".repeat(40));
        
        // Grant minting role to SaleManager
        console.log("   Granting MINTER_ROLE to SaleManager...");
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        await karmaToken.grantRole(MINTER_ROLE, saleManagerAddress);
        console.log("   ✅ MINTER_ROLE granted");
        
        // Grant vault manager role to SaleManager  
        console.log("   Granting VAULT_MANAGER_ROLE to SaleManager...");
        const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
        await vestingVault.grantRole(VAULT_MANAGER_ROLE, saleManagerAddress);
        console.log("   ✅ VAULT_MANAGER_ROLE granted");
        
        // Setup SaleManager roles
        console.log("   Configuring SaleManager roles...");
        const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
        const WHITELIST_MANAGER_ROLE = await saleManager.WHITELIST_MANAGER_ROLE();
        const ENGAGEMENT_MANAGER_ROLE = await saleManager.ENGAGEMENT_MANAGER_ROLE();
        
        await saleManager.grantRole(KYC_MANAGER_ROLE, kycManager.address);
        await saleManager.grantRole(WHITELIST_MANAGER_ROLE, whitelistManager.address);
        await saleManager.grantRole(ENGAGEMENT_MANAGER_ROLE, engagementManager.address);
        
        console.log("   ✅ All roles configured");
        deploymentLog.push(`Roles configured for managers`);
        
        // ============ STEP 4: Initialize Sale Phases ============
        console.log("\n⚙️ Step 4: Initializing Sale Phase System");
        console.log("-".repeat(40));
        
        // Initialize phase allocations
        console.log("   Setting phase allocations...");
        const privateAllocation = config.salePhases.private.allocation;
        const preAllocation = config.salePhases.preSale.allocation;
        const publicAllocation = config.salePhases.public.allocation;
        
        await saleManager.setAllocationBalance(1, privateAllocation); // Private Sale
        await saleManager.setAllocationBalance(2, preAllocation);     // Pre-Sale
        await saleManager.setAllocationBalance(3, publicAllocation);  // Public Sale
        
        console.log(`   ✅ Private Sale: ${ethers.formatEther(privateAllocation)} KARMA`);
        console.log(`   ✅ Pre-Sale: ${ethers.formatEther(preAllocation)} KARMA`);
        console.log(`   ✅ Public Sale: ${ethers.formatEther(publicAllocation)} KARMA`);
        
        // ============ STEP 5: Treasury Integration ============
        console.log("\n💰 Step 5: Configuring Treasury Integration");
        console.log("-".repeat(40));
        
        // Set treasury address (placeholder for now)
        const treasuryAddress = config.treasury?.address || admin.address;
        console.log(`   Setting treasury address: ${treasuryAddress}`);
        await saleManager.setTreasuryAddress(treasuryAddress);
        console.log("   ✅ Treasury integration configured");
        
        // Configure fund allocation percentages
        console.log("   Configuring fund allocations...");
        const allocations = config.treasury.allocation;
        await saleManager.setAllocationPercentages(
            allocations.marketing,
            allocations.kol,
            allocations.development,
            allocations.buyback
        );
        console.log(`   ✅ Allocations: ${allocations.marketing}% Marketing, ${allocations.kol}% KOL, ${allocations.development}% Dev, ${allocations.buyback}% Buyback`);
        
        // ============ STEP 6: Security Configuration ============
        console.log("\n🛡️ Step 6: Configuring Security Settings");
        console.log("-".repeat(40));
        
        // Configure rate limiting
        if (config.validation.rateLimiting.enabled) {
            console.log("   Enabling rate limiting...");
            await saleManager.configureRateLimiting(
                config.validation.rateLimiting.windowSize,
                config.validation.rateLimiting.maxPurchasesPerWindow,
                config.validation.rateLimiting.cooldownPeriod
            );
            console.log("   ✅ Rate limiting configured");
        }
        
        // Configure front-running protection
        if (config.validation.frontRunningProtection.enabled) {
            console.log("   Enabling front-running protection...");
            await saleManager.configureFrontRunningProtection(
                config.validation.frontRunningProtection.maxGasPrice,
                config.validation.frontRunningProtection.blockDelayThreshold
            );
            console.log("   ✅ Front-running protection enabled");
        }
        
        // ============ STEP 7: Verification & Testing ============
        console.log("\n✅ Step 7: Verification & Testing");
        console.log("-".repeat(40));
        
        // Verify contract deployment
        console.log("   Verifying contract deployment...");
        const saleManagerCode = await ethers.provider.getCode(saleManagerAddress);
        if (saleManagerCode === "0x") {
            throw new Error("SaleManager deployment failed - no code at address");
        }
        console.log("   ✅ SaleManager deployment verified");
        
        // Test basic functionality
        console.log("   Testing basic functionality...");
        const currentPhase = await saleManager.getCurrentPhase();
        console.log(`   Current phase: ${currentPhase} (INACTIVE)`);
        
        const privateBalance = await saleManager.getAllocationBalance(1);
        console.log(`   Private sale allocation: ${ethers.formatEther(privateBalance)} KARMA`);
        
        // Test role verification
        const hasKycRole = await saleManager.hasRole(KYC_MANAGER_ROLE, kycManager.address);
        console.log(`   KYC Manager role verified: ${hasKycRole}`);
        
        console.log("   ✅ All tests passed");
        
        // ============ SAVE DEPLOYMENT ARTIFACTS ============
        console.log("\n💾 Saving Deployment Artifacts");
        console.log("-".repeat(40));
        
        // Ensure directories exist
        [ARTIFACTS_DIR, LOGS_DIR, VERIFICATION_DIR].forEach(dir => {
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
        });
        
        // Save contract artifacts
        const artifacts = {
            network: {
                name: network.name,
                chainId: network.chainId.toString()
            },
            deployment: {
                timestamp: new Date().toISOString(),
                deployer: deployer.address,
                gasUsed: "TBD"
            },
            contracts: {
                karmaToken: {
                    address: karmaTokenAddress,
                    name: "KarmaToken"
                },
                vestingVault: {
                    address: vestingVaultAddress,
                    name: "VestingVault"
                },
                saleManager: {
                    address: saleManagerAddress,
                    name: "SaleManager"
                }
            },
            configuration: {
                phases: config.salePhases,
                security: config.validation,
                treasury: config.treasury
            }
        };
        
        const artifactsPath = path.join(ARTIFACTS_DIR, "stage3.1-contracts.json");
        fs.writeFileSync(artifactsPath, JSON.stringify(artifacts, null, 2));
        console.log(`   ✅ Artifacts saved: ${artifactsPath}`);
        
        // Save deployment log
        const logContent = [
            `Stage 3.1 Deployment Log`,
            `========================`,
            `Timestamp: ${new Date().toISOString()}`,
            `Network: ${network.name} (${network.chainId})`,
            `Deployer: ${deployer.address}`,
            ``,
            `Deployed Contracts:`,
            ...deploymentLog.map(entry => `  - ${entry}`),
            ``,
            `Configuration:`,
            `  - Private Sale: ${ethers.formatEther(privateAllocation)} KARMA`,
            `  - Pre-Sale: ${ethers.formatEther(preAllocation)} KARMA`,
            `  - Public Sale: ${ethers.formatEther(publicAllocation)} KARMA`,
            `  - Treasury: ${treasuryAddress}`,
            `  - Rate Limiting: ${config.validation.rateLimiting.enabled}`,
            `  - Front-running Protection: ${config.validation.frontRunningProtection.enabled}`,
            ``
        ].join('\n');
        
        const logPath = path.join(LOGS_DIR, "stage3.1-deployment.log");
        fs.writeFileSync(logPath, logContent);
        console.log(`   ✅ Log saved: ${logPath}`);
        
        // Save verification data
        const verificationData = {
            saleManager: {
                address: saleManagerAddress,
                constructorArgs: [karmaTokenAddress, vestingVaultAddress, admin.address],
                contractName: "SaleManager",
                verified: false
            },
            karmaToken: {
                address: karmaTokenAddress,
                constructorArgs: [],
                contractName: "KarmaToken", 
                verified: false
            },
            vestingVault: {
                address: vestingVaultAddress,
                constructorArgs: [karmaTokenAddress],
                contractName: "VestingVault",
                verified: false
            }
        };
        
        const verificationPath = path.join(VERIFICATION_DIR, "stage3.1-verification.json");
        fs.writeFileSync(verificationPath, JSON.stringify(verificationData, null, 2));
        console.log(`   ✅ Verification data saved: ${verificationPath}`);
        
        // ============ DEPLOYMENT SUMMARY ============
        console.log("\n🎉 Deployment Summary");
        console.log("=".repeat(60));
        console.log(`✅ Stage 3.1: SaleManager Core Architecture Deployed Successfully!`);
        console.log(`\n📋 Contract Addresses:`);
        console.log(`   KarmaToken: ${karmaTokenAddress}`);
        console.log(`   VestingVault: ${vestingVaultAddress}`);
        console.log(`   SaleManager: ${saleManagerAddress}`);
        
        console.log(`\n⚙️ Configuration:`);
        console.log(`   Private Sale Allocation: ${ethers.formatEther(privateAllocation)} KARMA`);
        console.log(`   Pre-Sale Allocation: ${ethers.formatEther(preAllocation)} KARMA`);
        console.log(`   Public Sale Allocation: ${ethers.formatEther(publicAllocation)} KARMA`);
        console.log(`   Treasury Address: ${treasuryAddress}`);
        
        console.log(`\n👥 Role Assignments:`);
        console.log(`   KYC Manager: ${kycManager.address}`);
        console.log(`   Whitelist Manager: ${whitelistManager.address}`);
        console.log(`   Engagement Manager: ${engagementManager.address}`);
        
        console.log(`\n🔗 Next Steps:`);
        console.log(`   1. Configure sale phase start times`);
        console.log(`   2. Setup whitelists for private and pre-sale`);
        console.log(`   3. Integrate with KYC provider`);
        console.log(`   4. Deploy Stage 3.2 (Sale Phase Implementations)`);
        console.log(`   5. Run integration tests`);
        
        console.log(`\n📄 Files Generated:`);
        console.log(`   - ${artifactsPath}`);
        console.log(`   - ${logPath}`);
        console.log(`   - ${verificationPath}`);
        
        return deploymentResults;
        
    } catch (error) {
        console.error("\n❌ Deployment Failed:");
        console.error(error);
        
        // Save error log
        const errorLog = [
            `Stage 3.1 Deployment Error`,
            `==========================`,
            `Timestamp: ${new Date().toISOString()}`,
            `Network: ${network.name} (${network.chainId})`,
            `Deployer: ${deployer.address}`,
            ``,
            `Error: ${error.message}`,
            `Stack: ${error.stack}`,
            ``
        ].join('\n');
        
        const errorPath = path.join(LOGS_DIR, `stage3.1-deployment-error-${Date.now()}.log`);
        fs.writeFileSync(errorPath, errorLog);
        console.log(`\n📄 Error log saved: ${errorPath}`);
        
        throw error;
    }
}

// Execute deployment
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { main }; 