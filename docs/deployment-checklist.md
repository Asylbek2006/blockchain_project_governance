# Deployment Checklist

## Before Deployment

1. Run `forge fmt`.
2. Run `forge build`.
3. Run `forge test -vv`.
4. Run `slither .`.
5. Review all deployment environment variables.
6. Confirm deployer wallet has enough testnet ETH.

## Deployment Order

1. Deploy `GovernanceToken`.
2. Deploy `TokenVesting`.
3. Deploy `TimelockController`.
4. Deploy `MyGovernor`.
5. Deploy `Treasury`.
6. Deploy `Box`.
7. Transfer team tokens to `TokenVesting`.
8. Transfer treasury tokens to `Treasury`.
9. Grant Timelock proposer and canceller roles to `MyGovernor`.
10. Revoke Timelock admin role from deployer.

## Verification Commands

```powershell
forge verify-contract <TOKEN_ADDRESS> src/GovernanceToken.sol:GovernanceToken --chain sepolia --etherscan-api-key $env:ETHERSCAN_API_KEY
forge verify-contract <VESTING_ADDRESS> src/TokenVesting.sol:TokenVesting --chain sepolia --etherscan-api-key $env:ETHERSCAN_API_KEY
forge verify-contract <GOVERNOR_ADDRESS> src/MyGovernor.sol:MyGovernor --chain sepolia --etherscan-api-key $env:ETHERSCAN_API_KEY
forge verify-contract <TREASURY_ADDRESS> src/Treasury.sol:Treasury --chain sepolia --etherscan-api-key $env:ETHERSCAN_API_KEY
forge verify-contract <BOX_ADDRESS> src/Box.sol:Box --chain sepolia --etherscan-api-key $env:ETHERSCAN_API_KEY
```

## Post-Deployment Checks

| Check | Expected value |
| --- | --- |
| Token total supply | 1,000,000 GOV |
| Token vesting balance | 400,000 GOV |
| Treasury token balance | 300,000 GOV |
| Voting delay | 7,200 blocks |
| Voting period | 50,400 blocks |
| Proposal threshold | 10,000 GOV |
| Quorum | 40,000 GOV |
| Timelock delay | 2 days |
| Treasury owner | Timelock |
| Box owner | Timelock |
| Timelock proposer | Governor |
| Timelock canceller | Governor |
| Timelock admin | Not deployer |

## Monitoring Plan

Track these events and metrics:

| Source | Events or metrics |
| --- | --- |
| Governor | ProposalCreated, VoteCast, ProposalQueued, ProposalExecuted |
| Timelock | CallScheduled, CallExecuted, Cancelled, MinDelayChange |
| Token | DelegateChanged, DelegateVotesChanged, Transfer |
| Treasury | EthReceived, EthTransferred, TokensTransferred, SpendingLimitUpdated |
| Box | ValueChanged |
| Risk metrics | Top delegated wallets, quorum margin, queued treasury outflows, execution deadline |
