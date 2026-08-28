# Copernicus
## Robot Design Interface for Godot 4

**Copernicus** is an open-source robotics design tool built on [Godot 4](https://godotengine.org/).
It combines 3D robot visualization, physics simulation, reinforcement learning, and ROS 2 integration
in a modular, forkable architecture.

Named after Nicolaus Copernicus who placed the Sun at the center of the solar system, Copernicus
places the **open-source community** at the center of robot development.

> **Repository:** [github.com/PatrickMockridge/Copernicus](https://github.com/PatrickMockridge/Copernicus) — the canonical and only source for Copernicus.

---

## Quick Start

```bash
# Navigation demo (no ROS 2 required)
godot scenes/turtle_demo.tscn

# Robot visualization with URDF import
godot scenes/robot_viewer.tscn

# Physics demo with differential drive
godot scenes/physics_demo.tscn

# Joint control panel
godot scenes/joint_control_panel.tscn

# GPU backend selector (Isaac Gym, RTX sensors)
godot scenes/gpu/gpu_backend_selector.tscn

# Navigation planner selector (A*, Nav2)
godot scenes/nav_selector.tscn

# IK solver selector (CCD, FABRIK, MoveIt)
godot scenes/ik_selector.tscn

# Industrial robot selector (MOTOMAN, ABB, OPC-UA)
godot scenes/industrial_selector.tscn

# Physics backend selector
godot scenes/physics_selector.tscn

# Robotics-as-a-service demos (RChain actuation + fees; launcher)
godot scenes/rchain/raas_launcher.tscn
```

---

## Feature Overview

### Robot Design
- **URDF Import** — Load robot models from URDF files into Godot scene tree
- **Interactive Joint Control** — Real-time sliders for joint manipulation
- **MJCF Support** — MuJoCo model format import

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
| Isaac Gym | GPU | Multi-robot training |

**Isaac Gym Tasks:** shadow_hand, anymal, allegro_hand, cartpole, ball_balance, quadcopter, franka_cube, kortex_robot

### Sensor Simulation
- **RTX LIDAR** — GPU ray tracing with Velodyne VLP-16/HDL-32E/HDL-64E, Ouster OS1-64
- **RTX Camera** — GPU path tracing with Intel RealSense D455, Azure Kinect DK, ZED 2i
- **Sensor Fusion** — Kalman filtering for LIDAR + camera + IMU + GPS
- **IMU** — Bias drift, random walk noise models

### ROS 2 Integration
- **TCP/UDP Bridge** — Sensor streaming and control
- **Native rclpy** — Direct ROS 2 integration with DDS transport
- **Isaac ROS Messages** — Nav2 and MoveIt integration
- Publishes: `/robot/odom`, `/robot/scan`, `/robot/image_raw`, `/robot/imu`
- Subscribes to: `/robot/cmd_vel`

### Navigation & Planning
| Component | Options |
|-----------|---------|
| Navigation | A* Grid (GDScript), Nav2 (ROS 2) |
| IK Solver | CCD, FABRIK (analytical), MoveIt (ROS 2) |

### Industrial Robots
| Robot | Protocol | Features |
|-------|----------|----------|
| MOTOMAN | INRC4 | Cartesian/joint moves, trajectory streaming |
| ABB | RAPID over TCP | FlexPendant integration |
| OPC-UA | Standard | Digital I/O, registers |
| Fanuc | Karl | Roboguide support |
| UR | urscript | ROS 2 driver integration |

### Omniverse Integration
- **USD Pipeline** — Export to Omniverse Kit format
- **Digital Twin Sync** — Real-time sync with Omniverse
- **Replicator** — Synthetic data generation for training

### Blockchain & Marketplace
- **ARIADNE** — Git-on-Arweave for permanent robot design storage
- **AO Hyperobjects** — Trade robot designs as digital assets
- **RChain Coordination** — On-chain coordination via RChain/RNode: capabilities, jobs, and event channels (the marketplace becomes one coordination primitive)
- **Robotics-as-a-Service** — RChain-driven robot actuation with work-metered fees

---

## Architecture

```
Copernicus
├── scripts/
│   ├── core/                         # Plugin integration system
│   │   ├── module.gd                 # CopernicusModule base class
│   │   └── module_registry.gd        # Self-registration autoload
│   ├── ui/                           # Shared UI components
│   │   ├── base_selector.gd           # Reusable selector UI
│   │   ├── copernicus_theme.gd        # Color/font/helper system
│   │   ├── toast.gd                  # Non-blocking notifications
│   │   ├── confirm_dialog.gd          # Modal confirmation dialog
│   │   └── loading_overlay.gd         # Full-screen spinner
│   ├── urdf_to_godot.gd           # URDF parser
│   ├── robot_viewer_controller.gd
│   ├── physics_demo.gd            # VehicleBody3D + differential drive
│   ├── control/
│   │   └── pid_controller.gd      # PID closed-loop control
│   ├── coordination/              # RChain coordination layer
│   │   ├── coordination_core.gd   # Abstract coordination interface
│   │   ├── rchain_coordination.gd # RChain backend (capabilities, jobs)
│   │   └── mock_coordination.gd   # Offline mock
│   ├── rchain/                    # RChain SDK
│   │   ├── rchain_wallet.gd       # Key lifecycle + deploy signing
│   │   ├── rnode_client.gd        # RNode HTTP client
│   │   ├── rholang_sdk.gd         # Rholang term builder
│   │   └── signal_bridge.gd       # Signal <-> channel adapter
│   ├── gpu/
│   │   ├── backends/              # GPU acceleration backends
│   │   │   ├── pytorch_learner.gd      # DQN
│   │   │   ├── ppo_learner.gd         # PPO
│   │   │   ├── sac_learner.gd          # SAC
│   │   │   ├── isaac_gym_task.gd       # Isaac Gym RL
│   │   │   ├── isaac_gym_replicator.gd # Omniverse Replicator
│   │   │   ├── multi_robot_trainer.gd   # Multi-robot coordinator
│   │   │   ├── compute_raycast.gd      # GPU raycasting
│   │   │   └── rtx_camera.py           # GPU path tracing
│   │   └── pytorch_learning_node.py    # Python RL subprocess
│   ├── nav/                        # Navigation planners
│   ├── ik/                         # IK solvers
│   └── physics/                    # Physics backends
├── scenes/                          # Godot scene files
├── addons/
│   ├── godot_ros2/                 # ROS 2 TCP/UDP bridge
│   ├── ros2_native/               # Native rclpy integration
│   ├── hyperobject/                # AO Hyperobjects SDK
│   ├── rchain/                     # RChain crypto GDExtension + rholang contracts
│   ├── gpu_sensors/                # RTX LIDAR, camera, fusion
│   ├── industrial/                 # Industrial robot backends
│   └── omni/                       # Omniverse USD integration
└── docs/                           # Documentation
```

### Plugin System

Copernicus uses a zero-touch plugin architecture built on three components:
- **CopernicusModule** — 5 static methods every backend implements (`get_module_name`, `get_module_description`, `is_available`, `get_requirements`, `get_module_category`)
- **ModuleRegistry** — autoload singleton where backends self-register via `_static_init()`; selectors query `get_available(category)` to populate their UI automatically
- **BaseSelector** — reusable selector UI that domain selectors extend by overriding 5-6 virtual methods (~25 lines per selector, down from ~190)

Adding a new backend means writing one class. No wiring up selectors, no match statements, no touching 3-4 files. See the [Plugin Developer Guide](docs/development/plugin-guide.md) for a step-by-step walkthrough.

### Design Philosophy

Copernicus aims for **Pareto efficiency** — maximum functionality with minimum complexity. **Composability first:** modules must be swappable without modifying caller code. The more complex and entangled a dependency, the more likely it belongs as an external plugin rather than in this repository. See the full [Design Philosophy](docs/design-philosophy.md) for details.

---

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Godot | 4.4+ | Headless mode supported |
| Rust | 1.95+ | For the RChain crypto GDExtension |
| RNode | latest | Optional, for on-chain coordination |
| Python | 3.10+ | For PyBullet/PyTorch backends |
| ROS 2 | Jazzy/Humble | Optional |
| CUDA | 11.8+ | For GPU acceleration |
| Isaac Gym | Latest | Optional, for GPU RL training |
| Omniverse | Latest | Optional, for USD pipeline |

---

## Documentation

### Getting Started
- [Quick Start](docs/quick-start.md) — Run your first demo
- [Getting Started Guide](docs/01-getting-started.md) — Detailed setup
- [Core Concepts](docs/02-concepts.md) — Robots, physics, sensors, control
- [Design Philosophy](docs/design-philosophy.md) — Pareto efficiency, modularity

### Feature Guides
- [URDF Import](docs/robots/urdf-import.md) — Load robot models from URDF
- [Robot Control](docs/robots/control.md) — Joint control, PID, trajectories
- [Composite Workspace](docs/README.md#quick-commands) — Unified 3D viewer + joint panel + toolbar
- [Physics Backends](docs/physics/backends.md) — Godot vs PyBullet vs CUDA
- [Sensors Overview](docs/sensors/overview.md) — LIDAR, camera, IMU
- [Sensor Noise Models](docs/sensors/noise-models.md) — Realistic noise
- [Reinforcement Learning](docs/rl/overview.md) — DQN, PPO, SAC
- [Isaac Gym RL Tasks](docs/rl/isaac-gym.md) — GPU training with Isaac Gym
- [RTX Sensors](docs/gpu/rtx_sensors.md) — GPU sensors

### Development
- [Plugin Developer Guide](docs/development/plugin-guide.md) — Build your own backend

### Reference
- [Architecture](docs/03-architecture.md) — System design
- [Navigation Planners](docs/navigation/planners.md) — A* and Nav2
- [IK Solvers](docs/navigation/ik-solvers.md) — CCD, FABRIK, MoveIt
- [ROS 2 Bridge](docs/ros2/bridge.md) — TCP/UDP setup
- [ROS2 Native](docs/ros2_native/overview.md) — Native rclpy integration
- [Industrial Robots](docs/industrial/overview.md) — MOTOMAN, ABB, OPC-UA
- [Omniverse](docs/omni/overview.md) — USD pipeline and digital twin
- [Marketplace](docs/blockchain/marketplace.md) — Trading robot designs
- [RChain Coordination](docs/rchain/design.md) — On-chain coordination via RChain/RNode

---

## License

Copernicus is distributed under [GNU AGPLv3](LICENSE).

Open source doesn't mean free for all uses — if you distribute derivative works,
you must release your source under AGPL as well.
