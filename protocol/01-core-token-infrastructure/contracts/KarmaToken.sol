// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KarmaToken
 * @dev Implementation of the $KARMA token for the Karma Labs ecosystem
 * 
 * Key Features:
 * - ERC-20 compliance with minting and burning capabilities
 * - Role-based access control for administrative functions
 * - Pausable functionality for emergency scenarios
 * - Integration interfaces for VestingVault, Treasury, BuybackBurn, and Paymaster
 * - Total supply cap of 1 billion tokens
 * 
 * Roles:
 * - DEFAULT_ADMIN_ROLE: Can manage all roles and pause/unpause
 * - MINTER_ROLE: Can mint tokens (restricted to SaleManager and Treasury)
 * - PAUSER_ROLE: Can pause/unpause token operations
 */
contract KarmaToken is ERC20, ERC20Burnable, AccessControl, Pausable, ReentrancyGuard {
    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Token constants
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens
    
    // Integration contract addresses
    address public vestingVault;
    address public treasury;
    address public buybackBurn;
    address public paymaster;
    address public saleManager;
    
    // Events for integration tracking
    event VestingVaultSet(address indexed oldVault, address indexed newVault);
    event TreasurySet(address indexed oldTreasury, address indexed newTreasury);
    event BuybackBurnSet(address indexed oldBuybackBurn, address indexed newBuybackBurn);
    event PaymasterSet(address indexed oldPaymaster, address indexed newPaymaster);
    event SaleManagerSet(address indexed oldSaleManager, address indexed newSaleManager);
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount);
    event EmergencyPause(address indexed pauser);
    event EmergencyUnpause(address indexed unpauser);
    
    /**
     * @dev Constructor sets up the token with initial admin
     * @param initialAdmin Address that will receive DEFAULT_ADMIN_ROLE
     */
    constructor(address initialAdmin) ERC20("Karma Token", "KARMA") {
        require(initialAdmin != address(0), "KarmaToken: Invalid admin address");
        
        // Grant initial admin all roles
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);
    }
    
    /**
     * @dev Mints tokens to specified address
     * @param to Address to receive tokens
     * @param amount Amount of tokens to mint
     * Requirements:
     * - Caller must have MINTER_ROLE
     * - Contract must not be paused
     * - Total supply after minting must not exceed MAX_SUPPLY
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(to != address(0), "KarmaToken: Cannot mint to zero address");
        require(amount > 0, "KarmaToken: Amount must be greater than zero");
        require(totalSupply() + amount <= MAX_SUPPLY, "KarmaToken: Exceeds maximum supply");
        
        _mint(to, amount);
        emit TokensMinted(to, amount, msg.sender);
    }
    
    /**
     * @dev Burns tokens from the caller's account
     * @param amount Amount of tokens to burn
     * Overrides ERC20Burnable to add event emission
     */
    function burn(uint256 amount) public override whenNotPaused {
        super.burn(amount);
        emit TokensBurned(msg.sender, amount);
    }
    
    /**
     * @dev Burns tokens from specified account (requires allowance)
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     * Overrides ERC20Burnable to add event emission
     */
    function burnFrom(address account, uint256 amount) public override whenNotPaused {
        super.burnFrom(account, amount);
        emit TokensBurned(account, amount);
    }
    
    /**
     * @dev Pauses all token operations
     * Can only be called by addresses with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit EmergencyPause(msg.sender);
    }
    
    /**
     * @dev Unpauses all token operations
     * Can only be called by addresses with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit EmergencyUnpause(msg.sender);
    }
    
    // ============ INTEGRATION CONTRACT SETTERS ============
    
    /**
     * @dev Sets the VestingVault contract address
     * @param _vestingVault Address of the VestingVault contract
     */
    function setVestingVault(address _vestingVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_vestingVault != address(0), "KarmaToken: Invalid VestingVault address");
        address oldVault = vestingVault;
        vestingVault = _vestingVault;
        emit VestingVaultSet(oldVault, _vestingVault);
    }
    
    /**
     * @dev Sets the Treasury contract address
     * @param _treasury Address of the Treasury contract
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "KarmaToken: Invalid Treasury address");
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasurySet(oldTreasury, _treasury);
    }
    
    /**
     * @dev Sets the BuybackBurn contract address
     * @param _buybackBurn Address of the BuybackBurn contract
     */
    function setBuybackBurn(address _buybackBurn) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_buybackBurn != address(0), "KarmaToken: Invalid BuybackBurn address");
        address oldBuybackBurn = buybackBurn;
        buybackBurn = _buybackBurn;
        emit BuybackBurnSet(oldBuybackBurn, _buybackBurn);
    }
    
    /**
     * @dev Sets the Paymaster contract address
     * @param _paymaster Address of the Paymaster contract
     */
    function setPaymaster(address _paymaster) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_paymaster != address(0), "KarmaToken: Invalid Paymaster address");
        address oldPaymaster = paymaster;
        paymaster = _paymaster;
        emit PaymasterSet(oldPaymaster, _paymaster);
    }
    
    /**
     * @dev Sets the SaleManager contract address and grants it MINTER_ROLE
     * @param _saleManager Address of the SaleManager contract
     */
    function setSaleManager(address _saleManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_saleManager != address(0), "KarmaToken: Invalid SaleManager address");
        
        // Revoke MINTER_ROLE from old SaleManager if it exists
        if (saleManager != address(0)) {
            _revokeRole(MINTER_ROLE, saleManager);
        }
        
        address oldSaleManager = saleManager;
        saleManager = _saleManager;
        
        // Grant MINTER_ROLE to new SaleManager
        _grantRole(MINTER_ROLE, _saleManager);
        
        emit SaleManagerSet(oldSaleManager, _saleManager);
    }
    
    // ============ PAYMASTER INTEGRATION HOOKS ============
    
    /**
     * @dev Hook for Paymaster to sponsor gas for specific operations
     * This function allows the Paymaster to validate sponsored transactions
     * @param user Address of the user making the transaction
     * @param operation Type of operation being performed
     * @return bool Whether the operation is eligible for gas sponsorship
     */
    function isOperationSponsored(address user, bytes4 operation) 
        external 
        view 
        returns (bool) 
    {
        // Only allow calls from the registered Paymaster
        if (msg.sender != paymaster || paymaster == address(0)) {
            return false;
        }
        
        // Define sponsored operations (transfers for platform fees, etc.)
        bytes4 transferSig = bytes4(keccak256("transfer(address,uint256)"));
        bytes4 transferFromSig = bytes4(keccak256("transferFrom(address,address,uint256)"));
        
        return (operation == transferSig || operation == transferFromSig);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Returns the remaining mintable supply
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
    
    /**
     * @dev Returns information about integration contracts
     */
    function getIntegrationContracts() 
        external 
        view 
        returns (
            address _vestingVault,
            address _treasury,
            address _buybackBurn,
            address _paymaster,
            address _saleManager
        ) 
    {
        return (vestingVault, treasury, buybackBurn, paymaster, saleManager);
    }
    
    // ============ OVERRIDES ============
    
    /**
     * @dev Override to add pause functionality to transfers
     */
    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }
    
    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency function to recover accidentally sent tokens
     * Can only be called by DEFAULT_ADMIN_ROLE
     * @param token Address of the token to recover
     * @param amount Amount to recover
     */
    function emergencyTokenRecovery(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(token != address(this), "KarmaToken: Cannot recover KARMA tokens");
        require(token != address(0), "KarmaToken: Invalid token address");
        
        IERC20(token).transfer(msg.sender, amount);
    }
} 