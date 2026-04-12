# Copernicus Documentation

> *"In the middle of difficulty lies opportunity."* — Albert Einstein

Welcome to **Copernicus**, an open-source robot design interface built on [Godot 4](https://godotengine.org/).

---

## Getting Started

### [Quick Start Guide](quick-start.md)
Run your first demo with the TurtleBot simulation.

### [Getting Started Guide](01-getting-started.md)
Detailed setup: Godot installation, Python dependencies, ROS 2.

### [Core Concepts](02-concepts.md)
Understand robots, physics engines, sensors, control systems, and RL.

### [Architecture](03-architecture.md)
System design, module relationships, and data flow.

---

## Feature Guides

### [URDF Import](robots/urdf-import.md)
Load robot models from URDF files into Godot.

### [Robot Control](robots/control.md)
Joint control, differential drive, PID controllers, trajectory execution.

### [Physics Backends](physics/backends.md)
Godot Native vs PyBullet vs PyBullet CUDA comparison.

### [Sensors Overview](sensors/overview.md)
LIDAR, camera, IMU, GPS, contact sensor simulation.

### [Sensor Noise Models](sensors/noise-models.md)
Realistic sensor modeling: range noise, lens distortion, IMU drift.

### [Reinforcement Learning](rl/overview.md)
DQN, PPO, and SAC algorithms for robot skill acquisition.

### [DQN](rl/dqn.md)
Deep Q-Network for discrete action spaces.

### [PPO and SAC](rl/ppo-sac.md)
Policy gradient methods for continuous control.

### [Navigation Planners](navigation/planners.md)
A* Grid and Nav2 for robot navigation.

### [IK Solvers](navigation/ik-solvers.md)
CCD, FABRIK, and MoveIt for inverse kinematics.

---

## Reference

### [ROS 2 Bridge](ros2/bridge.md)
TCP/UDP bridge setup for sensor streaming and control.

### [AI Code Generation](../ai-codegen.md)
AI behavior generation + ROS Coder IDE.

### [Marketplace](../blockchain/marketplace.md)
Trade robot designs via AO Hyperobjects.

---

## Directory Structure

```
docs/
├── 01-getting-started.md    # Setup and first demo
├── 02-concepts.md           # Core concepts
├── 03-architecture.md         # System design
├── robots/                   # Robot-related docs
│   ├── urdf-import.md       # URDF loading
│   └── control.md           # Joint control, PID
├── physics/                  # Physics docs
│   └── backends.md          # Backend comparison
├── sensors/                  # Sensor docs
│   ├── overview.md          # LIDAR, camera, IMU
│   └── noise-models.md     # Realistic noise
├── rl/                       # Reinforcement learning
│   ├── overview.md         # RL introduction
│   ├── dqn.md             # DQN algorithm
│   └── ppo-sac.md         # PPO and SAC
├── navigation/               # Navigation docs
│   ├── planners.md        # A*, Nav2
│   └── ik-solvers.md      # CCD, FABRIK, MoveIt
├── ros2/                    # ROS 2 integration
└── blockchain/              # Marketplace docs
```

---

## Quick Commands

```bash
# Run demos
godot scenes/turtle_demo.tscn      # Navigation (no ROS 2)
godot scenes/robot_viewer.tscn      # URDF visualization
godot scenes/physics_demo.tscn     # Vehicle dynamics

# GPU learning
godot scenes/gpu/gpu_backend_selector.tscn

# Selection panels
godot scenes/physics_selector.tscn
godot scenes/nav_selector.tscn
godot scenes/ik_selector.tscn
```

---

## Core Principles

### Godot-Native
Copernicus uses Godot's built-in capabilities: 3D rendering, physics (Jolt),
scene tree management, and UI system.

### Modular by Design
Every component is swappable: physics backends, navigation planners,
IK solvers, and RL algorithms.

### Clear Scope
Copernicus is a fast 3D editor for robot visualization and design.
For research-grade simulation, use Isaac Sim or Gazebo.
Copernicus exports to those simulators.

---

**Ready to start?** Read the [Quick Start Guide](quick-start.md) or jump to [Core Concepts](02-concepts.md).