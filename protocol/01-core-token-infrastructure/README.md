# Stage 1: Core Token Infrastructure

This directory contains all the files and contracts for Stage 1 of the Karma Labs protocol development - the Core Token Infrastructure phase.

## Overview

Stage 1 focuses on building the foundational token system and administrative controls that will serve as the backbone for all subsequent development stages.

## Components

### 1.1 KarmaToken Contract Development
- **Contract**: `contracts/KarmaToken.sol`
- **Interface**: `contracts/interfaces/IKarmaToken.sol`
- **Tests**: `test/KarmaToken.test.js`, `test/Stage1.1.test.js`
- **Deployment**: `scripts/deploy-stage1.1.js`
- **Configuration**: `config/stage1.1-config.json`

### 1.2 Administrative Control System
- **Contracts**: 
  - `contracts/access/KarmaMultiSigManager.sol`
  - `contracts/access/KarmaTimelock.sol`
  - `contracts/access/AdminControl.sol`
- **Tests**: `test/AdminSystem.test.js`, `test/KarmaAdminSystem.test.js`, `test/Stage1.2.test.js`
- **Deployment**: `scripts/deploy-stage1.2.js`
- **Configuration**: `config/stage1.2-config.json`

## Features

### KarmaToken Features
- ERC-20 compliant with 1 billion token maximum supply
- Role-based access control (Admin, Minter, Pauser, Burner)
- Pausable functionality for emergency scenarios
- Burnability for buyback-and-burn mechanisms
- Integration hooks for Treasury, BuybackBurn, and Paymaster contracts

### Administrative Control Features
- Multi-signature wallet integration (3-of-5 setup)
- Timelock controller for delayed execution
- Emergency pause mechanisms
- Role-based access control across the protocol
- Contract authorization framework

## Deployment

### Prerequisites
```bash
npm install
```

### Deploy Stage 1.1 (KarmaToken)
```bash
npm run deploy:stage1.1
```

### Deploy Stage 1.2 (Administrative Controls)
```bash
npm run deploy:stage1.2
```

### Deploy All Stage 1 Components
```bash
npm run deploy:all
```

## Testing

### Run All Tests
```bash
npm test
```

### Run Specific Stage Tests
```bash
npx hardhat test test/Stage1.1.test.js
npx hardhat test test/Stage1.2.test.js
```

## Configuration

Configuration files are located in the `config/` directory:
- `stage1.1-config.json` - KarmaToken configuration
- `stage1.2-config.json` - Administrative control configuration

## File Structure

```
01-core-token-infrastructure/
├── contracts/
│   ├── KarmaToken.sol
│   ├── interfaces/
│   │   └── IKarmaToken.sol
│   └── access/
│       ├── AdminControl.sol
│       ├── KarmaMultiSigManager.sol
│       └── KarmaTimelock.sol
├── test/
│   ├── KarmaToken.test.js
│   ├── AdminSystem.test.js
│   ├── KarmaAdminSystem.test.js
│   ├── Stage1.1.test.js
│   └── Stage1.2.test.js
├── scripts/
│   ├── deploy-admin-system.js
│   ├── deploy-stage1.1.js
│   └── deploy-stage1.2.js
├── config/
│   ├── stage1.1-config.json
│   └── stage1.2-config.json
├── utils/
│   └── constants.js
├── artifacts/
├── logs/
├── migrations/
└── verification/
```

## Integration with Other Stages

Stage 1 contracts are designed to integrate with:
- **Stage 2**: Vesting systems will reference KarmaToken for token distribution
- **Stage 3**: Sale contracts will mint tokens through KarmaToken
- **Stage 4**: Treasury will manage funds and coordinate with AdminControl
- **Stage 5**: Paymaster will receive funding and sponsorship authorization
- **Stage 6**: BuybackBurn will burn tokens through KarmaToken interface
- **Stage 7**: Governance will build upon AdminControl framework

## Security Considerations

- Multi-signature requirements for all administrative actions
- Timelock delays for sensitive operations
- Emergency pause mechanisms across all contracts
- Role-based access control preventing unauthorized actions
- Comprehensive test coverage ensuring contract reliability

## Next Steps

After successful deployment of Stage 1:
1. Deploy Stage 2 (Vesting System Architecture)
2. Integrate vesting contracts with KarmaToken minting
3. Configure administrative controls for vesting management
4. Prepare for Stage 3 (Token Sales Engine) integration 