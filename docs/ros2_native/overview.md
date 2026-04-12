# ROS2 Native Integration

Native ROS2 integration for Copernicus, replacing the TCP/UDP bridge with direct rclpy integration. Supports Isaac ROS messages, services, and actions.

---

## Overview

The ROS2 Native plugin provides:

- **Direct rclpy integration** via Python subprocess
- **Isaac ROS message types** for navigation and manipulation
- **DDS transport** for high-performance pub/sub
- **Action support** for goal-based execution
- **Parameter management** via ROS2 parameters

---

## Architecture

```
addons/ros2_native/
├── ros2_native.gd                # Plugin entry point
├── plugin.cfg                    # Plugin configuration
└── core/
    ├── rcl_node.gd              # rclpy wrapper
    ├── rcl_node_script.py       # Python bridge
    ├── dds_transport.gd         # Fast DDS transport
    └── isaac_ros_bridge.gd       # Isaac ROS messages
```

---

## Quick Start

### 1. Enable the Plugin

In Project Settings → Plugins → Enable "ROS2 Native Integration"

### 2. Create a ROS2 Node

```gdscript
var ros_node = RclNode.new()
ros_node.initialize({"node_name": "copernicus_node"})

# Create a publisher
ros_node.create_publisher("/cmd_vel", "geometry_msgs/Twist")

# Publish a message
ros_node.publish("/cmd_vel", {
    "linear": {"x": 0.5, "y": 0.0, "z": 0.0},
    "angular": {"x": 0.0, "y": 0.0, "z": 0.0}
})
```

### 3. Create a Subscriber

```gdscript
func _on_odom_received(msg: Dictionary):
    var pos = msg["pose"]["position"]
    print("Robot at: ", pos["x"], pos["y"], pos["z"])

ros_node.create_subscription("/odom", "nav_msgs/Odometry", _on_odom_received)
```

---

## RclNode

Main ROS2 node wrapper providing publishers, subscribers, services, and actions.

### Initialization

```gdscript
var node = RclNode.new()
node.initialize({"node_name": "my_robot"})

# Check availability
if RclNode.is_rclpy_available():
    print("ROS2 is available!")
```

### Publishers

```gdscript
# Create publisher
node.create_publisher("/robot/cmd_vel", "geometry_msgs/Twist", 10)

# Publish message
node.publish("/robot/cmd_vel", {
    "linear": {"x": 1.0, "y": 0.0, "z": 0.0},
    "angular": {"x": 0.0, "y": 0.0, "z": 0.5}
})
```

### Subscribers

```gdscript
func on_scan_received(msg: Dictionary):
    var ranges = msg["ranges"]
    print("LIDAR points: ", ranges.size())

node.create_subscription("/robot/scan", "sensor_msgs/LaserScan", on_scan_received)
```

### Services

```gdscript
# Create service server
node.create_service("/robot/reset", "std_srvs/Empty", func(req):
    return {"success": true}
)

# Call service client
var result = node.call_service("/robot/get_pose", {
    "query": "current"
})
```

### Actions

```gdscript
# Create action client
node.create_action_client("/robot/move", "nav_msgs/action/NavigateToPose")

# Send goal
var goal_result = node.send_action_goal("/robot/move", {
    "pose": {...},
    "behavior_tree": ""
})
```

### Parameters

```gdscript
# Set parameter
node.set_parameter("robot_name", "turtlebot")

# Get parameter
var name = node.get_parameter("robot_name")
```

---

## Isaac ROS Bridge

Isaac ROS message types for navigation and manipulation.

### Message Creation

```gdscript
# Create PoseStamped
var pose = IsaacROS.create_pose_stamped(
    Vector3(1.0, 2.0, 0.0),
    Quaternion(0, 0, 0, 1),
    "map"
)

# Create JointState
var joint_state = IsaacROS.create_joint_state(
    ["shoulder", "elbow", "wrist"],
    [0.5, -0.3, 0.8],
    [0.1, 0.2, 0.1],  # velocities
    [5.0, 3.0, 2.0]   # efforts
)

# Create Twist
var twist = IsaacROS.create_twist(
    Vector3(0.5, 0, 0),   # linear
    Vector3(0, 0, 0.3)    # angular
)

# Create Path
var path = IsaacROS.create_path(poses_array)
```

### MoveIt Integration

```gdscript
# Create MoveIt planning request
var request = IsaacROS.create_moveit_request("arm", target_pose)

# Navigate to pose (Nav2)
var nav_goal = IsaacROS.create_navigate_to_pose_goal(target_pose)
```

### Camera Info

```gdscript
# Create camera intrinsics
var camera_info = IsaacROS.create_camera_info(640, 480, 554.0, 554.0, 320.0, 240.0)
```

### Point Cloud

```gdscript
# Create point cloud
var cloud = IsaacROS.create_point_cloud(width, height, points_data)
```

---

## DDS Transport

High-performance DDS transport for low-latency pub/sub.

### Usage

```gdscript
var transport = DDSTransport.new()
transport.configure({"domain_id": 10})

# Create publisher
transport.create_publisher("/sensor/lidar", "sensor_msgs/PointCloud2")

# Publish
transport.publish("/sensor/lidar", {"points": [...], "timestamp": 123456})

# Create subscriber
transport.create_subscriber("/sensor/lidar", "sensor_msgs/PointCloud2", func(data):
    process_lidar(data)
)

# Poll in _process
func _process(delta):
    transport.poll()
```

### QoS Profiles

```gdscript
var qos = DDSTransport.QosProfile.new()
qos.reliability = 1  # RELIABLE
qos.durability = 0   # VOLATILE
qos.depth = 10

transport.set_qos("/important/topic", qos)
```

---

## Isaac ROS Packages

The plugin auto-detects installed Isaac ROS packages:

```gdscript
var packages = IsaacROS.get_isaac_packages()
for pkg in packages:
    print("Found: ", pkg)

# Check specific availability
if IsaacROS.is_isaac_available():
    print("Isaac ROS is available!")
```

### Supported Packages

| Package | Status |
|---------|--------|
| `isaac_ros_navigation` | Detected |
| `isaac_ros_manipulation` | Detected |
| `isaac_ros_visual_slam` | Detected |
| `nav2_bringup` | Supported |
| `moveit2` | Supported |

---

## Message Type Mapping

| Copernicus | ROS2 |
|-------------|-----|
| Vector3 | geometry_msgs/Point |
| Quaternion | geometry_msgs/Quaternion |
| Transform3D | geometry_msgs/Transform |
| Transform3D | geometry_msgs/Pose |
| Array[Vector3] | sensor_msgs/PointCloud |

---

## Integration with Existing Code

### Replace godot_ros2 Bridge

```gdscript
# Old approach (TCP/UDP)
var old_bridge = ROS2BridgeClient.new()

# New approach (Native rclpy)
var ros_node = RclNode.new()
ros_node.initialize({"node_name": "copernicus"})
```

### Combined with Industrial Plugin

```gdscript
# ROS2 for navigation
var nav = RclNode.new()
nav.initialize({"node_name": "navigation"})

# Industrial for robot control
var controller = IndustrialController.new()
controller.connect_robot("192.168.1.100", "MockIndustrial")
```

---

## Requirements

- ROS2 installation (Foxy, Galactic, Humble, or Jazzy)
- rclpy Python package
- DDS middleware (Fast DDS or Cyclone DDS)

```bash
# Check ROS2
ros2 pkg list | grep rclpy

# Install rclpy if missing
pip install rclpy
```

---

## Troubleshooting

### ROS2 Not Available

```bash
# Source ROS2
source /opt/ros/humble/setup.bash

# Verify
ros2 pkg list | head
```

### Isaac ROS Not Detected

```bash
# Install Isaac ROS packages
sudo apt install ros-humble-isaac-ros-*
```

### DDS Transport Issues

```bash
# Check DDS vendor
echo $RMW_IMPLEMENTATION

# Set Fast DDS
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

---

## See Also

- [ROS2 Bridge](ros2/bridge.md) - TCP/UDP bridge documentation
- [Navigation Planners](../navigation/planners.md) - Nav2 integration
- [IK Solvers](../navigation/ik-solvers.md) - MoveIt integration
- [Industrial Plugin](../industrial/overview.md) - Industrial robot control