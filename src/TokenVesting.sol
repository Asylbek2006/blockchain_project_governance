// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;

    uint256 public immutable start;
    uint256 public immutable duration;

    uint256 public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(address tokenAddress, address beneficiaryAddress, uint256 startTimestamp, uint256 vestingDuration) {
        require(tokenAddress != address(0), "Invalid token");
        require(beneficiaryAddress != address(0), "Invalid beneficiary");
        require(vestingDuration > 0, "Invalid duration");

        token = IERC20(tokenAddress);
        beneficiary = beneficiaryAddress;
        start = startTimestamp;
        duration = vestingDuration;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 total = token.balanceOf(address(this)) + released;

        if (timestamp < start) {
            return 0;
        } else if (timestamp >= start + duration) {
            return total;
        } else {
            return (total * (timestamp - start)) / duration;
        }
    }

    function release() external {
        uint256 amount = releasable();
        require(amount > 0, "nothing to release");

        released += amount;
        token.safeTransfer(beneficiary, amount);

        emit TokensReleased(beneficiary, amount);
    }
}
