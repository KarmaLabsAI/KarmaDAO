require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
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
      allowUnlimitedContractSize: true,
      accounts: {
        count: 10,
        accountsBalance: "10000000000000000000000" // 10k ETH
      }
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL || "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    },
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL || "https://sepolia-rollup.arbitrum.io/rpc",
      chainId: 421614,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      arbitrumSepolia: process.env.ARBISCAN_API_KEY || ""
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 0.1, // gwei for Arbitrum
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    excludeContracts: ["Mock"]
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [":BuybackBurn", ":FeeCollector", ":DEXRouter", ":ChainlinkKeeper"]
  },
  mocha: {
    timeout: 300000 // 5 minutes
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6"
  }
}; 