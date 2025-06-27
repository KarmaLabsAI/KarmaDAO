// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVestingVault.sol";

/**
 * @title VestingVault
 * @dev Core vesting contract with flexible time-locked token distribution
 * 
 * Features:
 * - Linear vesting calculations with cliff periods
 * - Multi-beneficiary management with efficient storage
 * - Batch operations for gas optimization
 * - Admin controls for revocation and modification
 * - Emergency pause functionality
 * - Comprehensive tracking and analytics
 */
contract VestingVault is IVestingVault, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ STATE VARIABLES ============
    
    IERC20 public immutable vestingToken;
    
    // Schedule storage
    mapping(uint256 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256[]) private _beneficiarySchedules;
    
    uint256 private _nextScheduleId;
    uint256 public totalVestingAmount;
    uint256 public totalClaimedAmount;
    
    // Role definitions
    bytes32 public constant VESTING_MANAGER_ROLE = keccak256("VESTING_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Constants for precision
    uint256 public constant VESTING_PRECISION = 10000; // For percentage calculations (100.00%)
    
    // ============ MODIFIERS ============
    
    modifier onlyVestingManager() {
        require(hasRole(VESTING_MANAGER_ROLE, msg.sender), "VestingVault: caller is not vesting manager");
        _;
    }
    
    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "VestingVault: caller is not emergency role");
        _;
    }
    
    modifier validSchedule(uint256 scheduleId) {
        require(scheduleId < _nextScheduleId, "VestingVault: invalid schedule ID");
        require(_vestingSchedules[scheduleId].beneficiary != address(0), "VestingVault: schedule does not exist");
        _;
    }
    
    modifier onlyBeneficiary(uint256 scheduleId) {
        require(
            _vestingSchedules[scheduleId].beneficiary == msg.sender,
            "VestingVault: caller is not beneficiary"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize the vesting vault
     * @param token Address of the token to vest
     * @param admin Address that will receive admin role
     */
    constructor(address token, address admin) {
        require(token != address(0), "VestingVault: invalid token address");
        require(admin != address(0), "VestingVault: invalid admin address");
        
        vestingToken = IERC20(token);
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VESTING_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        
        _nextScheduleId = 1; // Start IDs from 1
    }
    
    // ============ VESTING LOGIC IMPLEMENTATION ============
    
    /**
     * @dev Calculate vested amount using linear vesting with cliff
     * @param schedule The vesting schedule
     * @param currentTime Current timestamp
     * @return vested Amount currently vested
     */
    function _calculateVestedAmount(VestingSchedule memory schedule, uint256 currentTime) 
        internal 
        pure 
        returns (uint256 vested) 
    {
        if (schedule.revoked) {
            return schedule.claimedAmount; // No more vesting after revocation
        }
        
        // If before start time, nothing is vested
        if (currentTime < schedule.startTime) {
            return 0;
        }
        
        // If before cliff, nothing is vested
        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        // Calculate time passed since start
        uint256 timeSinceStart = currentTime - schedule.startTime;
        
        // If fully vested
        if (timeSinceStart >= schedule.vestingDuration) {
            return schedule.totalAmount;
        }
        
        // Linear vesting calculation
        vested = (schedule.totalAmount * timeSinceStart) / schedule.vestingDuration;
    }
    
    /**
     * @dev Calculate claimable amount for a schedule
     * @param scheduleId ID of the schedule
     * @return claimable Amount available to claim
     */
    function _calculateClaimableAmount(uint256 scheduleId) 
        internal 
        view 
        returns (uint256 claimable) 
    {
        VestingSchedule memory schedule = _vestingSchedules[scheduleId];
        uint256 vested = _calculateVestedAmount(schedule, block.timestamp);
        
        if (vested <= schedule.claimedAmount) {
            return 0;
        }
        
        return vested - schedule.claimedAmount;
    }
    
    // ============ VESTING MANAGEMENT ============
    
    /**
     * @dev Create a new vesting schedule
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        string memory scheduleType
    ) external override onlyVestingManager whenNotPaused returns (uint256 scheduleId) {
        return _createVestingScheduleInternal(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            scheduleType
        );
    }
    
    /**
     * @dev Create multiple vesting schedules in batch
     */
    function createVestingSchedulesBatch(
        address[] memory beneficiaries,
        uint256[] memory totalAmounts,
        uint256[] memory startTimes,
        uint256[] memory cliffDurations,
        uint256[] memory vestingDurations,
        string[] memory scheduleTypes
    ) external override onlyVestingManager whenNotPaused returns (uint256[] memory scheduleIds) {
        require(
            beneficiaries.length == totalAmounts.length &&
            totalAmounts.length == startTimes.length &&
            startTimes.length == cliffDurations.length &&
            cliffDurations.length == vestingDurations.length &&
            vestingDurations.length == scheduleTypes.length,
            "VestingVault: array length mismatch"
        );
        
        scheduleIds = new uint256[](beneficiaries.length);
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            scheduleIds[i] = _createVestingScheduleInternal(
                beneficiaries[i],
                totalAmounts[i],
                startTimes[i],
                cliffDurations[i],
                vestingDurations[i],
                scheduleTypes[i]
            );
        }
        
        return scheduleIds;
    }
    
    /**
     * @dev Internal function to create a vesting schedule
     */
    function _createVestingScheduleInternal(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        string memory scheduleType
    ) internal returns (uint256 scheduleId) {
        require(beneficiary != address(0), "VestingVault: invalid beneficiary");
        require(totalAmount > 0, "VestingVault: amount must be positive");
        require(vestingDuration > 0, "VestingVault: vesting duration must be positive");
        require(cliffDuration <= vestingDuration, "VestingVault: cliff cannot exceed vesting duration");
        require(startTime >= block.timestamp, "VestingVault: start time cannot be in the past");
        
        scheduleId = _nextScheduleId++;
        
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        schedule.totalAmount = totalAmount;
        schedule.claimedAmount = 0;
        schedule.startTime = startTime;
        schedule.cliffDuration = cliffDuration;
        schedule.vestingDuration = vestingDuration;
        schedule.revoked = false;
        schedule.beneficiary = beneficiary;
        schedule.scheduleType = scheduleType;
        
        // Add to beneficiary's schedule list
        _beneficiarySchedules[beneficiary].push(scheduleId);
        
        // Update total vesting amount
        totalVestingAmount += totalAmount;
        
        emit VestingScheduleCreated(
            beneficiary,
            scheduleId,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            scheduleType
        );
        
        return scheduleId;
    }
    
    // ============ CLAIMING SYSTEM ============
    
    /**
     * @dev Claim vested tokens for a specific schedule
     */
    function claimTokens(uint256 scheduleId) 
        external 
        override 
        validSchedule(scheduleId) 
        onlyBeneficiary(scheduleId) 
        whenNotPaused 
        nonReentrant 
    {
        uint256 claimableAmount = _calculateClaimableAmount(scheduleId);
        require(claimableAmount > 0, "VestingVault: no tokens available to claim");
        
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        schedule.claimedAmount += claimableAmount;
        totalClaimedAmount += claimableAmount;
        
        vestingToken.safeTransfer(msg.sender, claimableAmount);
        
        emit TokensClaimed(msg.sender, scheduleId, claimableAmount);
    }
    
    /**
     * @dev Claim vested tokens from multiple schedules
     */
    function claimTokensBatch(uint256[] memory scheduleIds) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        require(scheduleIds.length > 0, "VestingVault: empty schedule array");
        
        uint256 totalClaimable = 0;
        
        for (uint256 i = 0; i < scheduleIds.length; i++) {
            uint256 scheduleId = scheduleIds[i];
            
            require(scheduleId < _nextScheduleId, "VestingVault: invalid schedule ID");
            require(
                _vestingSchedules[scheduleId].beneficiary == msg.sender,
                "VestingVault: caller is not beneficiary"
            );
            
            uint256 claimableAmount = _calculateClaimableAmount(scheduleId);
            
            if (claimableAmount > 0) {
                VestingSchedule storage schedule = _vestingSchedules[scheduleId];
                schedule.claimedAmount += claimableAmount;
                totalClaimable += claimableAmount;
                
                emit TokensClaimed(msg.sender, scheduleId, claimableAmount);
            }
        }
        
        require(totalClaimable > 0, "VestingVault: no tokens available to claim");
        
        totalClaimedAmount += totalClaimable;
        vestingToken.safeTransfer(msg.sender, totalClaimable);
    }
    
    /**
     * @dev Claim all available tokens for the caller
     */
    function claimAllAvailable() external override whenNotPaused nonReentrant {
        uint256[] memory userSchedules = _beneficiarySchedules[msg.sender];
        require(userSchedules.length > 0, "VestingVault: no schedules found for caller");
        
        uint256 totalClaimable = 0;
        
        for (uint256 i = 0; i < userSchedules.length; i++) {
            uint256 scheduleId = userSchedules[i];
            uint256 claimableAmount = _calculateClaimableAmount(scheduleId);
            
            if (claimableAmount > 0) {
                VestingSchedule storage schedule = _vestingSchedules[scheduleId];
                schedule.claimedAmount += claimableAmount;
                totalClaimable += claimableAmount;
                
                emit TokensClaimed(msg.sender, scheduleId, claimableAmount);
            }
        }
        
        require(totalClaimable > 0, "VestingVault: no tokens available to claim");
        
        totalClaimedAmount += totalClaimable;
        vestingToken.safeTransfer(msg.sender, totalClaimable);
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Revoke a vesting schedule
     */
    function revokeSchedule(uint256 scheduleId) 
        external 
        override 
        validSchedule(scheduleId) 
        onlyVestingManager 
        whenNotPaused 
    {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        require(!schedule.revoked, "VestingVault: schedule already revoked");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule, block.timestamp);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;
        
        schedule.revoked = true;
        schedule.totalAmount = vestedAmount; // Reduce total to vested amount
        
        if (unvestedAmount > 0) {
            totalVestingAmount -= unvestedAmount;
        }
        
        emit ScheduleRevoked(schedule.beneficiary, scheduleId, unvestedAmount);
    }
    
    /**
     * @dev Partially revoke tokens from a schedule
     */
    function partialRevokeSchedule(uint256 scheduleId, uint256 amountToRevoke) 
        external 
        override 
        validSchedule(scheduleId) 
        onlyVestingManager 
        whenNotPaused 
    {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        require(!schedule.revoked, "VestingVault: schedule already revoked");
        require(amountToRevoke > 0, "VestingVault: revoke amount must be positive");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule, block.timestamp);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;
        
        require(amountToRevoke <= unvestedAmount, "VestingVault: cannot revoke vested tokens");
        
        schedule.totalAmount -= amountToRevoke;
        totalVestingAmount -= amountToRevoke;
        
        emit ScheduleRevoked(schedule.beneficiary, scheduleId, amountToRevoke);
    }
    
    /**
     * @dev Modify an existing vesting schedule
     */
    function modifySchedule(
        uint256 scheduleId,
        uint256 newTotalAmount,
        uint256 newVestingDuration
    ) external override validSchedule(scheduleId) onlyVestingManager whenNotPaused {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        require(!schedule.revoked, "VestingVault: cannot modify revoked schedule");
        require(newVestingDuration > 0, "VestingVault: vesting duration must be positive");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule, block.timestamp);
        require(newTotalAmount >= vestedAmount, "VestingVault: cannot reduce below vested amount");
        require(newTotalAmount >= schedule.claimedAmount, "VestingVault: cannot reduce below claimed amount");
        
        // Update total vesting amount
        if (newTotalAmount > schedule.totalAmount) {
            totalVestingAmount += (newTotalAmount - schedule.totalAmount);
        } else if (newTotalAmount < schedule.totalAmount) {
            totalVestingAmount -= (schedule.totalAmount - newTotalAmount);
        }
        
        schedule.totalAmount = newTotalAmount;
        schedule.vestingDuration = newVestingDuration;
        
        emit ScheduleModified(schedule.beneficiary, scheduleId, newTotalAmount, newVestingDuration);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get vesting schedule details
     */
    function getVestingSchedule(uint256 scheduleId) 
        external 
        view 
        override 
        validSchedule(scheduleId) 
        returns (VestingSchedule memory schedule) 
    {
        return _vestingSchedules[scheduleId];
    }
    
    /**
     * @dev Calculate vested amount for a schedule at current time
     */
    function getVestedAmount(uint256 scheduleId) 
        external 
        view 
        override 
        validSchedule(scheduleId) 
        returns (uint256 vested) 
    {
        return _calculateVestedAmount(_vestingSchedules[scheduleId], block.timestamp);
    }
    
    /**
     * @dev Calculate claimable amount for a schedule
     */
    function getClaimableAmount(uint256 scheduleId) 
        external 
        view 
        override 
        validSchedule(scheduleId) 
        returns (uint256 claimable) 
    {
        return _calculateClaimableAmount(scheduleId);
    }
    
    /**
     * @dev Get all schedule IDs for a beneficiary
     */
    function getBeneficiarySchedules(address beneficiary) 
        external 
        view 
        override 
        returns (uint256[] memory scheduleIds) 
    {
        return _beneficiarySchedules[beneficiary];
    }
    
    /**
     * @dev Get total vested amount across all schedules for a beneficiary
     */
    function getBeneficiaryVestedAmount(address beneficiary) 
        external 
        view 
        override 
        returns (uint256 totalVested) 
    {
        uint256[] memory userSchedules = _beneficiarySchedules[beneficiary];
        
        for (uint256 i = 0; i < userSchedules.length; i++) {
            uint256 scheduleId = userSchedules[i];
            totalVested += _calculateVestedAmount(_vestingSchedules[scheduleId], block.timestamp);
        }
        
        return totalVested;
    }
    
    /**
     * @dev Get total claimable amount across all schedules for a beneficiary
     */
    function getBeneficiaryClaimableAmount(address beneficiary) 
        external 
        view 
        override 
        returns (uint256 totalClaimable) 
    {
        uint256[] memory userSchedules = _beneficiarySchedules[beneficiary];
        
        for (uint256 i = 0; i < userSchedules.length; i++) {
            uint256 scheduleId = userSchedules[i];
            totalClaimable += _calculateClaimableAmount(scheduleId);
        }
        
        return totalClaimable;
    }
    
    /**
     * @dev Get vesting progress as a percentage (0-10000 for 0-100.00%)
     */
    function getVestingProgress(uint256 scheduleId) 
        external 
        view 
        override 
        validSchedule(scheduleId) 
        returns (uint256 progress) 
    {
        VestingSchedule memory schedule = _vestingSchedules[scheduleId];
        
        if (schedule.totalAmount == 0) return 0;
        
        uint256 vestedAmount = _calculateVestedAmount(schedule, block.timestamp);
        return (vestedAmount * VESTING_PRECISION) / schedule.totalAmount;
    }
    
    /**
     * @dev Check if cliff period has passed for a schedule
     */
    function isCliffReached(uint256 scheduleId) 
        external 
        view 
        override 
        validSchedule(scheduleId) 
        returns (bool cliffPassed) 
    {
        VestingSchedule memory schedule = _vestingSchedules[scheduleId];
        return block.timestamp >= schedule.startTime + schedule.cliffDuration;
    }
    
    /**
     * @dev Get the next unlock time for a schedule
     */
    function getNextUnlockTime(uint256 scheduleId) 
        external 
        view 
        override 
        validSchedule(scheduleId) 
        returns (uint256 nextUnlock) 
    {
        VestingSchedule memory schedule = _vestingSchedules[scheduleId];
        
        // If before start, next unlock is start + cliff
        if (block.timestamp < schedule.startTime) {
            return schedule.startTime + schedule.cliffDuration;
        }
        
        // If before cliff, next unlock is cliff time
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return schedule.startTime + schedule.cliffDuration;
        }
        
        // If fully vested, no next unlock
        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return 0;
        }
        
        // Next unlock is immediate (linear vesting)
        return block.timestamp;
    }
    
    // ============ EMERGENCY CONTROLS ============
    
    /**
     * @dev Emergency pause all vesting operations
     */
    function emergencyPause() external override onlyEmergency {
        _pause();
        emit EmergencyPause(msg.sender);
    }
    
    /**
     * @dev Emergency unpause all vesting operations
     */
    function emergencyUnpause() external override onlyEmergency {
        _unpause();
        emit EmergencyUnpause(msg.sender);
    }
    
    /**
     * @dev Check if contract is paused
     * @return paused True if contract is paused
     */
    function paused() public view override(Pausable, IVestingVault) returns (bool) {
        return super.paused();
    }
    
    // ============ ADMIN UTILITY FUNCTIONS ============
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats() 
        external 
        view 
        returns (
            uint256 totalSchedules,
            uint256 totalVesting,
            uint256 totalClaimed,
            uint256 totalAvailable
        ) 
    {
        return (
            _nextScheduleId - 1,
            totalVestingAmount,
            totalClaimedAmount,
            vestingToken.balanceOf(address(this))
        );
    }
    
    /**
     * @dev Emergency token recovery (for accidentally sent tokens)
     */
    function emergencyTokenRecovery(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(token != address(vestingToken), "VestingVault: cannot recover vesting token");
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev Fund the contract with vesting tokens
     */
    function fundContract(uint256 amount) external onlyVestingManager {
        require(amount > 0, "VestingVault: amount must be positive");
        vestingToken.safeTransferFrom(msg.sender, address(this), amount);
    }
} 