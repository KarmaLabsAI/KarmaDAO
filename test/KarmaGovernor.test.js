const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("KarmaGovernor - Stage 7.1", function () {
    let karmaToken, karmaStaking, karmaGovernor, timelock;
    let admin, proposer, voter1, voter2;

    beforeEach(async function () {
        [admin, proposer, voter1, voter2] = await ethers.getSigners();

        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);

        // Deploy KarmaStaking
        const KarmaStaking = await ethers.getContractFactory("KarmaStaking");
        karmaStaking = await KarmaStaking.deploy(
            await karmaToken.getAddress(),
            admin.address, // treasury placeholder
            admin.address
        );

        // Deploy TimelockController
        const TimelockController = await ethers.getContractFactory("TimelockController");
        timelock = await TimelockController.deploy(
            3 * 24 * 3600, // 3 days
            [admin.address],
            [admin.address],
            admin.address
        );

        // Deploy KarmaGovernor
        const KarmaGovernor = await ethers.getContractFactory("KarmaGovernor");
        karmaGovernor = await KarmaGovernor.deploy(
            await karmaToken.getAddress(),
            await timelock.getAddress(),
            await karmaStaking.getAddress(),
            admin.address
        );
    });

    describe("Deployment", function () {
        it("Should deploy successfully", async function () {
            expect(await karmaGovernor.token()).to.equal(await karmaToken.getAddress());
            expect(await karmaGovernor.stakingContract()).to.equal(await karmaStaking.getAddress());
        });

        it("Should have correct initial configuration", async function () {
            const config = await karmaGovernor.getGovernanceConfig();
            expect(config.quadraticVotingEnabled).to.be.true;
            expect(config.proposalThreshold).to.be.gt(0);
        });
    });

    describe("Basic Functionality", function () {
        it("Should allow staking tokens", async function () {
            await karmaToken.connect(admin).mint(proposer.address, ethers.parseEther("2000000"));
            await karmaToken.connect(proposer).approve(await karmaStaking.getAddress(), ethers.parseEther("1500000"));
            
            await expect(karmaStaking.connect(proposer).stake(ethers.parseEther("1500000"), 0))
                .to.emit(karmaStaking, "Staked");
        });

        it("Should calculate voting power", async function () {
            await karmaToken.connect(admin).mint(voter1.address, ethers.parseEther("5000000"));
            await karmaToken.connect(voter1).approve(await karmaStaking.getAddress(), ethers.parseEther("4000000"));
            await karmaStaking.connect(voter1).stake(ethers.parseEther("4000000"), 1);

            const votingPower = await karmaGovernor.getQuadraticVotingPower(
                voter1.address,
                await ethers.provider.getBlockNumber()
            );
            expect(votingPower).to.be.gt(0);
        });
    });
}); 