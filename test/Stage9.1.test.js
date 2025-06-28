const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 9.1 Security Audit and Hardening", function () {
    let admin, user1, user2, user3, auditor, bountyManager, insuranceManagerSigner, monitoringManager;
    let karmaToken, usdcToken, treasury;
    let securityManager, insuranceManager, bugBountyManager, securityMonitoring;
    
    const INSURANCE_FUND_TARGET = ethers.parseUnits("675000", 6); // $675K USDC
    const MAX_BOUNTY_REWARD = ethers.parseUnits("200000", 6); // $200K max bounty
    const MIN_BOUNTY_REWARD = ethers.parseUnits("100", 6); // $100 min bounty
    
    beforeEach(async function () {
        [admin, user1, user2, user3, auditor, bountyManager, insuranceManagerSigner, monitoringManager] = await ethers.getSigners();
        
        // Deploy mock tokens
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        karmaToken = await MockERC20.deploy("Karma Token", "KARMA", 18);
        usdcToken = await MockERC20.deploy("USD Coin", "USDC", 6);
        
        // Deploy mock treasury
        const MockTreasury = await ethers.getContractFactory("MockContract");
        treasury = await MockTreasury.deploy();
        
        // Mint tokens for testing
        await karmaToken.mint(admin.address, ethers.parseUnits("1000000", 18));
        await usdcToken.mint(admin.address, ethers.parseUnits("2000000", 6));
        await usdcToken.mint(treasury.address, ethers.parseUnits("1000000", 6));
        
        // Deploy Stage 9.1 contracts
        
        // Deploy Security Manager
        const KarmaSecurityManager = await ethers.getContractFactory("KarmaSecurityManager");
        securityManager = await KarmaSecurityManager.deploy(
            treasury.address,
            karmaToken.address,
            usdcToken.address,
            admin.address
        );
        
        // Deploy Insurance Manager
        const KarmaInsuranceManager = await ethers.getContractFactory("KarmaInsuranceManager");
        insuranceManager = await KarmaInsuranceManager.deploy(
            treasury.address,
            usdcToken.address,
            karmaToken.address,
            admin.address
        );
        
        // Deploy Bug Bounty Manager
        const KarmaBugBountyManager = await ethers.getContractFactory("KarmaBugBountyManager");
        bugBountyManager = await KarmaBugBountyManager.deploy(
            usdcToken.address,
            karmaToken.address,
            admin.address
        );
        
        // Deploy Security Monitoring
        const KarmaSecurityMonitoring = await ethers.getContractFactory("KarmaSecurityMonitoring");
        securityMonitoring = await KarmaSecurityMonitoring.deploy(admin.address);
        
        // Grant necessary roles
        await securityManager.grantRole(await securityManager.AUDIT_MANAGER_ROLE(), auditor.address);
        await securityManager.grantRole(await securityManager.BOUNTY_MANAGER_ROLE(), bountyManager.address);
        
        await insuranceManager.grantRole(await insuranceManager.INSURANCE_MANAGER_ROLE(), insuranceManagerSigner.address);
        await insuranceManager.grantRole(await insuranceManager.CLAIMS_PROCESSOR_ROLE(), admin.address);
        
        await bugBountyManager.grantRole(await bugBountyManager.BOUNTY_MANAGER_ROLE(), bountyManager.address);
        await bugBountyManager.grantRole(await bugBountyManager.VULNERABILITY_REVIEWER_ROLE(), admin.address);
        
        await securityMonitoring.grantRole(await securityMonitoring.MONITORING_MANAGER_ROLE(), monitoringManager.address);
        await securityMonitoring.grantRole(await securityMonitoring.THREAT_ANALYST_ROLE(), admin.address);
        
        // Approve tokens for transfers
        await usdcToken.approve(securityManager.address, ethers.parseUnits("1000000", 6));
        await usdcToken.approve(insuranceManager.address, ethers.parseUnits("1000000", 6));
        await usdcToken.approve(bugBountyManager.address, ethers.parseUnits("1000000", 6));
        
        await usdcToken.connect(treasury).approve(securityManager.address, ethers.parseUnits("1000000", 6));
        await usdcToken.connect(treasury).approve(insuranceManager.address, ethers.parseUnits("1000000", 6));
    });
    
    describe("Security Manager", function () {
        it("Should create threat model successfully", async function () {
            const attackVectors = ["Reentrancy", "Flash loan attack"];
            const riskLevels = [1, 3]; // MEDIUM, CRITICAL
            const mitigations = ["Reentrancy guard", "Flash loan protection"];
            
            const tx = await securityManager.connect(auditor).createThreatModel(
                user1.address,
                attackVectors,
                riskLevels,
                mitigations
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("ThreatModelCreated(uint256,address,address,bytes32)"));
            expect(event).to.not.be.undefined;
            
            const threatModel = await securityManager.getThreatModel(user1.address);
            expect(threatModel.targetContract).to.equal(user1.address);
            expect(threatModel.attackVectors.length).to.equal(2);
        });
        
        it("Should generate audit documentation", async function () {
            const contracts = [user1.address, user2.address];
            
            const tx = await securityManager.connect(auditor).generateAuditDocumentation(contracts);
            const receipt = await tx.wait();
            
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("AuditDocumentationGenerated(bytes32,address[],uint256)"));
            expect(event).to.not.be.undefined;
        });
        
        it("Should implement security measures", async function () {
            const findings = ["Fix reentrancy", "Add access control"];
            const priorities = [3, 2]; // CRITICAL, HIGH
            
            await expect(
                securityManager.connect(auditor).implementSecurityMeasures(findings, priorities)
            ).to.not.be.reverted;
        });
        
        it("Should start automated testing", async function () {
            const testSuite = "Comprehensive Security Test";
            const contracts = [user1.address, user2.address];
            
            await expect(
                securityManager.connect(auditor).startAutomatedTesting(testSuite, contracts)
            ).to.not.be.reverted;
        });
        
        it("Should create bug bounty program", async function () {
            const maxReward = ethers.parseUnits("50000", 6);
            const categoryRewards = new Array(10).fill(ethers.parseUnits("5000", 6));
            const severityMultipliers = [100, 250, 500, 750, 1000]; // 10%, 25%, 50%, 75%, 100%
            
            const tx = await securityManager.connect(bountyManager).createBugBountyProgram(
                maxReward,
                categoryRewards,
                severityMultipliers
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("BugBountyProgramCreated(uint256,uint256,uint256)"));
            expect(event).to.not.be.undefined;
        });
        
        it("Should submit and process vulnerability report", async function () {
            // First create a bug bounty program
            const maxReward = ethers.parseUnits("50000", 6);
            const categoryRewards = new Array(10).fill(ethers.parseUnits("5000", 6));
            const severityMultipliers = [100, 250, 500, 750, 1000];
            
            await securityManager.connect(bountyManager).createBugBountyProgram(
                maxReward,
                categoryRewards,
                severityMultipliers
            );
            
            // Submit vulnerability report
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("proof of vulnerability"));
            
            const submitTx = await securityManager.submitVulnerabilityReport(
                0, // ACCESS_CONTROL
                2, // HIGH
                "Critical Access Control Bug",
                "Detailed description of the vulnerability",
                proofHash
            );
            
            const submitReceipt = await submitTx.wait();
            const submitEvent = submitReceipt.logs.find(log => log.topics[0] === ethers.id("VulnerabilityReported(uint256,address,uint8,uint8)"));
            expect(submitEvent).to.not.be.undefined;
            
            // Process vulnerability report
            const bountyAmount = ethers.parseUnits("10000", 6);
            await expect(
                securityManager.processVulnerabilityReport(1, true, bountyAmount)
            ).to.not.be.reverted;
        });
        
        it("Should get security metrics", async function () {
            const metrics = await securityManager.getSecurityMetrics();
            expect(metrics.securityScore).to.be.greaterThan(0);
        });
    });
    
    describe("Insurance Manager", function () {
        it("Should allocate insurance fund", async function () {
            const amount = ethers.parseUnits("100000", 6);
            
            await expect(
                insuranceManager.connect(insuranceManagerSigner).allocateInsuranceFund(amount)
            ).to.not.be.reverted;
            
            const metrics = await insuranceManager.getInsuranceFundMetrics();
            expect(metrics.totalAllocated).to.equal(amount);
        });
        
        it("Should submit and process insurance claim", async function () {
            // Allocate fund first
            const fundAmount = ethers.parseUnits("100000", 6);
            await insuranceManager.connect(insuranceManagerSigner).allocateInsuranceFund(fundAmount);
            
            // Submit claim
            const claimAmount = ethers.parseUnits("5000", 6);
            const description = "Smart contract exploit loss";
            const evidenceHash = ethers.keccak256(ethers.toUtf8Bytes("evidence"));
            
            const submitTx = await insuranceManager.submitInsuranceClaim(
                claimAmount,
                0, // SMART_CONTRACT_RISK
                description,
                evidenceHash
            );
            
            const receipt = await submitTx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("InsuranceClaimSubmitted(uint256,address,uint256,uint8,uint256)"));
            expect(event).to.not.be.undefined;
            
            // Fast forward time to pass review period
            await network.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]); // 7 days
            await network.provider.send("evm_mine");
            
            // Process claim
            const payoutAmount = ethers.parseUnits("4000", 6);
            await expect(
                insuranceManager.processInsuranceClaim(
                    1,
                    2, // APPROVED
                    payoutAmount,
                    "Claim approved after investigation"
                )
            ).to.not.be.reverted;
        });
        
        it("Should create risk assessment", async function () {
            const coverageTypes = [0, 1]; // SMART_CONTRACT_RISK, ORACLE_RISK
            const coverageAmount = ethers.parseUnits("50000", 6);
            const premium = ethers.parseUnits("500", 6);
            
            await expect(
                insuranceManager.createRiskAssessment(
                    user1.address,
                    2, // HIGH
                    coverageTypes,
                    coverageAmount,
                    premium,
                    "High risk due to complex logic",
                    "Implement additional testing"
                )
            ).to.not.be.reverted;
        });
        
        it("Should integrate insurance protocol", async function () {
            const protocolAddress = user3.address;
            const protocolName = "Nexus Mutual";
            const coverageAmount = ethers.parseUnits("100000", 6);
            const premium = ethers.parseUnits("1000", 6);
            const supportedCoverage = [0, 1, 2]; // Multiple coverage types
            
            await expect(
                insuranceManager.integrateInsuranceProtocol(
                    protocolAddress,
                    protocolName,
                    coverageAmount,
                    premium,
                    supportedCoverage
                )
            ).to.not.be.reverted;
        });
    });
    
    describe("Bug Bounty Manager", function () {
        beforeEach(async function () {
            // Register a security researcher
            await bugBountyManager.connect(user1).registerSecurityResearcher(
                "hacker1",
                "hacker1@example.com",
                ["Reentrancy", "Access Control"]
            );
        });
        
        it("Should register security researcher", async function () {
            const researcher = await bugBountyManager.getSecurityResearcher(user1.address);
            expect(researcher.handle).to.equal("hacker1");
            expect(researcher.tier).to.equal(0); // NEWCOMER
        });
        
        it("Should create bug bounty program", async function () {
            const programName = "Karma Labs Bug Bounty";
            const totalFunding = ethers.parseUnits("100000", 6);
            const maxReward = ethers.parseUnits("50000", 6);
            const targetContracts = [user1.address, user2.address];
            const categoryRewards = new Array(12).fill(ethers.parseUnits("5000", 6));
            const severityMultipliers = [100, 250, 500, 750, 1000];
            const duration = 30 * 24 * 60 * 60; // 30 days
            
            const tx = await bugBountyManager.connect(bountyManager).createBugBountyProgram(
                programName,
                totalFunding,
                maxReward,
                targetContracts,
                categoryRewards,
                severityMultipliers,
                duration,
                false, // not immunefi integrated
                ""
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("BugBountyProgramCreated(uint256,string,uint256,uint256,bool)"));
            expect(event).to.not.be.undefined;
        });
        
        it("Should submit and review vulnerability report", async function () {
            // Create program first
            await bugBountyManager.connect(bountyManager).createBugBountyProgram(
                "Test Program",
                ethers.parseUnits("100000", 6),
                ethers.parseUnits("50000", 6),
                [user1.address],
                new Array(12).fill(ethers.parseUnits("5000", 6)),
                [100, 250, 500, 750, 1000],
                30 * 24 * 60 * 60,
                false,
                ""
            );
            
            // Submit vulnerability report
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("vulnerability proof"));
            
            const submitTx = await bugBountyManager.connect(user1).submitVulnerabilityReport(
                0, // ACCESS_CONTROL
                3, // HIGH
                "Critical Access Control Vulnerability",
                "Detailed vulnerability description",
                proofHash,
                [user1.address]
            );
            
            const submitReceipt = await submitTx.wait();
            const submitEvent = submitReceipt.logs.find(log => log.topics[0] === ethers.id("VulnerabilityReportSubmitted(uint256,address,uint8,uint8,uint256)"));
            expect(submitEvent).to.not.be.undefined;
            
            // Review vulnerability report
            const bountyAmount = ethers.parseUnits("10000", 6);
            await expect(
                bugBountyManager.reviewVulnerabilityReport(
                    1,
                    3, // CONFIRMED
                    bountyAmount,
                    "Vulnerability confirmed and bounty awarded"
                )
            ).to.not.be.reverted;
        });
        
        it("Should submit patch and coordinate disclosure", async function () {
            // Create program and submit report first
            await bugBountyManager.connect(bountyManager).createBugBountyProgram(
                "Test Program",
                ethers.parseUnits("100000", 6),
                ethers.parseUnits("50000", 6),
                [user1.address],
                new Array(12).fill(ethers.parseUnits("5000", 6)),
                [100, 250, 500, 750, 1000],
                30 * 24 * 60 * 60,
                false,
                ""
            );
            
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("vulnerability proof"));
            await bugBountyManager.connect(user1).submitVulnerabilityReport(
                0, 3, "Test Vulnerability", "Description", proofHash, [user1.address]
            );
            
            // Confirm vulnerability
            await bugBountyManager.reviewVulnerabilityReport(
                1, 3, ethers.parseUnits("10000", 6), "Confirmed"
            );
            
            // Submit patch
            const patchHash = ethers.keccak256(ethers.toUtf8Bytes("patch code"));
            await expect(
                bugBountyManager.submitPatch(1, patchHash, "Vulnerability patched")
            ).to.not.be.reverted;
            
            // Coordinate disclosure
            await expect(
                bugBountyManager.coordinateDisclosure(
                    1,
                    1, // COORDINATED
                    "Public disclosure of vulnerability",
                    0
                )
            ).to.not.be.reverted;
        });
        
        it("Should get community metrics", async function () {
            const metrics = await bugBountyManager.getCommunityMetrics();
            expect(metrics.totalResearchers).to.be.greaterThan(0);
        });
    });
    
    describe("Security Monitoring", function () {
        it("Should register monitoring system", async function () {
            const monitoredContracts = [user1.address, user2.address];
            const alertTypes = ["Unusual Volume", "Suspicious Activity"];
            
            const tx = await securityMonitoring.connect(monitoringManager).registerMonitoringSystem(
                0, // FORTA
                "Forta Network Monitor",
                user3.address,
                8, // priority
                monitoredContracts,
                alertTypes,
                "Forta agent configuration",
                "0x1234"
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("MonitoringSystemRegistered(uint256,uint8,address,string,uint256)"));
            expect(event).to.not.be.undefined;
        });
        
        it("Should report threat detection", async function () {
            // Register monitoring system first
            await securityMonitoring.connect(monitoringManager).registerMonitoringSystem(
                0, "Forta Monitor", user3.address, 8, [user1.address], ["Threat"], "config", "0x1234"
            );
            
            // Report threat
            const tx = await securityMonitoring.connect(user3).reportThreatDetection(
                2, // HIGH
                0, // UNUSUAL_TRANSACTION_VOLUME
                user1.address,
                "Unusual transaction volume detected",
                "0xevidence",
                750 // risk score
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("ThreatDetected(uint256,address,uint8,uint8,address,uint256)"));
            expect(event).to.not.be.undefined;
        });
        
        it("Should confirm threat detection", async function () {
            // Register system and report threat
            await securityMonitoring.connect(monitoringManager).registerMonitoringSystem(
                0, "Forta Monitor", user3.address, 8, [user1.address], ["Threat"], "config", "0x1234"
            );
            
            await securityMonitoring.connect(user3).reportThreatDetection(
                2, 0, user1.address, "Threat detected", "0xevidence", 750
            );
            
            // Confirm threat
            await expect(
                securityMonitoring.confirmThreatDetection(1, true, "Threat confirmed")
            ).to.not.be.reverted;
        });
        
        it("Should create security incident", async function () {
            const affectedContracts = [user1.address, user2.address];
            
            const tx = await securityMonitoring.createSecurityIncident(
                3, // CRITICAL
                "Critical Security Incident",
                "System compromise detected",
                affectedContracts,
                true // requires forensics
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.topics[0] === ethers.id("SecurityIncidentCreated(uint256,uint8,string,address[],uint256)"));
            expect(event).to.not.be.undefined;
        });
        
        it("Should start forensic investigation", async function () {
            // Create incident first
            await securityMonitoring.createSecurityIncident(
                3, "Test Incident", "Description", [user1.address], true
            );
            
            await expect(
                securityMonitoring.startForensicInvestigation(
                    1,
                    0, // TRANSACTION_ANALYSIS
                    "Detailed transaction analysis methodology"
                )
            ).to.not.be.reverted;
        });
        
        it("Should update security dashboard", async function () {
            await expect(
                securityMonitoring.updateSecurityDashboard()
            ).to.not.be.reverted;
            
            const dashboard = await securityMonitoring.getSecurityDashboard();
            expect(dashboard.securityScore).to.be.greaterThan(0);
        });
        
        it("Should get monitoring metrics", async function () {
            const metrics = await securityMonitoring.getMonitoringMetrics();
            expect(metrics.totalDetections).to.be.greaterThanOrEqual(0);
        });
    });
    
    describe("Integration Tests", function () {
        it("Should handle end-to-end security workflow", async function () {
            // 1. Create threat model
            await securityManager.connect(auditor).createThreatModel(
                user1.address,
                ["Reentrancy"],
                [3],
                ["Use reentrancy guard"]
            );
            
            // 2. Register monitoring
            await securityMonitoring.connect(monitoringManager).registerMonitoringSystem(
                0, "Integrated Monitor", user3.address, 9, [user1.address], ["All"], "config", "0x1234"
            );
            
            // 3. Detect threat
            await securityMonitoring.connect(user3).reportThreatDetection(
                3, 0, user1.address, "Critical threat", "0xevidence", 900
            );
            
            // 4. Allocate insurance fund
            await insuranceManager.connect(insuranceManagerSigner).allocateInsuranceFund(
                ethers.parseUnits("50000", 6)
            );
            
            // 5. Create bug bounty program
            await bugBountyManager.connect(bountyManager).createBugBountyProgram(
                "Emergency Bounty",
                ethers.parseUnits("50000", 6),
                ethers.parseUnits("25000", 6),
                [user1.address],
                new Array(12).fill(ethers.parseUnits("2000", 6)),
                [100, 250, 500, 750, 1000],
                7 * 24 * 60 * 60,
                false,
                ""
            );
            
            // Verify all systems are operational
            const securityMetrics = await securityManager.getSecurityMetrics();
            const insuranceMetrics = await insuranceManager.getInsuranceFundMetrics();
            const monitoringMetrics = await securityMonitoring.getMonitoringMetrics();
            
            expect(securityMetrics.securityScore).to.be.greaterThan(0);
            expect(insuranceMetrics.totalAllocated).to.be.greaterThan(0);
            expect(monitoringMetrics.totalDetections).to.be.greaterThan(0);
        });
        
        it("Should handle vulnerability discovery and response", async function () {
            // Register researcher
            await bugBountyManager.connect(user1).registerSecurityResearcher(
                "security_expert", "expert@security.com", ["All vulnerabilities"]
            );
            
            // Create bounty program
            await bugBountyManager.connect(bountyManager).createBugBountyProgram(
                "Critical Response Program",
                ethers.parseUnits("100000", 6),
                ethers.parseUnits("50000", 6),
                [user1.address],
                new Array(12).fill(ethers.parseUnits("5000", 6)),
                [100, 250, 500, 750, 1000],
                30 * 24 * 60 * 60,
                false,
                ""
            );
            
            // Submit vulnerability
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("critical vulnerability"));
            await bugBountyManager.connect(user1).submitVulnerabilityReport(
                0, 4, "Critical System Vulnerability", "System-wide vulnerability", proofHash, [user1.address]
            );
            
            // Confirm vulnerability
            await bugBountyManager.reviewVulnerabilityReport(
                1, 3, ethers.parseUnits("25000", 6), "Critical vulnerability confirmed"
            );
            
            // Create security incident
            await securityMonitoring.createSecurityIncident(
                4, "Critical Vulnerability Response", "Emergency response required", [user1.address], true
            );
            
            // Submit patch
            const patchHash = ethers.keccak256(ethers.toUtf8Bytes("emergency patch"));
            await bugBountyManager.submitPatch(1, patchHash, "Emergency patch deployed");
            
            // Process insurance claim if needed
            await insuranceManager.connect(insuranceManagerSigner).allocateInsuranceFund(
                ethers.parseUnits("100000", 6)
            );
            
            // Verify vulnerability resolved
            const report = await bugBountyManager.getVulnerabilityReport(1);
            expect(report.isPaid).to.be.true;
            expect(report.bountyAmount).to.equal(ethers.parseUnits("25000", 6));
        });
    });
    
    describe("Emergency Functions", function () {
        it("Should handle emergency pause/unpause", async function () {
            await expect(securityManager.emergencyPause()).to.not.be.reverted;
            await expect(securityManager.emergencyUnpause()).to.not.be.reverted;
            
            await expect(insuranceManager.emergencyPause()).to.not.be.reverted;
            await expect(insuranceManager.emergencyUnpause()).to.not.be.reverted;
            
            await expect(bugBountyManager.emergencyPause()).to.not.be.reverted;
            await expect(bugBountyManager.emergencyUnpause()).to.not.be.reverted;
            
            await expect(securityMonitoring.emergencyPause()).to.not.be.reverted;
            await expect(securityMonitoring.emergencyUnpause()).to.not.be.reverted;
        });
        
        it("Should handle emergency fund withdrawals", async function () {
            // Allocate funds first
            await insuranceManager.connect(insuranceManagerSigner).allocateInsuranceFund(
                ethers.parseUnits("10000", 6)
            );
            
            // Emergency withdrawal
            await expect(
                insuranceManager.emergencyWithdraw(admin.address, ethers.parseUnits("5000", 6))
            ).to.not.be.reverted;
        });
    });
    
    describe("Security Metrics and Reporting", function () {
        it("Should track comprehensive security metrics", async function () {
            // Generate some activity
            await securityManager.connect(auditor).createThreatModel(
                user1.address, ["Test"], [1], ["Test mitigation"]
            );
            
            await insuranceManager.connect(insuranceManagerSigner).allocateInsuranceFund(
                ethers.parseUnits("50000", 6)
            );
            
            // Check metrics
            const securityMetrics = await securityManager.getSecurityMetrics();
            const insuranceMetrics = await insuranceManager.getInsuranceFundMetrics();
            
            expect(securityMetrics.totalThreatModels).to.be.greaterThan(0);
            expect(insuranceMetrics.totalAllocated).to.be.greaterThan(0);
        });
        
        it("Should provide security dashboard updates", async function () {
            await securityMonitoring.updateSecurityDashboard();
            
            const dashboard = await securityMonitoring.getSecurityDashboard();
            expect(dashboard.lastUpdated).to.be.greaterThan(0);
            expect(dashboard.securityScore).to.be.greaterThan(0);
        });
    });
}); 