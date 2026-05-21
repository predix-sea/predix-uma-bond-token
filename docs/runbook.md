# Emergency Runbook — PredixUmaBondToken

## Incident severity

| Level | Trigger | Response time |
|-------|---------|---------------|
| P0 | Suspected unauthorized mint, key compromise, or abnormal supply growth | < 15 min |
| P1 | Rate-limit misconfiguration, paused mint stuck, indexer desync | < 1 h |
| P2 | Parameter tuning, role rotation, documentation | Planned |

## P0 — Suspected unauthorized mint or minter compromise

1. **Pause minting** (PAUSER_ROLE):
   ```bash
   cast send $TOKEN "pause()" --from $PAUSER --rpc-url $RPC_URL
   ```
2. Confirm `BondPaused` event on-chain; verify `mint` reverts.
3. Notify: security lead, protocol ops, multisig signers.
4. **Revoke** compromised `MINTER_ROLE`:
   ```bash
   cast send $TOKEN "revokeRole(bytes32,address)" $(cast keccak "MINTER_ROLE") $COMPROMISED --from $ADMIN
   ```
5. Forensics: trace `BondMinted` events, compare `totalSupply` vs expected.
6. Governance decision: deploy new token vs. resume after key rotation.
7. Post-incident: rotate PAUSER/RISK if needed; document root cause.

## P0 — Abnormal supply (within cap but unexpected)

1. Pause mint (above).
2. Query `totalSupply`, `mintedInWindow`, recent `BondMinted`.
3. If minter contract bug: pause upstream orchestrator; do not unpause until fix verified on testnet.

## P1 — Mint paused too long

1. Verify no active exploit.
2. Unpause:
   ```bash
   cast send $TOKEN "unpause()" --from $PAUSER --rpc-url $RPC_URL
   ```
3. Confirm `BondUnpaused` event.

## P1 — Rate limit blocking legitimate ops

1. Risk/admin may raise limit (requires multisig):
   ```bash
   cast send $TOKEN "setMintLimitPerWindow(uint256)" $NEW_LIMIT --from $RISK
   ```
2. Or shorten window (use with care):
   ```bash
   cast send $TOKEN "setMintWindowSizeSeconds(uint256)" $NEW_SECONDS --from $RISK
   ```
3. Monitor `BondMintLimitUpdated` / `BondMintWindowUpdated`.

## P1 — Approaching `maxSupply`

1. Monitor `remainingMaxSupply()`.
2. Halt minter automation before cap; coordinate governance for new deployment if more supply needed.

## Communication template

```
[PrediX Bond Token] Status: PAUSED / ACTIVE
Chain: <chainId>
Token: <address>
Action: <pause|unpause|revoke|param change>
Tx: <hash>
Impact: mint halted; transfers ACTIVE
Next update: <time>
```

## Post-deployment verification checklist

- [ ] `maxSupply` matches spec
- [ ] Role holders are multisigs (not EOAs) on mainnet
- [ ] `MINTER_ROLE` not held by deployer
- [ ] `pause` tested on testnet
- [ ] Indexer subscribed to `BondMinted`, pause, and `RoleGranted` events
- [ ] Runbook signers have PAUSER keys in incident wallet

## Contacts (fill before mainnet)

| Role | Contact |
|------|---------|
| PAUSER multisig | _TBD_ |
| ADMIN multisig | _TBD_ |
| Security | _TBD_ |
