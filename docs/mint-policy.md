# Mint Policy — Supply Cap & Rate Limits

## Hard cap (`maxSupply`)

- Set **once** in the constructor as an **immutable** value.
- Every `mint` checks: `totalSupply() + amount <= maxSupply`.
- On violation: `ExceedsMaxSupply(requested, available)`.

There is **no** admin function to raise `maxSupply`. A policy change requires deploying a new token and migrating balances off-chain/on-chain per PrediX governance.

## Rolling window rate limit

State:

| Field | Meaning |
|-------|---------|
| `mintWindowStart` | Start timestamp of active window |
| `mintedInWindow` | Cumulative minted in active window |
| `mintLimitPerWindow` | Max mint per window (governance-adjustable) |
| `mintWindowSizeSeconds` | Window length in seconds (governance-adjustable) |

### Algorithm

1. On each `mint`, if `block.timestamp >= mintWindowStart + mintWindowSizeSeconds`, reset:
   - `mintWindowStart = block.timestamp`
   - `mintedInWindow = 0`
2. Require `amount <= mintLimitPerWindow - mintedInWindow`.
3. On success: `mintedInWindow += amount`.

On violation: `MintRateLimitExceeded(requested, availableInWindow)`.

### Example (24h window)

```
mintLimitPerWindow = 1_000_000 tokens
mintWindowSizeSeconds = 86_400

Day 1: mint 1M → OK
Day 1: mint 1 → revert (rate limit)
Day 2 (after 24h): window rolls → mint 1M → OK
```

## Pause interaction

- `pause()` blocks **only** `mint` (via `whenNotPaused` on `mint`).
- **Transfers, approvals, and EIP-2612 permits remain enabled** so secondary liquidity and user exits are not frozen.
- Rationale: incident response targets **supply inflation**, not user-to-user movement of already-issued tokens.

## Custom events

| Event | When |
|-------|------|
| `BondMinted(operator, to, amount)` | Successful mint |
| `BondMintLimitUpdated(old, new)` | `setMintLimitPerWindow` |
| `BondMintWindowUpdated(old, new)` | `setMintWindowSizeSeconds` |
| `BondPaused(operator)` | `pause()` |
| `BondUnpaused(operator)` | `unpause()` |

## Views

- `remainingMintInWindow()` — capacity left (assumes no roll until next mint).
- `remainingMaxSupply()` — `maxSupply - totalSupply()`.
