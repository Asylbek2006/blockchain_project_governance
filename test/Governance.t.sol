// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceTest is Test {
    GovernanceToken token;
    MyGovernor      governor;
    TimelockController timelock;

    address treasury = address(1);
    address user1    = address(2);
    address user2    = address(3);

    function setUp() public {
        token = new GovernanceToken(address(this), treasury, address(11), address(12), address(this));
        timelock = new TimelockController(2 days, new address[](0), new address[](0), address(this));
        governor = new MyGovernor(token, timelock);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        token.transfer(user1, 5_000_000);
        token.transfer(user2, 5_000_000);
        token.delegate(address(this));
        vm.prank(user1);
        token.delegate(user1);
        vm.prank(user2);
        token.delegate(user2);
        vm.roll(block.number + 1);
    }

    function test_Propose() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        uint256 id = governor.propose(targets, values, calldatas, "Test Proposal");
        assertGt(id, 0);
    }

    function test_FullLifecycle() public {
        token.transfer(address(timelock), 1_000);

        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", user1, 100);
        string memory desc = "transfer tokens";

        uint256 id = governor.propose(targets, values, calldatas, desc);
        console.log("Step 1: Propose, state:", uint(governor.state(id)));

        vm.roll(block.number + governor.votingDelay() + 1);
        console.log("Step 2: Voting, state:", uint(governor.state(id))); 
        vm.prank(user1); governor.castVote(id, 1);
        vm.prank(user2); governor.castVote(id, 1);

        vm.roll(block.number + governor.votingPeriod());
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        console.log("Step 3: Queued, state:", uint(governor.state(id))); 

        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
        console.log("Step 4: Executed, state:", uint(governor.state(id))); 

        assertEq(uint(governor.state(id)), 7);
    }

    function test_DelegationVoting() public {
        uint256 before = token.getVotes(user2);
        vm.prank(user1);
        token.delegate(user2);
        vm.roll(block.number + 1);
        assertGt(token.getVotes(user2), before);
    }

    function test_NoQuorumDefeated() public {
        address poorVoter = address(99);
        token.transfer(poorVoter, 10);
        vm.prank(poorVoter);
        token.delegate(poorVoter);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        uint256 proposalId = governor.propose(targets, values, calldatas, "fail");
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(poorVoter);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod());
        assertEq(uint(governor.state(proposalId)), 3); 
    }

    function test_Threshold() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        vm.prank(address(0xdead));
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "fail");
    }

    function test_VoteAgainst() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        uint256 proposalId = governor.propose(targets, values, calldatas, "against");
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user1);
        governor.castVote(proposalId, 0);
        (uint256 against,,) = governor.proposalVotes(proposalId);
        assertGt(against, 0);
    }

    function test_Abstain() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        uint256 proposalId = governor.propose(targets, values, calldatas, "abstain");
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user1);
        governor.castVote(proposalId, 2);
        (,, uint256 abstain) = governor.proposalVotes(proposalId);
        assertGt(abstain, 0);
    }

    function test_QueueEarlyReverts() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        governor.propose(targets, values, calldatas, "fail queue");
        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes("fail queue")));
    }

    function test_ExecuteBeforeDelayReverts() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory desc = "early execute";
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod());
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function test_MultipleVotes() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        uint256 proposalId = governor.propose(targets, values, calldatas, "multiple voters");
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        (, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, token.getVotes(user1) + token.getVotes(user2));
    }

    function test_DoubleVoteReverts() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        uint256 proposalId = governor.propose(targets, values, calldatas, "double vote");
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        vm.prank(user1);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function test_ProposalStatePending() public {
        address[] memory targets = new address[](1);
        targets[0] = treasury;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        uint256 proposalId = governor.propose(targets, values, calldatas, "pending check");
        assertEq(uint(governor.state(proposalId)), 0); 
    }
}