const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Treasury Contract - Stage 4.1", function () {
    let treasury, karmaToken, saleManager;
    let admin, treasuryManager, approver1, approver2, approver3, user1, user2;
    let AllocationCategory;

    beforeEach(async function () {
        // Get signers
        [admin, treasuryManager, approver1, approver2, approver3, user1, user2] = await ethers.getSigners();

        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();

        // Deploy mock SaleManager (simplified for testing)
        const MockSaleManager = await ethers.getContractFactory("SaleManager");
        // Note: We'll use admin as sale manager for testing purposes
        
        // Deploy Treasury with approvers
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            admin.address,
            admin.address, // Using admin as sale manager for testing
            [approver1.address, approver2.address, approver3.address],
            2 // 2-of-3 multisig threshold
        );
        await treasury.waitForDeployment();

        // Define allocation categories enum for testing
        AllocationCategory = {
            MARKETING: 0,
            KOL: 1,
            DEVELOPMENT: 2,
            BUYBACK: 3
        };
    });

    describe("Deployment and Initialization", function () {
        it("Should deploy with correct initial configuration", async function () {
            expect(await treasury.saleManager()).to.equal(admin.address);
            expect(await treasury.multisigThreshold()).to.equal(2);
            expect(await treasury.largeWithdrawalThresholdBps()).to.equal(1000); // 10%
            
            // Check allocation config
            const config = await treasury.allocationConfig();
            expect(config.marketingPercentage).to.equal(3000); // 30%
            expect(config.kolPercentage).to.equal(2000); // 20%
            expect(config.developmentPercentage).to.equal(3000); // 30%
            expect(config.buybackPercentage).to.equal(2000); // 20%
        });

        it("Should setup roles correctly", async function () {
            const TREASURY_MANAGER_ROLE = await treasury.TREASURY_MANAGER_ROLE();
            const WITHDRAWAL_APPROVER_ROLE = await treasury.WITHDRAWAL_APPROVER_ROLE();
            const EMERGENCY_ROLE = await treasury.EMERGENCY_ROLE();
            
            expect(await treasury.hasRole(TREASURY_MANAGER_ROLE, admin.address)).to.be.true;
            expect(await treasury.hasRole(WITHDRAWAL_APPROVER_ROLE, approver1.address)).to.be.true;
            expect(await treasury.hasRole(WITHDRAWAL_APPROVER_ROLE, approver2.address)).to.be.true;
            expect(await treasury.hasRole(WITHDRAWAL_APPROVER_ROLE, approver3.address)).to.be.true;
            expect(await treasury.hasRole(EMERGENCY_ROLE, admin.address)).to.be.true;
        });

        it("Should initialize with zero balances and metrics", async function () {
            expect(await treasury.getBalance()).to.equal(0);
            const metrics = await treasury.getTreasuryMetrics();
            expect(metrics.totalReceived).to.equal(0);
            expect(metrics.totalDistributed).to.equal(0);
            expect(metrics.currentBalance).to.equal(0);
        });
    });

    describe("Fund Collection and Storage", function () {
        it("Should receive ETH from sale manager", async function () {
            const amount = ethers.parseEther("10");
            
            await expect(treasury.receiveFromSaleManager({ value: amount }))
                .to.emit(treasury, "FundsReceived")
                .withArgs(admin.address, amount, AllocationCategory.DEVELOPMENT);
            
            expect(await treasury.getBalance()).to.equal(amount);
            
            const metrics = await treasury.getTreasuryMetrics();
            expect(metrics.totalReceived).to.equal(amount);
            expect(metrics.totalAllocations).to.equal(1);
        });

        it("Should receive ETH with category specification", async function () {
            const amount = ethers.parseEther("5");
            
            await expect(treasury.receiveETH(AllocationCategory.MARKETING, "Marketing funds", { value: amount }))
                .to.emit(treasury, "FundsReceived")
                .withArgs(admin.address, amount, AllocationCategory.MARKETING);
            
            expect(await treasury.getBalance()).to.equal(amount);
        });

        it("Should allocate funds according to percentage breakdown", async function () {
            const amount = ethers.parseEther("100");
            await treasury.receiveFromSaleManager({ value: amount });
            
            const breakdown = await treasury.getAllocationBreakdown();
            
            // Check allocation percentages (30%, 20%, 30%, 20%)
            expect(breakdown.marketing).to.equal(ethers.parseEther("30"));
            expect(breakdown.kol).to.equal(ethers.parseEther("20"));
            expect(breakdown.development).to.equal(ethers.parseEther("30"));
            expect(breakdown.buyback).to.equal(ethers.parseEther("20"));
        });

        it("Should update allocation configuration", async function () {
            const newConfig = {
                marketingPercentage: 4000, // 40%
                kolPercentage: 1500,       // 15%
                developmentPercentage: 2500, // 25%
                buybackPercentage: 2000,   // 20%
                lastUpdated: 0
            };
            
            await expect(treasury.updateAllocationConfig(newConfig))
                .to.emit(treasury, "AllocationConfigUpdated");
            
            const config = await treasury.allocationConfig();
            expect(config.marketingPercentage).to.equal(4000);
            expect(config.kolPercentage).to.equal(1500);
        });

        it("Should reject invalid allocation configuration", async function () {
            const invalidConfig = {
                marketingPercentage: 4000, // 40%
                kolPercentage: 2000,       // 20%
                developmentPercentage: 3000, // 30%
                buybackPercentage: 2000,   // 20% = 110% total
                lastUpdated: 0
            };
            
            await expect(treasury.updateAllocationConfig(invalidConfig))
                .to.be.revertedWith("Treasury: allocation percentages must sum to 100%");
        });
    });

    describe("Withdrawal and Distribution Engine", function () {
        beforeEach(async function () {
            // Fund the treasury for withdrawal tests
            await treasury.receiveFromSaleManager({ value: ethers.parseEther("100") });
        });

        it("Should propose withdrawal successfully", async function () {
            const amount = ethers.parseEther("5");
            
            await expect(treasury.proposeWithdrawal(
                user1.address,
                amount,
                AllocationCategory.MARKETING,
                "Marketing campaign"
            )).to.emit(treasury, "WithdrawalProposed");
            
            const proposalDetails = await treasury.getWithdrawalProposal(1);
            expect(proposalDetails.proposer).to.equal(admin.address);
            expect(proposalDetails.recipient).to.equal(user1.address);
            expect(proposalDetails.amount).to.equal(amount);
            expect(proposalDetails.description).to.equal("Marketing campaign");
        });

        it("Should require multisig approval for withdrawal execution", async function () {
            const amount = ethers.parseEther("5");
            
            // Propose withdrawal
            await treasury.proposeWithdrawal(
                user1.address,
                amount,
                AllocationCategory.MARKETING,
                "Marketing campaign"
            );
            
            // First approval
            await expect(treasury.connect(approver1).approveWithdrawal(1))
                .to.emit(treasury, "WithdrawalApproved")
                .withArgs(1, approver1.address);
            
            // Second approval should trigger execution (2-of-3 threshold)
            const userBalanceBefore = await ethers.provider.getBalance(user1.address);
            
            await expect(treasury.connect(approver2).approveWithdrawal(1))
                .to.emit(treasury, "WithdrawalExecuted")
                .withArgs(1, user1.address, amount);
            
            const userBalanceAfter = await ethers.provider.getBalance(user1.address);
            expect(userBalanceAfter - userBalanceBefore).to.equal(amount);
        });

        it("Should handle large withdrawal with timelock", async function () {
            const largeAmount = ethers.parseEther("15"); // 15% of 100 ETH balance
            
            await treasury.proposeWithdrawal(
                user1.address,
                largeAmount,
                AllocationCategory.DEVELOPMENT,
                "Large development expense"
            );
            
            const proposalDetails = await treasury.getWithdrawalProposal(1);
            expect(proposalDetails.isLargeWithdrawal).to.be.true;
            
            // Approve by required signers
            await treasury.connect(approver1).approveWithdrawal(1);
            await treasury.connect(approver2).approveWithdrawal(1);
            
            // Should fail if executed before timelock
            await expect(treasury.executeWithdrawal(1))
                .to.be.revertedWith("Treasury: timelock not expired");
        });

        it("Should cancel withdrawal proposal", async function () {
            const amount = ethers.parseEther("5");
            
            await treasury.proposeWithdrawal(
                user1.address,
                amount,
                AllocationCategory.MARKETING,
                "Marketing campaign"
            );
            
            await expect(treasury.cancelWithdrawal(1))
                .to.emit(treasury, "WithdrawalCancelled")
                .withArgs(1, admin.address);
            
            const proposalDetails = await treasury.getWithdrawalProposal(1);
            expect(proposalDetails.status).to.equal(3); // CANCELLED
        });

        it("Should propose and execute batch distribution", async function () {
            const recipients = [user1.address, user2.address];
            const amounts = [ethers.parseEther("2"), ethers.parseEther("3")];
            const totalAmount = ethers.parseEther("5");
            
            await expect(treasury.proposeBatchDistribution(
                recipients,
                amounts,
                AllocationCategory.KOL,
                "KOL payments"
            )).to.emit(treasury, "BatchDistributionProposed")
              .withArgs(1, totalAmount);
            
            const user1BalanceBefore = await ethers.provider.getBalance(user1.address);
            const user2BalanceBefore = await ethers.provider.getBalance(user2.address);
            
            await expect(treasury.executeBatchDistribution(1))
                .to.emit(treasury, "BatchDistributionExecuted")
                .withArgs(1, totalAmount);
            
            const user1BalanceAfter = await ethers.provider.getBalance(user1.address);
            const user2BalanceAfter = await ethers.provider.getBalance(user2.address);
            
            expect(user1BalanceAfter - user1BalanceBefore).to.equal(amounts[0]);
            expect(user2BalanceAfter - user2BalanceBefore).to.equal(amounts[1]);
        });
    });

    describe("Emergency Mechanisms", function () {
        beforeEach(async function () {
            await treasury.receiveFromSaleManager({ value: ethers.parseEther("50") });
        });

        it("Should execute emergency withdrawal", async function () {
            const amount = ethers.parseEther("10");
            const userBalanceBefore = await ethers.provider.getBalance(user1.address);
            
            await expect(treasury.emergencyWithdrawal(
                user1.address,
                amount,
                "Critical infrastructure payment"
            )).to.emit(treasury, "EmergencyWithdrawal")
              .withArgs(user1.address, amount, "Critical infrastructure payment");
            
            const userBalanceAfter = await ethers.provider.getBalance(user1.address);
            expect(userBalanceAfter - userBalanceBefore).to.equal(amount);
            
            const metrics = await treasury.getTreasuryMetrics();
            expect(metrics.emergencyWithdrawals).to.equal(1);
        });

        it("Should pause and unpause treasury operations", async function () {
            await expect(treasury.pauseTreasury())
                .to.emit(treasury, "TreasuryPaused")
                .withArgs(admin.address);
            
            // Should reject operations when paused
            await expect(treasury.receiveETH(AllocationCategory.MARKETING, "Test", { value: ethers.parseEther("1") }))
                .to.be.revertedWith("Pausable: paused");
            
            await expect(treasury.unpauseTreasury())
                .to.emit(treasury, "TreasuryUnpaused")
                .withArgs(admin.address);
            
            // Should accept operations when unpaused
            await expect(treasury.receiveETH(AllocationCategory.MARKETING, "Test", { value: ethers.parseEther("1") }))
                .to.emit(treasury, "FundsReceived");
        });

        it("Should execute emergency recovery", async function () {
            const adminBalanceBefore = await ethers.provider.getBalance(admin.address);
            const treasuryBalance = await treasury.getBalance();
            
            const tx = await treasury.emergencyRecovery();
            const receipt = await tx.wait();
            const gasUsed = receipt.gasUsed * receipt.gasPrice;
            
            const adminBalanceAfter = await ethers.provider.getBalance(admin.address);
            expect(adminBalanceAfter).to.be.closeTo(
                adminBalanceBefore + treasuryBalance - gasUsed,
                ethers.parseEther("0.01") // Allow for gas cost variance
            );
        });
    });

    describe("Allocation Management", function () {
        beforeEach(async function () {
            await treasury.receiveFromSaleManager({ value: ethers.parseEther("100") });
        });

        it("Should check sufficient funds for category", async function () {
            expect(await treasury.hasSufficientFunds(AllocationCategory.MARKETING, ethers.parseEther("25")))
                .to.be.true;
            expect(await treasury.hasSufficientFunds(AllocationCategory.MARKETING, ethers.parseEther("35")))
                .to.be.false;
        });

        it("Should get category allocation details", async function () {
            const allocation = await treasury.getCategoryAllocation(AllocationCategory.MARKETING);
            expect(allocation.totalAllocated).to.equal(ethers.parseEther("30"));
            expect(allocation.available).to.equal(ethers.parseEther("30"));
            expect(allocation.totalSpent).to.equal(0);
            expect(allocation.reserved).to.equal(0);
        });

        it("Should reserve and release funds", async function () {
            const amount = ethers.parseEther("10");
            
            await expect(treasury.reserveFunds(AllocationCategory.MARKETING, amount))
                .to.emit(treasury, "FundsReserved")
                .withArgs(AllocationCategory.MARKETING, amount);
            
            const allocation = await treasury.getCategoryAllocation(AllocationCategory.MARKETING);
            expect(allocation.reserved).to.equal(amount);
            expect(allocation.available).to.equal(ethers.parseEther("20"));
            
            await expect(treasury.releaseReservedFunds(AllocationCategory.MARKETING, amount))
                .to.emit(treasury, "ReservedFundsReleased")
                .withArgs(AllocationCategory.MARKETING, amount);
            
            const allocationAfter = await treasury.getCategoryAllocation(AllocationCategory.MARKETING);
            expect(allocationAfter.reserved).to.equal(0);
            expect(allocationAfter.available).to.equal(ethers.parseEther("30"));
        });

        it("Should rebalance allocations between categories", async function () {
            const amount = ethers.parseEther("5");
            
            await expect(treasury.rebalanceAllocations(
                AllocationCategory.MARKETING,
                AllocationCategory.KOL,
                amount
            )).to.emit(treasury, "FundsRebalanced")
              .withArgs(AllocationCategory.MARKETING, AllocationCategory.KOL, amount);
            
            const marketingAllocation = await treasury.getCategoryAllocation(AllocationCategory.MARKETING);
            const kolAllocation = await treasury.getCategoryAllocation(AllocationCategory.KOL);
            
            expect(marketingAllocation.available).to.equal(ethers.parseEther("25"));
            expect(kolAllocation.available).to.equal(ethers.parseEther("25"));
        });
    });

    describe("Reporting and Analytics", function () {
        beforeEach(async function () {
            await treasury.receiveFromSaleManager({ value: ethers.parseEther("100") });
        });

        it("Should track treasury metrics correctly", async function () {
            // Execute a withdrawal to update metrics
            await treasury.proposeWithdrawal(
                user1.address,
                ethers.parseEther("5"),
                AllocationCategory.MARKETING,
                "Test withdrawal"
            );
            
            await treasury.connect(approver1).approveWithdrawal(1);
            await treasury.connect(approver2).approveWithdrawal(1);
            
            const metrics = await treasury.getTreasuryMetrics();
            expect(metrics.totalReceived).to.equal(ethers.parseEther("100"));
            expect(metrics.totalDistributed).to.equal(ethers.parseEther("5"));
            expect(metrics.totalWithdrawals).to.equal(1);
            expect(metrics.totalAllocations).to.equal(1);
        });

        it("Should provide historical transaction data", async function () {
            // Make a few transactions
            await treasury.receiveETH(AllocationCategory.KOL, "Additional funds", { value: ethers.parseEther("20") });
            
            const currentTime = Math.floor(Date.now() / 1000);
            const oneHourAgo = currentTime - 3600;
            const oneHourFromNow = currentTime + 3600;
            
            const transactions = await treasury.getHistoricalTransactions(oneHourAgo, oneHourFromNow);
            expect(transactions.length).to.be.greaterThan(0);
            
            const firstTransaction = transactions[0];
            expect(firstTransaction.amount).to.be.greaterThan(0);
            expect(firstTransaction.transactionType).to.include("Received:");
        });

        it("Should get withdrawal proposal details", async function () {
            await treasury.proposeWithdrawal(
                user1.address,
                ethers.parseEther("5"),
                AllocationCategory.MARKETING,
                "Test proposal"
            );
            
            const proposal = await treasury.getWithdrawalProposal(1);
            expect(proposal.proposer).to.equal(admin.address);
            expect(proposal.recipient).to.equal(user1.address);
            expect(proposal.amount).to.equal(ethers.parseEther("5"));
            expect(proposal.description).to.equal("Test proposal");
            expect(proposal.status).to.equal(0); // PENDING
        });

        it("Should get batch distribution details", async function () {
            const recipients = [user1.address, user2.address];
            const amounts = [ethers.parseEther("2"), ethers.parseEther("3")];
            
            await treasury.proposeBatchDistribution(
                recipients,
                amounts,
                AllocationCategory.KOL,
                "Test batch"
            );
            
            const batch = await treasury.getBatchDistribution(1);
            expect(batch.recipients).to.deep.equal(recipients);
            expect(batch.amounts).to.deep.equal(amounts);
            expect(batch.description).to.equal("Test batch");
            expect(batch.totalAmount).to.equal(ethers.parseEther("5"));
            expect(batch.executed).to.be.false;
        });
    });

    describe("Configuration Management", function () {
        it("Should update multisig threshold", async function () {
            await expect(treasury.setMultisigThreshold(3))
                .to.emit(treasury, "MultisigThresholdUpdated")
                .withArgs(3);
            
            expect(await treasury.multisigThreshold()).to.equal(3);
        });

        it("Should update timelock duration", async function () {
            const newDuration = 14 * 24 * 3600; // 14 days
            
            await expect(treasury.setTimelockDuration(newDuration))
                .to.emit(treasury, "TimelockDurationUpdated")
                .withArgs(newDuration);
            
            expect(await treasury.timelockDuration()).to.equal(newDuration);
        });

        it("Should update large withdrawal threshold", async function () {
            const newThreshold = 2000; // 20%
            
            await expect(treasury.setLargeWithdrawalThreshold(newThreshold))
                .to.emit(treasury, "LargeWithdrawalThresholdUpdated")
                .withArgs(newThreshold);
            
            expect(await treasury.largeWithdrawalThresholdBps()).to.equal(newThreshold);
        });

        it("Should update sale manager address", async function () {
            await expect(treasury.updateSaleManager(user1.address))
                .to.emit(treasury, "SaleManagerUpdated")
                .withArgs(admin.address, user1.address);
            
            expect(await treasury.saleManager()).to.equal(user1.address);
        });
    });

    describe("Access Control", function () {
        it("Should restrict treasury manager functions", async function () {
            await expect(treasury.connect(user1).proposeWithdrawal(
                user2.address,
                ethers.parseEther("1"),
                AllocationCategory.MARKETING,
                "Unauthorized"
            )).to.be.revertedWith("Treasury: caller is not treasury manager");
        });

        it("Should restrict withdrawal approver functions", async function () {
            await expect(treasury.connect(user1).approveWithdrawal(1))
                .to.be.revertedWith("Treasury: caller is not withdrawal approver");
        });

        it("Should restrict emergency functions", async function () {
            await expect(treasury.connect(user1).emergencyWithdrawal(
                user2.address,
                ethers.parseEther("1"),
                "Unauthorized emergency"
            )).to.be.revertedWith("Treasury: caller does not have emergency role");
        });

        it("Should restrict allocation manager functions", async function () {
            await expect(treasury.connect(user1).reserveFunds(
                AllocationCategory.MARKETING,
                ethers.parseEther("1")
            )).to.be.revertedWith("Treasury: caller is not allocation manager");
        });
    });

    describe("Edge Cases and Error Handling", function () {
        it("Should reject zero amount transactions", async function () {
            await expect(treasury.receiveFromSaleManager({ value: 0 }))
                .to.be.revertedWith("Treasury: no ETH sent");
            
            await expect(treasury.receiveETH(AllocationCategory.MARKETING, "Test", { value: 0 }))
                .to.be.revertedWith("Treasury: no ETH sent");
        });

        it("Should reject invalid category", async function () {
            await expect(treasury.receiveETH(99, "Invalid category", { value: ethers.parseEther("1") }))
                .to.be.revertedWith("Treasury: invalid category");
        });

        it("Should reject proposal for non-existent proposal ID", async function () {
            await expect(treasury.getWithdrawalProposal(999))
                .to.be.revertedWith("Treasury: proposal does not exist");
        });

        it("Should reject insufficient funds for withdrawal", async function () {
            await expect(treasury.proposeWithdrawal(
                user1.address,
                ethers.parseEther("1000"),
                AllocationCategory.MARKETING,
                "Too large"
            )).to.be.revertedWith("Treasury: insufficient funds in category");
        });

        it("Should reject double approval from same approver", async function () {
            await treasury.receiveFromSaleManager({ value: ethers.parseEther("100") });
            
            await treasury.proposeWithdrawal(
                user1.address,
                ethers.parseEther("5"),
                AllocationCategory.MARKETING,
                "Test"
            );
            
            await treasury.connect(approver1).approveWithdrawal(1);
            
            await expect(treasury.connect(approver1).approveWithdrawal(1))
                .to.be.revertedWith("Treasury: already approved by this approver");
        });
    });
}); 