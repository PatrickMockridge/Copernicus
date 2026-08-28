# RChain Coordination Layer — Design

## Intent

Copernicus is a robot design interface. Today its "blockchain" surface is an
**Arweave/AO marketplace**: robots are listed, bought and sold as digital assets,
and the coordination/trade intent is expressed as AO process messages.

This design moves the **coordination layer** off Arweave/AO and onto
**RChain/RNode**, so that RChain becomes a *universal robot coordination and
industrial metaverse layer*. The marketplace does not disappear — it becomes one
coordination primitive (a *capability transfer*) among several.

## Why Rholang

Rholang (the ρ-calculus dialect run by RNode) is a good fit for robot
coordination because its primitives map directly onto coordination needs:

| Rholang primitive | Coordination meaning |
|---|---|
| `name!(v)` / `name!!(v)` | send a message / persistent announcement |
| `for (p <- name) { … }` | receive (subscription) |
| `contract name(p) = { … }` | a persistent service / contract |
| `for (_ <- a; _ <- b) { … }` | atomic **join** — acquire two resources together |
| `new x in { … }` | unforgeable name → **capability** |
| `*x` vs `@x` | pass the *capability itself* vs match the *value* |

The **capability** model is the key insight: a robot's control authority is an
unforgeable channel. Ownership = holding the channel; transfer = sending the
channel to the next holder; a job can require possession of that channel before
it runs. This replaces "account balances own things" with "channels grant
authority", which composes under concurrency and is the property we build on.

## Arweave vs RChain — the split

| Concern | Where | Why |
|---|---|---|
| Asset **blobs** (meshes, URDF, textures, manifests) | Arweave (unchanged) | permanent, content-addressed, already implemented |
| Asset **metadata** / registry | RChain (rholang records) | mutable, queryable, coordinated |
| **Ownership / authority** | RChain capabilities | capability = unforgeable channel |
| **Trade / listing** | RChain `ownership` contract | a sale is a capability transfer + price escrow |
| **Jobs / tasks** | RChain `jobs` contract | capability-gated, atomic handoff |
| **Events / signals** | RChain named channels | map to Godot signals |

Concretely: `addons/hyperobject/sdk/{storage,manifest,ao}.gd` keep uploading asset
blobs to Arweave and return Arweave TX ids. Those TX ids are stored *inside*
rholang records. The AO process layer (`spawn_process`/`schedule_message` for
ownership) is **retired** in favour of RChain contracts.

## Architecture

```
GDScript
  CoordinationCore (abstract, extends CopernicusModule, category "coordination")
    ├─ RChainCoordination ──► RChainWallet ──► RChainCrypto (Rust GDExtension)
    │                        ├─ RNodeClient ──► HTTP :40403 (public) / :40405 (admin)
    │                        └─ RholangSDK ────► build rholang + RhoExpr JSON
    │                             └─ SignalBridge ──► poll channels ⇄ emit Godot signals
    └─ MockCoordination (in-memory, offline)

  MarketplaceCore (existing) ── RChainMarketplace (shim) ──► RChainCoordination
  Arweave/AO (existing, unchanged) ── asset blob persistence only
```

### Component responsibilities

- **RChainCrypto (GDExtension, Rust)** — secp256k1 keygen/sign/verify, keccak256,
  blake2b-256, base58, REV-address derivation, DeployData protobuf serialization.
  Pure functions, no node I/O. See `wallet-spec.md`.
- **RChainWallet (GDScript)** — key lifecycle (generate/import/export, mnemonic,
  keystore V3), REV address, deploy signing (via `RChainCrypto`), balance/transfer
  (via `revVault` rholang). See `wallet-spec.md`.
- **RNodeClient (GDScript)** — typed HTTP client for the RNode public/admin API.
  See `protocol.md`.
- **RholangSDK (GDScript)** — builds rholang terms and `RhoExpr` JSON, deploys and
  explores, and encodes/decodes public names. See `sdk-spec.md`.
- **SignalBridge (GDScript)** — the `signal ⇄ rholang channel` adapter. Emitting a
  Godot signal deploys a channel send; a poll loop detects on-chain data and emits
  the corresponding Godot signal. See `coordination-model.md`.
- **CoordinationCore + backends** — the swap point for the rest of the app.
  `RChainCoordination` is the real backend; `MockCoordination` is the offline
  stand-in. See `coordination-model.md`.

## Principles

1. **Arweave stays put.** No changes to `Storage`, `Manifest`, or `AOSDK`
   upload/download. Only the coordination actions move.
2. **One seam.** The rest of the app talks to `CoordinationCore` signals + methods
   only (mirroring how it already talks to `MarketplaceCore`).
3. **Capabilities, not accounts.** Authority is a channel; ownership is a hold;
   transfer is a send. Sales are a thin wrapper.
4. **Poll, don't push.** RChain has no pub/sub. `SignalBridge` polls
   `data-at-name` on a timer (default 1 s) and diffs.
5. **Deterministic names.** Public coordination names are quoted names under a
   `copernicus:` namespace; private/robot channels are unforgeable (`new`).
