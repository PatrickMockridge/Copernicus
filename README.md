# Robot Design POC

**Proof of Concept: AI-powered robot design with GameAI + GodotROS2 + TurtleBot4**

A demonstration of integrating AI code generation with robotics simulation in Godot 4, connected live to ROS 2.

## Concept

This POC shows how AI can assist in robot design by:
1. Spawning a real robot model (TurtleBot4) in a Godot 3D simulation
2. Connecting it live to ROS 2 via a TCP/UDP bridge
3. Using GameAI to generate GDScript behavior code for the robot
4. Running the behavior in simulation with full sensor data flowing to/from ROS 2

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

- Godot 4.2+ (or 4.3+ for `.uid` resource support)
- ROS 2 Jazzy (or Humble)
- `godot_ros2_bridge` package built in your ROS workspace
- TurtleBot4 ROS 2 packages (`ros-jazzy-turtlebot4-description`)
- GameAI SDK addon (included as submodule)
- GodotROS2 SDK addon (included as submodule)
- Anthropic API key (or OpenAI/Minimax)

## Quick Start

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

### 4. In-Godoot controls

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

## License

MIT
