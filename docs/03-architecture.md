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
│   ├── core/                        # Plugin integration system
│   │   ├── module.gd                # CopernicusModule — 5 static methods
│   │   └── module_registry.gd       # ModuleRegistry — self-registration autoload
│   │
│   ├── ui/                          # Shared UI components
│   │   ├── base_selector.gd          # Reusable selector (extended by domain selectors)
│   │   ├── copernicus_theme.gd       # Color system + factory methods
│   │   ├── toast.gd                  # Non-blocking notifications
│   │   ├── confirm_dialog.gd          # Modal confirmation
│   │   └── loading_overlay.gd         # Full-screen spinner
│   │
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
│   ├── main.tscn                   # main shell
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

### Backend Selection Flow (Registry-Based)

All domain selectors follow the same pattern — backends self-register, selectors auto-populate:

```
Backend._static_init()
    │
    ▼
ModuleRegistry.register("category", "id", script)
    │
    ▼
Selector opens ─→ ModuleRegistry.get_available("category")
    │                    │
    │                    ├── Calls get_module_name() on each script
    │                    ├── Calls is_available() on each script
    │                    └── Returns sorted: available first
    │
    ▼
BaseSelector populates radio list automatically
    │
    ▼
User clicks Apply ─→ Selector emits backend_selected("id")
    │
    ▼
ModuleRegistry.create("category", "id", config)
    │
    ▼
Returns configured instance (calls initialize() if defined)
```

### Physics Selection Flow

```
PhysicsSelector (extends BaseSelector, ~30 lines)
    │
    ▼ _get_category() returns "physics"
    │
ModuleRegistry.get_available("physics")
    │
    ├── GodotPhysicsBackend (available) ─→ Godot's Jolt engine
    ├── PyBulletBackend   (conditional) ─→ Bullet via Python subprocess
    └── GazeboBackend     (unavailable) ─→ hardcoded placeholder
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

## Plugin Integration System

Copernicus uses a zero-touch plugin architecture. Backends self-register; selectors auto-populate.

### Three-Part Architecture

```
CopernicusModule          ModuleRegistry           BaseSelector
(abstract base)           (autoload singleton)      (reusable UI)
      |                         |                        |
 Concrete backend -----> register("cat","id",script)     |
                              |                        |
                         get_available("cat") ------> populate radio list
                              |
                         create("cat","id",config) --> return instance
```

### CopernicusModule (scripts/core/module.gd)

Every backend extends `CopernicusModule` (via a domain abstract base) and implements 5 static methods:

```gdscript
static func get_module_name() -> String        # Display name
static func get_module_description() -> String  # Shown below name in selector
static func is_available() -> bool             # Real dependency check
static func get_requirements() -> String       # Install instructions
static func get_module_category() -> String    # Which selector category
```

### ModuleRegistry (scripts/core/module_registry.gd)

Autoload singleton. Backends self-register in `_static_init()`:

```gdscript
static func _static_init():
    ModuleRegistry.register("physics", "GazeboBackend", preload("res://scripts/physics/gazebo_backend.gd"))
```

That's it. The backend appears in the physics selector automatically.

### BaseSelector (scripts/ui/base_selector.gd)

Domain selectors extend `BaseSelector` and override 5-6 virtual methods. A full selector:

```gdscript
class_name PhysicsSelector
extends BaseSelector

signal backend_selected(backend_class: String)

func _get_title() -> String:          return "Select Physics Backend"
func _get_info_text() -> String:      return "Godot Native is fast..."
func _get_button_group_name() -> String: return "physics_backend"
func _get_category() -> String:       return "physics"

func _on_apply_pressed() -> void:
    backend_selected.emit(_selected_id)
    queue_free()

static func create_backend(id: String, config: Dictionary = {}) -> PhysicsBackend:
    return ModuleRegistry.create("physics", id, config)
```

~25 lines. The base class handles all UI construction, option population from the registry, default selection, cancel confirmation, and the apply button.

### Adding a New Backend

One file. That's it:

1. Create `scripts/physics/my_backend.gd` extending `PhysicsBackend`
2. Override the 5 static methods
3. Add `_static_init()` calling `ModuleRegistry.register()`
4. Restart Godot

See the [Plugin Developer Guide](development/plugin-guide.md) for a complete walkthrough with code examples.

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

- [Plugin Developer Guide](development/plugin-guide.md) — Build your own backend
- [Core Concepts](02-concepts.md) — Robots, sensors, control systems
- [Getting Started](01-getting-started.md) — Quick setup guide
- [Physics Backends](physics/backends.md) — Detailed backend comparison
- [Reinforcement Learning](rl/overview.md) — RL in Copernicus