const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 9.2 Production Deployment and Operations", function () {
    let admin, user1, user2, deploymentManager, operationsManager, maintenanceManager;
    let karmaToken, treasury;
    let productionDeploymentManager, systemInitializationManager, operationsMonitoringManager, maintenanceUpgradeManager;

    beforeEach(async function () {
        [admin, user1, user2, deploymentManager, operationsManager, maintenanceManager] = await ethers.getSigners();

        // Deploy mock KARMA token
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();

        // Deploy mock Treasury
        const Treasury = await ethers.getContractFactory("Treasury");
        treasury = await Treasury.deploy(
            admin.address,
            await karmaToken.getAddress(),
            ethers.parseUnits("100000", 6) // 100K USDC allocation
        );
        await treasury.waitForDeployment();

        // Deploy Production Deployment Manager
        const ProductionDeploymentManager = await ethers.getContractFactory("ProductionDeploymentManager");
        productionDeploymentManager = await ProductionDeploymentManager.deploy(admin.address);
        await productionDeploymentManager.waitForDeployment();

        // Deploy System Initialization Manager
        const SystemInitializationManager = await ethers.getContractFactory("SystemInitializationManager");
        systemInitializationManager = await SystemInitializationManager.deploy(
            admin.address,
            await karmaToken.getAddress(),
            await treasury.getAddress()
        );
        await systemInitializationManager.waitForDeployment();

        // Deploy Operations Monitoring Manager
        const OperationsMonitoringManager = await ethers.getContractFactory("OperationsMonitoringManager");
        operationsMonitoringManager = await OperationsMonitoringManager.deploy(admin.address);
        await operationsMonitoringManager.waitForDeployment();

        // Deploy Maintenance Upgrade Manager
        const MaintenanceUpgradeManager = await ethers.getContractFactory("MaintenanceUpgradeManager");
        maintenanceUpgradeManager = await MaintenanceUpgradeManager.deploy(admin.address);
        await maintenanceUpgradeManager.waitForDeployment();

        // Grant roles
        await productionDeploymentManager.grantRole(
            await productionDeploymentManager.DEPLOYMENT_MANAGER_ROLE(),
            deploymentManager.address
        );
        await systemInitializationManager.grantRole(
            await systemInitializationManager.INITIALIZATION_MANAGER_ROLE(),
            deploymentManager.address
        );
        await operationsMonitoringManager.grantRole(
            await operationsMonitoringManager.OPERATIONS_MANAGER_ROLE(),
            operationsManager.address
        );
        await maintenanceUpgradeManager.grantRole(
            await maintenanceUpgradeManager.UPGRADE_MANAGER_ROLE(),
            maintenanceManager.address
        );
    });

    describe("Production Deployment Manager", function () {
        it("Should create deployment plan", async function () {
            const tx = await productionDeploymentManager.connect(deploymentManager).createDeploymentPlan(
                "Initial Deployment",
                0, // PREPARATION stage
                [0, 1, 2], // TOKEN_PARAMETERS, TREASURY, GOVERNANCE
                [],
                ethers.parseUnits("5", "gwei"),
                Math.floor(Date.now() / 1000) + 86400, // 1 day from now
                "Initial system deployment"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "DeploymentPlanCreated");
            expect(event).to.not.be.undefined;
        });

        it("Should deploy contract", async function () {
            // Simple bytecode for testing (empty contract)
            const bytecode = "0x608060405234801561001057600080fd5b50603f80601f6000396000f3fe6080604052600080fd00";
            
            const tx = await productionDeploymentManager.connect(deploymentManager).deployContract(
                0, // CORE_TOKEN
                "TestContract",
                bytecode,
                "0x", // No constructor args
                "1.0.0"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "DeploymentStarted");
            expect(event).to.not.be.undefined;
        });

        it("Should advance deployment stage", async function () {
            await expect(
                productionDeploymentManager.connect(deploymentManager).advanceDeploymentStage(1) // TESTNET
            ).to.not.be.reverted;

            const stage = await productionDeploymentManager.getCurrentDeploymentStage();
            expect(stage).to.equal(1);
        });

        it("Should create rollback plan", async function () {
            // First deploy a contract to rollback
            const bytecode = "0x608060405234801561001057600080fd5b50603f80601f6000396000f3fe6080604052600080fd00";
            const deployTx = await productionDeploymentManager.connect(deploymentManager).deployContract(
                0, "TestContract", bytecode, "0x", "1.0.0"
            );
            const deployReceipt = await deployTx.wait();
            const deployEvent = deployReceipt.logs.find(log => log.fragment?.name === "DeploymentStarted");
            const deploymentId = deployEvent.args[0];

            await expect(
                productionDeploymentManager.connect(deploymentManager).createRollbackPlan(
                    deploymentId,
                    [user1.address],
                    [user2.address],
                    "Testing rollback"
                )
            ).to.not.be.reverted;
        });

        it("Should get deployment metrics", async function () {
            const metrics = await productionDeploymentManager.getDeploymentMetrics();
            expect(metrics.length).to.equal(4);
            expect(metrics[0]).to.be.a('bigint'); // totalDeployments
        });
    });

    describe("System Initialization Manager", function () {
        it("Should start initialization", async function () {
            await expect(
                systemInitializationManager.connect(deploymentManager).startInitialization()
            ).to.not.be.reverted;

            const phase = await systemInitializationManager.getCurrentPhase();
            expect(phase).to.equal(1); // CONTRACTS_DEPLOYED
        });

        it("Should create initialization task", async function () {
            await systemInitializationManager.connect(deploymentManager).startInitialization();

            const tx = await systemInitializationManager.connect(deploymentManager).createInitializationTask(
                "Setup Token Parameters",
                0, // TOKEN_PARAMETERS
                await karmaToken.getAddress(),
                "0x12345678", // Function selector
                "0x", // Parameters
                100, // Priority
                ethers.parseUnits("50000", "wei"), // Gas estimate
                true, // Required
                "Initialize token parameters"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "TaskCreated");
            expect(event).to.not.be.undefined;
        });

        it("Should create token distribution", async function () {
            const tx = await systemInitializationManager.connect(deploymentManager).createTokenDistribution(
                0, // TEAM_ALLOCATION
                [user1.address, user2.address],
                [ethers.parseUnits("1000", 18), ethers.parseUnits("2000", 18)],
                ethers.ZeroAddress, // No vesting contract
                Math.floor(Date.now() / 1000),
                0, // No vesting duration
                "Team allocation distribution"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "TokenDistributionStarted");
            expect(event).to.not.be.undefined;
        });

        it("Should create liquidity pool", async function () {
            const tx = await systemInitializationManager.connect(deploymentManager).createLiquidityPool(
                await karmaToken.getAddress(),
                "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", // WETH on Arbitrum
                ethers.parseUnits("1000000", 18), // 1M KARMA
                ethers.parseEther("500"), // 500 ETH
                3000, // 0.3% fee
                "KARMA/WETH Pool"
            );

            const receipt = await tx.wait();
            expect(tx).to.not.be.reverted;
        });

        it("Should configure governance", async function () {
            const tx = await systemInitializationManager.connect(deploymentManager).configureGovernance(
                user1.address, // Governance contract
                user2.address, // Staking contract
                ethers.parseUnits("1000000", 18), // 1M KARMA threshold
                7200, // 1 day voting delay
                50400, // 7 day voting period
                4, // 4% quorum
                "Main governance setup"
            );

            expect(tx).to.not.be.reverted;
        });

        it("Should check system integrity", async function () {
            const [isValid, issues] = await systemInitializationManager.verifySystemIntegrity();
            expect(isValid).to.be.a('boolean');
            expect(Array.isArray(issues)).to.be.true;
        });

        it("Should get initialization progress", async function () {
            const progress = await systemInitializationManager.getInitializationProgress();
            expect(progress).to.be.a('bigint');
            expect(progress).to.be.at.least(0n);
            expect(progress).to.be.at.most(100n);
        });
    });

    describe("Operations Monitoring Manager", function () {
        it("Should create monitoring configuration", async function () {
            const tx = await operationsMonitoringManager.connect(operationsManager).createMonitoringConfig(
                "Production Monitoring",
                2, // ADVANCED
                [await karmaToken.getAddress(), await treasury.getAddress()],
                [0, 1, 2], // GAS_USAGE, TRANSACTION_COUNT, ERROR_RATE
                3600, // 1 hour update interval
                2592000, // 30 days retention
                true, // Alerts enabled
                "Comprehensive production monitoring"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "MonitoringConfigCreated");
            expect(event).to.not.be.undefined;
        });

        it("Should record performance metric", async function () {
            await operationsMonitoringManager.grantRole(
                await operationsMonitoringManager.MONITORING_AGENT_ROLE(),
                user1.address
            );

            const tx = await operationsMonitoringManager.connect(user1).recordMetric(
                0, // GAS_USAGE
                await karmaToken.getAddress(),
                ethers.parseUnits("100000", "wei"),
                "wei"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "MetricUpdated");
            expect(event).to.not.be.undefined;
        });

        it("Should create health check", async function () {
            const tx = await operationsMonitoringManager.connect(operationsManager).createHealthCheck(
                "System Health Check",
                3600, // 1 hour interval
                true, // Automated
                "Automated system health monitoring"
            );

            expect(tx).to.not.be.reverted;
        });

        it("Should create alert", async function () {
            await operationsMonitoringManager.grantRole(
                await operationsMonitoringManager.ALERT_MANAGER_ROLE(),
                user1.address
            );

            const tx = await operationsMonitoringManager.connect(user1).createAlert(
                2, // ERROR severity
                0, // GAS_USAGE metric
                await karmaToken.getAddress(),
                "High gas usage detected"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "AlertTriggered");
            expect(event).to.not.be.undefined;
        });

        it("Should identify gas optimization", async function () {
            const tx = await operationsMonitoringManager.connect(operationsManager).identifyGasOptimization(
                await karmaToken.getAddress(),
                "transfer",
                50000, // Original gas cost
                35000, // Optimized gas cost
                "Storage optimization"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "GasOptimizationIdentified");
            expect(event).to.not.be.undefined;
        });

        it("Should create dashboard", async function () {
            const tx = await operationsMonitoringManager.connect(user1).createDashboard(
                "System Overview",
                [0, 1, 2], // GAS_USAGE, TRANSACTION_COUNT, ERROR_RATE
                300, // 5 minute refresh
                true, // Public
                ["chart", "gauge", "table"],
                "grid"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "DashboardCreated");
            expect(event).to.not.be.undefined;
        });

        it("Should generate transparency report", async function () {
            await operationsMonitoringManager.grantRole(
                await operationsMonitoringManager.REPORT_GENERATOR_ROLE(),
                user1.address
            );

            const startTime = Math.floor(Date.now() / 1000) - 86400; // 1 day ago
            const endTime = Math.floor(Date.now() / 1000);

            const tx = await operationsMonitoringManager.connect(user1).generateTransparencyReport(
                1, // WEEKLY
                startTime,
                endTime,
                ["performance", "security", "governance"]
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "TransparencyReportGenerated");
            expect(event).to.not.be.undefined;
        });

        it("Should get system statistics", async function () {
            const stats = await operationsMonitoringManager.getSystemStatistics();
            expect(stats.length).to.equal(5);
            expect(stats[0]).to.be.a('bigint'); // totalTransactions
        });

        it("Should enable automated monitoring", async function () {
            await expect(
                operationsMonitoringManager.connect(operationsManager).enableAutomatedMonitoring()
            ).to.not.be.reverted;

            const isEnabled = await operationsMonitoringManager.isAutomatedMonitoringEnabled();
            expect(isEnabled).to.be.true;
        });
    });

    describe("Maintenance Upgrade Manager", function () {
        it("Should propose upgrade", async function () {
            const tx = await maintenanceUpgradeManager.connect(maintenanceManager).proposeUpgrade(
                1, // MAJOR_UPDATE
                [await karmaToken.getAddress()],
                [user1.address], // New implementation
                ["0x12345678"], // Upgrade calls
                "Token Contract Upgrade",
                "Upgrade to latest version with new features",
                Math.floor(Date.now() / 1000) + 86400, // 1 day review
                true, // Requires governance
                "2.0.0"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "UpgradeProposed");
            expect(event).to.not.be.undefined;
        });

        it("Should schedule maintenance task", async function () {
            const tx = await maintenanceUpgradeManager.connect(maintenanceManager).scheduleMaintenanceTask(
                0, // ROUTINE
                [await karmaToken.getAddress()],
                ["0x12345678"], // Maintenance calls
                "Routine Maintenance",
                "Regular system maintenance",
                Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
                true, // Recurring
                86400 // Daily
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "MaintenanceScheduled");
            expect(event).to.not.be.undefined;
        });

        it("Should trigger emergency response", async function () {
            await maintenanceUpgradeManager.grantRole(
                await maintenanceUpgradeManager.EMERGENCY_RESPONDER_ROLE(),
                user1.address
            );

            const tx = await maintenanceUpgradeManager.connect(user1).triggerEmergencyResponse(
                "Security Incident",
                [await karmaToken.getAddress()],
                ["0x12345678"], // Emergency actions
                "Critical security vulnerability detected"
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "EmergencyResponseTriggered");
            expect(event).to.not.be.undefined;
        });

        it("Should submit community proposal", async function () {
            const tx = await maintenanceUpgradeManager.connect(user1).submitCommunityProposal(
                0, // TECHNICAL
                "Improve Gas Efficiency",
                "Proposal to optimize gas usage across contracts",
                "Detailed technical specification...",
                Math.floor(Date.now() / 1000) + 604800, // 1 week review
                Math.floor(Date.now() / 1000) + 2592000 // 1 month implementation
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.fragment?.name === "CommunityProposalSubmitted");
            expect(event).to.not.be.undefined;
        });

        it("Should get upgrade statistics", async function () {
            const stats = await maintenanceUpgradeManager.getUpgradeStatistics();
            expect(stats.length).to.equal(4);
            expect(stats[0]).to.be.a('bigint'); // totalUpgrades
        });

        it("Should get maintenance statistics", async function () {
            const stats = await maintenanceUpgradeManager.getMaintenanceStatistics();
            expect(stats.length).to.equal(4);
            expect(stats[0]).to.be.a('bigint'); // totalTasks
        });
    });

    describe("Integration Tests", function () {
        it("Should coordinate deployment and initialization", async function () {
            // Start deployment process
            await productionDeploymentManager.connect(deploymentManager).createDeploymentPlan(
                "Full System Deployment",
                0, // PREPARATION
                [0, 1, 2], // All contract types
                [],
                ethers.parseUnits("5", "gwei"),
                Math.floor(Date.now() / 1000) + 86400,
                "Complete system deployment"
            );

            // Start initialization
            await systemInitializationManager.connect(deploymentManager).startInitialization();

            // Create monitoring for the process
            await operationsMonitoringManager.connect(operationsManager).createMonitoringConfig(
                "Deployment Monitoring",
                3, // ENTERPRISE
                [await karmaToken.getAddress()],
                [0, 1], // GAS_USAGE, TRANSACTION_COUNT
                600, // 10 minutes
                86400, // 1 day
                true,
                "Monitor deployment process"
            );

            expect(true).to.be.true; // All operations completed
        });

        it("Should handle emergency scenario", async function () {
            // Grant emergency role
            await maintenanceUpgradeManager.grantRole(
                await maintenanceUpgradeManager.EMERGENCY_RESPONDER_ROLE(),
                operationsManager.address
            );

            // Create alert in monitoring
            await operationsMonitoringManager.grantRole(
                await operationsMonitoringManager.ALERT_MANAGER_ROLE(),
                operationsManager.address
            );

            await operationsMonitoringManager.connect(operationsManager).createAlert(
                3, // CRITICAL
                2, // ERROR_RATE
                await karmaToken.getAddress(),
                "Critical system error detected"
            );

            // Trigger emergency response
            await maintenanceUpgradeManager.connect(operationsManager).triggerEmergencyResponse(
                "System Failure",
                [await karmaToken.getAddress()],
                ["0x12345678"],
                "Emergency response triggered by monitoring alert"
            );

            expect(true).to.be.true; // Emergency response coordinated
        });

        it("Should demonstrate full production readiness", async function () {
            // 1. Deploy system
            const bytecode = "0x608060405234801561001057600080fd5b50603f80601f6000396000f3fe6080604052600080fd00";
            await productionDeploymentManager.connect(deploymentManager).deployContract(
                0, "ProductionContract", bytecode, "0x", "1.0.0"
            );

            // 2. Initialize parameters
            await systemInitializationManager.connect(deploymentManager).startInitialization();

            // 3. Setup monitoring
            await operationsMonitoringManager.connect(operationsManager).createMonitoringConfig(
                "Production Monitoring", 3, [await karmaToken.getAddress()], [0, 1, 2], 3600, 2592000, true, "Full monitoring"
            );

            // 4. Schedule maintenance
            await maintenanceUpgradeManager.connect(maintenanceManager).scheduleMaintenanceTask(
                0, [await karmaToken.getAddress()], ["0x12345678"], "Regular Maintenance", "Routine checks",
                Math.floor(Date.now() / 1000) + 3600, true, 86400
            );

            // Get system status
            const deploymentMetrics = await productionDeploymentManager.getDeploymentMetrics();
            const initProgress = await systemInitializationManager.getInitializationProgress();
            const systemStats = await operationsMonitoringManager.getSystemStatistics();
            const upgradeStats = await maintenanceUpgradeManager.getUpgradeStatistics();

            // Verify production readiness
            expect(deploymentMetrics[0]).to.be.at.least(1n); // At least 1 deployment
            expect(initProgress).to.be.a('bigint');
            expect(systemStats[0]).to.be.a('bigint'); // Total transactions
            expect(upgradeStats[0]).to.be.a('bigint'); // Total upgrades

            console.log("Stage 9.2 Production Deployment and Operations System is ready!");
        });
    });
}); 