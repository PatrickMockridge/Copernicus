# Getting Started with Copernicus

This guide walks you through setting up Copernicus and running your first robot simulation.

---

## Installation

### 1. Install Godot 4.4+

Download from [godotengine.org](https://godotengine.org/download).

Godot 4.4 or later is required for full feature support.

### 2. Clone the Repository

```bash
git clone https://github.com/PatrickMockridge/Copernicus.git
cd Copernicus
```

### 3. (Optional) Install Python Dependencies

For PyBullet physics and PyTorch ML:

```bash
pip install pybullet torch
```

### 4. (Optional) Install ROS 2

For full ROS 2 integration:

```bash
# Ubuntu 22.04+ / Debian
sudo apt install ros-jazzy-ros2-cli ros-jazzy-demo-nodes-py

# Or use Humble
source /opt/ros/humble/setup.bash
```

### 5. Verify Installation

```bash
godot --headless --quit
```

If you see "Godot Engine v4.4" without errors, you're ready.

---

## Running Demos

### Turtle Demo (No ROS 2 Required)

The fastest way to see Copernicus in action:

```bash
godot scenes/turtle_demo.tscn
```

**What you'll see:**
1. Green TurtleBot in a walled arena
2. Click on the ground to set a navigation goal
3. Robot plans a path using A* and navigates autonomously

**Controls:**
- Left-click → Set goal position
- W/S → Forward/backward
- A/D → Turn left/right

### Robot Viewer

Load and inspect URDF robot models:

```bash
godot scenes/robot_viewer.tscn
```

Use orbit camera (left-click drag) to inspect the robot.

### Physics Demo

Differential drive with VehicleBody3D:

```bash
godot scenes/physics_demo.tscn
```

**Controls:**
- Arrow keys → Drive the robot

---

## Loading Your Own Robot

### URDF Import

Place your robot's URDF file in the project, then:

```gdscript
var urdf_importer = URDFToGodot.new()
var robot_root = urdf_importer.import_file("path/to/robot.urdf")
add_child(robot_root)
```

The importer creates:
- `MeshInstance3D` for visual geometry
- `CollisionShape3D` for physics
- `PinJoint3D`/`SliderJoint3D` for joints

### Interactive Joint Control

Use the joint panel to manipulate joints:

```bash
godot scenes/joint_control_panel.tscn
```

Select a joint and use the slider to move it.

---

## Understanding the Architecture

Copernicus uses a layered architecture:

```
┌────────────────────────────────────────────┐
│              Your Robot Code               │
├────────────────────────────────────────────┤
│         Copernicus Core Modules            │
│  (URDF import, joint control, physics)     │
├────────────────────────────────────────────┤
│            Godot Engine                     │
│   (3D rendering, physics, scene tree)      │
└────────────────────────────────────────────┘

         Optional Integrations
┌────────────────┐ ┌────────────────┐ ┌────────────┐
│   godot_ros2   │ │  GPU Backend   │ │  Hyperobject│
│   (ROS 2)      │ │  (PyTorch)     │ │  (AO)      │
└────────────────┘ └────────────────┘ └────────────┘
```

---

## GPU Acceleration (Optional)

For reinforcement learning and GPU physics:

### CUDA Setup

```bash
# Check CUDA availability
python3 -c "import torch; print(torch.cuda.is_available())"
```

### PyTorch Q-Learning

```bash
# Train a robot policy
godot scenes/gpu/gpu_backend_selector.tscn
```

Select "PyTorch Q-Learning" as the backend.

### RL Algorithms Available

| Algorithm | Use Case |
|-----------|----------|
| DQN | Discrete action spaces (go left/right/up/down) |
| PPO | Continuous control (torque outputs) |
| SAC | Exploration-heavy tasks |

---

## Next Steps

### Explore the Demos
- `turtle_demo.tscn` — Navigation
- `robot_viewer.tscn` — URDF inspection
- `physics_demo.tscn` — Vehicle dynamics
- `joint_control_panel.tscn` — Joint manipulation

### Read the Core Concepts
- [Core Concepts](02-concepts.md) — Understand robots, physics, sensors
- [Architecture](03-architecture.md) — System design

### Extend Copernicus
- Fork the repo and create a module
- Add new physics backends or RL algorithms
- Contribute via PR

---

## Troubleshooting

### "Could not find type" errors

Run from the project root:
```bash
cd /path/to/Godot_4__Robotic_Design_Interface
godot scenes/turtle_demo.tscn
```

### Godot crashes on startup

Try headless mode:
```bash
godot --headless --quit
```

### Python dependencies missing

```bash
pip install pybullet torch
```

---

## Getting Help

- [Documentation index](README.md) — All docs
- [Architecture overview](03-architecture.md) — System design
- [Physics backends](physics/backends.md) — Simulation options
- [Issue tracker](https://github.com/PatrickMockridge/Copernicus/issues) — Report bugs