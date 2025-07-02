const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ZeroGIntegration", function () {
    let zeroGIntegration;
    let zeroGOracle;
    let crossChainBridge;
    let karmaToken;
    let admin, user1, user2, aiProvider, validator;
    
    beforeEach(async function () {
        [admin, user1, user2, aiProvider, validator] = await ethers.getSigners();
        
        // Deploy KarmaToken mock
        const KarmaToken = await ethers.getContractFactory("MockERC20");
        karmaToken = await KarmaToken.deploy("Karma Token", "KARMA", ethers.parseEther("1000000000"));
        await karmaToken.waitForDeployment();
        
        // Deploy ZeroGIntegration
        const ZeroGIntegration = await ethers.getContractFactory("ZeroGIntegration");
        zeroGIntegration = await ZeroGIntegration.deploy(
            await karmaToken.getAddress(),
            admin.address
        );
        await zeroGIntegration.waitForDeployment();
        
        // Deploy ZeroGOracle
        const ZeroGOracle = await ethers.getContractFactory("ZeroGOracle");
        zeroGOracle = await ZeroGOracle.deploy(
            await karmaToken.getAddress(),
            admin.address,
            [validator.address]
        );
        await zeroGOracle.waitForDeployment();
        
        // Deploy CrossChainBridge
        const CrossChainBridge = await ethers.getContractFactory("CrossChainBridge");
        crossChainBridge = await CrossChainBridge.deploy(
            await karmaToken.getAddress(),
            admin.address,
            [validator.address]
        );
        await crossChainBridge.waitForDeployment();
        
        // Setup tokens for testing
        await karmaToken.mint(user1.address, ethers.parseEther("10000"));
        await karmaToken.mint(user2.address, ethers.parseEther("10000"));
        await karmaToken.mint(await zeroGIntegration.getAddress(), ethers.parseEther("100000"));
    });
    
    describe("ZeroGIntegration Contract", function () {
        it("should deploy with correct initial configuration", async function () {
            expect(await zeroGIntegration.karmaToken()).to.equal(await karmaToken.getAddress());
            expect(await zeroGIntegration.hasRole(await zeroGIntegration.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true;
        });
        
        it("should allow cross-chain message sending", async function () {
            const recipient = "0x742d35Cc6634C0532925a3b8D40b4ed7C3a9D0Cb";
            const data = ethers.encodeBytes32String("test message");
            const gasLimit = 100000;
            const fee = ethers.parseEther("0.01");
            
            const tx = await zeroGIntegration.connect(user1).sendCrossChainMessage(
                recipient,
                data,
                gasLimit,
                { value: fee }
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.eventName === "CrossChainMessageSent");
            
            expect(event).to.not.be.undefined;
            expect(event.args.sender).to.equal(user1.address);
            expect(event.args.recipient).to.equal(recipient);
        });
        
        it("should process AI inference requests", async function () {
            const aiModel = "stable-diffusion-v1.5";
            const inputData = "A beautiful sunset over mountains";
            const complexity = 100;
            
            await zeroGIntegration.addAIProvider(aiProvider.address, [aiModel]);
            
            const tx = await zeroGIntegration.connect(user1).requestAIInference(
                aiModel,
                inputData,
                complexity
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.eventName === "AIInferenceRequested");
            
            expect(event).to.not.be.undefined;
            expect(event.args.user).to.equal(user1.address);
            expect(event.args.aiModel).to.equal(aiModel);
        });
        
        it("should handle metadata storage", async function () {
            const contentHash = "QmXYZ123...";
            const size = 1024;
            const isPublic = true;
            const encryptionKey = "";
            
            const tx = await zeroGIntegration.connect(user1).storeMetadata(
                contentHash,
                size,
                isPublic,
                encryptionKey
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.eventName === "MetadataStored");
            
            expect(event).to.not.be.undefined;
            expect(event.args.owner).to.equal(user1.address);
            expect(event.args.size).to.equal(size);
        });
        
        it("should track usage and costs", async function () {
            const computeUnits = 100;
            const storageUsed = 1024;
            const dataTransferred = 512;
            const proof = "0x1234567890abcdef";
            
            await zeroGIntegration.grantRole(
                await zeroGIntegration.USAGE_REPORTER_ROLE(),
                admin.address
            );
            
            await zeroGIntegration.reportUsage(
                user1.address,
                computeUnits,
                storageUsed,
                dataTransferred,
                proof
            );
            
            const usage = await zeroGIntegration.getUserUsage(user1.address);
            expect(usage.totalCompute).to.equal(computeUnits);
            expect(usage.totalStorage).to.equal(storageUsed);
            expect(usage.totalTransfer).to.equal(dataTransferred);
        });
        
        it("should handle emergency pause", async function () {
            await zeroGIntegration.emergencyPause("Security concern");
            expect(await zeroGIntegration.paused()).to.be.true;
            
            await expect(
                zeroGIntegration.connect(user1).requestAIInference("test", "test", 100)
            ).to.be.revertedWith("Pausable: paused");
            
            await zeroGIntegration.emergencyUnpause();
            expect(await zeroGIntegration.paused()).to.be.false;
        });
    });
    
    describe("ZeroGOracle Contract", function () {
        it("should deploy with correct validator setup", async function () {
            expect(await zeroGOracle.isValidator(validator.address)).to.be.true;
            expect(await zeroGOracle.validators(0)).to.equal(validator.address);
        });
        
        it("should process usage reports", async function () {
            const user = user1.address;
            const computeUnits = 100;
            const storageUsed = 1024;
            const dataTransferred = 512;
            const proof = "0x1234567890abcdef";
            
            await zeroGOracle.grantRole(
                await zeroGOracle.USAGE_REPORTER_ROLE(),
                admin.address
            );
            
            const tx = await zeroGOracle.reportUsage(
                user,
                computeUnits,
                storageUsed,
                dataTransferred,
                proof
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.eventName === "UsageReported");
            
            expect(event).to.not.be.undefined;
            expect(event.args.user).to.equal(user);
            expect(event.args.computeUnits).to.equal(computeUnits);
        });
        
        it("should handle settlements", async function () {
            // First report usage
            await zeroGOracle.grantRole(
                await zeroGOracle.USAGE_REPORTER_ROLE(),
                admin.address
            );
            
            const tx1 = await zeroGOracle.reportUsage(
                user1.address,
                1000,
                2048,
                1024,
                "0x1234567890abcdef"
            );
            const receipt1 = await tx1.wait();
            const usageEvent = receipt1.logs.find(log => log.eventName === "UsageReported");
            const reportId = usageEvent.args.reportId;
            
            // Process settlement
            const tx2 = await zeroGOracle.processSettlement(
                user1.address,
                [reportId]
            );
            
            const receipt2 = await tx2.wait();
            const settlementEvent = receipt2.logs.find(log => log.eventName === "SettlementProcessed");
            
            expect(settlementEvent).to.not.be.undefined;
            expect(settlementEvent.args.user).to.equal(user1.address);
        });
        
        it("should update pricing", async function () {
            const computePrice = ethers.parseEther("0.001");
            const storagePrice = ethers.parseEther("0.0001");
            const transferPrice = ethers.parseEther("0.00001");
            
            await zeroGOracle.grantRole(
                await zeroGOracle.PRICE_ORACLE_ROLE(),
                admin.address
            );
            
            await zeroGOracle.updatePricing(
                computePrice,
                storagePrice,
                transferPrice,
                "0x1234567890abcdef"
            );
            
            const pricing = await zeroGOracle.currentPricing();
            expect(pricing.computePrice).to.equal(computePrice);
            expect(pricing.storagePrice).to.equal(storagePrice);
            expect(pricing.transferPrice).to.equal(transferPrice);
        });
    });
    
    describe("CrossChainBridge Contract", function () {
        beforeEach(async function () {
            // Add 0G chain as supported
            await crossChainBridge.addSupportedChain(
                12345, // 0G chain ID
                "0x742d35Cc6634C0532925a3b8D40b4ed7C3a9D0Cb",
                "https://rpc.0g.ai",
                200000
            );
        });
        
        it("should initialize bridge to 0G blockchain", async function () {
            const amount = ethers.parseEther("1000");
            const targetChainId = 12345;
            const targetAddress = "0x742d35Cc6634C0532925a3b8D40b4ed7C3a9D0Cb";
            
            await karmaToken.connect(user1).approve(await crossChainBridge.getAddress(), amount);
            
            const tx = await crossChainBridge.connect(user1).bridgeToZeroG(
                await karmaToken.getAddress(),
                amount,
                targetChainId,
                targetAddress
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.eventName === "AssetLocked");
            
            expect(event).to.not.be.undefined;
            expect(event.args.user).to.equal(user1.address);
            expect(event.args.amount).to.be.closeTo(amount * 99n / 100n, ethers.parseEther("1")); // After 1% fee
        });
        
        it("should require validator approval for bridge completion", async function () {
            const amount = ethers.parseEther("1000");
            const targetChainId = 12345;
            const targetAddress = "0x742d35Cc6634C0532925a3b8D40b4ed7C3a9D0Cb";
            
            await karmaToken.connect(user1).approve(await crossChainBridge.getAddress(), amount);
            
            const tx = await crossChainBridge.connect(user1).bridgeToZeroG(
                await karmaToken.getAddress(),
                amount,
                targetChainId,
                targetAddress
            );
            
            const receipt = await tx.wait();
            const event = receipt.logs.find(log => log.eventName === "AssetLocked");
            const bridgeId = event.args.bridgeId;
            
            // Validate bridge
            await crossChainBridge.connect(validator).validateBridge(bridgeId, true);
            
            const bridgeRequest = await crossChainBridge.getBridgeRequest(bridgeId);
            expect(bridgeRequest.validatorSignatures).to.equal(1);
        });
        
        it("should handle bridge statistics", async function () {
            const initialStats = await crossChainBridge.getBridgeStatistics();
            expect(initialStats.totalBridges).to.equal(0);
            
            const amount = ethers.parseEther("1000");
            await karmaToken.connect(user1).approve(await crossChainBridge.getAddress(), amount);
            
            await crossChainBridge.connect(user1).bridgeToZeroG(
                await karmaToken.getAddress(),
                amount,
                12345,
                "0x742d35Cc6634C0532925a3b8D40b4ed7C3a9D0Cb"
            );
            
            const newStats = await crossChainBridge.getBridgeStatistics();
            expect(newStats.totalBridges).to.equal(1);
            expect(newStats.totalBridgedAmount).to.be.gt(0);
        });
        
        it("should handle emergency pause", async function () {
            await crossChainBridge.emergencyPause();
            expect(await crossChainBridge.paused()).to.be.true;
            
            await expect(
                crossChainBridge.connect(user1).bridgeToZeroG(
                    await karmaToken.getAddress(),
                    ethers.parseEther("1000"),
                    12345,
                    "0x742d35Cc6634C0532925a3b8D40b4ed7C3a9D0Cb"
                )
            ).to.be.revertedWith("Pausable: paused");
        });
    });
    
    describe("Integration Tests", function () {
        it("should integrate all components for complete AI payment flow", async function () {
            // 1. Setup AI provider
            await zeroGIntegration.addAIProvider(aiProvider.address, ["stable-diffusion-v1.5"]);
            
            // 2. Request AI inference
            const tx1 = await zeroGIntegration.connect(user1).requestAIInference(
                "stable-diffusion-v1.5",
                "A beautiful sunset",
                100
            );
            const receipt1 = await tx1.wait();
            const requestEvent = receipt1.logs.find(log => log.eventName === "AIInferenceRequested");
            const requestId = requestEvent.args.requestId;
            
            // 3. Complete inference (simulated by AI provider)
            await zeroGIntegration.grantRole(
                await zeroGIntegration.AI_PROVIDER_ROLE(),
                aiProvider.address
            );
            
            await zeroGIntegration.connect(aiProvider).completeAIInference(
                requestId,
                "QmResultHash123...",
                50
            );
            
            // 4. Report usage to oracle
            await zeroGOracle.grantRole(
                await zeroGOracle.USAGE_REPORTER_ROLE(),
                admin.address
            );
            
            await zeroGOracle.reportUsage(
                user1.address,
                50,
                0,
                0,
                "0x1234567890abcdef"
            );
            
            // 5. Verify usage tracking
            const usage = await zeroGIntegration.getUserUsage(user1.address);
            expect(usage.totalCompute).to.be.gt(0);
        });
        
        it("should handle cross-chain metadata storage payment", async function () {
            // 1. Store metadata
            const tx1 = await zeroGIntegration.connect(user1).storeMetadata(
                "QmMetadataHash123...",
                2048,
                false,
                "encryptionKey123"
            );
            const receipt1 = await tx1.wait();
            const storageEvent = receipt1.logs.find(log => log.eventName === "MetadataStored");
            const dataId = storageEvent.args.dataId;
            
            // 2. Verify metadata integrity
            const isValid = await zeroGIntegration.verifyMetadataIntegrity(
                dataId,
                "QmMetadataHash123..."
            );
            expect(isValid).to.be.true;
            
            // 3. Report storage usage
            await zeroGOracle.grantRole(
                await zeroGOracle.USAGE_REPORTER_ROLE(),
                admin.address
            );
            
            await zeroGOracle.reportUsage(
                user1.address,
                0,
                2048,
                0,
                "0x1234567890abcdef"
            );
            
            const usage = await zeroGIntegration.getUserUsage(user1.address);
            expect(usage.totalStorage).to.equal(2048);
        });
    });
}); 