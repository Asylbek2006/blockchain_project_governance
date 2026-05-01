// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/TokenVesting.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;
    TokenVesting vesting;

    address teamVesting = makeAddr("teamVesting");
    address treasury = makeAddr("treasury");
    address community = makeAddr("community");
    address liquidity = makeAddr("liquidity");
    address asylbek = makeAddr("asylbek");
    address bigali = makeAddr("bigali");

    uint256 constant TOTAL_SUPPLY = 1_000_000 * 10**18;

    function setUp() public {
        address vestingPlaceholder = makeAddr("vestingPlaceholder");
        token = new GovernanceToken(vestingPlaceholder, treasury, community, liquidity);
        vesting = new TokenVesting(address(token), teamVesting);
    
        uint256 teamAmount = token.balanceOf(vestingPlaceholder);
        vm.startPrank(vestingPlaceholder);
        token.transfer(address(vesting), teamAmount);
        vm.stopPrank();
    
        vesting.updateTotalVestedAmount();
    }

    function test_InitialDistribution() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(treasury), (TOTAL_SUPPLY * 30) / 100);
        assertEq(token.balanceOf(community), (TOTAL_SUPPLY * 20) / 100);
        assertEq(token.balanceOf(liquidity), (TOTAL_SUPPLY * 10) / 100);
    }

    function test_DelegationIncreasesVotingPower() public {
        vm.prank(community);
        token.delegate(community);
        assertEq(token.getVotes(community), (TOTAL_SUPPLY * 20) / 100);
    }

    function test_DelegateToBigali() public {
        vm.prank(community);
        token.delegate(bigali);
        assertEq(token.getVotes(bigali), (TOTAL_SUPPLY * 20) / 100);
        assertEq(token.getVotes(community), 0);
    }

    function test_VotingPowerSnapshot() public {
        vm.prank(community);
        token.delegate(community);
        uint256 blockNumber = block.number;
        vm.roll(blockNumber + 1);
        assertEq(token.getPastVotes(community, blockNumber), (TOTAL_SUPPLY * 20) / 100);
    }

    function test_VotingPowerAfterTransfer() public {
        vm.prank(community);
        token.delegate(community);
        uint256 transferAmount = 100 * 10**18;
        vm.prank(community);
        token.transfer(bigali, transferAmount);
        vm.prank(bigali);
        token.delegate(bigali);
        assertEq(token.getVotes(bigali), transferAmount);
        assertEq(token.getVotes(community), (TOTAL_SUPPLY * 20) / 100 - transferAmount);
    }

    function test_VestingReleasesLinearlyAfter6Months() public {
        vm.warp(block.timestamp + 182 days);
        uint256 releasable = vesting.releasableAmount();
        uint256 expectedHalf = (TOTAL_SUPPLY * 40) / 100 / 2;
        assertApproxEqRel(releasable, expectedHalf, 0.01e18);
    }

    function test_VestingFullReleaseAfter12Months() public {
        vm.warp(block.timestamp + 365 days);
        vm.prank(teamVesting);
        vesting.release();
        assertEq(token.balanceOf(teamVesting), (TOTAL_SUPPLY * 40) / 100);
    }

    function test_VestingReleaseFailsIfNotBeneficiary() public {
        vm.warp(block.timestamp + 30 days);
        vm.prank(asylbek);
        vm.expectRevert();
        vesting.release();
    }

    function test_VestingNoTokensBeforeTime() public view {
        uint256 releasable = vesting.releasableAmount();
        assertEq(releasable, 0);
    }

    function test_PermitAllowsGaslessApproval() public {
        uint256 privateKey = 0xA11CE;
        address permitOwner = vm.addr(privateKey);
        uint256 amount = 1000 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(community);
        token.transfer(permitOwner, amount);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            permitOwner,
            asylbek,
            amount,
            token.nonces(permitOwner),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(permitOwner, asylbek, amount, deadline, v, r, s);
        assertEq(token.allowance(permitOwner, asylbek), amount);
    }
}