// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockContract {
    mapping(address => bool) public authorized;
    uint256 public counter;
    
    event MockFunction(address caller, uint256 value);
    
    function mockFunction(uint256 value) external {
        counter = value;
        emit MockFunction(msg.sender, value);
    }
    
    function setAuthorized(address user, bool status) external {
        authorized[user] = status;
    }
    
    receive() external payable {}
}
