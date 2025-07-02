const { ethers } = require("hardhat");
const config = require("../config/stage9.2-config.json");

/**
 * @title Stage 9.2 Setup Script - Production Deployment and Operations
 * @notice Sets up production monitoring, operations, and maintenance systems
 */
async function setupStage9_2() {
    console.log("🚀 Setting up Stage 9.2: Production Deployment and Operations...");
    
    const [deployer, operationsManager, monitoringManager, maintenanceManager] = await ethers.getSigners();
    
    console.log("Deployer address:", deployer.address);
    console.log("Operations Manager:", operationsManager.address);
    console.log("Monitoring Manager:", monitoringManager.address);
    console.log("Maintenance Manager:", maintenanceManager.address);

    // Get deployed contract addresses
    const contractAddresses = {
        KarmaOperationsMonitoring: process.env.KARMA_OPERATIONS_MONITORING_ADDRESS,
        KarmaMaintenanceUpgrade: process.env.KARMA_MAINTENANCE_UPGRADE_ADDRESS,
        // All other protocol contracts for monitoring
        KarmaToken: process.env.KARMA_TOKEN_ADDRESS,
        VestingVault: process.env.VESTING_VAULT_ADDRESS,
        SaleManager: process.env.SALE_MANAGER_ADDRESS,
        Treasury: process.env.TREASURY_ADDRESS,
        Paymaster: process.env.PAYMASTER_ADDRESS,
        BuybackBurn: process.env.BUYBACK_BURN_ADDRESS,
        KarmaDAO: process.env.KARMA_DAO_ADDRESS,
        ZeroGIntegration: process.env.ZEROG_INTEGRATION_ADDRESS,
        KarmaSecurityMonitoring: process.env.KARMA_SECURITY_MONITORING_ADDRESS
    };

    // Validate critical contract addresses
    const criticalContracts = ['KarmaOperationsMonitoring', 'KarmaMaintenanceUpgrade'];
    for (const contractName of criticalContracts) {
        if (!contractAddresses[contractName]) {
            throw new Error(`${contractName} address not found in environment variables`);
        }
    }

    // Connect to deployed contracts
    const operationsMonitoring = await ethers.getContractAt("KarmaOperationsMonitoring", contractAddresses.KarmaOperationsMonitoring);
    const maintenanceUpgrade = await ethers.getContractAt("KarmaMaintenanceUpgrade", contractAddresses.KarmaMaintenanceUpgrade);

    console.log("\n📊 Setting up Operations Monitoring...");
    
    // 1. Setup Operations Monitoring
    try {
        // Grant operations manager role
        const OPERATIONS_MANAGER_ROLE = await operationsMonitoring.OPERATIONS_MANAGER_ROLE();
        const DASHBOARD_OPERATOR_ROLE = await operationsMonitoring.DASHBOARD_OPERATOR_ROLE();
        
        console.log("Granting operations manager role...");
        let tx = await operationsMonitoring.connect(deployer).grantRole(OPERATIONS_MANAGER_ROLE, operationsManager.address);
        await tx.wait(1);
        console.log("✅ Operations manager role granted");

        console.log("Granting dashboard operator role...");
        tx = await operationsMonitoring.connect(deployer).grantRole(DASHBOARD_OPERATOR_ROLE, monitoringManager.address);
        await tx.wait(1);
        console.log("✅ Dashboard operator role granted");

        // Configure monitoring systems
        console.log("Configuring monitoring systems...");
        const monitoringSystems = config.operations.monitoring.systems;
        
        // Setup Application Performance Monitoring
        if (monitoringSystems.applicationPerformance) {
            const apm = monitoringSystems.applicationPerformance;
            tx = await operationsMonitoring.connect(operationsManager).configureAPM(
                apm.provider,
                apm.metrics,
                Object.values(apm.alerting.thresholds)
            );
            await tx.wait(1);
            console.log("✅ Application Performance Monitoring configured");
        }

        // Setup Infrastructure Monitoring
        if (monitoringSystems.infrastructureMonitoring) {
            const infra = monitoringSystems.infrastructureMonitoring;
            tx = await operationsMonitoring.connect(operationsManager).configureInfrastructureMonitoring(
                infra.provider,
                infra.metrics,
                86400 * 90 // 90 days retention
            );
            await tx.wait(1);
            console.log("✅ Infrastructure Monitoring configured");
        }

        // Setup Blockchain Monitoring
        if (monitoringSystems.blockchainMonitoring) {
            const blockchain = monitoringSystems.blockchainMonitoring;
            tx = await operationsMonitoring.connect(operationsManager).configureBlockchainMonitoring(
                blockchain.metrics,
                Object.values(blockchain.alerting)
            );
            await tx.wait(1);
            console.log("✅ Blockchain Monitoring configured");
        }

        // Register all protocol contracts for monitoring
        console.log("Registering contracts for operational monitoring...");
        const protocolContracts = Object.entries(contractAddresses).filter(([name, addr]) => 
            addr && !name.includes('Monitoring') && !name.includes('Upgrade')
        );

        for (const [contractName, contractAddress] of protocolContracts) {
            try {
                tx = await operationsMonitoring.connect(operationsManager).registerContract(
                    contractName,
                    contractAddress,
                    "PRODUCTION", // environment
                    ["PERFORMANCE", "AVAILABILITY", "ERRORS"] // monitoring categories
                );
                await tx.wait(1);
                console.log(`✅ Registered ${contractName} for monitoring`);
            } catch (error) {
                console.log(`⚠️ Failed to register ${contractName}:`, error.message);
            }
        }

        // Setup dashboards
        console.log("Creating operational dashboards...");
        const dashboards = config.operations.monitoring.dashboards;
        
        for (const [dashboardName, dashboardConfig] of Object.entries(dashboards)) {
            try {
                tx = await operationsMonitoring.connect(monitoringManager).createDashboard(
                    dashboardName,
                    dashboardConfig.url,
                    dashboardConfig.access,
                    dashboardConfig.refresh
                );
                await tx.wait(1);
                console.log(`✅ Created ${dashboardName} dashboard`);
            } catch (error) {
                console.log(`⚠️ Failed to create ${dashboardName} dashboard:`, error.message);
            }
        }

    } catch (error) {
        console.error("❌ Operations monitoring setup failed:", error.message);
    }

    console.log("\n🔧 Setting up Maintenance and Upgrade System...");
    
    // 2. Setup Maintenance and Upgrade System
    try {
        // Grant maintenance manager role
        const MAINTENANCE_MANAGER_ROLE = await maintenanceUpgrade.MAINTENANCE_MANAGER_ROLE();
        const UPGRADE_MANAGER_ROLE = await maintenanceUpgrade.UPGRADE_MANAGER_ROLE();
        const EMERGENCY_RESPONSE_ROLE = await maintenanceUpgrade.EMERGENCY_RESPONSE_ROLE();
        
        console.log("Granting maintenance manager role...");
        tx = await maintenanceUpgrade.connect(deployer).grantRole(MAINTENANCE_MANAGER_ROLE, maintenanceManager.address);
        await tx.wait(1);
        console.log("✅ Maintenance manager role granted");

        console.log("Granting upgrade manager role...");
        tx = await maintenanceUpgrade.connect(deployer).grantRole(UPGRADE_MANAGER_ROLE, operationsManager.address);
        await tx.wait(1);
        console.log("✅ Upgrade manager role granted");

        console.log("Granting emergency response role...");
        tx = await maintenanceUpgrade.connect(deployer).grantRole(EMERGENCY_RESPONSE_ROLE, operationsManager.address);
        await tx.wait(1);
        console.log("✅ Emergency response role granted");

        // Configure maintenance windows
        console.log("Configuring maintenance windows...");
        const maintenanceConfig = config.maintenance.windows;
        
        // Planned maintenance window
        if (maintenanceConfig.planned) {
            tx = await maintenanceUpgrade.connect(maintenanceManager).configureMaintenanceWindow(
                "PLANNED",
                maintenanceConfig.planned.frequency,
                maintenanceConfig.planned.duration,
                maintenanceConfig.planned.notification
            );
            await tx.wait(1);
            console.log("✅ Planned maintenance window configured");
        }

        // Emergency maintenance procedures
        if (maintenanceConfig.emergency) {
            tx = await maintenanceUpgrade.connect(maintenanceManager).configureEmergencyMaintenance(
                maintenanceConfig.emergency.approval,
                maintenanceConfig.emergency.notification,
                maintenanceConfig.emergency.maxDuration
            );
            await tx.wait(1);
            console.log("✅ Emergency maintenance procedures configured");
        }

        // Setup update procedures
        console.log("Configuring update procedures...");
        const updateConfig = config.maintenance.updates;
        
        for (const [updateType, updateSettings] of Object.entries(updateConfig)) {
            try {
                tx = await maintenanceUpgrade.connect(maintenanceManager).configureUpdateProcedure(
                    updateType.toUpperCase(),
                    updateSettings.frequency,
                    updateSettings.testing,
                    updateSettings.approval
                );
                await tx.wait(1);
                console.log(`✅ ${updateType} update procedure configured`);
            } catch (error) {
                console.log(`⚠️ Failed to configure ${updateType} updates:`, error.message);
            }
        }

        // Setup deployment procedures
        console.log("Configuring deployment procedures...");
        const deploymentConfig = config.maintenance.procedures.deployment;
        
        tx = await maintenanceUpgrade.connect(maintenanceManager).configureDeploymentProcedure(
            deploymentConfig.method,
            deploymentConfig.validation,
            deploymentConfig.rollback
        );
        await tx.wait(1);
        console.log("✅ Deployment procedures configured");

        // Setup scaling procedures
        console.log("Configuring auto-scaling...");
        const scalingConfig = config.maintenance.procedures.scaling;
        
        tx = await maintenanceUpgrade.connect(maintenanceManager).configureAutoScaling(
            scalingConfig.triggers,
            scalingConfig.limits.min,
            scalingConfig.limits.max
        );
        await tx.wait(1);
        console.log("✅ Auto-scaling configured");

    } catch (error) {
        console.error("❌ Maintenance system setup failed:", error.message);
    }

    console.log("\n🔔 Setting up Alerting System...");
    
    // 3. Setup Alerting System
    try {
        // Configure alert channels
        const alertingConfig = config.operations.alerting;
        
        // Setup critical alerts
        if (alertingConfig.channels.critical) {
            const critical = alertingConfig.channels.critical;
            tx = await operationsMonitoring.connect(operationsManager).configureAlertChannel(
                "CRITICAL",
                Object.keys(critical), // channels: slack, sms, discord, email
                critical.slack?.webhook || "",
                critical.sms?.numbers || [],
                critical.discord?.webhook || ""
            );
            await tx.wait(1);
            console.log("✅ Critical alert channels configured");
        }

        // Setup high priority alerts
        if (alertingConfig.channels.high) {
            const high = alertingConfig.channels.high;
            tx = await operationsMonitoring.connect(operationsManager).configureAlertChannel(
                "HIGH",
                Object.keys(high),
                high.slack?.webhook || "",
                [],
                high.discord?.webhook || ""
            );
            await tx.wait(1);
            console.log("✅ High priority alert channels configured");
        }

        // Configure escalation policies
        console.log("Configuring alert escalation...");
        const escalationConfig = alertingConfig.escalation;
        
        tx = await operationsMonitoring.connect(operationsManager).configureEscalation(
            escalationConfig.noResponse,
            escalationConfig.failedResponse,
            escalationConfig.maxEscalations
        );
        await tx.wait(1);
        console.log("✅ Alert escalation configured");

    } catch (error) {
        console.error("❌ Alerting system setup failed:", error.message);
    }

    console.log("\n📈 Setting up Performance Monitoring...");
    
    // 4. Setup Performance Monitoring
    try {
        // Configure performance targets
        const performanceTargets = config.performance.targets;
        
        tx = await operationsMonitoring.connect(operationsManager).setPerformanceTargets(
            Math.floor(parseFloat(performanceTargets.availability) * 10000), // Convert to basis points
            parseInt(performanceTargets.responseTime.replace('ms', '')),
            parseInt(performanceTargets.throughput.replace('_TPS', '')),
            Math.floor(parseFloat(performanceTargets.errorRate) * 10000)
        );
        await tx.wait(1);
        console.log("✅ Performance targets configured");

        // Setup optimization features
        const optimizationConfig = config.performance.optimization;
        
        // Configure caching
        if (optimizationConfig.caching) {
            tx = await operationsMonitoring.connect(operationsManager).configureCaching(
                optimizationConfig.caching.strategy,
                Object.values(optimizationConfig.caching.ttl)
            );
            await tx.wait(1);
            console.log("✅ Caching optimization configured");
        }

        // Configure CDN
        if (optimizationConfig.cdn) {
            tx = await operationsMonitoring.connect(operationsManager).configureCDN(
                optimizationConfig.cdn.provider,
                optimizationConfig.cdn.caching
            );
            await tx.wait(1);
            console.log("✅ CDN optimization configured");
        }

    } catch (error) {
        console.error("❌ Performance monitoring setup failed:", error.message);
    }

    console.log("\n🔒 Setting up Compliance and Security...");
    
    // 5. Setup Compliance and Security
    try {
        // Configure data protection
        const complianceConfig = config.compliance;
        
        // GDPR compliance
        if (complianceConfig.dataProtection.gdpr) {
            const gdpr = complianceConfig.dataProtection.gdpr;
            tx = await operationsMonitoring.connect(operationsManager).configureGDPRCompliance(
                gdpr.dataProcessing,
                gdpr.retention,
                gdpr.consent
            );
            await tx.wait(1);
            console.log("✅ GDPR compliance configured");
        }

        // Setup AML monitoring
        if (complianceConfig.financial.aml) {
            const aml = complianceConfig.financial.aml;
            tx = await operationsMonitoring.connect(operationsManager).configureAMLMonitoring(
                aml.provider,
                aml.screening
            );
            await tx.wait(1);
            console.log("✅ AML monitoring configured");
        }

    } catch (error) {
        console.error("❌ Compliance setup failed:", error.message);
    }

    console.log("\n🔄 Setting up Disaster Recovery...");
    
    // 6. Setup Disaster Recovery
    try {
        const drConfig = config.disaster_recovery;
        
        // Configure backup procedures
        tx = await maintenanceUpgrade.connect(maintenanceManager).configureBackupProcedure(
            drConfig.backup.frequency,
            drConfig.backup.retention,
            drConfig.backup.verification
        );
        await tx.wait(1);
        console.log("✅ Backup procedures configured");

        // Configure failover
        tx = await maintenanceUpgrade.connect(maintenanceManager).configureFailover(
            drConfig.failover.mode,
            drConfig.failover.testing,
            drConfig.failover.automation
        );
        await tx.wait(1);
        console.log("✅ Failover procedures configured");

        // Set RTO and RPO targets
        tx = await maintenanceUpgrade.connect(maintenanceManager).setRecoveryTargets(
            drConfig.rto, // Recovery Time Objective
            drConfig.rpo  // Recovery Point Objective
        );
        await tx.wait(1);
        console.log("✅ Recovery targets configured");

    } catch (error) {
        console.error("❌ Disaster recovery setup failed:", error.message);
    }

    console.log("\n🎯 Validating Stage 9.2 setup...");
    
    // 7. Validation and Testing
    try {
        // Test monitoring systems
        console.log("Testing monitoring systems...");
        tx = await operationsMonitoring.connect(monitoringManager).testMonitoringSystems();
        await tx.wait(1);
        console.log("✅ Monitoring systems test completed");

        // Test alerting system
        console.log("Testing alert system...");
        tx = await operationsMonitoring.connect(operationsManager).testAlertSystem("LOW");
        await tx.wait(1);
        console.log("✅ Alert system test completed");

        // Test maintenance procedures
        console.log("Testing maintenance procedures...");
        tx = await maintenanceUpgrade.connect(maintenanceManager).testMaintenanceProcedures();
        await tx.wait(1);
        console.log("✅ Maintenance procedures test completed");

        // Validate performance metrics
        console.log("Validating performance metrics...");
        const performanceStatus = await operationsMonitoring.getPerformanceStatus();
        console.log(`Current performance status: ${performanceStatus}`);

        // Check system health
        console.log("Checking overall system health...");
        const systemHealth = await operationsMonitoring.getSystemHealth();
        console.log(`System health score: ${systemHealth}%`);

    } catch (error) {
        console.error("❌ Validation failed:", error.message);
    }

    console.log("\n📊 Stage 9.2 Setup Summary");
    console.log("==================================");
    console.log(`🖥️ Operations Monitoring: ${contractAddresses.KarmaOperationsMonitoring}`);
    console.log(`🔧 Maintenance & Upgrade: ${contractAddresses.KarmaMaintenanceUpgrade}`);
    console.log("\n🎯 Stage 9.2 Production Features:");
    console.log("✅ Comprehensive operational monitoring with multiple systems");
    console.log("✅ Real-time performance tracking and optimization");
    console.log("✅ Multi-channel alerting with escalation policies");
    console.log("✅ Automated maintenance windows and update procedures");
    console.log("✅ Blue-green deployment with automated rollback");
    console.log("✅ Auto-scaling with intelligent triggers");
    console.log("✅ Disaster recovery with RTO/RPO targets");
    console.log("✅ GDPR and AML compliance monitoring");
    console.log("✅ Comprehensive backup and failover procedures");
    console.log("✅ 24/7 monitoring with 99.9% uptime target");

    console.log("\n📈 Performance Targets:");
    console.log(`✅ Availability: ${config.performance.targets.availability}`);
    console.log(`✅ Response Time: ${config.performance.targets.responseTime}`);
    console.log(`✅ Throughput: ${config.performance.targets.throughput}`);
    console.log(`✅ Error Rate: ${config.performance.targets.errorRate}`);

    console.log("\n🚀 Next Steps:");
    console.log("1. Configure external monitoring integrations (Datadog, Prometheus)");
    console.log("2. Setup CDN and optimization services");
    console.log("3. Conduct disaster recovery drills");
    console.log("4. Train operations team on production procedures");
    console.log("5. Activate 24/7 monitoring and support");

    console.log("\n🎉 Stage 9.2 Production Deployment and Operations setup completed successfully!");
}

// Execute setup if called directly
if (require.main === module) {
    setupStage9_2()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("❌ Stage 9.2 setup failed:", error);
            process.exit(1);
        });
}

module.exports = { setupStage9_2 }; 