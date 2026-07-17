# predix-uma-bond-token

Production-grade **PrediX UMA bond / staking-related ERC20** module. Implements role-based minting, immutable supply cap, rolling mint rate limits, mint-only pause, and EIP-2612 permits — aligned with Polymarket-style engineering: minimal privilege, auditable events, operable runbooks.

> This repository is the **bond-token module**. Whether it is wired directly as UMA protocol collateral is determined by deployment configuration and PrediX governance — see [UMA bond deployment checklist](#uma-bond-deployment-checklist) below.

## Relationship to PrediX CTF (not the same module)

| | **This repo (bond)** | **CTF stack** (`predix-ctf-contracts`) |
|--|----------------------|----------------------------------------|
| Token standard | ERC20 (+ EIP-2612 permit) | ERC-1155 Conditional Tokens |
| Role | UMA bond / staking-related supply | Yes/No **outcome** positions (split / merge / redeem) |
| Typical collateral for markets | Not required to be this token | USDC (mainnet) / Mock ERC20 (tests, Amoy) |

**Do not** describe this bond ERC20 as Gnosis CTF or as Polymarket-style outcome shares.  
CTF architecture: see sibling repo `predix-ctf-contracts` → `docs/architecture.md`.  
Oracle lifecycle ↔ CTF: `predix-oracle-ops` → `docs/oracle-ctf-mapping.md`.

Core Solidity in this repository stays unchanged for the CTF改造; only documentation clarifies the boundary.

## Features

- **ERC20 + ERC20Permit (EIP-2612)**
- **AccessControl** — `DEFAULT_ADMIN`, `MINTER`, `PAUSER`, `RISK` (no `onlyOwner` mint)
- **Immutable `maxSupply`**
- **Rolling-window mint rate limit**
- **Pausable mint only** — transfers and permits stay live while paused
- **Foundry** toolchain — build, test, deploy, CI

## Project layout

```
src/PredixUmaBondToken.sol   # Core token
script/Deploy.s.sol          # Env-driven deployment
test/                        # Unit, fuzz, invariant, deploy tests
docs/                        # role-model, mint-policy, runbook
```

## Role model

See [docs/role-model.md](docs/role-model.md).

| Role | Capability |
|------|------------|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke roles; adjust mint policy |
| `MINTER_ROLE` | `mint` |
| `PAUSER_ROLE` | `pause` / `unpause` (mint only) |
| `RISK_ROLE` | `setMintLimitPerWindow`, `setMintWindowSizeSeconds` |

## Mint policy

See [docs/mint-policy.md](docs/mint-policy.md).

- **Cap:** `totalSupply + amount <= maxSupply` (immutable)
- **Rate limit:** rolling window; default env example = 24h / 1M tokens
- **Pause:** blocks `mint` only; `transfer` / `permit` unaffected

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- `lib/` dependencies (included via tarball install or `forge install`)

## Local development

```bash
cd predix-uma-bond-token

# Format
forge fmt

# Build
forge build

# Test
forge test -vvv

# Coverage (target >= 85% line coverage on src/)
forge coverage --report summary
```

## Deployment

### 1. Configure environment

```bash
cp .env.example .env
# Edit addresses — use multisigs on mainnet
```

### 2. Local Anvil

```bash
anvil &
source .env

forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vvvv
```

### 3. Testnet / Mainnet

```bash
source .env

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

The script asserts name, symbol, `maxSupply`, roles, and mint window parameters, then logs a deployment summary.

### Useful `cast` commands

```bash
export TOKEN=0x...

# Supply
cast call $TOKEN "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN "maxSupply()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN "remainingMaxSupply()(uint256)" --rpc-url $RPC_URL

# Rate limit
cast call $TOKEN "remainingMintInWindow()(uint256)" --rpc-url $RPC_URL

# Pause state
cast call $TOKEN "paused()(bool)" --rpc-url $RPC_URL

# Roles
cast call $TOKEN "hasRole(bytes32,address)(bool)" $(cast keccak "MINTER_ROLE") $MINTER --rpc-url $RPC_URL
```

## Security

- No upgrade proxy in v1 — reduces attack surface; migrations are explicit deployments.
- Zero-address checks on privileged setup and mint recipients.
- Custom errors for cap and rate-limit failures.
- Emergency procedures: [docs/runbook.md](docs/runbook.md)

### Emergency flow (summary)

1. PAUSER calls `pause()` → mint stops, transfers continue.
2. ADMIN revokes compromised roles.
3. Investigate `BondMinted` and `RoleGranted` events.
4. Unpause only after sign-off.

## UMA bond deployment checklist

Before using this token as (or alongside) UMA collateral:

- [ ] Confirm UMA network (mainnet / testnet) and bond token requirements with UMA docs
- [ ] `maxSupply` aligned with economic model and insurance fund sizing
- [ ] Rate limits aligned with expected bond deposit velocity
- [ ] All roles on multisigs; deployer keys do not retain roles
- [ ] Legal/compliance sign-off on token classification
- [ ] Monitor: `BondMinted`, `BondPaused`, `RoleGranted`
- [ ] Incident runbook distributed to PAUSER holders
- [ ] Optional: third-party audit before mainnet
- [ ] Register token metadata (symbol, decimals=18) with frontends and explorers

## CI

GitHub Actions runs `forge fmt --check`, `forge build`, and `forge test -vvv` on push/PR.

## License

MIT
