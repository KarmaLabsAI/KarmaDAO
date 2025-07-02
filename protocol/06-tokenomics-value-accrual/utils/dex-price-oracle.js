/**
 * @title DEX Price Oracle Utilities
 * @dev Utilities for DEX price aggregation and oracle functionality
 */

const { ethers } = require("ethers");

/**
 * Price oracle configuration for different DEX protocols
 */
const DEX_CONFIGS = {
    UNISWAP_V3: {
        name: "Uniswap V3",
        router: "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Mainnet
        quoter: "0xb27308f9F90D607463bb33eA1BaBb0E731D86B9E0", // Mainnet V2 quoter
        fee: 3000, // 0.3%
        gasEstimate: 150000
    },
    SUSHISWAP: {
        name: "SushiSwap",
        router: "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F", // Mainnet
        quoter: null, // Uses router for quotes
        fee: 3000, // 0.3%
        gasEstimate: 120000
    },
    BALANCER: {
        name: "Balancer",
        router: "0xBA12222222228d8Ba445958a75a0704d566BF2C8", // Vault address
        quoter: null,
        fee: 0, // Variable fees
        gasEstimate: 180000
    }
};

/**
 * Token configurations for price fetching
 */
const TOKEN_CONFIGS = {
    ETH: {
        address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
        decimals: 18,
        symbol: "ETH"
    },
    KARMA: {
        address: "0x0000000000000000000000000000000000000000", // To be set
        decimals: 18,
        symbol: "KARMA"
    },
    USDC: {
        address: "0xA0b86a33E6A6ca903da8D1eBf6e1C6Bc9b6Bcb47", // Arbitrum USDC
        decimals: 6,
        symbol: "USDC"
    }
};

/**
 * Calculate token amounts based on USD values
 */
function calculateTokenAmounts(usdAmount, ethPriceUSD, karmaPriceUSD) {
    const ethAmount = parseFloat(usdAmount) / parseFloat(ethPriceUSD);
    const karmaAmount = parseFloat(usdAmount) / parseFloat(karmaPriceUSD);
    
    return {
        eth: ethers.parseEther(ethAmount.toString()),
        karma: ethers.parseEther(karmaAmount.toString()),
        usd: ethers.parseUnits(usdAmount.toString(), 6)
    };
}

/**
 * Estimate gas costs for different operations
 */
function estimateGasCosts(operationType, amount, gasPrice) {
    const gasEstimates = {
        swap: 150000,
        buy: 120000,
        burn: 80000,
        transfer: 21000,
        approve: 46000
    };
    
    const gasLimit = gasEstimates[operationType] || 150000;
    return {
        gasLimit,
        gasCost: gasLimit * gasPrice,
        gasCostETH: ethers.formatEther((gasLimit * gasPrice).toString())
    };
}

/**
 * Calculate price impact for a given trade
 */
function calculatePriceImpact(amountIn, reserveIn, reserveOut) {
    // Simplified AMM price impact calculation
    const amountInBN = ethers.toBigInt(amountIn);
    const reserveInBN = ethers.toBigInt(reserveIn);
    const reserveOutBN = ethers.toBigInt(reserveOut);
    
    // Price before trade
    const priceBefore = (reserveOutBN * BigInt(1e18)) / reserveInBN;
    
    // Amount out using constant product formula (with 0.3% fee)
    const amountInWithFee = amountInBN * BigInt(997);
    const numerator = amountInWithFee * reserveOutBN;
    const denominator = (reserveInBN * BigInt(1000)) + amountInWithFee;
    const amountOut = numerator / denominator;
    
    // Price after trade
    const newReserveIn = reserveInBN + amountInBN;
    const newReserveOut = reserveOutBN - amountOut;
    const priceAfter = (newReserveOut * BigInt(1e18)) / newReserveIn;
    
    // Price impact percentage (in basis points)
    const priceImpact = ((priceBefore - priceAfter) * BigInt(10000)) / priceBefore;
    
    return {
        priceImpact: Number(priceImpact),
        amountOut: amountOut.toString(),
        newPrice: ethers.formatEther(priceAfter)
    };
}

/**
 * Format price data for display
 */
function formatPriceData(priceData) {
    return {
        ethPriceFormatted: `$${parseFloat(ethers.formatUnits(priceData.ethPrice, 8)).toFixed(2)}`,
        karmaPriceFormatted: `$${parseFloat(ethers.formatUnits(priceData.karmaPrice, 8)).toFixed(6)}`,
        timestamp: new Date(priceData.timestamp * 1000).toISOString(),
        age: Math.floor(Date.now() / 1000) - priceData.timestamp
    };
}

/**
 * Validate price data freshness
 */
function validatePriceFreshness(timestamp, maxAge = 3600) {
    const currentTime = Math.floor(Date.now() / 1000);
    const age = currentTime - timestamp;
    
    return {
        isValid: age <= maxAge,
        age,
        maxAge,
        warningThreshold: maxAge * 0.8
    };
}

/**
 * Calculate optimal slippage based on market conditions
 */
function calculateOptimalSlippage(amount, priceImpact, volatility = 0.02) {
    // Base slippage: 0.5%
    let slippage = 50; // basis points
    
    // Adjust for price impact
    if (priceImpact > 200) { // 2%
        slippage += Math.min(priceImpact / 2, 200); // Cap additional slippage at 2%
    }
    
    // Adjust for market volatility
    slippage += volatility * 10000; // Convert to basis points
    
    // Cap maximum slippage at 5%
    return Math.min(slippage, 500);
}

/**
 * DEX price comparison utilities
 */
const DEXPriceComparator = {
    /**
     * Compare prices across multiple DEXes
     */
    async comparePrices(tokenIn, tokenOut, amountIn, provider) {
        const prices = [];
        
        for (const [dexName, config] of Object.entries(DEX_CONFIGS)) {
            try {
                const quote = await this.getQuote(tokenIn, tokenOut, amountIn, config, provider);
                prices.push({
                    dex: dexName,
                    amountOut: quote.amountOut,
                    priceImpact: quote.priceImpact,
                    gasEstimate: config.gasEstimate,
                    effectivePrice: this.calculateEffectivePrice(amountIn, quote.amountOut)
                });
            } catch (error) {
                console.warn(`Failed to get quote from ${dexName}:`, error.message);
            }
        }
        
        return prices.sort((a, b) => ethers.toBigInt(b.amountOut) - ethers.toBigInt(a.amountOut));
    },

    /**
     * Get quote from specific DEX
     */
    async getQuote(tokenIn, tokenOut, amountIn, dexConfig, provider) {
        // This is a simplified implementation
        // In production, integrate with actual DEX quoter contracts
        
        const mockAmountOut = ethers.toBigInt(amountIn) * BigInt(95) / BigInt(100); // 5% slippage
        const mockPriceImpact = this.calculateMockPriceImpact(amountIn);
        
        return {
            amountOut: mockAmountOut.toString(),
            priceImpact: mockPriceImpact,
            gasEstimate: dexConfig.gasEstimate
        };
    },

    /**
     * Calculate effective price including fees and gas
     */
    calculateEffectivePrice(amountIn, amountOut) {
        const amountInBN = ethers.toBigInt(amountIn);
        const amountOutBN = ethers.toBigInt(amountOut);
        
        if (amountOutBN === BigInt(0)) return "0";
        
        return (amountInBN * BigInt(1e18) / amountOutBN).toString();
    },

    /**
     * Mock price impact calculation
     */
    calculateMockPriceImpact(amountIn) {
        const amount = ethers.toBigInt(amountIn);
        
        if (amount > ethers.parseEther("100")) return 500; // 5%
        if (amount > ethers.parseEther("10")) return 200;  // 2%
        if (amount > ethers.parseEther("1")) return 50;    // 0.5%
        return 10; // 0.1%
    }
};

/**
 * Revenue calculation utilities
 */
const RevenueCalculator = {
    /**
     * Calculate expected revenue from buyback
     */
    calculateBuybackRevenue(ethAmount, karmaPrice, burnAmount) {
        const ethAmountBN = ethers.toBigInt(ethAmount);
        const karmaPriceBN = ethers.toBigInt(karmaPrice);
        const burnAmountBN = ethers.toBigInt(burnAmount);
        
        // Revenue = ETH spent * market impact + tokens burned * price
        const marketImpactRevenue = ethAmountBN * BigInt(2) / BigInt(100); // 2% market impact
        const burnRevenue = burnAmountBN * karmaPriceBN / BigInt(1e18);
        
        return {
            marketImpact: marketImpactRevenue.toString(),
            burnValue: burnRevenue.toString(),
            totalRevenue: (marketImpactRevenue + burnRevenue).toString()
        };
    },

    /**
     * Calculate fee allocation breakdown
     */
    calculateFeeAllocation(totalFees, allocations) {
        const totalFeesBN = ethers.toBigInt(totalFees);
        const breakdown = {};
        
        for (const [category, percentage] of Object.entries(allocations)) {
            breakdown[category] = (totalFeesBN * BigInt(percentage) / BigInt(10000)).toString();
        }
        
        return breakdown;
    },

    /**
     * Calculate ROI metrics
     */
    calculateROI(investment, returns, timeframe) {
        const investmentBN = ethers.toBigInt(investment);
        const returnsBN = ethers.toBigInt(returns);
        
        if (investmentBN === BigInt(0)) return "0";
        
        const roi = ((returnsBN - investmentBN) * BigInt(10000)) / investmentBN;
        const annualizedROI = roi * BigInt(365) / BigInt(timeframe); // timeframe in days
        
        return {
            totalROI: roi.toString(),
            annualizedROI: annualizedROI.toString(),
            profitLoss: (returnsBN - investmentBN).toString()
        };
    }
};

module.exports = {
    DEX_CONFIGS,
    TOKEN_CONFIGS,
    calculateTokenAmounts,
    estimateGasCosts,
    calculatePriceImpact,
    formatPriceData,
    validatePriceFreshness,
    calculateOptimalSlippage,
    DEXPriceComparator,
    RevenueCalculator
}; 