# 11 — Wallet + Robotics-as-a-Service (RChain)

This document defines the **blockchain kernel**: an identity/wallet and the on-chain coordination that
makes robotics-as-a-service possible. It builds on `00` (kernel) and `03` (signals/async). The chain is
RChain (REV); the marketplace is a coordination primitive.

## 1. Wallet

`scripts/rchain/rchain_wallet.gd` (`RChainWallet`) owns identity. The private key lives only in memory
and, when persisted, only encrypted.

- **Keystore** — PBKDF2 + AES-256-CBC (`AESContext.update`), password-protected, `user://wallet.ks`.
- **Key lifecycle** — auto-generate on first launch; `from_private_key(hex)` and `from_mnemonic(phrase)`
  (BIP-39, path `m/44'/60'/0'/0/0`) import an existing identity; `generate_mnemonic()` creates a fresh
  24-word phrase.
- **Identity** — derives the REV address from the secp256k1 public key (Rust gdext `RChainCrypto`).

**Contract:** the UI exposes no plaintext key by default; import of a private key or mnemonic is also
available in the **Settings** screen. The wallet is the second pinned surface (funds at risk).

## 2. Coordination → RaaS

`scripts/coordination/coordination_core.gd` (`CoordinationCore`) is the abstract contract;
`rchain_coordination.gd` is the RChain backend. The four verbs are the RaaS life-cycle:

| Verb | Meaning |
|---|---|
| `register <robot>` | register a robot on-chain (registry + capability) |
| `publish <job>` | publish a job for hire |
| `claim <job> <robot>` | claim a job for a robot |
| `settle <robot> <fee>` | settle a **work-metered fee** |

**Contract:** RaaS is the same primitive as the marketplace — listing a design is issuing a capability
+ registering the robot; purchasing it transfers the capability. Work is metered and settled on-chain.

## 3. Backing SDK

`scripts/rchain/` — `rchain_service.gd` (autoload `RChainService`, also the `TaskRunner`),
`rnode_client.gd` (RNode HTTP + DeployData signing), `rholang_sdk.gd` (term builders),
`signal_bridge.gd` (rholang channel → signal). Crypto is the Rust GDExtension in `addons/rchain/gdext`
(`RChainCrypto`), built with `bash addons/rchain/build.sh`.

**Contract:** all on-chain work runs through `RChainService.run_async` (the `TaskRunner`); results are
marshalled to the main thread and emitted as signals.

## 4. Conformance checklist

- The wallet panel + Settings both import a key/mnemonic and show the REV address.
- `register`/`publish`/`claim`/`settle` are contributed commands (reachable from the terminal).
- `scripts/test_rchain.gd` passes offline crypto (node e2e skips without a running node).

## See also

- `docs/rchain/` (design, protocol, wallet-spec, coordination-model), `docs/blockchain/marketplace.md`,
  `scripts/rchain/`, `scripts/coordination/`, `addons/rchain/`.
