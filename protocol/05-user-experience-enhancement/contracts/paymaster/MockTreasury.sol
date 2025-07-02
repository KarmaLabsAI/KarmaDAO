// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockTreasury
 * @dev Mock Treasury contract for testing Paymaster functionality
 * 
 * This is a simplified mock of the Treasury contract for testing purposes.
 * In production, you would use the actual Treasury contract.
 */
contract MockTreasury {
    
    // Events
    event PaymasterFunded(address indexed paymaster, uint256 amount);
    
    /**
     * @dev Fund a paymaster (mock implementation)
     * @param paymaster Address of the paymaster to fund
     * @param amount Amount to fund
     */
    function fundPaymaster(address paymaster, uint256 amount) external {
        // In a real implementation, this would transfer funds
        // For testing, we just emit an event
        emit PaymasterFunded(paymaster, amount);
        
        // Mock funding by sending ETH to the paymaster
        if (address(this).balance >= amount) {
            (bool success,) = payable(paymaster).call{value: amount}("");
            require(success, "MockTreasury: funding failed");
        }
    }
    
    /**
     * @dev Get treasury balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Receive ETH
     */
    receive() external payable {
        // Allow receiving ETH
    }
    
    /**
     * @dev Emergency funding function for testing
     */
    function emergencyFund() external payable {
        // Allow funding the treasury for testing
    }
} 