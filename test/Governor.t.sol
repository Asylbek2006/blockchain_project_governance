// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/Box.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Treasury.sol";

contract GovernorTest is Test {
    GovernanceToken private governanceToken;
    MyGovernor private governor;
    TimelockController private timelock;
    Treasury private treasury;
    Box private box;

    address private teamReceiver = makeAddr("teamReceiver");
    address private liquidityPool = makeAddr("liquidityPool");
    address private proposer = makeAddr("proposer");
    address private voter = makeAddr("voter");
    address private lowPowerProposer = makeAddr("lowPowerProposer");
    address private smallVoter = makeAddr("smallVoter");
    address private delegator = makeAddr("delegator");
    address private delegatee = makeAddr("delegatee");
    address private treasuryRecipient = makeAddr("treasuryRecipient");

    uint256 private constant VOTING_DELAY = 7_200;
    uint256 private constant VOTING_PERIOD = 50_400;
    uint256 private constant TIMELOCK_DELAY = 2 days;

    function setUp() public {
        governanceToken = new GovernanceToken(teamReceiver, address(this), address(this), liquidityPool);

        address[] memory initialProposers = new address[](0);
        address[] memory initialExecutors = new address[](1);
        initialExecutors[0] = address(0);

        timelock = new TimelockController(TIMELOCK_DELAY, initialProposers, initialExecutors, address(this));
        governor = new MyGovernor(governanceToken, timelock);
        treasury = new Treasury(address(timelock));
        box = new Box(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        assertTrue(governanceToken.transfer(address(treasury), governanceToken.TREASURY_ALLOCATION()));
        assertTrue(governanceToken.transfer(proposer, 20_000 ether));
        assertTrue(governanceToken.transfer(voter, 50_000 ether));
        assertTrue(governanceToken.transfer(lowPowerProposer, 5_000 ether));
        assertTrue(governanceToken.transfer(smallVoter, 15_000 ether));
        assertTrue(governanceToken.transfer(delegator, 10_000 ether));
        assertTrue(governanceToken.transfer(delegatee, 5_000 ether));

        vm.prank(proposer);
        governanceToken.delegate(proposer);
        vm.prank(voter);
        governanceToken.delegate(voter);
        vm.prank(lowPowerProposer);
        governanceToken.delegate(lowPowerProposer);
        vm.prank(smallVoter);
        governanceToken.delegate(smallVoter);
        vm.prank(delegatee);
        governanceToken.delegate(delegatee);
        vm.prank(delegator);
        governanceToken.delegate(delegatee);

        vm.deal(address(treasury), 5 ether);
        vm.roll(block.number + 1);
    }

    function testGovernorConfigurationMatchesRequirements() public view {
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), governanceToken.totalSupply() / 100);
        assertEq(governor.quorum(block.number - 1), governanceToken.totalSupply() * 4 / 100);
        assertEq(timelock.getMinDelay(), TIMELOCK_DELAY);
    }

    function testTimelockRolesMatchGovernanceRequirements() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertEq(treasury.owner(), address(timelock));
        assertEq(box.owner(), address(timelock));
    }

    function testProposerBelowThresholdCannotCreateProposal() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(box);
        calldatas[0] = abi.encodeWithSelector(Box.store.selector, 1);

        vm.prank(lowPowerProposer);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Below threshold proposal");
    }

    function testVoteCannotBeCastDuringVotingDelay() public {
        Proposal memory proposal =
            _createProposal(address(box), 0, abi.encodeWithSelector(Box.store.selector, 10), "Early vote");

        vm.prank(voter);
        vm.expectRevert();
        governor.castVote(proposal.id, 1);
    }

    function testFullLifecycleStoresFortyTwoInBox() public {
        Proposal memory proposal =
            _createProposal(address(box), 0, abi.encodeWithSelector(Box.store.selector, 42), "Store 42 in Box");

        _castPassingVote(proposal.id);
        _queueProposal(proposal);
        _executeQueuedProposal(proposal);

        assertEq(box.retrieve(), 42);
        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Executed));
    }

    function testFullLifecycleTransfersTokensFromTreasury() public {
        uint256 transferAmount = 1_000 ether;
        Proposal memory proposal = _createProposal(
            address(treasury),
            0,
            abi.encodeWithSelector(
                Treasury.transferTokens.selector, address(governanceToken), treasuryRecipient, transferAmount
            ),
            "Transfer treasury tokens"
        );

        _castPassingVote(proposal.id);
        _queueProposal(proposal);
        _executeQueuedProposal(proposal);

        assertEq(governanceToken.balanceOf(treasuryRecipient), transferAmount);
    }

    function testFullLifecycleTransfersEthFromTreasury() public {
        uint256 transferAmount = 1 ether;
        Proposal memory proposal = _createProposal(
            address(treasury),
            0,
            abi.encodeWithSelector(Treasury.transferEth.selector, payable(treasuryRecipient), transferAmount),
            "Transfer treasury ETH"
        );

        _castPassingVote(proposal.id);
        _queueProposal(proposal);
        _executeQueuedProposal(proposal);

        assertEq(treasuryRecipient.balance, transferAmount);
    }

    function testFullLifecycleChangesTreasuryParameter() public {
        uint256 newSpendingLimit = 25_000 ether;
        Proposal memory proposal = _createProposal(
            address(treasury),
            0,
            abi.encodeWithSelector(Treasury.updateSpendingLimit.selector, newSpendingLimit),
            "Update treasury spending limit"
        );

        _castPassingVote(proposal.id);
        _queueProposal(proposal);
        _executeQueuedProposal(proposal);

        assertEq(treasury.spendingLimit(), newSpendingLimit);
    }

    function testDelegateeVotesWithDelegatorVotingPower() public {
        Proposal memory proposal =
            _createProposal(address(box), 0, abi.encodeWithSelector(Box.store.selector, 99), "Delegated vote");

        vm.roll(block.number + VOTING_DELAY + 1);

        uint256 delegateeVotingPower = governor.getVotes(delegatee, block.number - 1);

        vm.prank(delegatee);
        governor.castVote(proposal.id, 1);

        (, uint256 forVotes,) = governor.proposalVotes(proposal.id);

        assertEq(delegateeVotingPower, 15_000 ether);
        assertEq(forVotes, delegateeVotingPower);
    }

    function testProposalIsDefeatedWhenQuorumIsNotMet() public {
        Proposal memory proposal = _createProposalAs(
            smallVoter, address(box), 0, abi.encodeWithSelector(Box.store.selector, 77), "Low quorum"
        );

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(smallVoter);
        governor.castVote(proposal.id, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Defeated));
    }

    function testProposalIsDefeatedWhenAgainstVotesWin() public {
        Proposal memory proposal = _createProposal(
            address(box), 0, abi.encodeWithSelector(Box.store.selector, 123), "Defeated by against votes"
        );

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voter);
        governor.castVote(proposal.id, 0);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Defeated));
    }

    function testProposalCannotExecuteBeforeTimelockDelay() public {
        Proposal memory proposal =
            _createProposal(address(box), 0, abi.encodeWithSelector(Box.store.selector, 7), "Timelock delay");

        _castPassingVote(proposal.id);
        _queueProposal(proposal);

        vm.expectRevert();
        governor.execute(proposal.targets, proposal.values, proposal.calldatas, proposal.descriptionHash);
    }

    function testStateTransitionsFollowFullLifecycle() public {
        Proposal memory proposal =
            _createProposal(address(box), 0, abi.encodeWithSelector(Box.store.selector, 3), "State transitions");

        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Pending));

        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Active));

        vm.prank(voter);
        governor.castVote(proposal.id, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Succeeded));

        _queueProposal(proposal);
        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Queued));

        _executeQueuedProposal(proposal);
        assertEq(uint256(governor.state(proposal.id)), uint256(IGovernor.ProposalState.Executed));
    }

    function testDirectTreasuryAndBoxCallsAreBlocked() public {
        vm.prank(proposer);
        vm.expectRevert();
        treasury.transferTokens(address(governanceToken), treasuryRecipient, 1 ether);

        vm.prank(proposer);
        vm.expectRevert();
        box.store(1);
    }

    struct Proposal {
        uint256 id;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
    }

    function _createProposal(address target, uint256 value, bytes memory calldataBytes, string memory description)
        private
        returns (Proposal memory proposal)
    {
        return _createProposalAs(proposer, target, value, calldataBytes, description);
    }

    function _createProposalAs(
        address proposalCreator,
        address target,
        uint256 value,
        bytes memory calldataBytes,
        string memory description
    ) private returns (Proposal memory proposal) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = target;
        values[0] = value;
        calldatas[0] = calldataBytes;

        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(proposalCreator);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        proposal = Proposal(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _castPassingVote(uint256 proposalId) private {
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter);
        governor.castVote(proposalId, 1);
    }

    function _queueProposal(Proposal memory proposal) private {
        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(proposal.targets, proposal.values, proposal.calldatas, proposal.descriptionHash);
    }

    function _executeQueuedProposal(Proposal memory proposal) private {
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        governor.execute(proposal.targets, proposal.values, proposal.calldatas, proposal.descriptionHash);
    }
}
