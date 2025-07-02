// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../../interfaces/IVestingVault.sol";
import "../../../interfaces/IVestingConfigurationManager.sol";

/**
 * @title TeamVestingManager
 * @dev Specialized contract for managing team member vesting schedules
 * 
 * Team Vesting Specifications:
 * - 48-month (4-year) total vesting period
 * - 12-month cliff (no tokens released first year)
 * - 25% annual release after cliff period (linear vesting)
 * - Role-based access for team member management
 * 
 * Features:
 * - Automated team vesting configuration
 * - Team member registration and management
 * - Department/role-based categorization
 * - Batch operations for efficiency
 * - Performance and milestone tracking
 */
contract TeamVestingManager is IVestingConfigurationManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ STATE VARIABLES ============
    
    IVestingVault public immutable vestingVault;
    
    // Team vesting constants
    uint256 public constant TEAM_VESTING_DURATION = 4 * 365 * 24 * 60 * 60; // 4 years
    uint256 public constant TEAM_CLIFF_DURATION = 365 * 24 * 60 * 60; // 1 year
    uint256 public constant ANNUAL_RELEASE_PERCENTAGE = 2500; // 25% in basis points
    
    // Role definitions
    bytes32 public constant TEAM_MANAGER_ROLE = keccak256("TEAM_MANAGER_ROLE");
    bytes32 public constant HR_ROLE = keccak256("HR_ROLE");
    
    // Storage
    mapping(string => VestingTemplate) private _templates;
    mapping(address => BeneficiaryInfo) private _beneficiaries;
    mapping(string => address[]) private _beneficiariesByType;
    mapping(string => uint256) private _totalAllocationByTemplate;
    mapping(string => uint256) private _totalAllocationByType;
    
    string[] private _templateNames;
    address[] private _allBeneficiaries;
    
    uint256 public totalSchedulesCreated;
    uint256 public totalTokensAllocated;
    
    // Team-specific tracking
    mapping(address => string) public teamMemberDepartment;
    mapping(address => string) public teamMemberRole;
    mapping(address => uint256) public teamMemberJoinDate;
    mapping(address => bool) public teamMemberActive;
    
    // Department allocations
    mapping(string => uint256) public departmentTotalAllocation;
    mapping(string => uint256) public departmentMemberCount;
    string[] private _departments;
    
    // ============ EVENTS ============
    
    event TeamMemberAdded(
        address indexed member,
        string department,
        string role,
        uint256 allocation,
        uint256 joinDate
    );
    
    event TeamMemberUpdated(
        address indexed member,
        string newDepartment,
        string newRole,
        bool isActive
    );
    
    event DepartmentCreated(string indexed department, string description);
    
    event VestingScheduleCreatedForTeam(
        address indexed member,
        uint256 scheduleId,
        uint256 amount,
        uint256 startTime,
        string department,
        string role
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyTeamManager() {
        require(hasRole(TEAM_MANAGER_ROLE, msg.sender), "TeamVestingManager: caller is not team manager");
        _;
    }
    
    modifier onlyHR() {
        require(hasRole(HR_ROLE, msg.sender), "TeamVestingManager: caller is not HR");
        _;
    }
    
    modifier validTeamMember(address member) {
        require(_beneficiaries[member].beneficiary != address(0), "TeamVestingManager: not a registered team member");
        require(teamMemberActive[member], "TeamVestingManager: team member is not active");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize the team vesting manager
     * @param _vestingVault Address of the VestingVault contract
     * @param admin Address that will receive admin role
     */
    constructor(address _vestingVault, address admin) {
        require(_vestingVault != address(0), "TeamVestingManager: invalid vesting vault address");
        require(admin != address(0), "TeamVestingManager: invalid admin address");
        
        vestingVault = IVestingVault(_vestingVault);
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TEAM_MANAGER_ROLE, admin);
        _grantRole(HR_ROLE, admin);
        
        // Initialize default team template
        _createDefaultTeamTemplate();
    }
    
    /**
     * @dev Create the default team vesting template
     */
    function _createDefaultTeamTemplate() internal {
        VestingTemplate storage template = _templates["TEAM"];
        template.name = "TEAM";
        template.vestingDuration = TEAM_VESTING_DURATION;
        template.cliffDuration = TEAM_CLIFF_DURATION;
        template.releaseFrequency = 365 * 24 * 60 * 60; // Annual releases
        template.isActive = true;
        template.description = "Team member vesting: 4-year duration with 1-year cliff, 25% annual release";
        
        _templateNames.push("TEAM");
        
        emit VestingTemplateCreated(
            "TEAM",
            TEAM_VESTING_DURATION,
            TEAM_CLIFF_DURATION,
            template.description
        );
    }
    
    // ============ TEAM MEMBER MANAGEMENT ============
    
    /**
     * @dev Add a new team member
     * @param member Team member address
     * @param department Department name
     * @param role Role/position
     * @param allocation Total token allocation
     */
    function addTeamMember(
        address member,
        string memory department,
        string memory role,
        uint256 allocation
    ) external onlyHR whenNotPaused {
        require(member != address(0), "TeamVestingManager: invalid member address");
        require(bytes(department).length > 0, "TeamVestingManager: department cannot be empty");
        require(bytes(role).length > 0, "TeamVestingManager: role cannot be empty");
        require(allocation > 0, "TeamVestingManager: allocation must be positive");
        require(_beneficiaries[member].beneficiary == address(0), "TeamVestingManager: member already exists");
        
        // Register beneficiary
        BeneficiaryInfo storage beneficiary = _beneficiaries[member];
        beneficiary.beneficiary = member;
        beneficiary.totalAllocation = allocation;
        beneficiary.schedulesCount = 0;
        beneficiary.beneficiaryType = "TEAM_MEMBER";
        beneficiary.isActive = true;
        
        // Team-specific information
        teamMemberDepartment[member] = department;
        teamMemberRole[member] = role;
        teamMemberJoinDate[member] = block.timestamp;
        teamMemberActive[member] = true;
        
        // Update tracking
        _allBeneficiaries.push(member);
        _beneficiariesByType["TEAM_MEMBER"].push(member);
        _totalAllocationByType["TEAM_MEMBER"] += allocation;
        totalTokensAllocated += allocation;
        
        // Department tracking
        if (departmentMemberCount[department] == 0) {
            _departments.push(department);
            emit DepartmentCreated(department, string(abi.encodePacked("Department: ", department)));
        }
        departmentTotalAllocation[department] += allocation;
        departmentMemberCount[department]++;
        
        emit TeamMemberAdded(member, department, role, allocation, block.timestamp);
        emit BeneficiaryRegistered(member, "TEAM_MEMBER", allocation);
    }
    
    /**
     * @dev Update team member information
     * @param member Team member address
     * @param newDepartment New department (empty string to keep current)
     * @param newRole New role (empty string to keep current)
     * @param isActive New active status
     */
    function updateTeamMember(
        address member,
        string memory newDepartment,
        string memory newRole,
        bool isActive
    ) external onlyHR validTeamMember(member) {
        string memory oldDepartment = teamMemberDepartment[member];
        uint256 allocation = _beneficiaries[member].totalAllocation;
        
        // Update department if provided
        if (bytes(newDepartment).length > 0 && keccak256(bytes(newDepartment)) != keccak256(bytes(oldDepartment))) {
            // Remove from old department
            departmentTotalAllocation[oldDepartment] -= allocation;
            departmentMemberCount[oldDepartment]--;
            
            // Add to new department
            if (departmentMemberCount[newDepartment] == 0) {
                _departments.push(newDepartment);
                emit DepartmentCreated(newDepartment, string(abi.encodePacked("Department: ", newDepartment)));
            }
            departmentTotalAllocation[newDepartment] += allocation;
            departmentMemberCount[newDepartment]++;
            
            teamMemberDepartment[member] = newDepartment;
        }
        
        // Update role if provided
        if (bytes(newRole).length > 0) {
            teamMemberRole[member] = newRole;
        }
        
        // Update active status
        teamMemberActive[member] = isActive;
        _beneficiaries[member].isActive = isActive;
        
        emit TeamMemberUpdated(member, 
            bytes(newDepartment).length > 0 ? newDepartment : oldDepartment, 
            bytes(newRole).length > 0 ? newRole : teamMemberRole[member], 
            isActive
        );
        emit BeneficiaryStatusUpdated(member, isActive, isActive ? "Activated" : "Deactivated");
    }
    
    /**
     * @dev Create vesting schedule for team member
     * @param member Team member address
     * @param amount Amount of tokens to vest
     * @param startTime When vesting starts (0 for immediate)
     * @return scheduleId Created schedule ID
     */
    function createTeamVestingSchedule(
        address member,
        uint256 amount,
        uint256 startTime
    ) external onlyTeamManager validTeamMember(member) whenNotPaused returns (uint256 scheduleId) {
        require(amount > 0, "TeamVestingManager: amount must be positive");
        
        if (startTime == 0) {
            startTime = block.timestamp;
        }
        
        // Create schedule using VestingVault
        scheduleId = vestingVault.createVestingSchedule(
            member,
            amount,
            startTime,
            TEAM_CLIFF_DURATION,
            TEAM_VESTING_DURATION,
            "TEAM"
        );
        
        // Update beneficiary info
        BeneficiaryInfo storage beneficiary = _beneficiaries[member];
        beneficiary.scheduleIds.push(scheduleId);
        beneficiary.schedulesCount++;
        
        // Update tracking
        totalSchedulesCreated++;
        _totalAllocationByTemplate["TEAM"] += amount;
        
        emit VestingScheduleCreatedForTeam(
            member,
            scheduleId,
            amount,
            startTime,
            teamMemberDepartment[member],
            teamMemberRole[member]
        );
        emit VestingScheduleCreated(member, "TEAM", scheduleId, amount, startTime);
        
        return scheduleId;
    }
    
    /**
     * @dev Create vesting schedules for multiple team members
     * @param members Array of team member addresses
     * @param amounts Array of token amounts
     * @param startTimes Array of start times (0 for immediate)
     * @return scheduleIds Array of created schedule IDs
     */
    function createTeamVestingSchedulesBatch(
        address[] memory members,
        uint256[] memory amounts,
        uint256[] memory startTimes
    ) external onlyTeamManager whenNotPaused returns (uint256[] memory scheduleIds) {
        require(
            members.length == amounts.length && amounts.length == startTimes.length,
            "TeamVestingManager: array length mismatch"
        );
        
        scheduleIds = new uint256[](members.length);
        
        for (uint256 i = 0; i < members.length; i++) {
            scheduleIds[i] = this.createTeamVestingSchedule(members[i], amounts[i], startTimes[i]);
        }
        
        return scheduleIds;
    }
    
    // ============ INTERFACE IMPLEMENTATION ============
    
    /**
     * @dev Create a new vesting template
     */
    function createVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        uint256 releaseFrequency,
        string memory description
    ) external override onlyTeamManager {
        require(bytes(name).length > 0, "TeamVestingManager: name cannot be empty");
        require(vestingDuration > 0, "TeamVestingManager: vesting duration must be positive");
        require(cliffDuration <= vestingDuration, "TeamVestingManager: cliff cannot exceed vesting duration");
        require(!_templates[name].isActive, "TeamVestingManager: template already exists");
        
        VestingTemplate storage template = _templates[name];
        template.name = name;
        template.vestingDuration = vestingDuration;
        template.cliffDuration = cliffDuration;
        template.releaseFrequency = releaseFrequency;
        template.isActive = true;
        template.description = description;
        
        _templateNames.push(name);
        
        emit VestingTemplateCreated(name, vestingDuration, cliffDuration, description);
    }
    
    /**
     * @dev Update an existing vesting template
     */
    function updateVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        bool isActive
    ) external override onlyTeamManager {
        require(_templates[name].isActive || bytes(_templates[name].name).length > 0, "TeamVestingManager: template does not exist");
        require(vestingDuration > 0, "TeamVestingManager: vesting duration must be positive");
        require(cliffDuration <= vestingDuration, "TeamVestingManager: cliff cannot exceed vesting duration");
        
        VestingTemplate storage template = _templates[name];
        template.vestingDuration = vestingDuration;
        template.cliffDuration = cliffDuration;
        template.isActive = isActive;
        
        emit VestingTemplateUpdated(name, vestingDuration, cliffDuration, isActive);
    }
    
    /**
     * @dev Register a new beneficiary (redirects to addTeamMember)
     */
    function registerBeneficiary(
        address beneficiary,
        string memory beneficiaryType,
        uint256 totalAllocation
    ) external override {
        require(keccak256(bytes(beneficiaryType)) == keccak256(bytes("TEAM_MEMBER")), "TeamVestingManager: only TEAM_MEMBER type supported");
        this.addTeamMember(beneficiary, "GENERAL", "TEAM_MEMBER", totalAllocation);
    }
    
    /**
     * @dev Update beneficiary status
     */
    function updateBeneficiaryStatus(
        address beneficiary,
        bool isActive,
        string memory reason
    ) external override onlyHR {
        require(_beneficiaries[beneficiary].beneficiary != address(0), "TeamVestingManager: beneficiary not found");
        
        _beneficiaries[beneficiary].isActive = isActive;
        teamMemberActive[beneficiary] = isActive;
        
        emit BeneficiaryStatusUpdated(beneficiary, isActive, reason);
    }
    
    /**
     * @dev Create vesting schedule using a template
     */
    function createVestingScheduleFromTemplate(
        address beneficiary,
        string memory templateName,
        uint256 amount,
        uint256 startTime
    ) external override onlyTeamManager returns (uint256 scheduleId) {
        require(_templates[templateName].isActive, "TeamVestingManager: template not active");
        require(_beneficiaries[beneficiary].beneficiary != address(0), "TeamVestingManager: beneficiary not registered");
        
        VestingTemplate memory template = _templates[templateName];
        
        if (startTime == 0) {
            startTime = block.timestamp;
        }
        
        scheduleId = vestingVault.createVestingSchedule(
            beneficiary,
            amount,
            startTime,
            template.cliffDuration,
            template.vestingDuration,
            templateName
        );
        
        // Update beneficiary info
        BeneficiaryInfo storage beneficiaryInfo = _beneficiaries[beneficiary];
        beneficiaryInfo.scheduleIds.push(scheduleId);
        beneficiaryInfo.schedulesCount++;
        
        // Update tracking
        totalSchedulesCreated++;
        _totalAllocationByTemplate[templateName] += amount;
        
        emit VestingScheduleCreated(beneficiary, templateName, scheduleId, amount, startTime);
        
        return scheduleId;
    }
    
    /**
     * @dev Create multiple vesting schedules using templates
     */
    function createVestingSchedulesBatchFromTemplates(
        address[] memory beneficiaries,
        string[] memory templateNames,
        uint256[] memory amounts,
        uint256[] memory startTimes
    ) external override onlyTeamManager returns (uint256[] memory scheduleIds) {
        require(
            beneficiaries.length == templateNames.length &&
            templateNames.length == amounts.length &&
            amounts.length == startTimes.length,
            "TeamVestingManager: array length mismatch"
        );
        
        scheduleIds = new uint256[](beneficiaries.length);
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            scheduleIds[i] = this.createVestingScheduleFromTemplate(
                beneficiaries[i],
                templateNames[i],
                amounts[i],
                startTimes[i]
            );
        }
        
        return scheduleIds;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get vesting template details
     */
    function getVestingTemplate(string memory name) 
        external 
        view 
        override 
        returns (VestingTemplate memory template) 
    {
        return _templates[name];
    }
    
    /**
     * @dev Get all available template names
     */
    function getAvailableTemplates() external view override returns (string[] memory templateNames) {
        return _templateNames;
    }
    
    /**
     * @dev Get beneficiary information
     */
    function getBeneficiaryInfo(address beneficiary) 
        external 
        view 
        override 
        returns (BeneficiaryInfo memory info) 
    {
        return _beneficiaries[beneficiary];
    }
    
    /**
     * @dev Get all beneficiaries of a specific type
     */
    function getBeneficiariesByType(string memory beneficiaryType) 
        external 
        view 
        override 
        returns (address[] memory beneficiaries) 
    {
        return _beneficiariesByType[beneficiaryType];
    }
    
    /**
     * @dev Get total allocation for a specific template
     */
    function getTotalAllocationByTemplate(string memory templateName) 
        external 
        view 
        override 
        returns (uint256 totalAllocation) 
    {
        return _totalAllocationByTemplate[templateName];
    }
    
    /**
     * @dev Get total allocation for a beneficiary type
     */
    function getTotalAllocationByType(string memory beneficiaryType) 
        external 
        view 
        override 
        returns (uint256 totalAllocation) 
    {
        return _totalAllocationByType[beneficiaryType];
    }
    
    /**
     * @dev Get configuration manager statistics
     */
    function getManagerStatistics() 
        external 
        view 
        override 
        returns (
            uint256 totalBeneficiaries,
            uint256 totalTemplates,
            uint256 totalSchedules,
            uint256 totalAllocation
        ) 
    {
        return (
            _allBeneficiaries.length,
            _templateNames.length,
            totalSchedulesCreated,
            totalTokensAllocated
        );
    }
    
    // ============ TEAM-SPECIFIC VIEW FUNCTIONS ============
    
    /**
     * @dev Get team member details
     */
    function getTeamMemberDetails(address member) 
        external 
        view 
        returns (
            string memory department,
            string memory role,
            uint256 joinDate,
            bool isActive,
            uint256 totalAllocation,
            uint256 schedulesCount
        ) 
    {
        BeneficiaryInfo memory info = _beneficiaries[member];
        return (
            teamMemberDepartment[member],
            teamMemberRole[member],
            teamMemberJoinDate[member],
            teamMemberActive[member],
            info.totalAllocation,
            info.schedulesCount
        );
    }
    
    /**
     * @dev Get department statistics
     */
    function getDepartmentStats(string memory department) 
        external 
        view 
        returns (
            uint256 memberCount,
            uint256 totalAllocation,
            bool exists
        ) 
    {
        return (
            departmentMemberCount[department],
            departmentTotalAllocation[department],
            departmentMemberCount[department] > 0
        );
    }
    
    /**
     * @dev Get all departments
     */
    function getAllDepartments() external view returns (string[] memory departments) {
        return _departments;
    }
    
    /**
     * @dev Get team members by department
     */
    function getTeamMembersByDepartment(string memory department) 
        external 
        view 
        returns (address[] memory members) 
    {
        uint256 count = 0;
        
        // Count members in department
        for (uint256 i = 0; i < _allBeneficiaries.length; i++) {
            if (keccak256(bytes(teamMemberDepartment[_allBeneficiaries[i]])) == keccak256(bytes(department))) {
                count++;
            }
        }
        
        // Collect members
        members = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _allBeneficiaries.length; i++) {
            if (keccak256(bytes(teamMemberDepartment[_allBeneficiaries[i]])) == keccak256(bytes(department))) {
                members[index] = _allBeneficiaries[i];
                index++;
            }
        }
        
        return members;
    }
    
    // ============ EMERGENCY CONTROLS ============
    
    /**
     * @dev Emergency pause all operations
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Emergency unpause all operations
     */
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
} 