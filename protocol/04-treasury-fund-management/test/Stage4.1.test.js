/**
 * @title Stage 4.1 Test Suite - Treasury Core Infrastructure
 * @dev Test suite for Treasury Core Infrastructure development stage
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther, formatEther } = require("ethers");

describe("Stage 4.1: Treasury Core Infrastructure", function () {
    let treasury;
    let deployer, admin, multisigManager, marketing, kol, development;
    let TREASURY_ADMIN_ROLE, ALLOCATION_MANAGER_ROLE, WITHDRAWAL_MANAGER_ROLE;

    beforeEach(async function () {
        [deployer, admin, multisigManager, marketing, kol, development] = await ethers.getSigners();

        // Deploy Treasury contract
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            admin.address,
            multisigManager.address,
            parseEther("10000")
        );
        await treasury.waitForDeployment();

        // Get role identifiers
        TREASURY_ADMIN_ROLE = await treasury.TREASURY_ADMIN_ROLE();
        ALLOCATION_MANAGER_ROLE = await treasury.ALLOCATION_MANAGER_ROLE();
        WITHDRAWAL_MANAGER_ROLE = await treasury.WITHDRAWAL_MANAGER_ROLE();

        // Fund the treasury
        await deployer.sendTransaction({
            to: await treasury.getAddress(),
            value: parseEther("10000")
        });
    });

    describe("Fund Collection and Storage", function () {
        it("Should accept ETH deposits", async function () {
            const initialBalance = await ethers.provider.getBalance(await treasury.getAddress());
            
            await deployer.sendTransaction({
                to: await treasury.getAddress(),
                value: parseEther("1000")
            });
            
            const finalBalance = await ethers.provider.getBalance(await treasury.getAddress());
            expect(finalBalance).to.equal(initialBalance + parseEther("1000"));
        });

        it("Should track total balance correctly", async function () {
            const contractBalance = await ethers.provider.getBalance(await treasury.getAddress());
            const reportedBalance = await treasury.getTotalBalance();
            
            expect(reportedBalance).to.equal(contractBalance);
        });

        it("Should implement multisig controls", async function () {
            expect(await treasury.hasRole(await treasury.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true;
            expect(await treasury.hasRole(await treasury.MULTISIG_MANAGER_ROLE(), multisigManager.address)).to.be.true;
        });

        it("Should enforce allocation percentages", async function () {
            const balance = parseEther("10000");
            const allocations = await treasury.calculateAllocations(balance);
            
            // Expected: 30% marketing, 20% KOL, 30% development, 20% buyback
            expect(allocations[0]).to.equal(parseEther("3000")); // Marketing
            expect(allocations[1]).to.equal(parseEther("2000")); // KOL
            expect(allocations[2]).to.equal(parseEther("3000")); // Development
            expect(allocations[3]).to.equal(parseEther("2000")); // Buyback
        });
    });

    describe("Withdrawal and Distribution Engine", function () {
        beforeEach(async function () {
            await treasury.connect(admin).grantRole(ALLOCATION_MANAGER_ROLE, admin.address);
            await treasury.connect(admin).grantRole(WITHDRAWAL_MANAGER_ROLE, admin.address);
        });

        it("Should process withdrawal requests", async function () {
            const withdrawAmount = parseEther("500");
            const category = 0; // MARKETING
            
            await expect(
                treasury.connect(admin).requestWithdrawal(
                    category,
                    withdrawAmount,
                    marketing.address,
                    "Marketing campaign funding"
                )
            ).to.emit(treasury, "WithdrawalRequested");
        });

        it("Should enforce category spending limits", async function () {
            const balance = await treasury.getTotalBalance();
            const allocations = await treasury.calculateAllocations(balance);
            const marketingBudget = allocations[0];
            
            const excessiveAmount = marketingBudget + parseEther("1");
            
            await expect(
                treasury.connect(admin).requestWithdrawal(
                    0,
                    excessiveAmount,
                    marketing.address,
                    "Excessive withdrawal"
                )
            ).to.be.revertedWith("Treasury: insufficient allocation");
        });

        it("Should implement timelock for large withdrawals", async function () {
            const balance = await treasury.getTotalBalance();
            const largeAmount = (balance * BigInt(15)) / BigInt(100); // 15% of treasury
            
            await treasury.connect(admin).requestWithdrawal(
                0,
                largeAmount,
                marketing.address,
                "Large marketing campaign"
            );
            
            const request = await treasury.getWithdrawalRequest(0);
            expect(request.requiresTimelock).to.be.true;
        });

        it("Should support batch distributions", async function () {
            const recipients = [marketing.address, kol.address, development.address];
            const amounts = [parseEther("100"), parseEther("200"), parseEther("300")];
            const categories = [0, 1, 2];
            
            await expect(
                treasury.connect(admin).batchWithdraw(
                    categories,
                    amounts,
                    recipients,
                    "Batch distribution"
                )
            ).to.emit(treasury, "BatchWithdrawal");
        });

        it("Should handle emergency withdrawals", async function () {
            await treasury.connect(admin).pause();
            
            await expect(
                treasury.connect(admin).emergencyWithdraw(
                    parseEther("1000"),
                    admin.address
                )
            ).to.emit(treasury, "EmergencyWithdrawal");
        });
    });

    describe("Allocation Management", function () {
        beforeEach(async function () {
            await treasury.connect(admin).grantRole(ALLOCATION_MANAGER_ROLE, admin.address);
        });

        it("Should track allocation categories", async function () {
            const categories = await treasury.getAllocationCategories();
            expect(categories.length).to.equal(4);
            expect(categories[0]).to.equal("MARKETING");
            expect(categories[1]).to.equal("KOL");
            expect(categories[2]).to.equal("DEVELOPMENT");
            expect(categories[3]).to.equal("BUYBACK");
        });

        it("Should update allocation percentages", async function () {
            const newPercentages = [35, 25, 25, 15];
            
            await treasury.connect(admin).updateAllocationPercentages(newPercentages);
            
            const balance = parseEther("10000");
            const allocations = await treasury.calculateAllocations(balance);
            
            expect(allocations[0]).to.equal(parseEther("3500")); // Marketing
            expect(allocations[1]).to.equal(parseEther("2500")); // KOL
            expect(allocations[2]).to.equal(parseEther("2500")); // Development
            expect(allocations[3]).to.equal(parseEther("1500")); // Buyback
        });

        it("Should track spending per category", async function () {
            await treasury.connect(admin).grantRole(WITHDRAWAL_MANAGER_ROLE, admin.address);
            
            const withdrawAmount = parseEther("500");
            await treasury.connect(admin).requestWithdrawal(
                0,
                withdrawAmount,
                marketing.address,
                "Marketing spend"
            );
            
            const spentAmount = await treasury.getCategorySpent(0);
            expect(spentAmount).to.equal(withdrawAmount);
        });

        it("Should support allocation rebalancing", async function () {
            const fromCategory = 0; // MARKETING
            const toCategory = 2; // DEVELOPMENT
            const amount = parseEther("500");
            
            await expect(
                treasury.connect(admin).rebalanceAllocation(
                    fromCategory,
                    toCategory,
                    amount
                )
            ).to.emit(treasury, "AllocationRebalanced");
        });

        it("Should generate allocation reports", async function () {
            const report = await treasury.generateAllocationReport();
            
            expect(report.totalBalance).to.be.gt(0);
            expect(report.allocations.length).to.equal(4);
            expect(report.spent.length).to.equal(4);
            expect(report.remaining.length).to.equal(4);
        });
    });

    describe("Security and Access Control", function () {
        it("Should restrict allocation management to authorized roles", async function () {
            await expect(
                treasury.connect(marketing).updateAllocationPercentages([25, 25, 25, 25])
            ).to.be.revertedWith("Treasury: caller is not allocation manager");
        });

        it("Should restrict withdrawal management to authorized roles", async function () {
            await expect(
                treasury.connect(marketing).requestWithdrawal(
                    0,
                    parseEther("100"),
                    marketing.address,
                    "Unauthorized withdrawal"
                )
            ).to.be.revertedWith("Treasury: caller is not withdrawal manager");
        });

        it("Should support role revocation", async function () {
            await treasury.connect(admin).grantRole(ALLOCATION_MANAGER_ROLE, marketing.address);
            expect(await treasury.hasRole(ALLOCATION_MANAGER_ROLE, marketing.address)).to.be.true;
            
            await treasury.connect(admin).revokeRole(ALLOCATION_MANAGER_ROLE, marketing.address);
            expect(await treasury.hasRole(ALLOCATION_MANAGER_ROLE, marketing.address)).to.be.false;
        });

        it("Should implement pause functionality", async function () {
            await treasury.connect(admin).pause();
            expect(await treasury.paused()).to.be.true;
            
            await expect(
                treasury.connect(admin).requestWithdrawal(
                    0,
                    parseEther("100"),
                    marketing.address,
                    "Paused withdrawal"
                )
            ).to.be.revertedWith("Pausable: paused");
        });

        it("Should prevent reentrancy attacks", async function () {
            // Deploy malicious contract that attempts reentrancy
            const MaliciousContract = await ethers.getContractFactory("MaliciousReentrancy");
            const malicious = await MaliciousContract.deploy(await treasury.getAddress());
            
            await treasury.connect(admin).grantRole(WITHDRAWAL_MANAGER_ROLE, admin.address);
            
            await expect(
                treasury.connect(admin).requestWithdrawal(
                    0,
                    parseEther("100"),
                    await malicious.getAddress(),
                    "Reentrancy attempt"
                )
            ).to.be.revertedWith("ReentrancyGuard: reentrant call");
        });
    });

    describe("Integration with External Contracts", function () {
        it("Should integrate with SaleManager for fund collection", async function () {
            // Mock SaleManager contract
            const MockSaleManager = await ethers.getContractFactory("MockSaleManager");
            const saleManager = await MockSaleManager.deploy(await treasury.getAddress());
            
            await treasury.connect(admin).addAuthorizedDepositor(await saleManager.getAddress());
            
            const depositAmount = parseEther("1000");
            await saleManager.simulateDeposit({ value: depositAmount });
            
            const balance = await ethers.provider.getBalance(await treasury.getAddress());
            expect(balance).to.be.gte(depositAmount);
        });

        it("Should provide funding to BuybackBurn contract", async function () {
            const buybackAmount = parseEther("500");
            
            await treasury.connect(admin).grantRole(WITHDRAWAL_MANAGER_ROLE, admin.address);
            
            await expect(
                treasury.connect(admin).fundBuybackBurn(buybackAmount)
            ).to.emit(treasury, "BuybackFunded");
        });

        it("Should handle Paymaster funding requests", async function () {
            const paymasterAmount = parseEther("100");
            
            await treasury.connect(admin).grantRole(WITHDRAWAL_MANAGER_ROLE, admin.address);
            
            await expect(
                treasury.connect(admin).fundPaymaster(paymasterAmount)
            ).to.emit(treasury, "PaymasterFunded");
        });
    });

    describe("Gas Optimization and Performance", function () {
        it("Should efficiently handle multiple withdrawals", async function () {
            await treasury.connect(admin).grantRole(WITHDRAWAL_MANAGER_ROLE, admin.address);
            
            const gasUsed = [];
            
            for (let i = 0; i < 5; i++) {
                const tx = await treasury.connect(admin).requestWithdrawal(
                    0,
                    parseEther("100"),
                    marketing.address,
                    `Withdrawal ${i}`
                );
                const receipt = await tx.wait();
                gasUsed.push(receipt.gasUsed);
            }
            
            // Gas usage should remain relatively stable
            const avgGas = gasUsed.reduce((a, b) => a + b, BigInt(0)) / BigInt(gasUsed.length);
            const maxDeviation = avgGas / BigInt(10); // 10% deviation allowed
            
            for (const gas of gasUsed) {
                expect(gas).to.be.closeTo(avgGas, maxDeviation);
            }
        });

        it("Should optimize storage for allocation tracking", async function () {
            const initialStorage = await treasury.getStorageSlots();
            
            await treasury.connect(admin).grantRole(ALLOCATION_MANAGER_ROLE, admin.address);
            await treasury.connect(admin).updateAllocationPercentages([25, 25, 25, 25]);
            
            const finalStorage = await treasury.getStorageSlots();
            
            // Storage should not increase significantly
            expect(finalStorage - initialStorage).to.be.lt(10);
        });
    });
}); 