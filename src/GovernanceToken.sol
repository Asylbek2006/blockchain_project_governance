// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 10 ** 18;

    uint256 public constant TEAM_ALLOCATION = (TOTAL_SUPPLY * 40) / 100;
    uint256 public constant TREASURY_ALLOCATION = (TOTAL_SUPPLY * 30) / 100;
    uint256 public constant COMMUNITY_ALLOCATION = (TOTAL_SUPPLY * 20) / 100;
    uint256 public constant LIQUIDITY_ALLOCATION = (TOTAL_SUPPLY * 10) / 100;

    constructor(address teamTokenReceiver, address treasury, address communityAirdrop, address liquidityPool)
        ERC20("Governance Token", "GOV")
        ERC20Permit("Governance Token")
    {
        require(teamTokenReceiver != address(0), "Invalid team receiver");
        require(treasury != address(0), "Invalid treasury");
        require(communityAirdrop != address(0), "Invalid community airdrop");
        require(liquidityPool != address(0), "Invalid liquidity pool");

        _mint(teamTokenReceiver, TEAM_ALLOCATION);
        _mint(treasury, TREASURY_ALLOCATION);
        _mint(communityAirdrop, COMMUNITY_ALLOCATION);
        _mint(liquidityPool, LIQUIDITY_ALLOCATION);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
