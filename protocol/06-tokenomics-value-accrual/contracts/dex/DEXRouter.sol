// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title DEXRouter
 * @dev Multi-DEX integration and routing contract for Stage 6.1
 * @notice Provides optimal routing across multiple DEX protocols
 */
contract DEXRouter is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant DEX_MANAGER_ROLE = keccak256("DEX_MANAGER_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");

    enum DEXType {
        UNISWAP_V3,
        SUSHISWAP,
        BALANCER,
        CURVE
    }

    struct DEXConfig {
        address router;
        bool enabled;
        uint256 gasEstimate;
        uint256 feePercentage;
    }

    struct RouteInfo {
        DEXType dex;
        address[] path;
        uint256 expectedOut;
        uint256 priceImpact;
        uint256 gasEstimate;
    }

    mapping(DEXType => DEXConfig) public dexConfigs;
    mapping(address => mapping(address => RouteInfo)) public cachedRoutes;
    
    uint256 public constant MAX_SLIPPAGE = 1000; // 10%
    uint256 public constant PRICE_IMPACT_THRESHOLD = 500; // 5%
    uint256 public routeCacheTimeout = 300; // 5 minutes
    
    event DEXConfigured(DEXType indexed dexType, address router, bool enabled);
    event RouteCalculated(address tokenIn, address tokenOut, uint256 amountIn, RouteInfo route);
    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, DEXType dex);
    event RouteUpdated(address indexed tokenIn, address indexed tokenOut, RouteInfo route);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEX_MANAGER_ROLE, admin);
        _grantRole(ROUTER_ROLE, admin);
    }

    /**
     * @dev Configure DEX integration
     */
    function configureDEX(
        DEXType dexType,
        address router,
        bool enabled,
        uint256 gasEstimate,
        uint256 feePercentage
    ) external onlyRole(DEX_MANAGER_ROLE) {
        require(router != address(0), "DEXRouter: Invalid router address");
        require(gasEstimate > 0, "DEXRouter: Invalid gas estimate");
        require(feePercentage <= 10000, "DEXRouter: Fee percentage too high");

        dexConfigs[dexType] = DEXConfig({
            router: router,
            enabled: enabled,
            gasEstimate: gasEstimate,
            feePercentage: feePercentage
        });

        emit DEXConfigured(dexType, router, enabled);
    }

    /**
     * @dev Calculate optimal route for token swap
     */
    function calculateOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (RouteInfo memory bestRoute) {
        require(tokenIn != address(0) && tokenOut != address(0), "DEXRouter: Invalid token addresses");
        require(amountIn > 0, "DEXRouter: Invalid amount");

        uint256 bestOutput = 0;
        
        for (uint256 i = 0; i < 4; i++) {
            DEXType dexType = DEXType(i);
            DEXConfig memory config = dexConfigs[dexType];
            
            if (!config.enabled || config.router == address(0)) continue;
            
            RouteInfo memory route = _calculateRoute(tokenIn, tokenOut, amountIn, dexType);
            
            if (route.expectedOut > bestOutput) {
                bestOutput = route.expectedOut;
                bestRoute = route;
            }
        }

        require(bestOutput > 0, "DEXRouter: No valid route found");
    }

    /**
     * @dev Execute optimal swap
     */
    function executeOptimalSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxSlippage
    ) external onlyRole(ROUTER_ROLE) nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(maxSlippage <= MAX_SLIPPAGE, "DEXRouter: Slippage too high");
        
        RouteInfo memory route = this.calculateOptimalRoute(tokenIn, tokenOut, amountIn);
        
        // Validate slippage
        uint256 slippage = _calculateSlippage(route.expectedOut, minAmountOut);
        require(slippage <= maxSlippage, "DEXRouter: Slippage exceeded");
        
        // Validate price impact
        require(route.priceImpact <= PRICE_IMPACT_THRESHOLD, "DEXRouter: Price impact too high");
        
        amountOut = _executeSwap(route, tokenIn, tokenOut, amountIn, minAmountOut);
        
        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, route.dex);
    }

    /**
     * @dev Get supported DEX types
     */
    function getSupportedDEXes() external view returns (DEXType[] memory) {
        DEXType[] memory enabledDEXes = new DEXType[](4);
        uint256 count = 0;
        
        for (uint256 i = 0; i < 4; i++) {
            DEXType dexType = DEXType(i);
            if (dexConfigs[dexType].enabled) {
                enabledDEXes[count] = dexType;
                count++;
            }
        }
        
        // Resize array to actual count
        DEXType[] memory result = new DEXType[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = enabledDEXes[i];
        }
        
        return result;
    }

    /**
     * @dev Calculate price impact for a given swap
     */
    function calculatePriceImpact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        RouteInfo memory route = this.calculateOptimalRoute(tokenIn, tokenOut, amountIn);
        return route.priceImpact;
    }

    /**
     * @dev Get gas estimate for optimal route
     */
    function getGasEstimate(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        RouteInfo memory route = this.calculateOptimalRoute(tokenIn, tokenOut, amountIn);
        return route.gasEstimate;
    }

    /**
     * @dev Internal function to calculate route for specific DEX
     */
    function _calculateRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        DEXType dexType
    ) internal view returns (RouteInfo memory route) {
        DEXConfig memory config = dexConfigs[dexType];
        
        // Simplified route calculation - in production, integrate with actual DEX quoters
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        // Mock calculation for demonstration
        uint256 expectedOut = amountIn * 95 / 100; // Assume 5% fee
        uint256 priceImpact = _calculateMockPriceImpact(amountIn);
        
        route = RouteInfo({
            dex: dexType,
            path: path,
            expectedOut: expectedOut,
            priceImpact: priceImpact,
            gasEstimate: config.gasEstimate
        });
    }

    /**
     * @dev Execute swap on specific DEX
     */
    function _executeSwap(
        RouteInfo memory route,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        // In production, integrate with actual DEX routers
        // For now, return expected amount
        amountOut = route.expectedOut;
        
        // Ensure minimum output is met
        require(amountOut >= minAmountOut, "DEXRouter: Insufficient output amount");
    }

    /**
     * @dev Calculate slippage percentage
     */
    function _calculateSlippage(uint256 expected, uint256 minimum) internal pure returns (uint256) {
        if (expected == 0) return 0;
        return ((expected - minimum) * 10000) / expected;
    }

    /**
     * @dev Mock price impact calculation
     */
    function _calculateMockPriceImpact(uint256 amountIn) internal pure returns (uint256) {
        // Simple price impact model - larger trades have higher impact
        if (amountIn > 100 ether) return 500; // 5%
        if (amountIn > 10 ether) return 200; // 2%
        if (amountIn > 1 ether) return 50; // 0.5%
        return 10; // 0.1%
    }

    /**
     * @dev Emergency pause function
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause function
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Set route cache timeout
     */
    function setRouteCacheTimeout(uint256 timeout) external onlyRole(DEX_MANAGER_ROLE) {
        require(timeout >= 60, "DEXRouter: Timeout too short");
        routeCacheTimeout = timeout;
    }

    /**
     * @dev Get DEX configuration
     */
    function getDEXConfig(DEXType dexType) external view returns (DEXConfig memory) {
        return dexConfigs[dexType];
    }
} 