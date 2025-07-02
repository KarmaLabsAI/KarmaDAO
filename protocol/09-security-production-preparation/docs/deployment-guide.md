# Karma Labs Production Deployment Guide

## Overview

This guide provides comprehensive procedures for deploying the Karma Labs smart contract ecosystem to production (Arbitrum mainnet). It ensures secure, verified, and properly configured deployment of all nine protocol stages.

**Target Network:** Arbitrum One (Chain ID: 42161)  
**Deployment Method:** Staged deployment with validation  
**Security Level:** Production-grade with multi-signature controls  
**Estimated Total Cost:** ~$671 USD (at 30 gwei)  

## Pre-Deployment Checklist

### ✅ Security Requirements
- [ ] Security audit completed and all findings resolved
- [ ] Code freeze implemented (no changes post-audit)
- [ ] Multi-signature wallets configured and tested
- [ ] Hardware security modules (HSM) prepared
- [ ] Emergency response team on standby
- [ ] Insurance coverage activated ($675K via Nexus Mutual)

### ✅ Technical Requirements  
- [ ] All contracts compiled with Solidity 0.8.19
- [ ] 100% test coverage achieved
- [ ] Gas optimization completed
- [ ] Contract size limits verified (<24KB)
- [ ] Dependencies updated and audited
- [ ] Deployment scripts tested on testnet

### ✅ Operational Requirements
- [ ] Deployment team briefing completed
- [ ] Communication plan prepared
- [ ] Monitoring systems configured
- [ ] Rollback procedures defined
- [ ] Documentation updated
- [ ] Community notification prepared

### ✅ Regulatory Requirements
- [ ] Legal review completed
- [ ] Compliance verification finished
- [ ] Terms of service updated
- [ ] Privacy policy reviewed
- [ ] Jurisdiction analysis completed
- [ ] Regulatory filings prepared

## Deployment Architecture

```
Deployment Stages (Sequential)
│
├── Stage 1: Core Token Infrastructure
│   ├── KarmaToken.sol
│   ├── KarmaMultiSigManager.sol  
│   ├── KarmaTimelock.sol
│   └── AdminControl.sol
│
├── Stage 2: Vesting System Architecture
│   ├── VestingVault.sol
│   ├── TeamVesting.sol
│   └── PrivateSaleVesting.sol
│
├── Stage 3: Token Sales Engine
│   ├── SaleManager.sol
│   └── ISaleManager.sol
│
├── Stage 4: Treasury Fund Management
│   ├── Treasury.sol
│   └── ITreasury.sol
│
├── Stage 5: User Experience Enhancement
│   ├── Paymaster.sol
│   └── IPaymaster.sol
│
├── Stage 6: Tokenomics Value Accrual
│   ├── BuybackBurn.sol
│   └── FeeCollector.sol
│
├── Stage 7: Decentralized Governance
│   ├── KarmaDAO.sol
│   ├── QuadraticVoting.sol
│   └── ProposalManager.sol
│
├── Stage 8: External Ecosystem Integration
│   ├── ZeroGIntegration.sol
│   ├── CrossChainBridge.sol
│   └── Platform Integrations
│
└── Stage 9: Security & Production
    ├── KarmaBugBountyManager.sol
    ├── KarmaInsuranceManager.sol
    └── KarmaSecurityMonitoring.sol
```

## Deployment Environment Setup

### Network Configuration

```javascript
// hardhat.config.js - Production Settings
module.exports = {
  networks: {
    arbitrumOne: {
      url: process.env.ARBITRUM_RPC_URL,
      chainId: 42161,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      gasPrice: "auto",
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY,
          apiUrl: "https://api.arbiscan.io"
        }
      }
    }
  },
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  }
};
```

### Environment Variables

```bash
# .env.production
DEPLOYER_PRIVATE_KEY=0x...  # Hardware wallet derived key
ARBITRUM_RPC_URL=https://arbitrum-mainnet.infura.io/v3/YOUR_KEY
ARBISCAN_API_KEY=YOUR_ARBISCAN_API_KEY
GNOSIS_SAFE_ADDRESS=0x...  # Multi-sig wallet address
INSURANCE_FUND_ADDRESS=0x...  # Insurance fund wallet
BUG_BOUNTY_FUND_ADDRESS=0x...  # Bug bounty fund wallet

# Security Settings
ENABLE_VERIFICATION=true
ENABLE_MONITORING=true
EMERGENCY_PAUSE_AUTHORITY=0x...
```

## Stage-by-Stage Deployment

### Stage 1: Core Token Infrastructure

#### Pre-Deployment Verification
```bash
# Verify compilation
npm run compile

# Run security checks  
npm run lint:security
npm run test:security

# Verify contract sizes
npm run size-check
```

#### Deployment Commands
```bash
# Deploy Stage 1 contracts
npx hardhat run scripts/deploy-stage1.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage1.2.js --network arbitrumOne

# Verify contracts on Arbiscan
npx hardhat run scripts/verify-stage1.js --network arbitrumOne

# Configure initial parameters
npx hardhat run scripts/setup-stage1.1.js --network arbitrumOne
npx hardhat run scripts/setup-stage1.2.js --network arbitrumOne

# Validate deployment
npx hardhat run scripts/validate-stage1.1.js --network arbitrumOne
npx hardhat run scripts/validate-stage1.2.js --network arbitrumOne
```

#### Post-Deployment Checks
- [ ] Contract addresses recorded
- [ ] Etherscan verification completed
- [ ] Initial configuration verified
- [ ] Multi-sig ownership transferred
- [ ] Emergency pause functionality tested

### Stage 2: Vesting System Architecture

#### Dependencies
- Requires Stage 1 KarmaToken address
- Requires multi-sig manager configuration

#### Deployment Commands
```bash
# Deploy vesting contracts
npx hardhat run scripts/deploy-stage2.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage2.2.js --network arbitrumOne

# Setup vesting schedules
npx hardhat run scripts/setup-stage2.1.js --network arbitrumOne
npx hardhat run scripts/setup-stage2.2.js --network arbitrumOne

# Validate vesting parameters
npx hardhat run scripts/validate-stage2.1.js --network arbitrumOne
npx hardhat run scripts/validate-stage2.2.js --network arbitrumOne
```

#### Critical Validations
- [ ] Team vesting: 4-year schedule with 12-month cliff
- [ ] Private sale vesting: 6-month linear schedule
- [ ] Beneficiary addresses correctly configured
- [ ] Vesting amounts match tokenomics plan
- [ ] Emergency revocation capabilities tested

### Stage 3: Token Sales Engine

#### Dependencies
- Requires Stage 1 KarmaToken and AdminControl
- Requires Stage 2 VestingVault for private sale integration

#### Pre-Sale Preparation
```bash
# Generate merkle trees for whitelists
npx hardhat run scripts/generate-merkle-trees.js

# Prepare sale configurations
npx hardhat run scripts/prepare-sale-configs.js

# Deploy sale contracts
npx hardhat run scripts/deploy-stage3.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage3.2.js --network arbitrumOne
```

#### Sale Configuration
- **Private Sale:** $0.02/token, 100M KARMA, $25K-$200K limits
- **Pre-Sale:** $0.04/token, 100M KARMA, $1K-$10K limits  
- **Public Sale:** $0.05/token, 150M KARMA, $5K limit

### Stage 4: Treasury Fund Management

#### Dependencies
- Requires Stage 3 SaleManager for fund collection
- Requires multi-sig configuration for treasury controls

#### Deployment Commands
```bash
# Deploy treasury system
npx hardhat run scripts/deploy-stage4.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage4.2.js --network arbitrumOne

# Configure fund allocation rules
npx hardhat run scripts/setup-treasury-allocations.js --network arbitrumOne
```

#### Allocation Configuration
- 30% Marketing and Growth
- 20% KOL and Partnerships  
- 30% Development and Operations
- 20% Buyback and Burn

### Stage 5: User Experience Enhancement

#### Dependencies
- Requires Stage 4 Treasury for Paymaster funding ($100K ETH)

#### Deployment Commands
```bash
# Deploy Paymaster system
npx hardhat run scripts/deploy-stage5.1.js --network arbitrumOne

# Configure gas sponsorship rules
npx hardhat run scripts/setup-paymaster-rules.js --network arbitrumOne

# Fund Paymaster contract
npx hardhat run scripts/fund-paymaster.js --network arbitrumOne
```

### Stage 6: Tokenomics and Value Accrual

#### Dependencies
- Requires Stage 1 KarmaToken
- Requires DEX liquidity for buyback operations

#### Deployment Commands
```bash
# Deploy tokenomics contracts
npx hardhat run scripts/deploy-stage6.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage6.2.js --network arbitrumOne

# Setup DEX integrations
npx hardhat run scripts/setup-dex-routing.js --network arbitrumOne

# Configure automation triggers
npx hardhat run scripts/setup-automation.js --network arbitrumOne
```

#### Critical Configurations
- Buyback triggers: Monthly + $50K threshold
- Slippage protection: 5% maximum
- DEX routing: Uniswap V3 primary, SushiSwap backup

### Stage 7: Decentralized Governance

#### Dependencies
- Requires all previous stages for governance scope
- Requires community token distribution

#### Deployment Commands
```bash
# Deploy governance system
npx hardhat run scripts/deploy-stage7.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage7.2.js --network arbitrumOne

# Initialize governance parameters
npx hardhat run scripts/setup-governance.js --network arbitrumOne

# Transfer admin controls to governance
npx hardhat run scripts/transfer-to-governance.js --network arbitrumOne
```

#### Governance Parameters
- Proposal threshold: 0.1% (1M KARMA)
- Voting period: 7 days
- Execution delay: 3 days
- Quadratic voting enabled

### Stage 8: External Ecosystem Integration

#### Dependencies
- Requires 0G network connectivity
- Requires validator setup for cross-chain bridge

#### Deployment Commands
```bash
# Deploy 0G integration
npx hardhat run scripts/deploy-stage8.1.js --network arbitrumOne

# Deploy platform integrations  
npx hardhat run scripts/deploy-stage8.2.js --network arbitrumOne

# Setup cross-chain bridge
npx hardhat run scripts/setup-bridge-validators.js --network arbitrumOne
```

### Stage 9: Security and Production

#### Dependencies
- Requires all previous stages for comprehensive monitoring
- Requires insurance fund setup

#### Final Deployment Commands
```bash
# Deploy security infrastructure
npx hardhat run scripts/deploy-stage9.1.js --network arbitrumOne
npx hardhat run scripts/deploy-stage9.2.js --network arbitrumOne

# Initialize monitoring systems
npx hardhat run scripts/setup-monitoring.js --network arbitrumOne

# Activate security measures
npx hardhat run scripts/activate-security.js --network arbitrumOne
```

## Post-Deployment Procedures

### System Initialization

#### Token Distribution
```bash
# Execute planned token distribution
npx hardhat run scripts/execute-token-distribution.js --network arbitrumOne

# Distribution breakdown:
# - Team: 200M (vested)
# - Private Sale: 100M (vested)  
# - Public Sale: 150M (immediate)
# - Treasury/Community: 200M
# - Staking Rewards: 100M
# - Engagement Incentives: 80M
# - Early Testers: 20M
# - Liquidity: 50M
# - Reserve: 100M
```

#### Liquidity Setup
```bash
# Create initial Uniswap V3 pool
npx hardhat run scripts/create-liquidity-pool.js --network arbitrumOne

# Add initial liquidity (50M KARMA + ETH equivalent)
npx hardhat run scripts/add-initial-liquidity.js --network arbitrumOne
```

#### Governance Activation
```bash
# Transfer ownership to governance
npx hardhat run scripts/transfer-ownership.js --network arbitrumOne

# Create initial governance proposals
npx hardhat run scripts/create-initial-proposals.js --network arbitrumOne
```

### Monitoring Activation

#### Real-Time Monitoring Setup
```bash
# Configure Forta monitoring
npx hardhat run scripts/setup-forta-monitoring.js

# Setup OpenZeppelin Defender
npx hardhat run scripts/setup-oz-defender.js

# Initialize custom monitoring
npx hardhat run scripts/init-custom-monitoring.js
```

#### Alert Configuration
- Critical: Immediate Slack/Discord + SMS
- High: Slack/Discord within 5 minutes
- Medium: Daily digest email
- Low: Weekly summary report

### Security Activation

#### Bug Bounty Program Launch
```bash
# Deploy bug bounty contracts
npx hardhat run scripts/deploy-bug-bounty.js --network arbitrumOne

# Fund bounty program ($500K USDC)
npx hardhat run scripts/fund-bug-bounty.js --network arbitrumOne

# Publish on Immunefi
npm run publish-immunefi-program
```

#### Insurance Coverage
```bash
# Activate Nexus Mutual coverage
npx hardhat run scripts/activate-insurance.js --network arbitrumOne

# Fund insurance reserve ($675K)
npx hardhat run scripts/fund-insurance.js --network arbitrumOne
```

## Verification and Testing

### Contract Verification

#### Etherscan Verification
```bash
# Verify all contracts on Arbiscan
npx hardhat verify --network arbitrumOne KARMA_TOKEN_ADDRESS "Karma Token" "KARMA" 1000000000000000000000000000

# Verify with constructor arguments
npx hardhat verify --network arbitrumOne VESTING_VAULT_ADDRESS --constructor-args arguments.js
```

#### Source Code Publication
- [ ] All contract source code published on GitHub
- [ ] Commit hash recorded for each deployed contract
- [ ] Build reproducibility verified
- [ ] ABI files published to NPM registry

### Integration Testing

#### End-to-End Testing
```bash
# Run complete integration test suite
npm run test:integration:mainnet

# Test user journeys
npm run test:user-journeys

# Test emergency procedures
npm run test:emergency-procedures
```

#### Performance Testing
```bash
# Gas usage analysis
npm run analyze:gas-usage

# Load testing
npm run test:load

# Stress testing
npm run test:stress
```

## Security Measures

### Multi-Signature Configuration

#### Primary Multi-Sig (5-of-7)
- **Purpose:** Protocol administration and emergency controls
- **Signers:** 7 core team members across 4 time zones
- **Hardware:** Ledger Nano X with custom firmware
- **Backup:** Seed phrases in geographic distribution

#### Treasury Multi-Sig (3-of-5)
- **Purpose:** Fund management and allocation
- **Signers:** CFO, CTO, CEO, 2 board members
- **Hardware:** Hardware security modules (HSM)
- **Procedures:** Dual approval for transactions >$100K

### Emergency Procedures

#### Emergency Pause Authority
```solidity
// Emergency pause can be triggered by:
// 1. Multi-sig consensus (3-of-5)
// 2. Automated monitoring systems (critical alerts)
// 3. Community governance (emergency proposal)
```

#### Incident Response Team
- **Incident Commander:** CTO (24/7 on-call)
- **Technical Lead:** Lead Smart Contract Developer  
- **Operations Lead:** DevOps Manager
- **Communications Lead:** Head of Community
- **Legal Lead:** General Counsel

### Rollback Procedures

#### Contract Upgrade Rollback
```bash
# Emergency rollback via governance
npx hardhat run scripts/emergency-rollback.js --network arbitrumOne

# Requires:
# - Multi-sig approval
# - Community notification
# - 24-hour delay (unless critical)
```

#### State Recovery
- Pause affected contracts
- Analyze state corruption
- Deploy fixed contracts
- Migrate state if possible
- Compensate affected users

## Compliance and Legal

### Regulatory Compliance

#### United States
- [ ] SEC securities law analysis completed
- [ ] CFTC derivatives regulations reviewed
- [ ] FinCEN AML/KYC requirements addressed
- [ ] State money transmission licenses evaluated

#### European Union
- [ ] MiCA regulation compliance verified
- [ ] GDPR privacy requirements implemented
- [ ] Financial services licensing reviewed
- [ ] Cross-border transfer regulations addressed

#### Other Jurisdictions
- [ ] Major jurisdiction analysis completed
- [ ] Restricted territory blocking implemented
- [ ] Local counsel consultations completed
- [ ] Regulatory monitoring established

### Legal Documentation

#### Terms of Service
- Smart contract interaction terms
- Risk disclosures and disclaimers
- Intellectual property protections
- Dispute resolution procedures

#### Privacy Policy
- Data collection and usage policies
- GDPR compliance measures
- User rights and procedures
- Third-party service disclosures

## Communication Plan

### Pre-Launch (T-7 days)
- [ ] Security audit results published
- [ ] Deployment timeline announced
- [ ] Community AMA scheduled
- [ ] Press release prepared

### Launch Day (T-0)
- [ ] Real-time deployment updates
- [ ] Technical documentation published
- [ ] Community support channels activated
- [ ] Monitoring dashboards public

### Post-Launch (T+1 to T+30)
- [ ] Daily status updates
- [ ] Performance metrics published
- [ ] Community feedback collection
- [ ] Issue resolution tracking

## Success Criteria

### Technical Success
- [ ] All contracts deployed successfully
- [ ] 100% test coverage maintained
- [ ] Zero critical vulnerabilities
- [ ] All integrations functional
- [ ] Performance targets met

### Operational Success
- [ ] Monitoring systems operational
- [ ] Security measures active
- [ ] Emergency procedures tested
- [ ] Documentation complete
- [ ] Team training completed

### Business Success
- [ ] Token distribution executed
- [ ] Liquidity established
- [ ] Community engagement active
- [ ] Governance participation strong
- [ ] Revenue generation initiated

## Maintenance and Operations

### Regular Maintenance Tasks

#### Daily
- Monitor system health and performance
- Review security alerts and incidents
- Check community feedback and issues
- Verify automated system operations

#### Weekly  
- Analyze gas usage and optimization opportunities
- Review governance proposals and voting
- Update documentation and procedures
- Conduct security team briefings

#### Monthly
- Perform comprehensive security reviews
- Analyze financial and operational metrics
- Update risk assessments and procedures
- Conduct emergency response drills

#### Quarterly
- Complete external security audits
- Review and update threat models
- Assess regulatory compliance status
- Update disaster recovery procedures

### Long-Term Evolution

#### Planned Upgrades
- Governance-approved protocol improvements
- Security enhancement implementations
- Performance optimization deployments
- Feature addition rollouts

#### Community Transition
- Progressive decentralization milestones
- Governance authority transfer
- Community control mechanisms
- Emergency intervention reduction

---

**Deployment Team Contacts:**
- **Technical Lead:** tech-lead@karmalabs.com
- **Operations Manager:** ops@karmalabs.com  
- **Security Team:** security@karmalabs.com
- **Emergency Contact:** +1-555-KARMA-911

**Documentation Version:** 1.0  
**Last Updated:** [Date]  
**Next Review:** [Date + 3 months] 