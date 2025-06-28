const { ethers } = require("hardhat");

async function main() {
    console.log("🏛️  Deploying Stage 7.1: KarmaDAO Core Governance System");
    
    const [deployer, admin] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);
    console.log("Admin:", admin.address);

    // Deploy KarmaToken
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    const karmaToken = await KarmaToken.deploy(admin.address);
    console.log("✅ KarmaToken deployed at:", await karmaToken.getAddress());

    // Deploy KarmaStaking
    const KarmaStaking = await ethers.getContractFactory("KarmaStaking");
    const karmaStaking = await KarmaStaking.deploy(
        await karmaToken.getAddress(),
        admin.address, // treasury placeholder
        admin.address
    );
    console.log("✅ KarmaStaking deployed at:", await karmaStaking.getAddress());

    // Deploy TimelockController
    const TimelockController = await ethers.getContractFactory("TimelockController");
    const timelock = await TimelockController.deploy(
        3 * 24 * 3600, // 3 days
        [admin.address],
        [admin.address],
        admin.address
    );
    console.log("✅ TimelockController deployed at:", await timelock.getAddress());

    // Deploy KarmaGovernor
    const KarmaGovernor = await ethers.getContractFactory("KarmaGovernor");
    const karmaGovernor = await KarmaGovernor.deploy(
        await karmaToken.getAddress(),
        await timelock.getAddress(),
        await karmaStaking.getAddress(),
        admin.address
    );
    console.log("✅ KarmaGovernor deployed at:", await karmaGovernor.getAddress());

    // Grant roles
    const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
    const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
    
    await timelock.connect(admin).grantRole(PROPOSER_ROLE, await karmaGovernor.getAddress());
    await timelock.connect(admin).grantRole(EXECUTOR_ROLE, await karmaGovernor.getAddress());
    
    console.log("✅ Roles configured successfully");
    console.log("\n🎉 Stage 7.1 deployment completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }); 