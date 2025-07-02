const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("KarmaToken", function () {
  let karmaToken;
  let owner, admin, minter, pauser, user1, user2, treasury, saleManager;
  
  const MAX_SUPPLY = ethers.parseEther("1000000000"); // 1 billion tokens
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const PAUSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PAUSER_ROLE"));
  const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";

  beforeEach(async function () {
    [owner, admin, minter, pauser, user1, user2, treasury, saleManager] = await ethers.getSigners();
    
    const KarmaToken = await ethers.getContractFactory("KarmaToken");
    karmaToken = await KarmaToken.deploy(admin.address);
    await karmaToken.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await karmaToken.name()).to.equal("Karma Token");
      expect(await karmaToken.symbol()).to.equal("KARMA");
    });

    it("Should set the correct decimals", async function () {
      expect(await karmaToken.decimals()).to.equal(18);
    });

    it("Should have zero initial supply", async function () {
      expect(await karmaToken.totalSupply()).to.equal(0);
    });

    it("Should set correct max supply", async function () {
      expect(await karmaToken.MAX_SUPPLY()).to.equal(MAX_SUPPLY);
    });

    it("Should grant admin roles to initial admin", async function () {
      expect(await karmaToken.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
      expect(await karmaToken.hasRole(MINTER_ROLE, admin.address)).to.be.true;
      expect(await karmaToken.hasRole(PAUSER_ROLE, admin.address)).to.be.true;
    });
  });

  describe("Role Management", function () {
    it("Should allow admin to grant roles", async function () {
      await karmaToken.connect(admin).grantRole(MINTER_ROLE, minter.address);
      expect(await karmaToken.hasRole(MINTER_ROLE, minter.address)).to.be.true;
    });

    it("Should allow admin to revoke roles", async function () {
      await karmaToken.connect(admin).grantRole(MINTER_ROLE, minter.address);
      await karmaToken.connect(admin).revokeRole(MINTER_ROLE, minter.address);
      expect(await karmaToken.hasRole(MINTER_ROLE, minter.address)).to.be.false;
    });

    it("Should not allow non-admin to grant roles", async function () {
      await expect(
        karmaToken.connect(user1).grantRole(MINTER_ROLE, user2.address)
      ).to.be.reverted;
    });
  });

  describe("Minting", function () {
    beforeEach(async function () {
      await karmaToken.connect(admin).grantRole(MINTER_ROLE, minter.address);
    });

    it("Should allow minter to mint tokens", async function () {
      const amount = ethers.parseEther("1000");
      await karmaToken.connect(minter).mint(user1.address, amount);
      
      expect(await karmaToken.balanceOf(user1.address)).to.equal(amount);
      expect(await karmaToken.totalSupply()).to.equal(amount);
    });

    it("Should emit TokensMinted event", async function () {
      const amount = ethers.parseEther("1000");
      await expect(karmaToken.connect(minter).mint(user1.address, amount))
        .to.emit(karmaToken, "TokensMinted")
        .withArgs(user1.address, amount, minter.address);
    });

    it("Should not allow non-minter to mint", async function () {
      const amount = ethers.parseEther("1000");
      await expect(
        karmaToken.connect(user1).mint(user1.address, amount)
      ).to.be.reverted;
    });

    it("Should not allow minting to zero address", async function () {
      const amount = ethers.parseEther("1000");
      await expect(
        karmaToken.connect(minter).mint(ethers.ZeroAddress, amount)
      ).to.be.revertedWith("KarmaToken: Cannot mint to zero address");
    });

    it("Should not allow minting zero amount", async function () {
      await expect(
        karmaToken.connect(minter).mint(user1.address, 0)
      ).to.be.revertedWith("KarmaToken: Amount must be greater than zero");
    });

    it("Should not allow minting beyond max supply", async function () {
      const exceedingAmount = MAX_SUPPLY + ethers.parseEther("1");
      await expect(
        karmaToken.connect(minter).mint(user1.address, exceedingAmount)
      ).to.be.revertedWith("KarmaToken: Exceeds maximum supply");
    });

    it("Should not allow minting when paused", async function () {
      await karmaToken.connect(admin).grantRole(PAUSER_ROLE, pauser.address);
      await karmaToken.connect(pauser).pause();
      
      const amount = ethers.parseEther("1000");
      await expect(
        karmaToken.connect(minter).mint(user1.address, amount)
      ).to.be.reverted;
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      await karmaToken.connect(admin).grantRole(MINTER_ROLE, minter.address);
      const amount = ethers.parseEther("1000");
      await karmaToken.connect(minter).mint(user1.address, amount);
    });

    it("Should allow user to burn their tokens", async function () {
      const burnAmount = ethers.parseEther("500");
      await karmaToken.connect(user1).burn(burnAmount);
      
      expect(await karmaToken.balanceOf(user1.address)).to.equal(ethers.parseEther("500"));
      expect(await karmaToken.totalSupply()).to.equal(ethers.parseEther("500"));
    });

    it("Should emit TokensBurned event", async function () {
      const burnAmount = ethers.parseEther("500");
      await expect(karmaToken.connect(user1).burn(burnAmount))
        .to.emit(karmaToken, "TokensBurned")
        .withArgs(user1.address, burnAmount);
    });

    it("Should allow burnFrom with allowance", async function () {
      const burnAmount = ethers.parseEther("500");
      await karmaToken.connect(user1).approve(user2.address, burnAmount);
      await karmaToken.connect(user2).burnFrom(user1.address, burnAmount);
      
      expect(await karmaToken.balanceOf(user1.address)).to.equal(ethers.parseEther("500"));
    });

    it("Should not allow burning when paused", async function () {
      await karmaToken.connect(admin).grantRole(PAUSER_ROLE, pauser.address);
      await karmaToken.connect(pauser).pause();
      
      const burnAmount = ethers.parseEther("500");
      await expect(
        karmaToken.connect(user1).burn(burnAmount)
      ).to.be.reverted;
    });
  });

  describe("Pausable", function () {
    beforeEach(async function () {
      await karmaToken.connect(admin).grantRole(PAUSER_ROLE, pauser.address);
    });

    it("Should allow pauser to pause", async function () {
      await karmaToken.connect(pauser).pause();
      expect(await karmaToken.paused()).to.be.true;
    });

    it("Should emit EmergencyPause event", async function () {
      await expect(karmaToken.connect(pauser).pause())
        .to.emit(karmaToken, "EmergencyPause")
        .withArgs(pauser.address);
    });

    it("Should allow pauser to unpause", async function () {
      await karmaToken.connect(pauser).pause();
      await karmaToken.connect(pauser).unpause();
      expect(await karmaToken.paused()).to.be.false;
    });

    it("Should emit EmergencyUnpause event", async function () {
      await karmaToken.connect(pauser).pause();
      await expect(karmaToken.connect(pauser).unpause())
        .to.emit(karmaToken, "EmergencyUnpause")
        .withArgs(pauser.address);
    });

    it("Should not allow non-pauser to pause", async function () {
      await expect(
        karmaToken.connect(user1).pause()
      ).to.be.reverted;
    });

    it("Should prevent transfers when paused", async function () {
      // First mint some tokens and setup transfer
      await karmaToken.connect(admin).grantRole(MINTER_ROLE, minter.address);
      await karmaToken.connect(minter).mint(user1.address, ethers.parseEther("1000"));
      
      // Pause the contract
      await karmaToken.connect(pauser).pause();
      
      // Try to transfer - should fail
      await expect(
        karmaToken.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.reverted;
    });
  });

  describe("Integration Contract Setters", function () {
    it("Should allow admin to set VestingVault", async function () {
      await expect(karmaToken.connect(admin).setVestingVault(treasury.address))
        .to.emit(karmaToken, "VestingVaultSet")
        .withArgs(ethers.ZeroAddress, treasury.address);
      
      expect(await karmaToken.vestingVault()).to.equal(treasury.address);
    });

    it("Should allow admin to set Treasury", async function () {
      await expect(karmaToken.connect(admin).setTreasury(treasury.address))
        .to.emit(karmaToken, "TreasurySet")
        .withArgs(ethers.ZeroAddress, treasury.address);
      
      expect(await karmaToken.treasury()).to.equal(treasury.address);
    });

    it("Should allow admin to set SaleManager and grant MINTER_ROLE", async function () {
      await expect(karmaToken.connect(admin).setSaleManager(saleManager.address))
        .to.emit(karmaToken, "SaleManagerSet")
        .withArgs(ethers.ZeroAddress, saleManager.address);
      
      expect(await karmaToken.saleManager()).to.equal(saleManager.address);
      expect(await karmaToken.hasRole(MINTER_ROLE, saleManager.address)).to.be.true;
    });

    it("Should revoke MINTER_ROLE from old SaleManager when setting new one", async function () {
      // Set first sale manager
      await karmaToken.connect(admin).setSaleManager(saleManager.address);
      expect(await karmaToken.hasRole(MINTER_ROLE, saleManager.address)).to.be.true;
      
      // Set new sale manager
      await karmaToken.connect(admin).setSaleManager(user1.address);
      expect(await karmaToken.hasRole(MINTER_ROLE, saleManager.address)).to.be.false;
      expect(await karmaToken.hasRole(MINTER_ROLE, user1.address)).to.be.true;
    });

    it("Should not allow non-admin to set integration contracts", async function () {
      await expect(
        karmaToken.connect(user1).setVestingVault(treasury.address)
      ).to.be.reverted;
    });

    it("Should not allow setting zero address for integration contracts", async function () {
      await expect(
        karmaToken.connect(admin).setVestingVault(ethers.ZeroAddress)
      ).to.be.revertedWith("KarmaToken: Invalid VestingVault address");
    });
  });

  describe("Paymaster Integration", function () {
    beforeEach(async function () {
      await karmaToken.connect(admin).setPaymaster(user1.address);
    });

    it("Should return true for sponsored operations from paymaster", async function () {
      const transferSig = "0xa9059cbb"; // transfer(address,uint256)
      const result = await karmaToken.connect(user1).isOperationSponsored(user2.address, transferSig);
      expect(result).to.be.true;
    });

    it("Should return false for non-sponsored operations", async function () {
      const randomSig = "0x12345678";
      const result = await karmaToken.connect(user1).isOperationSponsored(user2.address, randomSig);
      expect(result).to.be.false;
    });

    it("Should return false when called by non-paymaster", async function () {
      const transferSig = "0xa9059cbb";
      const result = await karmaToken.connect(user2).isOperationSponsored(user2.address, transferSig);
      expect(result).to.be.false;
    });
  });

  describe("View Functions", function () {
    it("Should return remaining supply", async function () {
      expect(await karmaToken.remainingSupply()).to.equal(MAX_SUPPLY);
      
      // Mint some tokens
      await karmaToken.connect(admin).grantRole(MINTER_ROLE, minter.address);
      const mintAmount = ethers.parseEther("1000");
      await karmaToken.connect(minter).mint(user1.address, mintAmount);
      
      expect(await karmaToken.remainingSupply()).to.equal(MAX_SUPPLY - mintAmount);
    });

    it("Should return integration contracts", async function () {
      await karmaToken.connect(admin).setVestingVault(user1.address);
      await karmaToken.connect(admin).setTreasury(user2.address);
      
      const [vestingVault, treasury, buybackBurn, paymaster, saleManager] = 
        await karmaToken.getIntegrationContracts();
      
      expect(vestingVault).to.equal(user1.address);
      expect(treasury).to.equal(user2.address);
      expect(buybackBurn).to.equal(ethers.ZeroAddress);
      expect(paymaster).to.equal(ethers.ZeroAddress);
      expect(saleManager).to.equal(ethers.ZeroAddress);
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow admin to recover accidentally sent tokens", async function () {
      // Deploy a mock ERC20 token for testing
      const MockToken = await ethers.getContractFactory("KarmaToken");
      const mockToken = await MockToken.deploy(admin.address);
      
      // Grant minter role and mint some tokens to the KarmaToken contract
      await mockToken.connect(admin).grantRole(MINTER_ROLE, admin.address);
      await mockToken.connect(admin).mint(await karmaToken.getAddress(), ethers.parseEther("1000"));
      
      // Recover the tokens
      const initialBalance = await mockToken.balanceOf(admin.address);
      await karmaToken.connect(admin).emergencyTokenRecovery(await mockToken.getAddress(), ethers.parseEther("1000"));
      
      expect(await mockToken.balanceOf(admin.address)).to.equal(initialBalance + ethers.parseEther("1000"));
    });

    it("Should not allow recovering KARMA tokens", async function () {
      await expect(
        karmaToken.connect(admin).emergencyTokenRecovery(await karmaToken.getAddress(), ethers.parseEther("1000"))
      ).to.be.revertedWith("KarmaToken: Cannot recover KARMA tokens");
    });

    it("Should not allow non-admin to recover tokens", async function () {
      await expect(
        karmaToken.connect(user1).emergencyTokenRecovery(user2.address, ethers.parseEther("1000"))
      ).to.be.reverted;
    });
  });
}); 