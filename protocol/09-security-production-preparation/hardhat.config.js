require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("solidity-coverage");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
      gas: 12000000,
      gasPrice: 20000000000,
      allowUnlimitedContractSize: false,
      accounts: {
        count: 20,
        accountsBalance: "10000000000000000000000", // 10,000 ETH
      },
      forking: {
        url: process.env.ARBITRUM_RPC_URL || "https://arbitrum-mainnet.infura.io/v3/YOUR_KEY",
        enabled: false,
      },
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    arbitrumGoerli: {
      url: process.env.ARBITRUM_GOERLI_RPC_URL || "https://arbitrum-goerli.infura.io/v3/YOUR_KEY",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 421613,
      gas: 287853530,
      gasPrice: 100000000,
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY,
          apiUrl: "https://api-goerli.arbiscan.io",
        },
      },
    },
    arbitrumOne: {
      url: process.env.ARBITRUM_RPC_URL || "https://arbitrum-mainnet.infura.io/v3/YOUR_KEY",
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      chainId: 42161,
      gas: 287853530,
      gasPrice: "auto",
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY,
          apiUrl: "https://api.arbiscan.io",
        },
      },
    },
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY,
      arbitrumGoerli: process.env.ARBISCAN_API_KEY,
    },
    customChains: [
      {
        network: "arbitrumOne",
        chainId: 42161,
        urls: {
          apiURL: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io",
        },
      },
      {
        network: "arbitrumGoerli",
        chainId: 421613,
        urls: {
          apiURL: "https://api-goerli.arbiscan.io/api",
          browserURL: "https://goerli.arbiscan.io",
        },
      },
    ],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    gasPrice: 21,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    token: "ETH",
    gasPriceApi: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
    showMethodSig: true,
    showTimeSpent: true,
    excludeContracts: ["Mock", "Test"],
    outputFile: "gas-report.txt",
    noColors: true,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: ["Karma"],
    except: ["Mock", "Test"],
  },
  mocha: {
    timeout: 300000, // 5 minutes
    reporter: "spec",
    bail: false,
    grep: process.env.TEST_GREP || "",
  },
  // Security-focused settings
  security: {
    // Static analysis tools
    slither: {
      enabled: true,
      config: "tools/slither-config.json",
    },
    mythril: {
      enabled: true,
      config: "tools/mythril-config.json",
    },
    // Audit requirements
    audit: {
      required: true,
      minimumFirms: 3,
      scope: "FULL_SYSTEM",
    },
    // Bug bounty settings
    bugBounty: {
      platform: "immunefi",
      maxReward: 200000,
      active: true,
    },
  },
  // Production deployment settings
  production: {
    network: "arbitrumOne",
    verification: {
      required: true,
      timeout: 300000, // 5 minutes
    },
    monitoring: {
      forta: {
        enabled: true,
        bots: ["attack-detector", "governance-monitor", "treasury-watcher", "bridge-monitor"],
      },
      defender: {
        enabled: true,
        apiKey: process.env.DEFENDER_API_KEY,
        apiSecret: process.env.DEFENDER_API_SECRET,
      },
      custom: {
        enabled: true,
        endpoint: process.env.MONITORING_ENDPOINT,
      },
    },
    alerting: {
      slack: {
        webhook: process.env.SLACK_WEBHOOK_URL,
        channel: "#critical-alerts",
      },
      discord: {
        webhook: process.env.DISCORD_WEBHOOK_URL,
        channel: "critical-alerts",
      },
      email: {
        enabled: true,
        smtp: process.env.SMTP_ENDPOINT,
        recipients: ["security@karmalabs.com", "ops@karmalabs.com"],
      },
      sms: {
        enabled: true,
        provider: "twilio",
        numbers: [process.env.EMERGENCY_PHONE_1, process.env.EMERGENCY_PHONE_2],
      },
    },
    performance: {
      targets: {
        availability: 0.999, // 99.9%
        responseTime: 500, // 500ms
        throughput: 1000, // 1000 TPS
        errorRate: 0.001, // 0.1%
      },
      monitoring: {
        interval: 30, // 30 seconds
        retention: 2592000, // 30 days
      },
    },
    backup: {
      enabled: true,
      frequency: "hourly",
      retention: "90d",
      storage: {
        primary: "aws-s3",
        secondary: "google-cloud",
        tertiary: "azure-blob",
      },
      encryption: {
        enabled: true,
        algorithm: "AES-256",
        keyManagement: "aws-kms",
      },
    },
    disaster_recovery: {
      rpo: 3600, // 1 hour
      rto: 1800, // 30 minutes
      failover: {
        mode: "active-passive",
        automation: true,
        testing: "monthly",
      },
    },
  },
  // Environment-specific settings
  environments: {
    development: {
      security: "standard",
      monitoring: "basic",
      logging: "verbose",
    },
    staging: {
      security: "enhanced",
      monitoring: "comprehensive",
      logging: "detailed",
    },
    production: {
      security: "maximum",
      monitoring: "realtime",
      logging: "audit",
    },
  },
  // Compliance settings
  compliance: {
    gdpr: {
      enabled: true,
      dataProtection: true,
      privacyByDesign: true,
    },
    ccpa: {
      enabled: true,
      dataRights: true,
      optOut: true,
    },
    iso27001: {
      target: true,
      framework: "2013",
      scope: "information-security",
    },
    soc2: {
      target: true,
      type: "TYPE_II",
      auditor: "big-four",
    },
  },
  // Testing configuration
  testing: {
    coverage: {
      target: 100,
      threshold: {
        statements: 95,
        branches: 90,
        functions: 95,
        lines: 95,
      },
    },
    security: {
      penetration: true,
      fuzzing: true,
      staticAnalysis: true,
      dynamicAnalysis: true,
    },
    performance: {
      load: true,
      stress: true,
      endurance: true,
      volume: true,
    },
    integration: {
      crossContract: true,
      crossChain: true,
      endToEnd: true,
    },
  },
  // Documentation settings
  documentation: {
    natspec: {
      required: true,
      coverage: 100,
    },
    technical: {
      architecture: true,
      deployment: true,
      security: true,
      operations: true,
    },
    user: {
      guides: true,
      tutorials: true,
      api: true,
    },
  },
  // CI/CD settings
  cicd: {
    github: {
      workflows: [".github/workflows/ci.yml", ".github/workflows/security-scan.yml"],
      secrets: ["PRIVATE_KEY", "ARBISCAN_API_KEY", "SLACK_WEBHOOK"],
    },
    quality: {
      gates: {
        coverage: 95,
        security: "A+",
        performance: "A",
      },
      tools: ["eslint", "prettier", "slither", "mythril"],
    },
  },
  // Paths configuration
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    docs: "./docs",
    scripts: "./scripts",
    utils: "./utils",
    config: "./config",
    tools: "./tools",
  },
}; 