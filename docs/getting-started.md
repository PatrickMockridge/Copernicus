# Getting Started with Copernicus

Welcome to **Copernicus**, an open-source robot design interface built on Godot 4. This guide will help you set up Copernicus and create your first robot design.

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Godot | 4.4+ | |
| ROS 2 | Jazzy or Humble | Optional for sensor streaming |
| Node.js | 22+ | For blockchain features |
| Git | Any recent | |

## Installation

### 1. Clone the Repository

```bash
git clone https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface.git
cd Godot_4__Robotic_Design_Interface
```

### 2. Build ROS 2 Bridge (Optional)

Required only if you want sensor streaming to/from ROS 2.

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
Copernicus/
├── scripts/                 # Core GDScript modules
│   ├── urdf_to_godot.gd    # URDF → Godot scene tree
│   ├── robot_viewer_controller.gd
│   ├── physics_demo.gd     # VehicleBody3D demo
│   ├── joint_panel.gd      # Joint slider UI
│   ├── lidar_debug.gd      # LIDAR visualization
│   ├── camera_debug.gd     # Camera frustum
│   └── imu_debug.gd       # IMU axes
├── scenes/                 # Godot scene files (.tscn)
│   ├── robot_viewer.tscn   # 3D robot viewer
│   ├── joint_control_panel.tscn
│   └── physics_demo.tscn   # VehicleBody3D demo
├── addons/
│   ├── godot_ros2/        # ROS 2 integration
│   ├── hyperobject/        # AO Hyperobjects for tradeable assets
│   └── ...
├── docs/                   # Documentation
└── README.md               # Project overview
```

## Running Copernicus

### Robot Viewer

View and interact with robot models:

```bash
godot scenes/robot_viewer.tscn
```

Features:
- Orbit camera around robot (right-click drag)
- Zoom (mouse wheel)
- Joint slider control panel

### Physics Demo

Drive a differential robot with keyboard:

```bash
godot scenes/physics_demo.tscn
```

Controls:
- **W/S** — Forward/Reverse
- **A/D** — Left/Right steering

### Main Interface

```bash
godot scenes/main.tscn
```

Full interface with AI code generation, ROS Coder IDE, and blockchain publishing.

## In-Godot Controls

1. **Robot Viewer** — Orbit camera around robot
2. **Joint Control Panel** — Use sliders to manipulate joints
3. **Physics Demo** — WASD to drive, applies differential drive physics
4. **AI Code Agent** — Generate GDScript behaviors (via GameAI panel)
5. **ROS Coder** — In-game IDE for writing and deploying ROS2 Python code

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

- [ROS 2 Simulation](simulation.md) — Learn about sensors, actuators, and physics
- [Philosophy](philosophy.md) — Understand the open-source vision
- [Architecture](architecture.md) — System design overview
- [Blockchain](blockchain.md) — Publish robot designs to Arweave
