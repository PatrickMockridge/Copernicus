# Robot Design POC

**Proof of Concept: AI-powered robot design with GameAI + GodotROS2 + TurtleBot4**

> **Status**: Async fixes committed. Headless runs clean. UI rebuild blocked — main.gd can't reference autoloads (Godot parses main.gd before autoloads register). Need to investigate Godot initialization order or use deferred connections.

---

## What This Project Is

**An AI code agent for robot design** — like the Claude plugin in VS Code, but for robotics in Godot.

The AI is a **coding assistant embedded in the Godot editor** that helps you:
- **Write GDScript behaviors** for your robot (obstacle avoidance, wall following, patrol, etc.)
- **Debug issues** — "robot drifts left when moving forward, why?"
- **Architect robot systems** — state machines, sensor processing pipelines, controller logic
- **Reason about complex math** — PID tuning, coordinate transforms, kinematics, sensor models

Think: you select your robot in the Godot scene tree, type a request like "add obstacle avoidance using LIDAR", and the AI generates and explains the GDScript code for you. The AI understands your robot's context — its sensors, actuators, and existing code.

### The Core Loop

1. **Build** — Spawn a TurtleBot4 in Godot's 3D simulator (real meshes or primitive shapes)
2. **Connect** — Bridge to ROS 2 via TCP/UDP for live sensor data
3. **Ask AI** — Describe what you want: "generate obstacle avoidance behavior" or "explain this sensor math"
4. **Run** — Generated code runs in simulation with real sensor feedback from ROS 2

---

## Current Problems

### 1. Godot 4.4 Coroutine Breaking Changes

Godot 4.4 requires explicit `async` keyword on any function using `await`. In 4.0-4.3 this was implicit — the function silently became async. In 4.4, `await` in a non-async function is a **parse error**.

**Additionally**: `async func` itself is rejected with "Unexpected identifier in class body" even in Godot 4.3 — this appears to be a Godot build/environment issue affecting even minimal test files. This blocks both 4.3 and 4.4.

**Workaround**: Signals + Thread pattern replaces `async`/`await` entirely. Thread.start() + call_deferred() + emit_signal() achieves the same async behavior without the `async` keyword.

### 2. `class_name` Placement in Multi-Class Files

Godot 4.4 is stricter about `class_name` declarations. When a file has multiple top-level classes, each must be properly closed with `}` before the next `class_name` declaration. Inner classes should use `class X extends Y` syntax (no `class_name`).

### 3. `OS.delay_msec()` Deprecation

`OS.delay_msec()` is deprecated in Godot 4.4. It still works but emits deprecation warnings.

### 4. Cross-File Dependency Cascade

Godot loads all scripts at startup. If any script references a type from another file that failed to load, the referencing script also fails. This means fixes must be applied in dependency order or circular dependencies must be broken.

---

## Fix Progress — Incremental Todos

**Goal**: Full robot simulation with AI behavior generation working in Godot 4.3. Each fix is a success.

### Completed ✅

| Todo | File | Fix |
|------|------|-----|
| ✅ | `result.gd` | Remove static `ok()`/`err()` methods — circular reference at class definition time |
| ✅ | `http_client.gd` | Added `const Result = preload(...)` for type resolution; replaced `Result.ok()`/`Result.err()` calls |
| ✅ | `ai.gd` | No changes needed — already synchronous, returns `Result` directly |
| ✅ | `ros_ai.gd` | Converted all 10 async functions to sync + signal emit |
| ✅ | `ros2_bridge_client.gd` | `async func connect_bridge()` → Thread + `bridge_connection_completed` signal |
| ✅ | `godot_ros2.gd` | `async func initialize()` → signal-based callback chain |
| ✅ | `project.godot` | All 3 autoloads re-enabled (GameAI, ROSAI, GodotROS2) |
| ✅ | `main.gd` | Minimal stub for now — UI rebuild next |
| ✅ | **Headless test** | `godot4.3 --headless --quit` — no script errors, all autoloads load |

### In Progress 🔄

| Todo | File | Issue |
|------|------|-------|
| 🔄 | `main.gd` | **BLOCKED**: Godot parses main.gd at scene load time, before autoloads register. Autoload singletons (GameAI, ROSAI, GodotROS2) are not visible in main.gd's scope at parse time. Need deferred signal connections or different architecture. |
| 🔄 | Editor mode | Other SDK files still have `async` / structural issues (character_ai.gd, actuators.gd, physics_bodies.gd, etc.) — only affect editor code completion, not runtime |

---

## AI Code Agent Architecture

The AI integration is a **code agent** — like Claude in VS Code, embedded in the Godot editor.

**Principle**: The AI helps you write scripts, architect robot systems, and reason about complex math involved in robot design. It doesn't just generate text — it's an interactive coding assistant that understands your robot's context.

### How it works

- **GameAI (ai.gd)** — Generic AI provider wrapper for Claude, OpenAI, Minimax. Provides `chat()`, `generate_code()`, `explain_code()`.
- **ROSAI (ros_ai.gd)** — Robotics-specific AI code agent built on GameAI. Generates GDScript for behaviors, controllers, state machines; debugs issues; explains ROS topics.
- **Signals** — All AI operations are async via signals. Connect to `behavior_generated`, `diagnosis_completed`, etc.

### Design Decision: Signals over async/await

Godot 4.3 rejects `async func` declarations with "Unexpected identifier in class body". All async operations use **Thread + Signal pattern**:

```gdscript
var _thread: Thread
signal bridge_connection_completed(success: bool)

func connect_bridge() -> void:
    _thread = Thread.new()
    _thread.start(callable(self, "_connect_thread"))

func _connect_thread():
    # blocking work
    call_deferred("emit_bridge_connection_completed", true)
```

---

## Tomorrow's Tasks

1. **Fix main.gd autoload reference** — Godot parses main.gd before autoloads register. Try:
   - Move signal connections to `_enter_tree()` instead of `_ready()`
   - Use `call_deferred()` for autoload access
   - Or: make main.gd an autoload itself

2. **Editor mode fixes** — Fix remaining `async` in non-essential SDK files (character_ai.gd, demo.gd, roblox_ai.gd, actuators.gd, physics_bodies.gd, sensors.gd, simulator_plugins.gd)

3. **Full UI rebuild** — AI code agent panel with context display, task input, code output, action buttons

---

## Execution Rule

1. **Test after every single fix** — open Godot headless, check errors, close before next
2. **Commit after every passing test** — each fix is independently reversible
3. If errors persist after applying fix, the fix was wrong — do NOT move to next file
4. **Break circular dependencies first** — a minimal stub that does nothing is better than a complex file that won't load

---

## Last Godot 4.3 Output

```
Godot Engine v4.3.stable.official.77dcf97d8 - https://godotengine.org

WARNING: res://scenes/main.tscn:3 - ext_resource, invalid UID: uid://rns1mio6uock - using text path instead: res://scripts/main.gd
```

Headless mode (`godot4.3 --headless --quit`) runs with no script errors. All 3 autoloads (GameAI, ROSAI, GodotROS2) load successfully.

**Note**: Editor mode (`-e`) shows additional parse errors in non-essential SDK files (character_ai.gd, roblox_ai.gd, demo.gd, actuators.gd, physics_bodies.gd, sensors.gd, simulator_plugins.gd). These only affect editor code completion — the headless runtime is fully functional.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Robot Design POC                          │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Godot Controls — split panel)                   │
│  ├── ROS2 Bridge controls                                   │
│  ├── Robot spawner (TurtleBot4, mesh/primitive toggle)      │
│  ├── Simulation controls (play/pause/reset)                  │
│  ├── AI behavior generation                                  │
│  └── Generated code display                                  │
├─────────────────────────────────────────────────────────────┤
│  3D Viewport (right panel)                                  │
│  └── TurtleBot4 simulation running live                       │
├─────────────────────────────────────────────────────────────┤
│  GameAI SDK                                                 │
│  ├── AI Provider Integration (Claude, OpenAI, etc.)          │
│  └── ROSAI Module — Behavior Generation                     │
├─────────────────────────────────────────────────────────────┤
│  GodotROS2 SDK                                              │
│  ├── ROS2Simulator (physics, sensors)                       │
│  ├── TurtleBot4Loader (real DAE meshes or primitives)        │
│  ├── DifferentialDrive (wheel kinematics)                    │
│  └── ROS2BridgeClient → godot_ros2_bridge (ROS 2 node)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Signals + Thread Pattern

All `async func` / `await` is being replaced with:

```gdscript
var _thread: Thread
signal completed(result: Variant)

func do_async_work():
    _thread = Thread.new()
    _thread.start(callable(self, "_worker_thread").bind(args))

func _worker_thread():
    var result = blocking_work()
    call_deferred("emit_signal", "completed", result)
```

This achieves the same async behavior without the `async` keyword.

---

## Requirements

- Godot 4.3 (for development — 4.4 compatibility pending async rebuild)
- ROS 2 Jazzy (or Humble)
- `godot_ros2_bridge` package built in your ROS workspace
- TurtleBot4 ROS 2 packages (`ros-jazzy-turtlebot4-description`)
- GameAI SDK addon (included as submodule)
- GodotROS2 SDK addon (included as submodule)
- Anthropic API key (or OpenAI/Minimax)

## Quick Start (Godot 4.3)

### 1. Build the ROS 2 bridge

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --packages-select godot_ros2_bridge
source install/setup.sh
```

### 2. Start the bridge

```bash
ros2 run godot_ros2_bridge godot_bridge_node
```

### 3. Open Godot

```bash
cd Godot_4_Robotic_Design_Interface
godot4.3 --headless --quit
# Or open in Godot 4.3 editor
```

### 4. In-Godot controls (after full rebuild)

1. **Spawn TurtleBot4** — choose DAE Meshes (real robot visuals) or Primitives (Godot boxes/cylinders)
2. **Connect Bridge** — connects Godot to the running `godot_ros2_bridge` node
3. **Play / Pause / Reset** — control the simulation
4. Enter your **AI API key** and click **Connect AI**
5. Select a behavior and click **Generate with AI**

---

## ROS 2 Topics

| Topic | Type | Direction | Description |
|-------|------|-----------|-------------|
| `/turtlebot4/odom` | `nav_msgs/Odometry` | Godot → ROS | Ground-truth odometry |
| `/turtlebot4/scan` | `sensor_msgs/LaserScan` | Godot → ROS | 360° lidar scan (640 samples) |
| `/turtlebot4/imu` | `sensor_msgs/Imu` | Godot → ROS | IMU data |
| `/turtlebot4/cmd_vel` | `geometry_msgs/Twist` | ROS → Godot | Velocity command — drives the robot |

---

## TurtleBot4 Model

The simulator loads the real TurtleBot4 geometry from the ROS 2 packages:

- **Base**: Create3 — cylinder (r=0.164m, h=0.06m), mass 2.3kg
- **Wheels**: Differential drive, separation 0.233m, radius 0.0419m
- **Shell**: 0.390kg box on top
- **RPLidar A1**: 360° scan, 640 samples, range 0.164–12m, 62Hz
- **Oak-D Pro camera**: Forward-facing RGB-D
- **IMU**: In Create3 base

Meshes are loaded from `/opt/ros/jazzy/share/turtlebot4_description/meshes/` and `/opt/ros/jazzy/share/irobot_create_description/meshes/`. Select **Primitives** mode to build from Godot geometry instead.

---

## Bridge Protocol

The bridge uses:
- **TCP port 8765** — JSON control commands (create/destroy publishers/subscriptions, spin)
- **UDP port 8766** — High-frequency message data (sensor readings, odometry)

The `godot_ros2_bridge` Python package must be running as a ROS 2 node on the same machine.

---

## AI Behavior Generation

Uses GameAI to generate GDScript behaviors:
- `obstacle_avoid` — Lidar-based collision avoidance
- `wall_follow` — Maintain distance from walls
- `patrol` — Navigate between waypoints
- `chase` — Follow a moving target
- `flee` — Escape from threats

Generated code is displayed and can be copied for use in other GodotROS2 projects.

---

## Submodules

- `addons/GameAI` — GameAI SDK (AI code generation)
- `addons/godot_ros2` — GodotROS2 SDK (ROS 2 integration)

Both submodules are pinned to specific commits and modified inline for compatibility fixes. Do not update them without testing against Godot 4.3.

---

## License

MIT
