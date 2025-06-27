const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SaleManager", function () {
    let karmaToken, vestingVault, saleManager;
    let owner, treasury, user1, user2, kycManager, whitelistManager;
    
    const PRIVATE_SALE_PRICE = ethers.parseEther("0.02");
    
    beforeEach(async function () {
        [owner, treasury, user1, user2, kycManager, whitelistManager] = await ethers.getSigners();
        
        // Deploy contracts
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(owner.address);
        
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress(), owner.address);
        
        const SaleManager = await ethers.getContractFactory("SaleManager");
        saleManager = await SaleManager.deploy(
            await karmaToken.getAddress(),
            await vestingVault.getAddress(),
            treasury.address,
            owner.address
        );
        
        // Set up roles
        await saleManager.grantRole(await saleManager.KYC_MANAGER_ROLE(), kycManager.address);
        await saleManager.grantRole(await saleManager.WHITELIST_MANAGER_ROLE(), whitelistManager.address);
        await vestingVault.grantRole(await vestingVault.VESTING_MANAGER_ROLE(), await saleManager.getAddress());
        await karmaToken.setSaleManager(await saleManager.getAddress());
    });
    
    describe("Deployment", function () {
        it("Should set correct initial values", async function () {
            expect(await saleManager.getCurrentPhase()).to.equal(0); // NOT_STARTED
            expect(await saleManager.totalPurchases()).to.equal(0);
        });
        
        it("Should grant correct roles", async function () {
            const DEFAULT_ADMIN_ROLE = await saleManager.DEFAULT_ADMIN_ROLE();
            expect(await saleManager.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
        });
    });
    
    describe("Phase Management", function () {
        it("Should start private sale phase", async function () {
            const futureTime = Math.floor(Date.now() / 1000) + 3600;
            const config = {
                price: PRIVATE_SALE_PRICE,
                minPurchase: ethers.parseEther("25"),
                maxPurchase: ethers.parseEther("200"),
                hardCap: ethers.parseEther("2000"),
                tokenAllocation: ethers.parseEther("100000000"),
                startTime: futureTime,
                endTime: futureTime + 7200,
                whitelistRequired: false,
                kycRequired: false,
                merkleRoot: ethers.ZeroHash
            };
            
            await expect(saleManager.startSalePhase(1, config))
                .to.emit(saleManager, "SalePhaseStarted");
                
            expect(await saleManager.getCurrentPhase()).to.equal(1);
        });
        
        it("Should reject invalid configurations", async function () {
            const invalidConfig = {
                price: 0,
                minPurchase: ethers.parseEther("25"),
                maxPurchase: ethers.parseEther("200"),
                hardCap: ethers.parseEther("2000"),
                tokenAllocation: ethers.parseEther("100000000"),
                startTime: Math.floor(Date.now() / 1000) + 3600,
                endTime: Math.floor(Date.now() / 1000) + 7200,
                whitelistRequired: false,
                kycRequired: false,
                merkleRoot: ethers.ZeroHash
            };
            
            await expect(saleManager.startSalePhase(1, invalidConfig))
                .to.be.revertedWith("SaleManager: price must be positive");
        });
    });
    
    describe("KYC Management", function () {
        it("Should update KYC status", async function () {
            await expect(saleManager.connect(kycManager).updateKYCStatus(user1.address, 1))
                .to.emit(saleManager, "KYCStatusUpdated");
                
            const participant = await saleManager.getParticipant(user1.address);
            expect(participant.kycStatus).to.equal(1);
        });
        
        it("Should set accredited status", async function () {
            await saleManager.connect(kycManager).setAccreditedStatus(user1.address, true);
            const participant = await saleManager.getParticipant(user1.address);
            expect(participant.isAccredited).to.be.true;
        });
    });
    
    describe("Purchase Processing", function () {
        beforeEach(async function () {
            // Get the current block timestamp from the blockchain
            const latestBlock = await ethers.provider.getBlock('latest');
            const currentTime = latestBlock.timestamp;
            
            const config = {
                price: PRIVATE_SALE_PRICE,
                minPurchase: ethers.parseEther("1"),
                maxPurchase: ethers.parseEther("1000"),
                hardCap: ethers.parseEther("2000"),
                tokenAllocation: ethers.parseEther("100000000"),
                startTime: currentTime + 1000, // Start time 1000 seconds in future
                endTime: currentTime + 5000,   // End time 5000 seconds in future
                whitelistRequired: false,
                kycRequired: false,
                merkleRoot: ethers.ZeroHash
            };
            
            await saleManager.startSalePhase(1, config);
            
            // Wait for the phase to actually start
            await ethers.provider.send("evm_increaseTime", [1200]);
            await ethers.provider.send("evm_mine", []);
        });
        
        it("Should calculate token amount correctly", async function () {
            const ethAmount = ethers.parseEther("100");
            const expectedTokens = (ethAmount * ethers.parseEther("1")) / PRIVATE_SALE_PRICE;
            
            expect(await saleManager.calculateTokenAmount(ethAmount)).to.equal(expectedTokens);
        });
        
        it("Should process purchase successfully", async function () {
            // Set up user1 as accredited investor with KYC approval for private sale
            await saleManager.connect(kycManager).updateKYCStatus(user1.address, 1); // APPROVED
            await saleManager.connect(kycManager).setAccreditedStatus(user1.address, true);
            
            const purchaseAmount = ethers.parseEther("50");
            
            await expect(saleManager.connect(user1).purchaseTokens([], { value: purchaseAmount }))
                .to.emit(saleManager, "TokenPurchase");
                
            const purchase = await saleManager.getPurchase(0);
            expect(purchase.buyer).to.equal(user1.address);
            expect(purchase.ethAmount).to.equal(purchaseAmount);
        });
        
        it("Should enforce minimum purchase limits", async function () {
            await expect(saleManager.connect(user1).purchaseTokens([], { value: ethers.parseEther("0.5") }))
                .to.be.revertedWith("SaleManager: below minimum purchase");
        });
    });
    
    describe("Admin Functions", function () {
        it("Should pause and unpause", async function () {
            await saleManager.emergencyPause();
            expect(await saleManager.paused()).to.be.true;
            
            await saleManager.emergencyUnpause();
            expect(await saleManager.paused()).to.be.false;
        });
        
        it("Should require admin role for pause", async function () {
            await expect(saleManager.connect(user1).emergencyPause())
                .to.be.reverted;
        });
    });
});
