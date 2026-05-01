// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Box.sol";
import "openzeppelin-contracts/governance/TimelockController.sol";


contract GovernorTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Box box;

    address voter1 = makeAddr("voter1");   
    address voter2 = makeAddr("voter2");   
    address delegator = makeAddr("delegator");
    address delegatee = makeAddr("delegatee");
    address recipient = makeAddr("recipient");

    uint256 constant VOTING_DELAY = 7200;
    uint256 constant VOTING_PERIOD = 50400;
    uint256 constant TIMELOCK_DELAY = 2 days;

    function setUp() public {
        token = new GovernanceToken(makeAddr("team"), address(this), address(this),makeAddr("liquidity"));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); 

        timelock = new TimelockController(
            TIMELOCK_DELAY,
            proposers,
            executors,
            address(this)
        );

        governor = new MyGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(),  address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        box = new Box(address(timelock));

        token.transfer(address(timelock), token.TREASURY_ALLOCATION());

        token.transfer(voter1, 20_000e18);
        vm.prank(voter1);
        token.delegate(voter1);

        token.transfer(voter2, 50_000e18);
        vm.prank(voter2);
        token.delegate(voter2);

        token.transfer(delegator, 10_000e18);
        token.transfer(delegatee, 5_000e18);
        vm.prank(delegatee);
        token.delegate(delegatee);
        vm.prank(delegator);
        token.delegate(delegatee); 

        vm.roll(block.number + 1);
    }

    function _propose(address target, bytes memory data, string memory desc) internal returns (uint256) {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = target;
        calldatas[0] = data;
        vm.prank(voter1);
        return governor.propose(targets, values, calldatas, desc);
    }

    function _voteAndPass(uint256 pid) internal {
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voter2);
        governor.castVote(pid, 1);
    }

    function _queueAndExecute(address target, bytes memory data, string memory desc) internal {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = target;
        calldatas[0] = data;
        vm.roll(block.number + VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function test_ProposalThreshold() public view {
        assertEq(governor.proposalThreshold(), token.totalSupply() / 100);
    }

    function test_CannotProposeBelowThreshold() public {
        address poor = makeAddr("poor");
        token.transfer(poor, 100e18); 
        vm.prank(poor);
        token.delegate(poor);
        vm.roll(block.number + 1);

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);

        vm.prank(poor);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "fail");
    }

    function test_QuorumIs4Percent() public view {
        assertEq(governor.quorum(block.number - 1), token.totalSupply() * 4 / 100);
    }

    function test_CannotVoteDuringDelay() public {
        uint256 pid = _propose(address(box), abi.encodeWithSelector(Box.setValue.selector, 10), "too early");
        vm.prank(voter2);
        vm.expectRevert();
        governor.castVote(pid, 1);
    }

    function test_FullLifecycle_ChangeValue() public {
        console.log("\n=== PROPOSAL: Change Box Value ===");
        string memory desc = "Set box value to 42";
        bytes memory data  = abi.encodeWithSelector(Box.setValue.selector, 42);

        uint256 pid = _propose(address(box), data, desc);
        console.log("1. Proposed. ID:", pid);

        _voteAndPass(pid);
        console.log("2. Voted FOR");

        _queueAndExecute(address(box), data, desc);
        console.log("3. Queued and Executed");
        console.log("4. Box value:", box.value());

        assertEq(box.value(), 42);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Executed));
    }

    function test_FullLifecycle_TransferTokens() public {
        console.log("\n=== PROPOSAL: Transfer Tokens from Treasury ===");
        string memory desc = "Transfer 1000 GOV to recipient";
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), recipient, 1000e18);

        uint256 pid = _propose(address(token), data, desc);
        console.log("1. Proposed. ID:", pid);

        _voteAndPass(pid);
        console.log("2. Voted FOR");

        _queueAndExecute(address(token), data, desc);
        console.log("3. Queued and Executed");
        console.log("4. Recipient balance:", token.balanceOf(recipient) / 1e18, "GOV");

        assertEq(token.balanceOf(recipient), 1000e18);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Executed));
    }

    function test_DelegateeVotesForDelegator() public {
        uint256 pid = _propose(address(box), abi.encodeWithSelector(Box.setValue.selector, 99), "delegation test");
        vm.roll(block.number + VOTING_DELAY + 1);

        uint256 weight = governor.getVotes(delegatee, block.number - 1);
        assertGt(weight, 5_000e18);

        vm.prank(delegatee);
        governor.castVote(pid, 1);

        (, uint256 forVotes,) = governor.proposalVotes(pid);
        assertEq(forVotes, weight);
    }

    function test_ProposalDefeated_QuorumNotMet() public {
        address tinyVoter = makeAddr("tiny");
        token.transfer(tinyVoter, 15_000e18); 
        vm.prank(tinyVoter);
        token.delegate(tinyVoter);
        vm.roll(block.number + 1);

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(box);
        calldatas[0] = abi.encodeWithSelector(Box.setValue.selector, 99);

        vm.prank(tinyVoter);
        uint256 pid = governor.propose(targets, values, calldatas, "low quorum");

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(tinyVoter);
        governor.castVote(pid, 1); 

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Defeated));
    }

    function test_ProposalDefeated_VotedAgainst() public {
        uint256 pid = _propose(
            address(box),
            abi.encodeWithSelector(Box.setValue.selector, 99),
            "bad proposal"
        );
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter2);
        governor.castVote(pid, 0); 

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Defeated));
    }

    function test_CannotExecuteBeforeTimelockDelay() public {
        string memory desc = "timelock test";
        bytes memory data  = abi.encodeWithSelector(Box.setValue.selector, 7);

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(box);
        calldatas[0] = data;

        uint256 pid = _propose(address(box), data, desc);
        _voteAndPass(pid);
        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));

        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function test_StateTransitions() public {
        console.log("\n=== STATE TRANSITIONS ===");
        string memory desc = "state test";
        bytes memory data  = abi.encodeWithSelector(Box.setValue.selector, 3);

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(box);
        calldatas[0] = data;

        uint256 pid = _propose(address(box), data, desc);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Pending));
        console.log("State: Pending");

        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Active));
        console.log("State: Active");

        vm.prank(voter2);
        governor.castVote(pid, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Succeeded));
        console.log("State: Succeeded");

        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Queued));
        console.log("State: Queued");

        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint(governor.state(pid)), uint(IGovernor.ProposalState.Executed));
        console.log("State: Executed");
    }

    function test_TimelockOwnsBox() public {
        assertEq(box.owner(), address(timelock));
        vm.prank(voter1);
        vm.expectRevert();
        box.setValue(999);
    }
}
