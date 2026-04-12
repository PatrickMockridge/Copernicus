# Navigation Planner Module

Copernicus supports swappable navigation planners for robot path planning and navigation.

## Overview

```
Copernicus (Visualizer + Controller)
    │
    ├── Navigation Planner Interface (abstract)
    │       │
    │       ├── A* Grid Planner ← No external deps
    │       │       OR
    │       └── Nav2 Bridge ← Via ROS2, industry standard
```

## Planner Comparison

| Planner | Environment | Dependencies | Use Case |
|---------|-------------|--------------|----------|
| **A* Grid** | Known indoor | None | Simple navigation, grid maps |
| **Nav2** | Any | ROS2 + Nav2 | Industry, SLAM, complex |

## Why Multiple Planners?

Different navigation scenarios need different approaches:

- **A* Grid** works well for known environments with pre-built maps
- **Nav2** handles unknown environments with SLAM, dynamic obstacles, and industry-grade reliability

## A* Grid Planner (Default)

Pure GDScript A* path planner - no external dependencies.

### How It Works

```
1. Build occupancy grid from scene obstacles
2. A* search from start to goal
3. Return path as array of Vector3 waypoints
```

**Best for:**
- Indoor navigation with known obstacles
- Simple environments without dynamic changes
- When ROS2 is not available

```gdscript
var planner = AStarGridPlanner.new()
planner.initialize({"use_diagonals": true})

# Set map from occupancy grid
var map_data = occupancy_grid.to_dictionary()
planner.set_map(map_data)

# Plan path
var path = planner.plan(start_position, goal_position)
```

### Occupancy Grid Helper

Convert scene obstacles to grid representation:

```gdscript
var grid = OccupancyGrid.new()
grid.setup(100, 100, 0.1)  # 100x100 cells, 10cm resolution

# Mark obstacles from physics scene
var space_state = get_world_3d().direct_space_state
grid.from_scene(space_state, bounds_min, bounds_max, 0.1)

# Or mark manually
grid.mark_obstacle_world(Vector3(1.0, 0, 2.0))
grid.clear_obstacle_world(Vector3(1.0, 0, 2.0))
```

### Configuration

```gdscript
planner.initialize({
    "max_iterations": 1000,     # Max A* iterations
    "tolerance": 0.1,           # Goal tolerance (meters)
    "robot_radius": 0.3,        # For inflation
    "smooth_path": true,        # Apply path smoothing
    "use_diagonals": true       # Allow diagonal movement
})
```

## Nav2 Bridge (Industry Grade)

Connects to ROS2 Nav2 for industry-standard navigation.

**Requirements:**
- ROS2 installed and sourced
- Nav2 packages (`navigation2`, `nav2_bringup`)
- SLAM or pre-built map

```bash
# Check if ROS2/Nav2 is available
ros2 pkg list | grep nav2
```

```gdscript
var planner = Nav2Bridge.new()
planner.initialize({
    "planner_id": "GridBased",  # or "ThetaStar", "SmacPlanner"
    "use_astar": false
})

var path = planner.plan(start_position, goal_position)
```

### Nav2 Lifecycle

```gdscript
# Set robot pose for AMCL localization
planner.set_robot_pose(robot_transform)

# Clear costmap if robot gets stuck
planner.clear_costmap()

# Start/stop navigation
planner.start_navigation()
planner.stop_navigation()
```

## Navigation Planner Interface

All planners implement `NavPlanner`:

```gdscript
class_name NavPlanner

func initialize(config: Dictionary) -> bool
func plan(start: Vector3, goal: Vector3) -> Array  # Array of Vector3
func set_map(map_data: Dictionary) -> void
func clear_map() -> void
func is_valid_position(position: Vector3) -> bool
func get_last_path() -> Array
```

### Signals

```gdscript
planner.planning_started.emit()
planner.planning_progress.emit(0.5)  # 50% complete
planner.planning_finished.emit(true, path)
planner.planner_error.emit("No path found")
```

## Path Visualization

Visualize planned paths in 3D:

```gdscript
var visualizer = PathVisualizer.new()
add_child(visualizer)

# Show path
visualizer.visualize_path(path)

# Show only waypoints
visualizer.show_waypoints_only()

# Animate along path
visualizer.animate_along_path(path, robot_node, 1.0)  # 1 m/s
```

### Visualization Configuration

```gdscript
visualizer.set_path_color(Color(0.2, 0.8, 1.0, 0.8))
visualizer.set_waypoint_color(Color(1.0, 0.5, 0.2, 1.0))
visualizer.set_waypoint_radius(0.05)
```

## Using the Navigation Selector

Open the navigation selector panel:

```bash
godot scenes/nav_selector.tscn
```

Select your desired planner and click **Apply**.

## Programmatic Planner Selection

```gdscript
# Get available planners
var available = NavSelector.get_available_planners()

# Create a specific planner
var planner = NavSelector.create_planner("AStarGridPlanner", {
    "use_diagonals": true,
    "max_iterations": 1000
})
```

## Basic Usage Example

```gdscript
# 1. Create occupancy grid from scene
var grid = OccupancyGrid.new()
var space_state = get_world_3d().direct_space_state
grid.from_scene(space_state, Vector3(-10, 0, -10), Vector3(10, 0, 10), 0.1)

# 2. Create and configure planner
var planner = AStarGridPlanner.new()
planner.initialize({"use_diagonals": true})
planner.set_map(grid.to_dictionary())

# 3. Plan path
var start = Vector3(0, 0, 0)
var goal = Vector3(5, 0, 3)
var path = planner.plan(start, goal)

if path.is_empty():
    print("No path found!")
else:
    # 4. Visualize
    var visualizer = PathVisualizer.new()
    add_child(visualizer)
    visualizer.visualize_path(path)
```

## When to Use Which

| Scenario | Recommended Planner |
|---------|--------------------|
| Known indoor map, grid-based | A* Grid |
| No ROS2 available | A* Grid |
| Unknown environment | Nav2 |
| Dynamic obstacles | Nav2 |
| Large outdoor areas | Nav2 |
| SLAM required | Nav2 |
| Industry deployment | Nav2 |

## Performance Tips

### A* Grid Planner
- Use larger grid resolution for faster planning
- Enable path smoothing for smoother paths
- Pre-build occupancy grid when possible

### Nav2
- Use appropriate planner for environment (GridBased vs SmacPlanner)
- Tune costmap parameters for dynamic environments
- Use localization (AMCL) for known maps

## Adding New Planners

Implement the `NavPlanner` interface:

```gdscript
class_name MyNavPlanner
extends NavPlanner

func plan(start: Vector3, goal: Vector3) -> Array:
    # Your path planning implementation
    return path_array

# ... implement all required methods
```

Register in `NavSelector`:
```gdscript
_add_planner_option("MyPlanner", "My Navigator", "Description", MyPlanner.is_available())
```

## Architecture

```
scripts/nav/
├── nav_planner.gd           # Abstract interface
├── astar_grid_planner.gd    # Pure GDScript A*
├── occupancy_grid.gd        # Grid map utilities
├── path_visualizer.gd       # 3D path visualization
├── nav2_bridge.gd           # ROS2/Nav2 bridge
├── nav2_bridge.py           # Python ROS2 node
└── nav_selector.gd          # Planner selection UI

scenes/
└── nav_selector.tscn        # Selection panel scene
```

---

**Tip:** Start with A* Grid for fast prototyping, switch to Nav2 when you need SLAM, dynamic obstacle handling, or industry-grade reliability.
