const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { generateMerkleTree, generateMerkleProof } = require("../utils/merkle-helpers");

describe("Stage 3.1: SaleManager Core Architecture Tests", function () {
    let saleManager, karmaToken, vestingVault;
    let deployer, admin, buyer1, buyer2, kycManager, whitelistManager;
    let merkleTree, merkleRoot;
    
    const PRIVATE_SALE_ALLOCATION = ethers.parseEther("100000000"); // 100M KARMA
    const PRE_SALE_ALLOCATION = ethers.parseEther("100000000");     // 100M KARMA  
    const PUBLIC_SALE_ALLOCATION = ethers.parseEther("150000000");  // 150M KARMA
    
    beforeEach(async function () {
        [deployer, admin, buyer1, buyer2, kycManager, whitelistManager] = await ethers.getSigners();
        
        // Deploy KarmaToken mock
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy();
        await karmaToken.waitForDeployment();
        
        // Deploy VestingVault mock
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress());
        await vestingVault.waitForDeployment();
        
        // Deploy SaleManager
        const SaleManager = await ethers.getContractFactory("SaleManager");
        saleManager = await SaleManager.deploy(
            await karmaToken.getAddress(),
            await vestingVault.getAddress(),
            admin.address
        );
        await saleManager.waitForDeployment();
        
        // Setup roles
        const MINTER_ROLE = await karmaToken.MINTER_ROLE();
        const VAULT_MANAGER_ROLE = await vestingVault.VAULT_MANAGER_ROLE();
        const KYC_MANAGER_ROLE = await saleManager.KYC_MANAGER_ROLE();
        const WHITELIST_MANAGER_ROLE = await saleManager.WHITELIST_MANAGER_ROLE();
        
        await karmaToken.grantRole(MINTER_ROLE, await saleManager.getAddress());
        await vestingVault.grantRole(VAULT_MANAGER_ROLE, await saleManager.getAddress());
        await saleManager.grantRole(KYC_MANAGER_ROLE, kycManager.address);
        await saleManager.grantRole(WHITELIST_MANAGER_ROLE, whitelistManager.address);
        
        // Create whitelist merkle tree
        const whitelist = [buyer1.address, buyer2.address];
        merkleTree = generateMerkleTree(whitelist);
        merkleRoot = merkleTree.getHexRoot();
    });
    
    describe("Phase Management System", function () {
        it("Should initialize with INACTIVE phase", async function () {
            const currentPhase = await saleManager.getCurrentPhase();
            expect(currentPhase).to.equal(0); // SalePhase.INACTIVE
        });
        
        it("Should configure private sale phase correctly", async function () {
            const startTime = (await time.latest()) + 3600; // 1 hour from now
            
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            
            const config = await saleManager.getPhaseConfig(1); // SalePhase.PRIVATE
            expect(config.startTime).to.equal(startTime);
            expect(config.isConfigured).to.be.true;
            expect(config.merkleRoot).to.equal(merkleRoot);
        });
        
        it("Should configure pre-sale phase correctly", async function () {
            const privateStartTime = (await time.latest()) + 3600;
            const preStartTime = privateStartTime + 86400 * 60; // 60 days later
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            
            const config = await saleManager.getPhaseConfig(2); // SalePhase.PRE_SALE
            expect(config.startTime).to.equal(preStartTime);
            expect(config.isConfigured).to.be.true;
        });
        
        it("Should configure public sale phase correctly", async function () {
            const privateStartTime = (await time.latest()) + 3600;
            const preStartTime = privateStartTime + 86400 * 60;
            const publicStartTime = preStartTime + 86400 * 30; // 30 days after pre-sale
            
            const liquidityConfig = {
                factory: admin.address,
                weth: admin.address,
                router: admin.address,
                ethAmount: ethers.parseEther("1000"),
                tokenAmount: ethers.parseEther("50000"),
                fee: 3000
            };
            
            await saleManager.configurePrivateSale(privateStartTime, merkleRoot);
            await saleManager.configurePreSale(preStartTime, merkleRoot);
            await saleManager.configurePublicSale(publicStartTime, liquidityConfig);
            
            const config = await saleManager.getPhaseConfig(3); // SalePhase.PUBLIC
            expect(config.startTime).to.equal(publicStartTime);
            expect(config.isConfigured).to.be.true;
        });
        
        it("Should prevent unauthorized phase configuration", async function () {
            const startTime = (await time.latest()) + 3600;
            
            await expect(
                saleManager.connect(buyer1).configurePrivateSale(startTime, merkleRoot)
            ).to.be.reverted;
        });
        
        it("Should transition phases correctly", async function () {
            const startTime = (await time.latest()) + 100;
            
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            
            // Start private sale
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
            
            expect(await saleManager.getCurrentPhase()).to.equal(1);
            
            // End current phase
            await saleManager.endCurrentPhase();
            expect(await saleManager.getCurrentPhase()).to.equal(0); // Back to INACTIVE
        });
    });
    
    describe("Purchase Processing Engine", function () {
        beforeEach(async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
            
            // Setup KYC
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1); // APPROVED
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
        });
        
        it("Should calculate token amounts correctly for private sale", async function () {
            const ethAmount = ethers.parseEther("25"); // 25 ETH
            const expectedTokens = await saleManager.calculateTokenAmount(ethAmount);
            
            // Private sale: $0.02 per token, assuming 1 ETH = $1000
            // 25 ETH = $25,000, $25,000 / $0.02 = 1,250,000 tokens
            expect(expectedTokens).to.equal(ethers.parseEther("1250000"));
        });
        
        it("Should validate purchase limits correctly", async function () {
            // Test minimum limit (25 ETH for private sale)
            const belowMin = ethers.parseEther("20");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: belowMin })
            ).to.be.revertedWith("Purchase amount below minimum");
            
            // Test maximum limit (200 ETH for private sale)
            const aboveMax = ethers.parseEther("250");
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: aboveMax })
            ).to.be.revertedWith("Purchase amount above maximum");
        });
        
        it("Should process valid purchases correctly", async function () {
            const purchaseAmount = ethers.parseEther("50"); // 50 ETH
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.emit(saleManager, "TokensPurchased")
            .withArgs(buyer1.address, purchaseAmount, expectedTokens, 1);
            
            const purchase = await saleManager.getPurchase(0);
            expect(purchase.buyer).to.equal(buyer1.address);
            expect(purchase.ethAmount).to.equal(purchaseAmount);
            expect(purchase.tokenAmount).to.equal(expectedTokens);
        });
        
        it("Should track allocations correctly", async function () {
            const purchaseAmount = ethers.parseEther("100"); // 100 ETH
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            const balanceBefore = await saleManager.getAllocationBalance(1); // Private sale
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            const balanceAfter = await saleManager.getAllocationBalance(1);
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            
            expect(balanceAfter).to.equal(balanceBefore.sub(expectedTokens));
        });
        
        it("Should prevent purchases when allocation is exhausted", async function () {
            // Simulate allocation exhaustion by setting a very low balance
            const smallAmount = ethers.parseEther("1");
            await saleManager.setAllocationBalance(1, smallAmount);
            
            const purchaseAmount = ethers.parseEther("50");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.be.revertedWith("Insufficient allocation remaining");
        });
    });
    
    describe("Whitelist and Access Control", function () {
        beforeEach(async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
        });
        
        it("Should validate merkle proofs correctly", async function () {
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            const invalidProof = generateMerkleProof(merkleTree, admin.address); // Not in whitelist
            
            // Setup KYC for both
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            const purchaseAmount = ethers.parseEther("50");
            
            // Valid proof should work
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.not.be.reverted;
            
            // Invalid proof should fail
            await expect(
                saleManager.connect(admin).purchaseTokens(invalidProof, { value: purchaseAmount })
            ).to.be.revertedWith("Invalid whitelist proof");
        });
        
        it("Should enforce KYC requirements", async function () {
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            const purchaseAmount = ethers.parseEther("50");
            
            // Without KYC approval
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.be.revertedWith("KYC not approved");
            
            // With KYC but without accreditation (for private sale)
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.be.revertedWith("Must be accredited investor");
            
            // With both KYC and accreditation
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.not.be.reverted;
        });
        
        it("Should allow whitelist management", async function () {
            const newWhitelist = [buyer1.address, buyer2.address, admin.address];
            const newMerkleTree = generateMerkleTree(newWhitelist);
            const newMerkleRoot = newMerkleTree.getHexRoot();
            
            await saleManager.connect(whitelistManager).updateWhitelist(1, newMerkleRoot);
            
            const config = await saleManager.getPhaseConfig(1);
            expect(config.merkleRoot).to.equal(newMerkleRoot);
        });
        
        it("Should prevent unauthorized whitelist updates", async function () {
            const newMerkleRoot = ethers.keccak256(ethers.toUtf8Bytes("new root"));
            
            await expect(
                saleManager.connect(buyer1).updateWhitelist(1, newMerkleRoot)
            ).to.be.reverted;
        });
    });
    
    describe("Emergency Controls", function () {
        beforeEach(async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
        });
        
        it("Should allow emergency pause", async function () {
            await saleManager.pause();
            expect(await saleManager.paused()).to.be.true;
            
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            const purchaseAmount = ethers.parseEther("50");
            
            await expect(
                saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount })
            ).to.be.revertedWith("Pausable: paused");
        });
        
        it("Should allow emergency unpause", async function () {
            await saleManager.pause();
            await saleManager.unpause();
            expect(await saleManager.paused()).to.be.false;
        });
        
        it("Should prevent unauthorized pause operations", async function () {
            await expect(
                saleManager.connect(buyer1).pause()
            ).to.be.reverted;
            
            await expect(
                saleManager.connect(buyer1).unpause()
            ).to.be.reverted;
        });
    });
    
    describe("Integration with External Contracts", function () {
        it("Should integrate correctly with KarmaToken", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
            
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            const purchaseAmount = ethers.parseEther("50");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            const tokenBalanceBefore = await karmaToken.balanceOf(buyer1.address);
            const expectedTokens = await saleManager.calculateTokenAmount(purchaseAmount);
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            // Tokens should be minted to buyer (private sale goes to vesting)
            const tokenBalanceAfter = await karmaToken.balanceOf(buyer1.address);
            expect(tokenBalanceAfter).to.be.gte(tokenBalanceBefore);
        });
        
        it("Should integrate correctly with VestingVault", async function () {
            const startTime = (await time.latest()) + 100;
            await saleManager.configurePrivateSale(startTime, merkleRoot);
            await time.increaseTo(startTime);
            await saleManager.startSalePhase(1, await saleManager.getPhaseConfig(1));
            
            await saleManager.connect(kycManager).updateKYCStatus(buyer1.address, 1);
            await saleManager.connect(kycManager).setAccreditedStatus(buyer1.address, true);
            
            const purchaseAmount = ethers.parseEther("50");
            const validProof = generateMerkleProof(merkleTree, buyer1.address);
            
            await saleManager.connect(buyer1).purchaseTokens(validProof, { value: purchaseAmount });
            
            // Verify vesting schedule creation
            const vestingSchedules = await vestingVault.getScheduleIds(buyer1.address);
            expect(vestingSchedules.length).to.be.gt(0);
        });
    });
}); 