# Stage 6: Tokenomics and Value Accrual

Build automated token supply management and value mechanisms for the Karma Labs ecosystem.

## Overview

Stage 6 implements sophisticated tokenomics mechanisms that create sustainable value accrual through automated token buybacks, comprehensive revenue stream integration, and advanced DEX routing. The system captures revenue from all platform activities and automatically converts it into deflationary pressure on the KARMA token supply.

## Architecture

### Stage 6.1: BuybackBurn System Development
- **BuybackBurn Contract**: Core automated buyback and burn system
- **DEXRouter**: Multi-DEX integration with optimal routing
- **ChainlinkKeeper**: Automated execution triggers
- **Treasury Integration**: 20% allocation management

### Stage 6.2: Revenue Stream Integration  
- **FeeCollector**: Comprehensive platform fee collection
- **Revenue Routing**: Automated fee distribution
- **Credit System**: Off-chain payment integration
- **Oracle Integration**: Real-time price feeds

## Key Features

### 🔥 Automated Buyback & Burn
- **Monthly Triggers**: Automatic execution every 30 days
- **Threshold-Based**: $50K minimum trigger amount
- **Multi-DEX Support**: Uniswap V3, SushiSwap, Balancer
- **Slippage Protection**: Maximum 5% price impact

### 💰 Revenue Stream Capture
- **iNFT Trading**: 0.5% trading fees
- **Game Purchases**: 3% SillyHotel fees  
- **Premium Subscriptions**: $15 monthly fees
- **Asset Trading**: 2.5% KarmaLabs fees
- **Credit Surcharges**: 10% non-crypto payments

### 🛡️ Security & Controls
- **Large Operation Approval**: Multi-sig for >10% treasury
- **MEV Protection**: Front-running and sandwich prevention
- **Cooling-off Periods**: 24-hour delays for large operations
- **Emergency Pause**: Circuit breaker functionality

### 📊 Advanced Analytics
- **Real-time Metrics**: Buyback efficiency tracking
- **Revenue Attribution**: Source-based breakdown
- **Economic Impact**: Supply reduction analysis
- **Performance Monitoring**: Gas optimization tracking

## Contract Architecture

```
06-tokenomics-value-accrual/
├── contracts/
│   ├── BuybackBurn.sol              # Core buyback system
│   ├── interfaces/
│   │   ├── IBuybackBurn.sol         # Buyback interface
│   │   └── IFeeCollector.sol        # Revenue interface
│   ├── dex/
│   │   └── DEXRouter.sol            # Multi-DEX routing
│   ├── revenue/
│   │   └── FeeCollector.sol         # Revenue integration
│   └── automation/
│       └── ChainlinkKeeper.sol      # Automated triggers
├── test/
│   ├── BuybackBurn.test.js          # Core system tests
│   ├── FeeCollector.test.js         # Revenue tests
│   ├── Stage6.1.test.js             # Stage 6.1 tests
│   └── Stage6.2.test.js             # Stage 6.2 tests
└── scripts/
    ├── deploy-stage6.1.js           # Stage 6.1 deployment
    ├── deploy-stage6.2.js           # Stage 6.2 deployment
    ├── deploy-buyback-burn.js       # Core deployment
    └── setup-automation.js          # Automation setup
```

## Quick Start

### Prerequisites
- Node.js >= 16.0.0
- npm >= 8.0.0
- Hardhat

### Installation
```bash
cd protocol/06-tokenomics-value-accrual
npm install
```

### Compilation
```bash
npm run compile
```

### Testing
```bash
# Run all tests
npm test

# Run specific stage tests
npm run test:stage6.1
npm run test:stage6.2

# Run specific contract tests
npm run test:buyback
npm run test:fee-collector
```

### Deployment

#### Stage 6.1: BuybackBurn System
```bash
npm run deploy:stage6.1
```

#### Stage 6.2: Revenue Integration
```bash
npm run deploy:stage6.2
```

#### Individual Components
```bash
npm run deploy:buyback
npm run deploy:automation
```

## Configuration

### Stage 6.1 Configuration (`config/stage6.1-config.json`)
```json
{
  "buybackBurn": {
    "triggers": {
      "monthlyInterval": 2592000,
      "thresholdAmount": "50000000000000000000",
      "maxSlippage": 500
    },
    "dex": {
      "primaryDEX": "UNISWAP_V3",
      "supportedDEXes": ["UNISWAP_V3", "SUSHISWAP", "BALANCER"],
      "maxPriceImpact": 500
    }
  }
}
```

### Stage 6.2 Configuration (`config/stage6.2-config.json`)
```json
{
  "revenueStreams": {
    "platformFees": {
      "iNFTTrading": {
        "feePercentage": 50,
        "routeDestination": "buyback"
      },
      "premiumSubscriptions": {
        "fixedFee": "15000000000000000",
        "routeDestination": "buyback"
      }
    }
  }
}
```

## Usage Examples

### BuybackBurn Integration
```javascript
const buybackBurn = await ethers.getContractAt("BuybackBurn", address);

// Manual trigger
await buybackBurn.manualTrigger(
  ethers.parseEther("10"), // 10 ETH
  500 // 5% max slippage
);

// Check trigger conditions
const canTrigger = await buybackBurn.canTriggerBuyback();
const nextTrigger = await buybackBurn.getNextScheduledTrigger();
```

### Revenue Collection
```javascript
const feeCollector = await ethers.getContractAt("FeeCollector", address);

// Collect platform fees
await feeCollector.collectPlatformFees({ 
  value: ethers.parseEther("1") 
});

// Process credit purchase
await feeCollector.processCreditPurchase(
  userAddress,
  ethers.parseEther("100"), // Credit amount
  ethers.parseEther("50")   // KARMA value
);
```

### DEX Routing
```javascript
const dexRouter = await ethers.getContractAt("DEXRouter", address);

// Calculate optimal route
const route = await dexRouter.calculateOptimalRoute(
  tokenIn,
  tokenOut,
  ethers.parseEther("1")
);

// Execute swap
await dexRouter.executeOptimalSwap(
  tokenIn,
  tokenOut,
  ethers.parseEther("1"),
  minAmountOut,
  500 // 5% max slippage
);
```

## Economic Model

### Revenue Sources
1. **iNFT Trading**: 0.5% of all trade volume
2. **SillyHotel**: 3% of in-game purchases
3. **SillyPort**: $15/month premium subscriptions
4. **KarmaLabs**: 2.5% of asset trading
5. **Credit System**: 10% surcharge on non-crypto payments

### Fund Allocation
- **75%** → Buyback & Burn
- **25%** → Treasury Operations

### Buyback Mechanics
- **Trigger**: Monthly or $50K threshold
- **DEX Selection**: Optimal routing across protocols
- **Slippage Control**: Maximum 5% price impact
- **Burn Process**: Permanent token supply reduction

## Security Features

### Multi-Signature Controls
- Large operations (>10% treasury) require multi-sig approval
- 3-day timelock for sensitive parameter changes
- Emergency pause functionality

### MEV Protection
- Front-running prevention mechanisms
- Sandwich attack resistance
- Dynamic slippage adjustment

### Economic Safeguards
- Maximum daily buyback limits
- Price impact thresholds
- Market manipulation detection

## Monitoring & Analytics

### Key Metrics
- **Total Buybacks**: Historical execution count
- **ETH Spent**: Cumulative purchase amount  
- **Tokens Burned**: Permanent supply reduction
- **Price Impact**: Market effect measurement
- **Revenue Attribution**: Source breakdown

### Performance Tracking
- Gas optimization analysis
- Execution success rates
- DEX routing efficiency
- Revenue conversion rates

## Integration Points

### Dependencies
- **Stage 1**: KarmaToken contract for burn functionality
- **Stage 4**: Treasury contract for fund allocation
- **External**: DEX protocols for token swaps

### Platform Integration
- **SillyPort**: iNFT trading and premium subscriptions
- **SillyHotel**: In-game purchase fee routing
- **KarmaLabs**: Asset trading fee collection

## Testing Strategy

### Unit Tests
- Individual contract functionality
- Edge case validation
- Security boundary testing

### Integration Tests
- Cross-contract interactions
- End-to-end revenue flows
- Automated trigger verification

### Performance Tests
- Gas optimization validation
- Large operation handling
- High-frequency transaction processing

## Gas Optimization

### Efficiency Features
- Batch transaction processing
- Optimized storage patterns
- Minimal external calls
- Route caching mechanisms

### Cost Targets
- Buyback execution: <1M gas
- Fee collection: <300K gas
- Revenue routing: <200K gas

## Deployment Guide

### Prerequisites
1. Deploy Stage 1 (KarmaToken)
2. Deploy Stage 4 (Treasury)
3. Configure DEX integrations
4. Set up price oracles

### Stage 6.1 Deployment
1. Deploy BuybackBurn contract
2. Configure trigger parameters
3. Set up DEX integrations
4. Enable automation

### Stage 6.2 Deployment
1. Deploy FeeCollector contract
2. Configure revenue streams
3. Set up oracle feeds
4. Test fee routing

### Post-Deployment
1. Verify contract functionality
2. Configure monitoring
3. Set up alerting
4. Enable governance controls

## Maintenance

### Regular Operations
- Monitor execution success rates
- Optimize gas usage
- Update DEX configurations
- Review security parameters

### Upgrades
- Governance-controlled parameter updates
- Multi-sig approved contract upgrades
- Community-reviewed economic changes

## Support

### Documentation
- [Technical Specification](./docs/technical-spec.md)
- [Economic Model](./docs/economic-model.md)
- [Security Audit](./docs/security-audit.md)

### Community
- [Discord](https://discord.gg/karmalabs)
- [Telegram](https://t.me/karmalabs)
- [GitHub Issues](https://github.com/karma-labs/smart-contracts/issues)

## License

MIT License - see [LICENSE](./LICENSE) file for details.

---

**⚠️ Important**: This is a complex DeFi system handling significant value. Always test thoroughly on testnets before mainnet deployment and consider professional security audits. 