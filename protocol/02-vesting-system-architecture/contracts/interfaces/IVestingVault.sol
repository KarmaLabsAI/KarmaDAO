// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVestingVault
 * @dev Interface for the VestingVault contract
 * 
 * This interface defines the standard vesting functionality including:
 * - Linear vesting calculations with cliff periods
 * - Multi-beneficiary management
 * - Claim and revocation systems
 * - Emergency controls
 */
interface IVestingVault {
    
    // ============ STRUCTS ============
    
    /**
     * @dev Vesting schedule structure
     */
    struct VestingSchedule {
        uint256 totalAmount;        // Total tokens allocated
        uint256 claimedAmount;      // Tokens already claimed
        uint256 startTime;          // When vesting starts
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 vestingDuration;    // Total vesting duration in seconds
        bool revoked;               // Whether schedule was revoked
        address beneficiary;        // Who can claim tokens
        string scheduleType;        // Type identifier (e.g., "TEAM", "PRIVATE_SALE")
    }
    
    // ============ EVENTS ============
    
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        string scheduleType
    );
    
    event TokensClaimed(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 amount
    );
    
    event ScheduleRevoked(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 unvestedAmount
    );
    
    event ScheduleModified(
        address indexed beneficiary,
        uint256 indexed scheduleId,
        uint256 newAmount,
        uint256 newDuration
    );
    
    event EmergencyPause(address indexed admin);
    event EmergencyUnpause(address indexed admin);
    
    // ============ VESTING MANAGEMENT ============
    
    /**
     * @dev Create a new vesting schedule
     * @param beneficiary Address that can claim tokens
     * @param totalAmount Total tokens to vest
     * @param startTime When vesting starts (timestamp)
     * @param cliffDuration Cliff period in seconds
     * @param vestingDuration Total vesting duration in seconds
     * @param scheduleType Type identifier for the schedule
     * @return scheduleId Unique identifier for the schedule
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        string memory scheduleType
    ) external returns (uint256 scheduleId);
    
    /**
     * @dev Create multiple vesting schedules in batch
     * @param beneficiaries Array of beneficiary addresses
     * @param totalAmounts Array of total amounts to vest
     * @param startTimes Array of start times
     * @param cliffDurations Array of cliff durations
     * @param vestingDurations Array of vesting durations
     * @param scheduleTypes Array of schedule type identifiers
     * @return scheduleIds Array of created schedule IDs
     */
    function createVestingSchedulesBatch(
        address[] memory beneficiaries,
        uint256[] memory totalAmounts,
        uint256[] memory startTimes,
        uint256[] memory cliffDurations,
        uint256[] memory vestingDurations,
        string[] memory scheduleTypes
    ) external returns (uint256[] memory scheduleIds);
    
    // ============ CLAIMING ============
    
    /**
     * @dev Claim vested tokens for a specific schedule
     * @param scheduleId ID of the vesting schedule
     */
    function claimTokens(uint256 scheduleId) external;
    
    /**
     * @dev Claim vested tokens from multiple schedules
     * @param scheduleIds Array of schedule IDs to claim from
     */
    function claimTokensBatch(uint256[] memory scheduleIds) external;
    
    /**
     * @dev Claim all available tokens for the caller
     */
    function claimAllAvailable() external;
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Revoke a vesting schedule
     * @param scheduleId ID of the schedule to revoke
     */
    function revokeSchedule(uint256 scheduleId) external;
    
    /**
     * @dev Partially revoke tokens from a schedule
     * @param scheduleId ID of the schedule
     * @param amountToRevoke Amount of unvested tokens to revoke
     */
    function partialRevokeSchedule(uint256 scheduleId, uint256 amountToRevoke) external;
    
    /**
     * @dev Modify an existing vesting schedule
     * @param scheduleId ID of the schedule to modify
     * @param newTotalAmount New total amount (can only be reduced)
     * @param newVestingDuration New vesting duration
     */
    function modifySchedule(
        uint256 scheduleId,
        uint256 newTotalAmount,
        uint256 newVestingDuration
    ) external;
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get vesting schedule details
     * @param scheduleId ID of the schedule
     * @return schedule The complete vesting schedule
     */
    function getVestingSchedule(uint256 scheduleId) 
        external 
        view 
        returns (VestingSchedule memory schedule);
    
    /**
     * @dev Calculate vested amount for a schedule at current time
     * @param scheduleId ID of the schedule
     * @return vested Amount currently vested
     */
    function getVestedAmount(uint256 scheduleId) external view returns (uint256 vested);
    
    /**
     * @dev Calculate claimable amount for a schedule
     * @param scheduleId ID of the schedule
     * @return claimable Amount available to claim
     */
    function getClaimableAmount(uint256 scheduleId) external view returns (uint256 claimable);
    
    /**
     * @dev Get all schedule IDs for a beneficiary
     * @param beneficiary Address to query
     * @return scheduleIds Array of schedule IDs
     */
    function getBeneficiarySchedules(address beneficiary) 
        external 
        view 
        returns (uint256[] memory scheduleIds);
    
    /**
     * @dev Get total vested amount across all schedules for a beneficiary
     * @param beneficiary Address to query
     * @return totalVested Total amount vested
     */
    function getBeneficiaryVestedAmount(address beneficiary) 
        external 
        view 
        returns (uint256 totalVested);
    
    /**
     * @dev Get total claimable amount across all schedules for a beneficiary
     * @param beneficiary Address to query
     * @return totalClaimable Total amount available to claim
     */
    function getBeneficiaryClaimableAmount(address beneficiary) 
        external 
        view 
        returns (uint256 totalClaimable);
    
    /**
     * @dev Get vesting progress as a percentage (0-10000 for 0-100.00%)
     * @param scheduleId ID of the schedule
     * @return progress Vesting progress in basis points
     */
    function getVestingProgress(uint256 scheduleId) external view returns (uint256 progress);
    
    /**
     * @dev Check if cliff period has passed for a schedule
     * @param scheduleId ID of the schedule
     * @return cliffPassed True if cliff has been reached
     */
    function isCliffReached(uint256 scheduleId) external view returns (bool cliffPassed);
    
    /**
     * @dev Get the next unlock time for a schedule
     * @param scheduleId ID of the schedule
     * @return nextUnlock Timestamp of next token unlock
     */
    function getNextUnlockTime(uint256 scheduleId) external view returns (uint256 nextUnlock);
    
    // ============ EMERGENCY CONTROLS ============
    
    /**
     * @dev Emergency pause all vesting operations
     */
    function emergencyPause() external;
    
    /**
     * @dev Emergency unpause all vesting operations
     */
    function emergencyUnpause() external;
    
    /**
     * @dev Check if contract is paused
     * @return paused True if contract is paused
     */
    function paused() external view returns (bool paused);
} 