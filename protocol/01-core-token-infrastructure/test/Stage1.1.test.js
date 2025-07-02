/**
 * Stage 1.1 - KarmaToken Contract Development Tests
 * Comprehensive tests for the core ERC-20 token implementation
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// Load constants
const constants = require("../utils/constants.js");

describe("Stage 1.1 - KarmaToken Contract Development", function () {
    
    // Test fixture for deploying contracts
    async function deployKarmaTokenFixture() {
        const [deployer, admin, minter, pauser, burner, user1, user2, unauthorized] = await ethers.getSigners();

        // Deploy KarmaToken
        const KarmaToken = await ethers.getContractFactory("KarmaToken");
        const karmaToken = await KarmaToken.deploy(
            constants.TOKEN_CONSTANTS.NAME,
            constants.TOKEN_CONSTANTS.SYMBOL,
            constants.TOKEN_CONSTANTS.MAX_SUPPLY_WEI,
            admin.address
        );

        // Setup roles
        await karmaToken.connect(admin).grantRole(constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE, minter.address);
        await karmaToken.connect(admin).grantRole(constants.TOKEN_CONSTANTS.ROLES.PAUSER_ROLE, pauser.address);
        await karmaToken.connect(admin).grantRole(constants.TOKEN_CONSTANTS.ROLES.BURNER_ROLE, burner.address);

        return {
            karmaToken,
            deployer,
            admin,
            minter,
            pauser,
            burner,
            user1,
            user2,
            unauthorized
        };
    }

    describe("Core ERC-20 Implementation", function () {
        
        it("Should deploy with correct initial parameters", async function () {
            const { karmaToken } = await loadFixture(deployKarmaTokenFixture);

            const tokenInfo = await karmaToken.getTokenInfo();
            
            expect(tokenInfo.name).to.equal(constants.TOKEN_CONSTANTS.NAME);
            expect(tokenInfo.symbol).to.equal(constants.TOKEN_CONSTANTS.SYMBOL);
            expect(tokenInfo.decimals).to.equal(constants.TOKEN_CONSTANTS.DECIMALS);
            expect(tokenInfo.totalSupply).to.equal(0);
            expect(tokenInfo.maxSupply).to.equal(constants.TOKEN_CONSTANTS.MAX_SUPPLY_WEI);
            expect(tokenInfo.isPaused).to.equal(false);
        });

        it("Should have zero initial supply", async function () {
            const { karmaToken } = await loadFixture(deployKarmaTokenFixture);
            
            expect(await karmaToken.totalSupply()).to.equal(0);
        });

        it("Should set correct max supply", async function () {
            const { karmaToken } = await loadFixture(deployKarmaTokenFixture);
            
            expect(await karmaToken.maxSupply()).to.equal(constants.TOKEN_CONSTANTS.MAX_SUPPLY_WEI);
        });

        it("Should grant correct initial roles", async function () {
            const { karmaToken, admin } = await loadFixture(deployKarmaTokenFixture);
            
            expect(await karmaToken.hasRole(constants.TOKEN_CONSTANTS.ROLES.DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
        });
    });

    describe("Administrative Features", function () {
        
        describe("Role-Based Access Control", function () {
            
            it("Should grant MINTER_ROLE correctly", async function () {
                const { karmaToken, admin, minter } = await loadFixture(deployKarmaTokenFixture);
                
                expect(await karmaToken.hasRole(constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE, minter.address)).to.be.true;
                expect(await karmaToken.isAuthorizedMinter(minter.address)).to.be.true;
            });

            it("Should grant PAUSER_ROLE correctly", async function () {
                const { karmaToken, pauser } = await loadFixture(deployKarmaTokenFixture);
                
                expect(await karmaToken.hasRole(constants.TOKEN_CONSTANTS.ROLES.PAUSER_ROLE, pauser.address)).to.be.true;
                expect(await karmaToken.isAuthorizedPauser(pauser.address)).to.be.true;
            });

            it("Should grant BURNER_ROLE correctly", async function () {
                const { karmaToken, burner } = await loadFixture(deployKarmaTokenFixture);
                
                expect(await karmaToken.hasRole(constants.TOKEN_CONSTANTS.ROLES.BURNER_ROLE, burner.address)).to.be.true;
                expect(await karmaToken.isAuthorizedBurner(burner.address)).to.be.true;
            });

            it("Should allow admin to grant roles", async function () {
                const { karmaToken, admin, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                await karmaToken.connect(admin).grantRole(constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE, user1.address);
                
                expect(await karmaToken.hasRole(constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE, user1.address)).to.be.true;
            });

            it("Should allow admin to revoke roles", async function () {
                const { karmaToken, admin, minter } = await loadFixture(deployKarmaTokenFixture);
                
                await karmaToken.connect(admin).revokeRole(constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE, minter.address);
                
                expect(await karmaToken.hasRole(constants.TOKEN_CONSTANTS.ROLES.MINTER_ROLE, minter.address)).to.be.false;
            });
        });

        describe("Minting Function", function () {
            
            it("Should allow authorized minter to mint tokens", async function () {
                const { karmaToken, minter, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const mintAmount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
                
                await expect(karmaToken.connect(minter).mint(user1.address, mintAmount))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.MINTED)
                    .withArgs(user1.address, mintAmount, "");
                
                expect(await karmaToken.balanceOf(user1.address)).to.equal(mintAmount);
                expect(await karmaToken.totalSupply()).to.equal(mintAmount);
            });

            it("Should allow minting with reason", async function () {
                const { karmaToken, minter, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const mintAmount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
                const reason = "Test minting";
                
                await expect(karmaToken.connect(minter).mintWithReason(user1.address, mintAmount, reason))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.MINTED)
                    .withArgs(user1.address, mintAmount, reason);
                
                expect(await karmaToken.balanceOf(user1.address)).to.equal(mintAmount);
            });

            it("Should prevent minting beyond max supply", async function () {
                const { karmaToken, minter, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const excessiveAmount = ethers.BigNumber.from(constants.TOKEN_CONSTANTS.MAX_SUPPLY_WEI).add(1);
                
                await expect(karmaToken.connect(minter).mint(user1.address, excessiveAmount))
                    .to.be.revertedWith(constants.ERROR_MESSAGES.TOKEN.EXCEEDS_MAX_SUPPLY);
            });

            it("Should prevent unauthorized minting", async function () {
                const { karmaToken, unauthorized, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const mintAmount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
                
                await expect(karmaToken.connect(unauthorized).mint(user1.address, mintAmount))
                    .to.be.revertedWith(constants.ERROR_MESSAGES.ACCESS_CONTROL.UNAUTHORIZED);
            });
        });

        describe("Burning Function", function () {
            
            beforeEach(async function () {
                const { karmaToken, minter, user1 } = await loadFixture(deployKarmaTokenFixture);
                const mintAmount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
                await karmaToken.connect(minter).mint(user1.address, mintAmount);
            });

            it("Should allow token holders to burn their tokens", async function () {
                const { karmaToken, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const burnAmount = constants.TESTING_CONSTANTS.AMOUNTS.BURN_AMOUNT;
                const initialBalance = await karmaToken.balanceOf(user1.address);
                
                await expect(karmaToken.connect(user1).burn(burnAmount))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.BURNED)
                    .withArgs(user1.address, burnAmount, "");
                
                expect(await karmaToken.balanceOf(user1.address)).to.equal(initialBalance.sub(burnAmount));
            });

            it("Should allow authorized burner to burn tokens from account", async function () {
                const { karmaToken, burner, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const burnAmount = constants.TESTING_CONSTANTS.AMOUNTS.BURN_AMOUNT;
                const initialBalance = await karmaToken.balanceOf(user1.address);
                
                // First approve the burner
                await karmaToken.connect(user1).approve(burner.address, burnAmount);
                
                await expect(karmaToken.connect(burner).burnFrom(user1.address, burnAmount))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.BURNED)
                    .withArgs(user1.address, burnAmount, "");
                
                expect(await karmaToken.balanceOf(user1.address)).to.equal(initialBalance.sub(burnAmount));
            });

            it("Should allow burning with reason", async function () {
                const { karmaToken, user1 } = await loadFixture(deployKarmaTokenFixture);
                
                const burnAmount = constants.TESTING_CONSTANTS.AMOUNTS.BURN_AMOUNT;
                const reason = "Buyback and burn";
                
                await expect(karmaToken.connect(user1).burnWithReason(burnAmount, reason))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.BURNED)
                    .withArgs(user1.address, burnAmount, reason);
            });
        });

        describe("Pause Functionality", function () {
            
            it("Should allow authorized pauser to pause contract", async function () {
                const { karmaToken, pauser } = await loadFixture(deployKarmaTokenFixture);
                
                await expect(karmaToken.connect(pauser).pause())
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.PAUSE_STATE_CHANGED)
                    .withArgs(true, pauser.address);
                
                expect(await karmaToken.paused()).to.be.true;
            });

            it("Should allow authorized pauser to unpause contract", async function () {
                const { karmaToken, pauser } = await loadFixture(deployKarmaTokenFixture);
                
                await karmaToken.connect(pauser).pause();
                
                await expect(karmaToken.connect(pauser).unpause())
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.PAUSE_STATE_CHANGED)
                    .withArgs(false, pauser.address);
                
                expect(await karmaToken.paused()).to.be.false;
            });

            it("Should prevent transfers when paused", async function () {
                const { karmaToken, minter, pauser, user1, user2 } = await loadFixture(deployKarmaTokenFixture);
                
                // Mint tokens and pause
                await karmaToken.connect(minter).mint(user1.address, constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT);
                await karmaToken.connect(pauser).pause();
                
                await expect(karmaToken.connect(user1).transfer(user2.address, constants.TESTING_CONSTANTS.AMOUNTS.SMALL_AMOUNT))
                    .to.be.revertedWith(constants.ERROR_MESSAGES.TOKEN.PAUSED);
            });

            it("Should prevent unauthorized pausing", async function () {
                const { karmaToken, unauthorized } = await loadFixture(deployKarmaTokenFixture);
                
                await expect(karmaToken.connect(unauthorized).pause())
                    .to.be.revertedWith(constants.ERROR_MESSAGES.ACCESS_CONTROL.UNAUTHORIZED);
            });
        });
    });

    describe("Integration Interfaces", function () {
        
        describe("Treasury Integration", function () {
            
            it("Should emit treasury integration event", async function () {
                const { karmaToken, admin } = await loadFixture(deployKarmaTokenFixture);
                
                const amount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
                const operation = "Fund allocation";
                
                await expect(karmaToken.connect(admin).notifyTreasuryOperation(amount, operation))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.TREASURY_INTEGRATION)
                    .withArgs(admin.address, amount, operation);
            });
        });

        describe("BuybackBurn Integration", function () {
            
            it("Should emit buyback burn integration event", async function () {
                const { karmaToken, admin } = await loadFixture(deployKarmaTokenFixture);
                
                const amount = constants.TESTING_CONSTANTS.AMOUNTS.BURN_AMOUNT;
                const operation = "Automated buyback";
                
                await expect(karmaToken.connect(admin).notifyBuybackBurnOperation(amount, operation))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.BUYBACK_BURN_INTEGRATION)
                    .withArgs(admin.address, amount, operation);
            });
        });

        describe("Paymaster Integration", function () {
            
            it("Should emit paymaster integration event", async function () {
                const { karmaToken, admin } = await loadFixture(deployKarmaTokenFixture);
                
                const amount = constants.TESTING_CONSTANTS.AMOUNTS.SMALL_AMOUNT;
                const operation = "Gas sponsorship";
                
                await expect(karmaToken.connect(admin).notifyPaymasterOperation(amount, operation))
                    .to.emit(karmaToken, constants.EVENTS.TOKEN.PAYMASTER_INTEGRATION)
                    .withArgs(admin.address, amount, operation);
            });
        });
    });

    describe("Supply Management", function () {
        
        it("Should track remaining mintable supply correctly", async function () {
            const { karmaToken, minter, user1 } = await loadFixture(deployKarmaTokenFixture);
            
            const mintAmount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
            const maxSupply = await karmaToken.maxSupply();
            
            await karmaToken.connect(minter).mint(user1.address, mintAmount);
            
            const remainingSupply = await karmaToken.remainingMintableSupply();
            expect(remainingSupply).to.equal(maxSupply.sub(mintAmount));
        });

        it("Should validate minting capability correctly", async function () {
            const { karmaToken, minter, user1 } = await loadFixture(deployKarmaTokenFixture);
            
            const mintAmount = constants.TESTING_CONSTANTS.AMOUNTS.MINT_AMOUNT;
            const largeAmount = constants.TESTING_CONSTANTS.AMOUNTS.LARGE_AMOUNT;
            
            expect(await karmaToken.canMint(mintAmount)).to.be.true;
            expect(await karmaToken.canMint(largeAmount)).to.be.false;
        });
    });

    describe("Utility Functions", function () {
        
        it("Should return correct token info", async function () {
            const { karmaToken } = await loadFixture(deployKarmaTokenFixture);
            
            const tokenInfo = await karmaToken.getTokenInfo();
            
            expect(tokenInfo.name).to.equal(constants.TOKEN_CONSTANTS.NAME);
            expect(tokenInfo.symbol).to.equal(constants.TOKEN_CONSTANTS.SYMBOL);
            expect(tokenInfo.decimals).to.equal(constants.TOKEN_CONSTANTS.DECIMALS);
            expect(tokenInfo.maxSupply).to.equal(constants.TOKEN_CONSTANTS.MAX_SUPPLY_WEI);
        });

        it("Should check authorization status correctly", async function () {
            const { karmaToken, minter, pauser, burner, unauthorized } = await loadFixture(deployKarmaTokenFixture);
            
            expect(await karmaToken.isAuthorizedMinter(minter.address)).to.be.true;
            expect(await karmaToken.isAuthorizedPauser(pauser.address)).to.be.true;
            expect(await karmaToken.isAuthorizedBurner(burner.address)).to.be.true;
            
            expect(await karmaToken.isAuthorizedMinter(unauthorized.address)).to.be.false;
            expect(await karmaToken.isAuthorizedPauser(unauthorized.address)).to.be.false;
            expect(await karmaToken.isAuthorizedBurner(unauthorized.address)).to.be.false;
        });
    });

    it("Should initialize test environment", async function () {
        const [deployer] = await ethers.getSigners();
        expect(deployer.address).to.be.properAddress;
    });

    it("Should pass basic test", async function () {
        expect(true).to.be.true;
    });
}); 