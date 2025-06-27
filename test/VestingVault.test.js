const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("VestingVault", function () {
    let VestingVault, vestingVault;
    let KarmaToken, karmaToken;
    let admin, vestingManager, emergency, user1, user2, user3;
    
    const TOKENS_18_DECIMALS = ethers.parseEther("1");
    const INITIAL_SUPPLY = ethers.parseEther("1000000000"); // 1 billion tokens
    
    // Time constants
    const ONE_DAY = 24 * 60 * 60;
    const ONE_MONTH = 30 * ONE_DAY;
    const ONE_YEAR = 365 * ONE_DAY;
    
    // Role constants
    const VESTING_MANAGER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("VESTING_MANAGER_ROLE"));
    const EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));
    
    beforeEach(async function () {
        [admin, vestingManager, emergency, user1, user2, user3] = await ethers.getSigners();
        
        // Deploy KarmaToken
        KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();
        
        // Deploy VestingVault
        VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress(), admin.address);
        await vestingVault.waitForDeployment();
        
        // Grant roles
        await vestingVault.connect(admin).grantRole(VESTING_MANAGER_ROLE, vestingManager.address);
        await vestingVault.connect(admin).grantRole(EMERGENCY_ROLE, emergency.address);
        
        // Mint tokens to admin and fund the vesting vault
        await karmaToken.connect(admin).mint(admin.address, INITIAL_SUPPLY);
        await karmaToken.connect(admin).approve(await vestingVault.getAddress(), INITIAL_SUPPLY);
        await vestingVault.connect(admin).fundContract(ethers.parseEther("100000000")); // 100M tokens
    });
    
    describe("Deployment", function () {
        it("Should set the correct token address", async function () {
            expect(await vestingVault.vestingToken()).to.equal(await karmaToken.getAddress());
        });
        
        it("Should grant correct roles to admin", async function () {
            expect(await vestingVault.hasRole(await vestingVault.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true;
            expect(await vestingVault.hasRole(VESTING_MANAGER_ROLE, admin.address)).to.be.true;
            expect(await vestingVault.hasRole(EMERGENCY_ROLE, admin.address)).to.be.true;
        });
        
        it("Should start with empty schedules", async function () {
            const stats = await vestingVault.getContractStats();
            expect(stats[0]).to.equal(0); // totalSchedules
            expect(stats[1]).to.equal(0); // totalVesting
            expect(stats[2]).to.equal(0); // totalClaimed
        });
    });
    
    describe("Vesting Schedule Creation", function () {
        const vestingAmount = ethers.parseEther("10000");
        const cliffDuration = ONE_MONTH * 12; // 12 months
        const vestingDuration = ONE_YEAR * 4; // 4 years
        let startTime;
        
        beforeEach(async function () {
            const currentTime = await time.latest();
            startTime = currentTime + ONE_DAY; // Start tomorrow
        });
        
        it("Should create a vesting schedule", async function () {
            const tx = await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                vestingAmount,
                startTime,
                cliffDuration,
                vestingDuration,
                "TEAM"
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => 
                log.topics[0] === vestingVault.interface.getEvent("VestingScheduleCreated").topicHash
            );
            
            expect(event).to.not.be.undefined;
            
            // Check schedule was created
            const schedule = await vestingVault.getVestingSchedule(1);
            expect(schedule.beneficiary).to.equal(user1.address);
            expect(schedule.totalAmount).to.equal(vestingAmount);
            expect(schedule.startTime).to.equal(startTime);
            expect(schedule.cliffDuration).to.equal(cliffDuration);
            expect(schedule.vestingDuration).to.equal(vestingDuration);
            expect(schedule.scheduleType).to.equal("TEAM");
            expect(schedule.revoked).to.be.false;
        });
        
        it("Should create multiple schedules in batch", async function () {
            const beneficiaries = [user1.address, user2.address, user3.address];
            const amounts = [ethers.parseEther("5000"), ethers.parseEther("3000"), ethers.parseEther("2000")];
            const startTimes = [startTime, startTime + ONE_DAY, startTime + ONE_DAY * 2];
            const cliffs = [cliffDuration, 0, ONE_MONTH * 6];
            const durations = [vestingDuration, ONE_YEAR, ONE_YEAR * 2];
            const types = ["TEAM", "PRIVATE_SALE", "ADVISOR"];
            
            const scheduleIds = await vestingVault.connect(vestingManager).createVestingSchedulesBatch(
                beneficiaries,
                amounts,
                startTimes,
                cliffs,
                durations,
                types
            );
            
            // Verify all schedules were created
            for (let i = 0; i < beneficiaries.length; i++) {
                const schedule = await vestingVault.getVestingSchedule(i + 1);
                expect(schedule.beneficiary).to.equal(beneficiaries[i]);
                expect(schedule.totalAmount).to.equal(amounts[i]);
                expect(schedule.scheduleType).to.equal(types[i]);
            }
        });
        
        it("Should track beneficiary schedules", async function () {
            // Create multiple schedules for user1
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address, vestingAmount, startTime, cliffDuration, vestingDuration, "TEAM"
            );
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address, ethers.parseEther("5000"), startTime, 0, ONE_YEAR, "BONUS"
            );
            
            const schedules = await vestingVault.getBeneficiarySchedules(user1.address);
            expect(schedules.length).to.equal(2);
            expect(schedules[0]).to.equal(1);
            expect(schedules[1]).to.equal(2);
        });
        
        it("Should revert with invalid parameters", async function () {
            // Invalid beneficiary
            await expect(
                vestingVault.connect(vestingManager).createVestingSchedule(
                    ethers.ZeroAddress, vestingAmount, startTime, cliffDuration, vestingDuration, "TEAM"
                )
            ).to.be.revertedWith("VestingVault: invalid beneficiary");
            
            // Zero amount
            await expect(
                vestingVault.connect(vestingManager).createVestingSchedule(
                    user1.address, 0, startTime, cliffDuration, vestingDuration, "TEAM"
                )
            ).to.be.revertedWith("VestingVault: amount must be positive");
            
            // Cliff exceeds vesting duration
            await expect(
                vestingVault.connect(vestingManager).createVestingSchedule(
                    user1.address, vestingAmount, startTime, vestingDuration + 1, vestingDuration, "TEAM"
                )
            ).to.be.revertedWith("VestingVault: cliff cannot exceed vesting duration");
        });
        
        it("Should require vesting manager role", async function () {
            await expect(
                vestingVault.connect(user1).createVestingSchedule(
                    user1.address, vestingAmount, startTime, cliffDuration, vestingDuration, "TEAM"
                )
            ).to.be.revertedWith("VestingVault: caller is not vesting manager");
        });
    });
    
    describe("Vesting Logic and Calculations", function () {
        let scheduleId;
        const vestingAmount = ethers.parseEther("12000"); // 12,000 tokens
        const cliffDuration = ONE_YEAR; // 1 year cliff
        const vestingDuration = ONE_YEAR * 4; // 4 years total
        let startTime;
        
        beforeEach(async function () {
            const currentTime = await time.latest();
            startTime = currentTime + ONE_DAY;
            
            // Create a vesting schedule
            const tx = await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                vestingAmount,
                startTime,
                cliffDuration,
                vestingDuration,
                "TEAM"
            );
            scheduleId = 1;
        });
        
        it("Should return zero vested amount before start time", async function () {
            const vestedAmount = await vestingVault.getVestedAmount(scheduleId);
            expect(vestedAmount).to.equal(0);
        });
        
        it("Should return zero vested amount during cliff period", async function () {
            // Move to start time
            await time.increaseTo(startTime);
            expect(await vestingVault.getVestedAmount(scheduleId)).to.equal(0);
            
            // Move to just before cliff ends
            await time.increaseTo(startTime + cliffDuration - 100);
            expect(await vestingVault.getVestedAmount(scheduleId)).to.equal(0);
        });
        
        it("Should return correct vested amount after cliff", async function () {
            // Move to exactly after cliff
            await time.increaseTo(startTime + cliffDuration);
            const vestedAmount = await vestingVault.getVestedAmount(scheduleId);
            
            // After 1/4 of total time (cliff duration), 1/4 should be vested
            const expectedVested = vestingAmount / 4n;
            expect(vestedAmount).to.equal(expectedVested);
        });
        
        it("Should return linear vesting amounts", async function () {
            // Test at various points during vesting
            const timePoints = [
                startTime + ONE_YEAR,        // 25% (cliff)
                startTime + ONE_YEAR * 2,    // 50%
                startTime + ONE_YEAR * 3,    // 75%
                startTime + ONE_YEAR * 4     // 100%
            ];
            
            const expectedPercentages = [25n, 50n, 75n, 100n];
            
            for (let i = 0; i < timePoints.length; i++) {
                await time.increaseTo(timePoints[i]);
                const vestedAmount = await vestingVault.getVestedAmount(scheduleId);
                const expectedAmount = (vestingAmount * expectedPercentages[i]) / 100n;
                expect(vestedAmount).to.equal(expectedAmount);
            }
        });
        
        it("Should return full amount when fully vested", async function () {
            await time.increaseTo(startTime + vestingDuration + ONE_DAY);
            const vestedAmount = await vestingVault.getVestedAmount(scheduleId);
            expect(vestedAmount).to.equal(vestingAmount);
        });
        
        it("Should calculate vesting progress correctly", async function () {
            await time.increaseTo(startTime + ONE_YEAR * 2); // 50% through
            const progress = await vestingVault.getVestingProgress(scheduleId);
            expect(progress).to.equal(5000); // 50.00% in basis points
        });
        
        it("Should check cliff status correctly", async function () {
            expect(await vestingVault.isCliffReached(scheduleId)).to.be.false;
            
            await time.increaseTo(startTime + cliffDuration);
            expect(await vestingVault.isCliffReached(scheduleId)).to.be.true;
        });
    });
    
    describe("Token Claiming", function () {
        let scheduleId;
        const vestingAmount = ethers.parseEther("12000");
        const cliffDuration = ONE_MONTH * 6; // 6 months
        const vestingDuration = ONE_YEAR * 2; // 2 years
        let startTime;
        
        beforeEach(async function () {
            const currentTime = await time.latest();
            startTime = currentTime + ONE_DAY;
            
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                vestingAmount,
                startTime,
                cliffDuration,
                vestingDuration,
                "PRIVATE_SALE"
            );
            scheduleId = 1;
        });
        
        it("Should allow claiming after tokens become available", async function () {
            // Move to 50% vested
            await time.increaseTo(startTime + ONE_YEAR);
            
            const claimableAmount = await vestingVault.getClaimableAmount(scheduleId);
            const expectedClaimable = vestingAmount / 2n; // 50%
            expect(claimableAmount).to.equal(expectedClaimable);
            
            const initialBalance = await karmaToken.balanceOf(user1.address);
            
            await vestingVault.connect(user1).claimTokens(scheduleId);
            
            const finalBalance = await karmaToken.balanceOf(user1.address);
            expect(finalBalance - initialBalance).to.equal(expectedClaimable);
            
            // Check schedule updated
            const schedule = await vestingVault.getVestingSchedule(scheduleId);
            expect(schedule.claimedAmount).to.equal(expectedClaimable);
        });
        
        it("Should prevent double claiming", async function () {
            await time.increaseTo(startTime + ONE_YEAR);
            
            // First claim
            await vestingVault.connect(user1).claimTokens(scheduleId);
            
            // Second claim should fail
            await expect(
                vestingVault.connect(user1).claimTokens(scheduleId)
            ).to.be.revertedWith("VestingVault: no tokens available to claim");
        });
        
        it("Should allow partial claims over time", async function () {
            // Claim at 50%
            await time.increaseTo(startTime + ONE_YEAR);
            await vestingVault.connect(user1).claimTokens(scheduleId);
            
            const balanceAfterFirst = await karmaToken.balanceOf(user1.address);
            
            // Move to 75% and claim again
            await time.increaseTo(startTime + ONE_YEAR + ONE_MONTH * 6);
            await vestingVault.connect(user1).claimTokens(scheduleId);
            
            const balanceAfterSecond = await karmaToken.balanceOf(user1.address);
            const additionalClaimed = balanceAfterSecond - balanceAfterFirst;
            
            // Should have claimed approximately 25% more
            const expectedAdditional = vestingAmount / 4n;
            expect(additionalClaimed).to.be.closeTo(expectedAdditional, ethers.parseEther("100"));
        });
        
        it("Should support batch claiming", async function () {
            // Create another schedule
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                ethers.parseEther("6000"),
                startTime,
                0, // No cliff
                ONE_YEAR,
                "BONUS"
            );
            
            await time.increaseTo(startTime + ONE_YEAR);
            
            const scheduleIds = [1, 2];
            const initialBalance = await karmaToken.balanceOf(user1.address);
            
            await vestingVault.connect(user1).claimTokensBatch(scheduleIds);
            
            const finalBalance = await karmaToken.balanceOf(user1.address);
            const totalClaimed = finalBalance - initialBalance;
            
            // Should claim from both schedules
            expect(totalClaimed).to.be.gt(0);
        });
        
        it("Should support claiming all available tokens", async function () {
            // Create multiple schedules
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                ethers.parseEther("3000"),
                startTime,
                0,
                ONE_YEAR,
                "BONUS"
            );
            
            await time.increaseTo(startTime + ONE_YEAR);
            
            const initialBalance = await karmaToken.balanceOf(user1.address);
            await vestingVault.connect(user1).claimAllAvailable();
            const finalBalance = await karmaToken.balanceOf(user1.address);
            
            expect(finalBalance).to.be.gt(initialBalance);
        });
        
        it("Should only allow beneficiary to claim", async function () {
            await time.increaseTo(startTime + ONE_YEAR);
            
            await expect(
                vestingVault.connect(user2).claimTokens(scheduleId)
            ).to.be.revertedWith("VestingVault: caller is not beneficiary");
        });
    });
    
    describe("Admin Functions", function () {
        let scheduleId;
        const vestingAmount = ethers.parseEther("10000");
        let startTime;
        
        beforeEach(async function () {
            const currentTime = await time.latest();
            startTime = currentTime + ONE_DAY;
            
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                vestingAmount,
                startTime,
                ONE_MONTH * 6,
                ONE_YEAR * 2,
                "TEAM"
            );
            scheduleId = 1;
        });
        
        it("Should allow schedule revocation", async function () {
            await time.increaseTo(startTime + ONE_YEAR); // 50% vested
            
            const vestedBefore = await vestingVault.getVestedAmount(scheduleId);
            const unvestedBefore = vestingAmount - vestedBefore;
            
            await vestingVault.connect(vestingManager).revokeSchedule(scheduleId);
            
            const schedule = await vestingVault.getVestingSchedule(scheduleId);
            expect(schedule.revoked).to.be.true;
            expect(schedule.totalAmount).to.equal(vestedBefore);
        });
        
        it("Should allow partial revocation", async function () {
            await time.increaseTo(startTime + ONE_YEAR); // 50% vested
            
            const revokeAmount = ethers.parseEther("2000");
            await vestingVault.connect(vestingManager).partialRevokeSchedule(scheduleId, revokeAmount);
            
            const schedule = await vestingVault.getVestingSchedule(scheduleId);
            expect(schedule.totalAmount).to.equal(vestingAmount - revokeAmount);
        });
        
        it("Should allow schedule modification", async function () {
            const newAmount = ethers.parseEther("8000");
            const newDuration = ONE_YEAR * 3;
            
            await vestingVault.connect(vestingManager).modifySchedule(scheduleId, newAmount, newDuration);
            
            const schedule = await vestingVault.getVestingSchedule(scheduleId);
            expect(schedule.totalAmount).to.equal(newAmount);
            expect(schedule.vestingDuration).to.equal(newDuration);
        });
        
        it("Should require vesting manager role for admin functions", async function () {
            await expect(
                vestingVault.connect(user1).revokeSchedule(scheduleId)
            ).to.be.revertedWith("VestingVault: caller is not vesting manager");
        });
    });
    
    describe("Emergency Controls", function () {
        it("Should allow emergency pause", async function () {
            await vestingVault.connect(emergency).emergencyPause();
            expect(await vestingVault.paused()).to.be.true;
        });
        
        it("Should prevent operations when paused", async function () {
            await vestingVault.connect(emergency).emergencyPause();
            
            const currentTime = await time.latest();
            
            await expect(
                vestingVault.connect(vestingManager).createVestingSchedule(
                    user1.address,
                    ethers.parseEther("1000"),
                    currentTime + ONE_DAY,
                    0,
                    ONE_YEAR,
                    "TEST"
                )
            ).to.be.revertedWith("Pausable: paused");
        });
        
        it("Should allow emergency unpause", async function () {
            await vestingVault.connect(emergency).emergencyPause();
            await vestingVault.connect(emergency).emergencyUnpause();
            expect(await vestingVault.paused()).to.be.false;
        });
        
        it("Should require emergency role for emergency functions", async function () {
            await expect(
                vestingVault.connect(user1).emergencyPause()
            ).to.be.revertedWith("VestingVault: caller is not emergency role");
        });
    });
    
    describe("View Functions and Analytics", function () {
        beforeEach(async function () {
            const currentTime = await time.latest();
            const startTime = currentTime + ONE_DAY;
            
            // Create multiple schedules
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                ethers.parseEther("10000"),
                startTime,
                ONE_MONTH * 6,
                ONE_YEAR * 2,
                "TEAM"
            );
            
            await vestingVault.connect(vestingManager).createVestingSchedule(
                user1.address,
                ethers.parseEther("5000"),
                startTime,
                0,
                ONE_YEAR,
                "BONUS"
            );
        });
        
        it("Should return correct beneficiary totals", async function () {
            const currentTime = await time.latest();
            await time.increaseTo(currentTime + ONE_DAY + ONE_YEAR);
            
            const totalVested = await vestingVault.getBeneficiaryVestedAmount(user1.address);
            const totalClaimable = await vestingVault.getBeneficiaryClaimableAmount(user1.address);
            
            expect(totalVested).to.be.gt(0);
            expect(totalClaimable).to.be.gt(0);
        });
        
        it("Should return correct contract statistics", async function () {
            const stats = await vestingVault.getContractStats();
            expect(stats[0]).to.equal(2); // totalSchedules
            expect(stats[1]).to.equal(ethers.parseEther("15000")); // totalVesting
            expect(stats[2]).to.equal(0); // totalClaimed
        });
        
        it("Should return next unlock times", async function () {
            const nextUnlock = await vestingVault.getNextUnlockTime(1);
            expect(nextUnlock).to.be.gt(0);
        });
    });
}); 