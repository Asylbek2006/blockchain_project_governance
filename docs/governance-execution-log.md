# Governance Execution Log

Use this document during the final demo. Replace placeholder transaction hashes and screenshot filenames with your own testnet results.

## Environment

| Item | Value |
| --- | --- |
| Network | Sepolia or local Anvil |
| Voting delay | 7,200 blocks |
| Voting period | 50,400 blocks |
| Timelock delay | 2 days |
| Proposal threshold | 10,000 GOV |
| Quorum | 40,000 GOV |

## Deployment

1. Deploy `GovernanceToken`, `TokenVesting`, `TimelockController`, `MyGovernor`, `Treasury`, and `Box`.
2. Transfer 400,000 GOV to `TokenVesting`.
3. Transfer 300,000 GOV to `Treasury`.
4. Grant proposer and canceller roles to `MyGovernor`.
5. Revoke deployer admin role from `TimelockController`.

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

1. Encode calldata with `Treasury.transferTokens(token, recipient, amount)`.
2. Complete propose, vote, queue, execute.
3. Confirm recipient token balance increased.

Transaction hash: `<treasury execute transaction hash>`

Screenshot: `screenshots/07-treasury-transfer.png`
