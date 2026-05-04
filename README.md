# DAO & On-Chain Governance System

This project implements a complete DAO governance system with an ERC20Votes token, ERC20Permit support, linear team vesting, OpenZeppelin Governor, TimelockController, timelock-owned treasury, controlled Box contract, tests, deployment script, frontend, and production documentation.

## Contracts

| File | Purpose |
| --- | --- |
| `src/GovernanceToken.sol` | ERC20Votes and ERC20Permit governance token |
| `src/TokenVesting.sol` | 365 day linear team vesting |
| `src/MyGovernor.sol` | Governor with 1 day voting delay, 1 week voting period, 1% proposal threshold, 4% quorum |
| `src/Treasury.sol` | Timelock-owned ETH and ERC20 treasury |
| `src/Box.sol` | Timelock-owned controlled contract |

## Tests

Run:

```bash
forge test -vv
```

Coverage by test suite:

| Test file | Coverage |
| --- | --- |
| `test/GovernanceToken.t.sol` | Distribution, delegation, snapshots, permit signatures, vesting |
| `test/Governance.t.sol` | Proposal lifecycle, treasury transfers, parameter changes, Box.store(42), delegated voting, defeated proposals, timelock delay |
| `test/end_to_end_test.t.sol` | Task 3 end-to-end governance test: propose, vote, queue, execute, verify |

## Deployment

Set environment variables:

```bash
export PRIVATE_KEY="0x..."
export TEAM_WALLET="0x..."
export COMMUNITY_AIRDROP_WALLET="0x..."
export LIQUIDITY_POOL_WALLET="0x..."
```

Deploy:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --broadcast --verify
```

The script prints deployed contract addresses to the terminal.

## Frontend

Open `frontend/index.html` in a browser or serve the folder with any static server. Connect MetaMask, enter token and governor addresses, then use the UI to view balances, voting power, delegates, proposal state, proposal votes, and cast votes.

## Documentation

| Document | Content |
| --- | --- |
| `docs/token-distribution.md` | Distribution diagram and allocation table |
| `docs/execution-guide.md` | Local run, deployment, lifecycle steps, screenshot checklist |
| `docs/security-audit-report.md` | Slither command, manual findings, governance attack analysis |
| `docs/deployment-checklist.md` | Deployment order, verification, post-deployment checks, monitoring |
| `docs/research-analysis.md` | Governance models, DAO examples, attacks, legal notes, future models |
| `docs/defense-preparation.md` | Defense script, expected questions, video structure |
| `docs/governance-execution-log.md` | Proposal lifecycle execution log and screenshot checklist |
| `docs/gas-cost-summary.md` | Gas cost table for demo and final video |
