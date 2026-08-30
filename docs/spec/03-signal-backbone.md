# 03 — The Signal Backbone

Godot's signal system is the single integration surface of Copernicus. ROS2 topics, rholang channels
(the actor model), Python subprocesses, and plugin modules are all **adapted** to Godot signals. This
document states the rules and the event table; it is falsifiable (a test or grep can catch a
violation).

## Rule A — The adapter rule

Each external system has **exactly one** adapter (a `Node` or `RefCounted`) that owns the I/O and
emits Godot signals **on the main thread**. No panel performs I/O directly.

- **ROS2** → `GodotROS2` (autoload). A topic subscription becomes a Godot signal: the adapter exposes
  `topic_received(topic: String, message)` and the `initialization_completed(success)` signal. Panels
  create publishers/subscriptions through the adapter; they do not touch the executor. The status bar
  subscribes to `initialization_completed` — it does not test for node existence.
- **rholang (actor model)** → `SignalBridge` inside `RChainService`. A channel watch becomes
  `channel_message(channel, data)`; `RChainCoordination` re-exposes domain events (`robot_registered`,
  `job_published`, `job_claimed`, `work_published`, `work_settled`, `capability_granted`,
  `ownership_transferred`, `channel_message`). The mechanism is poll→diff→`call_deferred` (latency
  contract: ≤1 s per `_poll_interval`), documented as such; a lower-latency watch is a future change,
  not a different mechanism.
- **Python** → one `PythonBridge` (this unifies the currently-duplicated TCP bridges used by ROS2 and
  PyTorch). It emits `bridge_ready`, `bridge_error`, and `output_received(data)`. There is one JSON-
  line TCP protocol for all Python subprocesses.

## Rule B — The async rule

There is **one** task runner. Today there are two (`RChainService.run_async` callbacks and
`SignalBridge`'s raw thread); they are merged into a single `TaskRunner` autoload that:

- runs a `Callable` on a background thread (bounded pool),
- emits `task_completed(task_id, result)` on the main thread when done,
- never blocks the main thread.

All long work (RNode HTTP, AI chat, `OS.execute`, Python requests) goes through `TaskRunner`. No
`HTTPRequest`/`OS.execute`/blocking read runs on the main thread. The AI assistant (`scripts/ai/`) runs
its agent loop on a worker thread and marshals results back to the main thread, so its events fire
*after* the work completes, not after a blocking call on the UI thread.

## Rule C — The domain-signal rule

A signal declared by a service or backend **must have at least one consumer** (a UI component, a
listener, or a test). A declared-and-unconsumed signal is a spec violation. Panels *subscribe* to
backend signals; they do not only read method return values.

Currently violating this (each is declared but has zero `.connect`): `SignalBridge.channel_data`,
every `CoordinationCore` signal, every `GPUBackend` signal (`backend_ready`, `training_step`,
`episode_complete`, `inference_complete`, `raycast_complete`), `GodotROS2.initialization_completed`,
`PythonBridge.bridge_ready`/`bridge_error`. The implementation must connect each to a consumer or a
test.

## Event table

| Service / backend | Signals | Consumer |
|---|---|---|
| `GodotROS2` | `initialization_completed`, `topic_received` | status bar; sensor panels |
| `SignalBridge` (`RChainService`) | `channel_data` | coordination panel / channel view |
| `RChainCoordination` / `MockCoordination` | `robot_registered`, `capability_granted/revoked`, `ownership_transferred`, `job_published/claimed/completed`, `work_published/settled`, `channel_message`, `error_occurred` | coordination panel; `ScenarioService` (validates "register it", "run it for hire") |
| `MarketplaceCore` + backends | `listings_loaded`, `search_completed`, `listing_purchased/created`, `purchase_failed`, `loading_started/finished`, `error_occurred` | marketplace panel; `ScenarioService` (validates "put it on the market") |
| `GPUBackend` | `backend_ready/error`, `training_step`, `episode_complete`, `inference_complete`, `raycast_complete` | learning panel |
| `PythonBridge` | `bridge_ready`, `bridge_error`, `output_received` | gpu backends |
| `TaskRunner` | `task_completed` | any async caller |
| `ScenarioService` | `verdict_changed`, `scenario_changed` | `UiBrief` |
| `NavigationModel` | `route_changed` | `MainShell` (renders current route) |
| `RobotViewerController` | `robot_loaded`, `joint_changed`, `selection_changed`, `target_reached`, `joints_zeroed`, `viewport_action` | workspace, `ScenarioService` (validates "first light", "set the pose") |
| Sensors (`LidarDebug` etc.) | `scan_completed` | test mode / `ScenarioService` ("see what it sees") |

## Consequence

ROS2, blockchain, Python, and plugins are not "features with popups"; they are *producers of signals*
that the single tree consumes. The robot-design interface is the hub: loading a robot, moving a joint,
toggling a sensor, registering on-chain, or settling a job each emit a signal that both the UI and the
scenario engine (`ScenarioService`) observe — which is what makes the Workbench Loop legible and the
app coherent.
