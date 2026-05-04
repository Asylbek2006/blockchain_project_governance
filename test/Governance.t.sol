// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Box.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Treasury.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Treasury treasury;
    Box box;

    address recipient = address(1);
    address voterOne = address(2);
    address voterTwo = address(3);
    address smallVoter = address(4);
    address liquidityPool = address(5);

    function setUp() public {
        timelock = new TimelockController(2 days, new address[](0), new address[](0), address(this));
        treasury = new Treasury(address(timelock));

        token = new GovernanceToken(address(this), address(treasury), address(this), liquidityPool, address(this));
        governor = new MyGovernor(token, timelock);
        box = new Box(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        token.transfer(voterOne, 5_000_000 ether);
        token.transfer(voterTwo, 5_000_000 ether);
        token.transfer(smallVoter, 1 ether);

        token.delegate(address(this));

        vm.prank(voterOne);
        token.delegate(voterOne);

        vm.prank(voterTwo);
        token.delegate(voterTwo);

        vm.prank(smallVoter);
        token.delegate(smallVoter);

        vm.roll(block.number + 1);
    }

    function test_GovernorConfigurationMatchesAssignment() public view {
        assertEq(governor.votingDelay(), 7_200);
        assertEq(governor.votingPeriod(), 50_400);
        assertEq(governor.proposalThreshold(), 1_000_000 ether);
        assertEq(governor.quorum(block.number - 1), 4_000_000 ether);
        assertEq(timelock.getMinDelay(), 2 days);
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
    }

    function test_ProposalCanBeCreatedByAccountAboveThreshold() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(42);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Store 42 in Box");

        assertGt(proposalId, 0);
        assertEq(uint256(governor.state(proposalId)), 0);
    }

    function test_ProposalBelowThresholdReverts() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(42);

        vm.prank(smallVoter);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Small voter proposal");
    }

    function test_FullProposalLifecycleStoresBoxValue() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(42);

        uint256 proposalId = _proposeVoteQueueAndExecute(targets, values, calldatas, "Store 42 in Box");

        assertEq(uint256(governor.state(proposalId)), 7);
        assertEq(box.retrieve(), 42);
    }

    function test_TreasuryTransfersTokensThroughGovernance() public {
        uint256 recipientBalanceBefore = token.balanceOf(recipient);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildTreasuryTokenTransferProposal(recipient, 1_000 ether);

        _proposeVoteQueueAndExecute(targets, values, calldatas, "Transfer 1000 GOV from treasury");

        assertEq(token.balanceOf(recipient), recipientBalanceBefore + 1_000 ether);
    }

    function test_GovernanceChangesTreasuryParameter() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildTreasurySpendingLimitProposal(25_000 ether);

        _proposeVoteQueueAndExecute(targets, values, calldatas, "Set treasury spending limit");

        assertEq(treasury.spendingLimit(), 25_000 ether);
    }

    function test_DelegateeVotesOnBehalfOfDelegator() public {
        vm.prank(voterOne);
        token.delegate(voterTwo);
        vm.roll(block.number + 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(77);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Delegated voting proposal");
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voterTwo);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 10_000_000 ether);
    }

    function test_ProposalFailsWhenQuorumIsNotMet() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(10);

        uint256 proposalId = governor.propose(targets, values, calldatas, "No quorum proposal");
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(smallVoter);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint256(governor.state(proposalId)), 3);
    }

    function test_ProposalIsDefeatedWhenAgainstVotesWin() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(11);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Defeated proposal");
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voterOne);
        governor.castVote(proposalId, 0);

        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint256(governor.state(proposalId)), 3);
    }

    function test_ForAgainstAndAbstainVotesAreRecorded() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(12);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Vote counting proposal");
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voterOne);
        governor.castVote(proposalId, 1);

        vm.prank(voterTwo);
        governor.castVote(proposalId, 0);

        vm.prank(address(this));
        governor.castVote(proposalId, 2);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 5_000_000 ether);
        assertEq(forVotes, 5_000_000 ether);
        assertGt(abstainVotes, 0);
    }

    function test_DoubleVoteReverts() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(13);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Double vote proposal");
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voterOne);
        governor.castVote(proposalId, 1);

        vm.prank(voterOne);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function test_QueueBeforeSuccessReverts() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(14);
        string memory description = "Early queue proposal";

        governor.propose(targets, values, calldatas, description);

        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes(description)));
    }

    function test_ExecuteBeforeTimelockDelayReverts() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(15);
        string memory description = "Early execute proposal";
        bytes32 descriptionHash = keccak256(bytes(description));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        _voteForProposal(proposalId);
        vm.roll(block.number + governor.votingPeriod() + 1);
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function test_ProposalStateBecomesSucceededAfterWinningVote() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _buildBoxStoreProposal(16);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Succeeded proposal");
        _voteForProposal(proposalId);
        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint256(governor.state(proposalId)), 4);
    }

    function _proposeVoteQueueAndExecute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256) {
        bytes32 descriptionHash = keccak256(bytes(description));
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        _voteForProposal(proposalId);
        vm.roll(block.number + governor.votingPeriod() + 1);
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        return proposalId;
    }

    function _voteForProposal(uint256 proposalId) internal {
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voterOne);
        governor.castVote(proposalId, 1);

        vm.prank(voterTwo);
        governor.castVote(proposalId, 1);
    }

    function _buildBoxStoreProposal(uint256 newValue)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(Box.store.selector, newValue);
    }

    function _buildTreasuryTokenTransferProposal(address transferRecipient, uint256 transferAmount)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] =
            abi.encodeWithSelector(Treasury.transferERC20.selector, address(token), transferRecipient, transferAmount);
    }

    function _buildTreasurySpendingLimitProposal(uint256 newSpendingLimit)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(Treasury.setSpendingLimit.selector, newSpendingLimit);
    }
}
