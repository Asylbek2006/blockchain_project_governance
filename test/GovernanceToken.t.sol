// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/TokenVesting.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;
    TokenVesting vesting;

    address team = address(1);
    address treasury = address(2);
    address community = address(3);
    address liquidity = address(4);
    address user = address(5);

    function setUp() public {
        address vestingAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        token = new GovernanceToken(vestingAddr, treasury, community, liquidity, address(this));
        vesting = new TokenVesting(address(token), team, block.timestamp, 365 days);
        assertEq(address(vesting), vestingAddr);
    }

    function test_InitialDistribution() public view {
        assertEq(token.balanceOf(address(vesting)), 40_000_000 ether);
        assertEq(token.balanceOf(treasury), 30_000_000 ether);
        assertEq(token.balanceOf(community), 20_000_000 ether);
        assertEq(token.balanceOf(liquidity), 10_000_000 ether);
        assertEq(token.totalSupply(), 100_000_000 ether);
    }

    function test_Delegation() public {
        vm.prank(treasury);
        token.delegate(treasury);
        assertEq(token.getVotes(treasury), 30_000_000 ether);
    }

    function test_TransferUpdatesVotes() public {
        vm.prank(treasury);
        token.delegate(treasury);
        vm.prank(treasury);
        token.transfer(user, 100 ether);
        assertEq(token.getVotes(treasury), 29_999_900 ether);
    }

    function test_PastVotes() public {
        vm.prank(treasury);
        token.delegate(treasury);
        uint256 block1 = block.number;
        vm.roll(block1 + 1);
        vm.prank(treasury);
        token.transfer(user, 100 ether);
        assertEq(token.getPastVotes(treasury, block1), 30_000_000 ether);
    }

    function test_Permit() public {
        uint256 privateKey = 0xABC12;
        address owner      = vm.addr(privateKey);
        vm.prank(treasury);
        token.transfer(owner, 100 ether);
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    owner,
                    user,
                    50 ether,
                    nonce,
                    deadline
                ))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        token.permit(owner, user, 50 ether, deadline, v, r, s);
        assertEq(token.allowance(owner, user), 50 ether);
    }

    function test_VestingBeforeStart() public view {
        assertEq(vesting.releasable(), 0);
    }

    function test_VestingHalf() public {
        vm.warp(block.timestamp + 182 days);
        uint256 amount = vesting.releasable();
        assertGt(amount, 0);
    }

    function test_VestingFull() public {
        vm.warp(block.timestamp + 365 days);
        uint256 amount = vesting.releasable();
        assertEq(amount, 40_000_000 ether);
        vm.prank(team);
        vesting.release();
        assertEq(token.balanceOf(team), 40_000_000 ether);
        assertEq(vesting.released(), 40_000_000 ether);
    }
}
