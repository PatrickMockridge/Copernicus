# Simulation

Simulation in Copernicus is a **backend choice**, not the product. Physics fidelity is selected with
`tool physics` — Godot-native (Jolt) for design iteration, PyBullet / PyBullet-CUDA for research-grade
manipulation, and (via the ROS 2 bridge) external simulators. See
[`spec/13-backend-interface.md`](spec/13-backend-interface.md) and
[`spec/00-kernel.md`](spec/00-kernel.md).

---

## Godot-Native Physics

Copernicus uses Godot's built-in physics nodes, not custom simulation code:

| Component | Godot Node | Use Case |
|-----------|-----------|----------|
| Robot Base | `RigidBody3D` | Basic dynamics |
| Wheels | `VehicleBody3D` | Differential drive |
| Joints | `PinJoint3D`, `SliderJoint3D` | Kinematic chains |
| Collisions | `CollisionShape3D` | Physics shapes |

This approach keeps Copernicus lightweight and leverages Godot's proven physics engine.

---

## Bridge Setup

The SDK communicates with ROS 2 via TCP/UDP bridge.

### Build the Bridge

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --packages-select godot_ros2_bridge
source install/setup.sh
```

### Run the Bridge

```bash
export ROS_DOMAIN_ID=0
ros2 run godot_ros2_bridge godot_bridge_node
```

### Important: ROS_DOMAIN_ID

Must set `ROS_DOMAIN_ID` before running bridge and any Godot code. DDS participants must be on the same domain.

```bash
export ROS_DOMAIN_ID=0
```

## Core Components

### ROS2Simulator

```gdscript
var sim = ROS2Simulator.new()
sim.set_mode(ROS2Simulator.Mode.SIMPLE)  # or Mode.ADVANCED
add_child(sim)

# Time control
sim.set_time_scale(1.0)  # Normal speed
sim.set_time_scale(0.5)  # Slow motion
sim.pause()
sim.resume()
```

### RobotModel

```gdscript
# Simple mode
var robot = sim.create_simple_robot("turtle", "res://meshes/turtle.glb")

# Advanced mode (URDF)
var robot = sim.create_advanced_robot("arm", "res://urdf/arm.urdf")
robot.set_control_mode(RobotModel.ControlMode.POSITION)
```

## Sensors

| Sensor | Description |
|--------|-------------|
| `LidarSensor` | 2D/3D LIDAR with configurable angles and range |
| `CameraSensor` | RGB/depth camera |
| `ImuSensor` | IMU (accelerometer, gyroscope) |
| `GPSSensor` | GPS positioning |
| `ContactSensor` | Contact detection |
| `ForceTorqueSensor` | F/T measurements |

### LIDAR Example

```gdscript
var lidar = sim.add_lidar_to_robot(robot, "lidar", {
    "angle_min": -PI,
    "angle_max": PI,
    "angle_increment": 0.017,
    "range_min": 0.1,
    "range_max": 30.0
})
```

### IMU Example

```gdscript
var imu = sim.add_imu_to_robot(robot, "imu", {})
```

## Actuators

| Actuator | Description |
|----------|-------------|
| `Motor` | DC motor with velocity/torque control |
| `Servo` | Servo motor with position control |
| `Thruster` | Thruster for aquatic robots |
| `Propeller` | Propeller for aerial robots |

### Motor Example

```gdscript
var motor = Motor.new("wheel_motor")
motor.set_max_speed(1000.0)
motor.set_control_mode(Motor.ControlMode.VELOCITY)
robot.add_child(motor)
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

## Bridge Protocol

### TCP (Port 8765) — Control Commands

```json
{"cmd": "create_pub", "topic": "/robot/odom", "type": "nav_msgs/Odometry", "qos": 10}
{"cmd": "create_sub", "topic": "/robot/cmd_vel", "type": "geometry_msgs/Twist", "qos": 10}
{"cmd": "publish", "topic": "/robot/odom", "data": {...}}
{"cmd": "destroy_pub", "topic": "/robot/odom"}
{"cmd": "ping"}
```

### UDP (Port 8766) — Message Data

```json
{"topic": "/robot/odom", "data": {...}, "ts": 1234567890}
```

## TurtleBot4 Model

The simulator uses real TurtleBot4 geometry from ROS 2 packages:

- **Base**: Create3 — cylinder (r=0.164m, h=0.06m), mass 2.3kg
- **Wheels**: Differential drive, separation 0.233m, radius 0.0419m
- **RPLidar A1**: 360° scan, 640 samples, range 0.164–12m
- **IMU**: In Create3 base

Meshes from `/opt/ros/jazzy/share/turtlebot4_description/meshes/`.

## Message Helpers

```gdscript
var header = StdMsgs.create_header_now("base_link")
var twist = GeometryMsgs.create_twist(Vector3(1.0, 0, 0), Vector3.ZERO)
var scan = SensorMsgs.create_laserscan(header, -PI, PI, 0.01, 0.0, 0.1, 0.1, 30.0, ranges, intensities)
```

## When to Use Copernicus vs Full Simulators

| Use Case | Tool |
|----------|------|
| Quick robot design iteration | **Copernicus** |
| Testing joint configurations | **Copernicus** |
| Visualizing URDF models | **Copernicus** |
| Sensor data streaming | **Copernicus** |
| Research-grade physics | Isaac Sim / Gazebo |
| Motion planning | MoveIt / Nav2 |
| Controller development | Copernicus → full simulator |

## Troubleshooting

**"Topic does not appear to be published yet"**
- Cause: ROS_DOMAIN_ID mismatch
- Fix: `export ROS_DOMAIN_ID=0`

**Bridge starts but messages don't reach ROS**
- Check: Is ROS_DOMAIN_ID set consistently?
- Check: View bridge logs at `/tmp/bridge.log`

```bash
tail -f /tmp/bridge.log
```
