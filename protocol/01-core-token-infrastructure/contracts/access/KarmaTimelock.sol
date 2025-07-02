// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KarmaTimelock
 * @dev Timelock contract for sensitive operations with configurable delays
 * 
 * Features:
 * - Configurable timelock delays for different operation types
 * - Queue, execute, and cancel operations
 * - Emergency bypass mechanisms with proper controls
 * - Batch operation support for efficiency
 */
contract KarmaTimelock is AccessControl, ReentrancyGuard {
    
    // ============ STATE VARIABLES ============
    
    uint256 public constant MINIMUM_DELAY = 1 hours;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    uint256 public constant DEFAULT_DELAY = 2 days;
    
    // Operation types with different delays
    enum OperationType {
        STANDARD,       // 2 days - default operations
        CRITICAL,       // 7 days - critical system changes
        EMERGENCY,      // 1 hour - emergency operations
        GOVERNANCE      // 3 days - governance-related operations
    }
    
    struct TimelockOperation {
        bytes32 id;
        address target;
        uint256 value;
        bytes data;
        uint256 eta;  // execution time
        bool executed;
        bool cancelled;
        OperationType operationType;
        address proposer;
    }
    
    // Mapping from operation ID to operation details
    mapping(bytes32 => TimelockOperation) public operations;
    
    // Mapping from operation type to delay
    mapping(OperationType => uint256) public operationDelays;
    
    // Role definitions
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // ============ EVENTS ============
    
    event OperationQueued(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 eta,
        OperationType operationType,
        address indexed proposer
    );
    
    event OperationExecuted(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        address indexed executor
    );
    
    event OperationCancelled(bytes32 indexed id, address indexed canceller);
    event DelayUpdated(OperationType indexed operationType, uint256 oldDelay, uint256 newDelay);
    event EmergencyExecutionTriggered(bytes32 indexed id, address indexed executor);
    
    // ============ MODIFIERS ============
    
    modifier onlyProposer() {
        require(hasRole(PROPOSER_ROLE, msg.sender), "KarmaTimelock: caller is not proposer");
        _;
    }
    
    modifier onlyExecutor() {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "KarmaTimelock: caller is not executor");
        _;
    }
    
    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "KarmaTimelock: caller is not emergency role");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize the timelock with default delays and roles
     * @param admin Address that will receive admin role
     * @param proposers Array of addresses that can propose operations
     * @param executors Array of addresses that can execute operations
     */
    constructor(
        address admin,
        address[] memory proposers,
        address[] memory executors
    ) {
        require(admin != address(0), "KarmaTimelock: Invalid admin address");
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        
        // Grant proposer roles
        for (uint256 i = 0; i < proposers.length; i++) {
            _grantRole(PROPOSER_ROLE, proposers[i]);
        }
        
        // Grant executor roles
        for (uint256 i = 0; i < executors.length; i++) {
            _grantRole(EXECUTOR_ROLE, executors[i]);
        }
        
        // Set default delays
        operationDelays[OperationType.STANDARD] = DEFAULT_DELAY;
        operationDelays[OperationType.CRITICAL] = 7 days;
        operationDelays[OperationType.EMERGENCY] = 1 hours;
        operationDelays[OperationType.GOVERNANCE] = 3 days;
    }
    
    // ============ TIMELOCK OPERATIONS ============
    
    /**
     * @dev Queue an operation for later execution
     * @param target Target contract address
     * @param value ETH value to send
     * @param data Encoded function call data
     * @param operationType Type of operation (affects delay)
     * @return operationId Unique identifier for the operation
     */
    function queueOperation(
        address target,
        uint256 value,
        bytes memory data,
        OperationType operationType
    ) external onlyProposer returns (bytes32) {
        
        bytes32 operationId = keccak256(abi.encode(
            target,
            value,
            data,
            operationType,
            msg.sender,
            block.timestamp
        ));
        
        require(operations[operationId].id == bytes32(0), "KarmaTimelock: Operation already queued");
        
        uint256 delay = operationDelays[operationType];
        uint256 eta = block.timestamp + delay;
        
        operations[operationId] = TimelockOperation({
            id: operationId,
            target: target,
            value: value,
            data: data,
            eta: eta,
            executed: false,
            cancelled: false,
            operationType: operationType,
            proposer: msg.sender
        });
        
        emit OperationQueued(operationId, target, value, data, eta, operationType, msg.sender);
        
        return operationId;
    }
    
    /**
     * @dev Execute a queued operation after the timelock delay
     * @param operationId ID of the operation to execute
     */
    function executeOperation(bytes32 operationId) 
        external 
        payable 
        onlyExecutor 
        nonReentrant 
    {
        TimelockOperation storage operation = operations[operationId];
        
        require(operation.id != bytes32(0), "KarmaTimelock: Operation does not exist");
        require(!operation.executed, "KarmaTimelock: Operation already executed");
        require(!operation.cancelled, "KarmaTimelock: Operation was cancelled");
        require(block.timestamp >= operation.eta, "KarmaTimelock: Operation not ready for execution");
        
        operation.executed = true;
        
        // Execute the operation
        (bool success, ) = operation.target.call{value: operation.value}(operation.data);
        require(success, "KarmaTimelock: Operation execution failed");
        
        emit OperationExecuted(operationId, operation.target, operation.value, operation.data, msg.sender);
    }
    
    /**
     * @dev Cancel a queued operation
     * @param operationId ID of the operation to cancel
     */
    function cancelOperation(bytes32 operationId) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        TimelockOperation storage operation = operations[operationId];
        
        require(operation.id != bytes32(0), "KarmaTimelock: Operation does not exist");
        require(!operation.executed, "KarmaTimelock: Operation already executed");
        require(!operation.cancelled, "KarmaTimelock: Operation already cancelled");
        
        operation.cancelled = true;
        
        emit OperationCancelled(operationId, msg.sender);
    }
    
    /**
     * @dev Emergency execution bypass (requires EMERGENCY_ROLE)
     * @param operationId ID of the operation to execute immediately
     */
    function emergencyExecute(bytes32 operationId) 
        external 
        payable 
        onlyEmergency 
        nonReentrant 
    {
        TimelockOperation storage operation = operations[operationId];
        
        require(operation.id != bytes32(0), "KarmaTimelock: Operation does not exist");
        require(!operation.executed, "KarmaTimelock: Operation already executed");
        require(!operation.cancelled, "KarmaTimelock: Operation was cancelled");
        
        operation.executed = true;
        
        // Execute the operation immediately
        (bool success, ) = operation.target.call{value: operation.value}(operation.data);
        require(success, "KarmaTimelock: Emergency execution failed");
        
        emit EmergencyExecutionTriggered(operationId, msg.sender);
        emit OperationExecuted(operationId, operation.target, operation.value, operation.data, msg.sender);
    }
    
    // ============ BATCH OPERATIONS ============
    
    /**
     * @dev Queue multiple operations at once
     * @param targets Array of target addresses
     * @param values Array of ETH values
     * @param datas Array of encoded function calls
     * @param operationType Operation type for all operations
     * @return operationIds Array of operation IDs
     */
    function queueBatchOperations(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas,
        OperationType operationType
    ) external onlyProposer returns (bytes32[] memory) {
        
        require(
            targets.length == values.length && values.length == datas.length,
            "KarmaTimelock: Array length mismatch"
        );
        
        bytes32[] memory operationIds = new bytes32[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            operationIds[i] = this.queueOperation(targets[i], values[i], datas[i], operationType);
        }
        
        return operationIds;
    }
    
    /**
     * @dev Execute multiple operations at once
     * @param operationIds Array of operation IDs to execute
     */
    function executeBatchOperations(bytes32[] memory operationIds) 
        external 
        payable 
        onlyExecutor 
    {
        for (uint256 i = 0; i < operationIds.length; i++) {
            this.executeOperation{value: 0}(operationIds[i]);
        }
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Update the delay for a specific operation type
     * @param operationType The operation type to update
     * @param newDelay The new delay in seconds
     */
    function updateDelay(OperationType operationType, uint256 newDelay) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(
            newDelay >= MINIMUM_DELAY && newDelay <= MAXIMUM_DELAY,
            "KarmaTimelock: Invalid delay"
        );
        
        uint256 oldDelay = operationDelays[operationType];
        operationDelays[operationType] = newDelay;
        
        emit DelayUpdated(operationType, oldDelay, newDelay);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Check if an operation is ready for execution
     * @param operationId ID of the operation to check
     * @return ready True if the operation can be executed
     */
    function isOperationReady(bytes32 operationId) external view returns (bool) {
        TimelockOperation memory operation = operations[operationId];
        return operation.id != bytes32(0) && 
               !operation.executed && 
               !operation.cancelled && 
               block.timestamp >= operation.eta;
    }
    
    /**
     * @dev Get operation details
     * @param operationId ID of the operation
     * @return operation The complete operation details
     */
    function getOperation(bytes32 operationId) 
        external 
        view 
        returns (TimelockOperation memory) 
    {
        return operations[operationId];
    }
    
    /**
     * @dev Get the delay for a specific operation type
     * @param operationType The operation type to query
     * @return delay The delay in seconds
     */
    function getDelay(OperationType operationType) external view returns (uint256) {
        return operationDelays[operationType];
    }
    
    /**
     * @dev Calculate when an operation would be ready if queued now
     * @param operationType The operation type
     * @return eta The execution timestamp
     */
    function getTimestampForOperationType(OperationType operationType) 
        external 
        view 
        returns (uint256) 
    {
        return block.timestamp + operationDelays[operationType];
    }
    
    // ============ RECEIVE FUNCTION ============
    
    /**
     * @dev Allow contract to receive ETH for operations
     */
    receive() external payable {}
} 