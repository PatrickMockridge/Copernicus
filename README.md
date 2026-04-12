# Copernicus
## Robot Design Interface for Godot 4

**Copernicus** is an open-source robotics design tool built on [Godot 4](https://godotengine.org/).
It combines 3D robot visualization, physics simulation, reinforcement learning, and ROS 2 integration
in a modular, forkable architecture.

Named after Nicolaus Copernicus who placed the Sun at the center of the solar system, Copernicus
places the **open-source community** at the center of robot development.

---

## Quick Start

```bash
# Navigation demo (no ROS 2 required)
godot scenes/turtle_demo.tscn

# Robot visualization with URDF import
godot scenes/robot_viewer.tscn

# Physics demo with differential drive
godot scenes/physics_demo.tscn

# AI code generation panel
godot scenes/main.tscn

# Joint control panel
godot scenes/joint_control_panel.tscn
```

---

## Feature Overview

### Robot Design
- **URDF Import** — Load robot models from URDF files into Godot scene tree
- **Interactive Joint Control** — Real-time sliders for joint manipulation
- **MJCF Support** — MuJoCo model format import (planned)

### Physics Simulation
| Backend | Speed | Accuracy | Use Case |
|---------|-------|---------|----------|
| Godot Native | Fast | Game-grade | Design iteration |
| PyBullet | Medium | Research-grade | Manipulation |
| PyBullet CUDA | GPU | Research-grade | High-fidelity simulation |

### Reinforcement Learning
| Algorithm | Type | Best For |
|-----------|------|----------|
| DQN | Value-based | Discrete actions |
| PPO | Policy gradient | Continuous control |
| SAC | Off-policy | Exploration tasks |

### Sensor Simulation
- **LIDAR** — 360° scan with beam divergence and range noise
- **Camera** — Lens distortion (Brown-Conrady model), salt-pepper noise
- **IMU** — Bias drift, random walk noise models

### ROS 2 Integration
- TCP/UDP bridge for sensor streaming and control
- Publishes: `/robot/odom`, `/robot/scan`, `/robot/image_raw`, `/robot/imu`
- Subscribes to: `/robot/cmd_vel`

### Navigation & Planning
| Component | Options |
|-----------|---------|
| Navigation | A* Grid (GDScript), Nav2 (ROS 2) |
| IK Solver | CCD, FABRIK (analytical), MoveIt (ROS 2) |

### Blockchain & Marketplace
- **ARIADNE** — Git-on-Arweave for permanent robot design storage
- **AO Hyperobjects** — Trade robot designs as digital assets

---

## Architecture

```
Copernicus
├── scripts/                    # Core GDScript modules
│   ├── urdf_to_godot.gd        # URDF parser
│   ├── robot_viewer_controller.gd
│   ├── physics_demo.gd         # VehicleBody3D + differential drive
│   ├── control/
│   │   └── pid_controller.gd   # PID closed-loop control
│   ├── gpu/
│   │   ├── backends/           # GPU acceleration backends
│   │   │   ├── pytorch_learner.gd  # DQN
│   │   │   ├── ppo_learner.gd       # PPO
│   │   │   └── sac_learner.gd        # SAC
│   │   └── pytorch_learning_node.py # Python RL subprocess
│   ├── nav/                    # Navigation planners
│   ├── ik/                     # IK solvers
│   └── physics/                # Physics backends
├── scenes/                     # Godot scene files
├── addons/
│   ├── godot_ros2/            # ROS 2 bridge
│   ├── hyperobject/           # AO Hyperobjects SDK
│   └── GameAI/               # AI code generation
└── docs/                      # Documentation
```

---

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Godot | 4.4+ | Headless mode supported |
| Python | 3.10+ | For PyBullet/PyTorch backends |
| ROS 2 | Jazzy/Humble | Optional |
| CUDA | 11.8+ | For GPU acceleration |

---

## Documentation

### Getting Started
- [Quick Start](docs/quick-start.md) — Run your first demo
- [Getting Started Guide](docs/01-getting-started.md) — Detailed setup
- [Core Concepts](docs/02-concepts.md) — Robots, physics, sensors, control

### Feature Guides
- [Physics Backends](docs/physics/backends.md) — Godot vs PyBullet vs CUDA
- [Sensors](docs/sensors/overview.md) — LIDAR, camera, IMU
- [Reinforcement Learning](docs/rl/overview.md) — DQN, PPO, SAC

### Reference
- [Architecture](docs/03-architecture.md) — System design
- [Navigation](docs/navigation/planners.md) — A* and Nav2
- [IK Solvers](docs/navigation/ik-solvers.md) — CCD, FABRIK, MoveIt
- [ROS 2 Bridge](docs/ros2/bridge.md) — TCP/UDP setup
- [Marketplace](docs/marketplace.md) — Trading robot designs

---

## License

Copernicus is distributed under [GNU AGPLv3](LICENSE).

Open source doesn't mean free for all uses — if you distribute derivative works,
you must release your source under AGPL as well.