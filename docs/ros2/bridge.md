# ROS2 Bridge

The ROS2 bridge connects Copernicus to ROS2 for sensor data publishing, robot control, and navigation.

## Architecture

The bridge uses Godot's `addons/godot_ros2/` and `addons/ros2_native/` addons to:

- Publish sensor data (LIDAR, camera, IMU) to ROS2 topics
- Subscribe to `/cmd_vel` and joint commands
- Call ROS2 services for IK (MoveIt) and navigation (Nav2)

## Getting Started

See [ROS2 Native overview](../ros2_native/overview.md) for the native ROS2 integration.

## Relevant Modules

| Module | Purpose |
|--------|---------|
| `godot_ros2` | Core ROS2 bridge addon |
| `ros2_native` | Native ROS2 node integration |
| `nav2_bridge.gd` | Nav2 navigation bridge |
| `moveit_ik_bridge.gd` | MoveIt IK solver bridge |

## Requirements

- ROS2 installed and sourced
- Python packages: `rclpy`, `nav2` (for Nav2), `moveit` (for MoveIt)
