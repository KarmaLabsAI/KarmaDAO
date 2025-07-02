const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Vesting Configuration Managers", function () {
    let karmaToken;
    let vestingVault;
    let teamVestingManager;
    let privateSaleVestingManager;
    let vestingTemplateManager;
    
    let owner, admin, teamManager, hrManager, investmentManager, compliance, governance;
    let teamMember1, teamMember2, investor1, investor2, beneficiary1, beneficiary2;
    
    const INITIAL_SUPPLY = ethers.parseEther("1000000000"); // 1B tokens
    const TEAM_ALLOCATION = ethers.parseEther("100000"); // 100K tokens per team member
    const INVESTOR_ALLOCATION = ethers.parseEther("500000"); // 500K tokens per investor
    
    // Time constants
    const TEAM_VESTING_DURATION = 4 * 365 * 24 * 60 * 60; // 4 years
    const TEAM_CLIFF_DURATION = 365 * 24 * 60 * 60; // 1 year
    const PRIVATE_SALE_VESTING_DURATION = 6 * 30 * 24 * 60 * 60; // 6 months
    const PRIVATE_SALE_CLIFF_DURATION = 0; // No cliff
    
    beforeEach(async function () {
        [owner, admin, teamManager, hrManager, investmentManager, compliance, governance,
         teamMember1, teamMember2, investor1, investor2, beneficiary1, beneficiary2] = await ethers.getSigners();
        
        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        karmaToken = await KarmaToken.deploy(admin.address);
        await karmaToken.waitForDeployment();
        
        // Deploy VestingVault
        const VestingVault = await ethers.getContractFactory("VestingVault");
        vestingVault = await VestingVault.deploy(await karmaToken.getAddress(), admin.address);
        await vestingVault.waitForDeployment();
        
        // Deploy TeamVestingManager
        const TeamVestingManager = await ethers.getContractFactory("TeamVestingManager");
        teamVestingManager = await TeamVestingManager.deploy(await vestingVault.getAddress(), admin.address);
        await teamVestingManager.waitForDeployment();
        
        // Deploy PrivateSaleVestingManager  
        const PrivateSaleVestingManager = await ethers.getContractFactory("PrivateSaleVestingManager");
        privateSaleVestingManager = await PrivateSaleVestingManager.deploy(await vestingVault.getAddress(), admin.address);
        await privateSaleVestingManager.waitForDeployment();
        
        // Deploy VestingTemplateManager
        const VestingTemplateManager = await ethers.getContractFactory("VestingTemplateManager");
        vestingTemplateManager = await VestingTemplateManager.deploy(await vestingVault.getAddress(), admin.address);
        await vestingTemplateManager.waitForDeployment();
        
        // Setup roles
        await teamVestingManager.connect(admin).grantRole(await teamVestingManager.TEAM_MANAGER_ROLE(), teamManager.address);
        await teamVestingManager.connect(admin).grantRole(await teamVestingManager.HR_ROLE(), hrManager.address);
        
        await privateSaleVestingManager.connect(admin).grantRole(await privateSaleVestingManager.INVESTMENT_MANAGER_ROLE(), investmentManager.address);
        await privateSaleVestingManager.connect(admin).grantRole(await privateSaleVestingManager.COMPLIANCE_ROLE(), compliance.address);
        
        await vestingTemplateManager.connect(admin).grantRole(await vestingTemplateManager.TEMPLATE_MANAGER_ROLE(), admin.address);
        await vestingTemplateManager.connect(admin).grantRole(await vestingTemplateManager.GOVERNANCE_ROLE(), governance.address);
        
        // Grant vesting manager role to configuration managers
        const VESTING_MANAGER_ROLE = await vestingVault.VESTING_MANAGER_ROLE();
        await vestingVault.connect(admin).grantRole(VESTING_MANAGER_ROLE, await teamVestingManager.getAddress());
        await vestingVault.connect(admin).grantRole(VESTING_MANAGER_ROLE, await privateSaleVestingManager.getAddress());
        await vestingVault.connect(admin).grantRole(VESTING_MANAGER_ROLE, await vestingTemplateManager.getAddress());
        
        // Mint tokens and approve vesting vault
        await karmaToken.connect(admin).mint(admin.address, INITIAL_SUPPLY);
        await karmaToken.connect(admin).transfer(await vestingVault.getAddress(), INITIAL_SUPPLY / 2n);
    });
    
    describe("TeamVestingManager", function () {
        describe("Team Member Management", function () {
            it("Should add team member successfully", async function () {
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Senior Developer",
                    TEAM_ALLOCATION
                );
                
                const memberDetails = await teamVestingManager.getTeamMemberDetails(teamMember1.address);
                expect(memberDetails.department).to.equal("Engineering");
                expect(memberDetails.role).to.equal("Senior Developer");
                expect(memberDetails.totalAllocation).to.equal(TEAM_ALLOCATION);
                expect(memberDetails.isActive).to.be.true;
            });
            
            it("Should create team vesting schedule", async function () {
                // Add team member first
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Senior Developer",
                    TEAM_ALLOCATION
                );
                
                // Create vesting schedule
                const tx = await teamVestingManager.connect(teamManager).createTeamVestingSchedule(
                    teamMember1.address,
                    TEAM_ALLOCATION,
                    0 // Start immediately
                );
                
                const receipt = await tx.wait();
                const event = receipt.logs.find(log => {
                    try {
                        return teamVestingManager.interface.parseLog(log).name === 'VestingScheduleCreated';
                    } catch {
                        return false;
                    }
                });
                
                expect(event).to.not.be.undefined;
                
                // Verify schedule was created in VestingVault
                const scheduleId = 1; // First schedule
                const schedule = await vestingVault.getVestingSchedule(scheduleId);
                expect(schedule.beneficiary).to.equal(teamMember1.address);
                expect(schedule.totalAmount).to.equal(TEAM_ALLOCATION);
                expect(schedule.cliffDuration).to.equal(TEAM_CLIFF_DURATION);
                expect(schedule.vestingDuration).to.equal(TEAM_VESTING_DURATION);
            });
            
            it("Should create batch team vesting schedules", async function () {
                // Add team members
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Senior Developer",
                    TEAM_ALLOCATION
                );
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember2.address,
                    "Marketing",
                    "Marketing Manager",
                    TEAM_ALLOCATION
                );
                
                // Create batch schedules
                const tx = await teamVestingManager.connect(teamManager).createTeamVestingSchedulesBatch(
                    [teamMember1.address, teamMember2.address],
                    [TEAM_ALLOCATION, TEAM_ALLOCATION],
                    [0, 0] // Start immediately
                );
                
                await tx.wait();
                
                // Verify both schedules were created
                const member1Details = await teamVestingManager.getBeneficiaryInfo(teamMember1.address);
                const member2Details = await teamVestingManager.getBeneficiaryInfo(teamMember2.address);
                
                expect(member1Details.schedulesCount).to.equal(1);
                expect(member2Details.schedulesCount).to.equal(1);
            });
            
            it("Should update team member information", async function () {
                // Add team member
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Junior Developer",
                    TEAM_ALLOCATION
                );
                
                // Update team member
                await teamVestingManager.connect(hrManager).updateTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Senior Developer",
                    true
                );
                
                const memberDetails = await teamVestingManager.getTeamMemberDetails(teamMember1.address);
                expect(memberDetails.role).to.equal("Senior Developer");
                expect(memberDetails.isActive).to.be.true;
            });
        });
        
        describe("Template Management", function () {
            it("Should get default team template", async function () {
                const template = await teamVestingManager.getVestingTemplate("TEAM");
                
                expect(template.name).to.equal("TEAM");
                expect(template.vestingDuration).to.equal(TEAM_VESTING_DURATION);
                expect(template.cliffDuration).to.equal(TEAM_CLIFF_DURATION);
                expect(template.isActive).to.be.true;
            });
            
            it("Should create custom team template", async function () {
                await teamVestingManager.connect(teamManager).createVestingTemplate(
                    "TEAM_EXECUTIVE",
                    5 * 365 * 24 * 60 * 60, // 5 years
                    365 * 24 * 60 * 60, // 1 year cliff
                    365 * 24 * 60 * 60, // Annual releases
                    "Executive team vesting: 5-year duration with 1-year cliff"
                );
                
                const template = await teamVestingManager.getVestingTemplate("TEAM_EXECUTIVE");
                expect(template.name).to.equal("TEAM_EXECUTIVE");
                expect(template.vestingDuration).to.equal(5 * 365 * 24 * 60 * 60);
            });
        });
        
        describe("Analytics", function () {
            it("Should track manager statistics", async function () {
                // Add team members
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Senior Developer",
                    TEAM_ALLOCATION
                );
                await teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember2.address,
                    "Marketing",
                    "Marketing Manager",
                    TEAM_ALLOCATION
                );
                
                const stats = await teamVestingManager.getManagerStatistics();
                expect(stats.totalBeneficiaries).to.equal(2);
                expect(stats.totalAllocation).to.equal(TEAM_ALLOCATION * 2n);
            });
        });
    });
    
    describe("PrivateSaleVestingManager", function () {
        describe("Investor Management", function () {
            it("Should add investor successfully", async function () {
                await privateSaleVestingManager.connect(compliance).addInvestor(
                    investor1.address,
                    ethers.parseEther("50000"), // $50K investment
                    "STANDARD",
                    false // Not accredited
                );
                
                const investorDetails = await privateSaleVestingManager.getInvestorDetails(investor1.address);
                expect(investorDetails.investmentAmount).to.equal(ethers.parseEther("50000"));
                expect(investorDetails.tier).to.equal("STANDARD");
                expect(investorDetails.kycStatus).to.equal("PENDING");
                expect(investorDetails.isAccredited).to.be.false;
            });
            
            it("Should update investor KYC status", async function () {
                // Add investor
                await privateSaleVestingManager.connect(compliance).addInvestor(
                    investor1.address,
                    ethers.parseEther("50000"),
                    "STANDARD",
                    false
                );
                
                // Update KYC status
                await privateSaleVestingManager.connect(compliance).updateInvestorKYC(
                    investor1.address,
                    "APPROVED"
                );
                
                const investorDetails = await privateSaleVestingManager.getInvestorDetails(investor1.address);
                expect(investorDetails.kycStatus).to.equal("APPROVED");
            });
            
            it("Should create investor vesting schedule", async function () {
                // Add and approve investor
                await privateSaleVestingManager.connect(compliance).addInvestor(
                    investor1.address,
                    ethers.parseEther("50000"),
                    "STANDARD",
                    false
                );
                await privateSaleVestingManager.connect(compliance).updateInvestorKYC(
                    investor1.address,
                    "APPROVED"
                );
                
                // Create vesting schedule
                const tx = await privateSaleVestingManager.connect(investmentManager).createInvestorVestingSchedule(
                    investor1.address,
                    INVESTOR_ALLOCATION,
                    0 // Start immediately
                );
                
                await tx.wait();
                
                // Verify schedule was created
                const scheduleId = 1;
                const schedule = await vestingVault.getVestingSchedule(scheduleId);
                expect(schedule.beneficiary).to.equal(investor1.address);
                expect(schedule.totalAmount).to.equal(INVESTOR_ALLOCATION);
                expect(schedule.cliffDuration).to.equal(PRIVATE_SALE_CLIFF_DURATION);
                expect(schedule.vestingDuration).to.equal(PRIVATE_SALE_VESTING_DURATION);
            });
        });
        
        describe("Template Management", function () {
            it("Should get default private sale template", async function () {
                const template = await privateSaleVestingManager.getVestingTemplate("PRIVATE_SALE");
                
                expect(template.name).to.equal("PRIVATE_SALE");
                expect(template.vestingDuration).to.equal(PRIVATE_SALE_VESTING_DURATION);
                expect(template.cliffDuration).to.equal(PRIVATE_SALE_CLIFF_DURATION);
                expect(template.isActive).to.be.true;
            });
        });
    });
    
    describe("VestingTemplateManager", function () {
        describe("Template Management", function () {
            it("Should have default templates", async function () {
                const templates = await vestingTemplateManager.getAvailableTemplates();
                expect(templates.length).to.be.greaterThan(0);
                
                // Check for default templates
                const teamTemplate = await vestingTemplateManager.getVestingTemplate("TEAM_STANDARD");
                expect(teamTemplate.name).to.equal("TEAM_STANDARD");
                
                const privateSaleTemplate = await vestingTemplateManager.getVestingTemplate("PRIVATE_SALE_STANDARD");
                expect(privateSaleTemplate.name).to.equal("PRIVATE_SALE_STANDARD");
                
                const communityTemplate = await vestingTemplateManager.getVestingTemplate("COMMUNITY_REWARDS");
                expect(communityTemplate.name).to.equal("COMMUNITY_REWARDS");
            });
            
            it("Should create custom template", async function () {
                await vestingTemplateManager.connect(admin).createVestingTemplate(
                    "CUSTOM_TEMPLATE",
                    365 * 24 * 60 * 60, // 1 year
                    30 * 24 * 60 * 60, // 1 month cliff
                    30 * 24 * 60 * 60, // Monthly releases
                    "Custom template for testing"
                );
                
                const template = await vestingTemplateManager.getVestingTemplate("CUSTOM_TEMPLATE");
                expect(template.name).to.equal("CUSTOM_TEMPLATE");
                expect(template.vestingDuration).to.equal(365 * 24 * 60 * 60);
                expect(template.cliffDuration).to.equal(30 * 24 * 60 * 60);
            });
            
            it("Should lock and unlock templates", async function () {
                // Lock template
                await vestingTemplateManager.connect(governance).lockTemplate("TEAM_STANDARD");
                
                const metadataBefore = await vestingTemplateManager.getTemplateMetadata("TEAM_STANDARD");
                expect(metadataBefore.isLocked).to.be.true;
                
                // Unlock template
                await vestingTemplateManager.connect(governance).unlockTemplate("TEAM_STANDARD");
                
                const metadataAfter = await vestingTemplateManager.getTemplateMetadata("TEAM_STANDARD");
                expect(metadataAfter.isLocked).to.be.false;
            });
        });
        
        describe("Category Management", function () {
            it("Should have default categories", async function () {
                const categories = await vestingTemplateManager.getAllCategories();
                expect(categories).to.include("TEAM");
                expect(categories).to.include("INVESTOR");
                expect(categories).to.include("COMMUNITY");
                expect(categories).to.include("CUSTOM");
            });
            
            it("Should get templates by category", async function () {
                const teamTemplates = await vestingTemplateManager.getTemplatesByCategory("TEAM");
                expect(teamTemplates).to.include("TEAM_STANDARD");
                
                const investorTemplates = await vestingTemplateManager.getTemplatesByCategory("INVESTOR");
                expect(investorTemplates).to.include("PRIVATE_SALE_STANDARD");
            });
            
            it("Should create new category", async function () {
                await vestingTemplateManager.connect(admin).createCategory("ADVISOR", "Advisor vesting schedules");
                
                const categories = await vestingTemplateManager.getAllCategories();
                expect(categories).to.include("ADVISOR");
            });
        });
        
        describe("Beneficiary Management", function () {
            it("Should register and manage beneficiaries", async function () {
                await vestingTemplateManager.connect(admin).registerBeneficiary(
                    beneficiary1.address,
                    "COMMUNITY",
                    ethers.parseEther("10000")
                );
                
                const beneficiaryInfo = await vestingTemplateManager.getBeneficiaryInfo(beneficiary1.address);
                expect(beneficiaryInfo.beneficiary).to.equal(beneficiary1.address);
                expect(beneficiaryInfo.beneficiaryType).to.equal("COMMUNITY");
                expect(beneficiaryInfo.totalAllocation).to.equal(ethers.parseEther("10000"));
            });
            
            it("Should create vesting schedule from template", async function () {
                // Register beneficiary
                await vestingTemplateManager.connect(admin).registerBeneficiary(
                    beneficiary1.address,
                    "COMMUNITY",
                    ethers.parseEther("10000")
                );
                
                // Create vesting schedule using template
                const tx = await vestingTemplateManager.connect(admin).createVestingScheduleFromTemplate(
                    beneficiary1.address,
                    "COMMUNITY_REWARDS",
                    ethers.parseEther("5000"),
                    0 // Start immediately
                );
                
                await tx.wait();
                
                // Verify schedule was created
                const beneficiaryInfo = await vestingTemplateManager.getBeneficiaryInfo(beneficiary1.address);
                expect(beneficiaryInfo.schedulesCount).to.equal(1);
            });
        });
        
        describe("Analytics", function () {
            it("Should track template usage", async function () {
                // Register beneficiary and create schedule
                await vestingTemplateManager.connect(admin).registerBeneficiary(
                    beneficiary1.address,
                    "COMMUNITY",
                    ethers.parseEther("10000")
                );
                
                await vestingTemplateManager.connect(admin).createVestingScheduleFromTemplate(
                    beneficiary1.address,
                    "COMMUNITY_REWARDS",
                    ethers.parseEther("5000"),
                    0
                );
                
                // Check template metadata
                const metadata = await vestingTemplateManager.getTemplateMetadata("COMMUNITY_REWARDS");
                expect(metadata.usageCount).to.equal(1);
            });
            
            it("Should get most used templates", async function () {
                // Create multiple schedules to generate usage data
                await vestingTemplateManager.connect(admin).registerBeneficiary(
                    beneficiary1.address,
                    "COMMUNITY",
                    ethers.parseEther("10000")
                );
                await vestingTemplateManager.connect(admin).registerBeneficiary(
                    beneficiary2.address,
                    "COMMUNITY",
                    ethers.parseEther("10000")
                );
                
                // Use COMMUNITY_REWARDS template multiple times
                await vestingTemplateManager.connect(admin).createVestingScheduleFromTemplate(
                    beneficiary1.address,
                    "COMMUNITY_REWARDS",
                    ethers.parseEther("5000"),
                    0
                );
                await vestingTemplateManager.connect(admin).createVestingScheduleFromTemplate(
                    beneficiary2.address,
                    "COMMUNITY_REWARDS",
                    ethers.parseEther("5000"),
                    0
                );
                
                const [templates, counts] = await vestingTemplateManager.getMostUsedTemplates(3);
                expect(templates[0]).to.equal("COMMUNITY_REWARDS");
                expect(counts[0]).to.equal(2);
            });
        });
    });
    
    describe("Integration Tests", function () {
        it("Should work together for end-to-end vesting management", async function () {
            // 1. Add team member via TeamVestingManager
            await teamVestingManager.connect(hrManager).addTeamMember(
                teamMember1.address,
                "Engineering",
                "Senior Developer",
                TEAM_ALLOCATION
            );
            
            // 2. Add investor via PrivateSaleVestingManager
            await privateSaleVestingManager.connect(compliance).addInvestor(
                investor1.address,
                ethers.parseEther("50000"),
                "STANDARD",
                false
            );
            await privateSaleVestingManager.connect(compliance).updateInvestorKYC(
                investor1.address,
                "APPROVED"
            );
            
            // 3. Add community member via VestingTemplateManager
            await vestingTemplateManager.connect(admin).registerBeneficiary(
                beneficiary1.address,
                "COMMUNITY",
                ethers.parseEther("10000")
            );
            
            // 4. Create vesting schedules
            await teamVestingManager.connect(teamManager).createTeamVestingSchedule(
                teamMember1.address,
                TEAM_ALLOCATION,
                0
            );
            
            await privateSaleVestingManager.connect(investmentManager).createInvestorVestingSchedule(
                investor1.address,
                INVESTOR_ALLOCATION,
                0
            );
            
            await vestingTemplateManager.connect(admin).createVestingScheduleFromTemplate(
                beneficiary1.address,
                "COMMUNITY_REWARDS",
                ethers.parseEther("5000"),
                0
            );
            
            // 5. Verify all schedules were created
            const teamSchedule = await vestingVault.getVestingSchedule(1);
            const investorSchedule = await vestingVault.getVestingSchedule(2);
            const communitySchedule = await vestingVault.getVestingSchedule(3);
            
            expect(teamSchedule.beneficiary).to.equal(teamMember1.address);
            expect(investorSchedule.beneficiary).to.equal(investor1.address);
            expect(communitySchedule.beneficiary).to.equal(beneficiary1.address);
            
            // Different vesting periods
            expect(teamSchedule.vestingDuration).to.equal(TEAM_VESTING_DURATION);
            expect(investorSchedule.vestingDuration).to.equal(PRIVATE_SALE_VESTING_DURATION);
            expect(communitySchedule.vestingDuration).to.equal(2 * 365 * 24 * 60 * 60); // Community rewards is 2 years
        });
    });
    
    describe("Access Control", function () {
        it("Should enforce role-based access control", async function () {
            // Team manager roles
            await expect(
                teamVestingManager.connect(investor1).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Developer",
                    TEAM_ALLOCATION
                )
            ).to.be.revertedWith("TeamVestingManager: caller is not HR");
            
            // Investment manager roles
            await expect(
                privateSaleVestingManager.connect(teamMember1).addInvestor(
                    investor1.address,
                    ethers.parseEther("50000"),
                    "STANDARD",
                    false
                )
            ).to.be.revertedWith("PrivateSaleVestingManager: caller is not compliance officer");
            
            // Template manager roles
            await expect(
                vestingTemplateManager.connect(investor1).createVestingTemplate(
                    "UNAUTHORIZED",
                    365 * 24 * 60 * 60,
                    0,
                    30 * 24 * 60 * 60,
                    "Unauthorized template"
                )
            ).to.be.revertedWith("VestingTemplateManager: caller is not template manager");
        });
    });
    
    describe("Emergency Controls", function () {
        it("Should support emergency pause/unpause", async function () {
            // Pause TeamVestingManager
            await teamVestingManager.connect(admin).emergencyPause();
            
            await expect(
                teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Developer",
                    TEAM_ALLOCATION
                )
            ).to.be.revertedWith("Pausable: paused");
            
            // Unpause
            await teamVestingManager.connect(admin).emergencyUnpause();
            
            // Should work again
            await expect(
                teamVestingManager.connect(hrManager).addTeamMember(
                    teamMember1.address,
                    "Engineering",
                    "Developer",
                    TEAM_ALLOCATION
                )
            ).to.not.be.reverted;
        });
    });
}); 