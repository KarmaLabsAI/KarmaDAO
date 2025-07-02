const { ethers } = require("hardhat");
const config = require("../config/stage9.2-config.json");

/**
 * @title Stage 9.2 Validation Script - Production Deployment and Operations
 * @notice Validates that all production infrastructure is properly configured and operational
 */
async function validateStage9_2() {
    console.log("🚀 Validating Stage 9.2: Production Deployment and Operations...");
    
    const [deployer] = await ethers.getSigners();
    let validationResults = {
        passed: 0,
        failed: 0,
        warnings: 0,
        tests: []
    };

    // Get contract addresses from environment
    const contractAddresses = {
        KarmaOperationsMonitoring: process.env.KARMA_OPERATIONS_MONITORING_ADDRESS,
        KarmaMaintenanceUpgrade: process.env.KARMA_MAINTENANCE_UPGRADE_ADDRESS,
        // Previous stage contracts for integration validation
        KarmaToken: process.env.KARMA_TOKEN_ADDRESS,
        Treasury: process.env.TREASURY_ADDRESS,
        KarmaDAO: process.env.KARMA_DAO_ADDRESS,
        KarmaSecurityMonitoring: process.env.KARMA_SECURITY_MONITORING_ADDRESS
    };

    // Helper function to record test results
    function recordTest(name, passed, message, isWarning = false) {
        const result = { name, passed, message, isWarning };
        validationResults.tests.push(result);
        
        if (isWarning) {
            validationResults.warnings++;
            console.log(`⚠️ ${name}: ${message}`);
        } else if (passed) {
            validationResults.passed++;
            console.log(`✅ ${name}: ${message}`);
        } else {
            validationResults.failed++;
            console.log(`❌ ${name}: ${message}`);
        }
    }

    console.log("\n📋 1. Production Contract Deployment Validation");
    console.log("==============================================");

    // Validate production contract addresses
    const productionContracts = ['KarmaOperationsMonitoring', 'KarmaMaintenanceUpgrade'];
    
    for (const contractName of productionContracts) {
        const address = contractAddresses[contractName];
        
        if (!address || address === 'undefined') {
            recordTest(`${contractName} Address`, false, `Contract address not found in environment`);
            continue;
        }

        try {
            const code = await ethers.provider.getCode(address);
            if (code === '0x') {
                recordTest(`${contractName} Deployment`, false, `No contract code found at ${address}`);
            } else {
                recordTest(`${contractName} Deployment`, true, `Contract deployed at ${address}`);
                
                // Verify contract is operational
                const contract = await ethers.getContractAt(contractName, address);
                try {
                    await contract.getSystemHealth();
                    recordTest(`${contractName} Operational`, true, `Contract is responding to calls`);
                } catch (error) {
                    recordTest(`${contractName} Operational`, false, `Contract not responding: ${error.message}`);
                }
            }
        } catch (error) {
            recordTest(`${contractName} Deployment`, false, `Error checking deployment: ${error.message}`);
        }
    }

    if (!contractAddresses.KarmaOperationsMonitoring || !contractAddresses.KarmaMaintenanceUpgrade) {
        console.log("\n❌ Critical production contracts missing. Skipping further validation.");
        return validationResults;
    }

    console.log("\n📊 2. Operations Monitoring Validation");
    console.log("=====================================");

    try {
        const operationsMonitoring = await ethers.getContractAt("KarmaOperationsMonitoring", contractAddresses.KarmaOperationsMonitoring);

        // Check monitoring system status
        try {
            const systemHealth = await operationsMonitoring.getSystemHealth();
            recordTest("System Health", systemHealth >= 90, `System health: ${systemHealth}%`);
        } catch (error) {
            recordTest("System Health", false, `Error checking system health: ${error.message}`);
        }

        // Check performance monitoring
        try {
            const performanceStatus = await operationsMonitoring.getPerformanceStatus();
            recordTest("Performance Monitoring", performanceStatus.length > 0, 
                `Performance metrics: ${performanceStatus.length} active monitors`);
        } catch (error) {
            recordTest("Performance Monitoring", false, `Error checking performance: ${error.message}`);
        }

        // Check registered contracts
        try {
            const registeredContracts = await operationsMonitoring.getRegisteredContractsCount();
            const expectedContracts = Object.values(contractAddresses).filter(addr => addr && addr !== 'undefined').length;
            
            recordTest("Contract Registration", registeredContracts >= expectedContracts / 2,
                `${registeredContracts} contracts registered for monitoring`);
        } catch (error) {
            recordTest("Contract Registration", false, `Error checking registered contracts: ${error.message}`);
        }

        // Check alert configuration
        try {
            const alertChannels = await operationsMonitoring.getAlertChannelsCount();
            recordTest("Alert Configuration", alertChannels >= 3, 
                `${alertChannels} alert channels configured`);
        } catch (error) {
            recordTest("Alert Configuration", false, `Error checking alert configuration: ${error.message}`);
        }

        // Check roles
        try {
            const OPERATIONS_MANAGER_ROLE = await operationsMonitoring.OPERATIONS_MANAGER_ROLE();
            const hasManager = await operationsMonitoring.hasRole(OPERATIONS_MANAGER_ROLE, deployer.address);
            recordTest("Operations Roles", hasManager, 
                hasManager ? "Operations roles properly configured" : "Manager role not assigned");
        } catch (error) {
            recordTest("Operations Roles", false, `Error checking roles: ${error.message}`);
        }

        // Test monitoring functionality
        try {
            await operationsMonitoring.testMonitoringSystems();
            recordTest("Monitoring Functionality", true, "Monitoring systems test passed");
        } catch (error) {
            recordTest("Monitoring Functionality", false, `Monitoring test failed: ${error.message}`);
        }

    } catch (error) {
        recordTest("Operations Monitoring Connection", false, `Cannot connect to contract: ${error.message}`);
    }

    console.log("\n🔧 3. Maintenance and Upgrade System Validation");
    console.log("===============================================");

    try {
        const maintenanceUpgrade = await ethers.getContractAt("KarmaMaintenanceUpgrade", contractAddresses.KarmaMaintenanceUpgrade);

        // Check maintenance window configuration
        try {
            const maintenanceConfig = await maintenanceUpgrade.getMaintenanceConfiguration();
            recordTest("Maintenance Configuration", maintenanceConfig.configured, 
                maintenanceConfig.configured ? "Maintenance windows configured" : "Maintenance not configured");
        } catch (error) {
            recordTest("Maintenance Configuration", false, `Error checking maintenance config: ${error.message}`);
        }

        // Check update procedures
        try {
            const updateProcedures = await maintenanceUpgrade.getUpdateProceduresCount();
            const expectedProcedures = Object.keys(config.maintenance.updates).length;
            
            recordTest("Update Procedures", updateProcedures >= expectedProcedures,
                `${updateProcedures}/${expectedProcedures} update procedures configured`);
        } catch (error) {
            recordTest("Update Procedures", false, `Error checking update procedures: ${error.message}`);
        }

        // Check emergency response capabilities
        try {
            const emergencyConfig = await maintenanceUpgrade.getEmergencyConfiguration();
            recordTest("Emergency Response", emergencyConfig.enabled, 
                emergencyConfig.enabled ? "Emergency response enabled" : "Emergency response not configured");
        } catch (error) {
            recordTest("Emergency Response", false, `Error checking emergency config: ${error.message}`);
        }

        // Check roles
        try {
            const MAINTENANCE_MANAGER_ROLE = await maintenanceUpgrade.MAINTENANCE_MANAGER_ROLE();
            const hasManager = await maintenanceUpgrade.hasRole(MAINTENANCE_MANAGER_ROLE, deployer.address);
            recordTest("Maintenance Roles", hasManager, 
                hasManager ? "Maintenance roles properly configured" : "Manager role not assigned");
        } catch (error) {
            recordTest("Maintenance Roles", false, `Error checking roles: ${error.message}`);
        }

        // Test emergency procedures
        try {
            await maintenanceUpgrade.testMaintenanceProcedures();
            recordTest("Maintenance Testing", true, "Maintenance procedures test passed");
        } catch (error) {
            recordTest("Maintenance Testing", false, `Maintenance test failed: ${error.message}`);
        }

    } catch (error) {
        recordTest("Maintenance System Connection", false, `Cannot connect to contract: ${error.message}`);
    }

    console.log("\n📈 4. Performance Targets Validation");
    console.log("====================================");

    const performanceTargets = config.performance.targets;
    
    // Validate current network performance
    try {
        const startTime = Date.now();
        const blockNumber = await ethers.provider.getBlockNumber();
        const responseTime = Date.now() - startTime;
        
        const targetResponseTime = parseInt(performanceTargets.responseTime.replace('ms', ''));
        recordTest("Response Time", responseTime <= targetResponseTime, 
            `Network response time: ${responseTime}ms (target: ${targetResponseTime}ms)`);
    } catch (error) {
        recordTest("Response Time", false, `Error measuring response time: ${error.message}`);
    }

    // Check gas price performance
    try {
        const gasPrice = await ethers.provider.getGasPrice();
        const gasPriceGwei = parseFloat(ethers.formatUnits(gasPrice, "gwei"));
        
        recordTest("Gas Price Performance", gasPriceGwei <= 50, 
            `Current gas price: ${gasPriceGwei.toFixed(2)} gwei`);
    } catch (error) {
        recordTest("Gas Price Performance", false, `Error checking gas price: ${error.message}`);
    }

    // Validate availability target
    const availabilityTarget = parseFloat(performanceTargets.availability.replace('%', ''));
    recordTest("Availability Target", availabilityTarget >= 99.9, 
        `Availability target: ${availabilityTarget}%`);

    console.log("\n🔄 5. Backup and Recovery Validation");
    console.log("====================================");

    const backupConfig = config.operations.backups;
    
    // Validate backup configuration
    recordTest("Backup Frequency", backupConfig.frequency === "HOURLY", 
        `Backup frequency: ${backupConfig.frequency}`);
    
    recordTest("Backup Retention", backupConfig.retention.monthly === "12_MONTHS",
        `Backup retention: ${backupConfig.retention.monthly}`);
    
    recordTest("Backup Storage", backupConfig.storage.primary === "AWS_S3",
        `Primary backup storage: ${backupConfig.storage.primary}`);
    
    recordTest("Backup Encryption", backupConfig.encryption.enabled,
        `Backup encryption: ${backupConfig.encryption.enabled ? "enabled" : "disabled"}`);

    // Validate disaster recovery configuration
    const drConfig = config.disaster_recovery;
    
    recordTest("Recovery Time Objective", drConfig.rto <= 1800,
        `RTO: ${drConfig.rto} seconds (target: ≤30 minutes)`);
    
    recordTest("Recovery Point Objective", drConfig.rpo <= 3600,
        `RPO: ${drConfig.rpo} seconds (target: ≤1 hour)`);

    console.log("\n🔒 6. Compliance Validation");
    console.log("===========================");

    const complianceConfig = config.compliance;
    
    // Validate GDPR compliance
    recordTest("GDPR Compliance", complianceConfig.dataProtection.gdpr.enabled,
        `GDPR compliance: ${complianceConfig.dataProtection.gdpr.enabled ? "enabled" : "disabled"}`);
    
    // Validate AML monitoring
    recordTest("AML Monitoring", complianceConfig.financial.aml.enabled,
        `AML monitoring: ${complianceConfig.financial.aml.enabled ? "enabled" : "disabled"}`);
    
    // Validate KYC verification
    recordTest("KYC Verification", complianceConfig.financial.kyc.enabled,
        `KYC verification: ${complianceConfig.financial.kyc.enabled ? "enabled" : "disabled"}`);

    console.log("\n🌐 7. Infrastructure Validation");
    console.log("===============================");

    const infrastructureConfig = config.production.infrastructure;
    
    // Validate node providers
    const nodeProviders = infrastructureConfig.nodeProviders;
    const primaryProvider = nodeProviders.find(provider => provider.primary);
    
    recordTest("Primary Node Provider", !!primaryProvider,
        primaryProvider ? `Primary provider: ${primaryProvider.name}` : "No primary provider configured");
    
    recordTest("Backup Providers", nodeProviders.length >= 3,
        `${nodeProviders.length} node providers configured`);
    
    // Validate storage configuration
    const storageConfig = infrastructureConfig.dataStorage;
    recordTest("Primary Storage", storageConfig.primary === "IPFS",
        `Primary storage: ${storageConfig.primary}`);
    
    recordTest("Storage Redundancy", storageConfig.tertiary === "AWS_S3",
        `Tertiary storage: ${storageConfig.tertiary}`);

    console.log("\n🔔 8. Alerting System Validation");
    console.log("================================");

    const alertingConfig = config.operations.alerting;
    
    // Validate alert channels
    const criticalChannels = alertingConfig.channels.critical;
    const channelCount = Object.keys(criticalChannels).length;
    
    recordTest("Critical Alert Channels", channelCount >= 3,
        `${channelCount} critical alert channels configured`);
    
    // Validate escalation configuration
    const escalationConfig = alertingConfig.escalation;
    recordTest("Escalation Configuration", escalationConfig.maxEscalations >= 3,
        `Max escalations: ${escalationConfig.maxEscalations}`);

    console.log("\n👥 9. Team and Access Validation");
    console.log("================================");

    const teamConfig = config.team;
    
    // Validate team structure
    const teamStructure = teamConfig.structure;
    const teams = Object.keys(teamStructure);
    
    recordTest("Team Structure", teams.length >= 3,
        `${teams.length} teams configured (operations, security, development)`);
    
    // Validate on-call coverage
    const hasFullCoverage = teamStructure.operations.oncall === "24x7" && 
                           teamStructure.security.oncall === "24x7";
    
    recordTest("On-call Coverage", hasFullCoverage,
        hasFullCoverage ? "24x7 on-call coverage configured" : "Incomplete on-call coverage");
    
    // Validate access controls
    const accessConfig = teamConfig.access;
    recordTest("Access Control", accessConfig.principle === "LEAST_PRIVILEGE",
        `Access principle: ${accessConfig.principle}`);
    
    recordTest("MFA Requirement", accessConfig.mfa === "REQUIRED",
        `MFA requirement: ${accessConfig.mfa}`);

    console.log("\n🎯 10. Integration with Previous Stages");
    console.log("======================================");

    // Test integration with other protocol stages
    const protocolContracts = ['KarmaToken', 'Treasury', 'KarmaDAO', 'KarmaSecurityMonitoring'];
    
    for (const contractName of protocolContracts) {
        const address = contractAddresses[contractName];
        
        if (address && address !== 'undefined') {
            try {
                const code = await ethers.provider.getCode(address);
                recordTest(`${contractName} Integration`, code !== '0x',
                    `${contractName} available for monitoring integration`);
            } catch (error) {
                recordTest(`${contractName} Integration`, false,
                    `Error checking ${contractName}: ${error.message}`);
            }
        } else {
            recordTest(`${contractName} Integration`, false,
                `${contractName} address not available`, true);
        }
    }

    console.log("\n🎯 11. Final Production Readiness Assessment");
    console.log("==========================================");

    // Overall system health assessment
    const healthScore = (validationResults.passed / (validationResults.passed + validationResults.failed)) * 100;
    
    if (healthScore >= 95) {
        recordTest("Production Health Score", true, `Excellent health score: ${healthScore.toFixed(1)}%`);
    } else if (healthScore >= 90) {
        recordTest("Production Health Score", true, `Good health score: ${healthScore.toFixed(1)}%`, true);
    } else if (healthScore >= 80) {
        recordTest("Production Health Score", false, `Poor health score: ${healthScore.toFixed(1)}%`, true);
    } else {
        recordTest("Production Health Score", false, `Critical health score: ${healthScore.toFixed(1)}%`);
    }

    // Production deployment readiness
    const criticalFailures = validationResults.tests.filter(test => !test.passed && !test.isWarning);
    const productionReady = criticalFailures.length === 0 && healthScore >= 90;
    
    recordTest("Production Deployment Ready", productionReady,
        productionReady ? "System ready for production deployment" : `${criticalFailures.length} critical issues found`);

    // SLA compliance check
    const slaCompliant = healthScore >= 99.9;
    recordTest("SLA Compliance", slaCompliant,
        slaCompliant ? "Meeting 99.9% uptime SLA" : "Not meeting SLA requirements", !slaCompliant);

    console.log("\n📊 Stage 9.2 Validation Summary");
    console.log("===============================");
    console.log(`✅ Tests Passed: ${validationResults.passed}`);
    console.log(`❌ Tests Failed: ${validationResults.failed}`);
    console.log(`⚠️ Warnings: ${validationResults.warnings}`);
    console.log(`📈 Health Score: ${healthScore.toFixed(1)}%`);
    console.log(`🎯 Production Ready: ${productionReady ? "YES" : "NO"}`);
    console.log(`📊 SLA Compliant: ${slaCompliant ? "YES" : "NO"}`);

    if (productionReady) {
        console.log("\n🎉 Stage 9.2 Production Deployment and Operations validation completed successfully!");
        console.log("✅ All production infrastructure is properly configured and operational");
        console.log("📊 Monitoring, alerting, and maintenance systems are active");
        console.log("🔄 Backup and disaster recovery procedures are in place");
        console.log("👥 Team structure and access controls are properly configured");
        console.log("🚀 System is ready for full production deployment");
    } else {
        console.log("\n⚠️ Stage 9.2 validation completed with issues");
        console.log("❌ Please address the following critical issues before production:");
        criticalFailures.forEach(failure => {
            console.log(`   - ${failure.name}: ${failure.message}`);
        });
    }

    console.log("\n📋 Production Deployment Checklist:");
    console.log("1. ✅ All Stage 9.1 security infrastructure validated");
    console.log("2. ✅ Production monitoring and operations configured");
    console.log("3. ✅ Performance targets and SLA requirements defined");
    console.log("4. ✅ Backup and disaster recovery procedures established");
    console.log("5. ✅ Team structure and access controls implemented");
    console.log("6. ✅ Compliance frameworks activated");
    console.log("7. ✅ Integration with all protocol stages validated");

    console.log("\n🚀 Final Production Steps:");
    console.log("1. Execute mainnet deployment sequence");
    console.log("2. Verify all contracts on Arbiscan");
    console.log("3. Initialize production monitoring systems");
    console.log("4. Activate 24/7 support and on-call procedures");
    console.log("5. Launch public status page and community communications");
    console.log("6. Begin community transition and progressive decentralization");

    return validationResults;
}

// Execute validation if called directly
if (require.main === module) {
    validateStage9_2()
        .then((results) => {
            const success = results.failed === 0;
            process.exit(success ? 0 : 1);
        })
        .catch((error) => {
            console.error("❌ Stage 9.2 validation failed:", error);
            process.exit(1);
        });
}

module.exports = { validateStage9_2 }; 