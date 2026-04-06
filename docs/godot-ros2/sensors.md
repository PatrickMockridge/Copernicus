# Sensors

Sensor classes for robot perception. All sensors extend the base `Sensor` class.

## Base Sensor (sensor.gd)

```gdscript
class_name Sensor
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `_update_rate` | float | 30.0 | Update frequency in Hz |
| `_enabled` | bool | true | Sensor active state |
| `_frame_id` | String | "" | TF frame identifier |
| `_pose` | Transform3D | IDENTITY | Sensor transform |

### Methods

#### `get_name() -> String`
Returns the sensor name.

#### `get_node() -> Node3D`
Returns the parent node.

#### `set_robot(robot: Node3D) -> void`
Set the parent robot.

#### `get_robot() -> Node3D`
Get the parent robot.

#### `set_frame_id(frame: String) -> void`
Set the TF frame ID.

#### `get_frame_id() -> String`
Get the TF frame ID.

#### `set_update_rate(rate: float) -> void`
Set the update rate in Hz.

#### `get_update_rate() -> float`
Get the update rate.

#### `set_enabled(enabled: bool) -> void`
Enable or disable the sensor.

#### `is_enabled() -> bool`
Check if sensor is enabled.

#### `set_pose(pose: Transform3D) -> void`
Set the sensor pose.

#### `get_pose() -> Transform3D`
Get the sensor pose.

#### `set_noise_enabled(enabled: bool) -> void`
Enable sensor noise.

#### `configure(params: Dictionary) -> void`
Configure from dictionary. Supports keys:
- `update_rate`
- `frame_id`
- `pose`
- `noise`

#### `should_update(current_time: float) -> bool`
Check if sensor should update based on rate.

#### `get_header() -> Dictionary`
Get a ROS header with stamp and frame_id.

---

## LidarSensor (lidar_sensor.gd)

2D/3D LIDAR sensor.

```gdscript
class_name LidarSensor
extends Sensor
```

### Configuration

```gdscript
var lidar = LidarSensor.new("front_lidar")
lidar.set_angle_range(-PI, PI)       # Full 360 scan
lidar.set_increment(0.0174533)       # ~1 degree resolution
lidar.set_range_limits(0.1, 30.0)    # 10cm to 30m
lidar.set_scan_time(0.1)             # 10Hz scan rate
```

### Methods

#### `set_angle_range(angle_min: float, angle_max: float) -> void`
Set the scan angle range (radians).

#### `set_increment(inc: float) -> void`
Set the angular resolution (radians).

#### `set_range_limits(min_range: float, max_range: float) -> void`
Set min/max range (meters).

#### `set_scan_time(time: float) -> void`
Set scan time (seconds).

#### `set_publish_topic(topic: String) -> void`
Set ROS topic name.

#### `get_scan_message(header: Dictionary) -> Dictionary`
Get a `sensor_msgs/LaserScan` message.

### ROS Topic

- Topic: `scan` (configurable)
- Type: `sensor_msgs/LaserScan`

---

## CameraSensor (camera_sensor.gd)

RGB/depth camera sensor.

```gdscript
class_name CameraSensor
extends Sensor
```

### Configuration

```gdscript
var camera = CameraSensor.new("rgb_camera")
camera.set_fov(1.047)              # ~60 degrees
camera.set_near(0.1)              # 10cm near plane
camera.set_far(100.0)             # 100m far plane
camera.set_resolution(640, 480)   # Resolution
camera.set_publish_topic("image_raw")
```

### Methods

#### `set_fov(fov: float) -> void`
Set field of view (radians).

#### `set_near(near: float) -> void`
Set near clipping plane (meters).

#### `set_far(far: float) -> void`
Set far clipping plane (meters).

#### `set_resolution(width: int, height: int) -> void`
Set image resolution.

#### `set_publish_topic(topic: String) -> void`
Set ROS topic name.

#### `get_projection_matrix() -> Projection`
Get camera projection matrix.

#### `render_viewport(camera: Camera3D) -> Image`
Render viewport to image.

### ROS Topic

- Topic: `image_raw` (configurable)
- Type: `sensor_msgs/Image`

---

## ImuSensor (imu_sensor.gd)

IMU sensor for orientation and acceleration.

```gdscript
class_name ImuSensor
extends Sensor
```

### Configuration

```gdscript
var imu = ImuSensor.new("imu")
imu.set_publish_topic("imu")
```

### Methods

#### `set_publish_topic(topic: String) -> void`
Set ROS topic name.

#### `update_meas(orientation: Quaternion, angular_vel: Vector3, linear_accel: Vector3) -> void`
Update sensor measurements.

#### `get_imu_message(header: Dictionary) -> Dictionary`
Get a `sensor_msgs/Imu` message.

### ROS Topic

- Topic: `imu` (configurable)
- Type: `sensor_msgs/Imu`

---

## GPSSensor (gps_sensor.gd)

GPS positioning sensor.

```gdscript
class_name GPSSensor
extends Sensor
```

### ROS Topic

- Topic: `gps`
- Type: `sensor_msgs/NavSatFix`

---

## ForceTorqueSensor (force_torque_sensor.gd)

Force/torque measurement sensor.

```gdscript
class_name ForceTorqueSensor
extends Sensor
```

### ROS Topic

- Topic: `ft`
- Type: `geometry_msgs/Wrench`

---

## ContactSensor (contact_sensor.gd)

Contact detection sensor.

```gdscript
class_name ContactSensor
extends Sensor
```

### ROS Topic

- Topic: `contact`
- Type: `sensor_msgs/PointCloud`

---

## Usage Example

```gdscript
extends Node3D

var sim: ROS2Simulator
var robot: RobotModel
var lidar: LidarSensor
var camera: CameraSensor
var imu: ImuSensor

func _ready() -> void:
    sim = ROS2Simulator.new()
    add_child(sim)

    robot = sim.create_simple_diff_robot("my_robot", "", "", "", Transform3D.IDENTITY)

    # Add LIDAR
    lidar = sim.add_lidar_to_robot(robot, "lidar", {
        "angle_min": -PI,
        "angle_max": PI,
        "range_min": 0.1,
        "range_max": 30.0
    })

    # Add camera
    camera = sim.add_camera_to_robot(robot, "camera", {
        "fov": 1.047,
        "width": 640,
        "height": 480
    })

    # Add IMU
    imu = sim.add_imu_to_robot(robot, "imu", {})

    # Access sensor data
    var header = imu.get_header()
    var imu_msg = imu.get_imu_message(header)
```

## Source Files

| Class | File |
|-------|------|
| `Sensor` | `sensors/sensor.gd` |
| `LidarSensor` | `sensors/lidar_sensor.gd` |
| `CameraSensor` | `sensors/camera_sensor.gd` |
| `ImuSensor` | `sensors/imu_sensor.gd` |
| `GPSSensor` | `sensors/gps_sensor.gd` |
| `ForceTorqueSensor` | `sensors/force_torque_sensor.gd` |
| `ContactSensor` | `sensors/contact_sensor.gd` |
