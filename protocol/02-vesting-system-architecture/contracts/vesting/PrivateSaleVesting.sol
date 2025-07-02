// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../../interfaces/IVestingVault.sol";
import "../../../interfaces/IVestingConfigurationManager.sol";

/**
 * @title PrivateSaleVestingManager
 * @dev Specialized contract for managing private sale investor vesting schedules
 * 
 * Private Sale Vesting Specifications:
 * - 6-month linear vesting schedule
 * - Monthly release calculations (16.67% monthly)
 * - Immediate start functionality (no cliff)
 * - Investor management and tracking system
 */
contract PrivateSaleVestingManager is IVestingConfigurationManager, AccessControl, Pausable, ReentrancyGuard {
    
    // ============ STATE VARIABLES ============
    
    IVestingVault public immutable vestingVault;
    
    // Private sale vesting constants
    uint256 public constant PRIVATE_SALE_VESTING_DURATION = 6 * 30 * 24 * 60 * 60; // 6 months
    uint256 public constant PRIVATE_SALE_CLIFF_DURATION = 0; // No cliff
    uint256 public constant MONTHLY_RELEASE_PERCENTAGE = 1667; // 16.67% in basis points
    
    // Investment tier constants
    uint256 public constant MIN_INVESTMENT = 25000 * 1e18; // $25,000 worth
    uint256 public constant MAX_INVESTMENT = 200000 * 1e18; // $200,000 worth
    
    // Role definitions
    bytes32 public constant INVESTMENT_MANAGER_ROLE = keccak256("INVESTMENT_MANAGER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    
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
    
    // Investor-specific tracking
    mapping(address => uint256) public investorInvestmentAmount;
    mapping(address => uint256) public investorInvestmentDate;
    mapping(address => string) public investorKYCStatus;
    mapping(address => string) public investorTier;
    mapping(address => bool) public investorAccredited;
    mapping(address => bool) public investorActive;
    
    // ============ EVENTS ============
    
    event InvestorAdded(
        address indexed investor,
        uint256 investmentAmount,
        string tier,
        string kycStatus,
        bool isAccredited
    );
    
    event KYCStatusUpdated(
        address indexed investor,
        string oldStatus,
        string newStatus,
        uint256 updateTime
    );
    
    // ============ MODIFIERS ============
    
    modifier onlyInvestmentManager() {
        require(hasRole(INVESTMENT_MANAGER_ROLE, msg.sender), "PrivateSaleVestingManager: caller is not investment manager");
        _;
    }
    
    modifier onlyCompliance() {
        require(hasRole(COMPLIANCE_ROLE, msg.sender), "PrivateSaleVestingManager: caller is not compliance officer");
        _;
    }
    
    modifier validInvestor(address investor) {
        require(_beneficiaries[investor].beneficiary != address(0), "PrivateSaleVestingManager: not a registered investor");
        require(investorActive[investor], "PrivateSaleVestingManager: investor is not active");
        require(keccak256(bytes(investorKYCStatus[investor])) == keccak256(bytes("APPROVED")), "PrivateSaleVestingManager: investor KYC not approved");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _vestingVault, address admin) {
        require(_vestingVault != address(0), "PrivateSaleVestingManager: invalid vesting vault address");
        require(admin != address(0), "PrivateSaleVestingManager: invalid admin address");
        
        vestingVault = IVestingVault(_vestingVault);
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(INVESTMENT_MANAGER_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        
        // Initialize default template
        _createDefaultPrivateSaleTemplate();
    }
    
    function _createDefaultPrivateSaleTemplate() internal {
        VestingTemplate storage template = _templates["PRIVATE_SALE"];
        template.name = "PRIVATE_SALE";
        template.vestingDuration = PRIVATE_SALE_VESTING_DURATION;
        template.cliffDuration = PRIVATE_SALE_CLIFF_DURATION;
        template.releaseFrequency = 30 * 24 * 60 * 60; // Monthly releases
        template.isActive = true;
        template.description = "Private sale vesting: 6-month linear vesting, no cliff, 16.67% monthly release";
        
        _templateNames.push("PRIVATE_SALE");
        
        emit VestingTemplateCreated(
            "PRIVATE_SALE",
            PRIVATE_SALE_VESTING_DURATION,
            PRIVATE_SALE_CLIFF_DURATION,
            template.description
        );
    }
    
    // ============ INVESTOR MANAGEMENT ============
    
    function addInvestor(
        address investor,
        uint256 investmentAmount,
        string memory tier,
        bool isAccredited
    ) external onlyCompliance whenNotPaused {
        _addInvestorInternal(investor, investmentAmount, tier, isAccredited);
    }
    
    function updateInvestorKYC(address investor, string memory newKYCStatus) external onlyCompliance {
        require(_beneficiaries[investor].beneficiary != address(0), "PrivateSaleVestingManager: investor not found");
        
        string memory oldStatus = investorKYCStatus[investor];
        investorKYCStatus[investor] = newKYCStatus;
        
        if (keccak256(bytes(newKYCStatus)) == keccak256(bytes("REJECTED"))) {
            investorActive[investor] = false;
            _beneficiaries[investor].isActive = false;
        }
        
        emit KYCStatusUpdated(investor, oldStatus, newKYCStatus, block.timestamp);
    }
    
    function createInvestorVestingSchedule(
        address investor,
        uint256 amount,
        uint256 startTime
    ) external onlyInvestmentManager validInvestor(investor) whenNotPaused returns (uint256 scheduleId) {
        require(amount > 0, "PrivateSaleVestingManager: amount must be positive");
        
        if (startTime == 0) {
            startTime = block.timestamp;
        }
        
        scheduleId = vestingVault.createVestingSchedule(
            investor,
            amount,
            startTime,
            PRIVATE_SALE_CLIFF_DURATION,
            PRIVATE_SALE_VESTING_DURATION,
            "PRIVATE_SALE"
        );
        
        BeneficiaryInfo storage beneficiary = _beneficiaries[investor];
        beneficiary.scheduleIds.push(scheduleId);
        beneficiary.schedulesCount++;
        
        totalSchedulesCreated++;
        _totalAllocationByTemplate["PRIVATE_SALE"] += amount;
        
        emit VestingScheduleCreated(investor, "PRIVATE_SALE", scheduleId, amount, startTime);
        
        return scheduleId;
    }
    
    // ============ INTERFACE IMPLEMENTATION ============
    
    function createVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        uint256 releaseFrequency,
        string memory description
    ) external override onlyInvestmentManager {
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
    
    function updateVestingTemplate(
        string memory name,
        uint256 vestingDuration,
        uint256 cliffDuration,
        bool isActive
    ) external override onlyInvestmentManager {
        VestingTemplate storage template = _templates[name];
        template.vestingDuration = vestingDuration;
        template.cliffDuration = cliffDuration;
        template.isActive = isActive;
        
        emit VestingTemplateUpdated(name, vestingDuration, cliffDuration, isActive);
    }
    
    function registerBeneficiary(
        address beneficiary,
        string memory beneficiaryType,
        uint256 totalAllocation
    ) external override {
        require(keccak256(bytes(beneficiaryType)) == keccak256(bytes("INVESTOR")), "PrivateSaleVestingManager: only INVESTOR type supported");
        _addInvestorInternal(beneficiary, totalAllocation, "STANDARD", false);
    }
    
    function _addInvestorInternal(
        address investor,
        uint256 investmentAmount,
        string memory tier,
        bool isAccredited
    ) internal {
        require(investor != address(0), "PrivateSaleVestingManager: invalid investor address");
        require(investmentAmount >= MIN_INVESTMENT, "PrivateSaleVestingManager: investment below minimum");
        require(investmentAmount <= MAX_INVESTMENT, "PrivateSaleVestingManager: investment above maximum");
        require(_beneficiaries[investor].beneficiary == address(0), "PrivateSaleVestingManager: investor already exists");
        
        uint256 tokenAllocation = investmentAmount; // 1:1 ratio for demo
        
        BeneficiaryInfo storage beneficiary = _beneficiaries[investor];
        beneficiary.beneficiary = investor;
        beneficiary.totalAllocation = tokenAllocation;
        beneficiary.schedulesCount = 0;
        beneficiary.beneficiaryType = "INVESTOR";
        beneficiary.isActive = true;
        
        investorInvestmentAmount[investor] = investmentAmount;
        investorInvestmentDate[investor] = block.timestamp;
        investorKYCStatus[investor] = "PENDING";
        investorTier[investor] = tier;
        investorAccredited[investor] = isAccredited;
        investorActive[investor] = true;
        
        _allBeneficiaries.push(investor);
        _beneficiariesByType["INVESTOR"].push(investor);
        _totalAllocationByType["INVESTOR"] += tokenAllocation;
        totalTokensAllocated += tokenAllocation;
        
        emit InvestorAdded(investor, investmentAmount, tier, "PENDING", isAccredited);
        emit BeneficiaryRegistered(investor, "INVESTOR", tokenAllocation);
    }
    
    function updateBeneficiaryStatus(
        address beneficiary,
        bool isActive,
        string memory reason
    ) external override onlyCompliance {
        require(_beneficiaries[beneficiary].beneficiary != address(0), "PrivateSaleVestingManager: beneficiary not found");
        
        _beneficiaries[beneficiary].isActive = isActive;
        investorActive[beneficiary] = isActive;
        
        emit BeneficiaryStatusUpdated(beneficiary, isActive, reason);
    }

    function createVestingScheduleFromTemplate(
        address beneficiary,
        string memory templateName,
        uint256 amount,
        uint256 startTime
    ) external override onlyInvestmentManager returns (uint256 scheduleId) {
        require(_templates[templateName].isActive, "PrivateSaleVestingManager: template not active");
        require(_beneficiaries[beneficiary].beneficiary != address(0), "PrivateSaleVestingManager: beneficiary not registered");
        
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
        
        BeneficiaryInfo storage beneficiaryInfo = _beneficiaries[beneficiary];
        beneficiaryInfo.scheduleIds.push(scheduleId);
        beneficiaryInfo.schedulesCount++;
        
        totalSchedulesCreated++;
        _totalAllocationByTemplate[templateName] += amount;
        
        emit VestingScheduleCreated(beneficiary, templateName, scheduleId, amount, startTime);
        
        return scheduleId;
    }

    function createVestingSchedulesBatchFromTemplates(
        address[] memory beneficiaries,
        string[] memory templateNames,
        uint256[] memory amounts,
        uint256[] memory startTimes
    ) external override onlyInvestmentManager returns (uint256[] memory scheduleIds) {
        require(
            beneficiaries.length == templateNames.length &&
            templateNames.length == amounts.length &&
            amounts.length == startTimes.length,
            "PrivateSaleVestingManager: array length mismatch"
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
    
    function getInvestorDetails(address investor) 
        external 
        view 
        returns (
            uint256 investmentAmount,
            uint256 investmentDate,
            string memory kycStatus,
            string memory tier,
            bool isAccredited,
            bool isActive,
            uint256 totalAllocation
        ) 
    {
        BeneficiaryInfo memory info = _beneficiaries[investor];
        return (
            investorInvestmentAmount[investor],
            investorInvestmentDate[investor],
            investorKYCStatus[investor],
            investorTier[investor],
            investorAccredited[investor],
            investorActive[investor],
            info.totalAllocation
        );
    }
    
    // ============ EMERGENCY CONTROLS ============
    
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
