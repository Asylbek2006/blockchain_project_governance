# Token Distribution

Total supply: 100,000,000 GOV

```mermaid
pie title GOV Initial Distribution
    "Team vesting: 40%" : 40
    "Treasury: 30%" : 30
    "Community airdrop: 20%" : 20
    "Liquidity: 10%" : 10
```

| Allocation | Amount | Destination |
| --- | ---: | --- |
| Team vesting | 40,000,000 GOV | `TokenVesting` |
| Treasury | 30,000,000 GOV | `Treasury` |
| Community airdrop | 20,000,000 GOV | Community wallet |
| Liquidity | 10,000,000 GOV | Liquidity wallet |

The team allocation is minted directly to `TokenVesting` during deployment and releases linearly to the team wallet over 365 days.
