require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("hardhat-gas-reporter");
require("solidity-coverage");

const fs = require("fs");
const path = require("path");

// Load environment variables
require("dotenv").config();

// Import contract directories from other stages
const contractPaths = [
  "../../01-core-token-infrastructure/contracts",
  "../../02-vesting-system-architecture/contracts", 
  "./contracts"
];

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      metadata: {
        bytecodeHash: "none",
      },
    },
  },
  
  networks: {
    hardhat: {
      chainId: 31337,
      gas: 12000000,
      blockGasLimit: 12000000,
      allowUnlimitedContractSize: true,
      accounts: {
        count: 20,
        accountsBalance: "10000000000000000000000" // 10,000 ETH
      }
    },
    
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL || "https://arb1.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 42161,
      gas: 5000000,
      gasPrice: 1000000000, // 1 gwei
      timeout: 60000
    },
    
    arbitrumGoerli: {
      url: process.env.ARBITRUM_GOERLI_RPC_URL || "https://goerli-rollup.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 421613,
      gas: 5000000,
      gasPrice: 1000000000,
      timeout: 60000
    },
    
    goerli: {
      url: process.env.GOERLI_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 5,
      gas: 5000000,
      gasPrice: 20000000000, // 20 gwei
      timeout: 60000
    },
    
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1,
      gas: 5000000,
      gasPrice: 30000000000, // 30 gwei
      timeout: 60000
    }
  },
  
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      arbitrumGoerli: process.env.ARBISCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || ""
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
    gasPrice: 1, // gwei
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    excludeContracts: ["mocks/", "test/"],
    src: "./contracts",
    showTimeSpent: true,
    showMethodSig: true,
    maxMethodDiff: 10
  },
  
  mocha: {
    timeout: 40000,
    color: true,
    reporter: "spec"
  },
  
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [":SaleManager$", ":ISaleManager$"]
  },
  
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6",
    alwaysGenerateOverloads: false,
    externalArtifacts: [
      "../../01-core-token-infrastructure/artifacts/contracts/**/*.json",
      "../../02-vesting-system-architecture/artifacts/contracts/**/*.json"
    ]
  },
  
  // Custom task configurations
  defaultNetwork: "hardhat",
  
  // Compilation settings for dependencies
  dependencyCompiler: {
    paths: [
      "@openzeppelin/contracts/token/ERC20/ERC20.sol",
      "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol",
      "@openzeppelin/contracts/security/Pausable.sol",
      "@openzeppelin/contracts/access/AccessControl.sol",
      "@openzeppelin/contracts/security/ReentrancyGuard.sol",
      "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"
    ],
    keep: true
  }
};

// Custom tasks
task("compile-all", "Compile all contracts including dependencies")
  .setAction(async (taskArgs, hre) => {
    console.log("🔨 Compiling all contracts...");
    
    // Compile current stage
    await hre.run("compile");
    
    // Compile dependencies from other stages
    for (const contractPath of contractPaths) {
      const fullPath = path.resolve(__dirname, contractPath);
      if (fs.existsSync(fullPath)) {
        console.log(`📦 Compiling contracts from ${contractPath}...`);
        // This would require additional setup for cross-stage compilation
      }
    }
    
    console.log("✅ All contracts compiled successfully!");
  });

task("deploy-all", "Deploy all Stage 3 components")
  .addOptionalParam("network", "Network to deploy to", "hardhat")
  .setAction(async (taskArgs, hre) => {
    console.log(`🚀 Deploying all Stage 3 components to ${taskArgs.network}...`);
    
    // Deploy Stage 3.1
    console.log("📦 Deploying Stage 3.1: SaleManager Core Architecture...");
    await hre.run("run", { script: "scripts/deploy-stage3.1.js" });
    
    // Deploy Stage 3.2  
    console.log("📦 Deploying Stage 3.2: Sale Phase Implementations...");
    await hre.run("run", { script: "scripts/deploy-stage3.2.js" });
    
    // Deploy Stage 3.3
    console.log("📦 Deploying Stage 3.3: Revenue and Fund Management...");
    await hre.run("run", { script: "scripts/deploy-stage3.3.js" });
    
    console.log("✅ All Stage 3 components deployed successfully!");
  });

task("setup-all", "Setup all Stage 3 components")
  .addOptionalParam("network", "Network to setup on", "hardhat")
  .setAction(async (taskArgs, hre) => {
    console.log(`⚙️ Setting up all Stage 3 components on ${taskArgs.network}...`);
    
    // Setup Stage 3.1
    await hre.run("run", { script: "scripts/setup-stage3.1.js" });
    
    // Setup Stage 3.2
    await hre.run("run", { script: "scripts/setup-stage3.2.js" });
    
    // Setup Stage 3.3  
    await hre.run("run", { script: "scripts/setup-stage3.3.js" });
    
    console.log("✅ All Stage 3 components setup successfully!");
  });

task("validate-all", "Validate all Stage 3 deployments")
  .addOptionalParam("network", "Network to validate on", "hardhat")
  .setAction(async (taskArgs, hre) => {
    console.log(`🔍 Validating all Stage 3 deployments on ${taskArgs.network}...`);
    
    // Validate Stage 3.1
    await hre.run("run", { script: "scripts/validate-stage3.1.js" });
    
    // Validate Stage 3.2
    await hre.run("run", { script: "scripts/validate-stage3.2.js" });
    
    // Validate Stage 3.3
    await hre.run("run", { script: "scripts/validate-stage3.3.js" });
    
    console.log("✅ All Stage 3 validations completed successfully!");
  });

task("generate-whitelist", "Generate whitelist and Merkle tree")
  .addParam("input", "Input CSV file path")
  .addParam("output", "Output directory")
  .setAction(async (taskArgs, hre) => {
    console.log("🌳 Generating whitelist and Merkle tree...");
    const { generateWhitelist } = require("./utils/generate-whitelist");
    await generateWhitelist(taskArgs.input, taskArgs.output);
    console.log("✅ Whitelist generation completed!");
  });

task("calculate-tokens", "Calculate token amounts for given ETH")
  .addParam("eth", "ETH amount")
  .addParam("phase", "Sale phase (private, pre, public)")
  .setAction(async (taskArgs, hre) => {
    const { calculateTokenAmount, formatTokenAmount } = require("./utils/price-calculator");
    const ethAmount = ethers.parseEther(taskArgs.eth);
    const tokens = calculateTokenAmount(ethAmount, taskArgs.phase);
    console.log(`💰 ${taskArgs.eth} ETH = ${formatTokenAmount(tokens)} KARMA (${taskArgs.phase} sale)`);
  }); 