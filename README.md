# Robot Design Interface

AI-powered robotics simulator in Godot 4 with ROS 2 integration and blockchain design sharing.

## Status

- **Godot 4.4** — Runs clean
- **ROS 2** — Bridge connection working
- **Blockchain** — ARIADNE + AO Hyperobjects integrated
- **AI Agent** — Experimental

## Quick Start

### 1. Clone and Open

```bash
git clone https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface.git
cd Godot_4__Robotic_Design_Interface
godot
```

### 2. Build ROS 2 Bridge

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --packages-select godot_ros2_bridge
source install/setup.sh
export ROS_DOMAIN_ID=0
ros2 run godot_ros2_bridge godot_bridge_node
```

### 3. Run Godot

```bash
cd Godot_4__Robotic_Design_Interface
godot --headless --quit
```

## Features

- **ROS 2 Simulation** — Simulate robots with realistic sensor data from ROS 2
- **AI Code Agent** — Generate GDScript behaviors (obstacle avoidance, wall following, patrol)
- **Blockchain Publishing** — Publish robot designs permanently to Arweave via ARIADNE
- **Tradeable Designs** — Robot designs become transferable via AO Hyperobjects
- **TurtleBot4 Ready** — Real meshes and physics from ROS 2 packages

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Robot Design Interface                      │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Godot Controls)                                   │
│  ├── ROS2 Bridge controls                                   │
│  ├── Robot spawner (TurtleBot4)                              │
│  ├── Simulation controls (play/pause/reset)                   │
│  └── AI behavior generation                                  │
├─────────────────────────────────────────────────────────────┤
│  3D Viewport                                                 │
│  └── TurtleBot4 simulation running live                       │
├─────────────────────────────────────────────────────────────┤
│  GameAI SDK (EXPERIMENTAL)                                   │
│  └── AI Code Agent — Behavior generation                     │
├─────────────────────────────────────────────────────────────┤
│  GodotROS2 SDK                                              │
│  ├── ROS2Simulator (physics, sensors)                       │
│  ├── TurtleBot4Loader (meshes or primitives)                 │
│  ├── DifferentialDrive (wheel kinematics)                    │
│  └── ROS2BridgeClient ← TCP/UDP → ROS 2                     │
├─────────────────────────────────────────────────────────────┤
│  Blockchain Layer                                            │
│  ├── ARIADNE — Git-on-Arweave (permanent storage)           │
│  └── AO Hyperobjects — Ownership and trading                │
└─────────────────────────────────────────────────────────────┘
```

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Setup, installation, first robot |
| [ROS 2 Simulation](docs/simulation.md) | Sensors, actuators, robot models |
| [Blockchain](docs/blockchain.md) | ARIADNE + AO Hyperobjects |
| [Development](docs/development/code-patterns.md) | Godot 4.x patterns |

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Godot | 4.4+ | |
| ROS 2 | Jazzy or Humble | |
| Node.js | 22+ | For ARIADNE CLI |
| Arweave Wallet | JWK | Optional, for blockchain |

## ROS 2 Topics

| Topic | Type | Direction | Description |
|-------|------|-----------|-------------|
| `/turtlebot4/odom` | `nav_msgs/Odometry` | Godot → ROS | Ground-truth odometry |
| `/turtlebot4/scan` | `sensor_msgs/LaserScan` | Godot → ROS | 360° lidar scan |
| `/turtlebot4/imu` | `sensor_msgs/Imu` | Godot → ROS | IMU data |
| `/turtlebot4/cmd_vel` | `geometry_msgs/Twist` | ROS → Godot | Velocity command |

## License

MIT
