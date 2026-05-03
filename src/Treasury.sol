// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract Treasury {
    address public immutable timelock;

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Not timelock");
        _;
    }

    constructor(address _timelock) {
        timelock = _timelock;
    }

    receive() external payable {}

    function transferERC20(address token, address to, uint256 amount) external onlyTimelock {
        IERC20(token).transfer(to, amount);
    }

    function transferETH(address payable to, uint256 amount) external onlyTimelock{
        require(address(this).balance >= amount, "Not enough ETH");
        to.transfer(amount);
    }
}