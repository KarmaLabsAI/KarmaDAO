const { ethers } = require("ethers");

/**
 * AI Payment Calculator
 * Utilities for calculating AI inference payments and cross-chain costs
 */
class AIPaymentCalculator {
    constructor(config = {}) {
        this.config = {
            // Default pricing in KARMA tokens (18 decimals)
            computeUnitPrice: ethers.parseEther(config.computeUnitPrice || "0.001"),
            storagePrice: ethers.parseEther(config.storagePrice || "0.0001"),
            transferPrice: ethers.parseEther(config.transferPrice || "0.00001"),
            
            // AI model complexity multipliers
            modelComplexity: {
                "gpt-3.5-turbo": 1.0,
                "gpt-4": 3.0,
                "claude-3-haiku": 1.2,
                "claude-3-sonnet": 2.0,
                "claude-3-opus": 4.0,
                "stable-diffusion-v1.5": 1.5,
                "stable-diffusion-xl": 2.5,
                "dall-e-3": 3.5,
                "midjourney-v6": 3.0,
                "leonardo-ai": 2.0,
                ...config.modelComplexity
            },
            
            // Task type multipliers
            taskComplexity: {
                "text-generation": 1.0,
                "image-generation": 2.0,
                "video-generation": 5.0,
                "audio-generation": 1.5,
                "code-generation": 1.8,
                "translation": 0.8,
                "summarization": 0.6,
                "analysis": 1.2,
                ...config.taskComplexity
            },
            
            // Quality/resolution multipliers
            qualityMultipliers: {
                "draft": 0.5,
                "standard": 1.0,
                "high": 1.8,
                "premium": 3.0,
                "ultra": 5.0,
                ...config.qualityMultipliers
            },
            
            // Cross-chain and network fees
            bridgeFee: config.bridgeFee || 100, // basis points (1%)
            networkGasMultiplier: config.networkGasMultiplier || 1.2,
            
            ...config
        };
    }
    
    /**
     * Calculate AI inference cost based on model, task, and parameters
     * @param {Object} request - Inference request parameters
     * @returns {Object} Cost breakdown
     */
    calculateInferenceCost(request) {
        const {
            aiModel,
            taskType = "text-generation",
            quality = "standard",
            inputSize = 0,
            outputSize = 0,
            complexity = 1,
            duration = 0
        } = request;
        
        if (!aiModel) {
            throw new Error("AI model is required for cost calculation");
        }
        
        // Base compute cost
        const modelMultiplier = this.config.modelComplexity[aiModel] || 1.0;
        const taskMultiplier = this.config.taskComplexity[taskType] || 1.0;
        const qualityMultiplier = this.config.qualityMultipliers[quality] || 1.0;
        
        // Calculate compute units needed
        const baseComputeUnits = Math.max(1, Math.ceil(complexity * duration * 0.1));
        const adjustedComputeUnits = Math.ceil(
            baseComputeUnits * modelMultiplier * taskMultiplier * qualityMultiplier
        );
        
        // Calculate costs
        const computeCost = this.config.computeUnitPrice * BigInt(adjustedComputeUnits);
        const storageCost = this.config.storagePrice * BigInt(Math.ceil((inputSize + outputSize) / 1024));
        const transferCost = this.config.transferPrice * BigInt(Math.ceil(outputSize / 1024));
        
        const totalCost = computeCost + storageCost + transferCost;
        
        return {
            computeUnits: adjustedComputeUnits,
            computeCost: computeCost.toString(),
            storageCost: storageCost.toString(),
            transferCost: transferCost.toString(),
            totalCost: totalCost.toString(),
            breakdown: {
                modelMultiplier,
                taskMultiplier,
                qualityMultiplier,
                inputSize,
                outputSize
            }
        };
    }
    
    /**
     * Calculate cross-chain bridge cost
     * @param {string} amount - Amount to bridge (in wei)
     * @param {string} sourceChain - Source chain identifier
     * @param {string} targetChain - Target chain identifier
     * @returns {Object} Bridge cost breakdown
     */
    calculateBridgeCost(amount, sourceChain = "arbitrum", targetChain = "0g") {
        const amountBN = BigInt(amount);
        
        // Bridge fee (percentage of amount)
        const bridgeFee = (amountBN * BigInt(this.config.bridgeFee)) / BigInt(10000);
        
        // Network gas estimation (varies by chain)
        const gasEstimate = this.estimateGasCost(sourceChain, targetChain);
        
        // Validator fees
        const validatorFee = ethers.parseEther("0.001"); // Fixed validator fee
        
        const totalFee = bridgeFee + gasEstimate + validatorFee;
        const netAmount = amountBN - totalFee;
        
        return {
            grossAmount: amount,
            netAmount: netAmount.toString(),
            fees: {
                bridgeFee: bridgeFee.toString(),
                gasFee: gasEstimate.toString(),
                validatorFee: validatorFee.toString(),
                totalFee: totalFee.toString()
            },
            feePercentage: Number(totalFee * BigInt(10000) / amountBN) / 100
        };
    }
    
    /**
     * Estimate gas costs for cross-chain operations
     * @param {string} sourceChain - Source chain
     * @param {string} targetChain - Target chain
     * @returns {bigint} Estimated gas cost in wei
     */
    estimateGasCost(sourceChain, targetChain) {
        const gasEstimates = {
            "arbitrum": ethers.parseEther("0.001"),
            "ethereum": ethers.parseEther("0.01"),
            "polygon": ethers.parseEther("0.0001"),
            "0g": ethers.parseEther("0.0005"),
            "default": ethers.parseEther("0.002")
        };
        
        const sourceGas = gasEstimates[sourceChain] || gasEstimates.default;
        const targetGas = gasEstimates[targetChain] || gasEstimates.default;
        
        // Apply network multiplier
        const totalGas = (sourceGas + targetGas) * BigInt(Math.floor(this.config.networkGasMultiplier * 100)) / BigInt(100);
        
        return totalGas;
    }
    
    /**
     * Calculate storage costs for different data types
     * @param {Object} data - Data storage parameters
     * @returns {Object} Storage cost breakdown
     */
    calculateStorageCost(data) {
        const {
            size,
            type = "general",
            duration = 2592000, // 30 days default
            replication = 3,
            encryption = false
        } = data;
        
        if (!size || size <= 0) {
            throw new Error("Data size is required for storage cost calculation");
        }
        
        // Base storage cost per MB per month
        const baseCostPerMB = this.config.storagePrice;
        const sizeInMB = Math.ceil(size / (1024 * 1024));
        const monthsStored = Math.ceil(duration / 2592000);
        
        // Type multipliers
        const typeMultipliers = {
            "metadata": 0.5,
            "image": 1.0,
            "video": 1.5,
            "audio": 1.2,
            "document": 0.8,
            "general": 1.0
        };
        
        const typeMultiplier = typeMultipliers[type] || 1.0;
        
        // Calculate costs
        const baseCost = baseCostPerMB * BigInt(sizeInMB) * BigInt(monthsStored);
        const replicationCost = baseCost * BigInt(replication - 1) / BigInt(2); // 50% cost for additional replicas
        const encryptionCost = encryption ? baseCost / BigInt(10) : BigInt(0); // 10% encryption overhead
        
        const totalCost = BigInt(Math.floor(Number(baseCost) * typeMultiplier)) + replicationCost + encryptionCost;
        
        return {
            sizeInMB,
            monthsStored,
            baseCost: baseCost.toString(),
            replicationCost: replicationCost.toString(),
            encryptionCost: encryptionCost.toString(),
            totalCost: totalCost.toString(),
            costPerMBPerMonth: baseCostPerMB.toString()
        };
    }
    
    /**
     * Calculate batch operation discount
     * @param {Array} operations - Array of operations
     * @param {number} batchSize - Size of batch
     * @returns {Object} Batch pricing
     */
    calculateBatchDiscount(operations, batchSize) {
        if (!Array.isArray(operations) || operations.length === 0) {
            throw new Error("Operations array is required");
        }
        
        // Calculate individual costs
        const individualCosts = operations.map(op => {
            if (op.type === "inference") {
                return this.calculateInferenceCost(op);
            } else if (op.type === "storage") {
                return this.calculateStorageCost(op);
            } else if (op.type === "bridge") {
                return this.calculateBridgeCost(op.amount, op.sourceChain, op.targetChain);
            }
            return { totalCost: "0" };
        });
        
        const totalIndividualCost = individualCosts.reduce(
            (sum, cost) => sum + BigInt(cost.totalCost || "0"),
            BigInt(0)
        );
        
        // Batch discounts based on size
        const discountTiers = [
            { threshold: 1, discount: 0 },
            { threshold: 5, discount: 5 },    // 5% discount for 5+ operations
            { threshold: 10, discount: 10 },  // 10% discount for 10+ operations
            { threshold: 25, discount: 15 },  // 15% discount for 25+ operations
            { threshold: 50, discount: 20 },  // 20% discount for 50+ operations
            { threshold: 100, discount: 25 }  // 25% discount for 100+ operations
        ];
        
        let discountPercentage = 0;
        for (const tier of discountTiers.reverse()) {
            if (batchSize >= tier.threshold) {
                discountPercentage = tier.discount;
                break;
            }
        }
        
        const discountAmount = (totalIndividualCost * BigInt(discountPercentage)) / BigInt(100);
        const totalBatchCost = totalIndividualCost - discountAmount;
        const savings = totalIndividualCost - totalBatchCost;
        
        return {
            operationCount: operations.length,
            batchSize,
            individualCost: totalIndividualCost.toString(),
            discountPercentage,
            discountAmount: discountAmount.toString(),
            totalBatchCost: totalBatchCost.toString(),
            savings: savings.toString(),
            savingsPercentage: Number(savings * BigInt(10000) / totalIndividualCost) / 100,
            operations: individualCosts
        };
    }
    
    /**
     * Estimate monthly costs for a user based on usage patterns
     * @param {Object} usage - Monthly usage patterns
     * @returns {Object} Monthly cost estimate
     */
    estimateMonthlyCosts(usage) {
        const {
            inferenceRequests = [],
            storageGB = 0,
            bridgeTransactions = [],
            subscription = "basic"
        } = usage;
        
        // Calculate inference costs
        const inferenceCosts = inferenceRequests.map(req => this.calculateInferenceCost(req));
        const totalInferenceCost = inferenceCosts.reduce(
            (sum, cost) => sum + BigInt(cost.totalCost),
            BigInt(0)
        );
        
        // Calculate storage costs
        const storageSize = storageGB * 1024 * 1024 * 1024; // Convert GB to bytes
        const storageCost = this.calculateStorageCost({
            size: storageSize,
            duration: 2592000 // 30 days
        });
        
        // Calculate bridge costs
        const bridgeCosts = bridgeTransactions.map(tx => 
            this.calculateBridgeCost(tx.amount, tx.sourceChain, tx.targetChain)
        );
        const totalBridgeCost = bridgeCosts.reduce(
            (sum, cost) => sum + BigInt(cost.fees.totalFee),
            BigInt(0)
        );
        
        // Subscription discounts
        const subscriptionDiscounts = {
            "free": 0,
            "basic": 5,
            "premium": 15,
            "enterprise": 25
        };
        
        const discountPercentage = subscriptionDiscounts[subscription] || 0;
        const totalCost = totalInferenceCost + BigInt(storageCost.totalCost) + totalBridgeCost;
        const discountAmount = (totalCost * BigInt(discountPercentage)) / BigInt(100);
        const finalCost = totalCost - discountAmount;
        
        return {
            breakdown: {
                inference: totalInferenceCost.toString(),
                storage: storageCost.totalCost,
                bridge: totalBridgeCost.toString(),
                subtotal: totalCost.toString()
            },
            subscription: {
                tier: subscription,
                discountPercentage,
                discountAmount: discountAmount.toString()
            },
            total: finalCost.toString(),
            costInUSD: this.convertToUSD(finalCost),
            recommendations: this.generateCostOptimizationRecommendations(usage, finalCost)
        };
    }
    
    /**
     * Convert KARMA cost to USD (mock implementation)
     * @param {bigint} karmaCost - Cost in KARMA wei
     * @returns {string} USD cost estimate
     */
    convertToUSD(karmaCost) {
        // Mock KARMA price - in production this would use a price oracle
        const karmaToUSD = 0.05; // $0.05 per KARMA token
        const karmaAmount = Number(ethers.formatEther(karmaCost));
        const usdAmount = karmaAmount * karmaToUSD;
        return usdAmount.toFixed(2);
    }
    
    /**
     * Generate cost optimization recommendations
     * @param {Object} usage - Usage patterns
     * @param {bigint} currentCost - Current monthly cost
     * @returns {Array} Optimization recommendations
     */
    generateCostOptimizationRecommendations(usage, currentCost) {
        const recommendations = [];
        
        // Batch operation recommendations
        if (usage.inferenceRequests && usage.inferenceRequests.length > 5) {
            recommendations.push({
                type: "batch_operations",
                description: "Consider batching your AI inference requests to save up to 25%",
                potentialSavings: "10-25%"
            });
        }
        
        // Storage optimization
        if (usage.storageGB > 10) {
            recommendations.push({
                type: "storage_optimization",
                description: "Archive old data or use compression to reduce storage costs",
                potentialSavings: "20-40%"
            });
        }
        
        // Subscription upgrade
        const currentCostUSD = this.convertToUSD(currentCost);
        if (parseFloat(currentCostUSD) > 50) {
            recommendations.push({
                type: "subscription_upgrade",
                description: "Upgrade to Enterprise tier for better bulk discounts",
                potentialSavings: "15-30%"
            });
        }
        
        // Model optimization
        const highCostModels = usage.inferenceRequests?.filter(req => 
            this.config.modelComplexity[req.aiModel] > 3.0
        );
        if (highCostModels && highCostModels.length > 0) {
            recommendations.push({
                type: "model_optimization",
                description: "Consider using more cost-effective AI models for non-critical tasks",
                potentialSavings: "30-60%"
            });
        }
        
        return recommendations;
    }
    
    /**
     * Update pricing configuration
     * @param {Object} newConfig - New pricing configuration
     */
    updatePricing(newConfig) {
        this.config = {
            ...this.config,
            ...newConfig
        };
    }
}

module.exports = { AIPaymentCalculator }; 