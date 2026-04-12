# Copernicus

## Robot Design Interface

> *"In the middle of difficulty lies opportunity."* — Albert Einstein

AI-powered robotics design interface in Godot 4 with ROS 2, blockchain publishing, and AI code generation. Named **Copernicus** after the astronomer who placed the Sun at the center of the solar system — just as this project places the **open-source community** at the center of robot development.

---

## The Copernican Philosophy

### Why Open Source Robotics?

Robotics has been dominated by closed, proprietary systems:
- **Expensive licenses** restrict who can participate
- **Black-box simulators** hide the math
- **Single-vendor lock-in** stifles innovation
- **Fragmented tools** prevent sharing

Just as NVIDIA uses Unity for Isaac Sim, Copernicus uses [Godot](https://godotengine.org/) — but with a fundamentally different philosophy:

```
        Proprietary Tools
              ↓
         ┌─────────┐
         │ CLOSED  │   ← Old model: exclusive, expensive
         └─────────┘
              ↓
    ┌─────────────────────┐
    │     COPERNICUS      │   ← New model: open, modular, yours
    │  ┌───────────────┐  │
    │  │   Community   │  │
    │  │    ↺ Fork     │  │
    │  │    ↻ PRs      │  │
    │  │    ↻ Modules  │  │
    │  └───────────────┘  │
    └─────────────────────┘
              ↓
         Everyone
```

### Godot-Native Approach

Copernicus doesn't fight Godot — it embraces what Godot does well:

| Strength | Use Case |
|----------|----------|
| 3D Rendering | Robot meshes, materials, lighting |
| UI System | Joint sliders, control panels |
| Scene Tree | Robot hierarchy, kinematic chains |
| Native Physics | VehicleBody3D, joints, basic simulation |
| ROS2 Bridge | Sensor streaming to external tools |

**Copernicus is NOT:**
- A physics research simulator (use Isaac Sim/Gazebo) — but has Godot native + PyBullet plugin
- An IK solver (use MoveIt) — but has Analytical IK + MoveIt plugin
- A motion planner (use Nav2) — but has A* Grid + Nav2 plugin

**Copernicus IS:**
- A fast 3D editor for visualizing robot models
- An interactive tool for testing joint configurations
- A ROS2 data source for sensor streams
- A design viewer that exports to full simulators

---

## Features

- **URDF Visualizer** — Parse and visualize robot models from URDF files
- **Interactive Joint Control** — Real-time joint manipulation via sliders
- **Physics Demo** — Differential drive using Godot's VehicleBody3D
- **Sensor Debug Visualization** — LIDAR rays, camera frustum, IMU axes
- **ROS 2 Bridge** — Sensor data streaming to/from external tools
- **AI Code Agent** — Generate GDScript behaviors (obstacle avoidance, patrol)
- **ROS Coder IDE** — In-game IDE for writing ROS2 Python (rclpy) software
- **Blockchain Publishing** — Few clicks to publish your robot to Arweave
- **AO Hyperobjects** — Trade robot designs as ownership-verifiable assets
- **Decentralized Marketplace** — Buy and sell robots, parts, and worlds via AO tokens
- **Navigation Plugins** — A* Grid (pure GDScript) and Nav2 (ROS2) path planners
- **IK Solver Plugins** — Analytical (CCD/FABRIK) and MoveIt (ROS2)
- **Physics Backend Plugins** — Godot native and PyBullet backends

---

## Quick Start

```bash
# Clone
git clone https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface.git
cd Godot_4__Robotic_Design_Interface

# Run robot viewer
godot scenes/robot_viewer.tscn

# Run physics demo (WASD controls)
godot scenes/physics_demo.tscn

# Run main interface
godot scenes/main.tscn
```

### Try the Turtle Demo (No ROS2 Required!)

The **TurtleBot demo** is the fastest way to see Copernicus in action:

```bash
godot scenes/turtle_demo.tscn
```

**What it does:**
- Shows a turtlebot in a 2D arena with obstacles
- **Click anywhere on the ground** to set a goal
- Robot plans an A* path and navigates to your click
- Toggle **"Switch to ROS2 Mode"** to connect to real turtlesim

This demo showcases the modular plugin architecture — same A* planner works natively (Godot physics) and via ROS2 (turtlesim bridge).

---

## Documentation

- [Quick Start Guide](docs/quick-start.md) ← **Start here for the turtle demo**
- [Marketplace](docs/marketplace.md) ← **Buy and sell robots, parts, worlds**
- [Getting Started](docs/getting-started.md)
- [AI Code Agent](docs/ai-codegen.md)
- [Blockchain](docs/blockchain.md)
- [ROS 2 Simulation](docs/simulation.md)
- [Testing](docs/testing.md)
- [Physics Backends](docs/physics-backends.md)
- [IK Solvers](docs/ik-solver.md)
- [Navigation Planners](docs/nav-planner.md)

```
Copernicus / Robot Design Interface
├──────────────────────────────────────────────────────────────┐
│  UI Layer (Godot Controls)                                   │
│  ├── Robot viewer with orbit camera                           │
│  ├── Joint control panels (sliders)                          │
│  ├── Physics demo with VehicleBody3D                         │
│  └── ROS 2 Bridge controls                                   │
├──────────────────────────────────────────────────────────────┤
│  Godot-Native Modules                                        │
│  ├── URDF Importer → Godot scene tree                       │
│  ├── Skeleton3D / Joint3D for kinematics                    │
│  ├── VehicleBody3D for differential drive                    │
│  └── MeshInstance3D for visuals                              │
├──────────────────────────────────────────────────────────────┤
│  AI Layer (Optional)                                          │
│  ├── GameAI — Chat/completion via Minimax                    │
│  └── ROSAI — ROS-specific behavior prompts                   │
├──────────────────────────────────────────────────────────────┤
│  ROS 2 Bridge                                                │
│  ├── TCP/UDP communication                                   │
│  └── sensor_msgs / geometry_msgs                             │
├──────────────────────────────────────────────────────────────┤
│  Blockchain Layer                                             │
│  ├── Arweave — Permanent decentralized storage             │
│  ├── RobotPublisher — File bundling + upload orchestration │
│  └── AO Hyperobjects — Ownership and trading                │
└──────────────────────────────────────────────────────────────┘
```

---

## Modular by Design

Copernicus is designed to be extended with swappable plugin backends:

```
┌─────────────────────────────────────────────────────────────┐
│                    Copernicus                                │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐ │
│  │ URDF      │ │ Physics   │ │ ROS2                      │ │
│  │ Importer  │ │ Backend   │ │ Bridge                    │ │
│  └───────────┘ └───────────┘ └───────────────────────────┘ │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐ │
│  │ Joint     │ │ IK Solver │ │ Navigation               │ │
│  │ Control   │ │ Backend   │ │ Planner                  │ │
│  └───────────┘ └───────────┘ └───────────────────────────┘ │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────────┐ │
│  │ Sensor    │ │ Hyperobject│ │ ROS Coder IDE           │ │
│  │ Debug     │ │ Trade      │ │                          │ │
│  └───────────┘ └───────────┘ └───────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Each backend has a swappable interface:**
- **Physics:** Godot Native (VehicleBody3D) or PyBullet
- **IK Solver:** Analytical (CCD/FABRIK) or MoveIt (ROS2)
- **Navigation:** A* Grid or Nav2 (ROS2)

**Fork it. Extend it. Make it yours.**

---

## Publishing to Blockchain

Turn your robot into a tradeable AO Hyperobject in **few clicks**:

1. Open your robot scene in Copernicus
2. Click **Publish** in the toolbar
3. Configure name, description, price
4. Click **Publish**

Your robot files are uploaded to Arweave (permanent storage) and linked to an AO Hyperobject process (ownership, transfer).

```gdscript
// Programmatic publishing
var files = IDEIntegration.discover_robot_files()
var result = IDEIntegration.quick_publish(files, "MyRobot", "A differential drive robot", 5.0)
```

---

## ROS 2 Topics

| Topic | Type | Description |
|-------|------|-------------|
| `/turtlebot4/odom` | nav_msgs/Odometry | Ground-truth odometry |
| `/turtlebot4/scan` | sensor_msgs/LaserScan | 360° lidar |
| `/turtlebot4/imu` | sensor_msgs/Imu | IMU data |
| `/turtlebot4/cmd_vel` | geometry_msgs/Twist | Velocity command |

---

## Documentation

- [Getting Started](docs/getting-started.md)
- [AI Code Agent](docs/ai-codegen.md)
- [Blockchain](docs/blockchain.md)
- [ROS 2 Simulation](docs/simulation.md)
- [Testing](docs/testing.md)
- [Physics Backends](docs/physics-backends.md)
- [IK Solvers](docs/ik-solver.md)
- [Navigation Planners](docs/nav-planner.md)

---

## Contributing

1. **Fork** the repository
2. **Create** your module in a clean, self-contained way
3. **Submit** a PR with a clear description
4. **Join** the discussion

Every contribution makes robotics more accessible.

---

## Requirements

| Component | Version |
|-----------|---------|
| Godot | 4.4+ |
| ROS 2 | Jazzy or Humble |
| Node.js | 22+ (for ARIADNE CLI) |

---

## License

Copernicus is distributed under the **GNU Affero General Public License v3 (AGPLv3)**.

See [LICENSE](LICENSE) for the full license text and ethical statement.

**In short:**
- You can use, modify, and distribute Copernicus freely
- If you distribute it (including over a network), you must release source under AGPL
- Derivative works must also be AGPL

**Ethical Note:** We believe robotics should expand human capability, solve real problems, and respect autonomy. We acknowledge that any technology can be misused — we cannot stop bad actors. But by making this software open, we choose to trust the many over controlling the few.

---

**Copernicus: Robot design for the many, not the few.**