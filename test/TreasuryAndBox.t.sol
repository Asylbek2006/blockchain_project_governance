// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/Box.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Treasury.sol";

contract TreasuryAndBoxTest is Test {
    GovernanceToken private governanceToken;
    MyGovernor private governor;
    TimelockController private timelock;
    Treasury private treasury;
    Box private box;

    address private teamReceiver = makeAddr("teamReceiver");
    address private liquidityPool = makeAddr("liquidityPool");
    address private proposer = makeAddr("proposer");
    address private voter = makeAddr("voter");
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

        vm.prank(proposer);
        governanceToken.delegate(proposer);

        vm.prank(voter);
        governanceToken.delegate(voter);

        vm.deal(address(treasury), 5 ether);
        vm.roll(block.number + 1);
    }

    function testEndToEndGovernanceStoresValueInBox() public {
        GovernanceProposal memory governanceProposal =
            _createProposal(address(box), 0, abi.encodeWithSelector(Box.store.selector, 42), "Store 42 in Box");

        assertEq(uint256(governor.state(governanceProposal.id)), uint256(IGovernor.ProposalState.Pending));

        _activateProposal(governanceProposal.id);
        assertEq(uint256(governor.state(governanceProposal.id)), uint256(IGovernor.ProposalState.Active));

        _castVote(governanceProposal.id);
        _finishVotingPeriod();
        assertEq(uint256(governor.state(governanceProposal.id)), uint256(IGovernor.ProposalState.Succeeded));

        _queueProposal(governanceProposal);
        assertEq(uint256(governor.state(governanceProposal.id)), uint256(IGovernor.ProposalState.Queued));

        _executeProposal(governanceProposal);

        assertEq(box.retrieve(), 42);
        assertEq(uint256(governor.state(governanceProposal.id)), uint256(IGovernor.ProposalState.Executed));
    }

    function testEndToEndGovernanceTransfersTokensFromTreasury() public {
        uint256 transferAmount = 1_000 ether;
        GovernanceProposal memory governanceProposal = _createProposal(
            address(treasury),
            0,
            abi.encodeWithSelector(
                Treasury.transferTokens.selector, address(governanceToken), treasuryRecipient, transferAmount
            ),
            "Transfer tokens from treasury"
        );

        _voteQueueExecute(governanceProposal);

        assertEq(governanceToken.balanceOf(treasuryRecipient), transferAmount);
        assertEq(
            treasury.getTokenBalance(address(governanceToken)), governanceToken.TREASURY_ALLOCATION() - transferAmount
        );
    }

    function testEndToEndGovernanceTransfersEthFromTreasury() public {
        uint256 transferAmount = 1 ether;
        GovernanceProposal memory governanceProposal = _createProposal(
            address(treasury),
            0,
            abi.encodeWithSelector(Treasury.transferEth.selector, payable(treasuryRecipient), transferAmount),
            "Transfer ETH from treasury"
        );

        _voteQueueExecute(governanceProposal);

        assertEq(treasuryRecipient.balance, transferAmount);
        assertEq(treasury.getEthBalance(), 4 ether);
    }

    function testOnlyTimelockCanControlTreasuryAndBox() public {
        assertEq(treasury.owner(), address(timelock));
        assertEq(box.owner(), address(timelock));

        vm.prank(proposer);
        vm.expectRevert();
        treasury.transferTokens(address(governanceToken), treasuryRecipient, 1 ether);

        vm.prank(proposer);
        vm.expectRevert();
        box.store(42);
    }

    struct GovernanceProposal {
        uint256 id;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
    }

    function _createProposal(address target, uint256 value, bytes memory calldataBytes, string memory description)
        private
        returns (GovernanceProposal memory governanceProposal)
    {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = target;
        values[0] = value;
        calldatas[0] = calldataBytes;

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        governanceProposal = GovernanceProposal(proposalId, targets, values, calldatas, keccak256(bytes(description)));
    }

    function _voteQueueExecute(GovernanceProposal memory governanceProposal) private {
        _activateProposal(governanceProposal.id);
        _castVote(governanceProposal.id);
        _finishVotingPeriod();
        _queueProposal(governanceProposal);
        _executeProposal(governanceProposal);
    }

    function _activateProposal(uint256) private {
        vm.roll(block.number + VOTING_DELAY + 1);
    }

    function _castVote(uint256 proposalId) private {
        vm.prank(voter);
        governor.castVote(proposalId, 1);
    }

    function _finishVotingPeriod() private {
        vm.roll(block.number + VOTING_PERIOD + 1);
    }

    function _queueProposal(GovernanceProposal memory governanceProposal) private {
        governor.queue(
            governanceProposal.targets,
            governanceProposal.values,
            governanceProposal.calldatas,
            governanceProposal.descriptionHash
        );
    }

    function _executeProposal(GovernanceProposal memory governanceProposal) private {
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(
            governanceProposal.targets,
            governanceProposal.values,
            governanceProposal.calldatas,
            governanceProposal.descriptionHash
        );
    }
}
