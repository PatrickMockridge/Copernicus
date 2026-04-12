# Copernicus
## Robot Design Interface for Godot 4

**Copernicus** is a 3D robotics design tool built on [Godot 4](https://godotengine.org/).
It provides robot visualization, joint control, physics simulation, ROS 2 integration,
blockchain publishing, and modular plugin architecture.

## Quick Start

```bash
godot scenes/turtle_demo.tscn    # Navigation demo (no ROS 2 required)
godot scenes/main.tscn           # AI code generation panel
godot scenes/robot_viewer.tscn   # URDF robot visualization
godot scenes/physics_demo.tscn   # VehicleBody3D with WASD controls
```

## Features

- **3D Robot Visualization** — URDF import, orbit camera, joint inspection
- **Interactive Joint Control** — Real-time joint manipulation via sliders
- **Physics Simulation** — Godot VehicleBody3D (native) or PyBullet backend
- **ROS 2 Integration** — TCP/UDP bridge for sensor streaming and control
- **IK Solver Plugins** — Analytical (CCD, FABRIK) or MoveIt via ROS 2
- **Navigation Plugins** — A* Grid (pure GDScript) or Nav2 via ROS 2
- **Blockchain Publishing** — Upload designs to Arweave, trade via AO Hyperobjects
- **AI Code Generation** — Generate GDScript behaviors via Minimax
- **Decentralized Marketplace** — Buy and sell robots, parts, environments

## Architecture

Copernicus uses a modular plugin architecture with swappable backends:

| Component | Plugin Options |
|-----------|---------------|
| Physics | Godot Native (VehicleBody3D), PyBullet |
| IK Solver | Analytical (CCD/FABRIK), MoveIt (ROS 2) |
| Navigation | A* Grid, Nav2 (ROS 2) |
| Marketplace | AO Hyperobjects, Mock (testing) |

## Requirements

| Component | Version |
|-----------|---------|
| Godot | 4.4+ |
| ROS 2 | Jazzy or Humble (optional) |
| Node.js | 22+ (optional, for ARIADNE CLI) |

## Documentation

- [Quick Start Guide](docs/quick-start.md) — Turtle demo and getting started
- [Marketplace](docs/marketplace.md) — Decentralized asset trading
- [Physics Backends](docs/physics-backends.md)
- [IK Solvers](docs/ik-solver.md)
- [Navigation Planners](docs/nav-planner.md)
- [ROS 2 Simulation](docs/simulation.md)
- [Blockchain](docs/blockchain.md)

## License

Copernicus is distributed under the [GNU AGPLv3](LICENSE).

To use, modify, or distribute, you must release source under AGPL.
Derivative works must also be AGPL.
