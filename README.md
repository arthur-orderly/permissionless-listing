# Orderly Network — Permissionless Listing System

> Smart contracts + frontend for permissionless perpetual futures listing on Orderly Network.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Frontend (SPA)                          │
│  Wallet Connection → Listing Wizard → Dashboard → Admin      │
└───────────────┬─────────────────────────────────────────────┘
                │ (ethers.js / Reown AppKit)
┌───────────────▼─────────────────────────────────────────────┐
│                   Arbitrum One (L2)                           │
│                                                              │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ ListingRegistry │  │ ListingStake │  │   FeeVault    │  │
│  │ (UUPS Proxy)    │  │ (UUPS Proxy) │  │ (UUPS Proxy)  │  │
│  │                 │  │              │  │               │  │
│  │ • createListing │  │ • stake()    │  │ • collectFees │  │
│  │ • activate      │◄─│ • unstake()  │  │ • distribute  │  │
│  │ • deactivate    │  │ • slash()    │  │ • fee splits  │  │
│  │ • updateParams  │  │              │  │               │  │
│  └─────────────────┘  └──────▲───────┘  └───────────────┘  │
│                              │                               │
│                    ┌─────────┴──────────┐                    │
│                    │  SlashingOracle    │                    │
│                    │  (UUPS Proxy)      │                    │
│                    │                    │                    │
│                    │  • proposeSlash    │                    │
│                    │  • voteSlash       │                    │
│                    │  • executeSlash    │                    │
│                    │  (3/5 multisig)    │                    │
│                    │  (48h timelock)    │                    │
│                    └────────────────────┘                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  ListingLib (Library)                                  │  │
│  │  • Leverage caps by market cap tier                    │  │
│  │  • IMR/MMR derivation                                  │  │
│  │  • Fee markup validation (0-5/0-2 bps)                │  │
│  │  • Liquidation fee rates                               │  │
│  │  • IF Rate / Liq Rate calculation                      │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Orderly Backend   │
                    │  (Off-chain)       │
                    │  • Price feeds     │
                    │  • Order matching  │
                    │  • Funding rates   │
                    │  • Monitoring      │
                    └────────────────────┘
```

## Contract Addresses (Arbitrum One)

| Contract | Address | Notes |
|----------|---------|-------|
| ListingRegistry (Proxy) | `TBD` | UUPS upgradeable |
| ListingStake (Proxy) | `TBD` | USDC staking |
| FeeVault (Proxy) | `TBD` | Fee collection |
| SlashingOracle (Proxy) | `TBD` | Governance |
| USDC | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` | Arbitrum native USDC |

## Key Parameters

### Leverage Caps (from spec)
| Market Cap | Max Leverage | IMR | MMR |
|-----------|-------------|-----|-----|
| < $30M | 5x | 20% | 10% |
| $30M - $100M | 10x | 10% | 6%* |
| > $100M | 20x | 5% | 2.5% |

*MMR exception: 6% when mcap < $100M and IMR = 10%

### Fee Markups
- Taker: 0-5 bps
- Maker: 0-2 bps

### Staking
- Minimum: 50,000 USDC
- Lock period: 6 months
- Slashing: 0-100% based on violation severity

### Slashing Conditions
| Violation | Slash % |
|-----------|---------|
| Rug pull / platform losses | 100% |
| Listing abandonment (no MM 7+ days) | 50% |
| Market manipulation | 0-50% (case-by-case) |

## How to Build

### Smart Contracts

```bash
cd contracts
forge build
forge test
```

### Deploy to Arbitrum

```bash
export PRIVATE_KEY=...
export DEPLOYER=...
export INSURANCE_FUND=...
export PROTOCOL_TREASURY=...
export ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc

cd contracts
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast --verify
```

### Frontend

Just open `frontend/index.html` in a browser, or serve it:

```bash
cd frontend
npx serve .
```

## Integration with Orderly Backend

The smart contracts handle **staking, slashing, and fee distribution** on-chain. The actual trading infrastructure (order matching, price feeds, funding rates, liquidations) remains on Orderly's off-chain backend.

### Integration flow:
1. **Listing creation**: Lister stakes on-chain → backend picks up `ListingCreated` event → configures trading pair
2. **Parameter updates**: Lister calls `updateParams()` → backend syncs new parameters
3. **Fee collection**: Backend calculates fees off-chain → calls `FeeVault.collectFees()` periodically
4. **Slashing**: Risk team proposes slash via `SlashingOracle` → 3/5 multisig vote → 48h timelock → execute
5. **Deactivation**: Admin or lister calls `deactivateListing()` → backend removes trading pair

## Security Considerations

- **UUPS Upgradeable**: All contracts use UUPS proxy pattern with OpenZeppelin v5. Only DEFAULT_ADMIN_ROLE can upgrade.
- **Role-based access**: LISTER_ROLE, ADMIN_ROLE, ORACLE_ROLE, VOTER_ROLE with proper separation.
- **Reentrancy guards**: All state-changing functions with token transfers use ReentrancyGuard.
- **CEI pattern**: Checks-Effects-Interactions followed throughout.
- **Timelock**: 48-hour delay on slash execution prevents hasty/malicious slashing.
- **Multisig**: 3-of-5 quorum required for slashing, preventing unilateral action.
- **SafeERC20**: All token transfers use OpenZeppelin's SafeERC20.

## Gas Estimates

| Operation | Estimated Gas |
|-----------|--------------|
| createListing | ~350,000 |
| stake | ~120,000 |
| activateListing | ~50,000 |
| proposeSlash | ~150,000 |
| voteSlash | ~50,000 |
| executeSlash | ~200,000 |
| distributeFees | ~150,000 |

## Test Coverage

20 tests covering:
- Listing lifecycle (create, activate, deactivate)
- Leverage cap validation by market cap tier
- MMR exception for mid-cap tokens
- Fee markup bounds checking
- Stake/unstake with lock periods
- 100% and 50% slashing scenarios
- Full slashing governance flow (propose → vote → timelock → execute)
- Quorum requirements
- Double-vote prevention
- Fee collection and distribution math
- Access control enforcement

```bash
forge test -v
# 20 tests passed, 0 failed
```

## File Structure

```
permissionless-listing/
├── README.md                          ← This file
├── contracts/                         ← Foundry project
│   ├── foundry.toml
│   ├── src/
│   │   ├── ListingRegistry.sol        ← Core registry (UUPS)
│   │   ├── ListingStake.sol           ← Staking & slashing (UUPS)
│   │   ├── FeeVault.sol               ← Fee distribution (UUPS)
│   │   ├── SlashingOracle.sol         ← Governance (UUPS)
│   │   ├── interfaces/
│   │   │   ├── IListingRegistry.sol
│   │   │   └── IListingStake.sol
│   │   └── libraries/
│   │       └── ListingLib.sol         ← Validation & derived params
│   ├── test/
│   │   ├── ListingRegistry.t.sol      ← 8 tests
│   │   ├── ListingStake.t.sol         ← 4 tests
│   │   ├── FeeVault.t.sol             ← 4 tests
│   │   └── SlashingOracle.t.sol       ← 4 tests
│   └── script/
│       └── Deploy.s.sol               ← Arbitrum deployment
├── frontend/
│   └── index.html                     ← Full SPA (React-free, CDN-based)
└── [spec docs]
    ├── Orderly_Perps_Listing_Parameters_Rules.md
    ├── Permissionless_Listing_Configuration_UX_Flow.md
    ├── Permissionless_Listing_Frontend_Requirements.md
    └── Slashing_System.md
```
