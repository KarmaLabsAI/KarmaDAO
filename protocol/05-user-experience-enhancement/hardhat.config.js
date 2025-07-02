require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("hardhat-gas-reporter");
require("solidity-coverage");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    hardhat: {
      chainId: 31337,
      accounts: {
        count: 20,
        accountsBalance: "10000000000000000000000" // 10,000 ETH
      },
      gas: 30000000,
      gasPrice: 8000000000, // 8 gwei
      blockGasLimit: 30000000
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      gas: 30000000,
      gasPrice: 8000000000,
      timeout: 60000
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL || "https://arb1.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 42161,
      gas: 30000000,
      gasPrice: 100000000, // 0.1 gwei
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY
        }
      }
    },
    arbitrumGoerli: {
      url: process.env.ARBITRUM_GOERLI_RPC_URL || "https://goerli-rollup.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 421613,
      gas: 30000000,
      gasPrice: 100000000,
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY
        }
      }
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
      gas: 30000000,
      gasPrice: 2000000000, // 2 gwei
      verify: {
        etherscan: {
          apiKey: process.env.ETHERSCAN_API_KEY
        }
      }
    }
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY,
      arbitrumGoerli: process.env.ARBISCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY
    },
    customChains: [
      {
        network: "arbitrumGoerli",
        chainId: 421613,
        urls: {
          apiURL: "https://api-goerli.arbiscan.io/api",
          browserURL: "https://goerli.arbiscan.io"
        }
      }
    ]
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    gasPrice: 20,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    outputFile: "gas-report.txt",
    noColors: true,
    excludeContracts: ["Mock", "Test"]
  },
  mocha: {
    timeout: 60000,
    retries: 0
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  defaultNetwork: "hardhat"
}; 