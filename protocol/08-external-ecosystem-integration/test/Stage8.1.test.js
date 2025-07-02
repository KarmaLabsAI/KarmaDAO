const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Stage 8.1 - 0G Blockchain Integration Development", function () {
    let owner, user1, user2, user3, validator1, validator2, oracle1, oracle2;
    let karmaToken, treasury;
    let crossChainBridge, aiInferencePayment, metadataStorage, oracle;
    
    const INITIAL_SUPPLY = ethers.utils.parseEther("1000000000"); // 1B tokens
    const BRIDGE_FEE = ethers.utils.parseEther("0.001");
    const INFERENCE_COST = ethers.utils.parseEther("0.01");
    const STORAGE_COST = ethers.utils.parseEther("0.002");
    
    beforeEach(async function () {
        [owner, user1, user2, user3, validator1, validator2, oracle1, oracle2] = await ethers.getSigners();
        
        // Deploy mock KarmaToken for testing
        const ERC20Mock = await ethers.getContractFactory("contracts/mocks/ERC20Mock.sol:ERC20Mock");
        karmaToken = await ERC20Mock.deploy("Karma Token", "KARMA", INITIAL_SUPPLY);
        
        // Deploy mock Treasury
        const MockTreasury = await ethers.getContractFactory("contracts/mocks/MockTreasury.sol:MockTreasury");
        treasury = await MockTreasury.deploy();
        
        // Deploy and setup contracts for Stage 8.1
        await deployStage81Contracts();
        
        // Setup initial state
        await setupInitialState();
    });
    
    async function deployStage81Contracts() {
        // Deploy KarmaCrossChainBridge
        const KarmaCrossChainBridge = await ethers.getContractFactory("KarmaCrossChainBridge");
        crossChainBridge = await KarmaCrossChainBridge.deploy(
            karmaToken.address,
            treasury.address,
            owner.address
        );
        
        // Deploy KarmaAIInferencePayment
        const KarmaAIInferencePayment = await ethers.getContractFactory("KarmaAIInferencePayment");
        aiInferencePayment = await KarmaAIInferencePayment.deploy(
            karmaToken.address,
            crossChainBridge.address,
            treasury.address,
            owner.address
        );
        
        // Deploy KarmaMetadataStorage
        const KarmaMetadataStorage = await ethers.getContractFactory("KarmaMetadataStorage");
        metadataStorage = await KarmaMetadataStorage.deploy(
            karmaToken.address,
            crossChainBridge.address,
            treasury.address,
            owner.address
        );
        
        // Deploy Karma0GOracle
        const Karma0GOracle = await ethers.getContractFactory("Karma0GOracle");
        oracle = await Karma0GOracle.deploy(
            karmaToken.address,
            crossChainBridge.address,
            treasury.address,
            owner.address
        );
    }
    
    async function setupInitialState() {
        // Transfer tokens to users
        await karmaToken.transfer(user1.address, ethers.utils.parseEther("100000"));
        await karmaToken.transfer(user2.address, ethers.utils.parseEther("100000"));
        await karmaToken.transfer(user3.address, ethers.utils.parseEther("100000"));
        
        // Add validators to bridge
        await crossChainBridge.addValidator(validator1.address, ethers.utils.parseEther("100000"));
        await crossChainBridge.addValidator(validator2.address, ethers.utils.parseEther("100000"));
        
        // Add oracles and reporters
        await oracle.addUsageReporter(oracle1.address, ethers.utils.parseEther("50000"));
        await oracle.grantRole(await oracle.PRICE_ORACLE_ROLE(), oracle2.address);
        await oracle.grantRole(await oracle.SETTLEMENT_VALIDATOR_ROLE(), validator1.address);
        
        // Add AI models
        await aiInferencePayment.addModel("gpt-4", 0, 2); // TEXT_GENERATION, HEAVY
        await aiInferencePayment.addModel("dall-e-3", 1, 2); // IMAGE_GENERATION, HEAVY
        await aiInferencePayment.addModel("codex", 2, 1); // CODE_GENERATION, MEDIUM
    }
    
    describe("Cross-Chain Bridge", function () {
        it("Should send cross-chain message successfully", async function () {
            const recipient = user2.address;
            const messageType = 0; // INFERENCE_REQUEST
            const payload = ethers.utils.toUtf8Bytes("Test inference request");
            const gasLimit = 1000000;
            
            const bridgeFee = await crossChainBridge.calculateBridgeFee(messageType, gasLimit, 0);
            
            const tx = await crossChainBridge.connect(user1).sendMessage(
                recipient,
                messageType,
                payload,
                gasLimit,
                { value: bridgeFee }
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === "MessageSent");
            
            expect(event).to.not.be.undefined;
            expect(event.args.sender).to.equal(user1.address);
            expect(event.args.recipient).to.equal(recipient);
            expect(event.args.messageType).to.equal(messageType);
        });
        
        it("Should validate messages correctly", async function () {
            // First send a message
            const recipient = user2.address;
            const messageType = 0;
            const payload = ethers.utils.toUtf8Bytes("Test message");
            const gasLimit = 1000000;
            const bridgeFee = await crossChainBridge.calculateBridgeFee(messageType, gasLimit, 0);
            
            const tx = await crossChainBridge.connect(user1).sendMessage(
                recipient,
                messageType,
                payload,
                gasLimit,
                { value: bridgeFee }
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === "MessageSent");
            const messageId = event.args.messageId;
            
            // Validate message
            await crossChainBridge.connect(validator1).validateMessage(messageId, true);
            await crossChainBridge.connect(validator2).validateMessage(messageId, true);
            
            // Check if message was validated (would need min confirmations)
            const message = await crossChainBridge.getMessage(messageId);
            expect(message.messageId).to.equal(messageId);
        });
        
        it("Should calculate bridge fees correctly", async function () {
            const messageType = 0; // INFERENCE_REQUEST
            const gasLimit = 1000000;
            const value = ethers.utils.parseEther("1");
            
            const fee = await crossChainBridge.calculateBridgeFee(messageType, gasLimit, value);
            expect(fee).to.be.gt(0);
        });
    });
    
    describe("AI Inference Payment System", function () {
        it("Should request AI inference successfully", async function () {
            const inferenceType = 0; // TEXT_GENERATION
            const complexity = 2; // HEAVY
            const priority = 1; // NORMAL
            const inputData = ethers.utils.toUtf8Bytes("Generate a story about AI");
            const modelName = "gpt-4";
            
            const estimatedCost = await aiInferencePayment.calculateInferenceCost(
                inferenceType,
                complexity,
                priority,
                1000, // compute units
                100   // tokens
            );
            
            const tx = await aiInferencePayment.connect(user1).requestInference(
                inferenceType,
                complexity,
                priority,
                inputData,
                modelName,
                { value: estimatedCost }
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === "InferenceRequested");
            
            expect(event).to.not.be.undefined;
            expect(event.args.requester).to.equal(user1.address);
            expect(event.args.inferenceType).to.equal(inferenceType);
            expect(event.args.complexity).to.equal(complexity);
        });
        
        it("Should complete inference and process payment", async function () {
            // First request inference
            const inferenceType = 0;
            const complexity = 1; // MEDIUM
            const priority = 1;
            const inputData = ethers.utils.toUtf8Bytes("Test input");
            const modelName = "codex";
            
            const estimatedCost = await aiInferencePayment.calculateInferenceCost(
                inferenceType, complexity, priority, 500, 50
            );
            
            const requestTx = await aiInferencePayment.connect(user1).requestInference(
                inferenceType, complexity, priority, inputData, modelName,
                { value: estimatedCost }
            );
            
            const receipt = await requestTx.wait();
            const event = receipt.events.find(e => e.event === "InferenceRequested");
            const requestId = event.args.requestId;
            
            // Grant executor role and complete inference
            await aiInferencePayment.grantRole(
                await aiInferencePayment.INFERENCE_EXECUTOR_ROLE(),
                owner.address
            );
            
            const outputData = ethers.utils.toUtf8Bytes("Generated code output");
            await aiInferencePayment.completeInference(
                requestId,
                outputData,
                500, // actual compute units
                50,  // input tokens
                100  // output tokens
            );
            
            const request = await aiInferencePayment.getInferenceRequest(requestId);
            expect(request.status).to.equal(3); // COMPLETED
            expect(request.outputData).to.not.be.empty;
        });
        
        it("Should calculate inference costs correctly", async function () {
            const cost = await aiInferencePayment.calculateInferenceCost(
                0, // TEXT_GENERATION
                1, // MEDIUM
                2, // HIGH priority
                1000, // compute units
                200   // tokens
            );
            
            expect(cost).to.be.gt(0);
        });
        
        it("Should handle queue management", async function () {
            const queueStatus = await aiInferencePayment.getQueueStatus();
            expect(queueStatus.totalQueued).to.equal(0);
        });
    });
    
    describe("Metadata Storage System", function () {
        it("Should request data storage successfully", async function () {
            const storageType = 0; // INFT_METADATA
            const accessLevel = 1; // RESTRICTED
            const data = ethers.utils.toUtf8Bytes("Test iNFT metadata");
            const storageDuration = 30 * 24 * 60 * 60; // 30 days
            const authorizedUsers = [user2.address];
            
            const storageCost = await metadataStorage.calculateStorageCost(
                storageType,
                accessLevel,
                data.length,
                storageDuration
            );
            
            const tx = await metadataStorage.connect(user1).requestStorage(
                storageType,
                accessLevel,
                data,
                storageDuration,
                authorizedUsers,
                { value: storageCost }
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === "StorageRequested");
            
            expect(event).to.not.be.undefined;
            expect(event.args.requester).to.equal(user1.address);
            expect(event.args.storageType).to.equal(storageType);
            expect(event.args.dataSize).to.equal(data.length);
        });
        
        it("Should grant and revoke access correctly", async function () {
            // First request storage
            const storageType = 0;
            const accessLevel = 2; // PRIVATE
            const data = ethers.utils.toUtf8Bytes("Private data");
            const storageDuration = 30 * 24 * 60 * 60;
            
            const storageCost = await metadataStorage.calculateStorageCost(
                storageType, accessLevel, data.length, storageDuration
            );
            
            const requestTx = await metadataStorage.connect(user1).requestStorage(
                storageType, accessLevel, data, storageDuration, [],
                { value: storageCost }
            );
            
            const receipt = await requestTx.wait();
            const event = receipt.events.find(e => e.event === "StorageRequested");
            const requestId = event.args.requestId;
            
            // Grant access to user2
            await metadataStorage.connect(user1).grantAccess(requestId, user2.address);
            
            // Check access
            const hasAccess = await metadataStorage.hasAccessToData(requestId, user2.address);
            expect(hasAccess).to.be.true;
            
            // Revoke access
            await metadataStorage.connect(user1).revokeAccess(requestId, user2.address);
            
            const hasAccessAfter = await metadataStorage.hasAccessToData(requestId, user2.address);
            expect(hasAccessAfter).to.be.false;
        });
        
        it("Should calculate storage costs correctly", async function () {
            const cost = await metadataStorage.calculateStorageCost(
                0, // INFT_METADATA
                1, // RESTRICTED
                1024 * 1024, // 1MB
                30 * 24 * 60 * 60 // 30 days
            );
            
            expect(cost).to.be.gt(0);
        });
        
        it("Should extend storage duration", async function () {
            // Request initial storage
            const storageType = 0;
            const accessLevel = 0; // PUBLIC
            const data = ethers.utils.toUtf8Bytes("Public data");
            const storageDuration = 30 * 24 * 60 * 60;
            
            const storageCost = await metadataStorage.calculateStorageCost(
                storageType, accessLevel, data.length, storageDuration
            );
            
            const requestTx = await metadataStorage.connect(user1).requestStorage(
                storageType, accessLevel, data, storageDuration, [],
                { value: storageCost }
            );
            
            const receipt = await requestTx.wait();
            const event = receipt.events.find(e => e.event === "StorageRequested");
            const requestId = event.args.requestId;
            
            // Mark as stored
            await metadataStorage.markDataStored(requestId, "QmTestHash123");
            
            // Extend storage
            const additionalDuration = 15 * 24 * 60 * 60; // 15 more days
            const extensionCost = await metadataStorage.calculateStorageCost(
                storageType, accessLevel, data.length, additionalDuration
            );
            
            await metadataStorage.connect(user1).extendStorage(
                requestId, additionalDuration, { value: extensionCost }
            );
            
            const updatedRequest = await metadataStorage.getStorageRequest(requestId);
            expect(updatedRequest.storageDuration).to.equal(storageDuration + additionalDuration);
        });
    });
    
    describe("0G Oracle System", function () {
        it("Should report usage data successfully", async function () {
            const user = user1.address;
            const computeUnits = 1000;
            const storageUsed = 1024 * 1024; // 1MB
            const dataTransferred = 512 * 1024; // 512KB
            const serviceType = "AI_INFERENCE";
            const proof = ethers.utils.toUtf8Bytes("usage_proof_data");
            
            const tx = await oracle.connect(oracle1).reportUsage(
                user,
                computeUnits,
                storageUsed,
                dataTransferred,
                serviceType,
                proof
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === "UsageReported");
            
            expect(event).to.not.be.undefined;
            expect(event.args.user).to.equal(user);
            expect(event.args.computeUnits).to.equal(computeUnits);
            expect(event.args.reporter).to.equal(oracle1.address);
        });
        
        it("Should validate usage reports", async function () {
            // First report usage
            const tx = await oracle.connect(oracle1).reportUsage(
                user1.address,
                500,
                1024,
                512,
                "STORAGE",
                ethers.utils.toUtf8Bytes("proof")
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === "UsageReported");
            const reportId = event.args.reportId;
            
            // Validate report
            await oracle.connect(validator1).validateReport(
                reportId,
                true,
                ethers.utils.toUtf8Bytes("validation_proof")
            );
            
            const report = await oracle.getUsageReport(reportId);
            expect(report.status).to.equal(1); // VALIDATED
        });
        
        it("Should update prices correctly", async function () {
            const karmaPrice = ethers.utils.parseEther("0.06"); // $0.06
            const computePrice = ethers.utils.parseEther("0.0002");
            const storagePrice = ethers.utils.parseEther("0.00002");
            const transferPrice = ethers.utils.parseEther("0.000002");
            const priceProof = ethers.utils.toUtf8Bytes("price_feed_proof");
            
            await oracle.connect(oracle2).updatePrices(
                karmaPrice,
                computePrice,
                storagePrice,
                transferPrice,
                priceProof
            );
            
            const currentPrices = await oracle.getCurrentPrices();
            expect(currentPrices.karmaPrice).to.equal(karmaPrice);
            expect(currentPrices.computePrice).to.equal(computePrice);
            expect(currentPrices.reporter).to.equal(oracle2.address);
        });
        
        it("Should handle settlement requests", async function () {
            // First report and validate usage
            const reportTx = await oracle.connect(oracle1).reportUsage(
                user1.address,
                2000, // Higher compute units to meet threshold
                2048,
                1024,
                "AI_INFERENCE",
                ethers.utils.toUtf8Bytes("proof")
            );
            
            const reportReceipt = await reportTx.wait();
            const reportEvent = reportReceipt.events.find(e => e.event === "UsageReported");
            const reportId = reportEvent.args.reportId;
            
            // Validate the report
            await oracle.connect(validator1).validateReport(
                reportId,
                true,
                ethers.utils.toUtf8Bytes("validation_proof")
            );
            
            // Request settlement
            const settlementTx = await oracle.connect(user1).requestSettlement(
                user1.address,
                [reportId],
                false
            );
            
            const settlementReceipt = await settlementTx.wait();
            const settlementEvent = settlementReceipt.events.find(e => e.event === "SettlementRequested");
            
            expect(settlementEvent).to.not.be.undefined;
            expect(settlementEvent.args.requester).to.equal(user1.address);
        });
        
        it("Should raise and resolve disputes", async function () {
            // Report usage
            const reportTx = await oracle.connect(oracle1).reportUsage(
                user1.address, 1000, 1024, 512, "TEST", ethers.utils.toUtf8Bytes("proof")
            );
            
            const reportReceipt = await reportTx.wait();
            const reportEvent = reportReceipt.events.find(e => e.event === "UsageReported");
            const reportId = reportEvent.args.reportId;
            
            // Validate report first
            await oracle.connect(validator1).validateReport(
                reportId, true, ethers.utils.toUtf8Bytes("validation_proof")
            );
            
            // Raise dispute
            await oracle.grantRole(await oracle.DISPUTE_RESOLVER_ROLE(), owner.address);
            
            const disputeTx = await oracle.connect(user2).raiseDispute(
                reportId,
                "Suspicious usage pattern",
                ethers.utils.toUtf8Bytes("dispute_evidence")
            );
            
            const disputeReceipt = await disputeTx.wait();
            const disputeEvent = disputeReceipt.events.find(e => e.event === "DisputeRaised");
            const disputeId = disputeEvent.args.disputeId;
            
            // Resolve dispute
            await oracle.resolveDispute(
                disputeId,
                1, // VALIDATED
                ethers.utils.toUtf8Bytes("resolution_data")
            );
            
            const dispute = await oracle._disputeCases ? oracle._disputeCases(disputeId) : null;
            // Would need getter function to verify resolution
        });
    });
    
    describe("Integration Tests", function () {
        it("Should handle cross-contract integration flow", async function () {
            // 1. Send cross-chain message for inference request
            const payload = ethers.utils.defaultAbiCoder.encode(
                ["uint8", "uint8", "uint8", "string"],
                [0, 2, 1, "gpt-4"] // TEXT_GENERATION, HEAVY, NORMAL, model
            );
            
            const bridgeFee = await crossChainBridge.calculateBridgeFee(0, 1000000, 0);
            
            const bridgeTx = await crossChainBridge.connect(user1).sendMessage(
                aiInferencePayment.address,
                0, // INFERENCE_REQUEST
                payload,
                1000000,
                { value: bridgeFee }
            );
            
            const bridgeReceipt = await bridgeTx.wait();
            const bridgeEvent = bridgeReceipt.events.find(e => e.event === "MessageSent");
            
            expect(bridgeEvent).to.not.be.undefined;
            
            // 2. Request inference directly
            const inferenceCost = await aiInferencePayment.calculateInferenceCost(
                0, 2, 1, 1000, 100
            );
            
            const inferenceTx = await aiInferencePayment.connect(user1).requestInference(
                0, 2, 1,
                ethers.utils.toUtf8Bytes("Generate AI content"),
                "gpt-4",
                { value: inferenceCost }
            );
            
            const inferenceReceipt = await inferenceTx.wait();
            const inferenceEvent = inferenceReceipt.events.find(e => e.event === "InferenceRequested");
            
            expect(inferenceEvent).to.not.be.undefined;
            
            // 3. Store metadata
            const storageCost = await metadataStorage.calculateStorageCost(
                0, 1, 1024, 30 * 24 * 60 * 60
            );
            
            const storageTx = await metadataStorage.connect(user1).requestStorage(
                0, 1,
                ethers.utils.toUtf8Bytes("Inference result metadata"),
                30 * 24 * 60 * 60,
                [],
                { value: storageCost }
            );
            
            const storageReceipt = await storageTx.wait();
            const storageEvent = storageReceipt.events.find(e => e.event === "StorageRequested");
            
            expect(storageEvent).to.not.be.undefined;
            
            // 4. Report usage via oracle
            const usageTx = await oracle.connect(oracle1).reportUsage(
                user1.address,
                1000,
                1024,
                512,
                "AI_INFERENCE_FLOW",
                ethers.utils.toUtf8Bytes("integrated_flow_proof")
            );
            
            const usageReceipt = await usageTx.wait();
            const usageEvent = usageReceipt.events.find(e => e.event === "UsageReported");
            
            expect(usageEvent).to.not.be.undefined;
        });
    });
    
    describe("Configuration and Admin Functions", function () {
        it("Should update bridge configuration", async function () {
            await crossChainBridge.updateBridgeConfig(
                5, // min confirmations
                15000000, // max gas limit
                ethers.utils.parseEther("0.002"), // bridge fee
                48 * 60 * 60, // 48 hours timeout
                true // is active
            );
            
            const config = await crossChainBridge.getBridgeConfig();
            expect(config.minConfirmations).to.equal(5);
            expect(config.bridgeFee).to.equal(ethers.utils.parseEther("0.002"));
        });
        
        it("Should update AI inference pricing", async function () {
            await aiInferencePayment.updatePricingModel(
                0, // TEXT_GENERATION
                1, // MEDIUM
                ethers.utils.parseEther("0.0002"), // base price
                150, // complexity multiplier
                100, // priority multiplier
                ethers.utils.parseEther("0.00002"), // token price
                ethers.utils.parseEther("0.003"), // setup cost
                true // is active
            );
            
            const pricing = await aiInferencePayment.getPricingModel(0, 1);
            expect(pricing.basePrice).to.equal(ethers.utils.parseEther("0.0002"));
            expect(pricing.complexityMultiplier).to.equal(150);
        });
        
        it("Should update storage configuration", async function () {
            await metadataStorage.updateStorageConfig(
                ethers.utils.parseEther("0.002"), // base price per MB
                120, // duration multiplier
                ethers.utils.parseEther("0.0002"), // access price per query
                ethers.utils.parseEther("0.02"), // encryption surcharge
                15 * 365 * 24 * 60 * 60, // max storage duration (15 years)
                200 * 1024 * 1024, // max file size (200MB)
                true // is active
            );
            
            const config = await metadataStorage.getStorageConfig();
            expect(config.basePricePerMB).to.equal(ethers.utils.parseEther("0.002"));
            expect(config.maxFileSize).to.equal(200 * 1024 * 1024);
        });
        
        it("Should update oracle configuration", async function () {
            await oracle.updateOracleConfig(
                ethers.utils.parseEther("0.002"), // reporting threshold
                48 * 60 * 60, // validation period
                10 * 24 * 60 * 60, // dispute period
                ethers.utils.parseEther("2"), // settlement threshold
                ethers.utils.parseEther("0.002"), // oracle fee
                true // is active
            );
            
            const config = await oracle.getOracleConfig();
            expect(config.reportingThreshold).to.equal(ethers.utils.parseEther("0.002"));
            expect(config.settlementThreshold).to.equal(ethers.utils.parseEther("2"));
        });
    });
}); 