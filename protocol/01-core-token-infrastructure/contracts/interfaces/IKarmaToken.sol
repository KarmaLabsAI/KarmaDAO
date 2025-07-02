// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IKarmaToken
 * @dev Interface for the Karma token contract with enhanced features
 * Stage 1.1 - Core Token Infrastructure
 */
interface IKarmaToken is IERC20 {
    
    // ============ EVENTS ============
    
    event Minted(address indexed to, uint256 amount, string reason);
    event Burned(address indexed from, uint256 amount, string reason);
    event PauseStateChanged(bool isPaused, address indexed admin);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event TreasuryIntegration(address indexed treasury, uint256 amount, string operation);
    event BuybackBurnIntegration(address indexed buybackBurn, uint256 amount, string operation);
    event PaymasterIntegration(address indexed paymaster, uint256 amount, string operation);
    
    // ============ ROLES ============
    
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function MINTER_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function BURNER_ROLE() external view returns (bytes32);
    
    // ============ CORE FUNCTIONS ============
    
    function mint(address to, uint256 amount) external;
    function mintWithReason(address to, uint256 amount, string calldata reason) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function burnWithReason(uint256 amount, string calldata reason) external;
    function burnFromWithReason(address account, uint256 amount, string calldata reason) external;
    
    // ============ PAUSE FUNCTIONALITY ============
    
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    
    // ============ SUPPLY MANAGEMENT ============
    
    function maxSupply() external view returns (uint256);
    function remainingMintableSupply() external view returns (uint256);
    function canMint(uint256 amount) external view returns (bool);
    
    // ============ ROLE MANAGEMENT ============
    
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    
    // ============ INTEGRATION HOOKS ============
    
    function notifyTreasuryOperation(uint256 amount, string calldata operation) external;
    function notifyBuybackBurnOperation(uint256 amount, string calldata operation) external;
    function notifyPaymasterOperation(uint256 amount, string calldata operation) external;
    
    // ============ UTILITY FUNCTIONS ============
    
    function isAuthorizedMinter(address account) external view returns (bool);
    function isAuthorizedBurner(address account) external view returns (bool);
    function isAuthorizedPauser(address account) external view returns (bool);
    function getTokenInfo() external view returns (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        uint256 maxSupply,
        bool isPaused
    );
} 