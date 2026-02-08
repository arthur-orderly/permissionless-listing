# Permissionless Listing — Smart Contracts

Foundry project for Orderly Network's permissionless listing system on Arbitrum One.

## Quick Start

```bash
forge build    # Compile
forge test     # Run 20 tests
forge test -v  # Verbose output
```

## Contracts

| Contract | Description |
|----------|-------------|
| `ListingRegistry` | Core registry — create, activate, deactivate, update listings |
| `ListingStake` | USDC staking with lock periods and slashing |
| `FeeVault` | Fee collection and distribution (protocol/lister/insurance splits) |
| `SlashingOracle` | 3/5 multisig governance with 48h timelock for slashing |
| `ListingLib` | Pure library for parameter validation and derived calculations |

## Deploy

```bash
source .env  # PRIVATE_KEY, DEPLOYER, INSURANCE_FUND, PROTOCOL_TREASURY, ARBITRUM_RPC_URL
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast --verify
```
