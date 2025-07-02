require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("solidity-coverage");

// Load environment variables
require('dotenv').config({ path: '../../.env' });

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x" + "0".repeat(64);
const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY || "";
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
const INFURA_API_KEY = process.env.INFURA_API_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true, // Enable for better optimization
    },
  },
  
  networks: {
    hardhat: {
      chainId: 31337,
      gas: 12000000,
      gasPrice: 20000000000,
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        count: 20,
        accountsBalance: "10000000000000000000000" // 10,000 ETH
      },
      allowUnlimitedContractSize: true,
      blockGasLimit: 30000000,
    },
    
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      gas: 12000000,
      gasPrice: 20000000000,
    },
    
    // Arbitrum One (Mainnet)
    arbitrum: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      chainId: 42161,
      accounts: PRIVATE_KEY !== "0x" + "0".repeat(64) ? [PRIVATE_KEY] : [],
      gasPrice: 100000000, // 0.1 gwei
      gas: 8000000,
      verify: {
        etherscan: {
          apiUrl: "https://api.arbiscan.io",
          apiKey: ARBISCAN_API_KEY
        }
      }
    },
    
    // Arbitrum Sepolia (Testnet)
    "arbitrum-sepolia": {
      url: `https://arb-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      chainId: 421614,
      accounts: PRIVATE_KEY !== "0x" + "0".repeat(64) ? [PRIVATE_KEY] : [],
      gasPrice: 100000000, // 0.1 gwei
      gas: 8000000,
      verify: {
        etherscan: {
          apiUrl: "https://api-sepolia.arbiscan.io",
          apiKey: ARBISCAN_API_KEY
        }
      }
    },
    
    // Ethereum Mainnet (for reference)
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 1,
      accounts: PRIVATE_KEY !== "0x" + "0".repeat(64) ? [PRIVATE_KEY] : [],
      gasPrice: 20000000000, // 20 gwei
      gas: 8000000,
    },
  },
  
  etherscan: {
    apiKey: {
      arbitrumOne: ARBISCAN_API_KEY,
      arbitrumTestnet: ARBISCAN_API_KEY,
      "arbitrum-sepolia": ARBISCAN_API_KEY,
    },
    customChains: [
      {
        network: "arbitrum-sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io"
        }
      }
    ]
  },
  
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    gasPrice: 20,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    showTimeSpent: true,
    showMethodSig: true,
    maxMethodDiff: 10,
    maxDeploymentDiff: 10,
    outputFile: "reports/gas-report.txt",
    noColors: false,
    rst: false,
    rstTitle: "Gas Usage Report",
  },
  
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
    strict: true,
    only: ["Treasury", "ITreasury"],
    except: ["Mock"],
  },
  
  mocha: {
    timeout: 300000, // 5 minutes
    reporter: process.env.CI ? "json" : "spec",
    reporterOptions: process.env.CI ? { output: "test-results.json" } : {},
  },
  
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    deploy: "./scripts",
    deployments: "./deployments",
  },
  
  // Stage 4 specific settings
  stage4: {
    treasury: {
      initialBalance: "10000000000000000000000", // 10K ETH
      allocationPercentages: {
        marketing: 30,
        kol: 20,
        development: 30,
        buyback: 20
      },
      withdrawalTimelock: {
        thresholdPercent: 10,
        timelockDays: 7
      }
    },
    tokenDistribution: {
      communityRewards: "200000000000000000000000000", // 200M KARMA
      airdropAllocation: "20000000000000000000000000",  // 20M KARMA
      stakingAllocation: "100000000000000000000000000", // 100M KARMA
      engagementAllocation: "80000000000000000000000000" // 80M KARMA
    }
  }
}; 