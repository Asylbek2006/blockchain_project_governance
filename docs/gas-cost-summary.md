# Gas Cost Summary

Generate the final gas report with:

```bash
forge test --gas-report
```

Record the final numbers in this table before submission:

| Action | Test |
| --- | --- |
| Token delegation | `test_Delegation` |
| Voting power snapshot | `test_PastVotes` |
| Permit approval | `test_Permit` |
| Vesting release | `test_VestingFull` |
| Box governance lifecycle | `test_FullProposalLifecycleStoresBoxValue` |
| Treasury token transfer lifecycle | `test_TreasuryTransfersTokensThroughGovernance` |
| Treasury parameter change | `test_GovernanceChangesTreasuryParameter` |
| Delegated voting | `test_DelegateeVotesOnBehalfOfDelegator` |
| Failed quorum proposal | `test_ProposalFailsWhenQuorumIsNotMet` |

Use `forge snapshot` if your instructor asks for a dedicated `.gas-snapshot` file.
