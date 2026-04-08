# Copernicus Architecture

## Overview

Copernicus is built on a simple principle: **leverage what Godot does well**. Rather than fighting the engine, Copernicus embraces Godot's native capabilities for 3D rendering, physics, and scene management.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Copernicus                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     Godot Engine (4.4+)                       │  │
│  │                                                                │  │
│  │   ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │  │
│  │   │  3D Scene   │ │   Physics   │ │       UI System        │ │  │
│  │   │             │ │             │ │                         │ │  │
│  │   │ • Mesh      │ │ • Vehicle   │ │ • Joint sliders        │ │  │
│  │   │ • Lighting  │ │   Body3D    │ │ • Control panels       │ │  │
│  │   │ • Camera    │ │ • Joints    │ │ • Labels               │ │  │
│  │   └─────────────┘ └─────────────┘ └─────────────────────────┘ │  │
│  │                                                                │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│  ┌───────────────────────────┼───────────────────────────────────┐  │
│  │                           ▼                                    │  │
│  │   ┌─────────────────────────────────────────────────────────┐   │  │
│  │   │              Copernicus Core Modules                   │   │  │
│  │   │                                                           │   │  │
│  │   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │   │  │
│  │   │  │ URDF     │ │ Physics  │ │ Joint    │ │ Sensor   │   │   │  │
│  │   │  │ Import   │ │ Demo     │ │ Control  │ │ Debug    │   │   │  │
│  │   │  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │   │  │
│  │   │                                                           │   │  │
│  │   └─────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                              │                                        │
│  ┌───────────────────────────┼────────────────────────────────────┐    │
│  │                    Optional Layers                            │    │
│  │                           ▼                                    │    │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐    │    │
│  │   │  godot_ros2  │  │  AI Layer    │  │  Blockchain     │    │    │
│  │   │  (ROS2)      │  │  (GameAI)    │  │  (AO/Arweave)  │    │    │
│  │   └──────────────┘  └──────────────┘  └──────────────────┘    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Godot-Native Core

### Why Native Nodes?

Copernicus uses Godot's built-in nodes instead of custom classes:

| Purpose | Godot Node | Why |
|---------|-----------|-----|
| Robot meshes | `MeshInstance3D` | Optimized 3D rendering |
| Collision | `CollisionShape3D` | Native physics integration |
| Wheels | `VehicleBody3D` | Built-in vehicle physics! |
| Joints | `PinJoint3D`, `SliderJoint3D` | Godot handles the math |
| Kinematics | `Skeleton3D` | Skeleton system for chains |
| Sensors | `RayCast3D`, `Area3D` | Native raycasting |

### Key Scripts

| Script | Purpose |
|--------|---------|
| `urdf_to_godot.gd` | Parse URDF → Godot scene tree |
| `robot_viewer_controller.gd` | 3D viewer + orbit camera |
| `physics_demo.gd` | VehicleBody3D differential drive |
| `joint_panel.gd` | HSlider-based joint control |
| `lidar_debug.gd` | LIDAR ray visualization |
| `camera_debug.gd` | Camera frustum display |
| `imu_debug.gd` | IMU axes visualization |

---

## Module Layers

### Layer 1: Godot Engine
The foundation — Godot 4.4+ provides:
- 3D rendering engine
- Physics simulation (Jolt/Bullet)
- Scene tree management
- UI system (Control nodes)
- GDScript runtime

### Layer 2: Copernicus Core
Essential modules built on Godot:
- **URDF Importer** — Convert URDF to Godot scene tree
- **Physics Demo** — VehicleBody3D base + differential drive
- **Joint Control** — Real-time joint manipulation
- **Sensor Debug** — LIDAR, camera, IMU visualization

### Layer 3: Optional Integrations

```
┌─────────────────────────────────────────┐
│           Optional Layers               │
├─────────────┬─────────────┬─────────────┤
│ godot_ros2  │  AI Layer   │  Blockchain │
│ (ROS2)      │  (GameAI)   │  (AO/Arweave│
├─────────────┼─────────────┼─────────────┤
│ • TCP/UDP   │ • Minimax   │ • Arweave   │
│   bridge    │   API       │   storage   │
│ • sensor_   │ • Code      │ • AO Hyper- │
│   msgs      │   generation│   objects   │
│ • cmd_vel   │ • ROS Coder │ • Trading   │
└─────────────┴─────────────┴─────────────┘
```

---

## Scene Structure

### Robot Viewer Scene

```
scenes/robot_viewer.tscn
└── RobotViewer (RobotViewerController)
    ├── CameraPivot (Node3D)
    │   └── Camera (Camera3D)
    ├── AmbientLight (DirectionalLight3D)
    ├── KeyLight (DirectionalLight3D)
    ├── FillLight (DirectionalLight3D)
    └── GroundStatic (StaticBody3D)
        └── Ground (MeshInstance3D)
    └── Robot Root (Node3D, created at runtime)
        └── [URDF-loaded robot hierarchy]
```

### Physics Demo Scene

```
scenes/physics_demo.tscn
└── PhysicsDemo (Node3D)
    ├── CameraPivot (Node3D)
    │   └── Camera (Camera3D)
    ├── AmbientLight (DirectionalLight3D)
    ├── KeyLight (DirectionalLight3D)
    ├── Ground (StaticBody3D)
    │   ├── GroundCollision (CollisionShape3D)
    │   └── GroundMesh (MeshInstance3D)
    ├── Obstacle1 (StaticBody3D)
    ├── Obstacle2 (StaticBody3D)
    ├── Obstacle3 (StaticBody3D)
    └── TurtleBot (VehicleBody3D) [created at runtime]
        ├── BodyCollision (CollisionShape3D)
        ├── BodyVisual (MeshInstance3D)
        ├── FrontLeftWheel (VehicleWheel3D)
        ├── FrontRightWheel (VehicleWheel3D)
        ├── RearLeftWheel (VehicleWheel3D)
        └── RearRightWheel (VehicleWheel3D)
```

---

## Data Flow

### URDF → Godot Scene

```
URDF File (XML)
    │
    ▼
urdf_to_godot.gd (XMLParser)
    │
    ├── Parse <link> elements → MeshInstance3D + CollisionShape3D
    ├── Parse <joint> elements → PinJoint3D / SliderJoint3D
    └── Parse <material> → StandardMaterial3D
    │
    ▼
Godot Scene Tree (Node3D hierarchy)
    │
    ▼
Robot Viewer displays it
```

### ROS2 Integration

```
Copernicus                      ROS 2
    │                              │
    ├── sensor data ────────────────► /robot/scan
    │         (TCP/UDP bridge)        │
    │                              │
    ◄── cmd_vel ◄─────────────────── /robot/cmd_vel
    │                              │
```

---

## Directory Structure

```
Copernicus/
├── scripts/                     # Core GDScript
│   ├── urdf_to_godot.gd        # URDF parser
│   ├── robot_viewer_controller.gd
│   ├── physics_demo.gd          # VehicleBody3D
│   ├── joint_panel.gd          # UI sliders
│   ├── lidar_debug.gd           # Sensor viz
│   ├── camera_debug.gd
│   ├── imu_debug.gd
│   └── ...
├── scenes/                      # Godot scenes
│   ├── robot_viewer.tscn
│   ├── joint_control_panel.tscn
│   ├── physics_demo.tscn
│   └── main.tscn
├── addons/                      # Optional modules
│   ├── godot_ros2/              # ROS2 bridge
│   ├── hyperobject/             # AO Hyperobjects
│   └── ...
├── docs/                        # Documentation
│   ├── philosophy.md           # Why open source
│   ├── architecture.md         # This file
│   └── ...
└── README.md                    # Project overview
```

---

## Extending Copernicus

### Creating a New Module

1. Create your module directory under `addons/` or `modules/`
2. Add `plugin.cfg` for Godot plugin system
3. Implement your core script with `class_name`
4. Add optional scenes and scripts
5. Document in a README.md
6. Submit a PR or fork freely

### Module Example

```
addons/my_sensor/
├── plugin.cfg
├── my_sensor.gd         # class_name MySensor
├── my_sensor_config.tscn
└── README.md
```

---

## Further Reading

- [Philosophy](philosophy.md) — Why open source robotics matters
- [Getting Started](getting-started.md) — Set up your environment
- [Simulation](simulation.md) — ROS2 and physics details
- [Contributing](development/contributing.md) — How to contribute
