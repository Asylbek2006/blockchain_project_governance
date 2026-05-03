// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(); 
        
        TimelockController timelock = new TimelockController(2 days, new address[](0), new address[](0), msg.sender);

        GovernanceToken token = new GovernanceToken(msg.sender, msg.sender, msg.sender, msg.sender, msg.sender);

        MyGovernor governor = new MyGovernor(token, timelock);

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0)); 

        console.log("Token:     ", address(token));
        console.log("Timelock:  ", address(timelock));
        console.log("Governor:  ", address(governor));

        vm.stopBroadcast();
    }
}