# Deployment Checklist

## Before Deployment

1. Run `forge fmt`.
2. Run `forge build`.
3. Run `forge test -vv`.
4. Run `slither .`.
5. Confirm `PRIVATE_KEY`, `RPC_URL`, `ETHERSCAN_API_KEY`, `TEAM_WALLET`, `COMMUNITY_AIRDROP_WALLET`, and `LIQUIDITY_POOL_WALLET`.
6. Confirm the deployer wallet has enough ETH for deployment and verification.
7. Confirm the team, community, and liquidity addresses are controlled by the correct operators.

## Deployment Command

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --broadcast --verify
```

## Deployment Order

1. Deploy `TimelockController` with a 2 day delay.
2. Deploy `Treasury` with the Timelock as controller.
3. Deploy `GovernanceToken` with initial distribution receivers.
4. Deploy `TokenVesting` with 365 day linear team vesting.
5. Deploy `Box` with the Timelock as owner.
6. Deploy `MyGovernor` with token voting and Timelock execution.
7. Grant `PROPOSER_ROLE` to `MyGovernor`.
8. Grant `CANCELLER_ROLE` to `MyGovernor`.
9. Grant `EXECUTOR_ROLE` to `address(0)` so any account can execute ready approved proposals.
10. Revoke `DEFAULT_ADMIN_ROLE` from the deployer.

## Verified Contract Links

Replace these placeholders after Sepolia deployment:

| Contract | Address | Etherscan link |
| --- | --- | --- |
| GovernanceToken | `<TOKEN_ADDRESS>` | `https://sepolia.etherscan.io/address/<TOKEN_ADDRESS>#code` |
| TokenVesting | `<VESTING_ADDRESS>` | `https://sepolia.etherscan.io/address/<VESTING_ADDRESS>#code` |
| TimelockController | `<TIMELOCK_ADDRESS>` | `https://sepolia.etherscan.io/address/<TIMELOCK_ADDRESS>#code` |
| MyGovernor | `<GOVERNOR_ADDRESS>` | `https://sepolia.etherscan.io/address/<GOVERNOR_ADDRESS>#code` |
| Treasury | `<TREASURY_ADDRESS>` | `https://sepolia.etherscan.io/address/<TREASURY_ADDRESS>#code` |
| Box | `<BOX_ADDRESS>` | `https://sepolia.etherscan.io/address/<BOX_ADDRESS>#code` |

## Manual Verification Commands

Use these only if `--verify` does not complete automatically:

```bash
forge verify-contract <TOKEN_ADDRESS> src/GovernanceToken.sol:GovernanceToken --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
forge verify-contract <VESTING_ADDRESS> src/TokenVesting.sol:TokenVesting --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
forge verify-contract <GOVERNOR_ADDRESS> src/MyGovernor.sol:MyGovernor --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
forge verify-contract <TREASURY_ADDRESS> src/Treasury.sol:Treasury --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
forge verify-contract <BOX_ADDRESS> src/Box.sol:Box --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
```

## Post-Deployment Checks

| Check | Expected value |
| --- | --- |
| Token name | `GovernanceToken` |
| Token symbol | `GOV` |
| Token total supply | 100,000,000 GOV |
| Token vesting balance | 40,000,000 GOV |
| Treasury token balance | 30,000,000 GOV |
| Community airdrop balance | 20,000,000 GOV |
| Liquidity balance | 10,000,000 GOV |
| Voting delay | 7,200 blocks |
| Voting period | 50,400 blocks |
| Proposal threshold | 1,000,000 GOV |
| Quorum | 4,000,000 GOV |
| Timelock delay | 2 days |
| Treasury controller | Timelock |
| Box owner | Timelock |
| Timelock proposer | Governor only |
| Timelock canceller | Governor only |
| Timelock executor | Open executor role |
| Timelock admin | Timelock itself, not deployer |

## Monitoring Plan

| Source | Events or metrics |
| --- | --- |
| Governor | `ProposalCreated`, `VoteCast`, `ProposalQueued`, `ProposalExecuted`, `ProposalCanceled` |
| Timelock | `CallScheduled`, `CallExecuted`, `Cancelled`, `MinDelayChange` |
| Token | `DelegateChanged`, `DelegateVotesChanged`, `Transfer`, `Approval` |
| Treasury | `EthReceived`, `EthTransferred`, `TokensTransferred`, `SpendingLimitUpdated`, `ExternalCallExecuted` |
| Box | `ValueStored` |
| Risk metrics | Top delegated wallets, quorum margin, proposal target addresses, queued treasury outflows, execution readiness, failed executions |

## Emergency Review Process

1. Review every proposal target, value, calldata, and description.
2. Decode calldata before voting.
3. Compare treasury outflow to available treasury balances.
4. Check whether voting power moved shortly before the proposal snapshot.
5. During the 2 day timelock, publish a summary of the proposal impact.
6. If a malicious proposal is detected, warn token holders and prepare migration or emergency response.
