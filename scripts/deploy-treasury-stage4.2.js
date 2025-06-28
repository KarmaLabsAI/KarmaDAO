const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying Karma Labs Treasury System - Stage 4.2 Advanced Features");
    console.log("=".repeat(80));

    // Get deployment accounts
    const [deployer, admin, approver1, approver2, approver3, user1, user2, user3, paymaster, buybackBurn] = await ethers.getSigners();
    
    console.log("📋 Deployment Configuration:");
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Admin: ${admin.address}`);
    console.log(`Approvers: ${approver1.address}, ${approver2.address}, ${approver3.address}`);
    console.log(`Users: ${user1.address}, ${user2.address}, ${user3.address}`);
    console.log(`Paymaster Mock: ${paymaster.address}`);
    console.log(`BuybackBurn Mock: ${buybackBurn.address}`);
    console.log("");

    // Deploy ecosystem contracts
    console.log("📦 Setting up existing ecosystem contracts...");
    
    // Deploy KarmaToken
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(admin.address);
    await karmaToken.waitForDeployment();
    console.log(`✅ KarmaToken deployed: ${await karmaToken.getAddress()}`);

    // Deploy VestingVault (simplified for treasury testing)
    const VestingVault = await ethers.getContractFactory("VestingVault");
    const vestingVault = await VestingVault.deploy(
        await karmaToken.getAddress(),
        admin.address
    );
    await vestingVault.waitForDeployment();
    console.log(`✅ VestingVault deployed: ${await vestingVault.getAddress()}`);

    // Deploy SaleManager
    const SaleManager = await ethers.getContractFactory("SaleManager");
    const saleManager = await SaleManager.deploy(
        await karmaToken.getAddress(),
        await vestingVault.getAddress(),
        admin.address, // temporary treasury address
        admin.address
    );
    await saleManager.waitForDeployment();
    console.log(`✅ SaleManager deployed: ${await saleManager.getAddress()}`);

    // Deploy Treasury with Stage 4.1 & 4.2 functionality
    console.log("\n🏛️  Deploying Treasury Contract with Stage 4.2 Features...");
    
    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(
        admin.address,
        await saleManager.getAddress(),
        [approver1.address, approver2.address, approver3.address],
        2 // 2-of-3 multisig threshold
    );
    await treasury.waitForDeployment();
    const treasuryAddress = await treasury.getAddress();
    console.log(`✅ Treasury deployed: ${treasuryAddress}`);

    // Configure Treasury with KarmaToken
    await treasury.connect(admin).setKarmaToken(await karmaToken.getAddress());
    console.log("✅ Treasury configured with KarmaToken");

    // Grant roles for Stage 4.2 functionality
    const MINTER_ROLE = await karmaToken.MINTER_ROLE();
    await karmaToken.connect(admin).grantRole(MINTER_ROLE, treasuryAddress);
    console.log("✅ Treasury granted minting role for token distributions");

    // Mint tokens to Treasury for distributions
    const totalTokensForDistribution = ethers.parseEther("500000000"); // 500M tokens
    await karmaToken.connect(admin).mint(treasuryAddress, totalTokensForDistribution);
    console.log(`✅ Minted ${ethers.formatEther(totalTokensForDistribution)} KARMA tokens to Treasury`);

    // Fund treasury with ETH
    const initialFunding = ethers.parseEther("200");
    await treasury.connect(deployer).receiveETH(0, "Initial funding for Stage 4.2 demo", { value: initialFunding });
    console.log(`✅ Treasury funded with ${ethers.formatEther(initialFunding)} ETH`);

    // ============ STAGE 4.2: TOKEN DISTRIBUTION SYSTEM DEMO ============
    console.log("\n" + "=".repeat(80));
    console.log("🎯 Stage 4.2 Demo: Token Distribution System");
    console.log("=".repeat(80));

    // Configure Token Distributions
    console.log("\n📊 Configuring Token Distribution Allocations...");
    
    // Community Rewards (200M tokens)
    const communityRewardsAllocation = ethers.parseEther("200000000");
    await treasury.connect(admin).configureTokenDistribution(
        0, // COMMUNITY_REWARDS
        communityRewardsAllocation,
        0, // no vesting
        0  // no cliff
    );
    console.log(`✅ Community Rewards: ${ethers.formatEther(communityRewardsAllocation)} KARMA configured`);

    // Airdrop (20M tokens for early testers)
    const airdropAllocation = ethers.parseEther("20000000");
    await treasury.connect(admin).configureTokenDistribution(
        1, // AIRDROP
        airdropAllocation,
        0, // no vesting
        0  // no cliff
    );
    console.log(`✅ Airdrop: ${ethers.formatEther(airdropAllocation)} KARMA configured`);

    // Staking Rewards (100M tokens over 2 years)
    const stakingRewardsAllocation = ethers.parseEther("100000000");
    const stakingDistributionPeriod = 2 * 365 * 24 * 3600; // 2 years
    await treasury.connect(admin).configureStakingRewards(
        stakingRewardsAllocation,
        stakingDistributionPeriod
    );
    console.log(`✅ Staking Rewards: ${ethers.formatEther(stakingRewardsAllocation)} KARMA over 2 years`);

    // Engagement Incentives (80M tokens over 2 years)
    const engagementIncentiveAllocation = ethers.parseEther("80000000");
    const engagementDistributionPeriod = 2 * 365 * 24 * 3600; // 2 years
    const baseRewardRate = ethers.parseEther("1000"); // 1000 KARMA per engagement point
    await treasury.connect(admin).configureEngagementIncentives(
        engagementIncentiveAllocation,
        engagementDistributionPeriod,
        baseRewardRate
    );
    console.log(`✅ Engagement Incentives: ${ethers.formatEther(engagementIncentiveAllocation)} KARMA over 2 years`);

    // Demonstrate Community Rewards Distribution
    console.log("\n💰 Distributing Community Rewards...");
    const communityRecipients = [user1.address, user2.address, user3.address];
    const communityAmounts = [
        ethers.parseEther("50000"),  // 50K KARMA for user1
        ethers.parseEther("75000"),  // 75K KARMA for user2
        ethers.parseEther("25000")   // 25K KARMA for user3
    ];
    
    const user1BalanceBefore = await karmaToken.balanceOf(user1.address);
    const user2BalanceBefore = await karmaToken.balanceOf(user2.address);
    const user3BalanceBefore = await karmaToken.balanceOf(user3.address);
    
    await treasury.connect(admin).distributeCommunityRewards(
        communityRecipients,
        communityAmounts,
        "Q1 2025 Community Rewards Distribution"
    );
    
    console.log(`✅ Community Rewards Distributed:`);
    console.log(`   User1: ${ethers.formatEther(await karmaToken.balanceOf(user1.address) - user1BalanceBefore)} KARMA`);
    console.log(`   User2: ${ethers.formatEther(await karmaToken.balanceOf(user2.address) - user2BalanceBefore)} KARMA`);
    console.log(`   User3: ${ethers.formatEther(await karmaToken.balanceOf(user3.address) - user3BalanceBefore)} KARMA`);

    // Demonstrate Airdrop Execution
    console.log("\n🪂 Executing Early Tester Airdrop...");
    const airdropRecipients = [user1.address, user2.address];
    const airdropAmounts = [
        ethers.parseEther("10000"), // 10K KARMA for user1
        ethers.parseEther("15000")  // 15K KARMA for user2
    ];
    const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("early_tester_merkle_root"));
    
    const airdropId = await treasury.connect(admin).executeAirdrop.staticCall(
        airdropRecipients,
        airdropAmounts,
        merkleRoot
    );
    
    await treasury.connect(admin).executeAirdrop(
        airdropRecipients,
        airdropAmounts,
        merkleRoot
    );
    
    console.log(`✅ Airdrop executed (ID: ${airdropId})`);
    console.log(`   Total tokens: ${ethers.formatEther(airdropAmounts[0] + airdropAmounts[1])} KARMA`);

    // Demonstrate Staking Rewards Distribution
    console.log("\n🥩 Distributing Staking Rewards...");
    const stakingContract = user3.address; // Mock staking contract
    const stakingRewardAmount = ethers.parseEther("50000"); // 50K KARMA for staking rewards
    
    const stakingContractBalanceBefore = await karmaToken.balanceOf(stakingContract);
    
    await treasury.connect(admin).distributeStakingRewards(
        stakingContract,
        stakingRewardAmount
    );
    
    console.log(`✅ Staking Rewards Distributed:`);
    console.log(`   Staking Contract: ${ethers.formatEther(await karmaToken.balanceOf(stakingContract) - stakingContractBalanceBefore)} KARMA`);

    // Demonstrate Engagement Incentives Distribution
    console.log("\n🎯 Distributing Engagement Incentives...");
    const engagementUsers = [user1.address, user2.address];
    const engagementPoints = [50, 150]; // user2 gets bonus for high engagement (>=100 points)
    
    const user1EngagementBefore = await karmaToken.balanceOf(user1.address);
    const user2EngagementBefore = await karmaToken.balanceOf(user2.address);
    
    await treasury.connect(admin).distributeEngagementIncentives(
        engagementUsers,
        engagementPoints
    );
    
    console.log(`✅ Engagement Incentives Distributed:`);
    console.log(`   User1 (50 pts): ${ethers.formatEther(await karmaToken.balanceOf(user1.address) - user1EngagementBefore)} KARMA`);
    console.log(`   User2 (150 pts + bonus): ${ethers.formatEther(await karmaToken.balanceOf(user2.address) - user2EngagementBefore)} KARMA`);

    // ============ STAGE 4.2: EXTERNAL CONTRACT INTEGRATION DEMO ============
    console.log("\n" + "=".repeat(80));
    console.log("🔗 Stage 4.2 Demo: External Contract Integration");
    console.log("=".repeat(80));

    // Configure External Contracts
    console.log("\n⚙️  Configuring External Contracts...");
    
    // Configure Paymaster contract ($100K ETH initial allocation)
    const paymasterFundingAmount = ethers.parseEther("10"); // 10 ETH for demo
    const paymasterFundingFrequency = 7 * 24 * 3600; // Weekly
    const paymasterMinimumBalance = ethers.parseEther("1"); // 1 ETH minimum
    
    await treasury.connect(admin).configureExternalContract(
        paymaster.address,
        0, // PAYMASTER
        paymasterFundingAmount,
        paymasterFundingFrequency,
        paymasterMinimumBalance
    );
    console.log(`✅ Paymaster configured: ${paymaster.address}`);
    console.log(`   Funding Amount: ${ethers.formatEther(paymasterFundingAmount)} ETH`);
    console.log(`   Minimum Balance: ${ethers.formatEther(paymasterMinimumBalance)} ETH`);

    // Configure BuybackBurn contract (20% of treasury allocations)
    const buybackFundingAmount = ethers.parseEther("5"); // 5 ETH for demo
    const buybackFundingFrequency = 30 * 24 * 3600; // Monthly
    const buybackMinimumBalance = ethers.parseEther("0.5"); // 0.5 ETH minimum
    
    await treasury.connect(admin).configureExternalContract(
        buybackBurn.address,
        1, // BUYBACK_BURN
        buybackFundingAmount,
        buybackFundingFrequency,
        buybackMinimumBalance
    );
    console.log(`✅ BuybackBurn configured: ${buybackBurn.address}`);
    console.log(`   Funding Amount: ${ethers.formatEther(buybackFundingAmount)} ETH`);

    // Fund Paymaster Contract
    console.log("\n💰 Funding Paymaster Contract...");
    const paymasterInitialFunding = ethers.parseEther("15"); // $100K ETH equivalent for demo
    const paymasterBalanceBefore = await ethers.provider.getBalance(paymaster.address);
    
    await treasury.connect(admin).fundPaymaster(
        paymaster.address,
        paymasterInitialFunding
    );
    
    const paymasterBalanceAfter = await ethers.provider.getBalance(paymaster.address);
    console.log(`✅ Paymaster funded with ${ethers.formatEther(paymasterInitialFunding)} ETH`);
    console.log(`   Balance: ${ethers.formatEther(paymasterBalanceAfter)} ETH (was ${ethers.formatEther(paymasterBalanceBefore)} ETH)`);

    // Fund BuybackBurn Contract
    console.log("\n🔥 Funding BuybackBurn Contract...");
    const buybackInitialFunding = ethers.parseEther("20"); // 20% of treasury allocation for demo
    const buybackBalanceBefore = await ethers.provider.getBalance(buybackBurn.address);
    
    await treasury.connect(admin).fundBuybackBurn(
        buybackBurn.address,
        buybackInitialFunding
    );
    
    const buybackBalanceAfter = await ethers.provider.getBalance(buybackBurn.address);
    console.log(`✅ BuybackBurn funded with ${ethers.formatEther(buybackInitialFunding)} ETH`);
    console.log(`   Balance: ${ethers.formatEther(buybackBalanceAfter)} ETH (was ${ethers.formatEther(buybackBalanceBefore)} ETH)`);

    // Demonstrate External Balance Monitoring
    console.log("\n📊 Monitoring External Contract Balances...");
    
    const [paymasterBalance, paymasterBelowThreshold] = await treasury.monitorExternalBalance(paymaster.address);
    const [buybackBalance, buybackBelowThreshold] = await treasury.monitorExternalBalance(buybackBurn.address);
    
    console.log(`✅ External Contract Monitoring:`);
    console.log(`   Paymaster: ${ethers.formatEther(paymasterBalance)} ETH (Below threshold: ${paymasterBelowThreshold})`);
    console.log(`   BuybackBurn: ${ethers.formatEther(buybackBalance)} ETH (Below threshold: ${buybackBelowThreshold})`);

    // Trigger Automatic Funding
    console.log("\n🤖 Triggering Automatic Funding...");
    await treasury.connect(admin).triggerAutomaticFunding();
    console.log("✅ Automatic funding triggered for all configured contracts");

    // ============ STAGE 4.2: TRANSPARENCY AND GOVERNANCE DEMO ============
    console.log("\n" + "=".repeat(80));
    console.log("🏛️  Stage 4.2 Demo: Transparency and Governance");
    console.log("=".repeat(80));

    // Create Governance Proposals
    console.log("\n📋 Creating Governance Proposals...");
    
    // Marketing proposal
    const marketingProposalId = await treasury.connect(admin).createGovernanceProposal.staticCall(
        "Website Redesign Project",
        "Funding for complete website redesign and UX improvements",
        ethers.parseEther("25"), // 25 ETH requested
        0, // MARKETING category
        7 * 24 * 3600 // 7-day voting period
    );
    
    await treasury.connect(admin).createGovernanceProposal(
        "Website Redesign Project",
        "Funding for complete website redesign and UX improvements",
        ethers.parseEther("25"),
        0, // MARKETING category
        7 * 24 * 3600
    );
    
    console.log(`✅ Marketing Proposal created (ID: ${marketingProposalId})`);
    console.log(`   Requested: 25 ETH for website redesign`);

    // Development proposal
    const devProposalId = await treasury.connect(admin).createGovernanceProposal.staticCall(
        "Smart Contract Audit",
        "Security audit for upcoming contract upgrades",
        ethers.parseEther("30"), // 30 ETH requested
        2, // DEVELOPMENT category
        7 * 24 * 3600 // 7-day voting period
    );
    
    await treasury.connect(admin).createGovernanceProposal(
        "Smart Contract Audit",
        "Security audit for upcoming contract upgrades",
        ethers.parseEther("30"),
        2, // DEVELOPMENT category
        7 * 24 * 3600
    );
    
    console.log(`✅ Development Proposal created (ID: ${devProposalId})`);
    console.log(`   Requested: 30 ETH for security audit`);

    // Demonstrate Enhanced Reporting
    console.log("\n📊 Generating Enhanced Treasury Reports...");
    
    // Get detailed monthly report
    const currentDate = new Date();
    const currentYear = currentDate.getFullYear();
    const currentMonth = currentDate.getMonth() + 1;
    
    const monthlyReport = await treasury.getDetailedMonthlyReport(currentMonth, currentYear);
    console.log(`✅ Monthly Report (${currentMonth}/${currentYear}):`);
    console.log(`   Total Received: ${ethers.formatEther(monthlyReport.totalReceived)} ETH`);
    console.log(`   Total Distributed: ${ethers.formatEther(monthlyReport.totalDistributed)} ETH`);
    console.log(`   Token Distributions: ${ethers.formatEther(monthlyReport.tokenDistributions)} KARMA`);
    console.log(`   External Funding: ${ethers.formatEther(monthlyReport.externalFunding)} ETH`);
    console.log(`   Governance Proposals: ${monthlyReport.governanceProposals}`);

    // Get public analytics
    const publicAnalytics = await treasury.getPublicAnalytics();
    console.log(`\n✅ Public Analytics:`);
    console.log(`   Total Treasury Value: ${ethers.formatEther(publicAnalytics.totalTreasuryValue)} ETH`);
    console.log(`   Monthly Inflow: ${ethers.formatEther(publicAnalytics.monthlyInflow)} ETH`);
    console.log(`   Monthly Outflow: ${ethers.formatEther(publicAnalytics.monthlyOutflow)} ETH`);
    console.log(`   Tokens Distributed: ${ethers.formatEther(publicAnalytics.tokensDistributed)} KARMA`);
    console.log(`   Active Proposals: ${publicAnalytics.activeProposals}`);

    // Get treasury dashboard
    const dashboard = await treasury.getTreasuryDashboard();
    console.log(`\n✅ Treasury Dashboard:`);
    console.log(`   Current ETH Balance: ${ethers.formatEther(dashboard.currentETHBalance)} ETH`);
    console.log(`   Current Token Balance: ${ethers.formatEther(dashboard.currentTokenBalance)} KARMA`);
    console.log(`   Pending Withdrawals: ${dashboard.pendingWithdrawals}`);
    console.log(`   Active Distributions: ${dashboard.activeDistributions}`);
    console.log(`   External Contracts: ${dashboard.externalContractsCount}`);

    // Export transaction history
    console.log("\n📜 Exporting Transaction History...");
    const fromTimestamp = 0;
    const toTimestamp = Math.floor(Date.now() / 1000) + 3600;
    
    await treasury.exportTransactionHistory(fromTimestamp, toTimestamp, "");
    console.log(`✅ Transaction history exported for period: ${fromTimestamp} to ${toTimestamp}`);

    // Final summary
    console.log("\n" + "=".repeat(80));
    console.log("🎉 Stage 4.2 Treasury System Deployment Complete!");
    console.log("=".repeat(80));

    const finalMetrics = await treasury.getTreasuryMetrics();
    const finalBalance = await treasury.getBalance();
    const finalTokenBalance = await karmaToken.balanceOf(treasuryAddress);
    
    console.log("\n📋 Final Treasury State:");
    console.log(`Treasury Contract: ${treasuryAddress}`);
    console.log(`KarmaToken: ${await karmaToken.getAddress()}`);
    console.log(`VestingVault: ${await vestingVault.getAddress()}`);
    console.log(`SaleManager: ${await saleManager.getAddress()}`);

    console.log("\n💰 Final Balances:");
    console.log(`ETH Balance: ${ethers.formatEther(finalBalance)} ETH`);
    console.log(`KARMA Balance: ${ethers.formatEther(finalTokenBalance)} KARMA`);
    console.log(`Total Received: ${ethers.formatEther(finalMetrics.totalReceived)} ETH`);
    console.log(`Total Distributed: ${ethers.formatEther(finalMetrics.totalDistributed)} ETH`);

    console.log("\n✅ Stage 4.2 Features Successfully Demonstrated:");
    console.log("  🎯 Token Distribution System:");
    console.log("    - Community Rewards (200M KARMA allocation)");
    console.log("    - Airdrop for Early Testers (20M KARMA allocation)");
    console.log("    - Staking Rewards (100M KARMA over 2 years)");
    console.log("    - Engagement Incentives (80M KARMA over 2 years)");
    
    console.log("  🔗 External Contract Integration:");
    console.log("    - Paymaster funding mechanisms ($100K ETH initial allocation)");
    console.log("    - BuybackBurn funding system (20% of treasury allocations)");
    console.log("    - Automated funding triggers based on contract balances");
    console.log("    - External contract balance monitoring and alerting");
    
    console.log("  🏛️  Transparency and Governance:");
    console.log("    - Comprehensive transaction logging and event emission");
    console.log("    - Enhanced monthly treasury reports");
    console.log("    - Governance proposal funding mechanisms");
    console.log("    - Public fund tracking and analytics endpoints");

    console.log("\n🚀 Stage 4.2 Advanced Treasury Features Ready for Production!");
    
    return {
        treasury: treasuryAddress,
        karmaToken: await karmaToken.getAddress(),
        vestingVault: await vestingVault.getAddress(),
        saleManager: await saleManager.getAddress(),
        finalBalance: ethers.formatEther(finalBalance),
        finalTokenBalance: ethers.formatEther(finalTokenBalance)
    };
}

main()
    .then((result) => {
        console.log("\n✅ Deployment completed successfully!");
        console.log("📊 Results:", result);
        process.exit(0);
    })
    .catch((error) => {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    }); 