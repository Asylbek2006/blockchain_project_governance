// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Box.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/TokenVesting.sol";
import "../src/Treasury.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Deploy is Script {
    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant TEAM_VESTING_DURATION = 365 days;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address teamWallet = vm.envOr("TEAM_WALLET", deployer);
        address communityAirdropWallet = vm.envOr("COMMUNITY_AIRDROP_WALLET", deployer);
        address liquidityPoolWallet = vm.envOr("LIQUIDITY_POOL_WALLET", deployer);
        uint256 deploymentNonce = vm.getNonce(deployer);
        address predictedTokenAddress = vm.computeCreateAddress(deployer, deploymentNonce + 2);
        address predictedVestingAddress = vm.computeCreateAddress(deployer, deploymentNonce + 3);

        vm.startBroadcast(deployerPrivateKey);

        TimelockController timelock = new TimelockController(
            TIMELOCK_DELAY,
            new address[](0),
            new address[](0),
            deployer
        );
        Treasury treasury = new Treasury(address(timelock));
        GovernanceToken token = new GovernanceToken(
            predictedVestingAddress,
            address(treasury),
            communityAirdropWallet,
            liquidityPoolWallet,
            deployer
        );
        TokenVesting tokenVesting = new TokenVesting(
            predictedTokenAddress,
            teamWallet,
            block.timestamp,
            TEAM_VESTING_DURATION
        );
        Box box = new Box(address(timelock));
        MyGovernor governor = new MyGovernor(token, timelock);

        require(address(token) == predictedTokenAddress, "Unexpected token address");
        require(address(tokenVesting) == predictedVestingAddress, "Unexpected vesting address");

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        console.log("GovernanceToken:", address(token));
        console.log("TokenVesting:", address(tokenVesting));
        console.log("TimelockController:", address(timelock));
        console.log("MyGovernor:", address(governor));
        console.log("Treasury:", address(treasury));
        console.log("Box:", address(box));
        console.log("Team wallet:", teamWallet);
        console.log("Community airdrop wallet:", communityAirdropWallet);
        console.log("Liquidity pool wallet:", liquidityPoolWallet);

        vm.stopBroadcast();
    }
}
 
