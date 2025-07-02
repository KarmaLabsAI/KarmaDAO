require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("hardhat-contract-sizer");
require("hardhat-docgen");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";
const INFURA_API_KEY = process.env.INFURA_API_KEY || "";
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY || "";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "";

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
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        accountsBalance: "10000000000000000000000"
      },
      forking: process.env.FORK_MAINNET === "true" ? {
        url: `https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}`,
        blockNumber: 140000000
      } : undefined,
      allowUnlimitedContractSize: true,
      blockGasLimit: 30000000,
      gas: 30000000,
      gasPin: 0,
      initialBaseFeePerGas: 0
    },
    
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      accounts: [PRIVATE_KEY]
    },
    
    // Ethereum Networks
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 1,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto",
      verify: {
        etherscan: {
          apiKey: ETHERSCAN_API_KEY
        }
      }
    },
    
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 5,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    },
    
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 11155111,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    },
    
    // Arbitrum Networks
    arbitrumOne: {
      url: `https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 42161,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto",
      verify: {
        etherscan: {
          apiKey: ARBISCAN_API_KEY,
          apiUrl: "https://api.arbiscan.io"
        }
      }
    },
    
    arbitrumGoerli: {
      url: `https://arbitrum-goerli.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 421613,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    },
    
    arbitrumSepolia: {
      url: `https://arbitrum-sepolia.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 421614,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    },
    
    // 0G Network (placeholder configuration)
    zeroG: {
      url: "https://rpc.0g.ai",
      chainId: 12345,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 60000,
      httpHeaders: {
        "User-Agent": "KarmaLabs/1.0"
      }
    },
    
    zeroGTestnet: {
      url: "https://testnet-rpc.0g.ai",
      chainId: 54321,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    },
    
    // Polygon Networks (for potential expansion)
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 137,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    },
    
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${INFURA_API_KEY}`,
      chainId: 80001,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto"
    }
  },
  
  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      goerli: ETHERSCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      arbitrumOne: ARBISCAN_API_KEY,
      arbitrumGoerli: ARBISCAN_API_KEY,
      arbitrumSepolia: ARBISCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || ""
    },
    customChains: [
      {
        network: "arbitrumOne",
        chainId: 42161,
        urls: {
          apiURL: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io"
        }
      },
      {
        network: "arbitrumGoerli",
        chainId: 421613,
        urls: {
          apiURL: "https://api-goerli.arbiscan.io/api",
          browserURL: "https://goerli.arbiscan.io"
        }
      },
      {
        network: "arbitrumSepolia",
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
    gasPrice: 10,
    coinmarketcap: COINMARKETCAP_API_KEY,
    token: "ETH",
    gasPriceApi: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
    showTimeSpent: true,
    showMethodSig: true,
    maxMethodDiff: 10,
    excludeContracts: ["Mock", "Test"],
    src: "./contracts",
    outputFile: "./gas-report.txt",
    noColors: false
  },
  
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
    strict: true,
    only: ["ZeroGIntegration", "CrossChainBridge", "KarmaLabsIntegration", "SillyPortIntegration", "SillyHotelIntegration"]
  },
  
  docgen: {
    path: "./docs",
    clear: true,
    runOnCompile: false,
    except: ["test", "Mock"]
  },
  
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6"
  },
  
  mocha: {
    timeout: 120000,
    bail: false,
    allowUncaught: false,
    reporter: "spec",
    slow: 10000
  },
  
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  
  // Custom task configurations
  defaultNetwork: "hardhat",
  
  // Additional compiler configurations for Stage 8
  compilers: [
    {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        viaIR: true,
        metadata: {
          bytecodeHash: "none",
          useLiteralContent: true
        },
        outputSelection: {
          "*": {
            "*": ["evm.bytecode", "evm.deployedBytecode", "devdoc", "userdoc", "metadata", "abi"]
          }
        }
      }
    }
  ],
  
  // External contract deployments for integration
  external: {
    contracts: [
      {
        artifacts: "../01-core-token-infrastructure/artifacts",
        deploy: "../01-core-token-infrastructure/deployments"
      },
      {
        artifacts: "../06-tokenomics-value-accrual/artifacts", 
        deploy: "../06-tokenomics-value-accrual/deployments"
      }
    ],
    deployments: {
      hardhat: ["../deployments/hardhat"],
      localhost: ["../deployments/localhost"],
      arbitrumOne: ["../deployments/arbitrumOne"],
      arbitrumGoerli: ["../deployments/arbitrumGoerli"]
    }
  }
}; 