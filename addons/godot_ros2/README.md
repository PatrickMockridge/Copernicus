# Godot ROS 2 SDK

A comprehensive ROS 2 SDK for Godot 4 that enables using Godot as a robotics simulator, designed to replace Gazebo with both **Simple Mode** (demos/presentations) and **Advanced Mode** (full development control).

## Features

### Two Operating Modes

**Simple Mode** - Perfect for demos and presentations:
- One-line robot creation
- Built-in robot templates (differential drive, etc.)
- Simplified sensor setup
- Minimal configuration required
- Great for teaching and quick prototyping

**Advanced Mode** - Full Gazebo-equivalent functionality:
- URDF import support
- Custom joint controllers
- Physics debugging
- Contact visualization
- Plugin system extensibility
- Low-level access to all components

## Installation

1. Copy `addons/godot_ros2` into your Godot project's `addons/` folder
2. Enable the plugin in **Project Settings > Plugins**
3. Install ROS 2 bridge (see [Bridge Setup](#bridge-setup))

## Quick Start

### Simple Mode

```gdscript
extends Node3D

var sim: ROS2Simulator
var robot: RobotModel
var lidar: LidarSensor

func _ready() -> void:
    # Initialize simulator in simple mode
    sim = ROS2Simulator.new()
    sim.set_mode(ROS2Simulator.Mode.SIMPLE)
    add_child(sim)

    # Create a differential drive robot with one line
    robot = sim.create_simple_diff_robot("my_robot", "", "", "", Transform3D.IDENTITY)

    # Add sensors easily
    lidar = sim.add_lidar_to_robot(robot, "front_lidar", {
        "angle_min": -PI,
        "angle_max": PI,
        "range_min": 0.1,
        "range_max": 30.0
    })

    # Connect to ROS 2
    var ros2 = GodotROS2.initialize("godot_node", "/robot")
```

### Advanced Mode

```gdscript
extends Node3D

var sim: ROS2Simulator
var robot: RobotModel

func _ready() -> void:
    sim = ROS2Simulator.new()
    sim.set_mode(ROS2Simulator.Mode.ADVANCED)
    add_child(sim)

    # Load from URDF
    robot = sim.create_advanced_robot("manipulator", "res://urdf/my_robot.urdf")

    # Add custom joint controllers
    var pos_controller = JointController.new()
    pos_controller.set_gains(10.0, 0.1, 1.0)
    sim.add_joint_control(robot, "joint1", pos_controller)

    # Enable physics debugging
    sim.enable_physics_debug()

    # Load plugins
    var perf_monitor = PerformanceMonitor.new()
    sim.load_plugin(perf_monitor)
```

## Core Components

### ROS2Simulator

Main simulation controller.

```gdscript
var sim = ROS2Simulator.new()
sim.set_mode(ROS2Simulator.Mode.SIMPLE)  # or Mode.ADVANCED
add_child(sim)

# Time control
sim.set_time_scale(1.0)  # Normal speed
sim.set_time_scale(0.5)  # Half speed (slow motion)
sim.pause()
sim.resume()

# World settings
sim.set_gravity(Vector3(0, -9.81, 0))
```

### RobotModel

Robot model with links and joints.

```gdscript
# Simple mode
var robot = sim.create_simple_robot("turtle", "res://meshes/turtle.glb")

# Advanced mode
var robot = sim.create_advanced_robot("arm", "res://urdf/arm.urdf")
robot.set_control_mode(RobotModel.ControlMode.POSITION)
```

### Sensors

Available sensors:
- `CameraSensor` - RGB/depth cameras
- `LidarSensor` - 2D/3D LIDAR
- `ImuSensor` - IMU (accelerometer, gyroscope)
- `GPSSensor` - GPS positioning
- `ContactSensor` - Contact detection
- `ForceTorqueSensor` - F/T measurements

```gdscript
# LIDAR
var lidar = sim.add_lidar_to_robot(robot, "lidar", {
    "angle_min": -PI,
    "angle_max": PI,
    "angle_increment": 0.017,
    "range_min": 0.1,
    "range_max": 30.0
})

# Camera
var camera = sim.add_camera_to_robot(robot, "camera", {
    "fov": 1.047,
    "width": 640,
    "height": 480
})

# IMU
var imu = sim.add_imu_to_robot(robot, "imu", {})
```

### Actuators

```gdscript
var motor = Motor.new("wheel_motor")
motor.set_max_speed(1000.0)
motor.set_control_mode(Motor.ControlMode.VELOCITY)
robot.add_child(motor)

var servo = Servo.new("gripper")
servo.set_limits(-1.57, 1.57)
robot.add_child(servo)
```

### Plugins

```gdscript
# Performance monitoring
var perf = PerformanceMonitor.new()
sim.load_plugin(perf)

# Contact visualization
var contact_viz = ContactVisualizer.new()
sim.load_plugin(contact_viz)

# Trajectory recording
var recorder = TrajectoryRecorder.new()
sim.load_plugin(recorder)
recorder.start_recording("robot_name")
```

## ROS 2 Topics

### Published Topics

| Topic | Type | Description |
|-------|------|-------------|
| `/robot/odom` | nav_msgs/Odometry | Ground truth odometry |
| `/robot/scan` | sensor_msgs/LaserScan | LIDAR scan data |
| `/robot/image_raw` | sensor_msgs/Image | Camera image |
| `/robot/imu` | sensor_msgs/Imu | IMU data |
| `/robot/gps` | sensor_msgs/NavSatFix | GPS coordinates |

### Subscribed Topics

| Topic | Type | Description |
|-------|------|-------------|
| `/robot/cmd_vel` | geometry_msgs/Twist | Velocity command |
| `/robot/joint_cmd` | trajectory_msgs/JointTrajectory | Joint command |

## Bridge Setup

The SDK communicates with ROS 2 via a TCP/UDP bridge process. Build and run the bridge:

```bash
# Build the bridge package
cd ~/ros2_ws
source /opt/ros/jazzy/setup.sh
colcon build --packages-select godot_ros2_bridge
source install/setup.sh

# IMPORTANT: Set ROS_DOMAIN_ID to match your ROS environment
export ROS_DOMAIN_ID=0

# Run the bridge
ros2 run godot_ros2_bridge godot_bridge_node
```

### Important: ROS_DOMAIN_ID

**Must set `ROS_DOMAIN_ID`** before running the bridge or any Godot code that connects to ROS. DDS participants must be on the same domain to discover each other.

```bash
# Set domain before running anything
export ROS_DOMAIN_ID=0  # or your domain number

# Verify domain is set
echo $ROS_DOMAIN_ID
```

If you see "topic does not appear to be published yet" errors, the domain ID is likely mismatched.

### Bridge Protocol

The bridge uses TCP (port 8765) for control commands and UDP (port 8766) for message data.

**Control Commands (JSON over TCP):**

```json
// Create a publisher
{"cmd": "create_pub", "topic": "/robot/odom", "type": "nav_msgs/Odometry", "qos": 10}

// Create a subscription
{"cmd": "create_sub", "topic": "/robot/cmd_vel", "type": "geometry_msgs/Twist", "qos": 10}

// Publish data to ROS2
{"cmd": "publish", "topic": "/robot/odom", "data": {...}}

// Destroy entities
{"cmd": "destroy_pub", "topic": "/robot/odom"}
{"cmd": "destroy_sub", "topic": "/robot/cmd_vel"}

// Get current topics
{"cmd": "get_topics"}

// Ping
{"cmd": "ping"}
```

**Data Messages (JSON over UDP):**
```json
{"topic": "/robot/odom", "data": {...}, "ts": 1234567890}
```

### Using with Godot

In your GDScript, connect to the bridge and publish/subscribe:

```gdscript
# Initialize with bridge connection
GodotROS2.initialize("godot_node", "/robot", "127.0.0.1")

# Create a publisher
var pub = GodotROS2.create_publisher("/robot/odom", "nav_msgs/Odometry")

# Publish data
var msg = {
    "header": {"stamp": {"sec": 1234}, "frame_id": "base_link"},
    "pose": {"pose": {"position": {"x": 1.0, "y": 0.0, "z": 0.0}}}
}
pub.publish(msg)

# Create a subscription with callback
func _on_cmd_vel(msg):
    var linear = msg.linear
    var angular = msg.angular
    # Process command

var sub = GodotROS2.create_subscription("/robot/cmd_vel", "geometry_msgs/Twist", Callable(self, "_on_cmd_vel"))
```

## Simple Mode Templates

### TurtleBot-style Robot

```gdscript
var turtle = sim.create_simple_diff_robot("turtle",
    "res://meshes/body.glb",   # body mesh
    "res://meshes/left_wheel.glb",
    "res://meshes/right_wheel.glb"
)
turtle.set_global_transform(Vector3(0, 0, 0))
```

### Quadcopter

```gdscript
var quad = sim.create_simple_robot("quad", "res://meshes/quad.glb")
var thrust0 = Thruster.new("fl")
thrust0.set_direction(Vector3(0, 1, 0))
quad.add_child(thrust0)
```

### Arm Manipulator

```gdscript
var arm = sim.create_advanced_robot("arm", "res://urdf/arm.urdf")
var controller = JointController.new("arm_controller")
controller.set_gains(10.0, 0.0, 1.0)
sim.add_joint_controller(arm, "joint1", controller)
```

## Advanced Mode Features

### URDF Import

```gdscript
robot.load_urdf("res://urdf/my_robot.urdf")
```

### Custom Physics

```gdscript
# Access contact manager
var contacts = sim.get_contact_manager().get_contacts_for_body("link_name")

# Enable debug visualization
sim.enable_physics_debug()
```

### Joint Controllers

```gdscript
var pos_ctrl = JointController.new()
pos_ctrl.set_target_position(1.57)  # 90 degrees
pos_ctrl.set_gains(10.0, 0.1, 1.0)  # Kp, Ki, Kd

var vel_ctrl = JointController.new()
vel_ctrl.set_target_velocity(1.0)   # rad/s
vel_ctrl.set_gains(1.0, 0.0, 0.1)

var eff_ctrl = JointController.new()
eff_ctrl.set_target_effort(5.0)     # Nm
```

## Message Types

Available message helpers:

- `StdMsgs` - Header, String, Bool, Int32, Float64, Time, etc.
- `GeometryMsgs` - Twist, Pose, Quaternion, Vector3, Transform, Wrench
- `SensorMsgs` - Image, LaserScan, Imu, NavSatFix, PointCloud2
- `NavMsgs` - Odometry, Path, OccupancyGrid
- `TF2Msgs` - TFMessage, TransformStamped

```gdscript
var header = StdMsgs.create_header_now("base_link")
var twist = GeometryMsgs.create_twist(Vector3(1.0, 0, 0), Vector3.ZERO)
var scan = SensorMsgs.create_laserscan(header, -PI, PI, 0.01, 0.0, 0.1, 0.1, 30.0, ranges, intensities)
```

## FileManager — Robot Code Deployment

File editing and code deployment to robot systems. Supports SSH and ROS service modes.

```gdscript
# SSH mode (direct robot connection)
var fm = GodotROS2.create_file_manager("192.168.1.100")
fm.set_connection_params("192.168.1.100", 22, "robot")
fm.connect_robot()

# Read existing file
var config = fm.read_file("/home/robot/catkin_ws/config/params.yaml")

# Write Python control script
fm.deploy_python_file(python_code, "/home/robot/catkin_ws/src/my_robot/control.py")

# Deploy launch file
var launch_content = "..."  # launch.py content
fm.deploy_launch_file("my_robot", "start", launch_content)

# Deploy URDF
fm.deploy_urdf("my_robot", "robot_description", urdf_content)

# Check file exists
if fm.file_exists("/home/robot/catkin_ws/src/my_robot/nodes/tracker.py"):
    fm.delete_file("/home/robot/catkin_ws/src/my_robot/nodes/tracker.py")

fm.disconnect()
```

### File Operations

| Method | Description |
|--------|-------------|
| `read_file(path)` | Read file content from robot |
| `write_file(path, content)` | Write content to robot file |
| `delete_file(path)` | Delete file on robot |
| `list_directory(path)` | List directory contents |
| `file_exists(path)` | Check if file exists |
| `create_directory(path)` | Create directory |
| `get_file_permissions(path)` | Get owner/group/mode |
| `set_file_permissions(path, mode)` | Set file permissions |

### Code Deployment Helpers

| Method | Description |
|--------|-------------|
| `deploy_python_file(content, path)` | Deploy Python with shebang +x |
| `deploy_launch_file(package, name, content)` | Deploy launch.py |
| `deploy_config_file(package, name, content)` | Deploy YAML config |
| `deploy_urdf(package, name, content)` | Deploy URDF |

## Troubleshooting & Debugging

### Common Issues

**"Topic does not appear to be published yet"**
- Cause: ROS_DOMAIN_ID mismatch between bridge and ROS tools
- Fix: Set `export ROS_DOMAIN_ID=0` (or your domain) before running bridge and ROS commands

**Bridge starts but messages don't reach ROS**
- Check: Is `ROS_DOMAIN_ID` set consistently?
- Check: Is a subscriber already running before publishing?
- Check: View bridge logs at `/tmp/bridge.log`

**Python rclpy publishers don't work but ros2 CLI does**
- Cause: rclpy and ros2 CLI may use different domain IDs
- Fix: Always set `ROS_DOMAIN_ID` environment variable

### Debugging Commands

```bash
# Check ROS environment
source /opt/ros/jazzy/setup.sh
echo $ROS_DOMAIN_ID

# List topics with domain
ROS_DOMAIN_ID=0 ros2 topic list

# Echo topic with domain
ROS_DOMAIN_ID=0 ros2 topic echo /topic_name

# Check topic details
ROS_DOMAIN_ID=0 ros2 topic info /topic_name -v

# Monitor ROS connections
ROS_DOMAIN_ID=0 ros2 doctor

# Restart ROS daemon on specific domain
ROS_DOMAIN_ID=0 ros2 daemon stop
ROS_DOMAIN_ID=0 ros2 daemon start
```

### Testing the Bridge Manually

```bash
# Terminal 1: Start bridge
source /opt/ros/jazzy/setup.sh
export ROS_DOMAIN_ID=0
ros2 run godot_ros2_bridge godot_bridge_node

# Terminal 2: Test with Python
python3 << 'EOF'
import socket, json

s = socket.socket()
s.connect(('127.0.0.1', 8765))

# Create publisher
s.sendall((json.dumps({"cmd": "create_pub", "topic": "/test", "type": "std_msgs/String", "qos": 10}) + "\n").encode())
print(s.recv(1024).decode())

# Publish
s.sendall((json.dumps({"cmd": "publish", "topic": "/test", "data": {"data": "Hello!"}}) + "\n").encode())
print(s.recv(1024).decode())
s.close()
EOF

# Terminal 2: Verify with ros2
source /opt/ros/jazzy/setup.sh
export ROS_DOMAIN_ID=0
ros2 topic echo /test std_msgs/String --once
```

### Bridge Log Location

Bridge logs are written to `/tmp/bridge.log` when started with `nohup`:
```bash
tail -f /tmp/bridge.log
```

---

## Blockchain Integration (Arweave + AO Hyperobjects)

The SDK includes support for publishing robot designs to Arweave and trading them as AO Hyperobjects.

### Architecture

```
Robot Design (RobotModel)
    │
    ├─► ARIADNE.push() ─► Arweave TX ID (permanent storage)
    │
    └─► AO Hyperobject ─► AO Process (ownership, transfer)
```

### Components

| Class | Purpose |
|-------|---------|
| `AriadneInterface` | Wrapper for ariadne-cli (git-on-Arweave) |
| `RobotHyperobject` | Bridge class linking ARIADNE repos with AO processes |
| `TradeManager` | Registry and trading operations for robot designs |
| `WalletService` | Single source of truth for wallet (autoload) |
| `ArweaveWallet` | JWK wallet wrapper for Arweave/AO operations |
| `AOSDK` | AO Hyperobject SDK (spawn processes, schedule messages) |
| `Storage` | Arweave upload/download helpers |

### Setup

1. **Install ariadne-cli** (Node 22+):
```bash
npm install -g ariadne-cli
```

2. **Create wallet** or use existing JWK wallet file:
```json
{
  "kty": "RSA",
  "n": "...",
  "e": "AQAB",
  "kid": "your_address_here"
}
```

3. **Load wallet in Godot**:
```gdscript
WalletService.get_instance().load_wallet("res://wallet.json")
```

### Publishing a Robot Design

```gdscript
# Initialize ARIADNE in your project directory
var ariadne = AriadneInterface.new()
ariadne.initialize("", true)  # --create flag

# Create robot hyperobject
var robot = RobotHyperobject.from_robot_model(robot_model, ariadne, ao)
var result = robot.publish()

# result = {
#   "exit_code": 0,
#   "output": "Published",
#   "repo_id": "arweave_tx_id_here",
#   "process_id": "ao_process_id_here"
# }
```

### Trading Robots

```gdscript
var trade_manager = TradeManager.new(ao, ariadne)

# List for sale
trade_manager.list_for_sale(repo_id, price.0)

# Remove from sale
trade_manager.unlist(repo_id)

# Transfer ownership
trade_manager.transfer(repo_id, new_owner_address)

# Purchase (uses WalletService wallet)
trade_manager.purchase(repo_id)
```

### Querying Robots

```gdscript
# Get robots owned by address
var owned = trade_manager.get_robots_by_owner(wallet_address)

# Get all robots for sale
var for_sale = trade_manager.get_robots_for_sale()

# Search by name
var results = trade_manager.search_by_name("turtlebot")
```

## License

MIT
