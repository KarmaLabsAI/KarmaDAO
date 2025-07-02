// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../../interfaces/IVestingVault.sol";
import "../../../interfaces/IVestingConfigurationManager.sol";

/**
 * @title VestingTemplateManager
 * @dev Flexible vesting template management system
 * 
 * Flexible Vesting Framework Features:
 * - Template system for future vesting schedules
 * - Configuration functions for custom vesting periods
 * - Percentage-based and fixed-amount vesting options
 * - Schedule modification capabilities for governance
 * 
 * Provides a unified interface for creating and managing custom vesting configurations
 * that can be reused across different beneficiary types and use cases.
 */
contract VestingTemplateManager is IVestingConfigurationManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ STATE VARIABLES ============
    
    IVestingVault public immutable vestingVault;
    
    // Role definitions
    bytes32 public constant TEMPLATE_MANAGER_ROLE = keccak256("TEMPLATE_MANAGER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
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
    
    // Template categories and metadata
    mapping(string => string) public templateCategory;
    mapping(string => uint256) public templateUsageCount;
    mapping(string => uint256) public templateCreationDate;
    mapping(string => address) public templateCreator;
    
    // Governance and modification tracking
    mapping(string => bool) public templateLocked;
    mapping(string => uint256) public templateLastModified;
    mapping(address => uint256) public beneficiaryLastUpdate;
    
    // Categories
    string[] private _categories;
    mapping(string => bool) private _categoryExists;
    
    // ============ EVENTS ============
    
    event TemplateUsed(
        string indexed templateName,
        address indexed beneficiary,
        uint256 scheduleId,
        uint256 amount
    );
    
    event TemplateLocked(
        string indexed templateName,
        address indexed locker,
        uint256 lockTime
    );
    
    event TemplateUnlocked(
        string indexed templateName,
        address indexed unlocker,
        uint256 unlockTime
    );
    
    event CategoryCreated(
        string indexed category,
        string description
    );
    
    event BeneficiaryMigrated(
        address indexed beneficiary,
        string fromType,
        string toType,
        uint256 migrationTime
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyTemplateManager() {
        require(hasRole(TEMPLATE_MANAGER_ROLE, msg.sender), "VestingTemplateManager: caller is not template manager");
        _;
    }
    
    modifier onlyGovernance() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "VestingTemplateManager: caller is not governance");
        _;
    }
    
    modifier templateExists(string memory templateName) {
        require(bytes(_templates[templateName].name).length > 0, "VestingTemplateManager: template does not exist");
        _;
    }
    
    modifier templateNotLocked(string memory templateName) {
        require(!templateLocked[templateName], "VestingTemplateManager: template is locked");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize the vesting template manager
     * @param _vestingVault Address of the VestingVault contract
     * @param admin Address that will receive admin role
     */
    constructor(address _vestingVault, address admin) {
        require(_vestingVault != address(0), "VestingTemplateManager: invalid vesting vault address");
        require(admin != address(0), "VestingTemplateManager: invalid admin address");
        
        vestingVault = IVestingVault(_vestingVault);
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TEMPLATE_MANAGER_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        
        // Initialize default categories and templates
        _initializeCategories();
        _createDefaultTemplates();
    }
    
    /**
     * @dev Initialize default template categories
     */
    function _initializeCategories() internal {
        _createCategory("TEAM", "Team member and employee vesting schedules");
        _createCategory("INVESTOR", "Investor and funding round vesting schedules");
        _createCategory("COMMUNITY", "Community rewards and incentive vesting schedules");
        _createCategory("CUSTOM", "Custom and project-specific vesting schedules");
    }
    
    /**
     * @dev Create a new category
     */
    function _createCategory(string memory category, string memory description) internal {
        if (!_categoryExists[category]) {
            _categories.push(category);
            _categoryExists[category] = true;
            emit CategoryCreated(category, description);
        }
    }
    
    /**
     * @dev Create default vesting templates
     */
    function _createDefaultTemplates() internal {
        // Team template (4-year, 1-year cliff)
        _createTemplateInternal(
            "TEAM_STANDARD",
            4 * 365 * 24 * 60 * 60, // 4 years
            365 * 24 * 60 * 60, // 1 year cliff
            365 * 24 * 60 * 60, // Annual releases
            "TEAM",
            "Standard team vesting: 4-year duration with 1-year cliff"
        );
        
        // Private sale template (6-month linear)
        _createTemplateInternal(
            "PRIVATE_SALE_STANDARD",
            6 * 30 * 24 * 60 * 60, // 6 months
            0, // No cliff
            30 * 24 * 60 * 60, // Monthly releases
            "INVESTOR",
            "Private sale vesting: 6-month linear vesting, no cliff"
        );
        
        // Community rewards template (2-year, 3-month cliff)
        _createTemplateInternal(
            "COMMUNITY_REWARDS",
            2 * 365 * 24 * 60 * 60, // 2 years
            3 * 30 * 24 * 60 * 60, // 3 months cliff
            30 * 24 * 60 * 60, // Monthly releases
            "COMMUNITY",
            "Community rewards: 2-year vesting with 3-month cliff"
        );
    }
    
    /**
     * @dev Internal function to create a template
     */
    function _createTemplateInternal(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        uint256 releaseFrequency,
        string memory category,
        string memory description
    ) internal {
        VestingTemplate storage template = _templates[name];
        template.name = name;
        template.vestingDuration = vestingDuration;
        template.cliffDuration = cliffDuration;
        template.releaseFrequency = releaseFrequency;
        template.isActive = true;
        template.description = description;
        
        _templateNames.push(name);
        templateCategory[name] = category;
        templateCreationDate[name] = block.timestamp;
        templateCreator[name] = address(this);
        templateUsageCount[name] = 0;
        templateLocked[name] = false;
        
        emit VestingTemplateCreated(name, vestingDuration, cliffDuration, description);
    }
    
    // ============ TEMPLATE MANAGEMENT ============
    
    /**
     * @dev Create a new vesting template
     */
    function createVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        uint256 releaseFrequency,
        string memory description
    ) external override onlyTemplateManager whenNotPaused {
        require(bytes(name).length > 0, "VestingTemplateManager: name cannot be empty");
        require(vestingDuration > 0, "VestingTemplateManager: vesting duration must be positive");
        require(cliffDuration <= vestingDuration, "VestingTemplateManager: cliff cannot exceed vesting duration");
        require(bytes(_templates[name].name).length == 0, "VestingTemplateManager: template already exists");
        
        VestingTemplate storage template = _templates[name];
        template.name = name;
        template.vestingDuration = vestingDuration;
        template.cliffDuration = cliffDuration;
        template.releaseFrequency = releaseFrequency;
        template.isActive = true;
        template.description = description;
        
        _templateNames.push(name);
        templateCategory[name] = "CUSTOM";
        templateCreationDate[name] = block.timestamp;
        templateCreator[name] = msg.sender;
        templateUsageCount[name] = 0;
        templateLocked[name] = false;
        templateLastModified[name] = block.timestamp;
        
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
    ) external override onlyTemplateManager templateExists(name) templateNotLocked(name) {
        require(vestingDuration > 0, "VestingTemplateManager: vesting duration must be positive");
        require(cliffDuration <= vestingDuration, "VestingTemplateManager: cliff cannot exceed vesting duration");
        
        VestingTemplate storage template = _templates[name];
        template.vestingDuration = vestingDuration;
        template.cliffDuration = cliffDuration;
        template.isActive = isActive;
        templateLastModified[name] = block.timestamp;
        
        emit VestingTemplateUpdated(name, vestingDuration, cliffDuration, isActive);
    }
    
    /**
     * @dev Set template category
     * @param templateName Template name
     * @param category Category name
     */
    function setTemplateCategory(
        string memory templateName,
        string memory category
    ) external onlyTemplateManager templateExists(templateName) templateNotLocked(templateName) {
        require(_categoryExists[category], "VestingTemplateManager: category does not exist");
        
        templateCategory[templateName] = category;
        templateLastModified[templateName] = block.timestamp;
    }
    
    /**
     * @dev Lock a template to prevent modifications
     * @param templateName Template name to lock
     */
    function lockTemplate(string memory templateName) 
        external 
        onlyGovernance 
        templateExists(templateName) 
    {
        require(!templateLocked[templateName], "VestingTemplateManager: template already locked");
        
        templateLocked[templateName] = true;
        
        emit TemplateLocked(templateName, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Unlock a template to allow modifications
     * @param templateName Template name to unlock
     */
    function unlockTemplate(string memory templateName) 
        external 
        onlyGovernance 
        templateExists(templateName) 
    {
        require(templateLocked[templateName], "VestingTemplateManager: template not locked");
        
        templateLocked[templateName] = false;
        
        emit TemplateUnlocked(templateName, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Create a new category
     * @param category Category name
     * @param description Category description
     */
    function createCategory(string memory category, string memory description) 
        external 
        onlyTemplateManager 
    {
        require(bytes(category).length > 0, "VestingTemplateManager: category cannot be empty");
        require(!_categoryExists[category], "VestingTemplateManager: category already exists");
        
        _createCategory(category, description);
    }
    
    // ============ BENEFICIARY MANAGEMENT ============
    
    /**
     * @dev Register a new beneficiary
     */
    function registerBeneficiary(
        address beneficiary,
        string memory beneficiaryType,
        uint256 totalAllocation
    ) external override onlyTemplateManager {
        require(beneficiary != address(0), "VestingTemplateManager: invalid beneficiary address");
        require(bytes(beneficiaryType).length > 0, "VestingTemplateManager: type cannot be empty");
        require(totalAllocation > 0, "VestingTemplateManager: allocation must be positive");
        require(_beneficiaries[beneficiary].beneficiary == address(0), "VestingTemplateManager: beneficiary already exists");
        
        BeneficiaryInfo storage beneficiaryInfo = _beneficiaries[beneficiary];
        beneficiaryInfo.beneficiary = beneficiary;
        beneficiaryInfo.totalAllocation = totalAllocation;
        beneficiaryInfo.schedulesCount = 0;
        beneficiaryInfo.beneficiaryType = beneficiaryType;
        beneficiaryInfo.isActive = true;
        
        _allBeneficiaries.push(beneficiary);
        _beneficiariesByType[beneficiaryType].push(beneficiary);
        _totalAllocationByType[beneficiaryType] += totalAllocation;
        totalTokensAllocated += totalAllocation;
        beneficiaryLastUpdate[beneficiary] = block.timestamp;
        
        emit BeneficiaryRegistered(beneficiary, beneficiaryType, totalAllocation);
    }
    
    /**
     * @dev Update beneficiary status
     */
    function updateBeneficiaryStatus(
        address beneficiary,
        bool isActive,
        string memory reason
    ) external override onlyTemplateManager {
        require(_beneficiaries[beneficiary].beneficiary != address(0), "VestingTemplateManager: beneficiary not found");
        
        _beneficiaries[beneficiary].isActive = isActive;
        beneficiaryLastUpdate[beneficiary] = block.timestamp;
        
        emit BeneficiaryStatusUpdated(beneficiary, isActive, reason);
    }
    
    /**
     * @dev Migrate beneficiary to a different type
     * @param beneficiary Beneficiary address
     * @param newType New beneficiary type
     */
    function migrateBeneficiary(
        address beneficiary,
        string memory newType
    ) external onlyTemplateManager {
        require(_beneficiaries[beneficiary].beneficiary != address(0), "VestingTemplateManager: beneficiary not found");
        require(bytes(newType).length > 0, "VestingTemplateManager: new type cannot be empty");
        
        BeneficiaryInfo storage beneficiaryInfo = _beneficiaries[beneficiary];
        string memory oldType = beneficiaryInfo.beneficiaryType;
        
        // Update type tracking
        _totalAllocationByType[oldType] -= beneficiaryInfo.totalAllocation;
        _totalAllocationByType[newType] += beneficiaryInfo.totalAllocation;
        
        // Remove from old type array
        address[] storage oldTypeArray = _beneficiariesByType[oldType];
        for (uint256 i = 0; i < oldTypeArray.length; i++) {
            if (oldTypeArray[i] == beneficiary) {
                oldTypeArray[i] = oldTypeArray[oldTypeArray.length - 1];
                oldTypeArray.pop();
                break;
            }
        }
        
        // Add to new type array
        _beneficiariesByType[newType].push(beneficiary);
        
        // Update beneficiary info
        beneficiaryInfo.beneficiaryType = newType;
        beneficiaryLastUpdate[beneficiary] = block.timestamp;
        
        emit BeneficiaryMigrated(beneficiary, oldType, newType, block.timestamp);
    }
    
    // ============ VESTING SCHEDULE CREATION ============
    
    /**
     * @dev Create vesting schedule using a template
     */
    function createVestingScheduleFromTemplate(
        address beneficiary,
        string memory templateName,
        uint256 amount,
        uint256 startTime
    ) external override onlyTemplateManager returns (uint256 scheduleId) {
        require(_templates[templateName].isActive, "VestingTemplateManager: template not active");
        require(_beneficiaries[beneficiary].beneficiary != address(0), "VestingTemplateManager: beneficiary not registered");
        require(_beneficiaries[beneficiary].isActive, "VestingTemplateManager: beneficiary not active");
        require(amount > 0, "VestingTemplateManager: amount must be positive");
        
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
        templateUsageCount[templateName]++;
        beneficiaryLastUpdate[beneficiary] = block.timestamp;
        
        emit VestingScheduleCreated(beneficiary, templateName, scheduleId, amount, startTime);
        emit TemplateUsed(templateName, beneficiary, scheduleId, amount);
        
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
    ) external override onlyTemplateManager returns (uint256[] memory scheduleIds) {
        require(
            beneficiaries.length == templateNames.length &&
            templateNames.length == amounts.length &&
            amounts.length == startTimes.length,
            "VestingTemplateManager: array length mismatch"
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
    
    function getVestingTemplate(string memory name) 
        external 
        view 
        override 
        returns (VestingTemplate memory template) 
    {
        return _templates[name];
    }
    
    function getAvailableTemplates() external view override returns (string[] memory templateNames) {
        return _templateNames;
    }
    
    function getBeneficiaryInfo(address beneficiary) 
        external 
        view 
        override 
        returns (BeneficiaryInfo memory info) 
    {
        return _beneficiaries[beneficiary];
    }
    
    function getBeneficiariesByType(string memory beneficiaryType) 
        external 
        view 
        override 
        returns (address[] memory beneficiaries) 
    {
        return _beneficiariesByType[beneficiaryType];
    }
    
    function getTotalAllocationByTemplate(string memory templateName) 
        external 
        view 
        override 
        returns (uint256 totalAllocation) 
    {
        return _totalAllocationByTemplate[templateName];
    }
    
    function getTotalAllocationByType(string memory beneficiaryType) 
        external 
        view 
        override 
        returns (uint256 totalAllocation) 
    {
        return _totalAllocationByType[beneficiaryType];
    }
    
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
    
    // ============ TEMPLATE-SPECIFIC VIEW FUNCTIONS ============
    
    /**
     * @dev Get template metadata
     */
    function getTemplateMetadata(string memory templateName) 
        external 
        view 
        templateExists(templateName)
        returns (
            string memory category,
            uint256 usageCount,
            uint256 creationDate,
            address creator,
            bool isLocked,
            uint256 lastModified
        ) 
    {
        return (
            templateCategory[templateName],
            templateUsageCount[templateName],
            templateCreationDate[templateName],
            templateCreator[templateName],
            templateLocked[templateName],
            templateLastModified[templateName]
        );
    }
    
    /**
     * @dev Get templates by category
     */
    function getTemplatesByCategory(string memory category) 
        external 
        view 
        returns (string[] memory templates) 
    {
        uint256 count = 0;
        
        // Count templates in category
        for (uint256 i = 0; i < _templateNames.length; i++) {
            if (keccak256(bytes(templateCategory[_templateNames[i]])) == keccak256(bytes(category))) {
                count++;
            }
        }
        
        // Collect templates
        templates = new string[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _templateNames.length; i++) {
            if (keccak256(bytes(templateCategory[_templateNames[i]])) == keccak256(bytes(category))) {
                templates[index] = _templateNames[i];
                index++;
            }
        }
        
        return templates;
    }
    
    /**
     * @dev Get all categories
     */
    function getAllCategories() external view returns (string[] memory categories) {
        return _categories;
    }
    
    /**
     * @dev Get most used templates
     */
    function getMostUsedTemplates(uint256 limit) 
        external 
        view 
        returns (string[] memory templates, uint256[] memory usageCounts) 
    {
        if (limit > _templateNames.length) {
            limit = _templateNames.length;
        }
        
        // Create arrays for sorting
        string[] memory sortedTemplates = new string[](limit);
        uint256[] memory sortedCounts = new uint256[](limit);
        
        // Simple selection sort for top templates
        for (uint256 i = 0; i < limit; i++) {
            uint256 maxUsage = 0;
            uint256 maxIndex = 0;
            
            for (uint256 j = 0; j < _templateNames.length; j++) {
                if (templateUsageCount[_templateNames[j]] > maxUsage) {
                    bool alreadySelected = false;
                    for (uint256 k = 0; k < i; k++) {
                        if (keccak256(bytes(sortedTemplates[k])) == keccak256(bytes(_templateNames[j]))) {
                            alreadySelected = true;
                            break;
                        }
                    }
                    if (!alreadySelected) {
                        maxUsage = templateUsageCount[_templateNames[j]];
                        maxIndex = j;
                    }
                }
            }
            
            if (maxUsage > 0) {
                sortedTemplates[i] = _templateNames[maxIndex];
                sortedCounts[i] = maxUsage;
            }
        }
        
        return (sortedTemplates, sortedCounts);
    }
    
    // ============ EMERGENCY CONTROLS ============
    
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
} 