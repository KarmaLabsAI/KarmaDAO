const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 7.2 - Advanced Governance Features", function () {
    let owner, treasury, user1, user2, user3, maliciousUser;
    let karmaToken, karmaStaking;
    let treasuryGovernance, protocolUpgradeGovernance, decentralizationManager;
    
    const INITIAL_SUPPLY = ethers.utils.parseEther("1000000000"); // 1B tokens
    const STAKE_AMOUNT = ethers.utils.parseEther("100000"); // 100K tokens
    
    beforeEach(async function () {
        [owner, treasury, user1, user2, user3, maliciousUser] = await ethers.getSigners();
        
        // Deploy mock KarmaToken for testing
        const ERC20Mock = await ethers.getContractFactory("contracts/mocks/ERC20Mock.sol:ERC20Mock");
        karmaToken = await ERC20Mock.deploy("Karma Token", "KARMA", INITIAL_SUPPLY);
        
        // Deploy and setup contracts for Stage 7.2
        await deployStage72Contracts();
        
        // Setup initial state
        await setupInitialState();
    });
    
    async function deployStage72Contracts() {
        // Deploy KarmaStaking with enhanced features
        const KarmaStaking = await ethers.getContractFactory("KarmaStaking");
        karmaStaking = await KarmaStaking.deploy(
            karmaToken.address,
            owner.address, // governance
            treasury.address,
            owner.address // admin
        );
        
        // Deploy TreasuryGovernance
        const TreasuryGovernance = await ethers.getContractFactory("TreasuryGovernance");
        treasuryGovernance = await TreasuryGovernance.deploy(
            owner.address, // karmaGovernor (mock)
            treasury.address,
            karmaToken.address,
            owner.address // admin
        );
        
        // Deploy ProtocolUpgradeGovernance
        const ProtocolUpgradeGovernance = await ethers.getContractFactory("ProtocolUpgradeGovernance");
        protocolUpgradeGovernance = await ProtocolUpgradeGovernance.deploy(
            owner.address, // karmaGovernor (mock)
            karmaToken.address,
            karmaStaking.address,
            owner.address // admin
        );
        
        // Deploy DecentralizationManager
        const DecentralizationManager = await ethers.getContractFactory("DecentralizationManager");
        decentralizationManager = await DecentralizationManager.deploy(
            owner.address, // karmaGovernor (mock)
            karmaStaking.address,
            treasury.address,
            protocolUpgradeGovernance.address,
            owner.address // admin
        );
    }
    
    async function setupInitialState() {
        // Transfer tokens to users
        await karmaToken.transfer(user1.address, STAKE_AMOUNT);
        await karmaToken.transfer(user2.address, STAKE_AMOUNT);
        await karmaToken.transfer(user3.address, STAKE_AMOUNT);
        await karmaToken.transfer(maliciousUser.address, STAKE_AMOUNT);
        
        // Initialize Stage 7.2 features
        await karmaStaking.initializeStage72Features(owner.address);
        
        // Approve staking contracts
        await karmaToken.connect(user1).approve(karmaStaking.address, STAKE_AMOUNT);
        await karmaToken.connect(user2).approve(karmaStaking.address, STAKE_AMOUNT);
        await karmaToken.connect(user3).approve(karmaStaking.address, STAKE_AMOUNT);
        
        // Set up initial stakes for users
        await karmaStaking.connect(user1).stakeTokens(
            ethers.utils.parseEther("50000"), // 50K - Bronze tier
            1, // 30 days lock
            "Initial stake for user1"
        );
        
        await karmaStaking.connect(user2).stakeTokens(
            ethers.utils.parseEther("100000"), // 100K - Gold tier  
            2, // 90 days lock
            "Initial stake for user2"
        );
        
        await karmaStaking.connect(user3).stakeTokens(
            ethers.utils.parseEther("25000"), // 25K - Bronze tier
            0, // Flexible
            "Initial stake for user3"
        );
    }
    
    describe("Enhanced Staking and Tiers", function () {
        it("Should correctly assign staking tiers based on stake amount", async function () {
            const user1Tier = await karmaStaking.getUserTier(user1.address);
            const user2Tier = await karmaStaking.getUserTier(user2.address);
            const user3Tier = await karmaStaking.getUserTier(user3.address);
            
            expect(user1Tier).to.equal(1); // Bronze tier
            expect(user2Tier).to.equal(3); // Gold tier
            expect(user3Tier).to.equal(1); // Bronze tier
        });
        
        it("Should upgrade user tier when stake increases", async function () {
            // User3 starts with Bronze tier
            expect(await karmaStaking.getUserTier(user3.address)).to.equal(1);
            
            // Stake more tokens to reach Silver tier
            await karmaToken.transfer(user3.address, ethers.utils.parseEther("30000"));
            await karmaToken.connect(user3).approve(karmaStaking.address, ethers.utils.parseEther("30000"));
            
            await karmaStaking.connect(user3).stakeTokens(
                ethers.utils.parseEther("30000"),
                1,
                "Upgrade to Silver tier"
            );
            
            // Should now be Silver tier
            expect(await karmaStaking.getUserTier(user3.address)).to.equal(2);
        });
    });
    
    describe("Governance Rewards System", function () {
        it("Should reward users for governance participation", async function () {
            // Update governance participation for user1
            await karmaStaking.updateGovernanceParticipation(
                user1.address,
                1, // proposals created
                5, // proposals voted
                ethers.utils.parseEther("1000"), // vote weight
                8500 // reputation score
            );
            
            // Reward for creating a proposal
            await karmaStaking.rewardGovernanceParticipation(
                user1.address,
                "proposal",
                9000 // high quality score
            );
            
            // Check that rewards were earned
            const unclaimedRewards = await karmaStaking.getUnclaimedGovernanceRewards(user1.address);
            expect(unclaimedRewards).to.be.gt(0);
        });
        
        it("Should allow users to claim governance rewards", async function () {
            // Setup and earn rewards
            await karmaStaking.updateGovernanceParticipation(user1.address, 1, 5, ethers.utils.parseEther("1000"), 8500);
            await karmaStaking.rewardGovernanceParticipation(user1.address, "proposal", 9000);
            
            const rewardsBefore = await karmaStaking.getUnclaimedGovernanceRewards(user1.address);
            expect(rewardsBefore).to.be.gt(0);
            
            // Claim rewards
            await karmaStaking.connect(user1).claimGovernanceRewards();
            
            // Rewards should be reset
            const rewardsAfter = await karmaStaking.getUnclaimedGovernanceRewards(user1.address);
            expect(rewardsAfter).to.equal(0);
        });
    });
    
    describe("Slashing Mechanisms", function () {
        it("Should slash users for malicious behavior", async function () {
            // First stake some tokens
            await karmaToken.connect(maliciousUser).approve(karmaStaking.address, STAKE_AMOUNT);
            await karmaStaking.connect(maliciousUser).stakeTokens(
                ethers.utils.parseEther("50000"),
                1,
                "Malicious user stake"
            );
            
            // Slash the user for malicious proposal
            await karmaStaking.slashUser(
                maliciousUser.address,
                0, // MALICIOUS_PROPOSAL
                1000, // 10% penalty
                "Created proposal to drain treasury"
            );
            
            // User should be marked as slashed
            expect(await karmaStaking.isUserSlashed(maliciousUser.address)).to.be.true;
        });
        
        it("Should allow users to appeal slashing", async function () {
            // First stake and slash user
            await karmaToken.connect(maliciousUser).approve(karmaStaking.address, STAKE_AMOUNT);
            await karmaStaking.connect(maliciousUser).stakeTokens(ethers.utils.parseEther("50000"), 1, "Test stake");
            
            await karmaStaking.slashUser(maliciousUser.address, 0, 1000, "Test slashing");
            
            // Appeal the slashing
            await karmaStaking.connect(maliciousUser).appealSlashing(1, "This was a mistake");
            
            // Should be able to appeal
            const slashingRecord = await karmaStaking.getSlashingRecord(1);
            expect(slashingRecord.slashedUser).to.equal(maliciousUser.address);
        });
    });
    
    describe("Treasury Governance Integration", function () {
        it("Should create treasury spending proposals", async function () {
            await treasuryGovernance.createTreasuryProposal(
                0, // GENERAL_SPENDING
                0, // MARKETING category
                ethers.utils.parseEther("100000"), // 100K KARMA
                user1.address, // recipient
                "Marketing campaign funding"
            );
            
            // Check proposal was created
            const proposal = await treasuryGovernance.getTreasuryProposal(1);
            expect(proposal.amount).to.equal(ethers.utils.parseEther("100000"));
            expect(proposal.recipient).to.equal(user1.address);
        });
        
        it("Should distribute community funds", async function () {
            // Set treasury value first
            await treasuryGovernance.updateTreasuryValue(ethers.utils.parseEther("1000000"));
            
            await treasuryGovernance.distributeCommunityFunds(
                user1.address,
                ethers.utils.parseEther("10000"),
                "Community development grant"
            );
            
            const communityFund = await treasuryGovernance.getCommunityFund();
            expect(communityFund.distributedAmount).to.equal(ethers.utils.parseEther("10000"));
        });
    });
    
    describe("Protocol Upgrade Governance", function () {
        it("Should create upgrade proposals", async function () {
            // Register a contract first
            await protocolUpgradeGovernance.registerContract(
                karmaToken.address,
                0, // CORE_TOKEN category
                "KarmaToken",
                true, // upgradeable
                ethers.constants.AddressZero, // no proxy admin
                karmaToken.address // implementation
            );
            
            await protocolUpgradeGovernance.createUpgradeProposal(
                1, // MINOR_UPGRADE
                0, // CORE_TOKEN category
                karmaToken.address, // target
                user1.address, // new implementation (mock)
                "0x", // upgrade data
                "Bug fix for token contract",
                "Fixed overflow vulnerability in transfer function"
            );
            
            const proposal = await protocolUpgradeGovernance.getUpgradeProposal(1);
            expect(proposal.targetContract).to.equal(karmaToken.address);
        });
        
        it("Should propose parameter changes", async function () {
            // Register contract first
            await protocolUpgradeGovernance.registerContract(
                karmaStaking.address,
                3, // STAKING category
                "KarmaStaking",
                false, // not upgradeable for this test
                ethers.constants.AddressZero,
                karmaStaking.address
            );
            
            await protocolUpgradeGovernance.proposeParameterChange(
                karmaStaking.address,
                "baseAPY",
                ethers.utils.formatBytes32String("1000"), // new value
                "Increase base APY to attract more stakers",
                75 // impact assessment
            );
            
            const parameterChange = await protocolUpgradeGovernance.getParameterChange(1);
            expect(parameterChange.parameterName).to.equal("baseAPY");
        });
    });
    
    describe("Progressive Decentralization", function () {
        it("Should initiate decentralization process", async function () {
            await decentralizationManager.initiateDecentralization();
            
            const status = await decentralizationManager.getDecentralizationStatus();
            expect(status.startTime).to.be.gt(0);
        });
        
        it("Should schedule control transitions", async function () {
            await decentralizationManager.scheduleControlTransition(
                0, // TREASURY_CONTROL
                owner.address, // from team
                user1.address, // to community representative
                2500, // 25% transfer
                Math.floor(Date.now() / 1000) + 86400, // tomorrow
                true, // requires community approval
                "Initial treasury control transfer"
            );
            
            const transition = await decentralizationManager.getControlTransition(1);
            expect(transition.transferAmount).to.equal(2500);
        });
        
        it("Should track governance metrics", async function () {
            await decentralizationManager.updateGovernanceMetrics(
                10, // total proposals
                7,  // community proposals
                100, // total votes
                25   // unique voters
            );
            
            const metrics = await decentralizationManager.getGovernanceMetrics();
            expect(metrics.totalProposals).to.equal(10);
            expect(metrics.communityProposals).to.equal(7);
        });
    });
}); 