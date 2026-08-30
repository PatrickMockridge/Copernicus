# Quick Start Guide

Copernicus is an operating system for robotics: a kernel (editor + terminal) with apps and robots
around it. Start the kernel shell:

```bash
godot scenes/main.tscn
```

This opens the 3D editor on top and the terminal at the bottom. Type `load arm6` or `load turtlebot` to
load a robot, `list` to see every command, or read the [interface manual](interface-user-manual.md).

The scenes below are standalone demos you can also run directly (no ROS 2 required).

## Step-by-Step: Running Demos

### 1. Turtle Demo (Navigation)

```bash
godot scenes/turtle_demo.tscn
```

**Controls:**
- Left-click on ground → Set goal position
- Robot plans A* path and navigates
- "Switch to ROS2 Mode" → Connect to real turtlesim

**Files:**
- `scenes/turtle_demo.tscn` - Demo scene
- `scripts/turtle_demo.gd` - Demo controller
- `scripts/turtle/turtle_controller.gd` - TurtleBot controller

### 2. Robot Viewer

```bash
godot scenes/robot_viewer.tscn
```

View robot models with orbit camera controls.

### 3. Physics Demo

```bash
godot scenes/physics_demo.tscn
```

Differential drive robot with WASD keyboard controls.

### 4. The kernel shell

```bash
godot scenes/main.tscn
```

The kernel: the 3D editor on top, the terminal (command line + log) at the bottom, and the screen rail
down the left. This is the main entry point.

### 5. Joint Control

```bash
godot scenes/main.tscn
```

Load a robot (`load arm6`) and manipulate joints with the viewport toolbar **Zero**/**Reach** buttons.
See the [features](features.md) and [Arm6 case study](case-study-robot-arm.md).

---

## Running with ROS2

For full ROS2 integration (turtlesim, sensor streaming):

### Prerequisites

```bash
# Install ROS2 (Jazzy or Humble)
# Source your ROS2 workspace
source /opt/ros/jazzy/setup.bash

# Run turtlesim
ros2 run turtlesim turtlesim_node
```

### Connect Copernicus to ROS2

1. Start the ROS2 bridge in a terminal:
   ```bash
   ros2 launch godot_ros2_bridge godot_ros2_bridge.launch.py
   ```

2. Run the turtle demo and click "Switch to ROS2 Mode"

3. The turtlebot will now control the real turtlesim!

---

## Project Structure

```
Copernicus/
├── scenes/              # Godot scene files (.tscn)
│   ├── turtle_demo.tscn  # ← Start here!
│   ├── main.tscn
│   └── physics_demo.tscn
├── scripts/              # GDScript modules
│   ├── turtle/          # TurtleBot controller
│   ├── nav/             # Navigation plugins
│   ├── ik/              # IK solver plugins
│   └── physics/         # Physics backend plugins
├── addons/
│   ├── godot_ros2/      # ROS2 bridge
│   └── rchain/          # RChain crypto
└── docs/
    └── quick-start.md    # This file
```

---

## Troubleshooting

### "Could not find type" errors

Some scripts require the full project context. Run from the project root:

```bash
cd Godot_4__Robotic_Design_Interface
godot scenes/turtle_demo.tscn
```

### ROS2 not available

That's fine! The turtle demo works completely natively without ROS2.

### Godot crashes on startup

Try running in headless mode first:

```bash
godot --headless --quit
```

If that works, the issue is display-related. Try:
```bash
godot scenes/turtle_demo.tscn --video-driver headless
```

---

## Next Steps

1. **Explore the demos** - Try each scene
2. **Read the architecture docs** - Understand the plugin system
3. **Add your robot** - Load a URDF or create from primitives
4. **Extend Copernicus** - Fork and create a module

---

## Getting Help

- Check [Getting Started Guide](01-getting-started.md) for detailed setup
- See [Simulation Guide](simulation.md) for ROS2 simulation
- Open an issue on [GitHub](https://github.com/PatrickMockridge/Copernicus)

---

**Ready to dive deeper?**
- [Architecture overview](03-architecture.md) - How plugins work
- [Physics backends](physics/backends.md) - Godot vs PyBullet
- [Navigation planners](navigation/planners.md) - A* vs Nav2
- [IK solvers](navigation/ik-solvers.md) - Analytical vs MoveIt
