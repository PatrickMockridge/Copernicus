# Getting Started

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Godot | 4.4+ | |
| ROS 2 | Jazzy or Humble | |
| Node.js | 22+ | For blockchain features |
| Git | Any recent | |

## Installation

### 1. Clone the Repository

```bash
git clone https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface.git
cd Godot_4__Robotic_Design_Interface
```

### 2. Build ROS 2 Bridge

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --packages-select godot_ros2_bridge
source install/setup.sh
```

### 3. Run Godot

```bash
cd Godot_4__Robotic_Design_Interface
godot --headless --quit
```

## Project Structure

```
.
├── addons/
│   ├── godot_ros2/          # ROS 2 simulator SDK
│   │   ├── arweave/        # Blockchain integration
│   │   └── core/           # Robot models, sensors, actuators
│   ├── GameAI/              # AI code agent for GDScript behaviors
│   └── ROSCoder/           # In-game IDE for ROS2 Python (rclpy) coding
├── docs/                   # Documentation
├── scenes/                 # Robot scene files
└── scripts/                # Main scripts
```

## Running the Simulator

### 1. Start the ROS 2 Bridge

```bash
export ROS_DOMAIN_ID=0
ros2 run godot_ros2_bridge godot_bridge_node
```

### 2. Open Godot

```bash
godot
```

### 3. In-Godot Controls

1. **Spawn TurtleBot4** — Choose DAE Meshes (real robot) or Primitives (Godot shapes)
2. **Connect Bridge** — Connects to the running `godot_ros2_bridge` node
3. **Play / Pause / Reset** — Control the simulation
4. **Generate Behavior** — Use AI to generate GDScript behaviors (via GameAI panel)
5. **ROS Coder** — Click "ROS Coder" button to open the in-game IDE for writing and deploying ROS2 Python code to your robot

## Troubleshooting

### Parse Errors in Editor

```bash
rm -rf .godot
godot -e --headless --quit
```

### ARIADNE Requires Node 22

```bash
node --version  # Should be v22+
```

### ROS Domain ID Mismatch

If you see "topic does not appear to be published yet", ensure `ROS_DOMAIN_ID` is set:

```bash
export ROS_DOMAIN_ID=0
```

## Next Steps

- [ROS 2 Simulation](simulation.md) — Learn about sensors, actuators, and robot models
- [Blockchain](blockchain.md) — Publish robot designs to Arweave
