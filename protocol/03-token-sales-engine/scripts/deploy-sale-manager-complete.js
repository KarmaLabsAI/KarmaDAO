const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Starting complete SaleManager ecosystem deployment...");
    
    const [deployer] = await ethers.getSigners();
    console.log("📝 Deploying contracts with account:", deployer.address);
    console.log("💰 Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");
    
    // Deploy KarmaToken first
    console.log("\n📦 Deploying KarmaToken...");
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(deployer.address);
    await karmaToken.waitForDeployment();
    const karmaTokenAddress = await karmaToken.getAddress();
    console.log("✅ KarmaToken deployed to:", karmaTokenAddress);
    
    // Deploy VestingVault
    console.log("\n📦 Deploying VestingVault...");
    const VestingVault = await ethers.getContractFactory("VestingVault");
    const vestingVault = await VestingVault.deploy(karmaTokenAddress, deployer.address);
    await vestingVault.waitForDeployment();
    const vestingVaultAddress = await vestingVault.getAddress();
    console.log("✅ VestingVault deployed to:", vestingVaultAddress);
    
    // Deploy SaleManager
    console.log("\n📦 Deploying SaleManager...");
    const SaleManager = await ethers.getContractFactory("SaleManager");
    const saleManager = await SaleManager.deploy(
        karmaTokenAddress,
        vestingVaultAddress,
        deployer.address, // Use deployer as treasury for demo
        deployer.address  // admin
    );
    await saleManager.waitForDeployment();
    const saleManagerAddress = await saleManager.getAddress();
    console.log("✅ SaleManager deployed to:", saleManagerAddress);
    
    // Set up contract integrations
    console.log("\n🔧 Setting up contract integrations...");
    
    // Set SaleManager in KarmaToken (grants MINTER_ROLE)
    console.log("🎭 Setting SaleManager in KarmaToken...");
    const setSaleManagerTx = await karmaToken.setSaleManager(saleManagerAddress);
    await setSaleManagerTx.wait();
    console.log("✅ SaleManager granted MINTER_ROLE in KarmaToken");
    
    // Grant VESTING_MANAGER_ROLE to SaleManager in VestingVault
    console.log("🎭 Granting VESTING_MANAGER_ROLE to SaleManager...");
    const VESTING_MANAGER_ROLE = await vestingVault.VESTING_MANAGER_ROLE();
    const grantRoleTx = await vestingVault.grantRole(VESTING_MANAGER_ROLE, saleManagerAddress);
    await grantRoleTx.wait();
    console.log("✅ SaleManager granted VESTING_MANAGER_ROLE in VestingVault");
    
    // Configure sale phases for immediate testing
    console.log("\n⚙️  Configuring sale phases for demo...");
    
    const latestBlock = await ethers.provider.getBlock('latest');
    const currentTime = latestBlock.timestamp;
    const oneHour = 60 * 60;
    const oneDay = 24 * oneHour;
    
    // Private Sale Configuration (immediate start for demo)
    const privateSaleConfig = {
        price: ethers.parseEther("0.02"), // $0.02 per token
        minPurchase: ethers.parseEther("0.1"), // Lower minimum for demo
        maxPurchase: ethers.parseEther("10"), // Lower maximum for demo  
        hardCap: ethers.parseEther("100"), // Lower cap for demo
        tokenAllocation: ethers.parseEther("5000"), // 5000 tokens for demo
        startTime: currentTime + 300, // Start in 5 minutes
        endTime: currentTime + oneDay, // End in 1 day
        whitelistRequired: false, // No whitelist for demo
        kycRequired: false, // No KYC for demo
        merkleRoot: ethers.ZeroHash
    };
    
    console.log("📋 Configuring Private Sale phase...");
    const configPrivateTx = await saleManager.updatePhaseConfig(1, privateSaleConfig);
    await configPrivateTx.wait();
    console.log("✅ Private Sale configured: 0.02 ETH/token, 0.1-10 ETH purchase range");
    
    // Pre-Sale Configuration
    const preSaleConfig = {
        price: ethers.parseEther("0.04"), // $0.04 per token
        minPurchase: ethers.parseEther("0.05"), // Lower minimum for demo
        maxPurchase: ethers.parseEther("5"), // Lower maximum for demo
        hardCap: ethers.parseEther("50"), // Lower cap for demo
        tokenAllocation: ethers.parseEther("2500"), // 2500 tokens for demo
        startTime: currentTime + oneDay + 300, // Start after private sale
        endTime: currentTime + (2 * oneDay), // End in 2 days
        whitelistRequired: false,
        kycRequired: false,
        merkleRoot: ethers.ZeroHash
    };
    
    console.log("📋 Configuring Pre-Sale phase...");
    const configPreSaleTx = await saleManager.updatePhaseConfig(2, preSaleConfig);
    await configPreSaleTx.wait();
    console.log("✅ Pre-Sale configured: 0.04 ETH/token, 0.05-5 ETH purchase range");
    
    // Public Sale Configuration
    const publicSaleConfig = {
        price: ethers.parseEther("0.05"), // $0.05 per token
        minPurchase: 0, // No minimum for public sale
        maxPurchase: ethers.parseEther("2"), // Lower maximum for demo
        hardCap: ethers.parseEther("30"), // Lower cap for demo
        tokenAllocation: ethers.parseEther("1500"), // 1500 tokens for demo
        startTime: currentTime + (2 * oneDay) + 300, // Start after pre-sale
        endTime: currentTime + (3 * oneDay), // End in 3 days
        whitelistRequired: false,
        kycRequired: false,
        merkleRoot: ethers.ZeroHash
    };
    
    console.log("📋 Configuring Public Sale phase...");
    const configPublicTx = await saleManager.updatePhaseConfig(3, publicSaleConfig);
    await configPublicTx.wait();
    console.log("✅ Public Sale configured: 0.05 ETH/token, max 2 ETH purchase");
    
    // Create some demo test purchases after private sale starts
    console.log("\n🧪 Setting up demo scenario...");
    
    // Start the private sale for immediate testing
    console.log("🚀 Starting Private Sale phase...");
    const startPhaseTx = await saleManager.startSalePhase(1, privateSaleConfig);
    await startPhaseTx.wait();
    console.log("✅ Private Sale phase started!");
    
    // Wait for phase to be active
    console.log("⏰ Advancing time to make phase active...");
    await ethers.provider.send("evm_increaseTime", [400]);
    await ethers.provider.send("evm_mine", []);
    
    // Make a demo purchase
    console.log("💰 Setting up deployer for demo purchase...");
    
    // Set up deployer as accredited investor for private sale
    const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
    await saleManager.grantRole(KYC_MANAGER_ROLE, deployer.address);
    await saleManager.updateKYCStatus(deployer.address, 1); // APPROVED
    await saleManager.setAccreditedStatus(deployer.address, true);
    console.log("✅ Deployer set up as accredited investor");
    
    console.log("💰 Making demo purchase...");
    const purchaseAmount = ethers.parseEther("1");
    const purchaseTx = await saleManager.purchaseTokens([], { value: purchaseAmount });
    await purchaseTx.wait();
    console.log("✅ Demo purchase completed: 1 ETH for tokens");
    
    // Check results
    const purchase = await saleManager.getPurchase(0);
    const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
    console.log(`   Received: ${ethers.formatEther(expectedTokens)} tokens`);
    
    // Display deployment summary
    console.log("\n📊 DEPLOYMENT SUMMARY");
    console.log("====================================");
    console.log("🪙 KarmaToken:", karmaTokenAddress);
    console.log("🔒 VestingVault:", vestingVaultAddress);
    console.log("🏭 SaleManager:", saleManagerAddress);
    console.log("🏦 Treasury:", deployer.address);
    console.log("");
    
    console.log("💼 Sale Phases:");
    console.log("  Private Sale: ACTIVE NOW - 0.02 ETH/token");
    console.log("  Pre-Sale:     Starts in ~1 day - 0.04 ETH/token");
    console.log("  Public Sale:  Starts in ~2 days - 0.05 ETH/token");
    console.log("");
    
    console.log("📈 Current Statistics:");
    const [ethRaised, tokensSold, participants] = await saleManager.getPhaseStatistics(1);
    console.log(`  ETH Raised: ${ethers.formatEther(ethRaised)} ETH`);
    console.log(`  Tokens Sold: ${ethers.formatEther(tokensSold)} KARMA`);
    console.log(`  Participants: ${participants}`);
    console.log("");
    
    console.log("🧪 Test Commands:");
    console.log("  Purchase tokens: saleManager.purchaseTokens([], {value: ethers.parseEther('0.5')})");
    console.log("  Check phase: saleManager.getCurrentPhase()");
    console.log("  View stats: saleManager.getPhaseStatistics(1)");
    console.log("");
    
    console.log("✅ Complete SaleManager ecosystem deployed and ready for testing!");
    
    return {
        karmaToken: karmaTokenAddress,
        vestingVault: vestingVaultAddress,
        saleManager: saleManagerAddress,
        treasury: deployer.address
    };
}

// Execute deployment
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("❌ Deployment failed:", error);
            process.exit(1);
        });
}

module.exports = main; 