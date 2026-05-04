# Governance Execution Log

Use this document during the final demo. Replace placeholder transaction hashes and screenshot filenames with your own local or Sepolia results.

## Environment

| Item | Value |
| --- | --- |
| Network | Sepolia or local Anvil |
| Voting delay | 7,200 blocks |
| Voting period | 50,400 blocks |
| Timelock delay | 2 days |
| Proposal threshold | 1,000,000 GOV |
| Quorum | 4,000,000 GOV |

## Deployment

1. Deploy `TimelockController`.
2. Deploy `Treasury` controlled by `TimelockController`.
3. Deploy `GovernanceToken` with the 40/30/20/10 distribution.
4. Deploy `TokenVesting` for the team allocation.
5. Deploy `Box` owned by `TimelockController`.
6. Deploy `MyGovernor`.
7. Grant proposer and canceller roles to `MyGovernor`.
8. Grant open executor role to `address(0)`.
9. Revoke deployer admin role from `TimelockController`.

Screenshot: `screenshots/01-deployment.png`

## Delegation

1. Call `GovernanceToken.delegate(delegateAddress)`.
2. Confirm `getVotes(delegateAddress)` returns delegated voting power.

Transaction hash: `<delegation transaction hash>`

Screenshot: `screenshots/02-delegation.png`

## Box Proposal

1. Encode calldata with `Box.store(42)`.
2. Call `MyGovernor.propose`.
3. Confirm proposal state is `Pending`.

Transaction hash: `<proposal transaction hash>`

Screenshot: `screenshots/03-proposal-created.png`

## Voting

1. Wait until voting delay passes.
2. Confirm proposal state is `Active`.
3. Call `MyGovernor.castVote(proposalId, 1)`.
4. Confirm vote result appears in the frontend.

Transaction hash: `<vote transaction hash>`

Screenshot: `screenshots/04-vote-cast.png`

## Queue

1. Wait until voting period ends.
2. Confirm proposal state is `Succeeded`.
3. Call `MyGovernor.queue`.
4. Confirm proposal state is `Queued`.

Transaction hash: `<queue transaction hash>`

Screenshot: `screenshots/05-queued.png`

## Execute

1. Wait until timelock delay passes.
2. Call `MyGovernor.execute`.
3. Confirm proposal state is `Executed`.
4. Call `Box.retrieve()` and confirm the value is `42`.

Transaction hash: `<execute transaction hash>`

Screenshot: `screenshots/06-executed-box-42.png`

## Treasury Proposal

1. Encode calldata with `Treasury.transferERC20(token, recipient, amount)`.
2. Complete propose, vote, queue, execute.
3. Confirm recipient token balance increased.

Transaction hash: `<treasury execute transaction hash>`

Screenshot: `screenshots/07-treasury-transfer.png`
