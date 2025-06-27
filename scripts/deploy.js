const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy KarmaToken
  const KarmaToken = await ethers.getContractFactory("KarmaToken");
  console.log("Deploying KarmaToken...");
  
  const karmaToken = await KarmaToken.deploy(deployer.address);
  await karmaToken.waitForDeployment();
  
  const tokenAddress = await karmaToken.getAddress();
  console.log("KarmaToken deployed to:", tokenAddress);
  
  // Verify deployment
  console.log("\n=== Deployment Verification ===");
  console.log("Token Name:", await karmaToken.name());
  console.log("Token Symbol:", await karmaToken.symbol());
  console.log("Token Decimals:", await karmaToken.decimals());
  console.log("Max Supply:", ethers.formatEther(await karmaToken.MAX_SUPPLY()));
  console.log("Current Supply:", ethers.formatEther(await karmaToken.totalSupply()));
  console.log("Remaining Supply:", ethers.formatEther(await karmaToken.remainingSupply()));
  
  // Check admin roles
  const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const PAUSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PAUSER_ROLE"));
  
  console.log("\n=== Role Verification ===");
  console.log("Has DEFAULT_ADMIN_ROLE:", await karmaToken.hasRole(DEFAULT_ADMIN_ROLE, deployer.address));
  console.log("Has MINTER_ROLE:", await karmaToken.hasRole(MINTER_ROLE, deployer.address));
  console.log("Has PAUSER_ROLE:", await karmaToken.hasRole(PAUSER_ROLE, deployer.address));
  
  console.log("\n=== Integration Contracts ===");
  const [vestingVault, treasury, buybackBurn, paymaster, saleManager] = await karmaToken.getIntegrationContracts();
  console.log("VestingVault:", vestingVault);
  console.log("Treasury:", treasury);
  console.log("BuybackBurn:", buybackBurn);
  console.log("Paymaster:", paymaster);
  console.log("SaleManager:", saleManager);
  
  // Save deployment info
  const network = await ethers.provider.getNetwork();
  const deploymentInfo = {
    networkName: network.name,
    chainId: network.chainId,
    karmaToken: tokenAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    blockNumber: await ethers.provider.getBlockNumber()
  };
  
  console.log("\n=== Deployment Complete ===");
  console.log("Network:", network.name);
  console.log("Chain ID:", network.chainId);
  console.log("Block Number:", deploymentInfo.blockNumber);
  console.log("Timestamp:", deploymentInfo.timestamp);
  
  return deploymentInfo;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 