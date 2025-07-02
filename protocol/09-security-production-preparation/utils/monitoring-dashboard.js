const { ethers } = require("hardhat");

/**
 * @title KarmaLabs Monitoring Dashboard
 * @notice Real-time monitoring and analytics dashboard for the entire ecosystem
 * @dev Provides comprehensive monitoring of all protocol stages and components
 */
class KarmaMonitoringDashboard {
    constructor(provider, contractAddresses, config = {}) {
        this.provider = provider;
        this.contracts = {};
        this.metrics = {};
        this.alerts = [];
        this.config = {
            refreshInterval: 30000, // 30 seconds
            alertThresholds: {
                gasPrice: 100000000000, // 100 gwei
                failureRate: 0.05, // 5%
                responseTime: 2000, // 2 seconds
                volumeSpike: 300, // 300% increase
                ...config.alertThresholds
            },
            ...config
        };
        
        this.initializeContracts(contractAddresses);
        this.startMonitoring();
    }

    /**
     * Initialize contract connections for monitoring
     */
    async initializeContracts(addresses) {
        try {
            // Stage 1: Core Token Infrastructure
            if (addresses.KarmaToken) {
                this.contracts.karmaToken = await ethers.getContractAt("KarmaToken", addresses.KarmaToken);
            }
            
            // Stage 2: Vesting System
            if (addresses.VestingVault) {
                this.contracts.vestingVault = await ethers.getContractAt("VestingVault", addresses.VestingVault);
            }
            
            // Stage 3: Token Sales
            if (addresses.SaleManager) {
                this.contracts.saleManager = await ethers.getContractAt("SaleManager", addresses.SaleManager);
            }
            
            // Stage 4: Treasury
            if (addresses.Treasury) {
                this.contracts.treasury = await ethers.getContractAt("Treasury", addresses.Treasury);
            }
            
            // Stage 5: Paymaster
            if (addresses.Paymaster) {
                this.contracts.paymaster = await ethers.getContractAt("Paymaster", addresses.Paymaster);
            }
            
            // Stage 6: Tokenomics
            if (addresses.BuybackBurn) {
                this.contracts.buybackBurn = await ethers.getContractAt("BuybackBurn", addresses.BuybackBurn);
            }
            
            // Stage 7: Governance
            if (addresses.KarmaDAO) {
                this.contracts.karmaDAO = await ethers.getContractAt("KarmaDAO", addresses.KarmaDAO);
            }
            
            // Stage 8: External Integration
            if (addresses.ZeroGIntegration) {
                this.contracts.zeroGIntegration = await ethers.getContractAt("ZeroGIntegration", addresses.ZeroGIntegration);
            }
            
            // Stage 9: Security & Monitoring
            if (addresses.KarmaSecurityMonitoring) {
                this.contracts.securityMonitoring = await ethers.getContractAt("KarmaSecurityMonitoring", addresses.KarmaSecurityMonitoring);
            }
            
            console.log("✅ Contract connections initialized for monitoring");
            
        } catch (error) {
            console.error("❌ Failed to initialize contract connections:", error);
            throw error;
        }
    }

    /**
     * Start continuous monitoring of all systems
     */
    startMonitoring() {
        console.log("🔄 Starting continuous monitoring...");
        
        // Main monitoring loop
        this.monitoringInterval = setInterval(async () => {
            try {
                await this.collectAllMetrics();
                await this.analyzeMetrics();
                await this.checkAlertConditions();
                await this.updateDashboard();
            } catch (error) {
                console.error("❌ Monitoring cycle error:", error);
            }
        }, this.config.refreshInterval);

        // Network monitoring
        this.networkInterval = setInterval(async () => {
            await this.monitorNetworkConditions();
        }, 10000); // Every 10 seconds

        // Security monitoring (high frequency)
        this.securityInterval = setInterval(async () => {
            await this.monitorSecurityMetrics();
        }, 5000); // Every 5 seconds
    }

    /**
     * Collect comprehensive metrics from all protocol stages
     */
    async collectAllMetrics() {
        const timestamp = Date.now();
        const blockNumber = await this.provider.getBlockNumber();
        
        this.metrics = {
            timestamp,
            blockNumber,
            network: await this.collectNetworkMetrics(),
            stage1: await this.collectStage1Metrics(),
            stage2: await this.collectStage2Metrics(),
            stage3: await this.collectStage3Metrics(),
            stage4: await this.collectStage4Metrics(),
            stage5: await this.collectStage5Metrics(),
            stage6: await this.collectStage6Metrics(),
            stage7: await this.collectStage7Metrics(),
            stage8: await this.collectStage8Metrics(),
            stage9: await this.collectStage9Metrics(),
            system: await this.collectSystemMetrics()
        };
    }

    /**
     * Collect network-level metrics
     */
    async collectNetworkMetrics() {
        try {
            const gasPrice = await this.provider.getGasPrice();
            const balance = await this.provider.getBalance(this.contracts.treasury?.address || ethers.ZeroAddress);
            
            return {
                gasPrice: gasPrice.toString(),
                treasuryBalance: balance.toString(),
                blockTime: await this.calculateAverageBlockTime(),
                networkUtilization: await this.calculateNetworkUtilization()
            };
        } catch (error) {
            console.error("❌ Failed to collect network metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 1 (Core Token) metrics
     */
    async collectStage1Metrics() {
        if (!this.contracts.karmaToken) return {};
        
        try {
            const totalSupply = await this.contracts.karmaToken.totalSupply();
            const circulatingSupply = await this.calculateCirculatingSupply();
            const holders = await this.countTokenHolders();
            
            return {
                totalSupply: totalSupply.toString(),
                circulatingSupply: circulatingSupply.toString(),
                uniqueHolders: holders,
                transferCount24h: await this.getTransferCount24h(),
                avgTransferSize: await this.getAverageTransferSize()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 1 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 2 (Vesting) metrics
     */
    async collectStage2Metrics() {
        if (!this.contracts.vestingVault) return {};
        
        try {
            const totalVested = await this.contracts.vestingVault.getTotalVestedAmount();
            const totalClaimed = await this.contracts.vestingVault.getTotalClaimedAmount();
            const activeBeneficiaries = await this.contracts.vestingVault.getActiveBeneficiariesCount();
            
            return {
                totalVested: totalVested.toString(),
                totalClaimed: totalClaimed.toString(),
                vestingProgress: ((totalClaimed * 10000n) / totalVested).toString(),
                activeBeneficiaries: activeBeneficiaries.toString(),
                claimsCount24h: await this.getVestingClaims24h()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 2 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 3 (Token Sales) metrics
     */
    async collectStage3Metrics() {
        if (!this.contracts.saleManager) return {};
        
        try {
            const currentPhase = await this.contracts.saleManager.getCurrentPhase();
            const totalRaised = await this.contracts.saleManager.getTotalRaised();
            const tokensSold = await this.contracts.saleManager.getTotalTokensSold();
            
            return {
                currentPhase: currentPhase.toString(),
                totalRaised: totalRaised.toString(),
                tokensSold: tokensSold.toString(),
                purchaseCount24h: await this.getSalePurchases24h(),
                avgPurchaseSize: await this.getAveragePurchaseSize()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 3 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 4 (Treasury) metrics
     */
    async collectStage4Metrics() {
        if (!this.contracts.treasury) return {};
        
        try {
            const treasuryBalance = await this.contracts.treasury.getTreasuryBalance();
            const allocations = await this.contracts.treasury.getAllAllocations();
            const withdrawals24h = await this.getTreasuryWithdrawals24h();
            
            return {
                totalBalance: treasuryBalance.toString(),
                marketingAllocation: allocations[0]?.toString() || "0",
                developmentAllocation: allocations[1]?.toString() || "0",
                buybackAllocation: allocations[2]?.toString() || "0",
                withdrawals24h: withdrawals24h.toString(),
                utilizationRate: await this.calculateTreasuryUtilization()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 4 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 5 (Paymaster) metrics
     */
    async collectStage5Metrics() {
        if (!this.contracts.paymaster) return {};
        
        try {
            const sponsoredGas = await this.contracts.paymaster.getTotalSponsoredGas();
            const activeUsers = await this.contracts.paymaster.getActiveUsersCount();
            const gasBalance = await this.provider.getBalance(this.contracts.paymaster.address);
            
            return {
                totalSponsoredGas: sponsoredGas.toString(),
                activeUsers: activeUsers.toString(),
                gasBalance: gasBalance.toString(),
                sponsoredTxs24h: await this.getSponsoredTransactions24h(),
                avgGasSponsored: await this.getAverageGasSponsored()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 5 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 6 (Tokenomics) metrics
     */
    async collectStage6Metrics() {
        if (!this.contracts.buybackBurn) return {};
        
        try {
            const totalBurned = await this.contracts.buybackBurn.getTotalBurned();
            const lastBuyback = await this.contracts.buybackBurn.getLastBuybackAmount();
            const buybacksCount = await this.contracts.buybackBurn.getBuybacksCount();
            
            return {
                totalBurned: totalBurned.toString(),
                lastBuybackAmount: lastBuyback.toString(),
                totalBuybacks: buybacksCount.toString(),
                buybacks24h: await this.getBuybacks24h(),
                burnRate: await this.calculateBurnRate()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 6 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 7 (Governance) metrics
     */
    async collectStage7Metrics() {
        if (!this.contracts.karmaDAO) return {};
        
        try {
            const activeProposals = await this.contracts.karmaDAO.getActiveProposalsCount();
            const totalVoters = await this.contracts.karmaDAO.getTotalVoters();
            const participationRate = await this.contracts.karmaDAO.getParticipationRate();
            
            return {
                activeProposals: activeProposals.toString(),
                totalVoters: totalVoters.toString(),
                participationRate: participationRate.toString(),
                votes24h: await this.getVotes24h(),
                proposalsCreated24h: await this.getProposalsCreated24h()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 7 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 8 (External Integration) metrics
     */
    async collectStage8Metrics() {
        if (!this.contracts.zeroGIntegration) return {};
        
        try {
            const aiInferenceCount = await this.contracts.zeroGIntegration.getTotalInferences();
            const crossChainTxs = await this.contracts.zeroGIntegration.getCrossChainTransactions();
            const integrationHealth = await this.contracts.zeroGIntegration.getIntegrationHealth();
            
            return {
                totalInferences: aiInferenceCount.toString(),
                crossChainTransactions: crossChainTxs.toString(),
                integrationHealth: integrationHealth.toString(),
                inferences24h: await this.getInferences24h(),
                avgInferenceCost: await this.getAverageInferenceCost()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 8 metrics:", error);
            return {};
        }
    }

    /**
     * Collect Stage 9 (Security) metrics
     */
    async collectStage9Metrics() {
        if (!this.contracts.securityMonitoring) return {};
        
        try {
            const securityScore = await this.contracts.securityMonitoring.getSecurityScore();
            const threatLevel = await this.contracts.securityMonitoring.getCurrentThreatLevel();
            const incidentsResolved = await this.contracts.securityMonitoring.getIncidentsResolvedCount();
            
            return {
                securityScore: securityScore.toString(),
                threatLevel: threatLevel.toString(),
                incidentsResolved: incidentsResolved.toString(),
                alerts24h: await this.getSecurityAlerts24h(),
                responseTime: await this.getAverageResponseTime()
            };
        } catch (error) {
            console.error("❌ Failed to collect Stage 9 metrics:", error);
            return {};
        }
    }

    /**
     * Collect system-wide metrics
     */
    async collectSystemMetrics() {
        try {
            return {
                systemUptime: process.uptime(),
                memoryUsage: process.memoryUsage(),
                activeConnections: await this.getActiveConnections(),
                errorRate: await this.calculateErrorRate(),
                responseTime: await this.calculateAverageResponseTime()
            };
        } catch (error) {
            console.error("❌ Failed to collect system metrics:", error);
            return {};
        }
    }

    /**
     * Analyze metrics for trends and anomalies
     */
    async analyzeMetrics() {
        try {
            // Trend analysis
            this.trends = {
                gasPrice: this.analyzeTrend('network.gasPrice'),
                volume: this.analyzeTrend('stage1.transferCount24h'),
                participation: this.analyzeTrend('stage7.participationRate'),
                security: this.analyzeTrend('stage9.securityScore')
            };

            // Anomaly detection
            this.anomalies = {
                gasSpike: this.detectGasSpike(),
                volumeSpike: this.detectVolumeSpike(),
                failureSpike: this.detectFailureSpike(),
                securityDrop: this.detectSecurityDrop()
            };

            // Performance analysis
            this.performance = {
                overall: this.calculateOverallHealth(),
                stages: this.calculateStageHealth(),
                critical: this.identifyCriticalIssues()
            };

        } catch (error) {
            console.error("❌ Failed to analyze metrics:", error);
        }
    }

    /**
     * Check for alert conditions and trigger notifications
     */
    async checkAlertConditions() {
        const alerts = [];

        try {
            // Critical alerts
            if (this.metrics.network.gasPrice > this.config.alertThresholds.gasPrice) {
                alerts.push({
                    level: 'CRITICAL',
                    type: 'GAS_PRICE_SPIKE',
                    message: `Gas price spiked to ${ethers.formatUnits(this.metrics.network.gasPrice, 'gwei')} gwei`,
                    timestamp: Date.now()
                });
            }

            // Security alerts
            if (this.metrics.stage9.threatLevel > 7) {
                alerts.push({
                    level: 'HIGH',
                    type: 'SECURITY_THREAT',
                    message: `Threat level elevated to ${this.metrics.stage9.threatLevel}/10`,
                    timestamp: Date.now()
                });
            }

            // Performance alerts
            if (this.performance.overall < 0.9) {
                alerts.push({
                    level: 'MEDIUM',
                    type: 'PERFORMANCE_DEGRADATION',
                    message: `Overall system health dropped to ${(this.performance.overall * 100).toFixed(1)}%`,
                    timestamp: Date.now()
                });
            }

            // Treasury alerts
            if (this.metrics.stage4.utilizationRate > 0.8) {
                alerts.push({
                    level: 'HIGH',
                    type: 'TREASURY_UTILIZATION',
                    message: `Treasury utilization at ${(this.metrics.stage4.utilizationRate * 100).toFixed(1)}%`,
                    timestamp: Date.now()
                });
            }

            this.alerts = alerts;
            
            if (alerts.length > 0) {
                await this.sendAlertNotifications(alerts);
            }

        } catch (error) {
            console.error("❌ Failed to check alert conditions:", error);
        }
    }

    /**
     * Send alert notifications through configured channels
     */
    async sendAlertNotifications(alerts) {
        for (const alert of alerts) {
            try {
                // Console logging
                const emoji = alert.level === 'CRITICAL' ? '🚨' : alert.level === 'HIGH' ? '⚠️' : 'ℹ️';
                console.log(`${emoji} ${alert.level}: ${alert.message}`);

                // Send to external monitoring systems
                await this.sendToSlack(alert);
                await this.sendToDiscord(alert);
                
                if (alert.level === 'CRITICAL') {
                    await this.sendSMSAlert(alert);
                }

            } catch (error) {
                console.error("❌ Failed to send alert notification:", error);
            }
        }
    }

    /**
     * Update dashboard with latest metrics
     */
    async updateDashboard() {
        try {
            const dashboardData = {
                timestamp: this.metrics.timestamp,
                overview: {
                    systemHealth: this.performance.overall,
                    activeAlerts: this.alerts.length,
                    gasPrice: ethers.formatUnits(this.metrics.network.gasPrice || "0", 'gwei'),
                    treasuryBalance: ethers.formatEther(this.metrics.stage4.totalBalance || "0")
                },
                stages: {
                    stage1: {
                        name: "Core Token",
                        health: this.performance.stages.stage1 || 1.0,
                        key_metrics: {
                            holders: this.metrics.stage1.uniqueHolders,
                            transfers24h: this.metrics.stage1.transferCount24h
                        }
                    },
                    stage2: {
                        name: "Vesting System",
                        health: this.performance.stages.stage2 || 1.0,
                        key_metrics: {
                            progress: `${(this.metrics.stage2.vestingProgress || 0) / 100}%`,
                            beneficiaries: this.metrics.stage2.activeBeneficiaries
                        }
                    },
                    stage3: {
                        name: "Token Sales",
                        health: this.performance.stages.stage3 || 1.0,
                        key_metrics: {
                            phase: this.metrics.stage3.currentPhase,
                            raised: ethers.formatEther(this.metrics.stage3.totalRaised || "0")
                        }
                    },
                    stage4: {
                        name: "Treasury",
                        health: this.performance.stages.stage4 || 1.0,
                        key_metrics: {
                            balance: ethers.formatEther(this.metrics.stage4.totalBalance || "0"),
                            utilization: `${((this.metrics.stage4.utilizationRate || 0) * 100).toFixed(1)}%`
                        }
                    },
                    stage5: {
                        name: "Paymaster",
                        health: this.performance.stages.stage5 || 1.0,
                        key_metrics: {
                            users: this.metrics.stage5.activeUsers,
                            sponsored24h: this.metrics.stage5.sponsoredTxs24h
                        }
                    },
                    stage6: {
                        name: "Tokenomics",
                        health: this.performance.stages.stage6 || 1.0,
                        key_metrics: {
                            burned: ethers.formatEther(this.metrics.stage6.totalBurned || "0"),
                            buybacks: this.metrics.stage6.totalBuybacks
                        }
                    },
                    stage7: {
                        name: "Governance",
                        health: this.performance.stages.stage7 || 1.0,
                        key_metrics: {
                            proposals: this.metrics.stage7.activeProposals,
                            participation: `${((this.metrics.stage7.participationRate || 0) / 100).toFixed(1)}%`
                        }
                    },
                    stage8: {
                        name: "Integration",
                        health: this.performance.stages.stage8 || 1.0,
                        key_metrics: {
                            inferences: this.metrics.stage8.totalInferences,
                            crosschain: this.metrics.stage8.crossChainTransactions
                        }
                    },
                    stage9: {
                        name: "Security",
                        health: this.performance.stages.stage9 || 1.0,
                        key_metrics: {
                            score: `${this.metrics.stage9.securityScore}/100`,
                            threat: `${this.metrics.stage9.threatLevel}/10`
                        }
                    }
                },
                alerts: this.alerts,
                trends: this.trends,
                anomalies: this.anomalies
            };

            // Save to file for web dashboard
            const fs = require('fs');
            fs.writeFileSync('./monitoring-dashboard.json', JSON.stringify(dashboardData, null, 2));
            
            console.log("📊 Dashboard updated successfully");
            
        } catch (error) {
            console.error("❌ Failed to update dashboard:", error);
        }
    }

    /**
     * Generate comprehensive health report
     */
    generateHealthReport() {
        return {
            timestamp: Date.now(),
            overall_health: this.performance.overall,
            system_metrics: this.metrics.system,
            stage_health: this.performance.stages,
            active_alerts: this.alerts,
            trends: this.trends,
            anomalies: this.anomalies,
            recommendations: this.generateRecommendations()
        };
    }

    /**
     * Generate system recommendations based on current metrics
     */
    generateRecommendations() {
        const recommendations = [];

        if (this.metrics.network.gasPrice > this.config.alertThresholds.gasPrice) {
            recommendations.push({
                priority: 'HIGH',
                category: 'PERFORMANCE',
                message: 'Consider pausing non-critical operations due to high gas prices'
            });
        }

        if (this.performance.overall < 0.8) {
            recommendations.push({
                priority: 'MEDIUM',
                category: 'SYSTEM',
                message: 'System performance below optimal, investigate bottlenecks'
            });
        }

        return recommendations;
    }

    /**
     * Stop monitoring and cleanup
     */
    stopMonitoring() {
        if (this.monitoringInterval) {
            clearInterval(this.monitoringInterval);
        }
        if (this.networkInterval) {
            clearInterval(this.networkInterval);
        }
        if (this.securityInterval) {
            clearInterval(this.securityInterval);
        }
        
        console.log("🛑 Monitoring stopped");
    }

    // Helper methods for metric calculations
    async calculateCirculatingSupply() {
        // Implementation for calculating circulating supply
        return ethers.parseEther("500000000"); // Placeholder
    }

    async countTokenHolders() {
        // Implementation for counting unique token holders
        return 10000; // Placeholder
    }

    async getTransferCount24h() {
        // Implementation for getting 24h transfer count
        return 1500; // Placeholder
    }

    async getAverageTransferSize() {
        // Implementation for average transfer size
        return ethers.parseEther("1000"); // Placeholder
    }

    calculateOverallHealth() {
        // Calculate overall system health score
        const stageHealths = Object.values(this.performance.stages || {});
        if (stageHealths.length === 0) return 1.0;
        
        return stageHealths.reduce((sum, health) => sum + health, 0) / stageHealths.length;
    }

    // Placeholder implementations for other helper methods
    async sendToSlack(alert) { /* Implementation */ }
    async sendToDiscord(alert) { /* Implementation */ }
    async sendSMSAlert(alert) { /* Implementation */ }
    analyzeTrend(metric) { return 'stable'; }
    detectGasSpike() { return false; }
    detectVolumeSpike() { return false; }
    detectFailureSpike() { return false; }
    detectSecurityDrop() { return false; }
}

module.exports = { KarmaMonitoringDashboard }; 