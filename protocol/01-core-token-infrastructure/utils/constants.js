/**
 * Karma Labs Smart Contract System Constants
 * Stage 1: Core Token Infrastructure
 */

// ============ TOKEN CONSTANTS ============

const TOKEN_CONSTANTS = {
    // Token Details
    NAME: "KarmaToken",
    SYMBOL: "KARMA",
    DECIMALS: 18,
    
    // Supply Management
    MAX_SUPPLY: "1000000000", // 1 billion tokens (in token units)
    MAX_SUPPLY_WEI: "1000000000000000000000000000", // 1 billion * 10^18
    
    // Initial Allocations (percentages)
    ALLOCATIONS: {
        PRIVATE_SALE: 10, // 100M tokens
        PRE_SALE: 10, // 100M tokens  
        PUBLIC_SALE: 15, // 150M tokens
        TEAM: 20, // 200M tokens
        COMMUNITY_REWARDS: 20, // 200M tokens
        TREASURY_RESERVE: 15, // 150M tokens
        STAKING_REWARDS: 10 // 100M tokens
    },
    
    // Role Identifiers (keccak256 hashes)
    ROLES: {
        DEFAULT_ADMIN_ROLE: "0x0000000000000000000000000000000000000000000000000000000000000000",
        MINTER_ROLE: "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
        PAUSER_ROLE: "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a",
        BURNER_ROLE: "0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848"
    }
};

// ============ ADMIN CONSTANTS ============

const ADMIN_CONSTANTS = {
    // MultiSig Configuration
    MULTISIG: {
        REQUIRED_SIGNATURES: 3,
        TOTAL_SIGNERS: 5,
        CONFIRMATION_TIME_SECONDS: 86400, // 24 hours
        EXECUTION_TIME_LIMIT: 604800 // 7 days
    },
    
    // Timelock Configuration
    TIMELOCK: {
        MIN_DELAY: 259200, // 3 days in seconds
        MAX_DELAY: 2592000, // 30 days in seconds
        GRACE_PERIOD: 1209600 // 14 days in seconds
    },
    
    // Emergency Controls
    EMERGENCY: {
        PAUSE_DURATION: 604800, // 7 days
        ROLE_REVOCATION_COOLDOWN: 86400, // 24 hours
        EMERGENCY_ADMIN_COUNT: 2
    },
    
    // Admin Roles
    ROLES: {
        EMERGENCY_ADMIN_ROLE: "0x5d8e12c39faa2a67e6b84d0ed8b40b09f5dd74d3c3e6d6e6e7e6e6e6e6e6e6e",
        TIMELOCK_ADMIN_ROLE: "0x7d8e12c39faa2a67e6b84d0ed8b40b09f5dd74d3c3e6d6e6e7e6e6e6e6e6e6e",
        MULTISIG_ADMIN_ROLE: "0x8d8e12c39faa2a67e6b84d0ed8b40b09f5dd74d3c3e6d6e6e7e6e6e6e6e6e6e",
        PROTOCOL_ADMIN_ROLE: "0x9d8e12c39faa2a67e6b84d0ed8b40b09f5dd74d3c3e6d6e6e7e6e6e6e6e6e6e"
    }
};

// ============ DEPLOYMENT CONSTANTS ============

const DEPLOYMENT_CONSTANTS = {
    // Network Configuration
    NETWORKS: {
        HARDHAT: {
            CHAIN_ID: 31337,
            GAS_LIMIT: 30000000,
            GAS_PRICE: "20000000000" // 20 gwei
        },
        ARBITRUM_MAINNET: {
            CHAIN_ID: 42161,
            GAS_LIMIT: 32000000,
            GAS_PRICE: "100000000" // 0.1 gwei
        },
        ARBITRUM_GOERLI: {
            CHAIN_ID: 421613,
            GAS_LIMIT: 32000000,
            GAS_PRICE: "100000000" // 0.1 gwei
        }
    },
    
    // Contract Deployment Order
    DEPLOYMENT_ORDER: [
        "KarmaMultiSigManager",
        "KarmaTimelock", 
        "AdminControl",
        "KarmaToken"
    ],
    
    // Verification Delays
    VERIFICATION_DELAY: 30000, // 30 seconds
    
    // Gas Optimization
    OPTIMIZER: {
        ENABLED: true,
        RUNS: 1000
    }
};

// ============ TESTING CONSTANTS ============

const TESTING_CONSTANTS = {
    // Test Accounts
    ACCOUNTS: {
        DEPLOYER: 0,
        ADMIN: 1,
        MINTER: 2,
        PAUSER: 3,
        USER1: 4,
        USER2: 5,
        EMERGENCY_ADMIN: 6,
        TIMELOCK_ADMIN: 7,
        MULTISIG_ADMIN: 8,
        UNAUTHORIZED: 9
    },
    
    // Test Amounts
    AMOUNTS: {
        MINT_AMOUNT: "1000000000000000000000", // 1000 tokens
        BURN_AMOUNT: "500000000000000000000", // 500 tokens
        SMALL_AMOUNT: "1000000000000000000", // 1 token
        LARGE_AMOUNT: "100000000000000000000000000" // 100M tokens
    },
    
    // Time Constants for Testing
    TIME: {
        ONE_DAY: 86400,
        ONE_WEEK: 604800,
        ONE_MONTH: 2592000,
        ONE_YEAR: 31536000
    }
};

// ============ ERROR MESSAGES ============

const ERROR_MESSAGES = {
    // Access Control Errors
    ACCESS_CONTROL: {
        UNAUTHORIZED: "AccessControl: account is missing role",
        INVALID_ADMIN: "AdminControl: Invalid admin address",
        ROLE_NOT_FOUND: "AdminControl: Role not found",
        ALREADY_HAS_ROLE: "AdminControl: Account already has role"
    },
    
    // Token Errors
    TOKEN: {
        EXCEEDS_MAX_SUPPLY: "KarmaToken: Exceeds maximum supply",
        INSUFFICIENT_BALANCE: "ERC20: transfer amount exceeds balance",
        PAUSED: "Pausable: token transfer while paused",
        INVALID_AMOUNT: "KarmaToken: Invalid amount",
        UNAUTHORIZED_MINTER: "KarmaToken: Unauthorized minter",
        UNAUTHORIZED_BURNER: "KarmaToken: Unauthorized burner"
    },
    
    // Admin Errors
    ADMIN: {
        EMERGENCY_PAUSE_ACTIVE: "AdminControl: Emergency pause active",
        ROLE_EMERGENCY_PAUSED: "AdminControl: Role emergency paused",
        INVALID_TIMELOCK_DELAY: "AdminControl: Invalid timelock delay",
        MULTISIG_INSUFFICIENT_SIGNATURES: "AdminControl: Insufficient signatures",
        CONTRACT_NOT_AUTHORIZED: "AdminControl: Contract not authorized"
    }
};

// ============ EVENTS ============

const EVENTS = {
    // Token Events
    TOKEN: {
        MINTED: "Minted",
        BURNED: "Burned", 
        PAUSE_STATE_CHANGED: "PauseStateChanged",
        TREASURY_INTEGRATION: "TreasuryIntegration",
        BUYBACK_BURN_INTEGRATION: "BuybackBurnIntegration",
        PAYMASTER_INTEGRATION: "PaymasterIntegration"
    },
    
    // Admin Events
    ADMIN: {
        EMERGENCY_PAUSE_ACTIVATED: "EmergencyPauseActivated",
        EMERGENCY_PAUSE_DEACTIVATED: "EmergencyPauseDeactivated",
        CONTRACT_AUTHORIZED: "ContractAuthorized",
        ROLE_EMERGENCY_PAUSED: "RoleEmergencyPaused",
        ADMIN_TRANSFERRED: "AdminTransferred",
        MULTISIG_MANAGER_UPDATED: "MultiSigManagerUpdated",
        TIMELOCK_UPDATED: "TimelockUpdated"
    }
};

// ============ EXPORTS ============

module.exports = {
    TOKEN_CONSTANTS,
    ADMIN_CONSTANTS,
    DEPLOYMENT_CONSTANTS,
    TESTING_CONSTANTS,
    ERROR_MESSAGES,
    EVENTS
}; 