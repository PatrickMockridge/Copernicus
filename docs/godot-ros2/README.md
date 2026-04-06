# godot_ros2 SDK

ROS 2 simulator plugin for Godot 4. Use Godot as a robotics simulator to replace Gazebo.

## Overview

The SDK provides:
- **Sensors**: LIDAR, camera, IMU, GPS, force/torque, contact detection
- **Actuators**: Motors, servos, thrusters, propellers
- **Robot Models**: Simple and advanced modes with URDF import
- **Physics**: Built-in physics engine with contact visualization
- **ROS 2 Bridge**: TCP/UDP connection to communicate with ROS 2

## Quick Start

```gdscript
extends Node3D

var sim: ROS2Simulator
var robot: RobotModel
var lidar: LidarSensor

func _ready() -> void:
    sim = ROS2Simulator.new()
    sim.set_mode(ROS2Simulator.Mode.SIMPLE)
    add_child(sim)

    robot = sim.create_simple_diff_robot("my_robot", "", "", "", Transform3D.IDENTITY)
    lidar = sim.add_lidar_to_robot(robot, "lidar", {
        "angle_min": -PI,
        "angle_max": PI,
        "range_min": 0.1,
        "range_max": 30.0
    })
```

## Documentation

- [Sensors](sensors.md) — Sensor classes and configuration
- [Actuators](actuators.md) — Motor, servo, thruster classes
- [Robot Models](robot-models.md) — Robot creation and URDF import
- [Simulator Plugins](simulator-plugins.md) — Performance monitoring, contact visualization
- [API Reference](api-reference.md) — Full API documentation

## Key Classes

| Class | File | Description |
|-------|------|-------------|
| `ROS2Simulator` | core/ros2_simulator.gd | Main simulation controller |
| `RobotModel` | core/robot_model.gd | Robot with links and joints |
| `Sensor` | sensors/sensor.gd | Base sensor class |
| `LidarSensor` | sensors/lidar_sensor.gd | 2D/3D LIDAR |
| `CameraSensor` | sensors/camera_sensor.gd | RGB/depth camera |
| `ImuSensor` | sensors/imu_sensor.gd | IMU sensor |
| `Actuator` | core/actuator.gd | Base actuator class |
| `Motor` | core/motor.gd | DC motor |
| `Servo` | core/servo.gd | Servo motor |
| `Thruster` | core/thruster.gd | Thruster actuator |
| `Propeller` | core/propeller.gd | Propeller (extends Thruster) |

## Two Operating Modes

### Simple Mode
Perfect for demos and quick prototyping:
- One-line robot creation
- Built-in templates
- Minimal configuration

### Advanced Mode
Full Gazebo-equivalent functionality:
- URDF import
- Custom joint controllers
- Physics debugging
- Plugin system

## Source Files

```
addons/godot_ros2/
├── core/
│   ├── ros2_simulator.gd      # Main simulator
│   ├── robot_model.gd         # Robot model
│   ├── robot_link.gd          # Robot link
│   ├── robot_joint.gd         # Robot joint
│   ├── joint_controller.gd    # Joint PID control
│   ├── contact_manager.gd    # Contact detection
│   ├── differential_drive.gd  # Drive system
│   ├── actuator.gd           # Base actuator
│   ├── motor.gd              # Motor
│   ├── servo.gd              # Servo
│   ├── thruster.gd           # Thruster
│   ├── propeller.gd           # Propeller
│   ├── simulator_plugin.gd    # Base plugin
│   ├── physics_logger.gd      # Logging plugin
│   ├── contact_visualizer.gd # Visualization plugin
│   ├── trajectory_recorder.gd # Recording plugin
│   └── performance_monitor.gd # Performance plugin
├── sensors/
│   ├── sensor.gd              # Base sensor
│   ├── lidar_sensor.gd        # LIDAR
│   ├── camera_sensor.gd       # Camera
│   ├── imu_sensor.gd         # IMU
│   ├── gps_sensor.gd         # GPS
│   ├── force_torque_sensor.gd # F/T sensor
│   └── contact_sensor.gd     # Contact sensor
└── ros2/
    ├── ros2_node.gd           # ROS 2 node
    ├── ros2_simulator.gd      # Simulator
    └── ...
```

For full documentation, see the [addon README](../../addons/godot_ros2/README.md).
