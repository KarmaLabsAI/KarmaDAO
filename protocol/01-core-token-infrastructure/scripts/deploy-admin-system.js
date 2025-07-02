const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying Administrative Control System with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy KarmaMultiSigManager
  console.log("\n=== Deploying KarmaMultiSigManager ===");
  const KarmaMultiSigManager = await ethers.getContractFactory("KarmaMultiSigManager");
  const karmaMultiSigManager = await KarmaMultiSigManager.deploy(deployer.address);
  await karmaMultiSigManager.waitForDeployment();
  
  const multiSigManagerAddress = await karmaMultiSigManager.getAddress();
  console.log("KarmaMultiSigManager deployed to:", multiSigManagerAddress);
  
  // Deploy KarmaTimelock with initial roles
  console.log("\n=== Deploying KarmaTimelock ===");
  const proposers = [deployer.address]; // Initially deployer can propose
  const executors = [deployer.address]; // Initially deployer can execute
  
  const KarmaTimelock = await ethers.getContractFactory("KarmaTimelock");
  const karmaTimelock = await KarmaTimelock.deploy(
    deployer.address,
    proposers,
    executors
  );
  await karmaTimelock.waitForDeployment();
  
  const timelockAddress = await karmaTimelock.getAddress();
  console.log("KarmaTimelock deployed to:", timelockAddress);
  
  // Verify deployments
  console.log("\n=== Deployment Verification ===");
  
  // Verify MultiSigManager
  console.log("MultiSigManager Admin:", await karmaMultiSigManager.hasRole(await karmaMultiSigManager.DEFAULT_ADMIN_ROLE(), deployer.address));
  console.log("MultiSigManager Emergency Role:", await karmaMultiSigManager.hasRole(await karmaMultiSigManager.EMERGENCY_ROLE(), deployer.address));
  console.log("MultiSigManager Operator Role:", await karmaMultiSigManager.hasRole(await karmaMultiSigManager.OPERATOR_ROLE(), deployer.address));
  
  // Verify Timelock
  console.log("Timelock Admin:", await karmaTimelock.hasRole(await karmaTimelock.DEFAULT_ADMIN_ROLE(), deployer.address));
  console.log("Timelock Proposer:", await karmaTimelock.hasRole(await karmaTimelock.PROPOSER_ROLE(), deployer.address));
  console.log("Timelock Executor:", await karmaTimelock.hasRole(await karmaTimelock.EXECUTOR_ROLE(), deployer.address));
  console.log("Timelock Emergency:", await karmaTimelock.hasRole(await karmaTimelock.EMERGENCY_ROLE(), deployer.address));
  
  // Display operation delays
  console.log("\n=== Timelock Operation Delays ===");
  console.log("Standard Operations:", (await karmaTimelock.getDelay(0)).toString(), "seconds");
  console.log("Critical Operations:", (await karmaTimelock.getDelay(1)).toString(), "seconds"); 
  console.log("Emergency Operations:", (await karmaTimelock.getDelay(2)).toString(), "seconds");
  console.log("Governance Operations:", (await karmaTimelock.getDelay(3)).toString(), "seconds");
  
  // Save deployment info
  const network = await ethers.provider.getNetwork();
  const deploymentInfo = {
    networkName: network.name,
    chainId: network.chainId,
    karmaMultiSigManager: multiSigManagerAddress,
    karmaTimelock: timelockAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    blockNumber: await ethers.provider.getBlockNumber()
  };
  
  console.log("\n=== Deployment Complete ===");
  console.log("Network:", network.name);
  console.log("Chain ID:", network.chainId);
  console.log("Block Number:", deploymentInfo.blockNumber);
  console.log("Timestamp:", deploymentInfo.timestamp);
  
  console.log("\n=== Next Steps ===");
  console.log("1. Set up Gnosis Safe factory addresses in MultiSigManager");
  console.log("2. Create 3-of-5 multisig wallet");
  console.log("3. Transfer admin roles from deployer to multisig");
  console.log("4. Test timelock operations with appropriate delays");
  console.log("5. Configure emergency response procedures");
  
  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 