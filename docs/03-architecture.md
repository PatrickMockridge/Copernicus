# Copernicus Architecture

This document describes the system architecture of Copernicus — how modules fit together
and how data flows through the system.

---

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        Copernicus                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌─────────────────────────────────────────────────────────┐    │
│   │                    Godot Engine (4.4+)                 │    │
│   │                                                          │    │
│   │   ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │    │
│   │   │  3D Scene    │ │   Physics    │ │      UI         │ │    │
│   │   │  (Mesh,      │ │   (Jolt,     │ │   (Control,     │ │    │
│   │   │   Lighting)  │ │   Vehicle)   │ │   Sliders)      │ │    │
│   │   └──────────────┘ └──────────────┘ └──────────────────┘ │    │
│   └─────────────────────────────────────────────────────────┘    │
│                              │                                    │
│   ┌──────────────────────────┼────────────────────────────────┐   │
│   │                    Core Modules                           │   │
│   │                          ▼                               │   │
│   │   ┌─────────────────────────────────────────────────────┐│   │
│   │   │  URDF Import │ Physics │ Sensors │ Control │ Nav  ││   │
│   │   └─────────────────────────────────────────────────────┘│   │
│   └──────────────────────────┼────────────────────────────────┘   │
│                              │                                    │
│   ┌──────────────────────────┼────────────────────────────────┐   │
│   │               Optional Integrations                      │   │
│   │                          ▼                               │   │
│   │   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │   │
│   │   │ godot_   │ │   GPU    │ │  AO     │ │   GameAI    │ │   │
│   │   │ ros2     │ │  Backend │ │Hyperobj │ │  (AI Code)  │ │   │
│   │   └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │   │
│   └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Core Principles

### 1. Godot-Native
Copernicus doesn't fight the engine — it uses what Godot does well:
- 3D rendering via `MeshInstance3D`, `DirectionalLight3D`
- Physics via Godot's Jolt engine (`RigidBody3D`, `VehicleBody3D`)
- Scene tree for robot hierarchy
- UI via `Control` nodes (sliders, panels, labels)

### 2. Modular by Design
Every component is swappable:
- Physics backends: Godot Native ↔ PyBullet ↔ PyBullet CUDA
- Navigation: A* Grid ↔ Nav2 (ROS 2)
- IK Solvers: CCD/FABRIK ↔ MoveIt (ROS 2)
- RL: DQN ↔ PPO ↔ SAC

### 3. Clear Scope
Copernicus is NOT:
- A physics research simulator (use Isaac Sim/Gazebo)
- A motion planner (use Nav2)
- An IK research solver (use MoveIt)

Copernicus IS:
- A fast 3D editor for visualizing robots
- A ROS 2 data source for sensor streaming
- A design tool that exports to full simulators

---

## Directory Structure

```
Copernicus/
├── scripts/                          # Core GDScript
│   ├── urdf_to_godot.gd             # URDF → Godot scene
│   ├── robot_viewer_controller.gd   # 3D viewer + orbit camera
│   ├── physics_demo.gd              # VehicleBody3D + differential drive
│   │
│   ├── control/                     # Control systems
│   │   └── pid_controller.gd       # PID closed-loop control
│   │
│   ├── gpu/                        # GPU acceleration
│   │   ├── gpu_backend.gd           # Abstract interface
│   │   ├── gpu_backend_selector.gd # Backend selection UI
│   │   ├── backends/               # Backend implementations
│   │   │   ├── pytorch_learner.gd  # DQN
│   │   │   ├── ppo_learner.gd      # PPO
│   │   │   ├── sac_learner.gd      # SAC
│   │   │   ├── cuda_physics.gd    # PyBullet CUDA
│   │   │   └── compute_raycast.gd  # GPU raycasting
│   │   ├── ui/
│   │   │   └── learning_panel.gd   # RL training UI
│   │   └── pytorch_learning_node.py # Python RL subprocess
│   │
│   ├── nav/                        # Navigation
│   │   ├── nav_planner.gd          # Abstract interface
│   │   ├── astar_grid_planner.gd   # A* path planner
│   │   ├── nav2_bridge.gd         # Nav2 ROS 2 bridge
│   │   └── occupancy_grid.gd      # Grid map utilities
│   │
│   ├── ik/                         # IK solvers
│   │   ├── ik_solver.gd            # Abstract interface
│   │   ├── analytical_ik_solver.gd  # CCD, FABRIK
│   │   └── moveit_ik_bridge.gd     # MoveIt ROS 2 bridge
│   │
│   ├── physics/                    # Physics backends
│   │   ├── physics_backend.gd      # Abstract interface
│   │   ├── godot_physics_backend.gd
│   │   ├── pybullet_backend.gd     # PyBullet bridge
│   │   └── pybullet_bridge.py      # Python side
│   │
│   └── turtle/                     # TurtleBot demo
│       ├── turtle_controller.gd
│       └── turtle_navigation.gd
│
├── scenes/                          # Godot scenes
│   ├── turtle_demo.tscn
│   ├── robot_viewer.tscn
│   ├── physics_demo.tscn
│   ├── main.tscn                   # AI code generation
│   ├── joint_control_panel.tscn
│   ├── gpu/
│   │   ├── gpu_backend_selector.tscn
│   │   └── ui/
│   │       └── learning_panel.tscn
│   └── gpu/                        # GPU scenes (note: path overlap intentional)
│
├── addons/                          # Optional plugins
│   ├── demo_framework/             # Reusable demo infrastructure
│   │   ├── demo_framework.gd        # EditorPlugin entry
│   │   ├── demo_environment.gd     # Camera, lighting, ground, obstacles
│   │   ├── demo_robot.gd           # Robot builder (CharacterBody3D)
│   │   └── plugin.cfg
│   │
│   ├── godot_ros2/                # ROS 2 bridge
│   │   ├── godot_ros2.gd          # Main entry
│   │   ├── core/
│   │   │   ├── ros2_node.gd
│   │   │   ├── robot_model.gd
│   │   │   ├── joint_controller.gd
│   │   │   ├── differential_drive.gd
│   │   │   └── ground_truth.gd
│   │   ├── ros2/
│   │   │   ├── publisher.gd
│   │   │   ├── subscription.gd
│   │   │   └── ros2_bridge_client.gd
│   │   └── sensors/              # Active sensor implementations
│   │       ├── sensor.gd
│   │       ├── lidar_sensor.gd
│   │       ├── camera_sensor.gd
│   │       ├── imu_sensor.gd
│   │       └── gps_sensor.gd
│   │
│   ├── gpu_sensors/               # GPU-accelerated sensors (RTX LIDAR, path tracing)
│   │
│   ├── hyperobject/              # AO Hyperobjects SDK
│   │   ├── sdk/
│   │   │   ├── hyperobjects.gd
│   │   │   ├── storage.gd
│   │   │   └── network.gd
│   │   └── marketplace/
│   │
│   ├── industrial/                 # Industrial robot backends (self-contained)
│   │   ├── industrial.gd          # Plugin entry
│   │   ├── industrial_selector.gd # UI selector panel
│   │   ├── core/
│   │   │   └── ...               # Backend interface, handlers
│   │   └── backends/
│   │       ├── mock_industrial.gd
│   │       ├── motoman_bridge.gd # MOTOMAN INRC4 bridge
│   │       └── opcua_bridge.gd
│   │
│   ├── primitives/               # Crypto, HTTP, wallet primitives
│   └── omni/                     # Omniverse USD integration
│
├── docs/                           # Documentation
│   ├── 01-getting-started.md
│   ├── 02-concepts.md
│   ├── 03-architecture.md
│   ├── robots/
│   ├── physics/
│   ├── sensors/
│   ├── rl/
│   ├── navigation/
│   ├── ros2/
│   ├── blockchain/
│   └── ai/
│
└── README.md
```

---

## Module Interactions

### URDF Import Flow

```
URDF File (XML)
    │
    ▼
urdf_to_godot.gd (XMLParser)
    │
    ├─ Parse <link> → MeshInstance3D + CollisionShape3D
    ├─ Parse <joint> → PinJoint3D / SliderJoint3D
    ├─ Parse <material> → StandardMaterial3D
    └─ Parse <origin> → Transform3D
    │
    ▼
Godot Scene Tree
    │
    ▼
RobotViewer displays it
```

### Physics Selection Flow

```
PhysicsSelector (UI)
    │
    ▼ select backend
    │
    ├── Godot Native ─→ godot_physics_backend.gd
    │                        └── Uses VehicleBody3D, RigidBody3D
    │
    ├── PyBullet ─→ pybullet_backend.gd
    │                    └── Communicates with pybullet_bridge.py
    │
    └── PyBullet CUDA ─→ cuda_physics.gd
                            └── GPU-accelerated physics via CUDA
```

### RL Training Flow

```
LearningPanel (UI)
    │
    ▼ select algorithm
    │
    ├── DQN ─→ pytorch_learner.gd ─→ pytorch_learning_node.py
    │
    ├── PPO ─→ ppo_learner.gd ─→ pytorch_learning_node.py
    │
    └── SAC ─→ sac_learner.gd ─→ pytorch_learning_node.py
                │
                ▼
        PyTorch on CUDA (or CPU fallback)
                │
                ▼
        Model checkpoints saved to disk
```

---

## Data Flow Examples

### Navigation Data Flow

```
User clicks on ground
    │
    ▼
A* Grid Planner calculates path
    │
    ▼
Differential Drive converts path to wheel velocities
    │
    ▼
VehicleBody3D applies forces
    │
    ▼
Robot moves, odometry updates
    │
    ▼
Ground truth publishes to ROS 2 (/robot/odom)
```

### Sensor Data Flow

```
Physics world
    │
    ▼
LIDARSensor rays intersect
    │
    ▼
Ranges computed with noise applied
    │
    ▼
LaserScan message created
    │
    ▼
Publisher sends via ROS 2 bridge
    │
    ▼
ROS 2 receives /robot/scan
```

---

## Adding New Modules

### 1. Create Module Directory

```
scripts/my_module/
├── my_module.gd           # class_name MyModule
├── my_backend.gd         # Optional backend
└── plugin.cfg            # If Godot plugin
```

### 2. Implement Abstract Interface

```gdscript
class_name MyModule
extends Node

static func is_available() -> bool:
    return true

func initialize(config: Dictionary) -> bool:
    return true

func shutdown() -> void:
    pass
```

### 3. Register in Selector

```gdscript
# In my_module_selector.gd
_add_module_option("MyModule", "My Module", "Description", MyModule.is_available())
```

### 4. Document

```markdown
## My Module

Explain what it does, how to use it, and example code.
```

---

## Signal Architecture

Key signals for module communication:

```gdscript
# PhysicsBackend
signal backend_initialized(success: bool)
signal backend_error(message: String)
signal simulation_stepped(delta: float)

# GPUBackend
signal backend_ready()
signal backend_error(message: String)
signal training_step(loss: float)
signal episode_complete(reward: float)

# Navigation
signal path_planned(path: Array)
signal goal_reached()

# IK Solver
signal solving_started()
signal solving_finished(success: bool, iterations: int)
```

---

## Further Reading

- [Core Concepts](02-concepts.md) — Robots, sensors, control systems
- [Getting Started](01-getting-started.md) — Quick setup guide
- [Physics Backends](physics/backends.md) — Detailed backend comparison
- [Reinforcement Learning](rl/overview.md) — RL in Copernicus