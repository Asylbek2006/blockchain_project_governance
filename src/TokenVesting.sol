// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public immutable token;
    address public immutable beneficiary;

    uint256 public immutable start;
    uint256 public immutable duration;

    uint256 public released;

    constructor(address _token, address _beneficiary, uint256 _start, uint256 _duration) {
        require(_beneficiary != address(0), "zero addr");

        token = IERC20(_token);
        beneficiary = _beneficiary;
        start = _start;
        duration = _duration;
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
        token.transfer(beneficiary, amount);
    }
}