// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVestingConfigurationManager
 * @dev Interface for vesting configuration manager contracts
 * 
 * Provides standardized interfaces for specific vesting schedule configurations:
 * - Team vesting (4-year, 12-month cliff)
 * - Private sale vesting (6-month linear)
 * - Flexible custom configurations
 */
interface IVestingConfigurationManager {
    
    // ============ STRUCTS ============
    
    /**
     * @dev Configuration template for vesting schedules
     */
    struct VestingTemplate {
        string name;                // Template name (e.g., "TEAM", "PRIVATE_SALE")
        uint256 vestingDuration;    // Total vesting duration in seconds
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 releaseFrequency;   // How often releases occur (for UI/calculation)
        bool isActive;              // Whether template is active
        string description;         // Human-readable description
    }
    
    /**
     * @dev Beneficiary information for tracking
     */
    struct BeneficiaryInfo {
        address beneficiary;        // Beneficiary address
        uint256 totalAllocation;   // Total tokens allocated
        uint256 schedulesCount;     // Number of vesting schedules
        uint256[] scheduleIds;      // Array of schedule IDs
        string beneficiaryType;     // Type (e.g., "TEAM_MEMBER", "INVESTOR")
        bool isActive;              // Whether beneficiary is active
    }
    
    // ============ EVENTS ============
    
    event VestingTemplateCreated(
        string indexed templateName,
        uint256 vestingDuration,
        uint256 cliffDuration,
        string description
    );
    
    event VestingTemplateUpdated(
        string indexed templateName,
        uint256 newVestingDuration,
        uint256 newCliffDuration,
        bool isActive
    );
    
    event BeneficiaryRegistered(
        address indexed beneficiary,
        string indexed beneficiaryType,
        uint256 totalAllocation
    );
    
    event VestingScheduleCreated(
        address indexed beneficiary,
        string indexed templateName,
        uint256 scheduleId,
        uint256 amount,
        uint256 startTime
    );
    
    event BeneficiaryStatusUpdated(
        address indexed beneficiary,
        bool isActive,
        string reason
    );
    
    // ============ TEMPLATE MANAGEMENT ============
    
    /**
     * @dev Create a new vesting template
     * @param name Template name
     * @param vestingDuration Total vesting duration in seconds
     * @param cliffDuration Cliff period in seconds
     * @param releaseFrequency Release frequency for calculations
     * @param description Human-readable description
     */
    function createVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        uint256 releaseFrequency,
        string memory description
    ) external;
    
    /**
     * @dev Update an existing vesting template
     * @param name Template name to update
     * @param vestingDuration New vesting duration
     * @param cliffDuration New cliff duration
     * @param isActive Whether template is active
     */
    function updateVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        bool isActive
    ) external;
    
    /**
     * @dev Get vesting template details
     * @param name Template name
     * @return template The vesting template
     */
    function getVestingTemplate(string memory name) 
        external 
        view 
        returns (VestingTemplate memory template);
    
    /**
     * @dev Get all available template names
     * @return templateNames Array of template names
     */
    function getAvailableTemplates() external view returns (string[] memory templateNames);
    
    // ============ BENEFICIARY MANAGEMENT ============
    
    /**
     * @dev Register a new beneficiary
     * @param beneficiary Beneficiary address
     * @param beneficiaryType Type identifier
     * @param totalAllocation Total tokens to be allocated
     */
    function registerBeneficiary(
        address beneficiary,
        string memory beneficiaryType,
        uint256 totalAllocation
    ) external;
    
    /**
     * @dev Update beneficiary status
     * @param beneficiary Beneficiary address
     * @param isActive New status
     * @param reason Reason for status change
     */
    function updateBeneficiaryStatus(
        address beneficiary,
        bool isActive,
        string memory reason
    ) external;
    
    /**
     * @dev Get beneficiary information
     * @param beneficiary Beneficiary address
     * @return info Beneficiary information
     */
    function getBeneficiaryInfo(address beneficiary) 
        external 
        view 
        returns (BeneficiaryInfo memory info);
    
    /**
     * @dev Get all beneficiaries of a specific type
     * @param beneficiaryType Type to filter by
     * @return beneficiaries Array of beneficiary addresses
     */
    function getBeneficiariesByType(string memory beneficiaryType) 
        external 
        view 
        returns (address[] memory beneficiaries);
    
    // ============ VESTING SCHEDULE CREATION ============
    
    /**
     * @dev Create vesting schedule using a template
     * @param beneficiary Beneficiary address
     * @param templateName Template to use
     * @param amount Amount of tokens to vest
     * @param startTime When vesting starts
     * @return scheduleId Created schedule ID
     */
    function createVestingScheduleFromTemplate(
        address beneficiary,
        string memory templateName,
        uint256 amount,
        uint256 startTime
    ) external returns (uint256 scheduleId);
    
    /**
     * @dev Create multiple vesting schedules using templates
     * @param beneficiaries Array of beneficiary addresses
     * @param templateNames Array of template names
     * @param amounts Array of token amounts
     * @param startTimes Array of start times
     * @return scheduleIds Array of created schedule IDs
     */
    function createVestingSchedulesBatchFromTemplates(
        address[] memory beneficiaries,
        string[] memory templateNames,
        uint256[] memory amounts,
        uint256[] memory startTimes
    ) external returns (uint256[] memory scheduleIds);
    
    // ============ ANALYTICS AND REPORTING ============
    
    /**
     * @dev Get total allocation for a specific template
     * @param templateName Template name
     * @return totalAllocation Total tokens allocated using this template
     */
    function getTotalAllocationByTemplate(string memory templateName) 
        external 
        view 
        returns (uint256 totalAllocation);
    
    /**
     * @dev Get total allocation for a beneficiary type
     * @param beneficiaryType Type to query
     * @return totalAllocation Total tokens allocated to this type
     */
    function getTotalAllocationByType(string memory beneficiaryType) 
        external 
        view 
        returns (uint256 totalAllocation);
    
    /**
     * @dev Get configuration manager statistics
     * @return totalBeneficiaries Total number of beneficiaries
     * @return totalTemplates Total number of templates
     * @return totalSchedules Total number of schedules created
     * @return totalAllocation Total tokens allocated
     */
    function getManagerStatistics() 
        external 
        view 
        returns (
            uint256 totalBeneficiaries,
            uint256 totalTemplates,
            uint256 totalSchedules,
            uint256 totalAllocation
        );
} 