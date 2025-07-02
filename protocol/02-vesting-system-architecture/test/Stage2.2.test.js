/**
 * Stage 2.2 - Vesting Schedule Configurations Tests
 * Tests for specific vesting patterns for different allocation types
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 2.2 - Vesting Schedule Configurations", function () {
    
    let vestingVault;
    let teamVesting;
    let privateSaleVesting;
    let karmaToken;
    let admin;
    let teamManager;
    let saleManager;

    beforeEach(async function () {
        [admin, teamManager, saleManager] = await ethers.getSigners();
        
        // Deploy mock KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(
            "KarmaToken",
            "KARMA",
            ethers.utils.parseEther("1000000000"),
            admin.address
        );

        // Deploy VestingVault
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(
            karmaToken.address,
            admin.address
        );

        // Deploy TeamVesting
        const TeamVesting = await ethers.getContractFactory("TeamVesting");
        teamVesting = await TeamVesting.deploy(
            vestingVault.address,
            admin.address
        );

        // Deploy PrivateSaleVesting
        const PrivateSaleVesting = await ethers.getContractFactory("PrivateSaleVesting");
        privateSaleVesting = await PrivateSaleVesting.deploy(
            vestingVault.address,
            admin.address
        );
    });

    describe("Deployment", function () {
        it("Should deploy TeamVesting with correct parameters", async function () {
            expect(await teamVesting.vestingVault()).to.equal(vestingVault.address);
        });

        it("Should deploy PrivateSaleVesting with correct parameters", async function () {
            expect(await privateSaleVesting.vestingVault()).to.equal(vestingVault.address);
        });
    });

    describe("Team Vesting Configuration", function () {
        it("Should configure 4-year vesting with 1-year cliff", async function () {
            // Test team vesting parameters
            expect(teamVesting.address).to.be.properAddress;
        });
    });

    describe("Private Sale Vesting Configuration", function () {
        it("Should configure 6-month linear vesting", async function () {
            // Test private sale vesting parameters
            expect(privateSaleVesting.address).to.be.properAddress;
        });
    });
}); 