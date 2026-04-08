# Copernicus - Robot Design Interface

## Project Overview

**Copernicus** is an open-source robot design interface built on Godot 4. Named after Nicolaus Copernicus who placed the Sun at the center of the solar system, it places the **open-source community** at the center of robot development.

Just as NVIDIA uses Unity for Isaac Sim, Copernicus uses Godot - a free, open-source game engine with exceptional 3D capabilities. But Copernicus is designed to be something more: a **modular, forkable ecosystem** where anyone can contribute modules, create PRs, and extend functionality.

## Architecture Philosophy

Copernicus leverages what Godot does natively:
- **3D rendering** with meshes, materials, lighting
- **UI** for interactive controls (sliders, panels)
- **Scene tree management** for robot hierarchy
- **Native physics** (VehicleBody3D, joints) for basic simulation
- **ROS2 bridge** for sensor data streaming

Copernicus is NOT:
- A physics research simulator (use Isaac Sim/Gazebo for that)
- An IK solver (use MoveIt)
- A motion planner (use Nav2)

**What Copernicus IS:**
- A fast 3D editor for visualizing robot models
- An interactive tool for testing joint configurations
- A ROS2 data source for sensor streams
- A design viewer that exports to full simulators

## Key Directories

- `scripts/` - Core GDScript modules
- `scenes/` - Godot scene files (.tscn)
- `addons/godot_ros2/` - ROS2 bridge for sensor/control
- `addons/hyperobject/` - AO Hyperobject SDK for tradeable assets
- `docs/` - Documentation

## Core Scripts

| File | Purpose |
|------|---------|
| `urdf_to_godot.gd` | URDF parser → Godot scene tree |
| `robot_viewer_controller.gd` | 3D viewer with orbit camera |
| `physics_demo.gd` | VehicleBody3D differential drive |
| `joint_panel.gd` | Interactive joint slider UI |
| `lidar_debug.gd` | LIDAR ray visualization |
| `camera_debug.gd` | Camera frustum visualization |
| `imu_debug.gd` | IMU axes visualization |

## Modularity

Copernicus is designed to be extended:
- Fork the repo and create domain-specific modules
- PR contributions welcome for new robot types, sensors, visualizations
- Each module is self-contained where possible
- Use Godot's addon system for optional extensions

## Commands

```bash
godot scenes/robot_viewer.tscn    # View robot model
godot scenes/physics_demo.tscn     # Drive vehicle with WASD
```
