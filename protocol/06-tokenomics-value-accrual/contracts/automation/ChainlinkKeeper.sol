// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ChainlinkKeeper
 * @dev Automated execution triggers for BuybackBurn system
 * @notice Implements Chainlink Keeper-compatible interface for automation
 */
contract ChainlinkKeeper is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant AUTOMATION_MANAGER_ROLE = keccak256("AUTOMATION_MANAGER_ROLE");

    struct AutomationConfig {
        uint256 interval;          // Time between executions
        uint256 threshold;         // Minimum balance threshold
        uint256 maxGasPrice;       // Maximum gas price for execution
        bool enabled;              // Whether automation is active
        uint256 lastExecution;     // Timestamp of last execution
    }

    struct ExecutionRecord {
        uint256 timestamp;
        uint256 amount;
        uint256 gasUsed;
        bool success;
        string reason;
    }

    // Target contract for automated calls
    address public targetContract;
    
    // Automation configuration
    AutomationConfig public automationConfig;
    
    // Execution history
    ExecutionRecord[] public executionHistory;
    mapping(uint256 => ExecutionRecord) public executions;
    uint256 public executionCount;
    
    // Performance metrics
    uint256 public totalExecutions;
    uint256 public successfulExecutions;
    uint256 public totalGasUsed;
    
    event AutomationConfigured(uint256 interval, uint256 threshold, uint256 maxGasPrice, bool enabled);
    event KeeperExecuted(uint256 indexed executionId, uint256 amount, uint256 gasUsed, bool success);
    event TargetContractUpdated(address indexed oldTarget, address indexed newTarget);
    event ExecutionFailed(uint256 indexed executionId, string reason);
    event EmergencyShutdown(string reason);

    constructor(address admin, address _targetContract) {
        require(_targetContract != address(0), "ChainlinkKeeper: Invalid target contract");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
        _grantRole(AUTOMATION_MANAGER_ROLE, admin);
        
        targetContract = _targetContract;
        
        // Default configuration
        automationConfig = AutomationConfig({
            interval: 2592000,        // 30 days
            threshold: 50 ether,      // 50 ETH threshold
            maxGasPrice: 50 gwei,     // 50 gwei max
            enabled: false,           // Start disabled
            lastExecution: 0
        });
    }

    /**
     * @dev Configure automation parameters
     */
    function configureAutomation(
        uint256 interval,
        uint256 threshold,
        uint256 maxGasPrice,
        bool enabled
    ) external onlyRole(AUTOMATION_MANAGER_ROLE) {
        require(interval >= 3600, "ChainlinkKeeper: Interval too short"); // Min 1 hour
        require(threshold > 0, "ChainlinkKeeper: Invalid threshold");
        require(maxGasPrice > 0, "ChainlinkKeeper: Invalid max gas price");

        automationConfig = AutomationConfig({
            interval: interval,
            threshold: threshold,
            maxGasPrice: maxGasPrice,
            enabled: enabled,
            lastExecution: automationConfig.lastExecution
        });

        emit AutomationConfigured(interval, threshold, maxGasPrice, enabled);
    }

    /**
     * @dev Check if upkeep is needed (Chainlink Keeper interface)
     */
    function checkUpkeep(bytes calldata /* checkData */) 
        external 
        view 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        if (!automationConfig.enabled || paused()) {
            return (false, "");
        }

        // Check time interval
        bool intervalPassed = (block.timestamp - automationConfig.lastExecution) >= automationConfig.interval;
        
        // Check balance threshold
        bool thresholdMet = targetContract.balance >= automationConfig.threshold;
        
        // Check gas price
        bool gasPriceAcceptable = tx.gasprice <= automationConfig.maxGasPrice;
        
        upkeepNeeded = intervalPassed && thresholdMet && gasPriceAcceptable;
        
        if (upkeepNeeded) {
            performData = abi.encode(targetContract.balance, block.timestamp);
        }
    }

    /**
     * @dev Perform upkeep (Chainlink Keeper interface)
     */
    function performUpkeep(bytes calldata performData) 
        external 
        onlyRole(KEEPER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        (uint256 amount, uint256 timestamp) = abi.decode(performData, (uint256, uint256));
        
        // Validate that upkeep is still needed
        (bool upkeepNeeded,) = this.checkUpkeep("");
        require(upkeepNeeded, "ChainlinkKeeper: Upkeep not needed");
        
        uint256 executionId = ++executionCount;
        uint256 gasStart = gasleft();
        
        bool success = _executeTarget(amount);
        
        uint256 gasUsed = gasStart - gasleft();
        totalGasUsed += gasUsed;
        totalExecutions++;
        
        if (success) {
            successfulExecutions++;
            automationConfig.lastExecution = block.timestamp;
        }
        
        // Record execution
        ExecutionRecord memory record = ExecutionRecord({
            timestamp: timestamp,
            amount: amount,
            gasUsed: gasUsed,
            success: success,
            reason: success ? "Automated execution" : "Execution failed"
        });
        
        executionHistory.push(record);
        executions[executionId] = record;
        
        emit KeeperExecuted(executionId, amount, gasUsed, success);
        
        if (!success) {
            emit ExecutionFailed(executionId, "Target contract execution failed");
        }
    }

    /**
     * @dev Manual execution for testing or emergency
     */
    function manualExecute(uint256 amount, string calldata reason) 
        external 
        onlyRole(AUTOMATION_MANAGER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        require(amount > 0, "ChainlinkKeeper: Invalid amount");
        
        uint256 executionId = ++executionCount;
        uint256 gasStart = gasleft();
        
        bool success = _executeTarget(amount);
        
        uint256 gasUsed = gasStart - gasleft();
        totalGasUsed += gasUsed;
        totalExecutions++;
        
        if (success) {
            successfulExecutions++;
        }
        
        // Record execution
        ExecutionRecord memory record = ExecutionRecord({
            timestamp: block.timestamp,
            amount: amount,
            gasUsed: gasUsed,
            success: success,
            reason: reason
        });
        
        executionHistory.push(record);
        executions[executionId] = record;
        
        emit KeeperExecuted(executionId, amount, gasUsed, success);
    }

    /**
     * @dev Execute target contract function
     */
    function _executeTarget(uint256 amount) internal returns (bool success) {
        try this.callTarget(amount) {
            success = true;
        } catch {
            success = false;
        }
    }

    /**
     * @dev External call to target contract (for try-catch)
     */
    function callTarget(uint256 amount) external {
        require(msg.sender == address(this), "ChainlinkKeeper: Internal call only");
        
        // Call target contract's trigger function
        (bool success,) = targetContract.call(
            abi.encodeWithSignature("manualTrigger(uint256,uint256)", amount, 500)
        );
        
        require(success, "ChainlinkKeeper: Target call failed");
    }

    /**
     * @dev Update target contract
     */
    function updateTargetContract(address newTarget) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newTarget != address(0), "ChainlinkKeeper: Invalid target");
        
        address oldTarget = targetContract;
        targetContract = newTarget;
        
        emit TargetContractUpdated(oldTarget, newTarget);
    }

    /**
     * @dev Get execution history
     */
    function getExecutionHistory(uint256 limit) 
        external 
        view 
        returns (ExecutionRecord[] memory) 
    {
        uint256 length = executionHistory.length;
        uint256 returnLength = limit > length ? length : limit;
        
        ExecutionRecord[] memory records = new ExecutionRecord[](returnLength);
        
        for (uint256 i = 0; i < returnLength; i++) {
            records[i] = executionHistory[length - 1 - i]; // Most recent first
        }
        
        return records;
    }

    /**
     * @dev Get performance metrics
     */
    function getPerformanceMetrics() 
        external 
        view 
        returns (
            uint256 total,
            uint256 successful,
            uint256 failureRate,
            uint256 avgGasUsed
        ) 
    {
        total = totalExecutions;
        successful = successfulExecutions;
        
        if (total > 0) {
            failureRate = ((total - successful) * 10000) / total; // Basis points
            avgGasUsed = totalGasUsed / total;
        }
    }

    /**
     * @dev Check if execution is due
     */
    function isExecutionDue() external view returns (bool) {
        if (!automationConfig.enabled || paused()) return false;
        
        return (block.timestamp - automationConfig.lastExecution) >= automationConfig.interval;
    }

    /**
     * @dev Get time until next execution
     */
    function getTimeUntilExecution() external view returns (uint256) {
        if (!automationConfig.enabled) return type(uint256).max;
        
        uint256 timeSinceLastExecution = block.timestamp - automationConfig.lastExecution;
        
        if (timeSinceLastExecution >= automationConfig.interval) {
            return 0;
        }
        
        return automationConfig.interval - timeSinceLastExecution;
    }

    /**
     * @dev Emergency shutdown
     */
    function emergencyShutdown(string calldata reason) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        automationConfig.enabled = false;
        _pause();
        
        emit EmergencyShutdown(reason);
    }

    /**
     * @dev Resume operations
     */
    function resumeOperations() 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _unpause();
    }

    /**
     * @dev Enable automation
     */
    function enableAutomation() external onlyRole(AUTOMATION_MANAGER_ROLE) {
        automationConfig.enabled = true;
    }

    /**
     * @dev Disable automation
     */
    function disableAutomation() external onlyRole(AUTOMATION_MANAGER_ROLE) {
        automationConfig.enabled = false;
    }
} 