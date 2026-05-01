// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/Box.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/TokenVesting.sol";
import "../src/Treasury.sol";

contract DeployDao is Script {
    uint256 private constant TIMELOCK_DELAY = 2 days;

    function run() external {
        address teamBeneficiary = vm.envAddress("TEAM_BENEFICIARY");
        address communityAirdrop = vm.envAddress("COMMUNITY_AIRDROP");
        address liquidityPool = vm.envAddress("LIQUIDITY_POOL");

        vm.startBroadcast();

        GovernanceToken governanceToken = new GovernanceToken(msg.sender, msg.sender, communityAirdrop, liquidityPool);
        TokenVesting tokenVesting = new TokenVesting(address(governanceToken), teamBeneficiary);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        TimelockController timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, msg.sender);
        MyGovernor governor = new MyGovernor(governanceToken, timelock);
        Treasury treasury = new Treasury(address(timelock));
        Box box = new Box(address(timelock));

        require(
            governanceToken.transfer(address(tokenVesting), governanceToken.TEAM_ALLOCATION()), "Team transfer failed"
        );
        require(
            governanceToken.transfer(address(treasury), governanceToken.TREASURY_ALLOCATION()),
            "Treasury transfer failed"
        );
        tokenVesting.updateTotalVestedAmount();

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();

        _writeDeploymentAddresses(governanceToken, tokenVesting, timelock, governor, treasury, box);
    }

    function _writeDeploymentAddresses(
        GovernanceToken governanceToken,
        TokenVesting tokenVesting,
        TimelockController timelock,
        MyGovernor governor,
        Treasury treasury,
        Box box
    ) private {
        string memory deploymentJson = "deployment";
        vm.serializeAddress(deploymentJson, "governanceToken", address(governanceToken));
        vm.serializeAddress(deploymentJson, "tokenVesting", address(tokenVesting));
        vm.serializeAddress(deploymentJson, "timelock", address(timelock));
        vm.serializeAddress(deploymentJson, "governor", address(governor));
        vm.serializeAddress(deploymentJson, "treasury", address(treasury));
        string memory finalJson = vm.serializeAddress(deploymentJson, "box", address(box));
        vm.writeJson(finalJson, "deployment-addresses.json");
    }
}
