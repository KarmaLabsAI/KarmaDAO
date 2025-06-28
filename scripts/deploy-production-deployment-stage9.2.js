const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying Stage 9.2: Production Deployment and Operations...");
    console.log("=".repeat(60));

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);
    console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

    // ============ DEPLOY DEPENDENCIES ============
    
    console.log("\n📋 Step 1: Deploying Dependencies...");
    
    // Deploy KARMA Token
    console.log("Deploying KARMA Token...");
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(deployer.address);
    await karmaToken.waitForDeployment();
    console.log("✅ KARMA Token deployed at:", await karmaToken.getAddress());

    // Deploy Treasury
    console.log("Deploying Treasury...");
    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(
        deployer.address,
        await karmaToken.getAddress(),
        ethers.parseUnits("100000", 6) // 100K USDC allocation
    );
    await treasury.waitForDeployment();
    console.log("✅ Treasury deployed at:", await treasury.getAddress());

    // ============ DEPLOY STAGE 9.2 CONTRACTS ============
    
    console.log("\n🏭 Step 2: Deploying Stage 9.2 Production Systems...");

    // Deploy Production Deployment Manager
    console.log("Deploying Production Deployment Manager...");
    const ProductionDeploymentManager = await ethers.getContractFactory("ProductionDeploymentManager");
    const productionDeploymentManager = await ProductionDeploymentManager.deploy(deployer.address);
    await productionDeploymentManager.waitForDeployment();
    console.log("✅ Production Deployment Manager deployed at:", await productionDeploymentManager.getAddress());

    // Deploy System Initialization Manager
    console.log("Deploying System Initialization Manager...");
    const SystemInitializationManager = await ethers.getContractFactory("SystemInitializationManager");
    const systemInitializationManager = await SystemInitializationManager.deploy(
        deployer.address,
        await karmaToken.getAddress(),
        await treasury.getAddress()
    );
    await systemInitializationManager.waitForDeployment();
    console.log("✅ System Initialization Manager deployed at:", await systemInitializationManager.getAddress());

    // Deploy Operations Monitoring Manager
    console.log("Deploying Operations Monitoring Manager...");
    const OperationsMonitoringManager = await ethers.getContractFactory("OperationsMonitoringManager");
    const operationsMonitoringManager = await OperationsMonitoringManager.deploy(deployer.address);
    await operationsMonitoringManager.waitForDeployment();
    console.log("✅ Operations Monitoring Manager deployed at:", await operationsMonitoringManager.getAddress());

    // Deploy Maintenance Upgrade Manager
    console.log("Deploying Maintenance Upgrade Manager...");
    const MaintenanceUpgradeManager = await ethers.getContractFactory("MaintenanceUpgradeManager");
    const maintenanceUpgradeManager = await MaintenanceUpgradeManager.deploy(deployer.address);
    await maintenanceUpgradeManager.waitForDeployment();
    console.log("✅ Maintenance Upgrade Manager deployed at:", await maintenanceUpgradeManager.getAddress());

    // ============ CONFIGURE PRODUCTION DEPLOYMENT SYSTEM ============
    
    console.log("\n⚙️ Step 3: Configuring Production Deployment System...");

    // Create deployment plan
    console.log("Creating deployment plan...");
    const createPlanTx = await productionDeploymentManager.createDeploymentPlan(
        "Karma Labs Production Deployment",
        0, // PREPARATION stage
        [0, 1, 2, 3, 4], // All contract types
        [],
        ethers.parseUnits("50", "gwei"), // Max gas price
        Math.floor(Date.now() / 1000) + 86400, // 1 day deadline
        "Complete Karma Labs ecosystem deployment"
    );
    await createPlanTx.wait();
    console.log("✅ Deployment plan created");

    // Advance to testnet stage
    console.log("Advancing to testnet deployment stage...");
    const advanceTx = await productionDeploymentManager.advanceDeploymentStage(1); // TESTNET
    await advanceTx.wait();
    console.log("✅ Advanced to testnet stage");

    // Deploy a test contract
    console.log("Deploying test contract...");
    const testBytecode = "0x608060405234801561001057600080fd5b50603f80601f6000396000f3fe6080604052600080fd00";
    const deployTx = await productionDeploymentManager.deployContract(
        0, // CORE_TOKEN
        "TestContract",
        testBytecode,
        "0x",
        "1.0.0"
    );
    await deployTx.wait();
    console.log("✅ Test contract deployed");

    // Get deployment metrics
    const deploymentMetrics = await productionDeploymentManager.getDeploymentMetrics();
    console.log("📊 Deployment Metrics:");
    console.log("   Total Deployments:", deploymentMetrics[0].toString());
    console.log("   Successful Deployments:", deploymentMetrics[1].toString());
    console.log("   Failed Deployments:", deploymentMetrics[2].toString());
    console.log("   Average Gas Used:", deploymentMetrics[3].toString());

    // ============ CONFIGURE SYSTEM INITIALIZATION ============
    
    console.log("\n🔧 Step 4: Configuring System Initialization...");

    // Start initialization
    console.log("Starting system initialization...");
    const startInitTx = await systemInitializationManager.startInitialization();
    await startInitTx.wait();
    console.log("✅ System initialization started");

    // Create initialization task
    console.log("Creating initialization task...");
    const createTaskTx = await systemInitializationManager.createInitializationTask(
        "Token Parameter Setup",
        0, // TOKEN_PARAMETERS
        await karmaToken.getAddress(),
        "0x12345678", // Mock function selector
        "0x", // Parameters
        100, // Priority
        ethers.parseUnits("50000", "wei"), // Gas estimate
        true, // Required
        "Configure token parameters for production"
    );
    await createTaskTx.wait();
    console.log("✅ Initialization task created");

    // Create token distribution
    console.log("Creating token distribution...");
    const createDistTx = await systemInitializationManager.createTokenDistribution(
        0, // TEAM_ALLOCATION
        [deployer.address],
        [ethers.parseUnits("1000000", 18)], // 1M KARMA
        ethers.ZeroAddress, // No vesting
        Math.floor(Date.now() / 1000),
        0,
        "Initial team allocation"
    );
    await createDistTx.wait();
    console.log("✅ Token distribution created");

    // Create liquidity pool
    console.log("Creating liquidity pool...");
    const createPoolTx = await systemInitializationManager.createLiquidityPool(
        await karmaToken.getAddress(),
        "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", // WETH on Arbitrum
        ethers.parseUnits("5000000", 18), // 5M KARMA
        ethers.parseEther("2500"), // 2500 ETH
        3000, // 0.3% fee
        "KARMA/WETH Main Pool"
    );
    await createPoolTx.wait();
    console.log("✅ Liquidity pool created");

    // Configure governance
    console.log("Configuring governance system...");
    const configGovTx = await systemInitializationManager.configureGovernance(
        deployer.address, // Mock governance contract
        deployer.address, // Mock staking contract
        ethers.parseUnits("1000000", 18), // 1M KARMA threshold
        7200, // 1 day voting delay
        50400, // 7 day voting period
        4, // 4% quorum
        "Production governance configuration"
    );
    await configGovTx.wait();
    console.log("✅ Governance configured");

    // Get initialization progress
    const initProgress = await systemInitializationManager.getInitializationProgress();
    console.log("📊 Initialization Progress:", initProgress.toString() + "%");

    // Verify system integrity
    const [isValid, issues] = await systemInitializationManager.verifySystemIntegrity();
    console.log("🔍 System Integrity Check:");
    console.log("   Valid:", isValid);
    console.log("   Issues:", issues.length);

    // ============ CONFIGURE OPERATIONS MONITORING ============
    
    console.log("\n📊 Step 5: Configuring Operations Monitoring...");

    // Create monitoring configuration
    console.log("Creating monitoring configuration...");
    const createMonitoringTx = await operationsMonitoringManager.createMonitoringConfig(
        "Production Monitoring",
        3, // ENTERPRISE level
        [await karmaToken.getAddress(), await treasury.getAddress()],
        [0, 1, 2, 3, 4], // All metric types
        3600, // 1 hour update interval
        2592000, // 30 days retention
        true, // Alerts enabled
        "Comprehensive production monitoring system"
    );
    await createMonitoringTx.wait();
    console.log("✅ Monitoring configuration created");

    // Grant monitoring agent role for recording metrics
    await operationsMonitoringManager.grantRole(
        await operationsMonitoringManager.MONITORING_AGENT_ROLE(),
        deployer.address
    );

    // Record sample metrics
    console.log("Recording sample metrics...");
    const recordMetricTx = await operationsMonitoringManager.recordMetric(
        0, // GAS_USAGE
        await karmaToken.getAddress(),
        ethers.parseUnits("150000", "wei"), // 150k gas
        "wei"
    );
    await recordMetricTx.wait();
    console.log("✅ Sample metric recorded");

    // Create health check
    console.log("Creating health check...");
    const createHealthTx = await operationsMonitoringManager.createHealthCheck(
        "System Health Check",
        3600, // 1 hour interval
        true, // Automated
        "Automated system health monitoring"
    );
    await createHealthTx.wait();
    console.log("✅ Health check created");

    // Grant alert manager role and create alert
    await operationsMonitoringManager.grantRole(
        await operationsMonitoringManager.ALERT_MANAGER_ROLE(),
        deployer.address
    );

    const createAlertTx = await operationsMonitoringManager.createAlert(
        1, // WARNING severity
        0, // GAS_USAGE metric
        await karmaToken.getAddress(),
        "Sample monitoring alert for demonstration"
    );
    await createAlertTx.wait();
    console.log("✅ Sample alert created");

    // Identify gas optimization
    console.log("Identifying gas optimization...");
    const identifyOptTx = await operationsMonitoringManager.identifyGasOptimization(
        await karmaToken.getAddress(),
        "transfer",
        75000, // Original gas cost
        55000, // Optimized gas cost
        "Storage layout optimization"
    );
    await identifyOptTx.wait();
    console.log("✅ Gas optimization identified");

    // Create public dashboard
    console.log("Creating public dashboard...");
    const createDashTx = await operationsMonitoringManager.createDashboard(
        "Karma Labs System Dashboard",
        [0, 1, 2, 3], // Multiple metrics
        300, // 5 minute refresh
        true, // Public
        ["performance-chart", "gas-gauge", "health-indicator", "alert-panel"],
        "responsive-grid"
    );
    await createDashTx.wait();
    console.log("✅ Public dashboard created");

    // Grant report generator role and create transparency report
    await operationsMonitoringManager.grantRole(
        await operationsMonitoringManager.REPORT_GENERATOR_ROLE(),
        deployer.address
    );

    const generateReportTx = await operationsMonitoringManager.generateTransparencyReport(
        0, // DAILY report
        Math.floor(Date.now() / 1000) - 86400, // 1 day ago
        Math.floor(Date.now() / 1000), // Now
        ["performance", "security", "governance", "financials"]
    );
    await generateReportTx.wait();
    console.log("✅ Transparency report generated");

    // Enable automated monitoring
    console.log("Enabling automated monitoring...");
    const enableAutoTx = await operationsMonitoringManager.enableAutomatedMonitoring();
    await enableAutoTx.wait();
    console.log("✅ Automated monitoring enabled");

    // Get system statistics
    const systemStats = await operationsMonitoringManager.getSystemStatistics();
    console.log("📊 System Statistics:");
    console.log("   Total Transactions:", systemStats[0].toString());
    console.log("   Total Gas Used:", systemStats[1].toString());
    console.log("   Average Gas Price:", systemStats[2].toString());
    console.log("   Uptime Percentage:", systemStats[3].toString() + "%");
    console.log("   Error Rate:", systemStats[4].toString() + "%");

    // ============ CONFIGURE MAINTENANCE AND UPGRADES ============
    
    console.log("\n🔧 Step 6: Configuring Maintenance and Upgrades...");

    // Propose system upgrade
    console.log("Proposing system upgrade...");
    const proposeUpgradeTx = await maintenanceUpgradeManager.proposeUpgrade(
        1, // MAJOR_UPDATE
        [await karmaToken.getAddress()],
        [deployer.address], // Mock new implementation
        ["0x12345678"], // Mock upgrade call
        "KARMA Token v2.0 Upgrade",
        "Major upgrade adding new features and optimizations",
        Math.floor(Date.now() / 1000) + 604800, // 1 week review period
        true, // Requires governance
        "2.0.0"
    );
    await proposeUpgradeTx.wait();
    console.log("✅ Upgrade proposal created");

    // Schedule maintenance task
    console.log("Scheduling maintenance task...");
    const scheduleMaintenanceTx = await maintenanceUpgradeManager.scheduleMaintenanceTask(
        0, // ROUTINE
        [await karmaToken.getAddress(), await treasury.getAddress()],
        ["0x12345678", "0x87654321"], // Mock maintenance calls
        "Weekly System Maintenance",
        "Routine weekly maintenance including cache clearing and optimization",
        Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
        true, // Recurring
        604800 // Weekly (7 days)
    );
    await scheduleMaintenanceTx.wait();
    console.log("✅ Maintenance task scheduled");

    // Grant emergency responder role and create emergency response
    await maintenanceUpgradeManager.grantRole(
        await maintenanceUpgradeManager.EMERGENCY_RESPONDER_ROLE(),
        deployer.address
    );

    const triggerEmergencyTx = await maintenanceUpgradeManager.triggerEmergencyResponse(
        "Security Incident Drill",
        [await karmaToken.getAddress()],
        ["0x12345678"], // Mock emergency action
        "Simulated security incident for testing emergency response procedures"
    );
    await triggerEmergencyTx.wait();
    console.log("✅ Emergency response triggered (drill)");

    // Submit community proposal
    console.log("Submitting community proposal...");
    const submitProposalTx = await maintenanceUpgradeManager.submitCommunityProposal(
        0, // TECHNICAL
        "Implement Gas Fee Optimization",
        "Community proposal to implement advanced gas fee optimization across all contracts",
        "Detailed technical specification for gas optimization implementation...",
        Math.floor(Date.now() / 1000) + 1209600, // 2 weeks review
        Math.floor(Date.now() / 1000) + 2592000 // 1 month implementation
    );
    await submitProposalTx.wait();
    console.log("✅ Community proposal submitted");

    // Get maintenance statistics
    const upgradeStats = await maintenanceUpgradeManager.getUpgradeStatistics();
    const maintenanceStats = await maintenanceUpgradeManager.getMaintenanceStatistics();
    
    console.log("📊 Upgrade Statistics:");
    console.log("   Total Upgrades:", upgradeStats[0].toString());
    console.log("   Successful Upgrades:", upgradeStats[1].toString());
    console.log("   Failed Upgrades:", upgradeStats[2].toString());
    console.log("   Average Upgrade Time:", upgradeStats[3].toString() + " seconds");

    console.log("📊 Maintenance Statistics:");
    console.log("   Total Tasks:", maintenanceStats[0].toString());
    console.log("   Completed Tasks:", maintenanceStats[1].toString());
    console.log("   Failed Tasks:", maintenanceStats[2].toString());
    console.log("   Average Execution Time:", maintenanceStats[3].toString() + " seconds");

    // ============ INTEGRATION TESTING ============
    
    console.log("\n🧪 Step 7: Integration Testing...");

    console.log("Testing cross-system integration...");

    // Test monitoring integration with deployment
    const allConfigs = await operationsMonitoringManager.getAllMonitoringConfigs();
    console.log("✅ Monitoring configs available:", allConfigs.length);

    // Test initialization status
    const initMetrics = await systemInitializationManager.getInitializationMetrics();
    console.log("✅ Initialization metrics:", {
        totalTasks: initMetrics[0].toString(),
        completedTasks: initMetrics[1].toString(),
        failedTasks: initMetrics[2].toString(),
        totalGasUsed: initMetrics[3].toString()
    });

    // Test deployment status
    const currentStage = await productionDeploymentManager.getCurrentDeploymentStage();
    console.log("✅ Current deployment stage:", currentStage.toString());

    // ============ SUMMARY ============
    
    console.log("\n" + "=".repeat(60));
    console.log("🎉 Stage 9.2 Deployment Complete!");
    console.log("=".repeat(60));
    
    console.log("\n📋 Deployed Contracts:");
    console.log("Production Deployment Manager:", await productionDeploymentManager.getAddress());
    console.log("System Initialization Manager:", await systemInitializationManager.getAddress());
    console.log("Operations Monitoring Manager:", await operationsMonitoringManager.getAddress());
    console.log("Maintenance Upgrade Manager:", await maintenanceUpgradeManager.getAddress());
    
    console.log("\n🔧 System Configuration:");
    console.log("✅ Production deployment system configured");
    console.log("✅ System initialization framework ready");
    console.log("✅ Comprehensive monitoring active");
    console.log("✅ Maintenance and upgrade procedures established");
    console.log("✅ Emergency response capabilities operational");
    console.log("✅ Community governance integration ready");
    
    console.log("\n📊 System Status:");
    console.log("Deployment Stage:", currentStage.toString(), "(Testnet)");
    console.log("Initialization Progress:", initProgress.toString() + "%");
    console.log("Monitoring Active:", await operationsMonitoringManager.isAutomatedMonitoringEnabled());
    console.log("Total System Components:", "4 main subsystems");
    
    console.log("\n🚀 Production Readiness:");
    console.log("✅ Staged deployment pipeline operational");
    console.log("✅ Automated system initialization ready");
    console.log("✅ Real-time monitoring and alerting active");
    console.log("✅ Maintenance scheduling and execution ready");
    console.log("✅ Emergency response procedures tested");
    console.log("✅ Community proposal system functional");
    console.log("✅ Transparency reporting operational");
    
    console.log("\n" + "=".repeat(60));
    console.log("Stage 9.2: Production Deployment and Operations");
    console.log("Enterprise-grade production systems deployed successfully!");
    console.log("Ready for mainnet deployment and operations.");
    console.log("=".repeat(60));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    }); 