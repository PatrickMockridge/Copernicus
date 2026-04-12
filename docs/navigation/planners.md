# Navigation Planners

Copernicus provides pluggable navigation systems from simple grid-based A* to industry-standard Nav2.

---

## Available Planners

| Planner | Type | ROS 2 Required | Use Case |
|---------|------|-----------------|----------|
| **A* Grid** | Grid-based | No | Indoor navigation, fast iteration |
| **Nav2 Bridge** | Full stack | Yes | SLAM, global planning, recovery |

---

## A* Grid Planner

Pure GDScript implementation of A* pathfinding on 2D occupancy grids.

### How It Works

```
1. Start at current position
2. Add to open set with f_score = g_score + heuristic
3. While open set not empty:
   a. Get node with lowest f_score
   b. If goal, reconstruct path
   c. For each neighbor:
      - If traversable and not in closed set:
        - Compute g_score (cost from start)
        - Compute f_score (g + heuristic)
        - If new path to neighbor is better:
          - Update came_from
          - Add to open set
```

### Basic Usage

```gdscript
var planner = AStarGridPlanner.new()
planner.set_grid_size(100, 100)  # 100x100 cells
planner.set_cell_size(0.1)      # 10cm per cell

# Set obstacles from physics scene
planner.set_obstacle_positions([...])

# Plan path
var start = Vector2i(10, 10)
var goal = Vector2i(50, 50)
var path = planner.plan(start, goal)

if path.size() > 0:
    # Path found
    for point in path:
        print("Go to: ", point)
```

### Configuration

```gdscript
planner.configure({
    "grid_width": 100,
    "grid_height": 100,
    "cell_size": 0.1,        # meters per cell
    "diagonal_movement": true,  # allow 8-connectivity
    "heuristic": AStarGridPlanner.EUCLIDEAN,  # or MANHATTAN
    "smooth_path": true         # apply path smoothing
})
```

### Heuristic Types

```gdscript
enum Heuristic {
    MANHATTAN,    # |dx| + |dy| - faster, less accurate
    EUCLIDEAN,     # sqrt(dx² + dy²) - slower, more accurate
    DIAGONAL      # max(|dx|, |dy|) - for diagonal movement
}
```

### Path Smoothing

Raw A* produces jerky, 90° turns. Enable smoothing for natural paths:

```gdscript
planner.set_smooth_path(true)

# Or manually smooth
var smooth_path = planner.smooth_path(raw_path)
```

---

## Nav2 Bridge

ROS 2 Nav2 integration for industry-standard navigation.

### When to Use

- SLAM for map building
- Global path planning with dynamic replanning
- Recovery behaviors when stuck
- Multi-floor buildings
- Complex environments

### Requirements

```bash
# Install ROS 2 Nav2
sudo apt install ros-jazzy-navigation2 ros-jazzy-nav2-bringup

# Launch Nav2
ros2 launch nav2_bringup navigation_launch.py
```

### Basic Usage

```gdscript
var nav = Nav2Bridge.new()
nav.initialize({
    "group_name": "manipulator",
    "robot_base_frame": "base_link",
    "odom_frame": "odom"
})


func navigate_to_goal(target_position: Vector3):
    nav.set_pose_goal({
        "position": [target_position.x, target_position.y, target_position.z],
        "orientation": [0, 0, 0, 1]  # quaternion
    })

    # Wait for result
    while not nav.is_goal_reached():
        var state = nav.get_current_state()
        print("Navigating: ", state)
        await get_tree().create_timer(0.5).timeout

    print("Goal reached!")
```

### Navigation State Machine

Nav2 follows a lifecycle state machine:

```
Configured → Inactive → Active → Active (Navigating) → Completed/Failed
```

### Costmap

Nav2 uses costmaps for obstacle avoidance:

```gdscript
# Clear costmap around robot
nav.clear_costmap()

# Set costmap defaults
nav.configure_costmap({
    "inflation_radius": 0.5,
    "cost_scaling_factor": 1.0,
    "footprint_padding": 0.1
})
```

---

## Occupancy Grid

Build 2D maps from physics scene for A* planning:

```gdscript
class_name OccupancyGrid
extends RefCounted

var _width: int = 100
var _height: int = 100
var _cell_size: float = 0.1
var _grid: Array = []  # 2D array of occupancy values


func build_from_physics(space_state: PhysicsDirectSpaceState3D,
                        bounds: AABB, origin: Vector3):
    _width = int(bounds.size.x / _cell_size)
    _height = int(bounds.size.z / _cell_size)

    for x in range(_width):
        _grid.append([])
        for y in range(_height):
            var world_pos = origin + Vector3(x * _cell_size, 0, y * _cell_size)
            var occupied = check_collision_at(space_state, world_pos)
            _grid[x].append(1 if occupied else 0)


func check_collision_at(space_state: PhysicsDirectSpaceState3D,
                        pos: Vector3) -> bool:
    var query = PhysicsPointQueryParameters3D.new()
    query.position = pos
    query.collide_with_bodies = true
    var result = space_state.intersect_point(query, 1)
    return result.size() > 0


func get_cell(x: int, y: int) -> int:
    if x >= 0 and x < _width and y >= 0 and y < _height:
        return _grid[x][y]
    return 1  # Out of bounds = occupied
```

---

## Differential Drive Navigation

For wheeled robots with differential drive:

```gdscript
class_name DiffDriveNavigator

var _planner: AStarGridPlanner
var _drive: DifferentialDrive


func navigate_to_goal(goal: Vector2i):
    var path = _planner.plan(current_grid_pos, goal)

    for waypoint in path:
        # Convert grid to world position
        var world_pos = grid_to_world(waypoint)

        # Navigate to waypoint
        while current_pos.distance_to(world_pos) > 0.1:
            # Compute heading
            var heading = atan2(world_pos.y - current_pos.y,
                              world_pos.x - current_pos.x)

            # Turn to face waypoint
            var turn_error = heading - current_heading
            var angular_vel = clamp(turn_error * 2.0, -max_turn, max_turn)

            # Move forward
            var linear_vel = min(current_pos.distance_to(world_pos), max_speed)

            _drive.apply_cmd_vel(linear_vel, angular_vel)

        # Reached waypoint, next one
```

---

## Path Visualizer

Display planned paths in 3D:

```gdscript
class_name PathVisualizer

var _line: ImmediateGeometry3D


func visualize_path(path: Array):
    _line.clear()
    _line.begin(Mesh.PRIMITIVE_LINE_STRIP)

    for point in path:
        _line.add_vertex(Vector3(point.x, 0.05, point.y))

    _line.end()
```

---

## Selector Panel

Use the navigation selector to choose between planners:

```bash
godot scenes/nav_selector.tscn
```

Programmatically:

```gdscript
# Check available planners
var available = NavSelector.get_available_planners()
# Returns: ["AStarGridPlanner", "Nav2Bridge"]

# Create planner
var planner = NavSelector.create_planner("AStarGridPlanner", {
    "grid_width": 100,
    "grid_height": 100
})
```

---

## Common Issues

### A* Path Not Found

- Check grid resolution (cell_size too large = no path through narrow spaces)
- Verify obstacles are correctly marked in grid
- Try enabling diagonal movement

### Nav2 Not Connecting

- Verify ROS 2 is sourced: `source /opt/ros/jazzy/setup.bash`
- Check `ros2 node list` shows navigation nodes
- Verify `/map` and `/odom` topics are publishing

### Robot Collides with Obstacles

- Increase inflation radius in Nav2
- Add recovery behaviors
- Check sensor coverage (blind spots)

---

## Architecture

```
scripts/nav/
├── nav_planner.gd           # Abstract interface
├── astar_grid_planner.gd    # A* implementation
├── nav2_bridge.gd          # Nav2 ROS 2 bridge
├── occupancy_grid.gd      # Grid utilities
└── path_visualizer.gd      # 3D path display

scenes/
└── nav_selector.tscn        # Planner selection UI
```

---

## See Also

- [IK Solvers](ik-solvers.md) — Robot arm planning
- [Control](../robots/control.md) — Differential drive kinematics
- [Sensors Overview](../sensors/overview.md) — Sensor-based obstacle detection