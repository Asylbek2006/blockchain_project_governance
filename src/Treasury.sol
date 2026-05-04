// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Treasury {
    using SafeERC20 for IERC20;

    address public immutable timelock;
    uint256 public spendingLimit;

    event EthReceived(address indexed sender, uint256 amount);
    event EthTransferred(address indexed recipient, uint256 amount);
    event TokensTransferred(address indexed token, address indexed recipient, uint256 amount);
    event SpendingLimitUpdated(uint256 oldSpendingLimit, uint256 newSpendingLimit);
    event ExternalCallExecuted(address indexed target, uint256 value, bytes data, bytes result);

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Caller is not timelock");
        _;
    }

    constructor(address timelockAddress) {
        require(timelockAddress != address(0), "Invalid timelock");
        timelock = timelockAddress;
    }

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    function transferERC20(address token, address to, uint256 amount) external onlyTimelock {
        require(to != address(0), "Invalid recipient");

        IERC20(token).safeTransfer(to, amount);

        emit TokensTransferred(token, to, amount);
    }

    function transferETH(address payable to, uint256 amount) external onlyTimelock {
        require(to != address(0), "Invalid recipient");
        require(address(this).balance >= amount, "Not enough ETH");

        (bool transferSucceeded,) = to.call{value: amount}("");
        require(transferSucceeded, "ETH transfer failed");

        emit EthTransferred(to, amount);
    }

    function setSpendingLimit(uint256 newSpendingLimit) external onlyTimelock {
        uint256 oldSpendingLimit = spendingLimit;
        spendingLimit = newSpendingLimit;

        emit SpendingLimitUpdated(oldSpendingLimit, newSpendingLimit);
    }

    function executeExternalCall(address target, uint256 value, bytes calldata data)
        external
        onlyTimelock
        returns (bytes memory)
    {
        require(target != address(0), "Invalid target");
        require(address(this).balance >= value, "Not enough ETH");

        (bool callSucceeded, bytes memory result) = target.call{value: value}(data);
        require(callSucceeded, "External call failed");

        emit ExternalCallExecuted(target, value, data, result);

        return result;
    }
}
