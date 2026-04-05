# Robot Design POC

**Proof of Concept: AI-powered robot design with GameAI + GodotROS2 + TurtleBot4**

> **Status**: Development halted — Godot 4.4 compatibility issues in progress. See todos below.

---

## What This Project Aims to Do

1. Spawn a real robot model (TurtleBot4) in a Godot 3D simulation
2. Connect it live to ROS 2 via a TCP/UDP bridge
3. Use GameAI to generate GDScript behavior code for the robot
4. Run the behavior in simulation with full sensor data flowing to/from ROS 2

---

## Current Problems

### 1. Godot 4.4 Coroutine Breaking Changes

Godot 4.4 requires explicit `async` keyword on any function using `await`. In 4.0-4.3 this was implicit — the function silently became async. In 4.4, `await` in a non-async function is a **parse error**.

**Root cause**: Code was written against Godot 4.2/4.3 where this pattern silently worked.

**Fix rule**: For any function that calls `await`, change `func` to `async func`. Callers of async functions must also be async — this creates a cascade up the call chain.

### 2. `class_name` Placement in Multi-Class Files

Godot 4.4 is stricter about `class_name` declarations. When a file has multiple top-level classes, each must be properly closed with `}` before the next `class_name` declaration. Inner classes should use `class X extends Y` syntax (no `class_name`).

### 3. `OS.delay_msec()` Deprecation

`OS.delay_msec()` is deprecated in Godot 4.4. It still works but emits deprecation warnings.

---

## Fix Progress — Incremental Todos

**Goal**: Project opens in Godot 4.4 with zero script errors. Each fix is a success.

### Completed ✅

| Todo | File | Fix |
|------|------|-----|
| ✅ | `ros_ai.gd` | All ~10 async functions already correct |
| ✅ | `character_ai.gd` | All ~11 async functions already correct |
| ✅ | `roblox_ai.gd` | All ~16 async functions already correct |
| ✅ | `demo.gd` | `_on_generate_code_pressed` already async |
| ✅ | `ros2_bridge_client.gd` | `connect_bridge` already async |
| ✅ | `sensors.gd` | Inner classes closed with `}` |
| ✅ | `actuators.gd` | Inner classes closed with `}` |
| ✅ | `physics_bodies.gd` | Inner classes closed with `}` |
| ✅ | `simulator_plugins.gd` | Inner classes closed with `}` |

### In Progress 🔄

| Todo | File | Issue |
|------|------|-------|
| 🔄 | `scripts/main.gd` | `_on_generate_pressed` (line 588) needs `async` |
| 🔄 | `godot_ros2.gd` | `initialize` (line 25) needs `async` |

### Not Started ⬜

| Todo | File | Issue |
|------|------|-------|
| ⬜ | `ros_ai.gd` | "Unexpected identifier async in class body" at line 35 — file may have encoding issue, needs investigation |

---

## Execution Rule

1. **Test after every single fix** — open Godot headless, check errors, close before next
2. **Commit after every passing test** — each fix is independently reversible
3. If errors persist after applying fix, the fix was wrong — do NOT move to next file

---

## Last Godot Error Output

```
SCRIPT ERROR: Parse Error: Unexpected identifier "async" in class body.
          at: GDScript::reload (res://addons/GameAI/integrations/ros/ros_ai.gd:35)
SCRIPT ERROR: Parse Error: Could not parse global class "ROS2BridgeClient" from "res://addons/godot_ros2/ros2/ros2_bridge_client.gd".
SCRIPT ERROR: Parse Error: Unexpected identifier "async" in class body.
          at: GDScript::reload (res://scripts/main.gd:419)
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Robot Design POC                          │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Godot Controls — split panel)                    │
│  ├── ROS2 Bridge controls                                   │
│  ├── Robot spawner (TurtleBot4, mesh/primitive toggle)      │
│  ├── Simulation controls (play/pause/reset)                  │
│  ├── AI behavior generation                                  │
│  └── Generated code display                                  │
├─────────────────────────────────────────────────────────────┤
│  3D Viewport (right panel)                                  │
│  └── TurtleBot4 simulation running live                      │
├─────────────────────────────────────────────────────────────┤
│  GameAI SDK                                                 │
│  ├── AI Provider Integration (Claude, OpenAI, etc.)          │
│  └── ROSAI Module — Behavior Generation                     │
├─────────────────────────────────────────────────────────────┤
│  GodotROS2 SDK                                              │
│  ├── ROS2Simulator (physics, sensors)                        │
│  ├── TurtleBot4Loader (real DAE meshes or primitives)       │
│  ├── DifferentialDrive (wheel kinematics)                    │
│  └── ROS2BridgeClient → godot_ros2_bridge (ROS 2 node)      │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

- Godot 4.2 or 4.3 (for development — 4.4 compatibility pending)
- ROS 2 Jazzy (or Humble)
- `godot_ros2_bridge` package built in your ROS workspace
- TurtleBot4 ROS 2 packages (`ros-jazzy-turtlebot4-description`)
- GameAI SDK addon (included as submodule)
- GodotROS2 SDK addon (included as submodule)
- Anthropic API key (or OpenAI/Minimax)

## Quick Start (Godot 4.2/4.3)

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
godot4 --headless  # or open in Godot editor
```

### 4. In-Godot controls

1. **Spawn TurtleBot4** — choose DAE Meshes (real robot visuals) or Primitives (Godot boxes/cylinders)
2. **Connect Bridge** — connects Godot to the running `godot_ros2_bridge` node
3. **Play / Pause / Reset** — control the simulation
4. Enter your **AI API key** and click **Connect AI**
5. Select a behavior and click **Generate with AI**

## ROS 2 Topics

| Topic | Type | Direction | Description |
|-------|------|-----------|-------------|
| `/turtlebot4/odom` | `nav_msgs/Odometry` | Godot → ROS | Ground-truth odometry |
| `/turtlebot4/scan` | `sensor_msgs/LaserScan` | Godot → ROS | 360° lidar scan (640 samples) |
| `/turtlebot4/imu` | `sensor_msgs/Imu` | Godot → ROS | IMU data |
| `/turtlebot4/cmd_vel` | `geometry_msgs/Twist` | ROS → Godot | Velocity command — drives the robot |

## TurtleBot4 Model

The simulator loads the real TurtleBot4 geometry from the ROS 2 packages:

- **Base**: Create3 — cylinder (r=0.164m, h=0.06m), mass 2.3kg
- **Wheels**: Differential drive, separation 0.233m, radius 0.0419m
- **Shell**: 0.390kg box on top
- **RPLidar A1**: 360° scan, 640 samples, range 0.164–12m, 62Hz
- **Oak-D Pro camera**: Forward-facing RGB-D
- **IMU**: In Create3 base

Meshes are loaded from `/opt/ros/jazzy/share/turtlebot4_description/meshes/` and `/opt/ros/jazzy/share/irobot_create_description/meshes/`. Select **Primitives** mode to build from Godot geometry instead.

## Bridge Protocol

The bridge uses:
- **TCP port 8765** — JSON control commands (create/destroy publishers/subscriptions, spin)
- **UDP port 8766** — High-frequency message data (sensor readings, odometry)

The `godot_ros2_bridge` Python package must be running as a ROS 2 node on the same machine.

## AI Behavior Generation

Uses GameAI to generate GDScript behaviors:
- `obstacle_avoid` — Lidar-based collision avoidance
- `wall_follow` — Maintain distance from walls
- `patrol` — Navigate between waypoints
- `chase` — Follow a moving target
- `flee` — Escape from threats

Generated code is displayed and can be copied for use in other GodotROS2 projects.

## Submodules

- `addons/GameAI` — GameAI SDK (AI code generation)
- `addons/godot_ros2` — GodotROS2 SDK (ROS 2 integration)

Both submodules are pinned to specific commits and modified inline for compatibility fixes. Do not update them without testing against Godot 4.4.

## License

MIT