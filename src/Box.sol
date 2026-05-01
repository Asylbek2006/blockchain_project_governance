// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private storedValue;

    event ValueChanged(uint256 newValue);

    constructor(address timelockAddress) Ownable(timelockAddress) {}

    function store(uint256 newValue) public onlyOwner {
        storedValue = newValue;
        emit ValueChanged(newValue);
    }

    function retrieve() public view returns(uint256) {
        return storedValue;
    }
}