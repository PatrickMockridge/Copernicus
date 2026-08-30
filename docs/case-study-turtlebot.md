# Case Study — the TurtleBot (differential-drive mobile robot)

This walks through loading the built-in TurtleBot4, inspecting it, driving it, reading its LIDAR, and
wiring it to ROS 2. It doubles as the Workbench Loop's **See What It Sees** and **Make It Move** steps.

## 1. Load the robot

```
> load turtlebot
```

This calls `RobotLibrary.build("turtlebot")` → `TurtleBotFactory.build()`, which builds a small
differential-drive base:

- `base_link` — the body (0.3 × 0.1 × 0.2 m).
- `wheel_l_joint` / `wheel_r_joint` — two revolute wheels about the X axis, at ±0.12 m from center.
- `sensor_mount` — where the LIDAR sits.

> Note: the *default* robot you see on first launch is a different demo model. For this case study,
> always `load turtlebot` to get the factory version (its wheels are named `wheel_l_joint` /
> `wheel_r_joint`).

## 2. Inspect it

- **Orbit** (left-drag), **zoom** (wheel), **pan** (middle-drag / `WASD`).
- `wireframe on` for the flat debug look; `grid off` to hide the grid.

## 3. Drive it

The library model is kinematic (its wheels spin; the body doesn't translate). To actually drive, use a
demo or the controller:

```
> demo physics     # WASD differential-drive demo (VehicleBody3D)
```

or

```
> demo turtle      # click the ground to drive toward the point
```

Both open in an in-place demo overlay with a **Back** button. Driving the physics demo marks the
Workbench Loop's **Make It Move** check (`robot_moved`).

Programmatically, the differential drive is `scripts/turtle/turtle_controller.gd`:
`TurtleController.apply_cmd_vel(linear, angular)` sets the left/right wheel engine forces from
`v_left = v − ω·half_base`, `v_right = v + ω·half_base`.

## 4. Read the LIDAR

```
> sensors lidar on
```

This turns on `LidarDebug`, a 360-ray fan originating above the robot, raycasting against the scene and
coloured by distance. It marks the Workbench Loop's **See What It Sees** check (`lidar_active`).

`> sensors camera on` and `> sensors imu on` do the same for the camera and IMU overlays.

## 5. Wire it to ROS 2

```
> ros2
```

Connects the bridge. The ROS2 side publishes `/robot/scan` (a `sensor_msgs/LaserScan` from
`addons/godot_ros2/sensors/lidar_sensor.gd`) and `/robot/odom`, and subscribes to `/robot/cmd_vel` —
so an external ROS 2 node can drive the TurtleBot with `TurtleController.apply_cmd_vel`.

## Implementation notes

- **Model:** `scripts/robots/factories/turtlebot_factory.gd` (`TurtleBotFactory.build()`).
- **Driving:** `scripts/turtle/turtle_controller.gd` (`TurtleController`, a `VehicleBody3D` with four
  `VehicleWheel3D`s); `scripts/physics_demo.gd` (WASD); `scripts/turtle_demo.gd` (click-to-drive).
- **LIDAR:** `scripts/lidar_debug.gd` (`LidarDebug`, 360 rays, `MultiMeshInstance3D`); ROS2
  `addons/godot_ros2/sensors/lidar_sensor.gd`.
- **Scenarios:** `scripts/scenarios/scenario_service.gd` — `see_what_it_sees` (sensors) and
  `make_it_move` (auto-opens the physics demo).

See also: [features](features.md), [robot control](robots/control.md), [sensors overview](sensors/overview.md),
[ROS2 bridge](ros2/bridge.md).
