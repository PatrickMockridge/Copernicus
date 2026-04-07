# Robot Design Interface

AI-powered robotics simulator in Godot 4 with ROS 2, blockchain publishing, and AI code generation.

## Features

- **ROS 2 Simulation** — Simulate TurtleBot4 with realistic sensor data
- **AI Code Agent** — Generate GDScript behaviors (obstacle avoidance, wall following, patrol) via Minimax/Claude
- **Blockchain Publishing** — Publish robot designs permanently to Arweave
- **Tradeable Designs** — Robot designs become transferable via AO Hyperobjects

## Quick Start

```bash
git clone https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface.git
cd Godot_4__Robotic_Design_Interface
cp .env.example .env
# Add your Minimax API key to .env
godot
```

## AI Setup

The AI code agent uses Minimax (same API as Claude Code in VS Code).

1. Copy `.env.example` to `.env`
2. Add your API key:
   ```
   ANTHROPIC_API_KEY=your_key_here
   ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic
   ```
3. Run Godot and use the AI panel to generate robot behaviors

## ROS 2 Bridge

```bash
# Build the bridge
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --packages-select godot_ros2_bridge
source install/setup.sh

# Run
export ROS_DOMAIN_ID=0
ros2 run godot_ros2_bridge godot_bridge_node

# In another terminal
cd Godot_4__Robotic_Design_Interface
godot
```

## Architecture

```
Robot Design Interface
├─────────────────────────────────────────────────────────────┐
│  UI Layer (Godot Controls)                                   │
│  ├── AI behavior generation (GameAI SDK)                      │
│  ├── Robot spawner (TurtleBot4)                              │
│  ├── Simulation controls (play/pause/reset)                   │
│  └── ROS 2 Bridge controls                                   │
├─────────────────────────────────────────────────────────────┤
│  AI Layer                                                   │
│  ├── GameAI — Chat/completion via Minimax                   │
│  └── ROSAI — ROS-specific behavior prompts                  │
├─────────────────────────────────────────────────────────────┤
│  Simulation Layer                                            │
│  ├── GodotROS2 SDK — Sensors, actuators, physics            │
│  ├── TurtleBot4 — Real robot models                         │
│  └── ROS 2 Bridge — TCP/UDP communication                   │
├─────────────────────────────────────────────────────────────┤
│  Blockchain Layer                                            │
│  ├── ARIADNE — Git-on-Arweave (permanent storage)           │
│  └── AO Hyperobjects — Ownership and trading                │
└─────────────────────────────────────────────────────────────┘
```

## ROS 2 Topics

| Topic | Type | Description |
|-------|------|-------------|
| `/turtlebot4/odom` | nav_msgs/Odometry | Ground-truth odometry |
| `/turtlebot4/scan` | sensor_msgs/LaserScan | 360° lidar |
| `/turtlebot4/imu` | sensor_msgs/Imu | IMU data |
| `/turtlebot4/cmd_vel` | geometry_msgs/Twist | Velocity command |

## Testing

See [Testing](docs/testing.md) for test procedures and known issues.

## Documentation

- [Getting Started](docs/getting-started.md)
- [AI Code Agent](docs/ai-codegen.md)
- [Blockchain](docs/blockchain.md)
- [ROS 2 Simulation](docs/simulation.md)
- [Testing](docs/testing.md)

## Requirements

| Component | Version |
|-----------|---------|
| Godot | 4.4+ |
| ROS 2 | Jazzy or Humble |
| Node.js | 22+ (for ARIADNE CLI) |
