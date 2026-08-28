# RChain — GDScript SDK Specification

The GDScript SDK lives in `scripts/rchain/` and is the only layer the rest of the
app talks to. All classes return `Result` (`addons/primitives/result.gd`) for
fallible operations, mirroring the existing Arweave/AO SDK.

## `RNodeClient` (extends `RefCounted`)

Typed HTTP client for the RNode public/admin API (`protocol.md`). Configured from
`EnvService` (`RCHAIN_HOST`/`RCHAIN_PUBLIC_PORT`/`RCHAIN_ADMIN_PORT`, defaults
`localhost` / `40403` / `40405`).

```
var base_url: String
var admin_url: String
func get_status() -> Result                       # -> { version, address, network_id, shard_id, min_phlo_price, latest_block_number, ... }
func explore_deploy(term: String) -> Result        # -> { expr: Array, block: Dictionary }
func deploy(request: Dictionary) -> Result         # -> deploy_id String
func deploy_status(id: String) -> Result           # -> { status: String, result: Array, block: Dictionary }
func propose() -> Result
func data_at_name(name_rho: Dictionary, depth: int) -> Result   # -> { exprs: Array, length: int }
func get_block(hash: String) -> Result
func faucet(address: String) -> Result             # -> { deploy_id, amount, to }
func get_capabilities() -> Result                  # -> { autopropose, propose_on_deploy, manual_propose, admin_http, dev_mode, faucet }
func get_pooled_deploys() -> Result
```

`deploy()` performs submit-and-track: POST, parse the deploy id, then poll
`deploy_status()` until terminal. Blocking HTTP is done via a small internal
helper (Godot `HTTPRequest` + a bounded poll loop), not `HyperHttpClient`'s
async signals, because `SignalBridge` needs synchronous reads.

## `RholangSDK` (extends `RefCounted`)

Builds rholang terms and encodes/decodes `RhoExpr` JSON.

```
func name_to_rho(name: String) -> Dictionary            # {"ExprString": name}
func rho_expr_to_json(expr: Variant) -> Variant          # externally-tagged RhoExpr -> plain JSON
func build_send(channel_rho: Dictionary, payload_rho: Dictionary) -> String   # "<ch>!(<payload>)"
func build_register_robot(name: String, record: Dictionary) -> String
func build_query(name: String) -> String
func build_transfer(robot: String, to: String) -> String
func build_publish_job(job_id: String, spec: Dictionary) -> String
func build_claim_job(job_id: String, robot: String) -> String
func build_complete_job(job_id: String, result: Dictionary) -> String
func build_emit(channel: String, data: Dictionary) -> String
func build_check_balance(address: String) -> String     # revVault getBalance
func build_transfer_rev(to: String, amount: int) -> String
```

Term builders are string templates (like `~/RWallet/r-wallet/src/utils/rho.ts`);
each embeds the canonical contract name from `rholang-contracts.md` and the
`*return` channel pattern for query-style calls.

## `RChainWallet` (extends `Wallet` from `addons/primitives/wallet/wallet.gd`)

See `wallet-spec.md` for the full crypto contract. GDScript responsibilities:
key lifecycle, REV address, deploy signing, balance/transfer, mnemonic/keystore.

```
func generate() -> Result
func from_private_key(hex: String) -> Result
func export_private_key() -> String
func get_public_key() -> String
func get_rev_address() -> String
func sign_deploy(term: String, node_status: Dictionary) -> Result   # fills timestamp/phlo from node
func check_balance() -> Result                                       # -> int
func transfer(to: String, amount: int) -> Result                     # -> deploy_id
func save_keystore(password: String, path: String) -> Result
func load_keystore(path: String, password: String) -> Result
func from_mnemonic(phrase: String) -> Result
func generate_mnemonic() -> String
```

Holds an internal `RNodeClient` for balance/transfer and a reference to the
`RChainCrypto` GDExtension singleton.

## `SignalBridge` (extends `Node`)

The adapter between Godot signals and rholang channels.

```
signal channel_data(channel: String, data: Dictionary)

func register_channel(signal_name: String, channel_name: String) -> void
func emit(channel: String, data: Dictionary) -> Result       # build + deploy a channel send
func poll() -> void                                          # called by a Timer (~1 s)
```

Internally keeps `_channels: Dictionary` (`channel_name -> last_seen`). `poll()`
calls `data_at_name` for each subscribed channel, diffs against `last_seen`, and
emits `channel_data` for new data. `emit()` builds `channel!(data)` via
`RholangSDK.build_emit` and deploys it with `RChainWallet`.

## Autoload

A single `RChainService` autoload (`scripts/rchain/rchain_service.gd`, `extends
Node`) owns one `RChainWallet`, one `RNodeClient`, one `RholangSDK`, and one
`SignalBridge`, so the whole app shares one node connection and one identity.
Registered in `project.godot`.
