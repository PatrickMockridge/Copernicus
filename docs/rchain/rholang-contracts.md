# RChain — Rholang Contracts Specification

Spec for the `.rho` contracts in `addons/rchain/rho/`. Public names are quoted
names under the `copernicus:` namespace. Private channels (capabilities, inboxes)
are unforgeable `new` names.

Convention: a contract is a `contract` listening on a public name; each message
is a tuple whose first element is a method tag `@"method"`; query methods take a
final `*ret` channel and respond on it.

Contracts are declared directly on the public name (`contract @"copernicus:…"(…)`),
not bound with `new x(@"…")` — that `new` form expects a URI (backtick), not a
quoted name. Complex values (records, specs, results) are stored as **hex-encoded
JSON strings** because rholang string literals have no escape sequences.

## `registry.rho`

- **Public name:** `@"copernicus:registry"`
- **State:** `Map name -> record` (held in a recursive loop), where `record` is
  `{ "asset_tx_id", "metadata", "creator", "registered_at" }`.
- **Messages:**
  - `(@"register", name, record)` — upsert `record` under `name`; announce on
    `@"copernicus:registry"` so `robot_registered` fires.
  - `(@"query", name, *ret)` → `ret!(record)` (or `ret!(Nil)` if absent).
  - `(@"list", *ret)` → `ret!([records…])`.
- **Invariant:** at most one record per `name`; `register` overwrites.

## `ownership.rho` (capabilities + ledger)

- **Public name:** `@"copernicus:ownership"`
- **State:** `Map robot -> (cap_unforgeable, holder_addr, revoked_bool)`.
- **Messages:**
  - `(@"issue", robot, *cap)` — `new cap in { … }`, bind `robot -> (cap, holder=deployerId,
    revoked=false)`, respond `cap!(…)` so the creator receives the capability.
  - `(@"transfer", robot, to_addr, *ret)` — if not revoked, send the capability
    token to `to_addr`'s inbox and update holder; announce on
    `@"copernicus:ownership"`; `ret!(true)`.
  - `(@"holder", robot, *ret)` → `ret!(holder_addr)`.
  - `(@"revoke", robot)` — set `revoked=true`; announce.
- **Invariant:** a revoked robot cannot be transferred or claimed; only the
  current holder can transfer.

## `jobs.rho`

- **Public name:** `@"copernicus:jobs"`
- **State:** `Map job_id -> { spec, reward, state, claimant }`, `state ∈
  {published, claimed, completed, cancelled}`.
- **Messages:**
  - `(@"publish", job_id, spec, *ret)` — add `{spec, reward, state: published}`;
    announce on `@"copernicus:jobs"`.
  - `(@"claim", job_id, robot, *cap, *ret)` — **join** on the robot's capability
    (from `ownership`): only succeeds if the claimant holds a valid capability;
    set `state: claimed, claimant: robot`; `ret!(true)`.
  - `(@"complete", job_id, result, *ret)` — set `state: completed`; announce
    `result` on `@"copernicus:job-results"`.
  - `(@"cancel", job_id)` — set `state: cancelled` (only if published).
- **Invariant:** `claim` requires a valid, non-revoked capability — enforced by
  the rholang join, not by the app.

## `channels.rho` (pub/sub)

- **Public name:** `@"copernicus:channels"`
- **Messages:**
  - `(@"open", name)` — create a persistent channel contract for
    `@"copernicus:channels:<name>"`.
  - `(@"send", name, data)` — `@"copernicus:channels:<name>"!(data)` (persistent
    send so late subscribers can read).
  - `(@"subscribe", name, *ret)` — register `ret` to receive future messages.
- **Invariant:** `send` is a persistent send (`!!`), so the last value remains
  readable by `data_at_name`.

## `marketplace.rho` (thin sale layer)

- **Public name:** `@"copernicus:marketplace"`
- **Messages:**
  - `(@"list", robot, price)` — record an asking price for a robot (ledger holds
    the capability; price is an offer).
  - `(@"buy", robot, buyer, *ret)` — escrow `price` REV from `buyer` via
    `revVault.transfer`, then `ownership!("transfer", robot, buyer, *ret)`; on
    success settle escrow to the seller.
- **Invariant:** a `buy` atomically moves REV and the capability, or neither
  (rholang join on both the vault transfer result and the ownership transfer).

## `inbox.rho` (per-entity inbox)

- Each address has a named inbox `@"copernicus:inbox:<addr>"` used by
  `ownership.transfer` to deliver capability tokens. Persistent receive that
  buffers incoming capability names until the recipient consumes them.

## Notes for implementation

- Mirror the capability/join idiom in
  `~/RNodeRust/qucalc/examples/dining_philosophers.rho` (forks-as-tokens).
- Registry/jobs use a recursive `for` loop holding state in a tuple-space cell,
  patterned after `~/RNodeRust/qucalc/rholang/Directory.rho`.
- Announce-on-public-name is how `SignalBridge` turns on-chain activity into
  Godot signals without polling-specific private channels.
