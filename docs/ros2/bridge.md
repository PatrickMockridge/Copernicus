# ROS2 Bridge

The ROS2 bridge connects Copernicus to ROS2 for sensor data publishing, robot control, and navigation via TCP/UDP and native rclpy.

## Architecture

The bridge lives in `addons/godot_ros2/` and uses Godot's `StreamPeerTCP` for persistent connections:

```
Copernicus (Godot)                    ROS2 Network
┌──────────────────┐                ┌──────────────────┐
│  ROS2BridgeClient │──TCP:9090──▶  │  ros2_bridge.py  │
│  (StreamPeerTCP)  │◀────────────  │  (rclpy node)     │
└──────────────────┘                └────────┬─────────┘
                                             │
                                      ┌──────▼──────────┐
                                      │  ROS2 Middleware  │
                                      │  (DDS / FastDDS)  │
                                      └──────────────────┘
```

The `addons/ros2_native/` addon provides an alternative path with direct rclpy integration and DDS transport. See [ROS2 Native overview](../ros2_native/overview.md) for that approach.

## Published Topics

| Topic | Message Type | Rate | Description |
|-------|-------------|------|-------------|
| `/robot/odom` | `nav_msgs/Odometry` | 50 Hz | Robot pose and velocity |
| `/robot/scan` | `sensor_msgs/LaserScan` | 10 Hz | LIDAR point ranges |
| `/robot/image_raw` | `sensor_msgs/Image` | 30 Hz | Camera RGB feed |
| `/robot/imu` | `sensor_msgs/Imu` | 100 Hz | Orientation, angular velocity, linear acceleration |

## Subscribed Topics

| Topic | Message Type | Purpose |
|-------|-------------|---------|
| `/robot/cmd_vel` | `geometry_msgs/Twist` | Drive velocity commands |

## Publisher Setup

```gdscript
var bridge = ROS2BridgeClient.new()
bridge.start("127.0.0.1", 9090)

# Publish sensor data
func _process(delta):
    bridge.publish_odom("/robot/odom", {
        "position": robot.position,
        "orientation": robot.quaternion,
        "linear_velocity": robot.linear_velocity,
        "angular_velocity": robot.angular_velocity
    })
```

## Subscriber Setup

```gdscript
func _on_cmd_vel_received(msg: Dictionary):
    var linear = msg.get("linear", {})
    var angular = msg.get("angular", {})
    robot.set_velocity(
        Vector3(linear.get("x", 0), 0, angular.get("z", 0))
    )

bridge.subscribe("/robot/cmd_vel", "geometry_msgs/Twist", _on_cmd_vel_received)
```

## QoS Configuration

```gdscript
bridge.set_qos("/robot/scan", {
    "reliability": 1,   # RELIABLE
    "durability": 0,    # VOLATILE
    "depth": 10
})

bridge.set_qos("/robot/imu", {
    "reliability": 2,   # BEST_EFFORT
    "depth": 1
})
```

## Persistent Python Subprocess

For compute-heavy backends (physics, RL), Copernicus uses a persistent TCP subprocess pattern via [PythonBridge](../development/plugin-guide.md#pythonbridge). This eliminates the ~200ms per-call overhead of spawning a new Python process for each command:

```
PythonBridge.start("script.py", port)  →  OS.create_process("python3")
PythonBridge.send({cmd json})          →  StreamPeerTCP ↔ JSON line protocol
PythonBridge.shutdown()                →  OS.kill(pid)
```

Used by: PyBullet backend, DQN/PPO/SAC learners.

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
