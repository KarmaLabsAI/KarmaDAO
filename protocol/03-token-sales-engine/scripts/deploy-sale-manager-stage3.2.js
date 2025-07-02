/**
 * Stage 3.2 Deployment Script - SaleManager with Enhanced Business Logic
 * 
 * This script demonstrates all Stage 3.2 functionality:
 * - Exact business parameters for all three phases
 * - Community engagement scoring system  
 * - Referral system for pre-sale participants
 * - MEV protection for public sale
 * - Phase-specific token distribution logic
 * - Uniswap V3 integration preparation
 */

const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

async function main() {
    console.log("\n=== KARMA LABS - STAGE 3.2 DEPLOYMENT ===\n");
    
    const [deployer, treasury, privateBuyer, preSaleBuyer, publicBuyer, referrer] = await ethers.getSigners();
    
    console.log("Deploying Stage 3.2 with account:", deployer.address);
    console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));
    
    // ============ DEPLOY CORE CONTRACTS ============
    
    console.log("\n--- Deploying Core Contracts ---");
    
    // Deploy KarmaToken
    console.log("Deploying KarmaToken...");
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy("Karma Token", "KARMA", treasury.address);
    await karmaToken.waitForDeployment();
    console.log("✅ KarmaToken deployed to:", await karmaToken.getAddress());
    
    // Deploy VestingVault
    console.log("Deploying VestingVault...");
    const VestingVault = await ethers.getContractFactory("VestingVault");
    const vestingVault = await VestingVault.deploy(await karmaToken.getAddress(), treasury.address);
    await vestingVault.waitForDeployment();
    console.log("✅ VestingVault deployed to:", await vestingVault.getAddress());
    
    // Deploy SaleManager (Stage 3.2)
    console.log("Deploying SaleManager (Stage 3.2)...");
    const SaleManager = await ethers.getContractFactory("SaleManager");
    const saleManager = await SaleManager.deploy(
        await karmaToken.getAddress(),
        await vestingVault.getAddress(),
        treasury.address,
        deployer.address
    );
    await saleManager.waitForDeployment();
    console.log("✅ SaleManager (Stage 3.2) deployed to:", await saleManager.getAddress());
    
    // ============ SETUP ROLES AND PERMISSIONS ============
    
    console.log("\n--- Setting Up Roles and Permissions ---");
    
    // Grant minting role to SaleManager
    const MINTER_ROLE = await karmaToken.MINTER_ROLE();
    await karmaToken.grantRole(MINTER_ROLE, await saleManager.getAddress());
    console.log("✅ Granted MINTER_ROLE to SaleManager");
    
    // Grant vault manager role to SaleManager
    const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
    await vestingVault.grantRole(VAULT_MANAGER_ROLE, await saleManager.getAddress());
    console.log("✅ Granted VAULT_MANAGER_ROLE to SaleManager");
    
    // Setup role managers
    const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
    const WHITELIST_MANAGER_ROLE = await saleManager.WHITELIST_MANAGER_ROLE();
    const ENGAGEMENT_MANAGER_ROLE = await saleManager.ENGAGEMENT_MANAGER_ROLE();
    
    await saleManager.grantRole(KYC_MANAGER_ROLE, deployer.address);
    await saleManager.grantRole(WHITELIST_MANAGER_ROLE, deployer.address);
    await saleManager.grantRole(ENGAGEMENT_MANAGER_ROLE, deployer.address);
    console.log("✅ Granted management roles to deployer");
    
    // ============ STAGE 3.2: CREATE MERKLE WHITELISTS ============
    
    console.log("\n--- Creating Merkle Tree Whitelists ---");
    
    // Private sale whitelist (accredited investors)
    const privateWhitelist = [privateBuyer.address, referrer.address];
    const privateLeaves = privateWhitelist.map(addr => keccak256(addr));
    const privateMerkleTree = new MerkleTree(privateLeaves, keccak256, { sortPairs: true });
    const privateMerkleRoot = privateMerkleTree.getHexRoot();
    
    // Pre-sale whitelist (community members)
    const preWhitelist = [preSaleBuyer.address, publicBuyer.address];
    const preLeaves = preWhitelist.map(addr => keccak256(addr));
    const preMerkleTree = new MerkleTree(preLeaves, keccak256, { sortPairs: true });
    const preMerkleRoot = preMerkleTree.getHexRoot();
    
    console.log("✅ Private Sale Merkle Root:", privateMerkleRoot);
    console.log("✅ Pre-Sale Merkle Root:", preMerkleRoot);
    
    // ============ STAGE 3.2: CONFIGURE PHASES WITH EXACT BUSINESS PARAMETERS ============
    
    console.log("\n--- Configuring Sale Phases with Stage 3.2 Business Logic ---");
    
    const currentTime = Math.floor(Date.now() / 1000);
    
    // Configure Private Sale ($0.02, $2M raise, 100M tokens, 6-month vesting)
    const privateStartTime = currentTime + 300; // 5 minutes from now
    await saleManager.configurePrivateSale(privateStartTime, privateMerkleRoot);
    console.log("✅ Private Sale configured:");
    console.log("   - Price: $0.02 per token");
    console.log("   - Min/Max: $25K - $200K");
    console.log("   - Hard Cap: $2M");
    console.log("   - Allocation: 100M tokens");
    console.log("   - Vesting: 100% vested (6 months linear)");
    
    // Configure Pre-Sale ($0.04, $4M raise, 100M tokens, 50% immediate + 50% vested)
    const preStartTime = currentTime + 600; // 10 minutes from now
    await saleManager.configurePreSale(preStartTime, preMerkleRoot);
    console.log("✅ Pre-Sale configured:");
    console.log("   - Price: $0.04 per token");
    console.log("   - Min/Max: $1K - $10K");
    console.log("   - Hard Cap: $4M");
    console.log("   - Allocation: 100M tokens");
    console.log("   - Distribution: 50% immediate + 50% vested (3 months)");
    console.log("   - Features: Engagement bonuses + Referral system");
    
    // Configure Public Sale ($0.05, $7.5M raise, 150M tokens, 100% immediate)
    const publicStartTime = currentTime + 900; // 15 minutes from now
    const liquidityConfig = {
        uniswapV3Factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984", // Mainnet factory
        uniswapV3Router: "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Mainnet router
        wethAddress: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // Mainnet WETH
        poolFee: 3000, // 0.3% fee tier
        liquidityEth: ethers.parseEther("100"), // 100 ETH for liquidity
        liquidityTokens: ethers.parseEther("5000"), // 5000 KARMA for liquidity
        tickLower: -887220, // Full range liquidity
        tickUpper: 887220
    };
    
    await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
    console.log("✅ Public Sale configured:");
    console.log("   - Price: $0.05 per token");
    console.log("   - Max: $5K per wallet");
    console.log("   - Hard Cap: $7.5M");
    console.log("   - Allocation: 150M tokens");
    console.log("   - Distribution: 100% immediate");
    console.log("   - Features: MEV protection + Uniswap V3 integration");
    
    // ============ STAGE 3.2: SETUP COMMUNITY ENGAGEMENT SCORING ============
    
    console.log("\n--- Setting Up Community Engagement Scoring ---");
    
    // Set engagement scores for pre-sale participants
    const engagementData = {
        discordActivity: 85,    // 85/100 Discord engagement
        twitterActivity: 92,    // 92/100 Twitter engagement
        githubActivity: 78,     // 78/100 GitHub contributions
        forumActivity: 90,      // 90/100 Forum participation
        lastUpdated: currentTime,
        verified: true
    };
    
    await saleManager.updateEngagementScore(preSaleBuyer.address, engagementData);
    const engagementScore = await saleManager.calculateEngagementScore(preSaleBuyer.address);
    console.log("✅ Engagement score set for pre-sale buyer:", engagementScore, "basis points");
    
    // Lower engagement for public buyer
    const lowerEngagementData = {
        discordActivity: 45,
        twitterActivity: 30,
        githubActivity: 20,
        forumActivity: 35,
        lastUpdated: currentTime,
        verified: true
    };
    
    await saleManager.updateEngagementScore(publicBuyer.address, lowerEngagementData);
    const lowerScore = await saleManager.calculateEngagementScore(publicBuyer.address);
    console.log("✅ Lower engagement score set for public buyer:", lowerScore, "basis points");
    
    // ============ STAGE 3.2: SETUP REFERRAL SYSTEM ============
    
    console.log("\n--- Setting Up Referral System ---");
    
    // Setup KYC for private sale participants (needed for referral eligibility)
    await saleManager.updateKYCStatus(privateBuyer.address, 1); // APPROVED
    await saleManager.setAccreditedStatus(privateBuyer.address, true);
    
    await saleManager.updateKYCStatus(referrer.address, 1); // APPROVED
    await saleManager.setAccreditedStatus(referrer.address, true);
    
    console.log("✅ KYC approved for private sale participants");
    
    // ============ STAGE 3.2: DEMONSTRATE PRIVATE SALE ============
    
    console.log("\n--- Starting Private Sale Demonstration ---");
    
    // Wait for private sale to start
    console.log("Waiting for private sale to start...");
    await new Promise(resolve => setTimeout(resolve, 6000)); // Wait 6 seconds
    
    // Start private sale
    const privateConfig = await saleManager.getPhaseConfig(1); // SalePhase.PRIVATE = 1
    await saleManager.startSalePhase(1, privateConfig);
    console.log("✅ Private sale started");
    
    // Private sale purchase (creates referral eligibility)
    const privatePurchaseAmount = ethers.parseEther("25000"); // $25K minimum
    const privateProof = privateMerkleTree.getHexProof(keccak256(referrer.address));
    
    await saleManager.connect(referrer).purchaseTokens(privateProof, { 
        value: privatePurchaseAmount 
    });
    console.log("✅ Private sale purchase completed: $25K by referrer");
    
    const privatePurchase = await saleManager.getPurchase(0);
    console.log("   - Tokens purchased:", ethers.formatEther(privatePurchase.tokenAmount));
    console.log("   - Vested:", privatePurchase.vested);
    
    // Check vesting schedule
    const vestingSchedules = await vestingVault.getVestingSchedules(referrer.address);
    console.log("   - Vesting schedules created:", vestingSchedules.length);
    if (vestingSchedules.length > 0) {
        console.log("   - Vesting duration:", vestingSchedules[0].duration / (24 * 60 * 60), "days");
    }
    
    // Register referral relationship
    await saleManager.registerReferral(referrer.address, preSaleBuyer.address);
    console.log("✅ Referral relationship registered: referrer -> preSaleBuyer");
    
    // ============ STAGE 3.2: DEMONSTRATE PRE-SALE WITH BONUSES ============
    
    console.log("\n--- Starting Pre-Sale with Engagement & Referral Bonuses ---");
    
    // End private sale and start pre-sale
    await saleManager.endCurrentPhase();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const preConfig = await saleManager.getPhaseConfig(2); // SalePhase.PRE_SALE = 2
    await saleManager.startSalePhase(2, preConfig);
    console.log("✅ Pre-sale started");
    
    // Pre-sale purchase with referral bonus
    const prePurchaseAmount = ethers.parseEther("5000"); // $5K purchase
    const preProof = preMerkleTree.getHexProof(keccak256(preSaleBuyer.address));
    
    const baseTokens = await saleManager.calculateTokenAmount(prePurchaseAmount);
    const bonusTokens = await saleManager.calculateBonusTokens(preSaleBuyer.address, baseTokens);
    
    console.log("Purchase calculation:");
    console.log("   - ETH amount:", ethers.formatEther(prePurchaseAmount));
    console.log("   - Base tokens:", ethers.formatEther(baseTokens));
    console.log("   - Engagement bonus:", ethers.formatEther(bonusTokens));
    
    await saleManager.connect(preSaleBuyer).purchaseTokensWithReferral(
        preProof, 
        referrer.address, 
        { value: prePurchaseAmount }
    );
    console.log("✅ Pre-sale purchase with referral completed");
    
    const prePurchase = await saleManager.getPurchase(1);
    console.log("   - Total tokens received:", ethers.formatEther(prePurchase.tokenAmount));
    console.log("   - Bonus tokens:", ethers.formatEther(prePurchase.bonusTokens));
    console.log("   - Referrer:", prePurchase.referrer);
    
    // Check token distribution (50% immediate + 50% vested)
    const buyerBalance = await karmaToken.balanceOf(preSaleBuyer.address);
    const buyerVestingSchedules = await vestingVault.getVestingSchedules(preSaleBuyer.address);
    console.log("   - Immediate tokens received:", ethers.formatEther(buyerBalance));
    console.log("   - Vesting schedules:", buyerVestingSchedules.length);
    
    // ============ STAGE 3.2: DEMONSTRATE PUBLIC SALE WITH MEV PROTECTION ============
    
    console.log("\n--- Starting Public Sale with MEV Protection ---");
    
    // End pre-sale and start public sale
    await saleManager.endCurrentPhase();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const publicConfig = await saleManager.getPhaseConfig(3); // SalePhase.PUBLIC = 3
    await saleManager.startSalePhase(3, publicConfig);
    console.log("✅ Public sale started");
    
    // Create liquidity pool
    const poolAddress = await saleManager.createLiquidityPool();
    console.log("✅ Uniswap V3 liquidity pool created:", poolAddress);
    
    // Enable MEV protection for public buyer
    await saleManager.connect(publicBuyer).enableMEVProtection(300); // 3% max slippage
    console.log("✅ MEV protection enabled for public buyer (3% max slippage)");
    
    // Public sale purchase with MEV protection
    const publicPurchaseAmount = ethers.parseEther("2000"); // $2K purchase
    const expectedTokens = await saleManager.calculateTokenAmount(publicPurchaseAmount);
    const minTokensOut = expectedTokens * 97n / 100n; // Allow 3% slippage
    const deadline = currentTime + 3600; // 1 hour deadline
    
    await saleManager.connect(publicBuyer).purchaseTokensWithMEVProtection(
        [], // No merkle proof needed for public sale
        minTokensOut,
        deadline,
        { value: publicPurchaseAmount }
    );
    console.log("✅ Public sale purchase with MEV protection completed");
    
    const publicPurchase = await saleManager.getPurchase(2);
    console.log("   - Tokens received:", ethers.formatEther(publicPurchase.tokenAmount));
    console.log("   - All tokens immediate (no vesting)");
    
    // Check immediate token receipt
    const publicBuyerBalance = await karmaToken.balanceOf(publicBuyer.address);
    console.log("   - Buyer balance:", ethers.formatEther(publicBuyerBalance));
    
    // ============ STAGE 3.2: ANALYTICS AND REPORTING ============
    
    console.log("\n--- Stage 3.2 Analytics & Statistics ---");
    
    // Overall statistics
    const [totalEthRaised, totalTokensSold, totalParticipants] = await saleManager.getOverallStatistics();
    console.log("📊 Overall Statistics:");
    console.log("   - Total ETH raised:", ethers.formatEther(totalEthRaised));
    console.log("   - Total tokens sold:", ethers.formatEther(totalTokensSold));
    console.log("   - Total participants:", totalParticipants.toString());
    
    // Phase-specific statistics
    for (let phase = 1; phase <= 3; phase++) {
        const [phaseEth, phaseTokens, phaseParticipants] = await saleManager.getPhaseStatistics(phase);
        const phaseName = phase === 1 ? "Private" : phase === 2 ? "Pre-Sale" : "Public";
        console.log(`   - ${phaseName} Sale: ${ethers.formatEther(phaseEth)} ETH, ${ethers.formatEther(phaseTokens)} tokens, ${phaseParticipants} participants`);
    }
    
    // Referral statistics
    const [totalReferrals, totalReferralBonus, activeReferrers] = await saleManager.getReferralStatistics();
    console.log("🤝 Referral Statistics:");
    console.log("   - Total referrals:", totalReferrals.toString());
    console.log("   - Total referral bonus tokens:", ethers.formatEther(totalReferralBonus));
    console.log("   - Active referrers:", activeReferrers.toString());
    
    // Engagement system stats
    console.log("🎯 Engagement System:");
    console.log("   - Total engagement updates:", (await saleManager.totalEngagementUpdates()).toString());
    console.log("   - High engagement participant bonus:", ethers.formatEther(bonusTokens));
    
    // Liquidity configuration
    const liquidityConfigResult = await saleManager.getLiquidityConfig();
    console.log("🏊 Liquidity Pool Configuration:");
    console.log("   - Pool fee:", liquidityConfigResult.poolFee);
    console.log("   - Liquidity ETH:", ethers.formatEther(liquidityConfigResult.liquidityEth));
    console.log("   - Liquidity tokens:", ethers.formatEther(liquidityConfigResult.liquidityTokens));
    
    // ============ DEPLOYMENT SUMMARY ============
    
    console.log("\n=== STAGE 3.2 DEPLOYMENT SUMMARY ===");
    console.log("✅ All Stage 3.2 features successfully implemented and demonstrated:");
    console.log("   1. Exact business parameters for all phases");
    console.log("   2. Community engagement scoring with weighted bonuses");
    console.log("   3. Referral system for pre-sale participants");
    console.log("   4. Phase-specific token distribution logic");
    console.log("   5. MEV protection for public sale");
    console.log("   6. Basic Uniswap V3 integration");
    console.log("   7. Comprehensive analytics and reporting");
    
    console.log("\n📋 Contract Addresses:");
    console.log("   - KarmaToken:", await karmaToken.getAddress());
    console.log("   - VestingVault:", await vestingVault.getAddress());
    console.log("   - SaleManager (Stage 3.2):", await saleManager.getAddress());
    console.log("   - Liquidity Pool:", poolAddress);
    
    console.log("\n🎉 Stage 3.2 deployment and demonstration completed successfully!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Deployment failed:", error);
        process.exit(1);
    }); 