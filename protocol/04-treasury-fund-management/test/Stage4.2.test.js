/**
 * @title Stage 4.2 Test Suite - Advanced Treasury Features
 * @dev Test suite for Advanced Treasury Features development stage
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 4.2: Advanced Treasury Features", function () {
    let treasury, karmaToken;
    let deployer, admin, multisigManager, user1, user2;

    beforeEach(async function () {
        [deployer, admin, multisigManager, user1, user2] = await ethers.getSigners();

        // Deploy KarmaToken for token distribution testing
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(
            "Karma Token",
            "KARMA",
            admin.address
        );
        await karmaToken.waitForDeployment();

        // Deploy Treasury contract
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            admin.address,
            multisigManager.address,
            ethers.parseEther("10000")
        );
        await treasury.waitForDeployment();

        // Fund the treasury
        await deployer.sendTransaction({
            to: await treasury.getAddress(),
            value: ethers.parseEther("10000")
        });

        // Mint KARMA tokens to treasury for distribution
        await karmaToken.connect(admin).mint(
            await treasury.getAddress(),
            ethers.parseEther("200000000") // 200M KARMA
        );
    });

    describe("Token Distribution System", function () {
        it("Should distribute KARMA tokens for community rewards", async function () {
            const rewardAmount = ethers.parseEther("1000");
            
            await expect(
                treasury.connect(admin).distributeTokenRewards(
                    [user1.address],
                    [rewardAmount],
                    "Community rewards"
                )
            ).to.emit(treasury, "TokenRewardsDistributed");
        });

        it("Should handle airdrop distribution", async function () {
            const airdropAmount = ethers.parseEther("100");
            
            await expect(
                treasury.connect(admin).executeAirdrop(
                    [user1.address],
                    [airdropAmount]
                )
            ).to.emit(treasury, "AirdropExecuted");
        });
    });

    describe("External Contract Integration", function () {
        it("Should fund Paymaster contract", async function () {
            const fundingAmount = ethers.parseEther("100");
            
            await expect(
                treasury.connect(admin).fundPaymaster(
                    user1.address,
                    fundingAmount
                )
            ).to.emit(treasury, "PaymasterFunded");
        });

        it("Should fund BuybackBurn contract", async function () {
            const fundingAmount = ethers.parseEther("2000");
            
            await expect(
                treasury.connect(admin).fundBuybackBurn(
                    user1.address,
                    fundingAmount
                )
            ).to.emit(treasury, "BuybackFunded");
        });
    });

    describe("Transparency and Governance", function () {
        it("Should generate monthly reports", async function () {
            const report = await treasury.generateMonthlyReport();
            expect(report.totalBalance).to.be.gt(0);
        });

        it("Should support governance proposal funding", async function () {
            const fundingAmount = ethers.parseEther("500");
            
            await expect(
                treasury.connect(admin).fundGovernanceProposal(
                    1,
                    fundingAmount,
                    user1.address,
                    "Proposal funding"
                )
            ).to.emit(treasury, "GovernanceProposalFunded");
        });
    });
}); 