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
    
    it("Should set Gnosis Safe addresses", async function () {
      const mockFactory = user1.address;
      const mockMasterCopy = user2.address;
      
      await karmaMultiSigManager.setGnosisSafeAddresses(mockFactory, mockMasterCopy);
      
      const [factory, masterCopy, wallet] = await karmaMultiSigManager.getMultiSigInfo();
      expect(factory).to.equal(mockFactory);
      expect(masterCopy).to.equal(mockMasterCopy);
      expect(wallet).to.equal(ethers.ZeroAddress);
    });
    
    it("Should reject invalid Gnosis Safe addresses", async function () {
      await expect(
        karmaMultiSigManager.setGnosisSafeAddresses(ethers.ZeroAddress, user2.address)
      ).to.be.revertedWith("KarmaMultiSig: Invalid factory address");
      
      await expect(
        karmaMultiSigManager.setGnosisSafeAddresses(user1.address, ethers.ZeroAddress)
      ).to.be.revertedWith("KarmaMultiSig: Invalid master copy address");
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
      
      // Check state update
      const [factory, masterCopy, wallet] = await karmaMultiSigManager.getMultiSigInfo();
      expect(wallet).to.not.equal(ethers.ZeroAddress);
    });
    
    it("Should reject invalid multisig configurations", async function () {
      await karmaMultiSigManager.setGnosisSafeAddresses(user1.address, user2.address);
      
      // Wrong number of owners
      await expect(
        karmaMultiSigManager.createMultiSig([admin.address, proposer.address], 123)
      ).to.be.revertedWith("KarmaMultiSig: Must have exactly 5 owners");
      
      // Duplicate owners
      const duplicateOwners = [admin.address, admin.address, proposer.address, executor.address, emergency.address];
      await expect(
        karmaMultiSigManager.createMultiSig(duplicateOwners, 123)
      ).to.be.revertedWith("KarmaMultiSig: Duplicate owner address");
      
      // Zero address owner
      const invalidOwners = [ethers.ZeroAddress, admin.address, proposer.address, executor.address, emergency.address];
      await expect(
        karmaMultiSigManager.createMultiSig(invalidOwners, 123)
      ).to.be.revertedWith("KarmaMultiSig: Invalid owner address");
    });
    
    it("Should handle admin transfer workflow", async function () {
      const newAdmin = user1.address;
      
      // Initiate transfer
      await karmaMultiSigManager.initiateAdminTransfer(newAdmin);
      expect(await karmaMultiSigManager.pendingAdmin()).to.equal(newAdmin);
      
      // Check status
      const [pending, initiatedAt, timeRemaining, canAccept] = await karmaMultiSigManager.getAdminTransferStatus();
      expect(pending).to.equal(newAdmin);
      expect(initiatedAt).to.be.gt(0);
      expect(canAccept).to.be.false;
      
      // Try to accept too early (should fail)
      await expect(
        karmaMultiSigManager.connect(user1).acceptAdminTransfer()
      ).to.be.revertedWith("KarmaMultiSig: transfer delay not met");
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60 + 1]); // 2 days + 1 second
      await ethers.provider.send("evm_mine");
      
      // Accept transfer
      await karmaMultiSigManager.connect(user1).acceptAdminTransfer();
      
      // Verify roles transferred
      expect(await karmaMultiSigManager.hasRole(DEFAULT_ADMIN_ROLE, newAdmin)).to.be.true;
      expect(await karmaMultiSigManager.pendingAdmin()).to.equal(ethers.ZeroAddress);
    });
    
    it("Should allow admin transfer cancellation", async function () {
      const newAdmin = user1.address;
      
      await karmaMultiSigManager.initiateAdminTransfer(newAdmin);
      await karmaMultiSigManager.cancelAdminTransfer();
      
      expect(await karmaMultiSigManager.pendingAdmin()).to.equal(ethers.ZeroAddress);
    });
    
    it("Should handle emergency role management", async function () {
      // Grant emergency role to user1
      await karmaMultiSigManager.grantRole(EMERGENCY_ROLE, user1.address);
      
      // Emergency grant role
      await karmaMultiSigManager.connect(user1).emergencyGrantRole(OPERATOR_ROLE, user2.address);
      expect(await karmaMultiSigManager.hasRole(OPERATOR_ROLE, user2.address)).to.be.true;
      
      // Emergency revoke role
      await karmaMultiSigManager.connect(user1).emergencyRevokeRole(OPERATOR_ROLE, user2.address);
      expect(await karmaMultiSigManager.hasRole(OPERATOR_ROLE, user2.address)).to.be.false;
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
      expect(operation.value).to.equal(value);
      expect(operation.data).to.equal(data);
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
      
      // Execute operation (this would fail because we can't actually call pause on the token from timelock)
      // But we can verify the timelock validation passes
      await expect(
        karmaTimelock.connect(executor).executeOperation(operationId)
      ).to.be.revertedWith("KarmaTimelock: Operation execution failed");
    });
    
    it("Should allow operation cancellation", async function () {
      const target = await karmaToken.getAddress();
      const value = 0;
      const data = karmaToken.interface.encodeFunctionData("pause");
      const operationType = 0; // STANDARD
      
      // Queue operation
      const tx = await karmaTimelock.connect(proposer).queueOperation(target, value, data, operationType);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment && log.fragment.name === "OperationQueued");
      const operationId = event.args.id;
      
      // Cancel operation
      await karmaTimelock.cancelOperation(operationId);
      
      // Check operation is cancelled
      const operation = await karmaTimelock.getOperation(operationId);
      expect(operation.cancelled).to.be.true;
      
      // Try to execute cancelled operation (should fail)
      await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");
      
      await expect(
        karmaTimelock.connect(executor).executeOperation(operationId)
      ).to.be.revertedWith("KarmaTimelock: Operation was cancelled");
    });
    
    it("Should handle emergency execution", async function () {
      const target = await karmaToken.getAddress();
      const value = 0;
      const data = karmaToken.interface.encodeFunctionData("pause");
      const operationType = 1; // CRITICAL (7 days normally)
      
      // Queue operation
      const tx = await karmaTimelock.connect(proposer).queueOperation(target, value, data, operationType);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment && log.fragment.name === "OperationQueued");
      const operationId = event.args.id;
      
      // Emergency execute without waiting (should fail because we don't have emergency role)
      await expect(
        karmaTimelock.connect(executor).emergencyExecute(operationId)
      ).to.be.revertedWith("KarmaTimelock: caller is not emergency role");
      
      // Grant emergency role and try again
      await karmaTimelock.grantRole(ethers.keccak256(ethers.toUtf8Bytes("EMERGENCY_ROLE")), executor.address);
      
      // This would fail on execution but pass timelock validation
      await expect(
        karmaTimelock.connect(executor).emergencyExecute(operationId)
      ).to.be.revertedWith("KarmaTimelock: Emergency execution failed");
    });
    
    it("Should allow delay updates", async function () {
      const operationType = 0; // STANDARD
      const newDelay = 3 * 24 * 60 * 60; // 3 days
      
      await karmaTimelock.updateDelay(operationType, newDelay);
      expect(await karmaTimelock.getDelay(operationType)).to.equal(newDelay);
    });
    
    it("Should reject invalid delay values", async function () {
      const operationType = 0; // STANDARD
      const tooShort = 30 * 60; // 30 minutes (less than 1 hour minimum)
      const tooLong = 31 * 24 * 60 * 60; // 31 days (more than 30 day maximum)
      
      await expect(
        karmaTimelock.updateDelay(operationType, tooShort)
      ).to.be.revertedWith("KarmaTimelock: Invalid delay");
      
      await expect(
        karmaTimelock.updateDelay(operationType, tooLong)
      ).to.be.revertedWith("KarmaTimelock: Invalid delay");
    });
  });

  describe("Integration Tests", function () {
    
    it("Should work together for secure admin transitions", async function () {
      // 1. Create multisig through MultiSigManager
      await karmaMultiSigManager.setGnosisSafeAddresses(user1.address, user2.address);
      const createTx = await karmaMultiSigManager.createMultiSig(multisigOwners, 12345);
      const createReceipt = await createTx.wait();
      
      // Extract multisig address from event
      const createEvent = createReceipt.logs.find(log => 
        log.fragment && log.fragment.name === "MultiSigCreated"
      );
      const multisigAddress = createEvent.args.multisig;
      
      // 2. Queue admin transfer through Timelock
      const target = await karmaMultiSigManager.getAddress();
      const value = 0;
      const data = karmaMultiSigManager.interface.encodeFunctionData("initiateAdminTransfer", [multisigAddress]);
      const operationType = 1; // CRITICAL
      
      const tx = await karmaTimelock.connect(proposer).queueOperation(target, value, data, operationType);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => log.fragment && log.fragment.name === "OperationQueued");
      const operationId = event.args.id;
      
      // 3. Wait for timelock delay
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]); // 7 days + 1 second
      await ethers.provider.send("evm_mine");
      
      // 4. This would execute the admin transfer if the contracts were properly integrated
      // For now, we just verify the timelock mechanics work
      expect(await karmaTimelock.isOperationReady(operationId)).to.be.true;
    });
  });
}); 