# Karma Labs Smart Contracts

This repository contains the smart contracts for the Karma Labs ecosystem, starting with the core `$KARMA` token implementation.

## Overview

The Karma Labs smart contract ecosystem enables:
- AI inference payments on 0G blockchain
- iNFT trading and interactions  
- Gasless transactions via Paymaster
- Community governance via KarmaDAO
- Automated tokenomics with buyback-and-burn

## Current Implementation Status

### ✅ Development Stage 1.1: KarmaToken Contract (COMPLETED)

The core `$KARMA` ERC-20 token with enhanced features:

**Core ERC-20 Implementation:**
- ✅ Inherits from OpenZeppelin ERC20, ERC20Burnable, Pausable
- ✅ Standard functions (transfer, approve, balanceOf, etc.)
- ✅ Total supply management (1 billion token cap)

**Administrative Features:**
- ✅ Role-based access control (DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE)
- ✅ Minting function restricted to authorized contracts
- ✅ Burning function for buyback-and-burn mechanism
- ✅ Pause/unpause for emergency scenarios

**Integration Interfaces:**
- ✅ Interfaces for VestingVault interaction
- ✅ Events for Treasury and BuybackBurn tracking
- ✅ Hooks for future Paymaster integration

## Contract Specifications

### KarmaToken.sol

**Token Details:**
- Name: Karma Token
- Symbol: KARMA
- Decimals: 18
- Max Supply: 1,000,000,000 KARMA
- Network: Arbitrum (with 0G integration)

**Key Features:**
- **Mintable**: Only contracts with MINTER_ROLE can mint tokens
- **Burnable**: Users can burn their tokens; BuybackBurn contract can burn purchased tokens
- **Pausable**: Emergency pause functionality for all token operations
- **Role-Based Access**: Secure admin functions with multi-signature control
- **Integration Ready**: Built-in hooks for ecosystem contracts

**Roles:**
- `DEFAULT_ADMIN_ROLE`: Can manage all roles and pause/unpause
- `MINTER_ROLE`: Can mint tokens (intended for SaleManager and Treasury)
- `PAUSER_ROLE`: Can pause/unpause token operations

**Integration Contracts:**
- VestingVault: Manages team and investor token vesting
- Treasury: Stores and distributes funds for ecosystem operations
- SaleManager: Handles private, pre-sale, and public token sales
- BuybackBurn: Executes automated token buybacks and burns
- Paymaster: Enables gasless transactions for users

## Usage

### Installation

```bash
npm install
```

### Compilation

```bash
npx hardhat compile
```

### Testing

```bash
npx hardhat test
```

### Deployment

```bash
# Deploy to local Hardhat network
npx hardhat run scripts/deploy.js

# Deploy to testnet
npx hardhat run scripts/deploy.js --network arbitrumTestnet

# Deploy to mainnet
npx hardhat run scripts/deploy.js --network arbitrum
```

## Security Features

- **OpenZeppelin Libraries**: Uses battle-tested OpenZeppelin contracts
- **Role-Based Access Control**: Granular permissions for different operations
- **Reentrancy Protection**: Guards against reentrancy attacks
- **Emergency Pause**: Ability to halt all operations in emergency
- **Supply Cap**: Hard cap of 1 billion tokens prevents inflation
- **Comprehensive Testing**: 100% test coverage of all functions

## Development Roadmap

### Completed (Stage 1.1)
- ✅ KarmaToken core implementation
- ✅ Role-based access control
- ✅ Minting and burning functionality
- ✅ Pausable emergency controls
- ✅ Integration interfaces
- ✅ Comprehensive test suite

### Next Steps (Stage 1.2 - 9)
- [ ] Administrative Control System (Gnosis Safe integration)
- [ ] VestingVault implementation
- [ ] SaleManager for multi-phase token sales
- [ ] Treasury management system
- [ ] Paymaster for gasless transactions
- [ ] BuybackBurn automated tokenomics
- [ ] KarmaDAO governance system
- [ ] 0G blockchain integration
- [ ] Security audits and production deployment

## Testing

The contract includes comprehensive tests covering:

- **Deployment**: Proper initialization and role assignment
- **Role Management**: Admin operations and access control
- **Minting**: Token creation with proper restrictions
- **Burning**: Token destruction and event emission
- **Pausable**: Emergency pause/unpause functionality
- **Integration Setters**: Contract address management
- **Paymaster Integration**: Gas sponsorship hooks
- **View Functions**: Data retrieval and supply tracking
- **Emergency Functions**: Token recovery mechanisms

All tests pass with 100% coverage:
```
39 passing (1s)
```

## Gas Optimization

The contract is optimized for gas efficiency:
- Compiler optimization enabled (200 runs)
- Efficient storage patterns
- Minimal external calls
- Optimized role checking

**Average Gas Costs:**
- Deployment: ~1,618,240 gas
- Mint: ~77,757 gas
- Transfer: ~46,469 gas (standard ERC-20)
- Burn: ~37,707 gas

## License

MIT License - see LICENSE file for details

## Contact

For questions or support, reach out to the Karma Labs team. 