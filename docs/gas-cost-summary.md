# Gas Cost Summary

Local Foundry test gas from `forge test -vv`:

| Action | Test | Gas |
| --- | --- | ---: |
| Box governance lifecycle | `testEndToEndGovernanceStoresValueInBox` | 359,519 |
| Treasury ETH transfer lifecycle | `testEndToEndGovernanceTransfersEthFromTreasury` | 344,250 |
| Treasury token transfer lifecycle | `testEndToEndGovernanceTransfersTokensFromTreasury` | 354,840 |
| Governor Box lifecycle | `testFullLifecycleStoresFortyTwoInBox` | 327,559 |
| Governor treasury token transfer | `testFullLifecycleTransfersTokensFromTreasury` | 350,020 |
| Governor treasury ETH transfer | `testFullLifecycleTransfersEthFromTreasury` | 343,311 |
| Treasury parameter change | `testFullLifecycleChangesTreasuryParameter` | 325,081 |
| Permit approval | `testPermitApprovesSpenderWithSignedMessage` | 114,560 |
| Self delegation | `testHolderCanDelegateVotesToSelf` | 88,729 |
| Delegation to representative | `testHolderCanDelegateVotesToAnotherAccount` | 94,739 |

Use `forge snapshot` before final submission if your instructor asks for a dedicated `.gas-snapshot` file.
