# Orderly Permissionless Listing System
## Technical Proposal & Reference Implementation

**Prepared by:** Arthur DEX (arthur-orderly)
**Date:** February 8, 2026
**Version:** 2.0

---

### Executive Summary

We've built a complete reference implementation for Orderly's permissionless listing system — production-ready smart contracts, a polished frontend with interactive workflows, and comprehensive test coverage. This document covers the major v2.0 updates: unified capital model, graduated enforcement, revenue calculator, and full account management.

### Problem Statement

- Orderly currently requires a manual listing process for new perpetual futures pairs
- This limits the speed of new market launches and creates a bottleneck
- Permissionless listing enables any qualified entity to list new perp markets, dramatically expanding Orderly's market coverage
- **Orderly as "Shopify for perp listings"** — lower barrier ($50-100K vs HyperLiquid's $14M HIP-3 stake), more guardrails

### Solution Architecture

#### Smart Contracts (Arbitrum, Solidity 0.8.24, Foundry)

1. **ListingRegistry** — UUPS upgradeable core registry. Manages listing lifecycle (Pending → Active → Suspended → Deactivated). Role-based access control (LISTER, ADMIN, ORACLE).

2. **ListingStake** — Single deposit mechanism requiring $50,000 USDC minimum with 6-month lock. Covers bond + insurance + liquidation in one deposit. Three slashing tiers: 100% (rug pull), 50% (abandonment), variable 0-50% (manipulation).

3. **FeeVault** — Fee collection and distribution with configurable splits (default: 50% protocol, 30% lister, 20% insurance fund).

4. **SlashingOracle** — Decentralized governance for slashing decisions. 3-of-5 multisig with mandatory 48-hour timelock.

5. **ListingLib** — Pure library implementing parameter derivation: leverage caps by market cap tier (<$30M→5x, $30-100M→10x, >$100M→20x), IMR/MMR calculation, funding rate bounds.

#### Frontend Application

**5-Step Listing Wizard:**
1. **Token Selection** — CoinGecko-powered live search with real market cap data, auto-calculates leverage tier
2. **Risk Parameters** — IMR/MMR, funding rate, position limits — auto-derived from market cap
3. **Fees & Revenue** — Interactive revenue calculator: volume selector ($50K-$10M/day), real-time daily/monthly/annual revenue, ROI on deposit, payback period
4. **Market Maker Setup** — "Run Your Own" vs "Partner with MM Firm", Arthur SDK code snippets, capital requirements ($10K min / $50K recommended / 20-50% APR target)
5. **Deposit & Confirm** — Single listing deposit with yield (~18% APR), review all parameters

**Dashboard & Monitoring:**
- Unified "My Listings" page with risk gauges (Deposit Coverage, Liquidation Runway, Orderbook Quality)
- Health column with enforcement ladder mapping (L1-L5 prefixes)
- Real-time alerts for threshold proximity
- Problem rows highlighted in orange/red

**Account Management:**
- Collapsible Listing Deposits section (per-listing breakdown, manage deposit modal with deposit/withdraw tabs)
- Fee Revenue tracking with withdraw modal
- Collapsible MM Accounts section
- Toast notifications for all actions

**Graduated Enforcement Ladder (5 levels):**
1. 📢 **L1 — Alert:** Warning notification to lister
2. ⏳ **L2 — Grace Period:** 24-hour window to fix issues
3. 📉 **L3 — Reduce Risk:** Automatic leverage reduction
4. ⛔ **L4 — Pause Trading:** Close-only mode
5. 🗳️ **L5 — Governance:** Slash vote + potential delist

*Philosophy: Depth/liquidity issues are operational (MM crashed, ran out of capital), not malicious. Automated ladder handles operations; slashing reserved for malicious behavior via governance.*

### Key Design Decisions (v2.0)

- **Unified Deposit Model:** Merged Bond + Safety & Liquidation Fund into single "Listing Deposit" per listing — one deposit covers all purposes, earns yield, higher deposit = higher max OI. Inspired by HyperLiquid HIP-3 (one stake, multiple purposes). Total capital: ~$100K ($50K deposit + $50K MM capital)
- **Graduated Enforcement over Immediate Slashing:** Operational issues get automated escalation; slashing only for malicious actors
- **Revenue Calculator in Wizard:** Listers see ROI before committing capital — reduces friction, increases confidence
- **MM Onboarding Built-In:** Arthur SDK integration guide directly in the wizard reduces time-to-market
- **UUPS Proxy Pattern:** Allows contract upgrades as system evolves
- **Conservative Defaults:** $50K minimum deposit, 6-month lock, 48hr timelock — erring on security

### Parameter Derivation

Key formulas implemented in `ListingLib.sol`:

- **Leverage:** `min(tier_max, floor(1/base_imr))`
- **IMR tiers:** <$30M mcap → 20% (5x), $30-100M → 10% (10x), >$100M → 5% (20x)
- **MMR:** `IMR / 2` (with 6% exception for certain tiers)
- **Fee bounds:** Taker markup 0-5bps, Maker markup 0-2bps
- ~20 parameters auto-derived from just 5 inputs (token address, target leverage, fee preferences, market cap, desired spread)

### Security

- Checks-Effects-Interactions pattern throughout
- Reentrancy guards on all external calls
- Role-based access with granular permissions
- 48-hour timelock on all slashing actions
- USDC approval pattern (approve → transferFrom)
- **20 unit tests** covering edge cases, access control, math precision, all passing

### Integration with Orderly Backend

1. Lister stakes on-chain → `ListingCreated` event emitted
2. Orderly backend listens for events via indexer
3. Backend validates parameters and enables the trading pair
4. Ongoing: backend monitors MM activity, feeds enforcement ladder
5. Fee markups applied at matching engine level, collected on-chain via FeeVault

### HyperLiquid HIP-3 Comparison

| | Orderly (This Proposal) | HyperLiquid HIP-3 |
|---|---|---|
| **Minimum Stake** | $50,000 USDC | ~$14M (2M HYPE) |
| **Lock Period** | 6 months | Indefinite |
| **Enforcement** | 5-level graduated ladder | Immediate delist |
| **MM Requirement** | Guided (SDK + partners) | Required, unguided |
| **Revenue Share** | 30% to lister | 0% to lister |
| **Barrier to Entry** | Accessible | Whale-only |

### Deliverables

1. ✅ Smart contracts (Foundry, 5 contracts, Solidity 0.8.24)
2. ✅ Full test suite (20 tests, all passing)
3. ✅ Frontend application with interactive workflows (deployed to Vercel)
4. ✅ Deployment scripts for Arbitrum
5. ✅ Documentation & this proposal

### Open Questions

1. **Market Maker Requirement** — Spec marks as TBD. Our implementation supports optional MM account with Arthur SDK integration guide. Recommend: minimum quote obligation.
2. **Oracle Data Source** — Market cap tier needs reliable oracle (Chainlink, Pyth, or Orderly price feeds). Currently admin-set.
3. **Cross-Chain Support** — Current implementation Arbitrum-only. Multi-chain needs cross-chain messaging.
4. **Deposit Yield Source** — Current ~18% APR assumes protocol revenue allocation. Needs treasury/governance approval.

### Proposed Next Steps

1. **Review:** Orderly engineering team reviews contracts and architecture
2. **Audit:** Professional smart contract audit (Trail of Bits or OpenZeppelin recommended)
3. **Testnet Deploy:** Arbitrum Sepolia for integration testing
4. **Backend Integration:** Connect on-chain events to Orderly matching engine
5. **Mainnet Launch:** Target March 2026 per roadmap

### Links

- **GitHub:** [github.com/arthur-orderly/permissionless-listing](https://github.com/arthur-orderly/permissionless-listing)
- **Frontend Demo:** [orderly-permissionless-listing-arthurs-projects-80466810.vercel.app](https://orderly-permissionless-listing-arthurs-projects-80466810.vercel.app)
- **Arthur DEX:** [arthurdex.com](https://arthurdex.com)
- **Arthur SDK:** [pypi.org/project/arthur-sdk](https://pypi.org/project/arthur-sdk/)
