# Execution Guide

## Local Test Run

1. Install Foundry.
2. Run `forge build`.
3. Run `forge test -vv`.
4. Confirm the test result shows 24 passing tests.

## Local Deployment

1. Start Anvil with `anvil`.
2. Export deployment variables:

```powershell
$env:TEAM_BENEFICIARY="0x..."
$env:COMMUNITY_AIRDROP="0x..."
$env:LIQUIDITY_POOL="0x..."
```

3. Deploy:

```powershell
forge script script/DeployDao.s.sol:DeployDao --rpc-url http://127.0.0.1:8545 --private-key <PRIVATE_KEY> --broadcast
```

4. Copy addresses from `deployment-addresses.json` into `frontend/index.html` through the UI fields.

## Governance Lifecycle Demo

1. Delegate proposer votes with `GovernanceToken.delegate(proposer)`.
2. Create a proposal through `MyGovernor.propose`.
3. Wait 7,200 blocks.
4. Vote with `MyGovernor.castVote(proposalId, 1)`.
5. Wait 50,400 blocks.
6. Queue with `MyGovernor.queue`.
7. Wait 2 days.
8. Execute with `MyGovernor.execute`.
9. Verify the target state changed.

## Required Screenshots

Take screenshots for these moments:

1. Successful deployment transaction.
2. Initial token distribution balances.
3. Vote delegation transaction.
4. Proposal creation transaction.
5. Active proposal in the frontend.
6. Successful vote transaction.
7. Proposal queued state.
8. Proposal executed state.
9. Treasury token transfer result.
10. `Box.retrieve()` returning `42`.
