# Security Audit Report

## Scope

| Contract | Purpose |
| --- | --- |
| `GovernanceToken.sol` | ERC20Votes and ERC20Permit governance token |
| `TokenVesting.sol` | Linear team token vesting |
| `MyGovernor.sol` | Token-weighted Governor with quorum and threshold rules |
| `TimelockController` | Delayed execution and permission control |
| `Treasury.sol` | Timelock-controlled ETH and ERC20 treasury |
| `Box.sol` | Timelock-owned controlled contract used for governance execution demos |

## Automated Analysis

Run Slither from the repository root:

```bash
slither .
```

If Slither is not installed:

```bash
python3 -m pip install slither-analyzer
slither .
```

Expected review focus:

| Area | Result |
| --- | --- |
| Reentrancy | Treasury uses `SafeERC20` for token transfers and emits events after state-changing actions. ETH and external calls are Timelock-only. |
| Access control | Treasury actions are restricted to the Timelock. Box is owned by the Timelock. Governor is the only Timelock proposer and canceller. |
| Low-level calls | `Treasury.executeExternalCall` intentionally allows arbitrary governance execution. Every proposal using it must be decoded and reviewed before voting. |
| Timestamp dependence | Token vesting uses `block.timestamp`, which is acceptable for linear release schedules. |
| Dangerous role setup | Deployment revokes deployer admin after granting Governor proposer/canceller roles and open executor role. |
| ERC20 return values | Treasury uses OpenZeppelin `SafeERC20`. |

In this execution environment Slither was not available, so the final submission should include a fresh terminal screenshot of `slither .` from the defense machine.

## Manual Findings

### Medium: Whale governance control

A wallet or coordinated group with more than 50% of delegated voting power can pass proposals that meet the threshold and quorum. The current safeguards are a 1 day voting delay, 1 week voting period, 4% quorum, and 2 day Timelock delay. These safeguards slow attacks and give token holders time to react, but they do not stop majority control.

Recommendation: add higher quorum for treasury-draining actions, a proposal guardian during early deployment, delegation monitoring, and social processes for emergency migration.

### Medium: Arbitrary external treasury execution

`Treasury.executeExternalCall` lets governance call any target with ETH and calldata. This is required for advanced treasury operations and upgrade execution, but it creates proposal-level risk.

Recommendation: require decoded calldata in proposal descriptions, maintain an allowlist policy for routine operations, and give voters a checklist for target, value, calldata, and expected effects.

### Low: Open executor role

The Timelock grants `EXECUTOR_ROLE` to `address(0)`, so anyone can execute a queued proposal after the delay. This is a common pattern because execution is already constrained by successful voting and Timelock scheduling.

Recommendation: monitor ready operations and execute legitimate proposals quickly after the delay.

### Low: Linear vesting has no revocation

The vesting contract releases team tokens linearly over 365 days and does not include revocation. This is simple and transparent, but the DAO cannot claw back unreleased tokens if the team wallet becomes compromised.

Recommendation: for production, consider a revocable vesting design controlled by the Timelock or a security council.

### Informational: ERC20Votes requires delegation

Token balances do not automatically become voting power. Holders must delegate to themselves or another address.

Recommendation: explain delegation clearly in the frontend and demo.

## Flash Loan Attack Analysis

The governance token uses OpenZeppelin `ERC20Votes`, which stores vote checkpoints by block. A proposal uses voting power from the proposal snapshot block, not the current token balance inside the vote transaction. This blocks the basic flash loan pattern where an attacker borrows tokens, votes, and returns tokens in one transaction.

Residual risk remains if an attacker borrows or buys tokens before the snapshot block and keeps them through the snapshot. The voting delay and monitoring plan reduce this risk by making large delegation changes visible before voting begins.

## Centralization Analysis

The deployer has temporary admin authority only during deployment. After deployment, the script grants Governor roles and revokes the deployer admin role. The expected final state is:

| Permission | Final holder |
| --- | --- |
| Timelock proposer | `MyGovernor` |
| Timelock canceller | `MyGovernor` |
| Timelock executor | Open executor role |
| Timelock admin | Timelock itself |
| Treasury controller | Timelock |
| Box owner | Timelock |

If the deployer remains admin after deployment, the system is centralized and should not be considered production-ready.

## Recommendations

1. Use a multisig deployment wallet.
2. Verify every contract on Etherscan immediately after deployment.
3. Publish a proposal review checklist for voters.
4. Monitor large transfers and delegation changes before proposal snapshots.
5. Add a proposal guardian or emergency veto for the first production phase.
6. Raise quorum or add special policies for large treasury transfers.
7. Keep the Timelock delay long enough for public review.
8. Require proposal descriptions to include decoded calldata, target addresses, and expected post-execution state.
