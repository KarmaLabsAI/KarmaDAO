require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");

// Load environment variables
require('dotenv').config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID || "";

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
      chainId: 1337,
      gas: 12000000,
      blockGasLimit: 12000000,
      allowUnlimitedContractSize: false,
      accounts: {
        count: 20,
        accountsBalance: "10000000000000000000000" // 10,000 ETH
      }
    },
    
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 1337
    },
    
    arbitrum: {
      url: `https://arbitrum-mainnet.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [PRIVATE_KEY],
      chainId: 42161
    },
    
    arbitrumGoerli: {
      url: `https://arbitrum-goerli.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [PRIVATE_KEY],
      chainId: 421613
    },
    
    arbitrumSepolia: {
      url: `https://arbitrum-sepolia.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [PRIVATE_KEY],
      chainId: 421614
    }
  },
  
  etherscan: {
    apiKey: {
      arbitrumOne: ETHERSCAN_API_KEY,
      arbitrumGoerli: ETHERSCAN_API_KEY,
      arbitrumSepolia: ETHERSCAN_API_KEY
    }
  },
  
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 20,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  },
  
  mocha: {
    timeout: 40000
  },
  
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  
  // Custom task configurations
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5"
  }
}; 