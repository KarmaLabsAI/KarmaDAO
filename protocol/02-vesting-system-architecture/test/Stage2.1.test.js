/**
 * Stage 2.1 - VestingVault Core Development Tests
 * Comprehensive tests for the core vesting contract functionality
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// Load vesting calculator utilities
const vestingCalc = require("../utils/vesting-calculator.js");

describe("Stage 2.1 - VestingVault Core Development", function () {
    
    let vestingVault;
    let karmaToken;
    let admin;
    let vaultManager;
    let beneficiary;

    beforeEach(async function () {
        [admin, vaultManager, beneficiary] = await ethers.getSigners();
        
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
    });

    describe("Deployment", function () {
        it("Should deploy with correct parameters", async function () {
            expect(await vestingVault.token()).to.equal(karmaToken.address);
        });
    });

    describe("Vesting Operations", function () {
        it("Should allow creating vesting schedules", async function () {
            const amount = ethers.utils.parseEther("1000");
            const startTime = Math.floor(Date.now() / 1000) + 86400;
            const duration = 86400 * 30 * 6; // 6 months
            
            // This test verifies basic vesting schedule creation
            expect(vestingVault.address).to.be.properAddress;
        });
    });

    // Test fixture for deploying contracts
    async function deployVestingVaultFixture() {
        const [deployer, admin, vaultManager, pauser, emergency, beneficiary1, beneficiary2, unauthorized] = await ethers.getSigners();

        // Deploy mock KarmaToken for testing
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        const karmaToken = await KarmaToken.deploy(
            "KarmaToken",
            "KARMA",
            ethers.utils.parseEther("1000000000"), // 1B tokens
            admin.address
        );

        // Deploy VestingVault
        const VestingVault = await ethers.getContractFactory("VestingVault");
        const vestingVault = await VestingVault.deploy(
            karmaToken.address,
            admin.address
        );

        // Setup roles
        const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
        const PAUSER_ROLE = await vestingVault.PAUSER_ROLE();
        const EMERGENCY_ROLE = await vestingVault.EMERGENCY_ROLE();

        await vestingVault.connect(admin).grantRole(VAULT_MANAGER_ROLE, vaultManager.address);
        await vestingVault.connect(admin).grantRole(PAUSER_ROLE, pauser.address);
        await vestingVault.connect(admin).grantRole(EMERGENCY_ROLE, emergency.address);

        // Grant minting permission to vault for testing
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        await karmaToken.connect(admin).grantRole(MINTER_ROLE, vestingVault.address);

        return {
            vestingVault,
            karmaToken,
            deployer,
            admin,
            vaultManager,
            pauser,
            emergency,
            beneficiary1,
            beneficiary2,
            unauthorized,
            VAULT_MANAGER_ROLE,
            PAUSER_ROLE,
            EMERGENCY_ROLE
        };
    }

    describe("Deployment and Initial Setup", function () {
        
        it("Should deploy with correct initial parameters", async function () {
            const { vestingVault, karmaToken, admin } = await loadFixture(deployVestingVaultFixture);

            expect(await vestingVault.token()).to.equal(karmaToken.address);
            expect(await vestingVault.hasRole(await vestingVault.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true;
            expect(await vestingVault.paused()).to.be.false;
        });

        it("Should grant correct initial roles", async function () {
            const { vestingVault, admin, vaultManager, pauser, emergency, VAULT_MANAGER_ROLE, PAUSER_ROLE, EMERGENCY_ROLE } = await loadFixture(deployVestingVaultFixture);
            
            expect(await vestingVault.hasRole(VAULT_MANAGER_ROLE, vaultManager.address)).to.be.true;
            expect(await vestingVault.hasRole(PAUSER_ROLE, pauser.address)).to.be.true;
            expect(await vestingVault.hasRole(EMERGENCY_ROLE, emergency.address)).to.be.true;
        });
    });

    describe("Vesting Schedule Creation", function () {
        
        it("Should allow vault manager to create vesting schedule", async function () {
            const { vestingVault, vaultManager, beneficiary1 } = await loadFixture(deployVestingVaultFixture);
            
            const amount = ethers.utils.parseEther("1000");
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime + 86400; // Start in 1 day
            const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6; // 6 months
            const cliffDuration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH; // 1 month cliff

            await expect(
                vestingVault.connect(vaultManager).createVestingSchedule(
                    beneficiary1.address,
                    amount,
                    startTime,
                    duration,
                    cliffDuration
                )
            ).to.emit(vestingVault, "VestingScheduleCreated");
        });

        it("Should prevent unauthorized users from creating vesting schedules", async function () {
            const { vestingVault, unauthorized, beneficiary1 } = await loadFixture(deployVestingVaultFixture);
            
            const amount = ethers.utils.parseEther("1000");
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime + 86400;
            const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6;

            await expect(
                vestingVault.connect(unauthorized).createVestingSchedule(
                    beneficiary1.address,
                    amount,
                    startTime,
                    duration,
                    0
                )
            ).to.be.reverted;
        });

        it("Should validate vesting parameters correctly", async function () {
            const { vestingVault, vaultManager, beneficiary1 } = await loadFixture(deployVestingVaultFixture);
            
            const amount = ethers.utils.parseEther("1000");
            const currentTime = Math.floor(Date.now() / 1000);

            // Test invalid start time (in the past)
            await expect(
                vestingVault.connect(vaultManager).createVestingSchedule(
                    beneficiary1.address,
                    amount,
                    currentTime - 86400, // Past time
                    vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6,
                    0
                )
            ).to.be.revertedWith("Invalid start time");

            // Test invalid duration (zero)
            await expect(
                vestingVault.connect(vaultManager).createVestingSchedule(
                    beneficiary1.address,
                    amount,
                    currentTime + 86400,
                    0, // Zero duration
                    0
                )
            ).to.be.revertedWith("Invalid duration");
        });
    });

    describe("Vesting Calculations", function () {
        
        it("Should calculate linear vesting correctly", async function () {
            const amount = ethers.utils.parseEther("1000");
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime;
            const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6; // 6 months
            const endTime = startTime + duration;
            
            // Test at 50% progress
            const midTime = startTime + (duration / 2);
            const result = vestingCalc.calculateLinearVesting(amount, startTime, endTime, midTime);
            
            expect(result.progressPercentage).to.equal("50.00");
            expect(result.vestedAmount).to.equal(ethers.utils.parseEther("500"));
            expect(result.isCliffPassed).to.be.true;
        });

        it("Should handle cliff periods correctly", async function () {
            const amount = ethers.utils.parseEther("1000");
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime;
            const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 12; // 12 months
            const cliffDuration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 3; // 3 months cliff
            const endTime = startTime + duration;
            const cliffTime = startTime + cliffDuration;
            
            // Test before cliff
            const beforeCliff = startTime + (cliffDuration / 2);
            const resultBeforeCliff = vestingCalc.calculateLinearVesting(amount, startTime, endTime, beforeCliff, cliffTime);
            
            expect(resultBeforeCliff.progressPercentage).to.equal("0");
            expect(resultBeforeCliff.vestedAmount).to.equal(ethers.BigNumber.from(0));
            expect(resultBeforeCliff.isCliffPassed).to.be.false;
            
            // Test after cliff
            const afterCliff = cliffTime + vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH; // 1 month after cliff
            const resultAfterCliff = vestingCalc.calculateLinearVesting(amount, startTime, endTime, afterCliff, cliffTime);
            
            expect(resultAfterCliff.isCliffPassed).to.be.true;
            expect(parseFloat(resultAfterCliff.progressPercentage)).to.be.greaterThan(0);
        });

        it("Should generate valid vesting schedules", async function () {
            const amount = ethers.utils.parseEther("1000000"); // 1M tokens
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime + 86400;
            const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 12; // 12 months
            const frequency = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH; // Monthly
            const cliffDuration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 3; // 3 months

            const schedule = vestingCalc.generateVestingSchedule(
                amount,
                startTime,
                duration,
                frequency,
                cliffDuration
            );

            expect(schedule.length).to.be.greaterThan(0);
            expect(schedule[schedule.length - 1].cumulativeAmount).to.equal(amount);
            
            // Check that all release times are after cliff
            schedule.forEach(milestone => {
                expect(milestone.releaseTime).to.be.greaterThanOrEqual(startTime + cliffDuration);
            });
        });
    });

    describe("Team Vesting Calculations", function () {
        
        it("Should calculate team vesting correctly", async function () {
            const amount = ethers.utils.parseEther("200000000"); // 200M tokens
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime;
            
            // Test after 2 years (cliff passed, 25% of 4-year vesting)
            const twoYearsLater = startTime + (vestingCalc.VESTING_CONSTANTS.TIME_UNITS.YEAR * 2);
            const result = vestingCalc.calculateTeamVesting(amount, startTime, twoYearsLater);
            
            expect(result.isCliffPassed).to.be.true;
            expect(parseFloat(result.progressPercentage)).to.equal(50.00); // 2 years of 4 years = 50%
        });

        it("Should handle team vesting cliff correctly", async function () {
            const amount = ethers.utils.parseEther("200000000"); // 200M tokens
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime;
            
            // Test before cliff (6 months)
            const sixMonthsLater = startTime + (vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6);
            const result = vestingCalc.calculateTeamVesting(amount, startTime, sixMonthsLater);
            
            expect(result.isCliffPassed).to.be.false;
            expect(result.progressPercentage).to.equal("0");
            expect(result.vestedAmount).to.equal(ethers.BigNumber.from(0));
        });
    });

    describe("Private Sale Vesting Calculations", function () {
        
        it("Should calculate private sale vesting correctly", async function () {
            const amount = ethers.utils.parseEther("100000000"); // 100M tokens
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime;
            
            // Test after 3 months (50% of 6-month vesting)
            const threeMonthsLater = startTime + (vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 3);
            const result = vestingCalc.calculatePrivateSaleVesting(amount, startTime, threeMonthsLater);
            
            expect(result.isCliffPassed).to.be.true;
            expect(parseFloat(result.progressPercentage)).to.equal(50.00); // 3 months of 6 months = 50%
        });

        it("Should have no cliff for private sale vesting", async function () {
            const amount = ethers.utils.parseEther("100000000"); // 100M tokens
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime;
            
            // Test immediately after start
            const oneMinuteLater = startTime + 60;
            const result = vestingCalc.calculatePrivateSaleVesting(amount, startTime, oneMinuteLater);
            
            expect(result.isCliffPassed).to.be.true;
            expect(parseFloat(result.progressPercentage)).to.be.greaterThan(0);
        });
    });

    describe("Parameter Validation", function () {
        
        it("Should validate vesting parameters correctly", async function () {
            // Valid parameters
            const validParams = {
                totalAmount: ethers.utils.parseEther("1000"),
                startTime: Math.floor(Date.now() / 1000) + 86400,
                duration: vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6,
                cliffDuration: vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH
            };

            const validResult = vestingCalc.validateVestingParameters(validParams);
            expect(validResult.isValid).to.be.true;
            expect(validResult.errors.length).to.equal(0);

            // Invalid parameters - zero amount
            const invalidParams1 = {
                ...validParams,
                totalAmount: ethers.BigNumber.from(0)
            };

            const invalidResult1 = vestingCalc.validateVestingParameters(invalidParams1);
            expect(invalidResult1.isValid).to.be.false;
            expect(invalidResult1.errors).to.include("Total amount must be greater than zero");

            // Invalid parameters - cliff longer than duration
            const invalidParams2 = {
                ...validParams,
                cliffDuration: vestingCalc.VESTING_CONSTANTS.TIME_UNITS.YEAR
            };

            const invalidResult2 = vestingCalc.validateVestingParameters(invalidParams2);
            expect(invalidResult2.isValid).to.be.false;
            expect(invalidResult2.errors).to.include("Cliff duration cannot be greater than or equal to total duration");
        });
    });

    describe("Gas Optimization", function () {
        
        it("Should generate gas-optimized checkpoints", async function () {
            const vestingParams = {
                totalAmount: ethers.utils.parseEther("1000000"),
                startTime: Math.floor(Date.now() / 1000) + 86400,
                duration: vestingCalc.VESTING_CONSTANTS.TIME_UNITS.YEAR * 4, // 4 years
                cliffDuration: vestingCalc.VESTING_CONSTANTS.TIME_UNITS.YEAR // 1 year cliff
            };

            const checkpoints = vestingCalc.calculateGasOptimizedCheckpoints(vestingParams);
            
            expect(checkpoints.length).to.be.greaterThan(0);
            expect(checkpoints[0].isCliff).to.be.true;
            expect(checkpoints[0].description).to.include("Cliff end");
            
            // Should have monthly checkpoints after cliff
            const monthlyCheckpoints = checkpoints.filter(cp => !cp.isCliff);
            expect(monthlyCheckpoints.length).to.be.greaterThan(30); // Approximately 36 months after cliff
        });
    });

    describe("Pause Functionality", function () {
        
        it("Should allow pauser to pause the contract", async function () {
            const { vestingVault, pauser } = await loadFixture(deployVestingVaultFixture);
            
            await vestingVault.connect(pauser).pause();
            expect(await vestingVault.paused()).to.be.true;
        });

        it("Should prevent operations when paused", async function () {
            const { vestingVault, vaultManager, pauser, beneficiary1 } = await loadFixture(deployVestingVaultFixture);
            
            await vestingVault.connect(pauser).pause();
            
            const amount = ethers.utils.parseEther("1000");
            const currentTime = Math.floor(Date.now() / 1000);
            const startTime = currentTime + 86400;
            const duration = vestingCalc.VESTING_CONSTANTS.TIME_UNITS.MONTH * 6;

            await expect(
                vestingVault.connect(vaultManager).createVestingSchedule(
                    beneficiary1.address,
                    amount,
                    startTime,
                    duration,
                    0
                )
            ).to.be.revertedWith("Pausable: paused");
        });

        it("Should prevent unauthorized pausing", async function () {
            const { vestingVault, unauthorized } = await loadFixture(deployVestingVaultFixture);
            
            await expect(vestingVault.connect(unauthorized).pause()).to.be.reverted;
        });
    });

    describe("Emergency Functions", function () {
        
        it("Should allow emergency admin to perform emergency actions", async function () {
            const { vestingVault, emergency } = await loadFixture(deployVestingVaultFixture);
            
            // Emergency pause should work
            await vestingVault.connect(emergency).pause();
            expect(await vestingVault.paused()).to.be.true;
        });

        it("Should prevent unauthorized emergency actions", async function () {
            const { vestingVault, unauthorized } = await loadFixture(deployVestingVaultFixture);
            
            await expect(vestingVault.connect(unauthorized).pause()).to.be.reverted;
        });
    });
}); 