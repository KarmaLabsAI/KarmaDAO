// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IProductionDeploymentManager
 * @dev Interface for Production Deployment and Operations Management
 * Stage 9.2 - Production Deployment and Operations Requirements
 */
interface IProductionDeploymentManager {
    
    // ============ ENUMS ============
    
    enum DeploymentStage {
        PREPARATION,        // Pre-deployment preparation
        TESTNET,           // Testnet deployment
        STAGING,           // Staging deployment
        PRODUCTION,        // Production deployment
        ROLLBACK          // Rollback state
    }
    
    enum DeploymentStatus {
        PENDING,           // Deployment pending
        IN_PROGRESS,       // Currently deploying
        COMPLETED,         // Successfully deployed
        FAILED,            // Deployment failed
        ROLLED_BACK       // Deployment rolled back
    }
    
    enum ContractType {
        CORE_TOKEN,        // KarmaToken
        TREASURY,          // Treasury system
        GOVERNANCE,        // Governance contracts
        VESTING,           // Vesting systems
        SALE_MANAGER,      // Sale management
        PAYMASTER,         // Paymaster system
        TOKENOMICS,        // BuybackBurn, Revenue
        SECURITY,          // Security systems
        PLATFORMS,         // Platform integrations
        MONITORING        // Operations monitoring
    }
    
    enum ValidationStatus {
        NOT_VALIDATED,     // Not yet validated
        VALIDATING,        // Currently validating
        VALIDATED,         // Successfully validated
        VALIDATION_FAILED, // Validation failed
        NEEDS_RETRY       // Needs validation retry
    }
    
    // ============ STRUCTS ============
    
    struct DeploymentPlan {
        bytes32 planId;
        string name;
        DeploymentStage targetStage;
        ContractType[] contractTypes;
        address[] dependencies;
        uint256 estimatedGas;
        uint256 maxGasPrice;
        uint256 deadline;
        bool isActive;
        string description;
    }
    
    struct ContractDeployment {
        bytes32 deploymentId;
        ContractType contractType;
        string contractName;
        address deployedAddress;
        address implementationAddress;
        bytes32 bytecodeHash;
        uint256 gasUsed;
        uint256 blockNumber;
        uint256 timestamp;
        DeploymentStatus status;
        ValidationStatus validationStatus;
        string version;
        bool isUpgradeable;
    }
    
    struct DeploymentMetrics {
        uint256 totalDeployments;
        uint256 successfulDeployments;
        uint256 failedDeployments;
        uint256 rolledBackDeployments;
        uint256 totalGasUsed;
        uint256 averageGasPerDeployment;
        uint256 totalDeploymentTime;
        mapping(ContractType => uint256) deploymentsByType;
        mapping(DeploymentStage => uint256) deploymentsByStage;
    }
    
    struct RollbackPlan {
        bytes32 rollbackId;
        bytes32 targetDeploymentId;
        address[] contractsToRollback;
        address[] previousVersions;
        uint256 rollbackDeadline;
        bool isExecuted;
        string reason;
    }
    
    struct ValidationReport {
        bytes32 validationId;
        bytes32 deploymentId;
        address validator;
        ValidationStatus status;
        uint256 timestamp;
        string[] checksPassed;
        string[] checksFailed;
        uint256 gasEstimate;
        bool securityCleared;
        string report;
    }
    
    // ============ EVENTS ============
    
    event DeploymentPlanCreated(bytes32 indexed planId, string name, DeploymentStage stage);
    event DeploymentStarted(bytes32 indexed deploymentId, ContractType indexed contractType, string contractName);
    event DeploymentCompleted(bytes32 indexed deploymentId, address indexed contractAddress, uint256 gasUsed);
    event DeploymentFailed(bytes32 indexed deploymentId, string reason);
    event RollbackInitiated(bytes32 indexed rollbackId, bytes32 indexed targetDeploymentId, string reason);
    event RollbackCompleted(bytes32 indexed rollbackId, address[] rolledBackContracts);
    event ContractValidated(bytes32 indexed deploymentId, address indexed validator, bool success);
    event DeploymentStageAdvanced(DeploymentStage indexed fromStage, DeploymentStage indexed toStage);
    
    // ============ DEPLOYMENT PLANNING ============
    
    function createDeploymentPlan(
        string calldata name,
        DeploymentStage targetStage,
        ContractType[] calldata contractTypes,
        address[] calldata dependencies,
        uint256 estimatedGas,
        uint256 deadline,
        string calldata description
    ) external returns (bytes32 planId);
    
    function updateDeploymentPlan(bytes32 planId, DeploymentPlan calldata plan) external returns (bool success);
    function activateDeploymentPlan(bytes32 planId) external returns (bool success);
    function getDeploymentPlan(bytes32 planId) external view returns (DeploymentPlan memory plan);
    function getActiveDeploymentPlans() external view returns (DeploymentPlan[] memory plans);
    
    // ============ STAGED DEPLOYMENT ============
    
    function deployContract(
        ContractType contractType,
        string calldata contractName,
        bytes calldata bytecode,
        bytes calldata constructorArgs,
        string calldata version
    ) external returns (bytes32 deploymentId);
    
    function deployUpgradeableContract(
        ContractType contractType,
        string calldata contractName,
        bytes calldata implementationBytecode,
        bytes calldata proxyBytecode,
        bytes calldata initData,
        string calldata version
    ) external returns (bytes32 deploymentId);
    
    function batchDeploy(
        ContractType[] calldata contractTypes,
        string[] calldata contractNames,
        bytes[] calldata bytecodes,
        bytes[] calldata constructorArgs,
        string[] calldata versions
    ) external returns (bytes32[] memory deploymentIds);
    
    function advanceDeploymentStage(DeploymentStage newStage) external returns (bool success);
    function getCurrentDeploymentStage() external view returns (DeploymentStage stage);
    
    // ============ ROLLBACK MECHANISMS ============
    
    function createRollbackPlan(
        bytes32 targetDeploymentId,
        address[] calldata contractsToRollback,
        address[] calldata previousVersions,
        string calldata reason
    ) external returns (bytes32 rollbackId);
    
    function executeRollback(bytes32 rollbackId) external returns (bool success);
    function emergencyRollback(bytes32 deploymentId, string calldata reason) external returns (bool success);
    function getRollbackPlan(bytes32 rollbackId) external view returns (RollbackPlan memory plan);
    
    // ============ VALIDATION AND VERIFICATION ============
    
    function submitValidationReport(
        bytes32 deploymentId,
        string[] calldata checksPassed,
        string[] calldata checksFailed,
        uint256 gasEstimate,
        bool securityCleared,
        string calldata report
    ) external returns (bytes32 validationId);
    
    function approveDeployment(bytes32 deploymentId) external returns (bool success);
    function rejectDeployment(bytes32 deploymentId, string calldata reason) external returns (bool success);
    function getValidationReport(bytes32 validationId) external view returns (ValidationReport memory report);
    
    // ============ DEPLOYMENT MONITORING ============
    
    function getContractDeployment(bytes32 deploymentId) external view returns (ContractDeployment memory deployment);
    function getDeploymentsByType(ContractType contractType) external view returns (ContractDeployment[] memory deployments);
    function getDeploymentsByStage(DeploymentStage stage) external view returns (ContractDeployment[] memory deployments);
    function getDeploymentMetrics() external view returns (
        uint256 totalDeployments,
        uint256 successfulDeployments,
        uint256 failedDeployments,
        uint256 averageGasUsed
    );
    
    // ============ AUTOMATION AND SCRIPTS ============
    
    function executeDeploymentScript(
        string calldata scriptName,
        bytes calldata scriptData
    ) external returns (bool success);
    
    function scheduleAutomatedDeployment(
        bytes32 planId,
        uint256 executionTime
    ) external returns (bool success);
    
    function cancelScheduledDeployment(bytes32 planId) external returns (bool success);
} 