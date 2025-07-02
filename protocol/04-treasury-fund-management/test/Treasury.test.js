const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Treasury Contract - Stage 4.1 & 4.2", function () {
    let treasury, karmaToken, saleManager;
    let admin, treasuryManager, approver1, approver2, approver3, user1, user2, paymasterContract, buybackBurnContract;
    let AllocationCategory, TokenDistributionType, ExternalContractType;

    beforeEach(async function () {
        // Get signers
        [admin, treasuryManager, approver1, approver2, approver3, user1, user2, paymasterContract, buybackBurnContract] = await ethers.getSigners();

        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();

        // Deploy Treasury with approvers
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            admin.address,
            admin.address, // Using admin as sale manager for testing
            [approver1.address, approver2.address, approver3.address],
            2 // 2-of-3 multisig threshold
        );
        await treasury.waitForDeployment();

        // Set KarmaToken in Treasury
        await treasury.connect(admin).setKarmaToken(await karmaToken.getAddress());

        // Grant minting role to Treasury for token distributions
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        await karmaToken.connect(admin).grantRole(MINTER_ROLE, await treasury.getAddress());

        // Define allocation categories enum for testing
        AllocationCategory = {
            MARKETING: 0,
            KOL: 1,
            DEVELOPMENT: 2,
            BUYBACK: 3
        };

        // Define token distribution types for Stage 4.2
        TokenDistributionType = {
            COMMUNITY_REWARDS: 0,
            AIRDROP: 1,
            STAKING_REWARDS: 2,
            ENGAGEMENT_INCENTIVE: 3
        };

        // Define external contract types for Stage 4.2
        ExternalContractType = {
            PAYMASTER: 0,
            BUYBACK_BURN: 1,
            GOVERNANCE_DAO: 2,
            STAKING_CONTRACT: 3
        };

        // Fund treasury for testing
        await treasury.receiveETH(AllocationCategory.DEVELOPMENT, "Initial funding", { value: ethers.parseEther("100") });
        
        // Mint tokens to treasury for distribution testing
        await karmaToken.connect(admin).mint(await treasury.getAddress(), ethers.parseEther("1000000")); // 1M tokens
    });

    // ============ STAGE 4.1 TESTS (EXISTING) ============

    describe("Deployment and Initialization", function () {
        it("Should deploy with correct configuration", async function () {
            expect(await treasury.multisigThreshold()).to.equal(2);
            expect(await treasury.saleManager()).to.equal(admin.address);
            expect(await treasury.isApprover(approver1.address)).to.be.true;
            expect(await treasury.isApprover(approver2.address)).to.be.true;
            expect(await treasury.isApprover(approver3.address)).to.be.true;
        });

        it("Should have default allocation configuration", async function () {
            const config = await treasury.allocationConfig();
            expect(config.marketingPercentage).to.equal(3000); // 30%
            expect(config.kolPercentage).to.equal(2000); // 20%
            expect(config.developmentPercentage).to.equal(3000); // 30%
            expect(config.buybackPercentage).to.equal(2000); // 20%
        });
    });

    // ============ STAGE 4.2: TOKEN DISTRIBUTION SYSTEM TESTS ============

    describe("Stage 4.2: Token Distribution System", function () {
        describe("Token Distribution Configuration", function () {
            it("Should configure community rewards distribution", async function () {
                const totalAllocation = ethers.parseEther("200000000"); // 200M tokens
                
                await expect(treasury.connect(admin).configureTokenDistribution(
                    TokenDistributionType.COMMUNITY_REWARDS,
                    totalAllocation,
                    0, // no vesting
                    0  // no cliff
                )).to.emit(treasury, "TokenDistributionConfigured")
                  .withArgs(TokenDistributionType.COMMUNITY_REWARDS, totalAllocation);

                const config = await treasury.getTokenDistributionConfig(TokenDistributionType.COMMUNITY_REWARDS);
                expect(config.totalAllocation).to.equal(totalAllocation);
                expect(config.isActive).to.be.true;
                expect(config.vestingDuration).to.equal(0);
            });

            it("Should configure staking rewards with 2-year distribution", async function () {
                const totalRewards = ethers.parseEther("100000000"); // 100M tokens
                const distributionPeriod = 2 * 365 * 24 * 3600; // 2 years
                
                await expect(treasury.connect(admin).configureStakingRewards(
                    totalRewards,
                    distributionPeriod
                )).to.emit(treasury, "StakingRewardsConfigured")
                  .withArgs(totalRewards, distributionPeriod);

                const stakingRewards = await treasury.stakingRewards();
                expect(stakingRewards.totalRewards).to.equal(totalRewards);
                expect(stakingRewards.distributionPeriod).to.equal(distributionPeriod);
                expect(stakingRewards.rewardsPerSecond).to.equal(totalRewards / BigInt(distributionPeriod));
            });

            it("Should configure engagement incentives", async function () {
                const totalIncentive = ethers.parseEther("80000000"); // 80M tokens
                const distributionPeriod = 2 * 365 * 24 * 3600; // 2 years
                const baseRewardRate = ethers.parseEther("1000"); // 1000 tokens per point
                
                await expect(treasury.connect(admin).configureEngagementIncentives(
                    totalIncentive,
                    distributionPeriod,
                    baseRewardRate
                )).to.emit(treasury, "EngagementIncentivesConfigured")
                  .withArgs(totalIncentive, distributionPeriod);

                const incentives = await treasury.engagementIncentives();
                expect(incentives.totalIncentive).to.equal(totalIncentive);
                expect(incentives.distributionPeriod).to.equal(distributionPeriod);
                expect(incentives.baseRewardRate).to.equal(baseRewardRate);
            });
        });

        describe("Community Rewards Distribution", function () {
            beforeEach(async function () {
                // Configure community rewards
                await treasury.connect(admin).configureTokenDistribution(
                    TokenDistributionType.COMMUNITY_REWARDS,
                    ethers.parseEther("200000000"),
                    0,
                    0
                );
            });

            it("Should distribute community rewards to multiple recipients", async function () {
                const recipients = [user1.address, user2.address];
                const amounts = [ethers.parseEther("1000"), ethers.parseEther("2000")];
                const totalAmount = ethers.parseEther("3000");
                
                const user1BalanceBefore = await karmaToken.balanceOf(user1.address);
                const user2BalanceBefore = await karmaToken.balanceOf(user2.address);
                
                await expect(treasury.connect(admin).distributeCommunityRewards(
                    recipients,
                    amounts,
                    "Q1 Community Rewards"
                )).to.emit(treasury, "CommunityRewardsDistributed")
                  .withArgs(recipients, amounts, totalAmount);

                expect(await karmaToken.balanceOf(user1.address)).to.equal(user1BalanceBefore + amounts[0]);
                expect(await karmaToken.balanceOf(user2.address)).to.equal(user2BalanceBefore + amounts[1]);

                const config = await treasury.getTokenDistributionConfig(TokenDistributionType.COMMUNITY_REWARDS);
                expect(config.distributedAmount).to.equal(totalAmount);
            });

            it("Should prevent exceeding allocation limit", async function () {
                const recipients = [user1.address];
                const amounts = [ethers.parseEther("200000001")]; // Exceeds 200M limit
                
                await expect(treasury.connect(admin).distributeCommunityRewards(
                    recipients,
                    amounts,
                    "Exceeds limit"
                )).to.be.revertedWith("Treasury: exceeds allocation");
            });
        });

        describe("Airdrop Distribution", function () {
            beforeEach(async function () {
                // Configure airdrop
                await treasury.connect(admin).configureTokenDistribution(
                    TokenDistributionType.AIRDROP,
                    ethers.parseEther("20000000"),
                    0,
                    0
                );
            });

            it("Should execute airdrop for early testers", async function () {
                const recipients = [user1.address, user2.address];
                const amounts = [ethers.parseEther("500"), ethers.parseEther("1500")];
                const totalTokens = ethers.parseEther("2000");
                const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test_merkle_root"));
                
                const user1BalanceBefore = await karmaToken.balanceOf(user1.address);
                
                await expect(treasury.connect(admin).executeAirdrop(
                    recipients,
                    amounts,
                    merkleRoot
                )).to.emit(treasury, "AirdropExecuted")
                  .withArgs(1, recipients, totalTokens);

                expect(await karmaToken.balanceOf(user1.address)).to.equal(user1BalanceBefore + amounts[0]);
                
                const config = await treasury.getTokenDistributionConfig(TokenDistributionType.AIRDROP);
                expect(config.distributedAmount).to.equal(totalTokens);
            });
        });

        describe("Staking Rewards Distribution", function () {
            beforeEach(async function () {
                // Configure staking rewards
                await treasury.connect(admin).configureStakingRewards(
                    ethers.parseEther("100000000"),
                    2 * 365 * 24 * 3600
                );
            });

            it("Should distribute staking rewards to staking contract", async function () {
                const stakingContract = user1.address; // Mock staking contract
                const amount = ethers.parseEther("10000");
                
                const contractBalanceBefore = await karmaToken.balanceOf(stakingContract);
                
                await expect(treasury.connect(admin).distributeStakingRewards(
                    stakingContract,
                    amount
                )).to.emit(treasury, "StakingRewardsDistributed")
                  .withArgs(stakingContract, amount);

                expect(await karmaToken.balanceOf(stakingContract)).to.equal(contractBalanceBefore + amount);
                
                const rewards = await treasury.stakingRewards();
                expect(rewards.distributedAmount).to.equal(amount);
            });

            it("Should prevent exceeding staking allocation", async function () {
                const stakingContract = user1.address;
                const amount = ethers.parseEther("100000001"); // Exceeds 100M limit
                
                await expect(treasury.connect(admin).distributeStakingRewards(
                    stakingContract,
                    amount
                )).to.be.revertedWith("Treasury: exceeds allocation");
            });
        });

        describe("Engagement Incentives Distribution", function () {
            beforeEach(async function () {
                // Configure engagement incentives
                await treasury.connect(admin).configureEngagementIncentives(
                    ethers.parseEther("80000000"),
                    2 * 365 * 24 * 3600,
                    ethers.parseEther("1000")
                );
            });

            it("Should distribute engagement incentives based on points", async function () {
                const users = [user1.address, user2.address];
                const engagementPoints = [50, 150]; // user2 gets bonus for high engagement
                
                const user1BalanceBefore = await karmaToken.balanceOf(user1.address);
                const user2BalanceBefore = await karmaToken.balanceOf(user2.address);
                
                await expect(treasury.connect(admin).distributeEngagementIncentives(
                    users,
                    engagementPoints
                )).to.emit(treasury, "EngagementIncentivesDistributed");

                // user1: 50 * 1000 = 50,000 tokens
                // user2: 150 * 1000 * 1.5 (bonus) = 225,000 tokens
                expect(await karmaToken.balanceOf(user1.address)).to.equal(
                    user1BalanceBefore + ethers.parseEther("50000")
                );
                expect(await karmaToken.balanceOf(user2.address)).to.equal(
                    user2BalanceBefore + ethers.parseEther("225000")
                );
            });
        });
    });

    // ============ STAGE 4.2: EXTERNAL CONTRACT INTEGRATION TESTS ============

    describe("Stage 4.2: External Contract Integration", function () {
        describe("External Contract Configuration", function () {
            it("Should configure Paymaster contract", async function () {
                const fundingAmount = ethers.parseEther("10"); // 10 ETH
                const fundingFrequency = 7 * 24 * 3600; // Weekly
                const minimumBalance = ethers.parseEther("1");
                
                await expect(treasury.connect(admin).configureExternalContract(
                    paymasterContract.address,
                    ExternalContractType.PAYMASTER,
                    fundingAmount,
                    fundingFrequency,
                    minimumBalance
                )).to.emit(treasury, "ExternalContractConfigured")
                  .withArgs(paymasterContract.address, ExternalContractType.PAYMASTER);

                const config = await treasury.getExternalContractConfig(paymasterContract.address);
                expect(config.contractAddress).to.equal(paymasterContract.address);
                expect(config.contractType).to.equal(ExternalContractType.PAYMASTER);
                expect(config.fundingAmount).to.equal(fundingAmount);
                expect(config.autoFundingEnabled).to.be.true;
            });

            it("Should configure BuybackBurn contract", async function () {
                const fundingAmount = ethers.parseEther("5");
                const fundingFrequency = 30 * 24 * 3600; // Monthly
                const minimumBalance = ethers.parseEther("0.5");
                
                await treasury.connect(admin).configureExternalContract(
                    buybackBurnContract.address,
                    ExternalContractType.BUYBACK_BURN,
                    fundingAmount,
                    fundingFrequency,
                    minimumBalance
                );

                const config = await treasury.getExternalContractConfig(buybackBurnContract.address);
                expect(config.fundingAmount).to.equal(fundingAmount);
                expect(config.minimumBalance).to.equal(minimumBalance);
            });
        });

        describe("Paymaster Funding", function () {
            it("Should fund Paymaster contract with ETH", async function () {
                const fundingAmount = ethers.parseEther("10");
                const initialBalance = await ethers.provider.getBalance(paymasterContract.address);
                
                await expect(treasury.connect(admin).fundPaymaster(
                    paymasterContract.address,
                    fundingAmount
                )).to.emit(treasury, "PaymasterFunded")
                  .withArgs(paymasterContract.address, fundingAmount);

                const finalBalance = await ethers.provider.getBalance(paymasterContract.address);
                expect(finalBalance - initialBalance).to.equal(fundingAmount);
            });

            it("Should prevent funding with insufficient treasury balance", async function () {
                const excessiveAmount = ethers.parseEther("1000"); // More than treasury has
                
                await expect(treasury.connect(admin).fundPaymaster(
                    paymasterContract.address,
                    excessiveAmount
                )).to.be.revertedWith("Treasury: insufficient balance");
            });
        });

        describe("BuybackBurn Funding", function () {
            it("Should fund BuybackBurn from buyback allocation", async function () {
                const fundingAmount = ethers.parseEther("5");
                const initialBalance = await ethers.provider.getBalance(buybackBurnContract.address);
                
                await expect(treasury.connect(admin).fundBuybackBurn(
                    buybackBurnContract.address,
                    fundingAmount
                )).to.emit(treasury, "BuybackBurnFunded")
                  .withArgs(buybackBurnContract.address, fundingAmount);

                const finalBalance = await ethers.provider.getBalance(buybackBurnContract.address);
                expect(finalBalance - initialBalance).to.equal(fundingAmount);
                
                // Check that buyback allocation was reduced
                const allocation = await treasury.getCategoryAllocation(AllocationCategory.BUYBACK);
                expect(allocation.totalSpent).to.equal(fundingAmount);
            });

            it("Should prevent exceeding buyback allocation", async function () {
                const allocation = await treasury.getCategoryAllocation(AllocationCategory.BUYBACK);
                const excessiveAmount = allocation.available + ethers.parseEther("1");
                
                await expect(treasury.connect(admin).fundBuybackBurn(
                    buybackBurnContract.address,
                    excessiveAmount
                )).to.be.revertedWith("Treasury: exceeds buyback allocation");
            });
        });

        describe("Automatic Funding Trigger", function () {
            beforeEach(async function () {
                // Configure contracts for automatic funding
                await treasury.connect(admin).configureExternalContract(
                    paymasterContract.address,
                    ExternalContractType.PAYMASTER,
                    ethers.parseEther("1"),
                    3600, // 1 hour frequency
                    ethers.parseEther("0.5")
                );
            });

            it("Should trigger automatic funding for configured contracts", async function () {
                await expect(treasury.connect(admin).triggerAutomaticFunding())
                    .to.emit(treasury, "AutomaticFundingTriggered");
            });

            it("Should monitor external contract balances", async function () {
                const [currentBalance, belowThreshold] = await treasury.monitorExternalBalance(paymasterContract.address);
                expect(currentBalance).to.equal(await ethers.provider.getBalance(paymasterContract.address));
                expect(belowThreshold).to.be.a('boolean');
            });
        });
    });

    // ============ STAGE 4.2: TRANSPARENCY AND GOVERNANCE TESTS ============

    describe("Stage 4.2: Transparency and Governance", function () {
        describe("Governance Proposals", function () {
            it("Should create governance proposal for treasury funding", async function () {
                const title = "Website Development";
                const description = "Funding for new website development";
                const requestedAmount = ethers.parseEther("10");
                const votingPeriod = 7 * 24 * 3600; // 7 days
                
                await expect(treasury.connect(admin).createGovernanceProposal(
                    title,
                    description,
                    requestedAmount,
                    AllocationCategory.MARKETING,
                    votingPeriod
                )).to.emit(treasury, "GovernanceProposalCreated")
                  .withArgs(1, admin.address, requestedAmount);
            });

            it("Should prevent empty proposals", async function () {
                await expect(treasury.connect(admin).createGovernanceProposal(
                    "",
                    "description",
                    ethers.parseEther("10"),
                    AllocationCategory.MARKETING,
                    7 * 24 * 3600
                )).to.be.revertedWith("Treasury: empty title");
            });
        });

        describe("Enhanced Reporting", function () {
            it("Should provide detailed monthly report", async function () {
                const currentYear = new Date().getFullYear();
                const currentMonth = new Date().getMonth() + 1;
                
                const report = await treasury.getDetailedMonthlyReport(currentMonth, currentYear);
                expect(report.totalReceived).to.be.a('bigint');
                expect(report.categoryBreakdown).to.be.an('array');
                expect(report.categoryBreakdown.length).to.equal(4);
            });

            it("Should provide public analytics", async function () {
                const analytics = await treasury.getPublicAnalytics();
                expect(analytics.totalTreasuryValue).to.equal(await treasury.getBalance());
                expect(analytics.allocationPercentages).to.be.an('array');
                expect(analytics.allocationPercentages.length).to.equal(4);
                expect(analytics.tokensDistributed).to.be.a('bigint');
            });

            it("Should export transaction history with filtering", async function () {
                const fromTimestamp = 0;
                const toTimestamp = Math.floor(Date.now() / 1000) + 3600;
                const transactionType = "";
                
                await expect(treasury.exportTransactionHistory(
                    fromTimestamp,
                    toTimestamp,
                    transactionType
                )).to.emit(treasury, "TransactionHistoryExported");
            });

            it("Should provide treasury dashboard data", async function () {
                const dashboard = await treasury.getTreasuryDashboard();
                expect(dashboard.currentETHBalance).to.equal(await treasury.getBalance());
                expect(dashboard.allocationStatus).to.be.an('array');
                expect(dashboard.allocationStatus.length).to.equal(4);
                expect(dashboard.pendingWithdrawals).to.be.a('bigint');
                expect(dashboard.activeDistributions).to.be.a('bigint');
            });
        });
    });

    // ============ ACCESS CONTROL TESTS ============

    describe("Stage 4.2: Access Control", function () {
        it("Should restrict token distribution to authorized roles", async function () {
            await expect(treasury.connect(user1).distributeCommunityRewards(
                [user2.address],
                [ethers.parseEther("1000")],
                "Unauthorized distribution"
            )).to.be.revertedWith("Treasury: caller is not token distributor");
        });

        it("Should restrict external funding to authorized roles", async function () {
            await expect(treasury.connect(user1).fundPaymaster(
                paymasterContract.address,
                ethers.parseEther("1")
            )).to.be.revertedWith("Treasury: caller is not external funder");
        });

        it("Should restrict governance functions to authorized roles", async function () {
            await expect(treasury.connect(user1).createGovernanceProposal(
                "Unauthorized Proposal",
                "This should fail",
                ethers.parseEther("1"),
                AllocationCategory.MARKETING,
                7 * 24 * 3600
            )).to.be.revertedWith("Treasury: caller does not have governance role");
        });
    });

    // ============ INTEGRATION TESTS ============

    describe("Stage 4.2: Integration Tests", function () {
        it("Should handle complete token distribution workflow", async function () {
            // Configure all distribution types
            await treasury.connect(admin).configureTokenDistribution(
                TokenDistributionType.COMMUNITY_REWARDS,
                ethers.parseEther("200000000"),
                0, 0
            );

            // Distribute community rewards
            await treasury.connect(admin).distributeCommunityRewards(
                [user1.address],
                [ethers.parseEther("10000")],
                "Integration test"
            );

            // Execute airdrop
            const airdropId = await treasury.connect(admin).executeAirdrop.staticCall(
                [user2.address],
                [ethers.parseEther("5000")],
                ethers.keccak256(ethers.toUtf8Bytes("test"))
            );

            await treasury.connect(admin).executeAirdrop(
                [user2.address],
                [ethers.parseEther("5000")],
                ethers.keccak256(ethers.toUtf8Bytes("test"))
            );

            // Verify distributions
            expect(await karmaToken.balanceOf(user1.address)).to.equal(ethers.parseEther("10000"));
            expect(await karmaToken.balanceOf(user2.address)).to.equal(ethers.parseEther("5000"));
            
            // Check total distributed
            const analytics = await treasury.getPublicAnalytics();
            expect(analytics.tokensDistributed).to.equal(ethers.parseEther("15000"));
        });

        it("Should handle complete external funding workflow", async function () {
            // Configure external contracts
            await treasury.connect(admin).configureExternalContract(
                paymasterContract.address,
                ExternalContractType.PAYMASTER,
                ethers.parseEther("5"),
                3600,
                ethers.parseEther("1")
            );

            // Fund Paymaster
            await treasury.connect(admin).fundPaymaster(
                paymasterContract.address,
                ethers.parseEther("10")
            );

            // Fund BuybackBurn
            await treasury.connect(admin).fundBuybackBurn(
                buybackBurnContract.address,
                ethers.parseEther("5")
            );

            // Check balances
            expect(await ethers.provider.getBalance(paymasterContract.address))
                .to.equal(ethers.parseEther("10"));
            expect(await ethers.provider.getBalance(buybackBurnContract.address))
                .to.equal(ethers.parseEther("5"));

            // Trigger automatic funding
            await treasury.connect(admin).triggerAutomaticFunding();
        });
    });
}); 