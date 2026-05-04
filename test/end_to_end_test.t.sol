// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Treasury.sol";
import "../src/Box.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract FullDAOTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Treasury treasury;
    Box box;

    address user1 = address(1);
    address user2 = address(2);

    function setUp() public {
        timelock = new TimelockController(
            2 days,
            new address[](0),
            new address[](0),
            address(this)
        );

        token = new GovernanceToken(
            address(this),
            address(this),
            address(this),
            address(this),
            address(this)
        );

        governor = new MyGovernor(token, timelock);

        treasury = new Treasury(address(timelock));
        box = new Box(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), address(this));

        token.transfer(user1, 2_000_000 ether);
        token.transfer(user2, 2_000_000 ether);

        token.delegate(address(this));

        vm.prank(user1);
        token.delegate(user1);

        vm.prank(user2);
        token.delegate(user2);

        vm.roll(block.number + 1);
    }

    function test_BoxGovernanceFlow() public {
        bytes memory data = abi.encodeWithSignature("store(uint256)", 42);

        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        uint256 proposalId = governor.propose(
            targets, values, calldatas, "Store 42 in Box"
        );
        console.log("STEP 1: PROPOSE");
        console.log("Proposal ID:", proposalId);
        console.log("State: 0 = Pending");

        vm.roll(block.number + governor.votingDelay() + 1);
        console.log("STEP 2: VOTE");

        vm.prank(user1);
        governor.castVote(proposalId, 1);

        vm.prank(user2);
        governor.castVote(proposalId, 1);

        console.log("State after votes (expect 1=Active):", uint256(governor.state(proposalId)));
        console.log("Votes casted");

        vm.roll(block.number + governor.votingPeriod() + 1);
        console.log("State after voting period (expect 4=Succeeded):", uint256(governor.state(proposalId)));

        bytes32 descHash = keccak256(bytes("Store 42 in Box"));
        governor.queue(targets, values, calldatas, descHash);
        console.log("STEP 3: QUEUE");
        console.log("Proposal queued in Timelock (2 day delay)");
        console.log("State after queue (expect 5=Queued):", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(targets, values, calldatas, descHash);
        console.log("STEP 4: EXECUTE");
        console.log("Timelock delay passed, proposal executed");
        console.log("State after execute (expect 7=Executed):", uint256(governor.state(proposalId)));

        uint256 val = box.retrieve();
        console.log("STEP 5: VERIFY");
        console.log("Box value:", val);
        assertEq(val, 42);
    }
}
