# Role Model — PredixUmaBondToken

## Overview

`PredixUmaBondToken` uses OpenZeppelin `AccessControl` with **no single-owner mint pattern**. Governance is split across four operational roles plus `DEFAULT_ADMIN_ROLE`.

## Roles

| Role | Identifier | Purpose |
|------|------------|---------|
| `DEFAULT_ADMIN_ROLE` | `0x00` (OZ default) | Grant/revoke roles; may adjust mint policy with `RISK_ROLE`; transfer to multisig in production |
| `MINTER_ROLE` | `keccak256("MINTER_ROLE")` | Execute `mint(to, amount)` within cap and rate limits |
| `PAUSER_ROLE` | `keccak256("PAUSER_ROLE")` | `pause()` / `unpause()` — **mint only** |
| `RISK_ROLE` | `keccak256("RISK_ROLE")` | `setMintLimitPerWindow`, `setMintWindowSizeSeconds` |

## Permission Matrix

| Action | ADMIN | MINTER | PAUSER | RISK | Public |
|--------|:-----:|:------:|:------:|:----:|:------:|
| `mint` | — | ✓ | — | — | — |
| `pause` / `unpause` | — | — | ✓ | — | — |
| `setMintLimitPerWindow` | ✓ | — | — | ✓ | — |
| `setMintWindowSizeSeconds` | ✓ | — | — | ✓ | — |
| `grantRole` / `revokeRole` | ✓ | — | — | — | — |
| `transfer` / `approve` / `permit` | — | — | — | — | ✓ (holders) |

## OpenZeppelin audit events

`AccessControl` emits standard events (document for indexers):

- `RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)`
- `RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)`
- `RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)`

## Production recommendations

1. Assign `DEFAULT_ADMIN_ROLE` to a **multisig** (e.g. Gnosis Safe) with ≥3-of-5.
2. Separate `MINTER_ROLE` to an operational hot wallet or minter contract with its own limits.
3. `PAUSER_ROLE` on a 24/7 incident multisig or hardware-backed EOA.
4. `RISK_ROLE` on risk committee multisig; changes should follow internal change management.
5. After deployment, **renounce** deployer roles if the deployer was temporarily granted any role.
6. Consider timelock on `DEFAULT_ADMIN_ROLE` admin functions for mainnet.

## Role rotation

```bash
# Grant new minter (as admin multisig)
cast send $TOKEN "grantRole(bytes32,address)" $(cast keccak "MINTER_ROLE") $NEW_MINTER --from $ADMIN

# Revoke old minter
cast send $TOKEN "revokeRole(bytes32,address)" $(cast keccak "MINTER_ROLE") $OLD_MINTER --from $ADMIN
```
