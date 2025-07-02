const { ethers } = require("hardhat");
const config = require("../config/stage9.1-config.json");

/**
 * @title Stage 9.1 Validation Script - Security Audit and Hardening
 * @notice Validates that all security infrastructure is properly configured and operational
 */
async function validateStage9_1() {
    console.log("🔍 Validating Stage 9.1: Security Audit and Hardening...");
    
    const [deployer] = await ethers.getSigners();
    let validationResults = {
        passed: 0,
        failed: 0,
        warnings: 0,
        tests: []
    };

    // Get contract addresses from environment
    const contractAddresses = {
        KarmaBugBountyManager: process.env.KARMA_BUG_BOUNTY_MANAGER_ADDRESS,
        KarmaInsuranceManager: process.env.KARMA_INSURANCE_MANAGER_ADDRESS,
        KarmaSecurityMonitoring: process.env.KARMA_SECURITY_MONITORING_ADDRESS,
        USDCToken: process.env.USDC_TOKEN_ADDRESS,
        KarmaToken: process.env.KARMA_TOKEN_ADDRESS
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

    console.log("\n📋 1. Contract Deployment Validation");
    console.log("=====================================");

    // Validate contract addresses
    for (const [name, address] of Object.entries(contractAddresses)) {
        if (!address || address === 'undefined') {
            recordTest(`${name} Address`, false, `Contract address not found in environment`);
            continue;
        }

        try {
            const code = await ethers.provider.getCode(address);
            if (code === '0x') {
                recordTest(`${name} Deployment`, false, `No contract code found at ${address}`);
            } else {
                recordTest(`${name} Deployment`, true, `Contract deployed at ${address}`);
            }
        } catch (error) {
            recordTest(`${name} Deployment`, false, `Error checking deployment: ${error.message}`);
        }
    }

    if (!contractAddresses.KarmaBugBountyManager || !contractAddresses.KarmaInsuranceManager || 
        !contractAddresses.KarmaSecurityMonitoring) {
        console.log("\n❌ Critical contracts missing. Skipping further validation.");
        return validationResults;
    }

    console.log("\n🏆 2. Bug Bounty Manager Validation");
    console.log("===================================");

    try {
        const bugBountyManager = await ethers.getContractAt("KarmaBugBountyManager", contractAddresses.KarmaBugBountyManager);

        // Check if contract is properly initialized
        try {
            const totalPrograms = await bugBountyManager.getTotalBugBountyPrograms();
            recordTest("Bug Bounty Initialization", true, `${totalPrograms} programs registered`);
        } catch (error) {
            recordTest("Bug Bounty Initialization", false, `Contract not properly initialized: ${error.message}`);
        }

        // Check funding
        try {
            const totalFunding = await bugBountyManager.getTotalProgramFunding();
            const expectedFunding = ethers.parseUnits(config.contracts.KarmaBugBountyManager.funding.totalAllocation, 6);
            
            if (totalFunding >= expectedFunding / 2n) { // At least 50% funded
                recordTest("Bug Bounty Funding", true, `${ethers.formatUnits(totalFunding, 6)} USDC funded`);
            } else {
                recordTest("Bug Bounty Funding", false, `Insufficient funding: ${ethers.formatUnits(totalFunding, 6)} USDC`);
            }
        } catch (error) {
            recordTest("Bug Bounty Funding", false, `Error checking funding: ${error.message}`);
        }

        // Check roles
        try {
            const BOUNTY_MANAGER_ROLE = await bugBountyManager.BOUNTY_MANAGER_ROLE();
            const hasManager = await bugBountyManager.hasRole(BOUNTY_MANAGER_ROLE, deployer.address);
            recordTest("Bug Bounty Roles", hasManager, hasManager ? "Roles properly configured" : "Manager role not assigned");
        } catch (error) {
            recordTest("Bug Bounty Roles", false, `Error checking roles: ${error.message}`);
        }

        // Check security features
        try {
            const paused = await bugBountyManager.paused();
            recordTest("Bug Bounty Pause Function", !paused, paused ? "Contract is paused" : "Contract operational");
        } catch (error) {
            recordTest("Bug Bounty Pause Function", false, `Error checking pause state: ${error.message}`);
        }

    } catch (error) {
        recordTest("Bug Bounty Manager Connection", false, `Cannot connect to contract: ${error.message}`);
    }

    console.log("\n🛡️ 3. Insurance Manager Validation");
    console.log("==================================");

    try {
        const insuranceManager = await ethers.getContractAt("KarmaInsuranceManager", contractAddresses.KarmaInsuranceManager);

        // Check insurance fund
        try {
            const fundBalance = await insuranceManager.getInsuranceFundBalance();
            const expectedFund = ethers.parseUnits(config.contracts.KarmaInsuranceManager.configuration.targetInsuranceFund, 6);
            
            if (fundBalance >= expectedFund / 2n) { // At least 50% funded
                recordTest("Insurance Fund", true, `${ethers.formatUnits(fundBalance, 6)} USDC in insurance fund`);
            } else {
                recordTest("Insurance Fund", false, `Insufficient insurance fund: ${ethers.formatUnits(fundBalance, 6)} USDC`);
            }
        } catch (error) {
            recordTest("Insurance Fund", false, `Error checking insurance fund: ${error.message}`);
        }

        // Check coverage types
        try {
            const coverageTypesCount = await insuranceManager.getCoverageTypesCount();
            const expectedTypes = Object.keys(config.contracts.KarmaInsuranceManager.coverageTypes).length;
            
            if (coverageTypesCount >= expectedTypes) {
                recordTest("Insurance Coverage Types", true, `${coverageTypesCount} coverage types registered`);
            } else {
                recordTest("Insurance Coverage Types", false, `Missing coverage types: ${coverageTypesCount}/${expectedTypes}`);
            }
        } catch (error) {
            recordTest("Insurance Coverage Types", false, `Error checking coverage types: ${error.message}`);
        }

        // Check roles
        try {
            const INSURANCE_MANAGER_ROLE = await insuranceManager.INSURANCE_MANAGER_ROLE();
            const hasManager = await insuranceManager.hasRole(INSURANCE_MANAGER_ROLE, deployer.address);
            recordTest("Insurance Roles", hasManager, hasManager ? "Roles properly configured" : "Manager role not assigned");
        } catch (error) {
            recordTest("Insurance Roles", false, `Error checking roles: ${error.message}`);
        }

    } catch (error) {
        recordTest("Insurance Manager Connection", false, `Cannot connect to contract: ${error.message}`);
    }

    console.log("\n📊 4. Security Monitoring Validation");
    console.log("====================================");

    try {
        const securityMonitoring = await ethers.getContractAt("KarmaSecurityMonitoring", contractAddresses.KarmaSecurityMonitoring);

        // Check monitoring status
        try {
            const isActive = await securityMonitoring.isMonitoringActive();
            recordTest("Security Monitoring Status", isActive, isActive ? "Monitoring is active" : "Monitoring is inactive");
        } catch (error) {
            recordTest("Security Monitoring Status", false, `Error checking monitoring status: ${error.message}`);
        }

        // Check monitoring systems
        try {
            const systemsCount = await securityMonitoring.getTotalMonitoringSystems();
            recordTest("Monitoring Systems", systemsCount > 0, `${systemsCount} monitoring systems registered`);
        } catch (error) {
            recordTest("Monitoring Systems", false, `Error checking monitoring systems: ${error.message}`);
        }

        // Check threat detection
        try {
            const threatLevel = await securityMonitoring.getCurrentThreatLevel();
            recordTest("Threat Detection", threatLevel >= 0, `Current threat level: ${threatLevel}/10`);
        } catch (error) {
            recordTest("Threat Detection", false, `Error checking threat level: ${error.message}`);
        }

        // Check security score
        try {
            const securityScore = await securityMonitoring.getSecurityScore();
            recordTest("Security Score", securityScore >= 80, `Security score: ${securityScore}/100`);
        } catch (error) {
            recordTest("Security Score", false, `Error checking security score: ${error.message}`);
        }

        // Check roles
        try {
            const MONITORING_MANAGER_ROLE = await securityMonitoring.MONITORING_MANAGER_ROLE();
            const hasManager = await securityMonitoring.hasRole(MONITORING_MANAGER_ROLE, deployer.address);
            recordTest("Monitoring Roles", hasManager, hasManager ? "Roles properly configured" : "Manager role not assigned");
        } catch (error) {
            recordTest("Monitoring Roles", false, `Error checking roles: ${error.message}`);
        }

    } catch (error) {
        recordTest("Security Monitoring Connection", false, `Cannot connect to contract: ${error.message}`);
    }

    console.log("\n🔗 5. Integration Validation");
    console.log("============================");

    // Check integration between systems
    try {
        const bugBountyManager = await ethers.getContractAt("KarmaBugBountyManager", contractAddresses.KarmaBugBountyManager);
        const securityMonitoring = await ethers.getContractAt("KarmaSecurityMonitoring", contractAddresses.KarmaSecurityMonitoring);

        // Check if bug bounty is connected to security monitoring
        try {
            const connectedMonitoring = await bugBountyManager.getSecurityMonitoring();
            const isConnected = connectedMonitoring.toLowerCase() === contractAddresses.KarmaSecurityMonitoring.toLowerCase();
            recordTest("Bug Bounty Integration", isConnected, 
                isConnected ? "Bug bounty connected to security monitoring" : "Bug bounty not properly integrated");
        } catch (error) {
            recordTest("Bug Bounty Integration", false, `Error checking integration: ${error.message}`);
        }

    } catch (error) {
        recordTest("Integration Check", false, `Error checking integrations: ${error.message}`);
    }

    console.log("\n⚡ 6. Performance and Gas Validation");
    console.log("===================================");

    // Test contract performance
    try {
        const gasPrice = await ethers.provider.getGasPrice();
        const gasThreshold = ethers.parseUnits("100", "gwei"); // 100 gwei
        
        if (gasPrice < gasThreshold) {
            recordTest("Gas Price Check", true, `Current gas price: ${ethers.formatUnits(gasPrice, "gwei")} gwei`);
        } else {
            recordTest("Gas Price Check", false, `High gas price: ${ethers.formatUnits(gasPrice, "gwei")} gwei`, true);
        }
    } catch (error) {
        recordTest("Gas Price Check", false, `Error checking gas price: ${error.message}`);
    }

    // Check network connectivity
    try {
        const blockNumber = await ethers.provider.getBlockNumber();
        recordTest("Network Connectivity", true, `Connected to block ${blockNumber}`);
    } catch (error) {
        recordTest("Network Connectivity", false, `Network connectivity issue: ${error.message}`);
    }

    console.log("\n🔐 7. Security Configuration Validation");
    console.log("=======================================");

    // Validate security configuration matches expected values
    const securityConfig = config.security;
    
    recordTest("Audit Requirements", securityConfig.auditRequirements.mandatoryAudits >= 3, 
        `${securityConfig.auditRequirements.mandatoryAudits} mandatory audits configured`);
    
    recordTest("Threat Model", securityConfig.threatModel.reviewCycle === "QUARTERLY", 
        `Threat model review cycle: ${securityConfig.threatModel.reviewCycle}`);

    recordTest("Emergency Controls", securityConfig.emergencyControls.pauseAuthority.length >= 2,
        `${securityConfig.emergencyControls.pauseAuthority.length} pause authorities configured`);

    console.log("\n📈 8. Monitoring Configuration Validation");
    console.log("=========================================");

    const monitoringConfig = config.monitoring;
    
    recordTest("Forta Integration", monitoringConfig.systems.forta.enabled, 
        `Forta monitoring: ${monitoringConfig.systems.forta.enabled ? "enabled" : "disabled"}`);
    
    recordTest("OpenZeppelin Defender", monitoringConfig.systems.openZeppelinDefender.enabled,
        `Defender monitoring: ${monitoringConfig.systems.openZeppelinDefender.enabled ? "enabled" : "disabled"}`);
    
    recordTest("Custom Monitoring", monitoringConfig.systems.customMonitoring.enabled,
        `Custom monitoring: ${monitoringConfig.systems.customMonitoring.enabled ? "enabled" : "disabled"}`);

    console.log("\n🎯 9. Final System Health Check");
    console.log("===============================");

    // Overall system health assessment
    const healthScore = (validationResults.passed / (validationResults.passed + validationResults.failed)) * 100;
    
    if (healthScore >= 90) {
        recordTest("System Health", true, `Excellent health score: ${healthScore.toFixed(1)}%`);
    } else if (healthScore >= 80) {
        recordTest("System Health", true, `Good health score: ${healthScore.toFixed(1)}%`, true);
    } else if (healthScore >= 70) {
        recordTest("System Health", false, `Poor health score: ${healthScore.toFixed(1)}%`, true);
    } else {
        recordTest("System Health", false, `Critical health score: ${healthScore.toFixed(1)}%`);
    }

    // Production readiness assessment
    const criticalFailures = validationResults.tests.filter(test => !test.passed && !test.isWarning);
    const productionReady = criticalFailures.length === 0 && healthScore >= 90;
    
    recordTest("Production Readiness", productionReady, 
        productionReady ? "System ready for production" : `${criticalFailures.length} critical issues found`);

    console.log("\n📊 Stage 9.1 Validation Summary");
    console.log("===============================");
    console.log(`✅ Tests Passed: ${validationResults.passed}`);
    console.log(`❌ Tests Failed: ${validationResults.failed}`);
    console.log(`⚠️ Warnings: ${validationResults.warnings}`);
    console.log(`📈 Health Score: ${healthScore.toFixed(1)}%`);
    console.log(`🎯 Production Ready: ${productionReady ? "YES" : "NO"}`);

    if (productionReady) {
        console.log("\n🎉 Stage 9.1 Security Audit and Hardening validation completed successfully!");
        console.log("✅ All security infrastructure is properly configured and operational");
        console.log("🔐 Bug bounty program, insurance coverage, and monitoring systems are active");
        console.log("🚀 System is ready for production deployment");
    } else {
        console.log("\n⚠️ Stage 9.1 validation completed with issues");
        console.log("❌ Please address the following critical issues before production:");
        criticalFailures.forEach(failure => {
            console.log(`   - ${failure.name}: ${failure.message}`);
        });
    }

    console.log("\n📋 Next Steps:");
    console.log("1. Address any critical issues identified above");
    console.log("2. Launch bug bounty program on Immunefi platform");
    console.log("3. Activate insurance coverage with Nexus Mutual");
    console.log("4. Configure external monitoring integrations");
    console.log("5. Conduct security team training and emergency drills");
    console.log("6. Proceed to Stage 9.2 Production Deployment validation");

    return validationResults;
}

// Execute validation if called directly
if (require.main === module) {
    validateStage9_1()
        .then((results) => {
            const success = results.failed === 0;
            process.exit(success ? 0 : 1);
        })
        .catch((error) => {
            console.error("❌ Stage 9.1 validation failed:", error);
            process.exit(1);
        });
}

module.exports = { validateStage9_1 }; 