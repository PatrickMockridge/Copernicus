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

Load a robot (`load arm6`) and manipulate joints from the viewport: the toolbar **Zero** button returns
all joints to 0°, and **Reach** runs inverse kinematics. Joints are also accessible programmatically via
`RobotViewerController` (`set_joint_rotation`, `zero_all_joints`). See the [features](features.md) and
[Arm6 case study](case-study-robot-arm.md).

---

## Understanding the Architecture

Copernicus is an operating system for robotics (see [`spec/00-kernel.md`](spec/00-kernel.md)):

- **Kernel** (always present): viewport, terminal, screen schema, AI assistant, wallet + RaaS.
- **Apps** (plugins): the robot library, marketplace, coordination, version control, RaaS.
- **Robots** (backends, via `tool <x>`): physics, IK, sensors, navigation, RL, industrial, ROS 2, Omniverse.
- **Economic layer**: blockchain + RaaS.

The kernel runs with nothing else enabled. See the [architecture](03-architecture.md) and
[design philosophy](design-philosophy.md) for the full picture.

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