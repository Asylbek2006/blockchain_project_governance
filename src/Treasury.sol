// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Treasury is Ownable, ReentrancyGuard {
    using Address for address payable;
    using SafeERC20 for IERC20;

    event EthReceived(address indexed sender, uint256 amount);
    event EthTransferred(address indexed recipient, uint256 amount);
    event TokensTransferred(address indexed token, address indexed recipient, uint256 amount);
    event ExternalCallExecuted(address indexed target, uint256 value, bytes data, bytes result);
    event SpendingLimitUpdated(uint256 newSpendingLimit);

    uint256 public spendingLimit;

    constructor(address timelockAddress) Ownable(timelockAddress) {}

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    function transferEth(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        require(recipient != address(0), "Zero address");
        require(address(this).balance >= amount, "Insufficient ETH");

        recipient.sendValue(amount);

        emit EthTransferred(recipient, amount);
    }

    function transferTokens(address token, address recipient, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(0), "Zero token address");
        require(recipient != address(0), "Zero recipient");
        IERC20(token).safeTransfer(recipient, amount);

        emit TokensTransferred(token, recipient, amount);
    }

    function updateSpendingLimit(uint256 newSpendingLimit) external onlyOwner {
        spendingLimit = newSpendingLimit;

        emit SpendingLimitUpdated(newSpendingLimit);
    }

    function executeExternalCall(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        nonReentrant
        returns (bytes memory result)
    {
        require(target != address(0), "Zero target");
        require(address(this).balance >= value, "Insufficient ETH");

        (bool success, bytes memory response) = target.call{value: value}(data);

        require(success, "External call failed");

        emit ExternalCallExecuted(target, value, data, response);

        return response;
    }

    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
