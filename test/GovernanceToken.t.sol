// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/TokenVesting.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken private governanceToken;
    TokenVesting private teamVesting;

    address private temporaryTeamReceiver = makeAddr("temporaryTeamReceiver");
    address private treasury = makeAddr("treasury");
    address private communityAirdrop = makeAddr("communityAirdrop");
    address private liquidityPool = makeAddr("liquidityPool");
    address private teamBeneficiary = makeAddr("teamBeneficiary");
    address private delegatee = makeAddr("delegatee");
    address private spender = makeAddr("spender");

    uint256 private constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 private constant TEAM_ALLOCATION = 400_000 ether;
    uint256 private constant TREASURY_ALLOCATION = 300_000 ether;
    uint256 private constant COMMUNITY_ALLOCATION = 200_000 ether;
    uint256 private constant LIQUIDITY_ALLOCATION = 100_000 ether;

    function setUp() public {
        governanceToken = new GovernanceToken(temporaryTeamReceiver, treasury, communityAirdrop, liquidityPool);
        teamVesting = new TokenVesting(address(governanceToken), teamBeneficiary);

        vm.prank(temporaryTeamReceiver);
        assertTrue(governanceToken.transfer(address(teamVesting), TEAM_ALLOCATION));
        teamVesting.updateTotalVestedAmount();
    }

    function testInitialSupplyAndDistribution() public view {
        assertEq(governanceToken.totalSupply(), TOTAL_SUPPLY);
        assertEq(governanceToken.balanceOf(address(teamVesting)), TEAM_ALLOCATION);
        assertEq(governanceToken.balanceOf(treasury), TREASURY_ALLOCATION);
        assertEq(governanceToken.balanceOf(communityAirdrop), COMMUNITY_ALLOCATION);
        assertEq(governanceToken.balanceOf(liquidityPool), LIQUIDITY_ALLOCATION);
    }

    function testHolderCanDelegateVotesToSelf() public {
        vm.prank(communityAirdrop);
        governanceToken.delegate(communityAirdrop);

        assertEq(governanceToken.getVotes(communityAirdrop), COMMUNITY_ALLOCATION);
    }

    function testHolderCanDelegateVotesToAnotherAccount() public {
        vm.prank(communityAirdrop);
        governanceToken.delegate(delegatee);

        assertEq(governanceToken.getVotes(delegatee), COMMUNITY_ALLOCATION);
        assertEq(governanceToken.getVotes(communityAirdrop), 0);
    }

    function testVotingPowerSnapshotKeepsHistoricalVotes() public {
        vm.prank(communityAirdrop);
        governanceToken.delegate(communityAirdrop);

        uint256 snapshotBlock = block.number;

        vm.roll(snapshotBlock + 1);
        vm.prank(communityAirdrop);
        assertTrue(governanceToken.transfer(delegatee, 1_000 ether));

        assertEq(governanceToken.getPastVotes(communityAirdrop, snapshotBlock), COMMUNITY_ALLOCATION);
    }

    function testVotingPowerMovesAfterDelegatedTransfer() public {
        vm.prank(communityAirdrop);
        governanceToken.delegate(communityAirdrop);

        vm.prank(communityAirdrop);
        assertTrue(governanceToken.transfer(delegatee, 1_000 ether));

        vm.prank(delegatee);
        governanceToken.delegate(delegatee);

        assertEq(governanceToken.getVotes(communityAirdrop), COMMUNITY_ALLOCATION - 1_000 ether);
        assertEq(governanceToken.getVotes(delegatee), 1_000 ether);
    }

    function testPermitApprovesSpenderWithSignedMessage() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 approvalAmount = 1_000 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(communityAirdrop);
        assertTrue(governanceToken.transfer(permitOwner, approvalAmount));

        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(
            abi.encode(
                permitTypeHash, permitOwner, spender, approvalAmount, governanceToken.nonces(permitOwner), deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", governanceToken.DOMAIN_SEPARATOR(), structHash));
        (uint8 signatureV, bytes32 signatureR, bytes32 signatureS) = vm.sign(privateKey, digest);

        governanceToken.permit(permitOwner, spender, approvalAmount, deadline, signatureV, signatureR, signatureS);

        assertEq(governanceToken.allowance(permitOwner, spender), approvalAmount);
        assertEq(governanceToken.nonces(permitOwner), 1);
    }

    function testNoTeamTokensAreReleasableAtStart() public view {
        assertEq(teamVesting.releasableAmount(), 0);
    }

    function testTeamTokensReleaseLinearlyAfterHalfDuration() public {
        vm.warp(block.timestamp + teamVesting.vestingDuration() / 2);

        assertApproxEqAbs(teamVesting.releasableAmount(), TEAM_ALLOCATION / 2, 1);
    }

    function testTeamBeneficiaryCanReleaseAllTokensAfterTwelveMonths() public {
        vm.warp(block.timestamp + teamVesting.vestingDuration());

        vm.prank(teamBeneficiary);
        teamVesting.release();

        assertEq(governanceToken.balanceOf(teamBeneficiary), TEAM_ALLOCATION);
        assertEq(teamVesting.totalReleasedAmount(), TEAM_ALLOCATION);
    }

    function testNonBeneficiaryCannotReleaseTeamTokens() public {
        vm.warp(block.timestamp + 30 days);

        vm.prank(spender);
        vm.expectRevert(bytes("Not beneficiary"));
        teamVesting.release();
    }
}
