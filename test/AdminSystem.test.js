const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Karma Administrative Control System", function () {
  let karmaMultiSigManager;
  let karmaTimelock;
  let karmaToken;
  let owner, admin, proposer, executor, emergency, user1, user2;
  
  // Test addresses for multisig
  let multisigOwners;
  
  const EMERGENCY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE"));
  const OPERATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("OPERATOR_ROLE"));
  const PROPOSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PROPOSER_ROLE"));
  const EXECUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("EXECUTOR_ROLE"));
  const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";

  beforeEach(async function () {
    [owner, admin, proposer, executor, emergency, user1, user2] = await ethers.getSigners();
    
    // Create 5 addresses for multisig (using existing signers + generating more)
    multisigOwners = [admin.address, proposer.address, executor.address, emergency.address, user1.address];
    
    // Deploy KarmaToken first
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    karmaToken = await KarmaToken.deploy(owner.address);
    await karmaToken.waitForDeployment();
    
    // Deploy KarmaMultiSigManager
    const KarmaMultiSigManager = await ethers.getContractFactory("KarmaMultiSigManager");
    karmaMultiSigManager = await KarmaMultiSigManager.deploy(owner.address);
    await karmaMultiSigManager.waitForDeployment();
    
    // Deploy KarmaTimelock
    const KarmaTimelock = await ethers.getContractFactory("KarmaTimelock");
    karmaTimelock = await KarmaTimelock.deploy(
      owner.address,
      [proposer.address],
      [executor.address]
    );
    await karmaTimelock.waitForDeployment();
  });

  describe("KarmaMultiSigManager", function () {
    
    it("Should deploy with correct initial state", async function () {
      expect(await karmaMultiSigManager.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
      expect(await karmaMultiSigManager.hasRole(EMERGENCY_ROLE, owner.address)).to.be.true;
      expect(await karmaMultiSigManager.hasRole(OPERATOR_ROLE, owner.address)).to.be.true;
    });
    
    it("Should create multisig with 5 owners", async function () {
      // Set up Gnosis Safe addresses first
      await karmaMultiSigManager.setGnosisSafeAddresses(user1.address, user2.address);
      
      const saltNonce = 12345;
      const tx = await karmaMultiSigManager.createMultiSig(multisigOwners, saltNonce);
      const receipt = await tx.wait();
      
      // Check event emission
      const event = receipt.logs.find(log => 
        log.fragment && log.fragment.name === "MultiSigCreated"
      );
      expect(event).to.not.be.undefined;
      expect(event.args.owners).to.deep.equal(multisigOwners);
      expect(event.args.threshold).to.equal(3);
    });
    
    it("Should handle admin transfer workflow", async function () {
      const newAdmin = user1.address;
      
      // Initiate transfer
      await karmaMultiSigManager.initiateAdminTransfer(newAdmin);
      expect(await karmaMultiSigManager.pendingAdmin()).to.equal(newAdmin);
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60 + 1]); // 2 days + 1 second
      await ethers.provider.send("evm_mine");
      
      // Accept transfer
      await karmaMultiSigManager.connect(user1).acceptAdminTransfer();
      
      // Verify roles transferred
      expect(await karmaMultiSigManager.hasRole(DEFAULT_ADMIN_ROLE, newAdmin)).to.be.true;
      expect(await karmaMultiSigManager.pendingAdmin()).to.equal(ethers.ZeroAddress);
    });
  });

  describe("KarmaTimelock", function () {
    
    it("Should deploy with correct initial state", async function () {
      expect(await karmaTimelock.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
      expect(await karmaTimelock.hasRole(PROPOSER_ROLE, proposer.address)).to.be.true;
      expect(await karmaTimelock.hasRole(EXECUTOR_ROLE, executor.address)).to.be.true;
      
      // Check default delays
      expect(await karmaTimelock.getDelay(0)).to.equal(2 * 24 * 60 * 60); // STANDARD: 2 days
      expect(await karmaTimelock.getDelay(1)).to.equal(7 * 24 * 60 * 60); // CRITICAL: 7 days
      expect(await karmaTimelock.getDelay(2)).to.equal(1 * 60 * 60); // EMERGENCY: 1 hour
      expect(await karmaTimelock.getDelay(3)).to.equal(3 * 24 * 60 * 60); // GOVERNANCE: 3 days
    });
    
    it("Should queue operations correctly", async function () {
      const target = await karmaToken.getAddress();
      const value = 0;
      const data = karmaToken.interface.encodeFunctionData("pause");
      const operationType = 0; // STANDARD
      
      const tx = await karmaTimelock.connect(proposer).queueOperation(target, value, data, operationType);
      const receipt = await tx.wait();
      
      // Find the OperationQueued event
      const event = receipt.logs.find(log => 
        log.fragment && log.fragment.name === "OperationQueued"
      );
      
      expect(event).to.not.be.undefined;
      const operationId = event.args.id;
      
      // Check operation details
      const operation = await karmaTimelock.getOperation(operationId);
      expect(operation.target).to.equal(target);
      expect(operation.executed).to.be.false;
      expect(operation.cancelled).to.be.false;
    });
    
    it("Should enforce timelock delays", async function () {
      const target = await karmaToken.getAddress();
      const value = 0;
      const data = karmaToken.interface.encodeFunctionData("pause");
      const operationType = 0; // STANDARD (2 days)
      
      // Queue operation
      const tx = await karmaTimelock.connect(proposer).queueOperation(target, value, data, operationType);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment && log.fragment.name === "OperationQueued");
      const operationId = event.args.id;
      
      // Try to execute immediately (should fail)
      await expect(
        karmaTimelock.connect(executor).executeOperation(operationId)
      ).to.be.revertedWith("KarmaTimelock: Operation not ready for execution");
      
      // Check operation is not ready
      expect(await karmaTimelock.isOperationReady(operationId)).to.be.false;
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60 + 1]); // 2 days + 1 second
      await ethers.provider.send("evm_mine");
      
      // Now should be ready
      expect(await karmaTimelock.isOperationReady(operationId)).to.be.true;
    });
  });
}); 