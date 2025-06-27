const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Starting SaleManager deployment...");
    
    const [deployer] = await ethers.getSigners();
    console.log("📝 Deploying contracts with account:", deployer.address);
    console.log("💰 Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH");
    
    // Get contract addresses (assuming they're already deployed)
    // In production, these would be loaded from deployment artifacts
    const karmaTokenAddress = process.env.KARMA_TOKEN_ADDRESS || "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const vestingVaultAddress = process.env.VESTING_VAULT_ADDRESS || "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
    const treasuryAddress = process.env.TREASURY_ADDRESS || deployer.address; // Use deployer as treasury for demo
    
    console.log("🔗 Using KarmaToken at:", karmaTokenAddress);
    console.log("🔗 Using VestingVault at:", vestingVaultAddress);
    console.log("🏦 Using Treasury at:", treasuryAddress);
    
    // Deploy SaleManager
    console.log("\n📦 Deploying SaleManager...");
    const SaleManager = await ethers.getContractFactory("SaleManager");
    const saleManager = await SaleManager.deploy(
        karmaTokenAddress,
        vestingVaultAddress,
        treasuryAddress,
        deployer.address // admin
    );
    
    await saleManager.waitForDeployment();
    const saleManagerAddress = await saleManager.getAddress();
    console.log("✅ SaleManager deployed to:", saleManagerAddress);
    
    // Set up contracts for integration
    console.log("\n🔧 Setting up contract integrations...");
    
    // Connect to existing contracts
    const karmaToken = await ethers.getContractAt("KarmaToken", karmaTokenAddress);
    const vestingVault = await ethers.getContractAt("VestingVault", vestingVaultAddress);
    
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
    
    // Configure sale phases according to business requirements
    console.log("\n⚙️  Configuring sale phases...");
    
    const currentTime = Math.floor(Date.now() / 1000);
    const oneDay = 24 * 60 * 60;
    const oneMonth = 30 * oneDay;
    
    // Private Sale Configuration (Month 3-4: $0.02, 100M KARMA, $2M raise)
    const privateSaleConfig = {
        price: ethers.parseEther("0.02"), // $0.02 per token (in ETH equivalent)
        minPurchase: ethers.parseEther("25"), // $25K minimum
        maxPurchase: ethers.parseEther("200"), // $200K maximum  
        hardCap: ethers.parseEther("2000"), // $2M hard cap
        tokenAllocation: ethers.parseEther("100000000"), // 100M tokens
        startTime: currentTime + (3 * oneMonth), // Start in 3 months
        endTime: currentTime + (4 * oneMonth), // End in 4 months
        whitelistRequired: true,
        kycRequired: true,
        merkleRoot: ethers.ZeroHash // Will be updated with actual whitelist
    };
    
    console.log("📋 Configuring Private Sale phase...");
    const configPrivateTx = await saleManager.updatePhaseConfig(1, privateSaleConfig); // PRIVATE = 1
    await configPrivateTx.wait();
    console.log("✅ Private Sale configured: $0.02/token, $2M cap, 100M tokens");
    
    // Pre-Sale Configuration (Month 7-8: $0.04, 100M KARMA, $4M raise)
    const preSaleConfig = {
        price: ethers.parseEther("0.04"), // $0.04 per token
        minPurchase: ethers.parseEther("1"), // $1K minimum
        maxPurchase: ethers.parseEther("10"), // $10K maximum
        hardCap: ethers.parseEther("4000"), // $4M hard cap
        tokenAllocation: ethers.parseEther("100000000"), // 100M tokens
        startTime: currentTime + (7 * oneMonth), // Start in 7 months
        endTime: currentTime + (8 * oneMonth), // End in 8 months  
        whitelistRequired: false, // Community phase, no whitelist
        kycRequired: false,
        merkleRoot: ethers.ZeroHash
    };
    
    console.log("📋 Configuring Pre-Sale phase...");
    const configPreSaleTx = await saleManager.updatePhaseConfig(2, preSaleConfig); // PRE_SALE = 2
    await configPreSaleTx.wait();
    console.log("✅ Pre-Sale configured: $0.04/token, $4M cap, 100M tokens");
    
    // Public Sale Configuration (Month 9: $0.05, 150M KARMA, $7.5M raise)
    const publicSaleConfig = {
        price: ethers.parseEther("0.05"), // $0.05 per token (IDO price)
        minPurchase: 0, // No minimum for public sale
        maxPurchase: ethers.parseEther("5"), // $5K maximum per wallet
        hardCap: ethers.parseEther("7500"), // $7.5M hard cap
        tokenAllocation: ethers.parseEther("150000000"), // 150M tokens
        startTime: currentTime + (9 * oneMonth), // Start in 9 months
        endTime: currentTime + (9 * oneMonth) + oneDay, // 1 day duration
        whitelistRequired: false,
        kycRequired: false,
        merkleRoot: ethers.ZeroHash
    };
    
    console.log("📋 Configuring Public Sale phase...");
    const configPublicTx = await saleManager.updatePhaseConfig(3, publicSaleConfig); // PUBLIC = 3
    await configPublicTx.wait();
    console.log("✅ Public Sale configured: $0.05/token, $7.5M cap, 150M tokens");
    
    // Set up additional roles for demo
    console.log("\n👥 Setting up additional management roles...");
    
    const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
    const WHITELIST_MANAGER_ROLE = await saleManager.WHITELIST_MANAGER_ROLE();
    
    // Grant roles to deployer for demo (in production, these would be separate addresses)
    await saleManager.grantRole(KYC_MANAGER_ROLE, deployer.address);
    await saleManager.grantRole(WHITELIST_MANAGER_ROLE, deployer.address);
    console.log("✅ Management roles granted to deployer");
    
    // Create some sample KYC approvals for testing
    console.log("\n🧪 Setting up demo data...");
    
    // Get some test addresses (in production, these would be real participants)
    const [, , testUser1, testUser2] = await ethers.getSigners();
    
    if (testUser1 && testUser2) {
        // Approve KYC for test users
        await saleManager.updateKYCStatus(testUser1.address, 1); // APPROVED
        await saleManager.updateKYCStatus(testUser2.address, 1); // APPROVED
        
        // Set accredited status for private sale eligibility
        await saleManager.setAccreditedStatus(testUser1.address, true);
        await saleManager.setAccreditedStatus(testUser2.address, true);
        
        console.log("✅ Demo KYC approvals created for test addresses");
        console.log("   - Test User 1:", testUser1.address);
        console.log("   - Test User 2:", testUser2.address);
    }
    
    // Display deployment summary
    console.log("\n📊 DEPLOYMENT SUMMARY");
    console.log("====================================");
    console.log("🏭 SaleManager Address:", saleManagerAddress);
    console.log("🪙 KarmaToken Address:", karmaTokenAddress);
    console.log("🔒 VestingVault Address:", vestingVaultAddress);
    console.log("🏦 Treasury Address:", treasuryAddress);
    console.log("");
    
    console.log("💼 Sale Phases Configured:");
    console.log("  Private Sale: Months 3-4, $0.02/token, $2M cap, 100M tokens");
    console.log("  Pre-Sale:     Months 7-8, $0.04/token, $4M cap, 100M tokens");
    console.log("  Public Sale:  Month 9,    $0.05/token, $7.5M cap, 150M tokens");
    console.log("");
    
    console.log("🎭 Roles and Permissions:");
    console.log("  - SaleManager has MINTER_ROLE in KarmaToken");
    console.log("  - SaleManager has VESTING_MANAGER_ROLE in VestingVault");
    console.log("  - Deployer has all management roles");
    console.log("");
    
    console.log("📋 Next Steps:");
    console.log("  1. Update whitelist merkle roots before private sale");
    console.log("  2. Start phases using startSalePhase() when ready");
    console.log("  3. Monitor sales through analytics functions");
    console.log("  4. Withdraw funds periodically to treasury");
    console.log("");
    
    console.log("✅ SaleManager deployment completed successfully!");
    
    return {
        saleManager: saleManagerAddress,
        karmaToken: karmaTokenAddress,
        vestingVault: vestingVaultAddress,
        treasury: treasuryAddress
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