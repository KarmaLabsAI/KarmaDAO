// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockEntryPoint
 * @dev Mock EntryPoint contract for testing Paymaster functionality
 * 
 * This is a simplified mock of the ERC-4337 EntryPoint contract
 * for testing purposes. In production, you would use the actual
 * ERC-4337 EntryPoint contract.
 */
contract MockEntryPoint {
    
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }
    
    // Events
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );
    
    /**
     * @dev Handle user operations (simplified mock implementation)
     * @param ops Array of user operations
     * @param beneficiary Address to receive gas refunds
     */
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external {
        for (uint256 i = 0; i < ops.length; i++) {
            _handleUserOp(ops[i], beneficiary);
        }
    }
    
    /**
     * @dev Handle a single user operation (mock implementation)
     * @param userOp The user operation to handle
     * @param beneficiary Address to receive gas refunds
     */
    function _handleUserOp(UserOperation calldata userOp, address payable beneficiary) internal {
        bytes32 userOpHash = getUserOpHash(userOp);
        
        // Mock successful execution
        emit UserOperationEvent(
            userOpHash,
            userOp.sender,
            address(0), // No paymaster in this mock
            userOp.nonce,
            true,       // success
            100000,     // mock gas cost
            100000      // mock gas used
        );
    }
    
    /**
     * @dev Get hash of user operation
     * @param userOp The user operation
     * @return Hash of the user operation
     */
    function getUserOpHash(UserOperation calldata userOp) public pure returns (bytes32) {
        return keccak256(abi.encode(
            userOp.sender,
            userOp.nonce,
            userOp.initCode,
            userOp.callData,
            userOp.callGasLimit,
            userOp.verificationGasLimit,
            userOp.preVerificationGas,
            userOp.maxFeePerGas,
            userOp.maxPriorityFeePerGas,
            userOp.paymasterAndData
        ));
    }
    
    /**
     * @dev Simulate user operation (for testing)
     * @param userOp The user operation to simulate
     * @return validation result
     */
    function simulateValidation(UserOperation calldata userOp) external view returns (uint256) {
        // Mock validation - always return success
        return 0;
    }
} 