# Security Audit Report

## Scope

Reviewed contracts:

| Contract | Purpose |
| --- | --- |
| `GovernanceToken.sol` | ERC20Votes and ERC20Permit governance token |
| `TokenVesting.sol` | Linear team token vesting |
| `MyGovernor.sol` | Token-weighted DAO governance |
| `Treasury.sol` | Timelock-owned ETH and ERC20 treasury |
| `Box.sol` | Timelock-owned controlled contract |

## Automated Analysis

Run Slither with:

```powershell
slither .
```

If Slither is not installed:

```powershell
pipx install slither-analyzer
slither .
```

Expected review focus:

| Area | Expected result |
| --- | --- |
| Reentrancy | No direct reentrancy in current token and treasury transfers; generic calls must be reviewed per target |
| Access control | Treasury and Box are restricted to the Timelock owner |
| Token voting | Uses OpenZeppelin ERC20Votes snapshots |
| Permit | Uses OpenZeppelin ERC20Permit |
| Timelock | Governor is proposer and canceller; execution is open after successful delay |

## Manual Findings

### Informational: Open executor role

The Timelock grants `EXECUTOR_ROLE` to `address(0)`, which allows anyone to execute a queued and ready proposal. This is common because execution is already constrained by proposal approval and the timelock delay. Operational monitoring should watch queued operations so the DAO knows what can be executed.

### Medium: Whale governance control

A wallet with more than 50% of delegated voting power can pass any proposal that satisfies the timelock and quorum rules. Existing safeguards are the 1 day voting delay, 1 week voting period, 4% quorum, and 2 day timelock. Stronger production safeguards include delegation caps, multisig emergency veto, proposal guardian, higher quorum for sensitive actions, and vote escrow or time-weighted voting.

### Low: Generic treasury execution risk

`Treasury.executeExternalCall` allows governance to call arbitrary contracts. This is intentional for upgrades and advanced treasury operations, but every proposal using it needs careful calldata review before voting.

### Low: Team allocation deployment trust

The deployment script temporarily mints team tokens to the deployer before moving them into `TokenVesting`. The transaction sequence must be executed atomically in one deployment script. After deployment, verify that the deployer has no team allocation balance.

## Flash Loan Attack Analysis

The governance token uses `ERC20Votes`, which reads voting power from historical checkpoints. A voter must have voting power at the proposal snapshot block, not only inside the vote transaction. This prevents a basic flash loan attack where tokens are borrowed, used to vote, and returned in the same transaction. A stronger attacker could still borrow or buy tokens before the snapshot, so voting delay, monitoring, and timelock review remain important.

## Recommendations

1. Use a multisig as the initial deployer and deployment operator.
2. Publish verified source code for every contract.
3. Add a proposal guardian or emergency veto for early production.
4. Increase quorum for treasury-draining actions.
5. Monitor large delegation changes, new proposals, queued operations, and treasury transfers.
6. Require human-readable proposal descriptions with exact target addresses and calldata.
