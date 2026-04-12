# Copernicus Documentation

> *"In the middle of difficulty lies opportunity."* — Albert Einstein

Welcome to **Copernicus**, an open-source robot design interface built on [Godot 4](https://godotengine.org/). Named after the astronomer who placed the Sun at the center of our solar system, Copernicus places the **open-source community** at the center of robot development.

---

## The Copernican Philosophy

### Why Open Source Robotics?

Robotics has long been dominated by closed, proprietary systems:
- **Expensive licenses** restrict who can participate
- **Black-box simulators** hide the math
- **Single-vendor lock-in** stifles innovation
- **Fragmented tools** prevent sharing

Just as NVIDIA uses Unity for Isaac Sim, Copernicus uses Godot — but with a fundamentally different philosophy:

| Proprietary | Copernicus |
|-------------|------------|
| Closed, expensive | Free (MIT), open source |
| Single vendor | Community-driven |
| Black box | Transparent, hackable |
| Fragmented | Modular, composable |

**Copernicus is more than software — it's a statement that robotics belongs to everyone.**

---

## Contents

### [Getting Started](getting-started.md)
Setup, installation, and your first robot.

### [ROS 2 Simulation](simulation.md)
Sensors, actuators, robot models, and Godot-native physics.

### [Philosophy](philosophy.md)
The conceptual foundation: why open source, why Godot, why modular.

### [Architecture](architecture.md)
System design and module relationships.

### [Physics Backends](physics-backends.md)
Optional physics engines: Godot Native or PyBullet.

### [Blockchain](blockchain.md)
ARIADNE git-on-Arweave and AO Hyperobjects for trading robot designs.

### [AI Code Agent](ai-codegen.md)
AI behavior generation + ROS Coder IDE.

### [Development](development/code-patterns.md)
Godot 4.x coding patterns and contributing guidelines.

### [License](license.md)
AGPLv3 license with ethical statement.

---

## Quick Links

| Resource | Description |
|----------|-------------|
| [ROS 2 Bridge Setup](simulation.md#bridge-setup) | Build and run the TCP/UDP bridge |
| [Wallet Setup](blockchain.md#wallet-setup) | Configure Arweave wallet |
| [AI Code Agent](ai-codegen.md) | AI behavior generation + ROS Coder IDE |
| [Testing](testing.md) | Test procedures and expected outputs |

---

## Core Principles

### 1. Godot-Native
Copernicus doesn't fight Godot — it embraces what Godot does well:
- **3D rendering** with meshes, materials, lighting
- **UI system** for interactive controls
- **Scene tree** for robot hierarchy
- **Native physics** (VehicleBody3D, joints)
- **ROS2 bridge** for sensor streaming

### 2. Clear Scope
Copernicus is **not** trying to replace research simulators:
- **NOT** a physics research simulator (use Isaac Sim/Gazebo)
- **NOT** an IK solver (use MoveIt)
- **NOT** a motion planner (use Nav2)

Copernicus **IS** a fast 3D editor for visualizing robots, testing joint configurations, and serving as a ROS2 data source.

### 3. Modular by Design
```
┌─────────────────────────────────────────────────────────────┐
│                    Copernicus                                │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐ │
│  │ URDF      │ │ Physics   │ │ ROS2                      │ │
│  │ Importer  │ │ Demo      │ │ Bridge                    │ │
│  └───────────┘ └───────────┘ └───────────────────────────┘ │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐ │
│  │ Joint     │ │ Sensor    │ │ Hyperobject               │ │
│  │ Control   │ │ Debug     │ │ Trade Assets              │ │
│  └───────────┘ └───────────┘ └───────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Fork it. Extend it. Make it yours.**
