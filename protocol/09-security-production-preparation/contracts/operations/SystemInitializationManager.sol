// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../interfaces/ISystemInitializationManager.sol";

/**
 * @title SystemInitializationManager
 * @dev Complete system initialization with parameter configuration and token distribution
 * Stage 9.2 - System Initialization Implementation
 */
contract SystemInitializationManager is ISystemInitializationManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ CONSTANTS ============
    
    bytes32 public constant INITIALIZATION_MANAGER_ROLE = keccak256("INITIALIZATION_MANAGER_ROLE");
    bytes32 public constant PARAMETER_SETTER_ROLE = keccak256("PARAMETER_SETTER_ROLE");
    bytes32 public constant DISTRIBUTION_MANAGER_ROLE = keccak256("DISTRIBUTION_MANAGER_ROLE");
    bytes32 public constant GOVERNANCE_ACTIVATOR_ROLE = keccak256("GOVERNANCE_ACTIVATOR_ROLE");
    
    uint256 public constant MAX_RETRY_ATTEMPTS = 3;
    uint256 public constant TASK_TIMEOUT = 1 hours;
    uint256 public constant DISTRIBUTION_BATCH_SIZE = 100;
    
    // Total token supply: 1 billion KARMA
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18;
    
    // Distribution percentages
    uint256 public constant TEAM_ALLOCATION_PCT = 25; // 250M KARMA
    uint256 public constant PRIVATE_SALE_PCT = 15;    // 150M KARMA
    uint256 public constant PUBLIC_SALE_PCT = 10;     // 100M KARMA
    uint256 public constant COMMUNITY_REWARDS_PCT = 20; // 200M KARMA
    uint256 public constant STAKING_REWARDS_PCT = 10;   // 100M KARMA
    uint256 public constant TREASURY_RESERVE_PCT = 15;  // 150M KARMA
    uint256 public constant PLATFORM_INCENTIVES_PCT = 8; // 80M KARMA
    uint256 public constant EARLY_TESTERS_PCT = 2;      // 20M KARMA
    
    // ============ STATE VARIABLES ============
    
    // Current initialization phase
    InitializationPhase public currentPhase;
    
    // Core contracts
    IERC20 public karmaToken;
    address public treasuryContract;
    address public governanceContract;
    address public stakingContract;
    
    // Task management
    mapping(bytes32 => InitializationTask) private _initializationTasks;
    mapping(ParameterCategory => bytes32[]) public tasksByCategory;
    mapping(InitializationStatus => bytes32[]) public tasksByStatus;
    
    // Parameter management
    mapping(bytes32 => ParameterSet) private _parameters;
    mapping(ParameterCategory => bytes32[]) public parametersByCategory;
    
    // Token distribution
    mapping(bytes32 => TokenDistribution) private _tokenDistributions;
    mapping(DistributionType => bytes32[]) public distributionsByType;
    
    // Liquidity pools
    mapping(bytes32 => LiquidityPool) private _liquidityPools;
    bytes32[] public allPoolIds;
    
    // Governance setup
    mapping(bytes32 => GovernanceSetup) private _governanceSetups;
    bytes32 public activeGovernanceSetup;
    
    // Metrics and tracking
    InitializationMetrics private _metrics;
    
    // Scheduling
    mapping(bytes32 => uint256) public scheduledTasks;
    
    // Request counters
    uint256 private _taskCounter;
    uint256 private _parameterCounter;
    uint256 private _distributionCounter;
    uint256 private _poolCounter;
    uint256 private _governanceCounter;
    
    // Initialization tracking
    bool public initializationStarted;
    bool public fullyInitialized;
    uint256 public initializationStartTime;
    uint256 public initializationEndTime;
    
    // ============ MODIFIERS ============
    
    modifier onlyInitializationManager() {
        require(hasRole(INITIALIZATION_MANAGER_ROLE, msg.sender), "SystemInit: Not initialization manager");
        _;
    }
    
    modifier onlyParameterSetter() {
        require(hasRole(PARAMETER_SETTER_ROLE, msg.sender), "SystemInit: Not parameter setter");
        _;
    }
    
    modifier onlyDistributionManager() {
        require(hasRole(DISTRIBUTION_MANAGER_ROLE, msg.sender), "SystemInit: Not distribution manager");
        _;
    }
    
    modifier onlyGovernanceActivator() {
        require(hasRole(GOVERNANCE_ACTIVATOR_ROLE, msg.sender), "SystemInit: Not governance activator");
        _;
    }
    
    modifier validTaskId(bytes32 taskId) {
        require(_initializationTasks[taskId].taskId != bytes32(0), "SystemInit: Invalid task ID");
        _;
    }
    
    modifier validParameterId(bytes32 parameterId) {
        require(_parameters[parameterId].parameterId != bytes32(0), "SystemInit: Invalid parameter ID");
        _;
    }
    
    modifier notFullyInitialized() {
        require(!fullyInitialized, "SystemInit: System already fully initialized");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _admin,
        address _karmaToken,
        address _treasuryContract
    ) {
        require(_admin != address(0), "SystemInit: Invalid admin");
        require(_karmaToken != address(0), "SystemInit: Invalid karma token");
        require(_treasuryContract != address(0), "SystemInit: Invalid treasury");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(INITIALIZATION_MANAGER_ROLE, _admin);
        _grantRole(PARAMETER_SETTER_ROLE, _admin);
        _grantRole(DISTRIBUTION_MANAGER_ROLE, _admin);
        _grantRole(GOVERNANCE_ACTIVATOR_ROLE, _admin);
        
        karmaToken = IERC20(_karmaToken);
        treasuryContract = _treasuryContract;
        
        currentPhase = InitializationPhase.NOT_STARTED;
        
        // Initialize metrics
        _metrics.totalTasks = 0;
        _metrics.completedTasks = 0;
        _metrics.failedTasks = 0;
        _metrics.totalGasUsed = 0;
        _metrics.initializationStartTime = 0;
        _metrics.initializationEndTime = 0;
    }
    
    // ============ INITIALIZATION MANAGEMENT ============
    
    function startInitialization() external override onlyInitializationManager whenNotPaused returns (bool success) {
        require(!initializationStarted, "SystemInit: Already started");
        
        initializationStarted = true;
        initializationStartTime = block.timestamp;
        currentPhase = InitializationPhase.CONTRACTS_DEPLOYED;
        
        _metrics.initializationStartTime = block.timestamp;
        
        emit InitializationStarted(block.timestamp, currentPhase);
        return true;
    }
    
    function getCurrentPhase() external view override returns (InitializationPhase phase) {
        return currentPhase;
    }
    
    function advancePhase(InitializationPhase newPhase) external override onlyInitializationManager returns (bool success) {
        require(uint8(newPhase) > uint8(currentPhase), "SystemInit: Cannot move backwards");
        require(newPhase <= InitializationPhase.FULLY_INITIALIZED, "SystemInit: Invalid phase");
        
        currentPhase = newPhase;
        
        if (newPhase == InitializationPhase.FULLY_INITIALIZED) {
            fullyInitialized = true;
            initializationEndTime = block.timestamp;
            _metrics.initializationEndTime = block.timestamp;
            
            emit SystemFullyInitialized(block.timestamp);
        }
        
        emit InitializationPhaseCompleted(newPhase, block.timestamp);
        return true;
    }
    
    function isFullyInitialized() external view override returns (bool initialized) {
        return fullyInitialized;
    }
    
    function getInitializationProgress() external view override returns (uint256 percentage) {
        if (_metrics.totalTasks == 0) return 0;
        return (_metrics.completedTasks * 100) / _metrics.totalTasks;
    }
    
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
    ) external override onlyInitializationManager notFullyInitialized returns (bytes32 taskId) {
        require(bytes(name).length > 0, "SystemInit: Empty task name");
        require(targetContract != address(0), "SystemInit: Invalid target contract");
        
        taskId = keccak256(abi.encodePacked(
            name, category, targetContract, functionSelector, block.timestamp, _taskCounter++
        ));
        
        InitializationTask storage task = _initializationTasks[taskId];
        task.taskId = taskId;
        task.name = name;
        task.category = category;
        task.targetContract = targetContract;
        task.functionSelector = functionSelector;
        task.parameters = parameters;
        task.status = InitializationStatus.PENDING;
        task.priority = priority;
        task.estimatedGas = estimatedGas;
        task.retryCount = 0;
        task.maxRetries = MAX_RETRY_ATTEMPTS;
        task.isRequired = isRequired;
        task.description = description;
        
        // Update tracking
        tasksByCategory[category].push(taskId);
        tasksByStatus[InitializationStatus.PENDING].push(taskId);
        _metrics.totalTasks++;
        
        emit TaskCreated(taskId, name, category);
        return taskId;
    }
    
    function executeTask(bytes32 taskId) external override onlyInitializationManager validTaskId(taskId) nonReentrant returns (bool success) {
        InitializationTask storage task = _initializationTasks[taskId];
        require(task.status == InitializationStatus.PENDING || task.status == InitializationStatus.REQUIRES_RETRY, 
                "SystemInit: Task not executable");
        
        task.status = InitializationStatus.IN_PROGRESS;
        uint256 gasStart = gasleft();
        
        // Execute the task
        (bool callSuccess, bytes memory returnData) = task.targetContract.call(
            abi.encodePacked(task.functionSelector, task.parameters)
        );
        
        uint256 gasUsed = gasStart - gasleft();
        _metrics.totalGasUsed += gasUsed;
        
        if (callSuccess) {
            task.status = InitializationStatus.COMPLETED;
            _metrics.completedTasks++;
            
            // Update status tracking
            _removeFromStatusList(taskId, InitializationStatus.PENDING);
            _removeFromStatusList(taskId, InitializationStatus.REQUIRES_RETRY);
            tasksByStatus[InitializationStatus.COMPLETED].push(taskId);
            
            emit TaskCompleted(taskId, gasUsed);
            return true;
        } else {
            task.retryCount++;
            
            if (task.retryCount >= task.maxRetries) {
                task.status = InitializationStatus.FAILED;
                _metrics.failedTasks++;
                
                _removeFromStatusList(taskId, InitializationStatus.PENDING);
                _removeFromStatusList(taskId, InitializationStatus.REQUIRES_RETRY);
                tasksByStatus[InitializationStatus.FAILED].push(taskId);
                
                emit TaskFailed(taskId, string(returnData), task.retryCount);
            } else {
                task.status = InitializationStatus.REQUIRES_RETRY;
                
                _removeFromStatusList(taskId, InitializationStatus.PENDING);
                tasksByStatus[InitializationStatus.REQUIRES_RETRY].push(taskId);
                
                emit TaskFailed(taskId, string(returnData), task.retryCount);
            }
            
            return false;
        }
    }
    
    function batchExecuteTasks(bytes32[] calldata taskIds) external override onlyInitializationManager returns (bool[] memory results) {
        results = new bool[](taskIds.length);
        
        for (uint256 i = 0; i < taskIds.length; i++) {
            results[i] = this.executeTask(taskIds[i]);
        }
        
        return results;
    }
    
    function retryFailedTask(bytes32 taskId) external override onlyInitializationManager validTaskId(taskId) returns (bool success) {
        InitializationTask storage task = _initializationTasks[taskId];
        require(task.status == InitializationStatus.REQUIRES_RETRY, "SystemInit: Task not retryable");
        
        task.status = InitializationStatus.PENDING;
        return this.executeTask(taskId);
    }
    
    function getTask(bytes32 taskId) external view override returns (InitializationTask memory task) {
        return _initializationTasks[taskId];
    }
    
    function getTasksByCategory(ParameterCategory category) external view override returns (InitializationTask[] memory tasks) {
        bytes32[] memory taskIds = tasksByCategory[category];
        tasks = new InitializationTask[](taskIds.length);
        
        for (uint256 i = 0; i < taskIds.length; i++) {
            tasks[i] = _initializationTasks[taskIds[i]];
        }
    }
    
    function getFailedTasks() external view override returns (InitializationTask[] memory tasks) {
        bytes32[] memory taskIds = tasksByStatus[InitializationStatus.FAILED];
        tasks = new InitializationTask[](taskIds.length);
        
        for (uint256 i = 0; i < taskIds.length; i++) {
            tasks[i] = _initializationTasks[taskIds[i]];
        }
    }
    
    // ============ PARAMETER CONFIGURATION ============
    
    function setParameter(
        ParameterCategory category,
        string calldata name,
        bytes calldata value,
        address targetContract,
        bytes4 setter,
        string calldata description
    ) external override onlyParameterSetter notFullyInitialized returns (bytes32 parameterId) {
        require(bytes(name).length > 0, "SystemInit: Empty parameter name");
        require(targetContract != address(0), "SystemInit: Invalid target contract");
        
        parameterId = keccak256(abi.encodePacked(
            category, name, targetContract, setter, block.timestamp, _parameterCounter++
        ));
        
        ParameterSet storage parameter = _parameters[parameterId];
        parameter.parameterId = parameterId;
        parameter.category = category;
        parameter.name = name;
        parameter.value = value;
        parameter.targetContract = targetContract;
        parameter.setter = setter;
        parameter.isSet = false;
        parameter.timestamp = block.timestamp;
        parameter.description = description;
        
        // Execute parameter setting
        (bool success, ) = targetContract.call(abi.encodePacked(setter, value));
        if (success) {
            parameter.isSet = true;
        }
        
        parametersByCategory[category].push(parameterId);
        
        emit ParameterConfigured(parameterId, targetContract, value);
        return parameterId;
    }
    
    function batchSetParameters(
        ParameterCategory[] calldata categories,
        string[] calldata names,
        bytes[] calldata values,
        address[] calldata targetContracts,
        bytes4[] calldata setters,
        string[] calldata descriptions
    ) external override onlyParameterSetter returns (bytes32[] memory parameterIds) {
        require(categories.length == names.length, "SystemInit: Array length mismatch");
        require(categories.length == values.length, "SystemInit: Array length mismatch");
        require(categories.length == targetContracts.length, "SystemInit: Array length mismatch");
        require(categories.length == setters.length, "SystemInit: Array length mismatch");
        require(categories.length == descriptions.length, "SystemInit: Array length mismatch");
        
        parameterIds = new bytes32[](categories.length);
        
        for (uint256 i = 0; i < categories.length; i++) {
            parameterIds[i] = this.setParameter(
                categories[i],
                names[i],
                values[i],
                targetContracts[i],
                setters[i],
                descriptions[i]
            );
        }
        
        return parameterIds;
    }
    
    function getParameter(bytes32 parameterId) external view override returns (ParameterSet memory parameter) {
        return _parameters[parameterId];
    }
    
    function getParametersByCategory(ParameterCategory category) external view override returns (ParameterSet[] memory parameters) {
        bytes32[] memory parameterIds = parametersByCategory[category];
        parameters = new ParameterSet[](parameterIds.length);
        
        for (uint256 i = 0; i < parameterIds.length; i++) {
            parameters[i] = _parameters[parameterIds[i]];
        }
    }
    
    function isParameterSet(bytes32 parameterId) external view override returns (bool isSet) {
        return _parameters[parameterId].isSet;
    }
    
    // ============ TOKEN DISTRIBUTION ============
    
    function createTokenDistribution(
        DistributionType distributionType,
        address[] calldata recipients,
        uint256[] calldata amounts,
        address vestingContract,
        uint256 startTime,
        uint256 vestingDuration,
        string calldata description
    ) external override onlyDistributionManager notFullyInitialized returns (bytes32 distributionId) {
        require(recipients.length == amounts.length, "SystemInit: Array length mismatch");
        require(recipients.length > 0, "SystemInit: No recipients");
        
        distributionId = keccak256(abi.encodePacked(
            distributionType, recipients, amounts, block.timestamp, _distributionCounter++
        ));
        
        // Calculate total amount
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        TokenDistribution storage distribution = _tokenDistributions[distributionId];
        distribution.distributionId = distributionId;
        distribution.distributionType = distributionType;
        distribution.recipients = recipients;
        distribution.amounts = amounts;
        distribution.vestingContract = vestingContract;
        distribution.totalAmount = totalAmount;
        distribution.distributedAmount = 0;
        distribution.isCompleted = false;
        distribution.startTime = startTime;
        distribution.vestingDuration = vestingDuration;
        distribution.description = description;
        
        distributionsByType[distributionType].push(distributionId);
        
        emit TokenDistributionStarted(distributionId, distributionType, totalAmount);
        return distributionId;
    }
    
    function executeTokenDistribution(bytes32 distributionId) external override onlyDistributionManager nonReentrant returns (bool success) {
        TokenDistribution storage distribution = _tokenDistributions[distributionId];
        require(distribution.distributionId != bytes32(0), "SystemInit: Invalid distribution ID");
        require(!distribution.isCompleted, "SystemInit: Distribution already completed");
        
        uint256 distributedAmount = 0;
        
        // Execute distribution in batches
        for (uint256 i = 0; i < distribution.recipients.length; i++) {
            address recipient = distribution.recipients[i];
            uint256 amount = distribution.amounts[i];
            
            if (distribution.vestingContract != address(0)) {
                // Transfer to vesting contract
                require(karmaToken.transfer(distribution.vestingContract, amount), "SystemInit: Vesting transfer failed");
                
                // Create vesting schedule (simplified - would call actual vesting contract)
                // In production: vestingContract.createVestingSchedule(recipient, amount, startTime, duration)
            } else {
                // Direct transfer
                require(karmaToken.transfer(recipient, amount), "SystemInit: Direct transfer failed");
            }
            
            distributedAmount += amount;
        }
        
        distribution.distributedAmount = distributedAmount;
        distribution.isCompleted = true;
        
        emit TokenDistributionCompleted(distributionId, distributedAmount);
        return true;
    }
    
    function batchExecuteDistributions(bytes32[] calldata distributionIds) external override onlyDistributionManager returns (bool[] memory results) {
        results = new bool[](distributionIds.length);
        
        for (uint256 i = 0; i < distributionIds.length; i++) {
            results[i] = this.executeTokenDistribution(distributionIds[i]);
        }
        
        return results;
    }
    
    function getTokenDistribution(bytes32 distributionId) external view override returns (TokenDistribution memory distribution) {
        return _tokenDistributions[distributionId];
    }
    
    function getDistributionsByType(DistributionType distributionType) external view override returns (TokenDistribution[] memory distributions) {
        bytes32[] memory distributionIds = distributionsByType[distributionType];
        distributions = new TokenDistribution[](distributionIds.length);
        
        for (uint256 i = 0; i < distributionIds.length; i++) {
            distributions[i] = _tokenDistributions[distributionIds[i]];
        }
    }
    
    function getTotalDistributedTokens() external view override returns (uint256 totalDistributed) {
        // Calculate across all distribution types
        for (uint8 i = 0; i <= uint8(DistributionType.EARLY_TESTERS); i++) {
            DistributionType distType = DistributionType(i);
            bytes32[] memory distributionIds = distributionsByType[distType];
            
            for (uint256 j = 0; j < distributionIds.length; j++) {
                totalDistributed += _tokenDistributions[distributionIds[j]].distributedAmount;
            }
        }
    }
    
    // ============ LIQUIDITY SETUP ============
    
    function createLiquidityPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint24 fee,
        string calldata description
    ) external override onlyInitializationManager notFullyInitialized returns (bytes32 poolId) {
        require(tokenA != address(0) && tokenB != address(0), "SystemInit: Invalid tokens");
        require(amountA > 0 && amountB > 0, "SystemInit: Invalid amounts");
        
        poolId = keccak256(abi.encodePacked(
            tokenA, tokenB, amountA, amountB, fee, block.timestamp, _poolCounter++
        ));
        
        LiquidityPool storage pool = _liquidityPools[poolId];
        pool.poolId = poolId;
        pool.tokenA = tokenA;
        pool.tokenB = tokenB;
        pool.amountA = amountA;
        pool.amountB = amountB;
        pool.poolAddress = address(0); // Set when created
        pool.fee = fee;
        pool.isCreated = false;
        pool.creationTime = 0;
        pool.description = description;
        
        allPoolIds.push(poolId);
        
        return poolId;
    }
    
    function setupInitialLiquidity(bytes32 poolId) external override onlyInitializationManager nonReentrant returns (bool success) {
        LiquidityPool storage pool = _liquidityPools[poolId];
        require(pool.poolId != bytes32(0), "SystemInit: Invalid pool ID");
        require(!pool.isCreated, "SystemInit: Pool already created");
        
        // In production, would integrate with actual DEX (Uniswap V3, etc.)
        // For now, simulate pool creation
        pool.poolAddress = address(uint160(uint256(keccak256(abi.encodePacked(poolId, block.timestamp)))));
        pool.isCreated = true;
        pool.creationTime = block.timestamp;
        
        emit LiquidityPoolCreated(poolId, pool.poolAddress, pool.amountA, pool.amountB);
        return true;
    }
    
    function batchSetupLiquidity(bytes32[] calldata poolIds) external override onlyInitializationManager returns (bool[] memory results) {
        results = new bool[](poolIds.length);
        
        for (uint256 i = 0; i < poolIds.length; i++) {
            results[i] = this.setupInitialLiquidity(poolIds[i]);
        }
        
        return results;
    }
    
    function getLiquidityPool(bytes32 poolId) external view override returns (LiquidityPool memory pool) {
        return _liquidityPools[poolId];
    }
    
    function getAllLiquidityPools() external view override returns (LiquidityPool[] memory pools) {
        pools = new LiquidityPool[](allPoolIds.length);
        
        for (uint256 i = 0; i < allPoolIds.length; i++) {
            pools[i] = _liquidityPools[allPoolIds[i]];
        }
    }
    
    // ============ GOVERNANCE ACTIVATION ============
    
    function configureGovernance(
        address governanceContract_,
        address stakingContract_,
        uint256 proposalThreshold,
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        string calldata description
    ) external override onlyGovernanceActivator notFullyInitialized returns (bytes32 setupId) {
        require(governanceContract_ != address(0), "SystemInit: Invalid governance contract");
        require(stakingContract_ != address(0), "SystemInit: Invalid staking contract");
        
        setupId = keccak256(abi.encodePacked(
            governanceContract_, stakingContract_, proposalThreshold, block.timestamp, _governanceCounter++
        ));
        
        GovernanceSetup storage setup = _governanceSetups[setupId];
        setup.setupId = setupId;
        setup.governanceContract = governanceContract_;
        setup.stakingContract = stakingContract_;
        setup.proposalThreshold = proposalThreshold;
        setup.votingDelay = votingDelay;
        setup.votingPeriod = votingPeriod;
        setup.quorumPercentage = quorumPercentage;
        setup.isActivated = false;
        setup.activationTime = 0;
        setup.description = description;
        
        governanceContract = governanceContract_;
        stakingContract = stakingContract_;
        
        return setupId;
    }
    
    function activateGovernance(bytes32 setupId) external override onlyGovernanceActivator returns (bool success) {
        GovernanceSetup storage setup = _governanceSetups[setupId];
        require(setup.setupId != bytes32(0), "SystemInit: Invalid setup ID");
        require(!setup.isActivated, "SystemInit: Already activated");
        
        setup.isActivated = true;
        setup.activationTime = block.timestamp;
        activeGovernanceSetup = setupId;
        
        emit GovernanceActivated(setup.governanceContract, block.timestamp);
        return true;
    }
    
    function transitionToDecentralizedControl() external override onlyGovernanceActivator returns (bool success) {
        require(activeGovernanceSetup != bytes32(0), "SystemInit: No active governance");
        
        // Transfer admin roles to governance contract
        GovernanceSetup memory setup = _governanceSetups[activeGovernanceSetup];
        
        _grantRole(DEFAULT_ADMIN_ROLE, setup.governanceContract);
        _grantRole(INITIALIZATION_MANAGER_ROLE, setup.governanceContract);
        
        // Renounce admin role from original admin (optional - could be done in separate call)
        // _revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
        
        return true;
    }
    
    function getGovernanceSetup(bytes32 setupId) external view override returns (GovernanceSetup memory setup) {
        return _governanceSetups[setupId];
    }
    
    function isGovernanceActive() external view override returns (bool active) {
        return activeGovernanceSetup != bytes32(0) && _governanceSetups[activeGovernanceSetup].isActivated;
    }
    
    // ============ VERIFICATION AND VALIDATION ============
    
    function verifySystemIntegrity() external view override returns (bool isValid, string[] memory issues) {
        string[] memory tempIssues = new string[](10);
        uint256 issueCount = 0;
        
        // Check core contracts
        if (address(karmaToken) == address(0)) {
            tempIssues[issueCount] = "KARMA token not set";
            issueCount++;
        }
        
        if (treasuryContract == address(0)) {
            tempIssues[issueCount] = "Treasury contract not set";
            issueCount++;
        }
        
        // Check initialization status
        if (!initializationStarted) {
            tempIssues[issueCount] = "Initialization not started";
            issueCount++;
        }
        
        // Check failed tasks
        if (_metrics.failedTasks > 0) {
            tempIssues[issueCount] = "Some tasks failed";
            issueCount++;
        }
        
        // Return results
        issues = new string[](issueCount);
        for (uint256 i = 0; i < issueCount; i++) {
            issues[i] = tempIssues[i];
        }
        
        isValid = (issueCount == 0);
    }
    
    function validateInitializationComplete() external view override returns (bool isComplete, string[] memory missingItems) {
        string[] memory tempMissing = new string[](10);
        uint256 missingCount = 0;
        
        // Check phases
        if (currentPhase != InitializationPhase.FULLY_INITIALIZED) {
            tempMissing[missingCount] = "Not in fully initialized phase";
            missingCount++;
        }
        
        // Check required tasks
        if (_metrics.completedTasks < _metrics.totalTasks) {
            tempMissing[missingCount] = "Not all tasks completed";
            missingCount++;
        }
        
        // Check governance
        if (!this.isGovernanceActive()) {
            tempMissing[missingCount] = "Governance not activated";
            missingCount++;
        }
        
        // Return results
        missingItems = new string[](missingCount);
        for (uint256 i = 0; i < missingCount; i++) {
            missingItems[i] = tempMissing[i];
        }
        
        isComplete = (missingCount == 0);
    }
    
    function runSystemHealthCheck() external view override returns (bool isHealthy, string[] memory warnings) {
        string[] memory tempWarnings = new string[](10);
        uint256 warningCount = 0;
        
        // Check token balance
        if (karmaToken.balanceOf(address(this)) == 0) {
            tempWarnings[warningCount] = "No KARMA tokens in initialization contract";
            warningCount++;
        }
        
        // Check gas usage
        if (_metrics.totalGasUsed > 50_000_000) { // 50M gas warning
            tempWarnings[warningCount] = "High gas usage detected";
            warningCount++;
        }
        
        // Check timing
        if (initializationStarted && 
            block.timestamp > initializationStartTime + 7 days && 
            !fullyInitialized) {
            tempWarnings[warningCount] = "Initialization taking longer than expected";
            warningCount++;
        }
        
        // Return results
        warnings = new string[](warningCount);
        for (uint256 i = 0; i < warningCount; i++) {
            warnings[i] = tempWarnings[i];
        }
        
        isHealthy = (warningCount == 0);
    }
    
    function generateInitializationReport() external view override returns (
        uint256 totalTasks,
        uint256 completedTasks,
        uint256 failedTasks,
        uint256 totalGasUsed,
        string memory summary
    ) {
        totalTasks = _metrics.totalTasks;
        completedTasks = _metrics.completedTasks;
        failedTasks = _metrics.failedTasks;
        totalGasUsed = _metrics.totalGasUsed;
        
        if (fullyInitialized) {
            summary = "System fully initialized and operational";
        } else if (initializationStarted) {
            summary = "Initialization in progress";
        } else {
            summary = "Initialization not yet started";
        }
    }
    
    // ============ AUTOMATION AND SCHEDULING ============
    
    function scheduleInitializationStep(
        bytes32 taskId,
        uint256 executionTime
    ) external override onlyInitializationManager validTaskId(taskId) returns (bool success) {
        require(executionTime > block.timestamp, "SystemInit: Invalid execution time");
        
        scheduledTasks[taskId] = executionTime;
        return true;
    }
    
    function executeScheduledTasks() external override onlyInitializationManager returns (uint256 executedCount) {
        executedCount = 0;
        
        // Iterate through scheduled tasks (simplified implementation)
        for (uint256 i = 0; i < _taskCounter; i++) {
            bytes32 taskId = keccak256(abi.encodePacked("task", i));
            
            if (scheduledTasks[taskId] != 0 && 
                scheduledTasks[taskId] <= block.timestamp &&
                _initializationTasks[taskId].status == InitializationStatus.PENDING) {
                
                bool success = this.executeTask(taskId);
                if (success) {
                    executedCount++;
                    delete scheduledTasks[taskId];
                }
            }
        }
        
        return executedCount;
    }
    
    function cancelScheduledTask(bytes32 taskId) external override onlyInitializationManager returns (bool success) {
        delete scheduledTasks[taskId];
        return true;
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    function _removeFromStatusList(bytes32 taskId, InitializationStatus status) internal {
        bytes32[] storage statusList = tasksByStatus[status];
        
        for (uint256 i = 0; i < statusList.length; i++) {
            if (statusList[i] == taskId) {
                statusList[i] = statusList[statusList.length - 1];
                statusList.pop();
                break;
            }
        }
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getInitializationMetrics() external view returns (
        uint256 totalTasks,
        uint256 completedTasks,
        uint256 failedTasks,
        uint256 totalGasUsed,
        uint256 startTime,
        uint256 endTime
    ) {
        return (
            _metrics.totalTasks,
            _metrics.completedTasks,
            _metrics.failedTasks,
            _metrics.totalGasUsed,
            _metrics.initializationStartTime,
            _metrics.initializationEndTime
        );
    }
    
    function getActiveGovernanceSetup() external view returns (GovernanceSetup memory setup) {
        if (activeGovernanceSetup != bytes32(0)) {
            return _governanceSetups[activeGovernanceSetup];
        }
        // Return empty setup if none active
    }
} 