# Stage 2: Vesting System Architecture

## Overview

Stage 2 implements a comprehensive vesting system architecture for the Karma Labs ecosystem, providing flexible time-locked token distribution mechanisms for team members, investors, and other stakeholders.

## Architecture

### Core Components

1. **VestingVault** - Core vesting contract with flexible scheduling capabilities
2. **TeamVesting** - Team-specific 4-year vesting with 1-year cliff
3. **PrivateSaleVesting** - Private sale 6-month linear vesting
4. **VestingCalculator** - Mathematical utilities for vesting calculations

### Stage Structure

- **Stage 2.1**: VestingVault Core Development
- **Stage 2.2**: Vesting Schedule Configurations

## Features

### VestingVault (Stage 2.1)
- ✅ Flexible vesting schedule creation
- ✅ Multi-beneficiary management
- ✅ Cliff period support
- ✅ Linear and custom vesting curves
- ✅ Emergency pause functionality
- ✅ Role-based access control
- ✅ Gas-optimized operations

### Vesting Configurations (Stage 2.2)
- ✅ Team vesting (4 years, 1-year cliff)
- ✅ Private sale vesting (6 months, linear)
- ✅ Configurable vesting templates
- ✅ Manager role assignments
- ✅ Integration with VestingVault

## Dependencies

- **Stage 1**: Core Token Infrastructure (KarmaToken)
- OpenZeppelin Contracts (AccessControl, Pausable, ReentrancyGuard)

## Quick Start

### Installation

```bash
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

# Run Stage 2.1 tests
npm run test:stage2.1

# Run Stage 2.2 tests  
npm run test:stage2.2

# Run vesting vault tests
npm run test:vesting

# Run vesting managers tests
npm run test:vesting-managers
```

### Deployment

```bash
# Deploy Stage 2.1 (VestingVault Core)
npm run deploy:stage2.1

# Deploy Stage 2.2 (Vesting Configurations)
npm run deploy:stage2.2

# Setup Stage 2.1
npm run setup:stage2.1

# Setup Stage 2.2
npm run setup:stage2.2
```

### Validation

```bash
# Validate Stage 2.1 deployment
npm run validate:stage2.1

# Validate Stage 2.2 deployment
npm run validate:stage2.2
```

## Contract Addresses

Contract addresses will be populated after deployment in the artifacts directory:
- `artifacts/stage2.1-contracts.json` - Stage 2.1 deployment artifacts
- `artifacts/stage2.2-contracts.json` - Stage 2.2 deployment artifacts

## Configuration

### Stage 2.1 Configuration
- Maximum beneficiaries: 10,000
- Maximum schedules per beneficiary: 10
- Minimum vesting duration: 1 day
- Maximum vesting duration: 4 years
- Emergency withdrawal: Enabled
- Pausable: Yes

### Stage 2.2 Configuration

#### Team Vesting
- Duration: 4 years (126,144,000 seconds)
- Cliff: 1 year (31,536,000 seconds)
- Release frequency: Monthly
- Total allocation: 200M KARMA tokens

#### Private Sale Vesting
- Duration: 6 months (15,552,000 seconds)
- Cliff: None (0 seconds)
- Release frequency: Monthly
- Total allocation: 100M KARMA tokens

## Vesting Mathematics

The vesting system uses precise mathematical calculations:

### Linear Vesting Formula
```
vestedAmount = totalAmount * (currentTime - startTime) / (endTime - startTime)
```

### Cliff Vesting
```
if (currentTime < cliffTime) {
    vestedAmount = 0
} else {
    vestedAmount = calculateLinearVesting(...)
}
```

## Security Features

- **Access Control**: Role-based permissions for all operations
- **Pausable**: Emergency pause functionality
- **Reentrancy Guards**: Protection against reentrancy attacks
- **Parameter Validation**: Comprehensive input validation
- **Emergency Recovery**: Admin emergency withdrawal capabilities

## Gas Optimization

- Optimized storage layouts
- Batch operations support
- Efficient beneficiary management
- Minimal on-chain calculations

## Integration Points

### Stage 1 Integration
- Depends on KarmaToken contract
- Uses AdminControl for role management
- Integrates with Treasury for funding

### Future Stage Integration
- **Stage 3**: Token Sales Engine will create vesting schedules
- **Stage 4**: Treasury will fund vesting contracts
- **Stage 7**: DAO governance will control vesting parameters

## Development Workflow

1. **Deploy Stage 2.1**: Core VestingVault infrastructure
2. **Setup Stage 2.1**: Configure roles and parameters
3. **Validate Stage 2.1**: Verify deployment and functionality
4. **Deploy Stage 2.2**: Vesting schedule configurations
5. **Setup Stage 2.2**: Configure team and private sale vesting
6. **Validate Stage 2.2**: Verify all configurations

## Testing Strategy

- **Unit Tests**: Individual contract functionality
- **Integration Tests**: Cross-contract interactions
- **Scenario Tests**: Real-world vesting scenarios
- **Edge Case Tests**: Boundary conditions and error cases
- **Gas Tests**: Gas optimization validation

## Monitoring and Analytics

- Event logging for all vesting operations
- Real-time vesting progress tracking
- Beneficiary analytics and reporting
- Compliance reporting capabilities

## Troubleshooting

### Common Issues

1. **Deployment Failures**: Check Stage 1 dependencies
2. **Role Assignment Errors**: Verify admin permissions
3. **Vesting Calculation Errors**: Validate time parameters
4. **Gas Limit Issues**: Increase gas limit for batch operations

### Error Codes

- `VV001`: Invalid vesting parameters
- `VV002`: Insufficient permissions
- `VV003`: Contract paused
- `VV004`: Invalid beneficiary address
- `VV005`: Vesting schedule not found

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Update documentation
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

For technical support and questions:
- GitHub Issues: https://github.com/karma-labs/smart-contracts/issues
- Documentation: https://docs.karmalabs.org
- Community: https://discord.gg/karmalabs 