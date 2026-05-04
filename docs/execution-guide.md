# Execution Guide

## Local Test Run

1. Install Foundry.
2. Run `forge fmt`.
3. Run `forge build`.
4. Run `forge test -vv`.
5. Confirm every test passes.

## Local Deployment

1. Start Anvil with `anvil`.
2. Export deployment variables:

```bash
export PRIVATE_KEY="0x..."
export TEAM_WALLET="0x..."
export COMMUNITY_AIRDROP_WALLET="0x..."
export LIQUIDITY_POOL_WALLET="0x..."
```

3. Deploy:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

4. Copy the printed `GovernanceToken` and `MyGovernor` addresses into the frontend contract fields.

## Testnet Deployment

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --broadcast --verify
```

Required environment variables:

| Variable | Purpose |
| --- | --- |
| `PRIVATE_KEY` | Deployment wallet private key |
| `RPC_URL` | Sepolia RPC endpoint from `foundry.toml` |
| `ETHERSCAN_API_KEY` | Contract verification |
| `TEAM_WALLET` | Team vesting beneficiary |
| `COMMUNITY_AIRDROP_WALLET` | Community allocation receiver |
| `LIQUIDITY_POOL_WALLET` | Liquidity allocation receiver |

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
