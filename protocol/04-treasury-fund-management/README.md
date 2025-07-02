# Stage 4: Treasury and Fund Management System

## Overview

The Treasury and Fund Management System is the financial backbone of the Karma Labs ecosystem, providing sophisticated fund management with automated allocation, secure multi-signature controls, and comprehensive token distribution capabilities.

## Features

### 🏛️ Core Treasury Infrastructure (Stage 4.1)
- **Multi-signature Treasury**: 3-of-5 multisig control with role-based access
- **Automated Allocation**: 30% Marketing, 20% KOL, 30% Development, 20% Buyback
- **Withdrawal Management**: Timelock for large withdrawals (>10% treasury, 7-day delay)
- **Security Controls**: Pausable, reentrancy protection, emergency mechanisms

### 🚀 Advanced Treasury Features (Stage 4.2)
- **Token Distribution**: Community rewards, airdrops, staking incentives
- **External Integration**: Paymaster funding, BuybackBurn support
- **Transparency**: Monthly reports, public tracking, governance funding
- **Advanced Operations**: Multi-currency support, yield strategies, emergency recovery

## Architecture

```
Treasury System
├── Treasury.sol (Core contract)
├── ITreasury.sol (Interface)
├── AllocationManager (Built-in)
├── WithdrawalManager (Built-in)
└── External Integrations
    ├── Paymaster funding
    ├── BuybackBurn allocation
    └── Governance proposals
```

## Deployment Structure

```
protocol/04-treasury-fund-management/
├── contracts/
│   ├── Treasury.sol
│   └── interfaces/
│       └── ITreasury.sol
├── test/
│   ├── Treasury.test.js
│   ├── Stage4.1.test.js
│   └── Stage4.2.test.js
├── scripts/
│   ├── deploy-treasury.js
│   ├── deploy-stage4.1.js
│   └── deploy-stage4.2.js
├── config/
│   ├── stage4.1-config.json
│   └── stage4.2-config.json
└── utils/
    └── treasury-calculator.js
```

## Quick Start

### Prerequisites
- Node.js >= 18.0.0
- Hardhat development environment
- Access to Arbitrum network (mainnet or testnet)

### Installation

```bash
cd protocol/04-treasury-fund-management
npm install
```

### Configuration

Update configuration files in `config/` directory:
- `stage4.1-config.json` - Core treasury settings
- `stage4.2-config.json` - Advanced features configuration

### Environment Variables

Create `.env` file in project root:
```env
PRIVATE_KEY=your_private_key_here
ARBISCAN_API_KEY=your_arbiscan_api_key
ALCHEMY_API_KEY=your_alchemy_api_key
```

### Deployment

#### Stage 4.1: Core Infrastructure
```bash
npm run deploy:stage4.1
```

#### Stage 4.2: Advanced Features
```bash
npm run deploy:stage4.2
```

#### Full Treasury System
```bash
npm run deploy
```

### Testing

```bash
# Run all tests
npm test

# Run specific stage tests
npm run test:stage4.1
npm run test:stage4.2

# Run treasury tests
npm run test:treasury

# Generate coverage report
npm run coverage
```

## Contract Details

### Treasury.sol

**Core Functions:**
- `requestWithdrawal(category, amount, recipient, description)` - Request fund withdrawal
- `calculateAllocations(balance)` - Calculate category allocations
- `updateAllocationPercentages(percentages)` - Update allocation split
- `fundPaymaster(amount)` - Fund gasless transaction system
- `fundBuybackBurn(amount)` - Allocate funds for token buyback

**Access Control:**
- `DEFAULT_ADMIN_ROLE` - Full treasury control
- `ALLOCATION_MANAGER_ROLE` - Manage fund allocations
- `WITHDRAWAL_MANAGER_ROLE` - Process withdrawals
- `MULTISIG_MANAGER_ROLE` - Multi-signature operations

**Security Features:**
- Multi-signature requirements for large operations
- Timelock mechanism for significant withdrawals
- Pausable for emergency situations  
- Reentrancy protection on all fund transfers
- Comprehensive event logging for transparency

### ITreasury.sol

**Interface defining:**
- Fund management operations
- Allocation and withdrawal functions
- Integration with external contracts
- Reporting and transparency methods

## Fund Allocation Strategy

| Category | Percentage | Purpose |
|----------|------------|---------|
| Marketing | 30% | Brand promotion, user acquisition campaigns |
| KOL | 20% | Key Opinion Leader partnerships and collaborations |
| Development | 30% | Platform development, maintenance, and improvements |
| Buyback | 20% | Token buyback and burn for value accrual |

## Token Distribution (200M KARMA)

| Type | Allocation | Percentage | Duration |
|------|-----------|------------|----------|
| Airdrop | 20M KARMA | 10% | One-time distribution |
| Staking Rewards | 100M KARMA | 50% | 2 years |
| Engagement Incentives | 80M KARMA | 40% | 2 years |

## Integration Points

### Stage Dependencies
- **Stage 1**: Core Token Infrastructure (KarmaToken)
- **Stage 3**: Token Sales Engine (fund collection)

### External Contract Integration
- **Paymaster**: $100K ETH initial funding for gasless transactions
- **BuybackBurn**: 20% treasury allocation for token value accrual
- **Governance**: Community proposal funding mechanism

## Security Considerations

### Multi-Signature Controls
- 3-of-5 multisig requirement for treasury operations
- Role-based access control for different operations
- Time-delayed execution for large withdrawals

### Emergency Mechanisms
- Pausable contract for emergency situations
- Emergency withdrawal capabilities with proper safeguards
- Fund recovery mechanisms with community oversight

### Audit Requirements
- Comprehensive test coverage (>95%)
- Multiple security audits before mainnet deployment
- Bug bounty program for ongoing security assessment

## API Endpoints

### Public Treasury Data
- `GET /api/treasury/balance` - Current treasury balance
- `GET /api/treasury/allocations` - Category allocations
- `GET /api/treasury/reports` - Monthly treasury reports
- `GET /api/treasury/transactions` - Transaction history

## Monitoring & Alerts

### Balance Monitoring
- Low balance alerts (<1000 ETH)
- Critical balance alerts (<500 ETH)
- Category overdraft warnings (>90% spent)

### Transaction Monitoring
- Large withdrawal notifications (>10% treasury)
- High-frequency transaction alerts
- Unusual spending pattern detection

## Gas Optimization

The Treasury system is optimized for gas efficiency:
- Batch operations for multiple transactions
- Efficient storage patterns for large data sets
- Optimized allocation calculations
- Minimal external calls in critical paths

## Testing Strategy

### Unit Tests
- Individual function testing with full coverage
- Edge case validation and boundary testing
- Access control and permission verification
- Gas cost validation and optimization testing

### Integration Tests
- Cross-contract interaction workflows
- Multi-step treasury operations
- External contract integration validation
- Economic mechanism testing

### Security Tests
- Reentrancy attack prevention
- Access control bypass attempts
- Economic attack simulations
- Emergency scenario testing

## Upgrade Path

The Treasury system supports controlled upgrades through:
- Governance-controlled upgrade mechanisms
- Proxy pattern implementation for contract upgrades
- Parameter adjustment through community voting
- Emergency upgrade capabilities with timelock

## Support & Documentation

- **Technical Documentation**: [docs/treasury-technical.md](docs/treasury-technical.md)
- **User Guide**: [docs/treasury-user-guide.md](docs/treasury-user-guide.md)
- **Integration Guide**: [docs/treasury-integration.md](docs/treasury-integration.md)
- **Security Guide**: [docs/treasury-security.md](docs/treasury-security.md)

## Contributing

Please read our [Contributing Guidelines](../../CONTRIBUTING.md) before submitting changes.

## License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.

---

**⚠️ Important**: This system manages significant financial assets. Always perform thorough testing on testnets before mainnet deployment and ensure proper security audits are completed. 