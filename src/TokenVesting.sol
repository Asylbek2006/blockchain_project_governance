// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public governanceToken;
    address public teamBeneficiary;
    uint256 public vestingStartTime;
    uint256 public vestingDuration = 365 days;
    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(address _governanceToken, address _teamBeneficiary) {
        require(_governanceToken != address(0), "Zero token address");
        require(_teamBeneficiary != address(0), "Zero beneficiary address");

        governanceToken = IERC20(_governanceToken);
        teamBeneficiary = _teamBeneficiary;
        vestingStartTime = block.timestamp;
        totalVestedAmount = governanceToken.balanceOf(address(this));
    }

    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - totalReleasedAmount;
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < vestingStartTime) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - vestingStartTime;

        if (elapsedTime >= vestingDuration) {
            return totalVestedAmount;
        }

        return (totalVestedAmount * elapsedTime) / vestingDuration;
    }

    function release() public {
        require(msg.sender == teamBeneficiary, "Not beneficiary");

        uint256 amount = releasableAmount();

        require(amount > 0, "No tokens to release");

        totalReleasedAmount += amount;
        require(governanceToken.transfer(teamBeneficiary, amount), "Transfer failed");

        emit TokensReleased(teamBeneficiary, amount);
    }

    function updateTotalVestedAmount() public {
        totalVestedAmount = governanceToken.balanceOf(address(this)) + totalReleasedAmount;
    }
}
