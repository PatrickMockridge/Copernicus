# RChain — RNode Protocol (HTTP + signing)

This is the exact wire contract `RNodeClient` and `RChainCrypto` implement,
distilled from `~/RWallet/r-wallet` (proven against the Rust node) and
`~/RNodeRust` (the node itself).

## Endpoints

`base` = public HTTP API (default `http://localhost:40403`).
`adminBase` = admin HTTP API (default `http://localhost:40405`).

| function | method + path | request body | response |
|---|---|---|---|
| `get_status` | `GET /api/status` | — | `ApiStatus` |
| `explore_deploy` | `POST /api/explore-deploy` | raw JSON **string** of a rholang term | `RhoDataResponse { expr, block }` |
| `deploy` | `POST /api/deploy` | `DeployRequest` (signed) | JSON string `"Success!\nDeployId is: <hex>"` |
| `deploy_status` | `GET /api/v1/deploy-status/:id` | — | `DeployExecStatus` |
| `propose` | `POST /api/propose` (admin) | none | JSON string `"Success! Block <hash> …"` |
| `data_at_name` | `POST /api/data-at-name` | `{ name: RhoUnforg, depth }` | `DataAtNameResponse { exprs, length }` |
| `get_block` | `GET /api/block/:hash` | — | `BlockInfo { blockInfo, deploys }` |
| `faucet` | `POST /api/faucet` | `{ address }` | `FaucetResponse { deployId, amount, to }` |
| `get_capabilities` | `GET /api/v1/capabilities` | — | `NodeCapabilities` |
| `get_pooled_deploys` | `GET /api/v1/deploys` | — | `PooledDeploys { deploys }` |

The Rust node also serves `/api/v1/…` variants and
`POST /api/v1/data-at-name-by-block-hash` / `POST /api/v1/explore-deploy-by-block-hash`
(point-in-time queries with `{ name, blockHash, usePreStateHash }`). `RNodeClient`
uses the legacy `/api/…` paths above (as RWallet does); `data-at-name-by-block-hash`
is reserved for block-pinned reads in `SignalBridge`.

## Wire facts (do not deviate)

- Serde enums are **externally tagged**: `ExprInt(42)` → `{"ExprInt":42}`,
  `UnforgDeploy(x)` → `{"UnforgDeploy":"<hex>"}`. There is no `{data}` wrapper.
- `deploy` / `propose` return a **JSON-encoded string** (`Json<String>`), so parse
  the response body as a string, not an object. The deploy id is the trailing hex
  in `"…DeployId is: <hex>"`.
- The **deploy id is the signature** (`DeployId is: <signature-hex>`), not a separate
  hash. `get_status` fields are **camelCase** (`shardId`, `minPhloPrice`,
  `latestBlockNumber`).
- `DeployExecStatus` is externally tagged:
  - `{"ProcessedWithSuccess":{"deployResult":RhoExpr[],"block":LightBlockInfo}}`
  - `{"ProcessedWithError":{"deployError":string,"block":LightBlockInfo}}`
  - `{"NotProcessed":{"status":string}}`
- `RhoExpr` variants: `ExprPar/ExprTuple/ExprList/ExprSet` (arrays of `RhoExpr`),
  `ExprMap` (array of `[string, RhoExpr]`), `ExprBool`, `ExprInt`, `ExprString`,
  `ExprUri`, `ExprBytes`, `ExprUnforg`.
- `RhoUnforg` variants: `UnforgPrivate`, `UnforgDeploy`, `UnforgDeployer` (each a
  hex string). A **public quoted name** `@"hello"` is expressed as
  `{"ExprString":"hello"}`.

## Deploy signing

`DeployData` is protobuf-serialized, then hashed and signed:

| field | proto tag | type |
|---|---|---|
| term | 2 | string |
| timestamp | 3 | int64 (ms) |
| phloPrice | 7 | int64 |
| phloLimit | 8 | int64 |
| validAfterBlockNumber | 10 | int64 |
| **shardId** | **11** | string |

`shardId` **must** be written (field 11) or the node rejects the deploy with
`"Deploy signature is invalid."`.

Algorithm (see `wallet-spec.md` for key details):

1. `serialized = protobuf(DeployData)` with the field table above.
2. `hash = blake2b-256(serialized)`.
3. `sig = secp256k1_sign(hash)` — canonical (low-S), **DER-encoded**.
4. `deployer = uncompressed 65-byte public key` (hex).
5. `sigAlgorithm = "secp256k1"`.

`DeployRequest` body:

```json
{
  "data": { "term", "timestamp", "phloPrice", "phloLimit", "validAfterBlockNumber", "shardId" },
  "deployer": "<hex 65-byte uncompressed pubkey>",
  "signature": "<hex DER sig>",
  "sigAlgorithm": "secp256k1"
}
```

## Deploy lifecycle

1. `get_status` → read `latestBlockNumber` (→ `validAfterBlockNumber`) and
   `minPhloPrice` (→ `phloPrice`).
2. Build `DeployData`, `sign_deploy`.
3. `POST /api/deploy` → deploy id.
4. Poll `GET /api/v1/deploy-status/:id` until terminal
   (`ProcessedWithSuccess` / `ProcessedWithError`).
5. If the node is in manual-propose mode, `POST /api/propose` to force a block.

## Native `revVault` system process

`RChainWallet` balance/transfer are rholang deploys against the native
`rho:rchain:revVault` process (not dedicated RPC calls):

| method | args | notes |
|---|---|---|
| `getBalance` | `[addr_string, ret]` | produces balance `Int` (0 if absent) |
| `transfer` | `[*deployerId, to_string, amount, ret]` | `from` derived from caller's `deployerId`; self-transfer is a no-op |
| `findOrCreate` | `[*deployerId, ret]` | produces `(true, addr)` |

Templates (see `~/RWallet/r-wallet/src/utils/rho.ts`):

```rholang
// check balance
new return, revVault(`rho:rchain:revVault`), balanceCh in {
  revVault!("getBalance", "<addr>", *balanceCh) |
  for (@balance <- balanceCh) { return!(balance) }
}

// transfer
new revVault(`rho:rchain:revVault`), deployerId(`rho:rchain:deployerId`),
    deployId(`rho:rchain:deployId`), resultCh in {
  revVault!("transfer", *deployerId, "<to>", <amount>, *resultCh) |
  for (_ <- resultCh) { deployId!((true, "Transfer successful (not yet finalized).")) }
}
```

## `RhoExpr` JSON conversion (for SDK)

`rhoExprToJson` mapping (recursive): `ExprInt→number`, `ExprString→string`,
`ExprBool→boolean`, `ExprUnforg→hex string`, `ExprList/Tuple/Set/Par→array`,
`ExprMap→object`. This is what `RholangSDK` uses to turn on-chain data into Godot
`Dictionary`/`Array`.
