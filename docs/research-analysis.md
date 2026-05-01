# DAO Governance Research

## Governance Models

Token-weighted voting is the most common DAO model. Each token equals voting power, which makes implementation simple and compatible with ERC20Votes. The weakness is plutocracy: large holders can dominate decisions.

Quadratic voting reduces whale dominance by making influence grow with the square root of voting weight. It can represent preference intensity better, but it needs Sybil resistance because one wealthy voter could split funds across many wallets.

Conviction voting lets support accumulate over time. It rewards long-term commitment and can work well for continuous funding decisions. It is harder to explain, harder to audit, and less familiar to most voters.

## Real-World DAO Analysis

Uniswap governance uses token-weighted voting with delegation. Major proposals often cover protocol deployments, fee changes, grants, and treasury programs. Turnout depends heavily on large delegates, so public delegate platforms and governance forums are important.

Aave governance uses token-weighted voting with safety-focused proposal review. Proposals often cover risk parameters, asset listings, caps, interest rate changes, and treasury actions. Aave shows the value of risk service providers because many proposals are technical and affect protocol solvency.

The key lesson from both DAOs is that governance is not only smart contracts. It also needs public discussion, clear proposal text, delegate accountability, monitoring, and post-execution review.

## Governance Attacks

Beanstalk was attacked through flash-loan governance. The attacker borrowed enough assets to gain voting power, passed a malicious proposal, executed it, and drained protocol funds. Prevention includes snapshot voting, longer voting delays, timelocks, proposal review, and limits on emergency execution.

Build Finance DAO suffered a hostile governance takeover. An attacker accumulated enough voting power to pass proposals that transferred control and minted tokens. Prevention includes quorum requirements, timelocks, emergency vetoes, active monitoring, and avoiding low participation governance.

## Legal Considerations

Wyoming recognizes DAO LLC structures, which can give a DAO legal personality and clearer member liability rules. This is useful for DAOs that need to sign contracts, hire vendors, or manage real-world obligations.

EU MiCA focuses mainly on crypto-asset issuers and service providers. DAOs can still be affected when governance controls token issuance, treasury operations, or services offered to users. Legal review is needed before public deployment.

## Future of Governance

Optimistic governance executes proposals by default unless challenged. It can reduce voter fatigue, but it needs strong challenge mechanisms and clear proposal scopes.

veToken models reward long-term lockers with stronger voting power. They align governance with long-term commitment, but can reduce liquidity and create vote markets.

Time-weighted voting gives more influence to holders who keep tokens longer. It can resist short-term governance capture, but it adds complexity and may disadvantage new participants.
