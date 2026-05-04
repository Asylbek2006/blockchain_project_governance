# Defense Preparation

## Demo Flow

1. Show `GovernanceToken.sol` and explain ERC20Votes plus ERC20Permit.
2. Show the distribution constants: 40% team, 30% treasury, 20% community, 10% liquidity.
3. Show `TokenVesting.sol` and explain linear release over 365 days.
4. Run `forge test -vv` and point to the passing token, governance, and end-to-end tests.
5. Show `MyGovernor.sol` parameters: 7,200 block delay, 50,400 block period, 1% threshold, 4% quorum.
6. Show Timelock ownership of `Treasury` and `Box`.
7. Demonstrate `Box.store(42)` through governance.
8. Demonstrate treasury token transfer through governance.
9. Open the frontend, connect MetaMask, show balance, voting power, delegate, proposal state, and vote buttons.
10. Finish with audit risks and safeguards.

## Questions To Prepare

| Question | Short answer |
| --- | --- |
| Why ERC20Votes? | It stores historical vote checkpoints for Governor snapshots. |
| Why ERC20Permit? | It enables signed approvals without a separate approval transaction. |
| Why Timelock? | It delays execution so users can inspect or react to successful proposals. |
| Can a whale pass proposals? | Yes, if they control enough delegated voting power; mitigations are quorum, timelock, monitoring, guardian, and higher thresholds. |
| Why flash loans are harder here? | Voting power is checked from snapshot blocks, not the current transaction balance. |
| Why Box is owned by Timelock? | Direct users cannot change it; only executed governance proposals can call `store`. |
| Why the frontend tracks proposal IDs manually? | OpenZeppelin Governor does not store an enumerable proposal list on-chain. |

## Video Structure

| Minute | Content |
| --- | --- |
| 0:00-1:00 | Project goal and architecture |
| 1:00-3:00 | Token, distribution, vesting |
| 3:00-5:00 | Delegation and voting snapshots |
| 5:00-8:00 | Full proposal lifecycle |
| 8:00-10:00 | Treasury and Box execution |
| 10:00-12:00 | Frontend walkthrough |
| 12:00-14:00 | Security audit and attack analysis |
| 14:00-15:00 | Gas and final summary |
