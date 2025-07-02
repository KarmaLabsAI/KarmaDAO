// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CrossChainBridge
 * @dev Cross-chain asset bridging between Arbitrum and 0G blockchain
 * @notice Enables KARMA token transfers and asset bridging for AI payments
 */
contract CrossChainBridge is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    bytes32 public constant BRIDGE_OPERATOR_ROLE = keccak256("BRIDGE_OPERATOR_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant CONFIG_MANAGER_ROLE = keccak256("CONFIG_MANAGER_ROLE");
    
    // ============ EVENTS ============
    
    event AssetLocked(
        bytes32 indexed bridgeId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 targetChainId,
        string targetAddress
    );
    
    event AssetReleased(
        bytes32 indexed bridgeId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 sourceChainId
    );
    
    event BridgeCompleted(
        bytes32 indexed bridgeId,
        address indexed user,
        uint256 amount,
        uint256 fee,
        bool success
    );
    
    event ValidatorSignature(
        bytes32 indexed bridgeId,
        address indexed validator,
        bool approved
    );
    
    event BridgeConfigUpdated(
        uint256 minAmount,
        uint256 maxAmount,
        uint256 bridgeFee,
        uint256 validationThreshold
    );
    
    // ============ ENUMS ============
    
    enum BridgeStatus {
        INITIATED,
        VALIDATED,
        COMPLETED,
        FAILED,
        CANCELLED
    }
    
    enum AssetType {
        KARMA_TOKEN,
        NFT,
        OTHER_TOKEN
    }
    
    // ============ STRUCTS ============
    
    struct BridgeRequest {
        bytes32 bridgeId;
        address user;
        address token;
        uint256 amount;
        uint256 sourceChainId;
        uint256 targetChainId;
        string targetAddress;
        AssetType assetType;
        BridgeStatus status;
        uint256 timestamp;
        uint256 fee;
        uint256 validatorSignatures;
        mapping(address => bool) hasValidated;
    }
    
    struct BridgeConfig {
        uint256 minAmount;          // Minimum bridge amount
        uint256 maxAmount;          // Maximum bridge amount
        uint256 bridgeFee;          // Bridge fee in basis points (100 = 1%)
        uint256 validationThreshold; // Required validator signatures
        uint256 timeoutPeriod;      // Bridge timeout in seconds
        bool isActive;              // Bridge active status
    }
    
    struct ChainConfig {
        uint256 chainId;
        string bridgeAddress;
        string rpcUrl;
        uint256 gasLimit;
        bool isSupported;
    }
    
    // ============ STATE VARIABLES ============
    
    IERC20 public karmaToken;
    BridgeConfig public bridgeConfig;
    
    // Bridge requests
    mapping(bytes32 => BridgeRequest) public bridgeRequests;
    mapping(address => bytes32[]) public userBridgeHistory;
    
    // Supported chains and tokens
    mapping(uint256 => ChainConfig) public supportedChains;
    mapping(address => bool) public supportedTokens;
    
    // Validators
    address[] public validators;
    mapping(address => bool) public isValidator;
    mapping(address => uint256) public validatorStake;
    
    // Statistics
    uint256 public totalBridged;
    uint256 public totalFees;
    uint256 public bridgeCounter;
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address _karmaToken,
        address _admin,
        address[] memory _validators
    ) {
        require(_karmaToken != address(0), "CrossChainBridge: Invalid karma token");
        require(_admin != address(0), "CrossChainBridge: Invalid admin");
        
        karmaToken = IERC20(_karmaToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(BRIDGE_OPERATOR_ROLE, _admin);
        _grantRole(CONFIG_MANAGER_ROLE, _admin);
        
        // Set up validators
        for (uint256 i = 0; i < _validators.length; i++) {
            _grantRole(VALIDATOR_ROLE, _validators[i]);
            validators.push(_validators[i]);
            isValidator[_validators[i]] = true;
        }
        
        // Initialize bridge configuration
        bridgeConfig = BridgeConfig({
            minAmount: 100 ether,        // 100 KARMA minimum
            maxAmount: 1000000 ether,    // 1M KARMA maximum
            bridgeFee: 100,              // 1% fee
            validationThreshold: (_validators.length * 2) / 3 + 1, // 2/3 + 1 threshold
            timeoutPeriod: 24 * 60 * 60, // 24 hours
            isActive: true
        });
        
        // Mark KARMA token as supported
        supportedTokens[_karmaToken] = true;
    }
    
    // ============ MODIFIERS ============
    
    modifier onlyBridgeOperator() {
        require(hasRole(BRIDGE_OPERATOR_ROLE, msg.sender), "CrossChainBridge: Not bridge operator");
        _;
    }
    
    modifier onlyValidator() {
        require(hasRole(VALIDATOR_ROLE, msg.sender), "CrossChainBridge: Not validator");
        _;
    }
    
    modifier onlyConfigManager() {
        require(hasRole(CONFIG_MANAGER_ROLE, msg.sender), "CrossChainBridge: Not config manager");
        _;
    }
    
    modifier validBridgeRequest(bytes32 bridgeId) {
        require(bridgeRequests[bridgeId].bridgeId != bytes32(0), "CrossChainBridge: Invalid bridge ID");
        _;
    }
    
    // ============ CORE BRIDGE FUNCTIONS ============
    
    /**
     * @dev Initiate asset bridge to 0G blockchain
     * @param token Token address to bridge
     * @param amount Amount to bridge
     * @param targetChainId Target chain ID (0G blockchain)
     * @param targetAddress Target address on 0G chain
     * @return bridgeId Unique bridge identifier
     */
    function bridgeToZeroG(
        address token,
        uint256 amount,
        uint256 targetChainId,
        string memory targetAddress
    ) external nonReentrant whenNotPaused returns (bytes32 bridgeId) {
        require(supportedTokens[token], "CrossChainBridge: Token not supported");
        require(supportedChains[targetChainId].isSupported, "CrossChainBridge: Chain not supported");
        require(amount >= bridgeConfig.minAmount, "CrossChainBridge: Amount below minimum");
        require(amount <= bridgeConfig.maxAmount, "CrossChainBridge: Amount above maximum");
        require(bytes(targetAddress).length > 0, "CrossChainBridge: Invalid target address");
        
        // Calculate bridge fee
        uint256 fee = (amount * bridgeConfig.bridgeFee) / 10000;
        uint256 netAmount = amount - fee;
        
        // Generate unique bridge ID
        bridgeCounter++;
        bridgeId = keccak256(abi.encodePacked(
            msg.sender,
            token,
            amount,
            targetChainId,
            block.timestamp,
            bridgeCounter
        ));
        
        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Create bridge request
        BridgeRequest storage request = bridgeRequests[bridgeId];
        request.bridgeId = bridgeId;
        request.user = msg.sender;
        request.token = token;
        request.amount = netAmount;
        request.sourceChainId = block.chainid;
        request.targetChainId = targetChainId;
        request.targetAddress = targetAddress;
        request.assetType = _getAssetType(token);
        request.status = BridgeStatus.INITIATED;
        request.timestamp = block.timestamp;
        request.fee = fee;
        request.validatorSignatures = 0;
        
        // Update user history
        userBridgeHistory[msg.sender].push(bridgeId);
        
        // Update statistics
        totalBridged += netAmount;
        totalFees += fee;
        
        emit AssetLocked(bridgeId, msg.sender, token, netAmount, targetChainId, targetAddress);
        
        return bridgeId;
    }
    
    /**
     * @dev Release assets from 0G blockchain bridge
     * @param bridgeId Bridge identifier
     * @param user Recipient user
     * @param token Token address
     * @param amount Amount to release
     * @param sourceChainId Source chain ID
     */
    function releaseFromZeroG(
        bytes32 bridgeId,
        address user,
        address token,
        uint256 amount,
        uint256 sourceChainId
    ) external onlyBridgeOperator nonReentrant {
        require(supportedTokens[token], "CrossChainBridge: Token not supported");
        require(user != address(0), "CrossChainBridge: Invalid user");
        require(amount > 0, "CrossChainBridge: Invalid amount");
        
        // Verify sufficient balance
        require(IERC20(token).balanceOf(address(this)) >= amount, "CrossChainBridge: Insufficient balance");
        
        // Transfer tokens to user
        IERC20(token).safeTransfer(user, amount);
        
        emit AssetReleased(bridgeId, user, token, amount, sourceChainId);
    }
    
    /**
     * @dev Validate bridge request (for validators)
     * @param bridgeId Bridge identifier
     * @param approved Whether to approve the bridge
     */
    function validateBridge(
        bytes32 bridgeId,
        bool approved
    ) external onlyValidator validBridgeRequest(bridgeId) {
        BridgeRequest storage request = bridgeRequests[bridgeId];
        
        require(request.status == BridgeStatus.INITIATED, "CrossChainBridge: Invalid status");
        require(!request.hasValidated[msg.sender], "CrossChainBridge: Already validated");
        require(block.timestamp <= request.timestamp + bridgeConfig.timeoutPeriod, "CrossChainBridge: Request expired");
        
        request.hasValidated[msg.sender] = true;
        
        if (approved) {
            request.validatorSignatures++;
            
            // Check if threshold reached
            if (request.validatorSignatures >= bridgeConfig.validationThreshold) {
                request.status = BridgeStatus.VALIDATED;
                _processBridge(bridgeId);
            }
        }
        
        emit ValidatorSignature(bridgeId, msg.sender, approved);
    }
    
    /**
     * @dev Process validated bridge request
     * @param bridgeId Bridge identifier
     */
    function _processBridge(bytes32 bridgeId) internal {
        BridgeRequest storage request = bridgeRequests[bridgeId];
        
        // In production, this would trigger cross-chain transaction
        // For now, mark as completed
        request.status = BridgeStatus.COMPLETED;
        
        emit BridgeCompleted(bridgeId, request.user, request.amount, request.fee, true);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get bridge request details
     * @param bridgeId Bridge identifier
     * @return Bridge request details
     */
    function getBridgeRequest(bytes32 bridgeId) 
        external 
        view 
        returns (
            address user,
            address token,
            uint256 amount,
            uint256 sourceChainId,
            uint256 targetChainId,
            string memory targetAddress,
            AssetType assetType,
            BridgeStatus status,
            uint256 timestamp,
            uint256 fee,
            uint256 validatorSignatures
        ) 
    {
        BridgeRequest storage request = bridgeRequests[bridgeId];
        return (
            request.user,
            request.token,
            request.amount,
            request.sourceChainId,
            request.targetChainId,
            request.targetAddress,
            request.assetType,
            request.status,
            request.timestamp,
            request.fee,
            request.validatorSignatures
        );
    }
    
    /**
     * @dev Get user bridge history
     * @param user User address
     * @return Array of bridge IDs
     */
    function getUserBridgeHistory(address user) external view returns (bytes32[] memory) {
        return userBridgeHistory[user];
    }
    
    /**
     * @dev Get bridge statistics
     * @return totalBridgedAmount Total amount bridged
     * @return totalFeesCollected Total fees collected
     * @return totalBridges Total number of bridges
     */
    function getBridgeStatistics() 
        external 
        view 
        returns (uint256 totalBridgedAmount, uint256 totalFeesCollected, uint256 totalBridges) 
    {
        return (totalBridged, totalFees, bridgeCounter);
    }
    
    // ============ CONFIGURATION FUNCTIONS ============
    
    /**
     * @dev Update bridge configuration
     * @param minAmount Minimum bridge amount
     * @param maxAmount Maximum bridge amount
     * @param bridgeFee Bridge fee in basis points
     * @param validationThreshold Required validator signatures
     */
    function updateBridgeConfig(
        uint256 minAmount,
        uint256 maxAmount,
        uint256 bridgeFee,
        uint256 validationThreshold
    ) external onlyConfigManager {
        require(minAmount > 0, "CrossChainBridge: Invalid min amount");
        require(maxAmount > minAmount, "CrossChainBridge: Invalid max amount");
        require(bridgeFee <= 1000, "CrossChainBridge: Fee too high"); // Max 10%
        require(validationThreshold > 0 && validationThreshold <= validators.length, "CrossChainBridge: Invalid threshold");
        
        bridgeConfig.minAmount = minAmount;
        bridgeConfig.maxAmount = maxAmount;
        bridgeConfig.bridgeFee = bridgeFee;
        bridgeConfig.validationThreshold = validationThreshold;
        
        emit BridgeConfigUpdated(minAmount, maxAmount, bridgeFee, validationThreshold);
    }
    
    /**
     * @dev Add supported chain
     * @param chainId Chain ID
     * @param bridgeAddress Bridge contract address on target chain
     * @param rpcUrl RPC URL for the chain
     * @param gasLimit Gas limit for cross-chain calls
     */
    function addSupportedChain(
        uint256 chainId,
        string memory bridgeAddress,
        string memory rpcUrl,
        uint256 gasLimit
    ) external onlyConfigManager {
        supportedChains[chainId] = ChainConfig({
            chainId: chainId,
            bridgeAddress: bridgeAddress,
            rpcUrl: rpcUrl,
            gasLimit: gasLimit,
            isSupported: true
        });
    }
    
    /**
     * @dev Add supported token
     * @param token Token address
     */
    function addSupportedToken(address token) external onlyConfigManager {
        require(token != address(0), "CrossChainBridge: Invalid token");
        supportedTokens[token] = true;
    }
    
    /**
     * @dev Remove supported token
     * @param token Token address
     */
    function removeSupportedToken(address token) external onlyConfigManager {
        supportedTokens[token] = false;
    }
    
    // ============ VALIDATOR MANAGEMENT ============
    
    /**
     * @dev Add validator
     * @param validator Validator address
     */
    function addValidator(address validator) external onlyConfigManager {
        require(!isValidator[validator], "CrossChainBridge: Already validator");
        
        _grantRole(VALIDATOR_ROLE, validator);
        validators.push(validator);
        isValidator[validator] = true;
    }
    
    /**
     * @dev Remove validator
     * @param validator Validator address
     */
    function removeValidator(address validator) external onlyConfigManager {
        require(isValidator[validator], "CrossChainBridge: Not validator");
        
        _revokeRole(VALIDATOR_ROLE, validator);
        isValidator[validator] = false;
        
        // Remove from validators array
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency pause bridge operations
     */
    function emergencyPause() external onlyBridgeOperator {
        _pause();
    }
    
    /**
     * @dev Resume bridge operations
     */
    function emergencyUnpause() external onlyBridgeOperator {
        _unpause();
    }
    
    /**
     * @dev Emergency withdrawal of stuck tokens
     * @param token Token address
     * @param amount Amount to withdraw
     * @param recipient Recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyBridgeOperator {
        require(recipient != address(0), "CrossChainBridge: Invalid recipient");
        IERC20(token).safeTransfer(recipient, amount);
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Determine asset type based on token address
     * @param token Token address
     * @return AssetType enum value
     */
    function _getAssetType(address token) internal view returns (AssetType) {
        if (token == address(karmaToken)) {
            return AssetType.KARMA_TOKEN;
        }
        return AssetType.OTHER_TOKEN;
    }
} 