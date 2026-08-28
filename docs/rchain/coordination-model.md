# RChain — Coordination Model

The formal coordination model behind `CoordinationCore`. This is the "beyond
marketplace" layer: robots are coordinated through **capabilities**, **jobs** and
**channels**, not just bought and sold.

## `CoordinationCore` (abstract, `extends CopernicusModule`, category `"coordination"`)

```
func initialize(config: Dictionary) -> bool
func get_my_address() -> String
func is_coordination_connected() -> bool

# registry
func register_robot(robot: Dictionary) -> Result        # { name, asset_tx_id, metadata }
func get_robot(name: String) -> Result
func list_robots(filter: Dictionary = {}) -> Result

# capabilities / ownership
func issue_capability(robot: String) -> Result          # creates robot's capability, holder = self
func revoke_capability(robot: String) -> Result
func transfer_capability(robot: String, to: String) -> Result
func get_holder(robot: String) -> Result

# jobs
func publish_job(job: Dictionary) -> Result             # { id, spec, reward }
func claim_job(job_id: String, robot: String) -> Result
func complete_job(job_id: String, result: Dictionary) -> Result

# channels / signals
func open_channel(name: String) -> Result
func subscribe_channel(name: String) -> Result
func emit_event(channel: String, data: Dictionary) -> Result

# robotics-as-a-service (actuation + work-metered fee)
func publish_work(job_id: String, command: Dictionary) -> Result
func get_work(job_id: String) -> Result
func settle_work(robot: String, fee: int) -> Result
```

Signals:

```
robot_registered(name: String, record: Dictionary)
capability_granted(robot: String, holder: String)
capability_revoked(robot: String)
ownership_transferred(robot: String, from: String, to: String)
job_published(job_id: String, job: Dictionary)
job_claimed(job_id: String, robot: String)
job_completed(job_id: String, result: Dictionary)
channel_message(channel: String, data: Dictionary)
work_published(job_id: String, command: Dictionary)
work_settled(robot: String, fee: int)
error_occurred(message: String)
```

Backends self-register via `static func _static_init()` →
`ModuleRegistry.register("coordination", id, preload(...))`:
`RChainCoordination` (real) and `MockCoordination` (offline).

## Capability lifecycle (state machine)

A robot's **control authority** is an unforgeable rholang name. The
`ownership` contract tracks the current holder's address for discoverability;
the *actual* authority is the channel.

```
         issue                transfer(to)               transfer(to)
 unissued ─────► held(holder) ─────────────► held(to) ─────────────► held(to') …
                    │                                    ▲
                    └────────── revoke ──► revoked        │ (no re-issue path in v1)
```

- `issue_capability` = `new cap in { … }`, bind `robot → (cap, holder=deployerId)`.
- `transfer_capability(to)` = send the capability channel to `to`'s inbox and
  update the ledger's holder. (A sale is `transfer_capability` gated on a REV
  escrow in `marketplace.rho`.)
- `revoke_capability` = mark revoked; the ledger rejects subsequent
  `claim`/`transfer` for that robot.

## Job lifecycle (state machine)

```
              publish            claim(robot)              complete(result)
 (none) ───────────► published ──────────────► claimed ─────────────────► completed
                          │                         │
                          └── cancel ──► cancelled  └── abort ──► published
```

- `publish_job` writes `job_id → { spec, reward, state: published }`.
- `claim_job(job_id, robot)` **requires** `robot` to hold a valid capability
  (enforced in the `jobs` contract via a join on the capability channel). This is
  the rholang-atomic "you can only run this if you control the robot".
- `complete_job` writes the result to the job's result channel (emits
  `job_completed`).

## Signal ⇄ channel mapping

Each coordination signal has a canonical rholang channel (a quoted name). The
`SignalBridge` maps one to the other.

| Godot signal | rholang channel |
|---|---|
| `robot_registered` | `@"copernicus:registry"` |
| `ownership_transferred` | `@"copernicus:ownership"` |
| `job_published` | `@"copernicus:jobs"` |
| `job_completed` | `@"copernicus:job-results"` |
| `channel_message(name)` | `@"copernicus:channels:<name>"` (per-channel) |

`emit_event(channel, data)` → deploy `@"…"!(data)`; `SignalBridge.poll()` reads
`data_at_name` on each subscribed channel and emits the mapped Godot signal. The
underlying rholang contracts announce on these channels, so `robot_registered`
fires without the app having to be the one that deployed the register.

## Relationship to the marketplace

`MarketplaceCore`/`Listing` remain the UI-facing interface. A new
`RChainMarketplace extends MarketplaceCore` maps:

| MarketplaceCore op | CoordinationCore op |
|---|---|
| `create_listing` | `issue_capability` + list under `@"copernicus:marketplace"` with a price |
| `purchase_listing` | `transfer_capability(to)` gated on REV escrow |
| `load_listings` / `search_listings` | `list_robots` / registry query |
| `get_listing` | `get_robot` + `get_holder` |

Asset blobs still upload to Arweave; only the TX id + metadata + authority live
on RChain.
