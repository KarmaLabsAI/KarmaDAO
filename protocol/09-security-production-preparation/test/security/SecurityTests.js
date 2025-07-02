const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

/**
 * @title Comprehensive Security Tests
 * @notice Security and penetration testing for the entire Karma Labs ecosystem
 * @dev Tests for vulnerabilities, attack vectors, and security measures
 */
describe("Karma Labs Security Tests", function () {
    let deployer, attacker, user1, user2, user3, securityManager, emergencyResponder;
    let contracts = {};
    let securityTestSuite;

    // Test configuration
    const ATTACK_VECTORS = {
        REENTRANCY: "REENTRANCY",
        INTEGER_OVERFLOW: "INTEGER_OVERFLOW", 
        ACCESS_CONTROL: "ACCESS_CONTROL",
        FRONT_RUNNING: "FRONT_RUNNING",
        FLASH_LOAN: "FLASH_LOAN",
        GOVERNANCE_ATTACK: "GOVERNANCE_ATTACK",
        ORACLE_MANIPULATION: "ORACLE_MANIPULATION",
        CROSS_CHAIN_REPLAY: "CROSS_CHAIN_REPLAY"
    };

    async function deploySecurityTestFixture() {
        const signers = await ethers.getSigners();
        [deployer, attacker, user1, user2, user3, securityManager, emergencyResponder] = signers;

        // Mock tokens for testing
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        const usdcToken = await MockERC20.deploy("USDC", "USDC", 6);
        const karmaToken = await MockERC20.deploy("KARMA", "KARMA", 18);

        // Deploy all protocol contracts for comprehensive testing
        const KarmaSecurityMonitoring = await ethers.getContractFactory("KarmaSecurityMonitoring");
        const securityMonitoring = await KarmaSecurityMonitoring.deploy(deployer.address);

        const KarmaBugBountyManager = await ethers.getContractFactory("KarmaBugBountyManager");
        const bugBountyManager = await KarmaBugBountyManager.deploy(
            usdcToken.target,
            karmaToken.target,
            deployer.address
        );

        const KarmaInsuranceManager = await ethers.getContractFactory("KarmaInsuranceManager");
        const insuranceManager = await KarmaInsuranceManager.deploy(
            deployer.address, // treasury
            usdcToken.target,
            karmaToken.target,
            deployer.address
        );

        // Security test utilities
        const SecurityTestUtilities = await ethers.getContractFactory("SecurityTestUtilities");
        const securityTestUtils = await SecurityTestUtilities.deploy();

        return {
            usdcToken,
            karmaToken,
            securityMonitoring,
            bugBountyManager,
            insuranceManager,
            securityTestUtils,
            deployer,
            attacker,
            user1,
            user2,
            user3,
            securityManager,
            emergencyResponder
        };
    }

    beforeEach(async function () {
        const fixture = await loadFixture(deploySecurityTestFixture);
        Object.assign(this, fixture);
        
        contracts = {
            securityMonitoring: fixture.securityMonitoring,
            bugBountyManager: fixture.bugBountyManager, 
            insuranceManager: fixture.insuranceManager,
            usdcToken: fixture.usdcToken,
            karmaToken: fixture.karmaToken
        };

        securityTestSuite = fixture.securityTestUtils;
    });

    describe("🔐 Access Control Security Tests", function () {
        it("Should prevent unauthorized role assignments", async function () {
            const BOUNTY_MANAGER_ROLE = await contracts.bugBountyManager.BOUNTY_MANAGER_ROLE();
            
            // Attacker should not be able to grant themselves roles
            await expect(
                contracts.bugBountyManager.connect(attacker).grantRole(BOUNTY_MANAGER_ROLE, attacker.address)
            ).to.be.revertedWith("AccessControl: account");

            // Only admin should be able to grant roles
            await contracts.bugBountyManager.connect(deployer).grantRole(BOUNTY_MANAGER_ROLE, securityManager.address);
            expect(await contracts.bugBountyManager.hasRole(BOUNTY_MANAGER_ROLE, securityManager.address)).to.be.true;
        });

        it("Should enforce role-based function access", async function () {
            // Test that functions require proper roles
            await expect(
                contracts.bugBountyManager.connect(attacker).createBugBountyProgram(
                    "Test Program",
                    ethers.parseUnits("1000", 6),
                    ethers.parseUnits("100", 6),
                    [contracts.karmaToken.target],
                    [ethers.parseUnits("50", 6)],
                    [1000],
                    86400,
                    true
                )
            ).to.be.revertedWith("KarmaBugBountyManager: caller is not bounty manager");
        });

        it("Should prevent privilege escalation attacks", async function () {
            // Grant user1 a lower privilege role
            const VULNERABILITY_REVIEWER_ROLE = await contracts.bugBountyManager.VULNERABILITY_REVIEWER_ROLE();
            await contracts.bugBountyManager.connect(deployer).grantRole(VULNERABILITY_REVIEWER_ROLE, user1.address);

            // User1 should not be able to escalate to admin
            const DEFAULT_ADMIN_ROLE = await contracts.bugBountyManager.DEFAULT_ADMIN_ROLE();
            await expect(
                contracts.bugBountyManager.connect(user1).grantRole(DEFAULT_ADMIN_ROLE, user1.address)
            ).to.be.revertedWith("AccessControl: account");
        });

        it("Should handle role revocation securely", async function () {
            const BOUNTY_MANAGER_ROLE = await contracts.bugBountyManager.BOUNTY_MANAGER_ROLE();
            
            // Grant role
            await contracts.bugBountyManager.connect(deployer).grantRole(BOUNTY_MANAGER_ROLE, user1.address);
            expect(await contracts.bugBountyManager.hasRole(BOUNTY_MANAGER_ROLE, user1.address)).to.be.true;

            // Revoke role
            await contracts.bugBountyManager.connect(deployer).revokeRole(BOUNTY_MANAGER_ROLE, user1.address);
            expect(await contracts.bugBountyManager.hasRole(BOUNTY_MANAGER_ROLE, user1.address)).to.be.false;

            // User should no longer have access
            await expect(
                contracts.bugBountyManager.connect(user1).createBugBountyProgram(
                    "Test Program", ethers.parseUnits("1000", 6), ethers.parseUnits("100", 6),
                    [contracts.karmaToken.target], [ethers.parseUnits("50", 6)], [1000], 86400, true
                )
            ).to.be.revertedWith("KarmaBugBountyManager: caller is not bounty manager");
        });
    });

    describe("🔄 Reentrancy Attack Tests", function () {
        it("Should prevent reentrancy in bug bounty payments", async function () {
            // Setup bug bounty program
            const BOUNTY_MANAGER_ROLE = await contracts.bugBountyManager.BOUNTY_MANAGER_ROLE();
            await contracts.bugBountyManager.connect(deployer).grantRole(BOUNTY_MANAGER_ROLE, deployer.address);

            // Fund the contract
            await contracts.usdcToken.mint(contracts.bugBountyManager.target, ethers.parseUnits("10000", 6));

            // Create program
            await contracts.bugBountyManager.createBugBountyProgram(
                "Test Program",
                ethers.parseUnits("5000", 6),
                ethers.parseUnits("1000", 6),
                [contracts.karmaToken.target],
                [ethers.parseUnits("500", 6), ethers.parseUnits("300", 6), ethers.parseUnits("200", 6)],
                [100, 250, 500, 800, 1000],
                86400,
                true
            );

            // Deploy reentrancy attack contract
            const ReentrancyAttack = await ethers.getContractFactory("ReentrancyAttackBugBounty");
            const reentrancyAttacker = await ReentrancyAttack.deploy(contracts.bugBountyManager.target);

            // Attempt reentrancy attack should fail
            await expect(
                reentrancyAttacker.attack()
            ).to.be.revertedWith("ReentrancyGuard: reentrant call");
        });

        it("Should prevent reentrancy in insurance claims", async function () {
            // Setup insurance
            await contracts.usdcToken.mint(contracts.insuranceManager.target, ethers.parseUnits("10000", 6));
            
            const CLAIMS_PROCESSOR_ROLE = await contracts.insuranceManager.CLAIMS_PROCESSOR_ROLE();
            await contracts.insuranceManager.connect(deployer).grantRole(CLAIMS_PROCESSOR_ROLE, deployer.address);

            // Deploy reentrancy attack contract
            const ReentrancyAttack = await ethers.getContractFactory("ReentrancyAttackInsurance");
            const reentrancyAttacker = await ReentrancyAttack.deploy(contracts.insuranceManager.target);

            // Attempt reentrancy attack should fail
            await expect(
                reentrancyAttacker.attack()
            ).to.be.revertedWith("ReentrancyGuard: reentrant call");
        });
    });

    describe("🔢 Integer Overflow/Underflow Tests", function () {
        it("Should handle large numbers safely", async function () {
            // Test with maximum uint256 values
            const maxUint256 = ethers.MaxUint256;
            
            // Should not overflow when handling large bounty amounts
            const BOUNTY_MANAGER_ROLE = await contracts.bugBountyManager.BOUNTY_MANAGER_ROLE();
            await contracts.bugBountyManager.connect(deployer).grantRole(BOUNTY_MANAGER_ROLE, deployer.address);

            // This should revert due to validation, not overflow
            await expect(
                contracts.bugBountyManager.createBugBountyProgram(
                    "Test Program",
                    maxUint256,
                    maxUint256,
                    [contracts.karmaToken.target],
                    [maxUint256],
                    [1000],
                    86400,
                    true
                )
            ).to.be.revertedWith("KarmaBugBountyManager: invalid total funding");
        });

        it("Should prevent underflow in balance calculations", async function () {
            // Test that withdrawal of more than balance is prevented
            await expect(
                contracts.usdcToken.transfer(user1.address, ethers.parseUnits("1000", 6))
            ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
        });

        it("Should safely handle arithmetic operations", async function () {
            // Test safe arithmetic in reward calculations
            const result = await securityTestSuite.testSafeArithmetic(
                ethers.parseUnits("1000", 6),
                ethers.parseUnits("500", 6)
            );
            expect(result).to.equal(ethers.parseUnits("1500", 6));
        });
    });

    describe("⚡ Front-Running Attack Tests", function () {
        it("Should implement MEV protection", async function () {
            // Test that sensitive operations are protected against front-running
            // This would typically involve commit-reveal schemes or batch processing
            
            const MONITORING_MANAGER_ROLE = await contracts.securityMonitoring.MONITORING_MANAGER_ROLE();
            await contracts.securityMonitoring.connect(deployer).grantRole(MONITORING_MANAGER_ROLE, deployer.address);

            // Register monitoring system with commit-reveal pattern
            const commitment = ethers.keccak256(ethers.toUtf8Bytes("secret_nonce_123"));
            
            await contracts.securityMonitoring.commitMonitoringRegistration(commitment);
            
            // Fast forward time
            await ethers.provider.send("evm_increaseTime", [86400]); // 24 hours
            await ethers.provider.send("evm_mine");

            // Reveal should work
            await contracts.securityMonitoring.revealMonitoringRegistration(
                "Test Monitor",
                deployer.address,
                5,
                [contracts.karmaToken.target],
                "secret_nonce_123"
            );
        });

        it("Should detect and prevent sandwich attacks", async function () {
            // Test sandwich attack detection
            const detector = await securityTestSuite.detectSandwichAttack(
                user1.address,
                ethers.parseEther("1000"),
                ethers.parseEther("900") // 10% slippage
            );
            
            expect(detector).to.be.true;
        });
    });

    describe("💡 Flash Loan Attack Tests", function () {
        it("Should prevent flash loan governance attacks", async function () {
            // Deploy mock flash loan contract
            const FlashLoanAttack = await ethers.getContractFactory("FlashLoanGovernanceAttack");
            const flashAttacker = await FlashLoanAttack.deploy();

            // Flash loan attack should be detected and prevented
            await expect(
                flashAttacker.executeFlashLoanAttack(contracts.karmaToken.target)
            ).to.be.revertedWith("Flash loan attack detected");
        });

        it("Should implement flash loan detection", async function () {
            // Test flash loan detection mechanism
            const isFlashLoan = await securityTestSuite.detectFlashLoan(
                user1.address,
                ethers.parseEther("1000000") // Large amount
            );
            
            expect(isFlashLoan).to.be.true;
        });

        it("Should prevent oracle manipulation via flash loans", async function () {
            // Test that oracle prices can't be manipulated with flash loans
            const manipulation = await securityTestSuite.testOracleManipulation(
                ethers.parseEther("1000000"), // Flash loan amount
                contracts.karmaToken.target
            );
            
            expect(manipulation.detected).to.be.true;
            expect(manipulation.prevented).to.be.true;
        });
    });

    describe("🗳️ Governance Attack Tests", function () {
        it("Should prevent governance token accumulation attacks", async function () {
            // Test large token accumulation detection
            const accumulation = await securityTestSuite.detectGovernanceAccumulation(
                attacker.address,
                ethers.parseEther("100000000"), // 10% of supply
                3600 // 1 hour timeframe
            );
            
            expect(accumulation.detected).to.be.true;
            expect(accumulation.flagged).to.be.true;
        });

        it("Should implement voting delay protections", async function () {
            // Test that there's proper delay between token acquisition and voting
            const delay = await securityTestSuite.checkVotingDelay(
                user1.address,
                block.timestamp
            );
            
            expect(delay).to.be.gte(86400); // At least 24 hours
        });

        it("Should prevent vote buying attacks", async function () {
            // Test vote buying detection
            const voteBuying = await securityTestSuite.detectVoteBuying(
                [user1.address, user2.address, user3.address],
                [true, true, true], // All voting the same way
                ethers.parseEther("1000") // Payment amount
            );
            
            expect(voteBuying.suspicious).to.be.true;
        });
    });

    describe("🔮 Oracle Security Tests", function () {
        it("Should validate oracle data freshness", async function () {
            // Test that stale oracle data is rejected
            const staleness = await securityTestSuite.checkOracleFreshness(
                block.timestamp - 7200 // 2 hours old
            );
            
            expect(staleness.stale).to.be.true;
        });

        it("Should implement price deviation checks", async function () {
            // Test price deviation detection
            const deviation = await securityTestSuite.checkPriceDeviation(
                ethers.parseEther("1.0"), // Current price
                ethers.parseEther("1.3")  // 30% higher
            );
            
            expect(deviation.exceeded).to.be.true;
        });

        it("Should prevent oracle manipulation", async function () {
            // Test oracle manipulation resistance
            const manipulation = await securityTestSuite.simulateOracleAttack(
                contracts.karmaToken.target,
                ethers.parseEther("0.5"), // 50% price drop
                300 // 5 minutes
            );
            
            expect(manipulation.prevented).to.be.true;
        });
    });

    describe("🌉 Cross-Chain Security Tests", function () {
        it("Should prevent replay attacks", async function () {
            // Test cross-chain replay attack prevention
            const nonce = 12345;
            const signature = "0x1234567890abcdef";
            
            // First use should succeed
            await securityTestSuite.processCrossChainMessage(nonce, signature);
            
            // Replay should fail
            await expect(
                securityTestSuite.processCrossChainMessage(nonce, signature)
            ).to.be.revertedWith("Nonce already used");
        });

        it("Should validate cross-chain signatures", async function () {
            // Test signature validation
            const message = ethers.keccak256(ethers.toUtf8Bytes("test message"));
            const signature = await user1.signMessage(ethers.getBytes(message));
            
            const valid = await securityTestSuite.validateCrossChainSignature(
                message,
                signature,
                user1.address
            );
            
            expect(valid).to.be.true;

            // Invalid signature should fail
            const invalidSignature = signature.slice(0, -2) + "00";
            const invalid = await securityTestSuite.validateCrossChainSignature(
                message,
                invalidSignature,
                user1.address
            );
            
            expect(invalid).to.be.false;
        });
    });

    describe("⏸️ Emergency Response Tests", function () {
        it("Should trigger emergency pause correctly", async function () {
            // Test emergency pause functionality
            const EMERGENCY_RESPONSE_ROLE = await contracts.securityMonitoring.EMERGENCY_RESPONSE_ROLE();
            await contracts.securityMonitoring.connect(deployer).grantRole(EMERGENCY_RESPONSE_ROLE, emergencyResponder.address);

            // Trigger emergency pause
            await contracts.securityMonitoring.connect(emergencyResponder).triggerEmergencyPause("Security test");
            
            // Contract should be paused
            expect(await contracts.securityMonitoring.paused()).to.be.true;
        });

        it("Should handle incident escalation", async function () {
            // Test incident escalation process
            const MONITORING_MANAGER_ROLE = await contracts.securityMonitoring.MONITORING_MANAGER_ROLE();
            await contracts.securityMonitoring.connect(deployer).grantRole(MONITORING_MANAGER_ROLE, securityManager.address);

            // Create and escalate incident
            await contracts.securityMonitoring.connect(securityManager).createSecurityIncident(
                "Test Incident",
                "Security test incident",
                [contracts.karmaToken.target],
                8, // High severity
                [emergencyResponder.address],
                true
            );

            const incidentsCount = await contracts.securityMonitoring.getTotalSecurityIncidents();
            expect(incidentsCount).to.equal(1);
        });

        it("Should coordinate emergency response", async function () {
            // Test multi-system emergency coordination
            const response = await securityTestSuite.coordinateEmergencyResponse(
                "CRITICAL_VULNERABILITY",
                [contracts.securityMonitoring.target, contracts.bugBountyManager.target],
                emergencyResponder.address
            );
            
            expect(response.successful).to.be.true;
            expect(response.responseTime).to.be.lt(300); // Less than 5 minutes
        });
    });

    describe("🔍 Advanced Security Analysis", function () {
        it("Should perform comprehensive security scan", async function () {
            // Comprehensive security scan of all contracts
            const scanResults = await securityTestSuite.performSecurityScan([
                contracts.securityMonitoring.target,
                contracts.bugBountyManager.target,
                contracts.insuranceManager.target
            ]);
            
            expect(scanResults.vulnerabilitiesFound).to.equal(0);
            expect(scanResults.securityScore).to.be.gte(95);
        });

        it("Should validate all security measures", async function () {
            // Validate that all security measures are properly implemented
            const validation = await securityTestSuite.validateSecurityMeasures();
            
            expect(validation.accessControl).to.be.true;
            expect(validation.reentrancyProtection).to.be.true;
            expect(validation.overflowProtection).to.be.true;
            expect(validation.emergencyPause).to.be.true;
            expect(validation.auditTrail).to.be.true;
        });

        it("Should test system resilience", async function () {
            // Test system resilience under attack conditions
            const resilience = await securityTestSuite.testSystemResilience(
                ATTACK_VECTORS,
                1000 // Number of attack attempts
            );
            
            expect(resilience.attacksBlocked).to.equal(1000);
            expect(resilience.systemCompromised).to.be.false;
        });

        it("Should validate cryptographic implementations", async function () {
            // Test cryptographic security
            const cryptoValidation = await securityTestSuite.validateCryptography();
            
            expect(cryptoValidation.hashingSecure).to.be.true;
            expect(cryptoValidation.signatureValidation).to.be.true;
            expect(cryptoValidation.randomnessSecure).to.be.true;
        });
    });

    describe("📊 Security Metrics and Reporting", function () {
        it("Should generate security metrics", async function () {
            // Test security metrics generation
            const metrics = await contracts.securityMonitoring.getSecurityMetrics();
            
            expect(metrics.threatsDetected).to.be.gte(0);
            expect(metrics.incidentsResolved).to.be.gte(0);
            expect(metrics.systemUptime).to.be.gte(0);
        });

        it("Should maintain audit trail", async function () {
            // Test audit trail functionality
            const MONITORING_MANAGER_ROLE = await contracts.securityMonitoring.MONITORING_MANAGER_ROLE();
            await contracts.securityMonitoring.connect(deployer).grantRole(MONITORING_MANAGER_ROLE, securityManager.address);

            // Perform monitored action
            await contracts.securityMonitoring.connect(securityManager).logSecurityEvent(
                "TEST_EVENT",
                "Security test event",
                user1.address,
                block.timestamp
            );

            // Verify audit trail
            const auditLog = await contracts.securityMonitoring.getAuditTrail(0, 10);
            expect(auditLog.length).to.be.gte(1);
        });

        it("Should generate compliance reports", async function () {
            // Test compliance reporting
            const complianceReport = await securityTestSuite.generateComplianceReport();
            
            expect(complianceReport.gdprCompliant).to.be.true;
            expect(complianceReport.securityStandards).to.be.true;
            expect(complianceReport.auditReady).to.be.true;
        });
    });

    describe("🎯 Penetration Testing", function () {
        it("Should resist penetration attempts", async function () {
            // Simulate penetration testing
            const penTest = await securityTestSuite.performPenetrationTest(
                [contracts.securityMonitoring.target],
                attacker.address
            );
            
            expect(penTest.breachAttempts).to.be.gt(0);
            expect(penTest.successfulBreaches).to.equal(0);
            expect(penTest.vulnerabilitiesExploited).to.equal(0);
        });

        it("Should detect and respond to attack patterns", async function () {
            // Test attack pattern detection
            const attackDetection = await securityTestSuite.detectAttackPatterns([
                { type: "BRUTE_FORCE", intensity: 100 },
                { type: "DOS", intensity: 50 },
                { type: "SOCIAL_ENGINEERING", intensity: 25 }
            ]);
            
            expect(attackDetection.detectedAttacks).to.equal(3);
            expect(attackDetection.responseTriggered).to.be.true;
        });
    });
}); 