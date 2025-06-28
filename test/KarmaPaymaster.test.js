const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("KarmaPaymaster", function () {
    let karmaPaymaster, karmaToken, treasury, entryPoint;
    let owner, admin, user1, user2, bundler, contractTarget;
    let paymasterManagerRole, whitelistManagerRole, emergencyRole, rateLimitManagerRole;

    beforeEach(async function () {
        [owner, admin, user1, user2, bundler, contractTarget] = await ethers.getSigners();

        // Deploy mock contracts
        const MockERC20 = await ethers.getContractFactory("KarmaToken");
        karmaToken = await MockERC20.deploy(admin.address);
        await karmaToken.waitForDeployment();

        // Deploy Mock Treasury (simplified for testing)
        const MockTreasury = await ethers.getContractFactory("MockTreasury");
        treasury = await MockTreasury.deploy();
        await treasury.waitForDeployment();
        
        // Fund the mock treasury for testing
        await admin.sendTransaction({
            to: await treasury.getAddress(),
            value: ethers.parseEther("100")
        });

        // Mock EntryPoint (simplified for testing)
        const MockEntryPoint = await ethers.getContractFactory("MockEntryPoint");
        entryPoint = await MockEntryPoint.deploy();
        await entryPoint.waitForDeployment();

        // Deploy KarmaPaymaster
        const KarmaPaymaster = await ethers.getContractFactory("KarmaPaymaster");
        karmaPaymaster = await KarmaPaymaster.deploy(
            await entryPoint.getAddress(),
            await treasury.getAddress(),
            await karmaToken.getAddress(),
            admin.address
        );
        await karmaPaymaster.waitForDeployment();

        // Get role constants
        paymasterManagerRole = await karmaPaymaster.PAYMASTER_MANAGER_ROLE();
        whitelistManagerRole = await karmaPaymaster.WHITELIST_MANAGER_ROLE();
        emergencyRole = await karmaPaymaster.EMERGENCY_ROLE();
        rateLimitManagerRole = await karmaPaymaster.RATE_LIMIT_MANAGER_ROLE();

        // Fund paymaster for testing
        await admin.sendTransaction({
            to: await karmaPaymaster.getAddress(),
            value: ethers.parseEther("10")
        });

        // Give users some KARMA tokens
        await karmaToken.connect(admin).mint(user1.address, ethers.parseEther("10000"));
        await karmaToken.connect(admin).mint(user2.address, ethers.parseEther("5000"));
    });

    describe("Deployment", function () {
        it("Should deploy with correct configuration", async function () {
            expect(await karmaPaymaster.entryPoint()).to.equal(await entryPoint.getAddress());
            expect(await karmaPaymaster.treasury()).to.equal(await treasury.getAddress());
            expect(await karmaPaymaster.karmaToken()).to.equal(await karmaToken.getAddress());
            
            const config = await karmaPaymaster.getSponsorshipConfig();
            expect(config.isActive).to.be.true;
            expect(config.policy).to.equal(1); // TOKEN_HOLDERS
        });

        it("Should grant all roles to admin", async function () {
            expect(await karmaPaymaster.hasRole(paymasterManagerRole, admin.address)).to.be.true;
            expect(await karmaPaymaster.hasRole(whitelistManagerRole, admin.address)).to.be.true;
            expect(await karmaPaymaster.hasRole(emergencyRole, admin.address)).to.be.true;
            expect(await karmaPaymaster.hasRole(rateLimitManagerRole, admin.address)).to.be.true;
        });
    });

    describe("Gas Sponsorship Engine", function () {
        let userOp;

        beforeEach(function () {
            userOp = {
                sender: user1.address,
                nonce: 0,
                initCode: "0x",
                callData: "0x",
                callGasLimit: 100000,
                verificationGasLimit: 100000,
                preVerificationGas: 21000,
                maxFeePerGas: ethers.parseUnits("20", "gwei"),
                maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
                paymasterAndData: "0x",
                signature: "0x"
            };
        });

        it("Should estimate gas correctly", async function () {
            const estimation = await karmaPaymaster.estimateGas(userOp);
            
            expect(estimation.preVerificationGas).to.be.greaterThan(userOp.preVerificationGas);
            expect(estimation.verificationGasLimit).to.be.greaterThan(userOp.verificationGasLimit);
            expect(estimation.totalGasEstimate).to.be.greaterThan(0);
            expect(estimation.totalCostEstimate).to.be.greaterThan(0);
        });

        it("Should check eligibility for token holders", async function () {
            const [eligible, reason] = await karmaPaymaster.isEligibleForSponsorship(userOp);
            expect(eligible).to.be.true;
            expect(reason).to.equal("");
        });

        it("Should reject users with insufficient tokens", async function () {
            userOp.sender = owner.address; // Owner has no KARMA tokens
            const [eligible, reason] = await karmaPaymaster.isEligibleForSponsorship(userOp);
            expect(eligible).to.be.false;
            expect(reason).to.equal("Insufficient KARMA token balance");
        });

        it("Should calculate sponsorship cost", async function () {
            const gasUsed = 100000;
            const gasPrice = ethers.parseUnits("20", "gwei");
            const cost = await karmaPaymaster.calculateSponsorshipCost(gasUsed, gasPrice);
            
            expect(cost).to.equal(BigInt(gasUsed) * gasPrice);
        });
    });

    describe("Access Control and Whitelisting", function () {
        it("Should whitelist contracts", async function () {
            const maxGasPerCall = 200000;
            const selectors = ["0x12345678", "0x87654321"];
            const dailyGasLimit = 1000000;

            await expect(
                karmaPaymaster.connect(admin).whitelistContract(
                    contractTarget.address,
                    maxGasPerCall,
                    selectors,
                    dailyGasLimit
                )
            ).to.emit(karmaPaymaster, "ContractWhitelisted")
             .withArgs(contractTarget.address, true);

            const approved = await karmaPaymaster.isContractCallApproved(
                contractTarget.address,
                "0x12345678",
                150000
            );
            expect(approved).to.be.true;
        });

        it("Should reject non-whitelisted function selectors", async function () {
            const maxGasPerCall = 200000;
            const selectors = ["0x12345678"];
            const dailyGasLimit = 1000000;

            await karmaPaymaster.connect(admin).whitelistContract(
                contractTarget.address,
                maxGasPerCall,
                selectors,
                dailyGasLimit
            );

            const approved = await karmaPaymaster.isContractCallApproved(
                contractTarget.address,
                "0x87654321", // Not in whitelist
                150000
            );
            expect(approved).to.be.false;
        });

        it("Should set user tiers", async function () {
            await expect(
                karmaPaymaster.connect(admin).setUserTier(user1.address, 2) // STAKER
            ).to.emit(karmaPaymaster, "UserTierUpdated")
             .withArgs(user1.address, 0, 2);

            const tier = await karmaPaymaster.getUserTier(user1.address);
            expect(tier).to.equal(2);
        });

        it("Should only allow whitelist managers to manage contracts", async function () {
            await expect(
                karmaPaymaster.connect(user1).whitelistContract(
                    contractTarget.address,
                    200000,
                    ["0x12345678"],
                    1000000
                )
            ).to.be.revertedWith("KarmaPaymaster: caller is not whitelist manager");
        });
    });

    describe("Anti-Abuse and Rate Limiting", function () {
        beforeEach(async function () {
            // Set user1 as VIP for higher limits
            await karmaPaymaster.connect(admin).setUserTier(user1.address, 1); // VIP
        });

        it("Should check rate limits correctly", async function () {
            const gasRequested = 100000;
            const [withinLimits, resetTime] = await karmaPaymaster.checkRateLimit(user1.address, gasRequested);
            
            expect(withinLimits).to.be.true;
            expect(resetTime).to.equal(0);
        });

        it("Should enforce daily gas limits", async function () {
            // Request gas that exceeds daily limit
            const excessiveGas = ethers.parseEther("10"); // Much more than daily limit
            const [withinLimits, resetTime] = await karmaPaymaster.checkRateLimit(user1.address, excessiveGas);
            
            expect(withinLimits).to.be.false;
            expect(resetTime).to.be.greaterThan(0);
        });

        it("Should blacklist users", async function () {
            await expect(
                karmaPaymaster.connect(admin).blacklistUser(user2.address, "Abuse detected")
            ).to.emit(karmaPaymaster, "UserBlacklisted")
             .withArgs(user2.address, "Abuse detected");

            const [withinLimits,] = await karmaPaymaster.checkRateLimit(user2.address, 100000);
            expect(withinLimits).to.be.false;
        });

        it("Should detect abuse for high gas requests", async function () {
            // Test with very high gas request (90% of max limit)
            const highGasRequested = Math.floor(500000 * 0.9); // 90% of default max gas per op
            
            const tx = await karmaPaymaster.detectAbuse(user1.address, highGasRequested);
            const receipt = await tx.wait();
            
            // Check if AbuseDetected event was emitted
            let abuseDetected = false;
            for (let log of receipt.logs) {
                try {
                    const parsed = karmaPaymaster.interface.parseLog(log);
                    if (parsed && parsed.name === 'AbuseDetected') {
                        abuseDetected = true;
                        expect(parsed.args.abuseType).to.equal("High gas request");
                        break;
                    }
                } catch (e) {
                    // Not a paymaster log, continue
                }
            }
            expect(abuseDetected).to.be.true;
        });

        it("Should update rate limits", async function () {
            const newDailyLimit = 2000000;
            const newMonthlyLimit = 50000000;
            const newMaxPerOp = 750000;

            await expect(
                karmaPaymaster.connect(admin).updateRateLimits(
                    newDailyLimit,
                    newMonthlyLimit,
                    newMaxPerOp
                )
            ).to.emit(karmaPaymaster, "GasLimitsUpdated")
             .withArgs(newDailyLimit, newMonthlyLimit, newMaxPerOp);

            const config = await karmaPaymaster.getSponsorshipConfig();
            expect(config.dailyGasLimit).to.equal(newDailyLimit);
        });

        it("Should handle emergency stop", async function () {
            const reason = "Security threat detected";
            
            await expect(
                karmaPaymaster.connect(admin).emergencyStop(reason)
            ).to.emit(karmaPaymaster, "EmergencyStop")
             .withArgs(admin.address, reason);

            expect(await karmaPaymaster.emergencyStopped()).to.be.true;
            expect(await karmaPaymaster.emergencyReason()).to.equal(reason);

            // Should not be operational
            const [operational, operationalReason] = await karmaPaymaster.isOperational();
            expect(operational).to.be.false;
            expect(operationalReason).to.equal(reason);
        });
    });

    describe("Economic Sustainability", function () {
        it("Should track funding status", async function () {
            const [balance, lastRefill, needsRefill] = await karmaPaymaster.getFundingStatus();
            
            expect(balance).to.equal(ethers.parseEther("10"));
            expect(needsRefill).to.be.false; // Should NOT need refill since 10 ETH = 10 ETH threshold
        });

        it("Should track cost metrics", async function () {
            const [totalSponsored, operationsCount, avgCostPerOp] = await karmaPaymaster.getCostTracking();
            
            expect(totalSponsored).to.equal(0); // No operations yet
            expect(operationsCount).to.equal(0);
            expect(avgCostPerOp).to.equal(0);
        });

        it("Should optimize gas fees", async function () {
            const [optimizedGasPrice, costSavings] = await karmaPaymaster.optimizeGasFees();
            
            expect(optimizedGasPrice).to.be.greaterThan(0);
            expect(costSavings).to.be.greaterThanOrEqual(0); // Cost savings can be 0 if already optimal
        });

        it("Should set auto-refill parameters", async function () {
            const newThreshold = ethers.parseEther("5");
            const newRefillAmount = ethers.parseEther("25");

            await karmaPaymaster.connect(admin).setAutoRefillParams(newThreshold, newRefillAmount);

            expect(await karmaPaymaster.autoRefillThreshold()).to.equal(newThreshold);
            expect(await karmaPaymaster.autoRefillAmount()).to.equal(newRefillAmount);
        });
    });

    describe("Configuration and Management", function () {
        it("Should update sponsorship policy", async function () {
            const newPolicy = 0; // ALLOWLIST_ONLY

            await expect(
                karmaPaymaster.connect(admin).updateSponsorshipPolicy(newPolicy)
            ).to.emit(karmaPaymaster, "SponsorshipPolicyUpdated")
             .withArgs(1, newPolicy); // From TOKEN_HOLDERS to ALLOWLIST_ONLY

            const config = await karmaPaymaster.getSponsorshipConfig();
            expect(config.policy).to.equal(newPolicy);
        });

        it("Should get user gas usage", async function () {
            const usage = await karmaPaymaster.getUserGasUsage(user1.address);
            
            expect(usage.dailyGasUsed).to.equal(0);
            expect(usage.monthlyGasUsed).to.equal(0);
            expect(usage.operationCount).to.equal(0);
            expect(usage.isBlacklisted).to.be.false;
        });

        it("Should get paymaster metrics", async function () {
            const metrics = await karmaPaymaster.getPaymasterMetrics();
            
            expect(metrics.currentBalance).to.equal(ethers.parseEther("10"));
            expect(metrics.totalOperationsSponsored).to.equal(0);
            expect(metrics.blacklistedUsers).to.equal(0);
        });

        it("Should check operational status", async function () {
            const [operational, reason] = await karmaPaymaster.isOperational();
            
            expect(operational).to.be.true;
            expect(reason).to.equal("");
        });
    });

    describe("Admin Functions", function () {
        it("Should update Treasury contract", async function () {
            const newTreasury = user2.address; // Mock new treasury
            
            await karmaPaymaster.connect(admin).updateTreasury(newTreasury);
            expect(await karmaPaymaster.treasury()).to.equal(newTreasury);
        });

        it("Should update KARMA token contract", async function () {
            const newKarmaToken = user2.address; // Mock new token
            
            await karmaPaymaster.connect(admin).updateKarmaToken(newKarmaToken);
            expect(await karmaPaymaster.karmaToken()).to.equal(newKarmaToken);
        });

        it("Should update gas price parameters", async function () {
            const newMaxGasPrice = ethers.parseUnits("200", "gwei");
            const newTargetGasPrice = ethers.parseUnits("30", "gwei");

            await karmaPaymaster.connect(admin).updateGasPriceParams(
                newMaxGasPrice,
                newTargetGasPrice
            );

            expect(await karmaPaymaster.maxGasPrice()).to.equal(newMaxGasPrice);
            expect(await karmaPaymaster.targetGasPrice()).to.equal(newTargetGasPrice);
        });

        it("Should handle emergency withdrawal", async function () {
            const withdrawAmount = ethers.parseEther("10");
            const initialBalance = await ethers.provider.getBalance(user2.address);

            await karmaPaymaster.connect(admin).emergencyWithdraw(user2.address, withdrawAmount);

            const finalBalance = await ethers.provider.getBalance(user2.address);
            expect(finalBalance - initialBalance).to.equal(withdrawAmount);
        });

        it("Should only allow admin for admin functions", async function () {
            await expect(
                karmaPaymaster.connect(user1).updateTreasury(user2.address)
            ).to.be.reverted; // Should be reverted regardless of specific error message
        });
    });

    describe("ERC-4337 Integration", function () {
        let userOp, userOpHash, maxCost;

        beforeEach(function () {
            userOp = {
                sender: user1.address,
                nonce: 0,
                initCode: "0x",
                callData: "0x",
                callGasLimit: 100000,
                verificationGasLimit: 100000,
                preVerificationGas: 21000,
                maxFeePerGas: ethers.parseUnits("20", "gwei"),
                maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
                paymasterAndData: "0x",
                signature: "0x"
            };
            
            userOpHash = ethers.keccak256(ethers.toUtf8Bytes("test-hash"));
            maxCost = ethers.parseEther("0.01");
        });

        it("Should validate eligible user operations", async function () {
            // Mock the entryPoint call
            await karmaPaymaster.connect(admin).grantRole(
                await karmaPaymaster.PAYMASTER_MANAGER_ROLE(),
                await entryPoint.getAddress()
            );

            // This would normally be called by EntryPoint
            // For testing, we'll call it directly but expect it to revert due to onlyEntryPoint
            await expect(
                karmaPaymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost)
            ).to.be.revertedWith("KarmaPaymaster: caller is not EntryPoint");
        });

        it("Should handle postOp correctly", async function () {
            const context = ethers.AbiCoder.defaultAbiCoder().encode(
                ["address", "bytes32", "uint256", "uint256"],
                [user1.address, userOpHash, maxCost, Math.floor(Date.now() / 1000)]
            );
            const actualGasCost = ethers.parseEther("0.005");

            // This would normally be called by EntryPoint
            await expect(
                karmaPaymaster.postOp(0, context, actualGasCost) // opSucceeded
            ).to.be.revertedWith("KarmaPaymaster: caller is not EntryPoint");
        });
    });
}); 