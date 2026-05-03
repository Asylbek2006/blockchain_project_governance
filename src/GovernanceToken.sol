// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint256 public constant TOTAL_SUPPLY = 100_000_000;

    constructor(address _vestingContract, address _treasury, address _communityAirdrop, address _liquidityPool, address _initialOwner)
        ERC20("GovernanceToken", "GOV")
        ERC20Permit("GovernanceToken")
        Ownable(_initialOwner)
    {
        _mint(_vestingContract,  (TOTAL_SUPPLY * 40) / 100);
        _mint(_treasury,         (TOTAL_SUPPLY * 30) / 100);
        _mint(_communityAirdrop, (TOTAL_SUPPLY * 20) / 100);
        _mint(_liquidityPool,    (TOTAL_SUPPLY * 10) / 100);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}