// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISystemInitializationManager
 * @dev Interface for System Initialization and Configuration Management
 * Stage 9.2 - System Initialization Implementation
 */
interface ISystemInitializationManager {
    
    // ============ ENUMS ============
    
    enum InitializationPhase {
        NOT_STARTED,          // Initialization not started
        CONTRACTS_DEPLOYED,   // Contracts deployed
        PARAMETERS_SET,       // Parameters configured
        TOKENS_DISTRIBUTED,   // Token distribution completed
        LIQUIDITY_SETUP,      // Liquidity pools created
        GOVERNANCE_ACTIVE,    // Governance activated
        FULLY_INITIALIZED    // System fully operational
    }
    
    enum InitializationStatus {
        PENDING,             // Pending initialization
        IN_PROGRESS,         // Currently initializing
        COMPLETED,           // Successfully completed
        FAILED,              // Initialization failed
        REQUIRES_RETRY      // Needs retry
    }
    
    enum ParameterCategory {
        TOKEN_PARAMETERS,    // Token-related parameters
        TREASURY_PARAMETERS, // Treasury configuration
        GOVERNANCE_PARAMETERS, // Governance settings
        VESTING_PARAMETERS,  // Vesting configurations
        SALE_PARAMETERS,     // Sale management settings
        SECURITY_PARAMETERS, // Security configurations
        PLATFORM_PARAMETERS, // Platform integrations
        ECONOMIC_PARAMETERS  // Economic model settings
    }
    
    enum DistributionType {
        TEAM_ALLOCATION,     // Team vesting (25%)
        PRIVATE_SALE,        // Private sale (15%)
        PUBLIC_SALE,         // Public sale (10%)
        COMMUNITY_REWARDS,   // Community rewards (20%)
        STAKING_REWARDS,     // Staking rewards (10%)
        TREASURY_RESERVE,    // Treasury reserve (15%)
        PLATFORM_INCENTIVES, // Platform incentives (8%)
        EARLY_TESTERS       // Early tester airdrop (2%)
    }
    
    // ============ STRUCTS ============
    
    struct InitializationTask {
        bytes32 taskId;
        string name;
        ParameterCategory category;
        address targetContract;
        bytes4 functionSelector;
        bytes parameters;
        InitializationStatus status;
        uint256 priority;
        uint256 estimatedGas;
        uint256 retryCount;
        uint256 maxRetries;
        bool isRequired;
        string description;
    }
    
    struct ParameterSet {
        bytes32 parameterId;
        ParameterCategory category;
        string name;
        bytes value;
        address targetContract;
        bytes4 setter;
        bool isSet;
        uint256 timestamp;
        string description;
    }
    
    struct TokenDistribution {
        bytes32 distributionId;
        DistributionType distributionType;
        address[] recipients;
        uint256[] amounts;
        address vestingContract;
        uint256 totalAmount;
        uint256 distributedAmount;
        bool isCompleted;
        uint256 startTime;
        uint256 vestingDuration;
        string description;
    }
    
    struct LiquidityPool {
        bytes32 poolId;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        address poolAddress;
        uint24 fee;
        bool isCreated;
        uint256 creationTime;
        string description;
    }
    
    struct GovernanceSetup {
        bytes32 setupId;
        address governanceContract;
        address stakingContract;
        uint256 proposalThreshold;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumPercentage;
        bool isActivated;
        uint256 activationTime;
        string description;
    }
    
    struct InitializationMetrics {
        uint256 totalTasks;
        uint256 completedTasks;
        uint256 failedTasks;
        uint256 totalGasUsed;
        uint256 initializationStartTime;
        uint256 initializationEndTime;
        mapping(ParameterCategory => uint256) tasksByCategory;
        mapping(InitializationStatus => uint256) tasksByStatus;
    }
    
    // ============ EVENTS ============
    
    event InitializationStarted(uint256 timestamp, InitializationPhase phase);
    event InitializationPhaseCompleted(InitializationPhase indexed phase, uint256 timestamp);
    event TaskCreated(bytes32 indexed taskId, string name, ParameterCategory category);
    event TaskCompleted(bytes32 indexed taskId, uint256 gasUsed);
    event TaskFailed(bytes32 indexed taskId, string reason, uint256 retryCount);
    event ParameterSet(bytes32 indexed parameterId, address indexed targetContract, bytes value);
    event TokenDistributionStarted(bytes32 indexed distributionId, DistributionType distributionType, uint256 totalAmount);
    event TokenDistributionCompleted(bytes32 indexed distributionId, uint256 distributedAmount);
    event LiquidityPoolCreated(bytes32 indexed poolId, address indexed poolAddress, uint256 amountA, uint256 amountB);
    event GovernanceActivated(address indexed governanceContract, uint256 timestamp);
    event SystemFullyInitialized(uint256 timestamp);
    
    // ============ INITIALIZATION MANAGEMENT ============
    
    function startInitialization() external returns (bool success);
    function getCurrentPhase() external view returns (InitializationPhase phase);
    function advancePhase(InitializationPhase newPhase) external returns (bool success);
    function isFullyInitialized() external view returns (bool initialized);
    function getInitializationProgress() external view returns (uint256 percentage);
    
    // ============ TASK MANAGEMENT ============
    
    function createInitializationTask(
        string calldata name,
        ParameterCategory category,
        address targetContract,
        bytes4 functionSelector,
        bytes calldata parameters,
        uint256 priority,
        uint256 estimatedGas,
        bool isRequired,
        string calldata description
    ) external returns (bytes32 taskId);
    
    function executeTask(bytes32 taskId) external returns (bool success);
    function batchExecuteTasks(bytes32[] calldata taskIds) external returns (bool[] memory results);
    function retryFailedTask(bytes32 taskId) external returns (bool success);
    function getTask(bytes32 taskId) external view returns (InitializationTask memory task);
    function getTasksByCategory(ParameterCategory category) external view returns (InitializationTask[] memory tasks);
    function getFailedTasks() external view returns (InitializationTask[] memory tasks);
    
    // ============ PARAMETER CONFIGURATION ============
    
    function setParameter(
        ParameterCategory category,
        string calldata name,
        bytes calldata value,
        address targetContract,
        bytes4 setter,
        string calldata description
    ) external returns (bytes32 parameterId);
    
    function batchSetParameters(
        ParameterCategory[] calldata categories,
        string[] calldata names,
        bytes[] calldata values,
        address[] calldata targetContracts,
        bytes4[] calldata setters,
        string[] calldata descriptions
    ) external returns (bytes32[] memory parameterIds);
    
    function getParameter(bytes32 parameterId) external view returns (ParameterSet memory parameter);
    function getParametersByCategory(ParameterCategory category) external view returns (ParameterSet[] memory parameters);
    function isParameterSet(bytes32 parameterId) external view returns (bool isSet);
    
    // ============ TOKEN DISTRIBUTION ============
    
    function createTokenDistribution(
        DistributionType distributionType,
        address[] calldata recipients,
        uint256[] calldata amounts,
        address vestingContract,
        uint256 startTime,
        uint256 vestingDuration,
        string calldata description
    ) external returns (bytes32 distributionId);
    
    function executeTokenDistribution(bytes32 distributionId) external returns (bool success);
    function batchExecuteDistributions(bytes32[] calldata distributionIds) external returns (bool[] memory results);
    function getTokenDistribution(bytes32 distributionId) external view returns (TokenDistribution memory distribution);
    function getDistributionsByType(DistributionType distributionType) external view returns (TokenDistribution[] memory distributions);
    function getTotalDistributedTokens() external view returns (uint256 totalDistributed);
    
    // ============ LIQUIDITY SETUP ============
    
    function createLiquidityPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint24 fee,
        string calldata description
    ) external returns (bytes32 poolId);
    
    function setupInitialLiquidity(bytes32 poolId) external returns (bool success);
    function batchSetupLiquidity(bytes32[] calldata poolIds) external returns (bool[] memory results);
    function getLiquidityPool(bytes32 poolId) external view returns (LiquidityPool memory pool);
    function getAllLiquidityPools() external view returns (LiquidityPool[] memory pools);
    
    // ============ GOVERNANCE ACTIVATION ============
    
    function configureGovernance(
        address governanceContract,
        address stakingContract,
        uint256 proposalThreshold,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        string calldata description
    ) external returns (bytes32 setupId);
    
    function activateGovernance(bytes32 setupId) external returns (bool success);
    function transitionToDecentralizedControl() external returns (bool success);
    function getGovernanceSetup(bytes32 setupId) external view returns (GovernanceSetup memory setup);
    function isGovernanceActive() external view returns (bool active);
    
    // ============ VERIFICATION AND VALIDATION ============
    
    function verifySystemIntegrity() external view returns (bool isValid, string[] memory issues);
    function validateInitializationComplete() external view returns (bool isComplete, string[] memory missingItems);
    function runSystemHealthCheck() external view returns (bool isHealthy, string[] memory warnings);
    function generateInitializationReport() external view returns (
        uint256 totalTasks,
        uint256 completedTasks,
        uint256 failedTasks,
        uint256 totalGasUsed,
        string memory summary
    );
    
    // ============ AUTOMATION AND SCHEDULING ============
    
    function scheduleInitializationStep(
        bytes32 taskId,
        uint256 executionTime
    ) external returns (bool success);
    
    function executeScheduledTasks() external returns (uint256 executedCount);
    function cancelScheduledTask(bytes32 taskId) external returns (bool success);
} 