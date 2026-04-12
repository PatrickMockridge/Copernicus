# Sensors Overview

Copernicus provides realistic sensor simulation for LIDAR, cameras, and IMU devices.

---

## Available Sensors

| Sensor | Output | Use Case |
|--------|--------|----------|
| **LIDAR** | LaserScan (ranges) | Navigation, obstacle detection |
| **Camera** | Image (RGB) | Perception, visual SLAM |
| **IMU** | Imu (accel + gyro) | State estimation, odometry |
| **GPS** | NavSatFix (lat/lon) | Outdoor navigation |
| **Contact** | Contact (force) | Manipulation, grasp detection |
| **Force/Torque** | Wrench (F+T) | Force feedback |

---

## LIDAR Sensor

Simulates 2D/3D laser range scanning.

### Basic Usage

```gdscript
var lidar = LidarSensor.new("front_lidar")
lidar.set_angle_range(-PI/2, PI/2)  # 180° scan
lidar.set_range_limits(0.1, 30.0)     # 10cm to 30m
lidar.set_increment(0.0174533)        # ~1 degree resolution
```

### Configuration

```gdscript
lidar.configure({
    "angle_min": -PI,
    "angle_max": PI,
    "range_min": 0.1,
    "range_max": 30.0,
    "increment": 0.0174533,  # ~1 degree
    "beam_divergence": 0.018,  # ~1 degree typical
    "range_noise": 0.01,  # stddev in meters
    "topic": "scan"
})
```

### Raycast Implementation

```gdscript
func _perform_raycast(origin: Vector3, direction: Vector3) -> float:
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * _range_max)
    query.collide_with_bodies = true

    var result = space_state.intersect_ray(query)
    if result:
        return origin.distance_to(result.position)
    return _range_max
```

### Noise Model

Real LIDAR has noise:
- Range noise increases with distance²
- Beam divergence adds angular uncertainty

```gdscript
func _apply_range_noise(range_value: float) -> float:
    # Noise increases with distance squared
    var distance_factor = range_value * range_value * 0.0001
    var total_stddev = _range_stddev + distance_factor
    return Sensor.gaussian_noise(range_value, 0.0, total_stddev)
```

---

## Camera Sensor

Renders viewport or performs raycast-based depth estimation.

### Basic Usage

```gdscript
var camera = CameraSensor.new("front_camera")
camera.set_fov(1.047)  # ~60 degrees
camera.set_resolution(640, 480)
```

### Lens Distortion

Brown-Conrady model for realistic camera distortion:

```gdscript
camera.configure({
    "lens_distortion": {
        "k1": 0.1,
        "k2": 0.01,
        "p1": 0.0,
        "p2": 0.0,
        "cx_offset": 0.0,
        "cy_offset": 0.0
    }
})
```

### Applying Distortion

```gdscript
func apply_lens_distortion(point: Vector2) -> Vector2:
    var x = point.x + _cx_offset
    var y = point.y + _cy_offset

    # Radial distortion
    var r2 = x * x + y * y
    var radial = 1.0 + r2 * (_k1 + _k2 * r2)

    # Tangential distortion
    var tx = 2.0 * _p1 * x * y + _p2 * (r2 + 2.0 * x * x)
    var ty = _p1 * (r2 + 2.0 * y * y) + 2.0 * _p2 * x * y

    return Vector2(radial * x + tx, radial * y + ty)
```

### Noise Models

```gdscript
# Gaussian noise
var noisy_pixel = Sensor.gaussian_noise(pixel_value, 0.0, stddev)

# Salt-and-pepper noise
if randf() < prob:
    return 0.0
elif randf() < prob:
    return 255.0
```

---

## IMU Sensor

Inertial Measurement Unit for acceleration and angular velocity.

### Basic Usage

```gdscript
var imu = ImuSensor.new("imu")
imu.set_update_rate(100.0)  # 100 Hz
imu.configure({
    "noise": {
        "gyro_bias_stddev": 0.001,
        "accel_bias_stddev": 0.01,
        "gyro_drift_rate": 0.0001
    }
})
```

### Noise Model

IMU noise includes:
- **Bias drift**: Random walk over time
- **Scale factor error**: Linear gain error
- **White noise**: Instantaneous random variation

```gdscript
func apply_gyro_noise(gyro: Vector3, dt: float) -> Vector3:
    # Bias drifts as random walk
    var drift = Sensor.imu_bias_noise(0.0, _gyro_drift_rate, dt)
    return gyro + drift + Vector3(randfn(0, _white_noise_stddev),
                                  randfn(0, _white_noise_stddev),
                                  randfn(0, _white_noise_stddev))
```

---

## ROS 2 Message Flow

```
Copernicus Sensors
    │
    ▼
ROS 2 Messages
    │
    ├── /robot/scan (sensor_msgs/LaserScan)
    ├── /robot/image_raw (sensor_msgs/Image)
    ├── /robot/imu (sensor_msgs/Imu)
    ├── /robot/gps (sensor_msgs/NavSatFix)
    └── /robot/contact (geometry_msgs/WrenchStamped)
    │
    ▼
ROS 2 Network
```

### Creating ROS Messages

```gdscript
func publish_lidar(publisher: Publisher, lidar: LidarSensor):
    var header = StdMsgs.create_header_now("base_link")
    var scan_msg = lidar.get_scan_message(header)
    publisher.publish(scan_msg)
```

---

## Sensor Placement

### In Robot Hierarchy

```
RobotRoot
├── base_link
│   └── sensor_mount (Node3D at offset)
│       ├── front_lidar (LidarSensor)
│       ├── front_camera (CameraSensor)
│       └── imu_link (ImuSensor)
```

### Transform Broadcasting

```gdscript
func broadcast_sensor_transforms():
    # LIDAR at base_link + offset
    var lidar_tf = Transform3D(Basis.IDENTITY, Vector3(0.1, 0.2, 0))
    broadcaster.send_transform("base_link", "front_lidar", lidar_tf)

    # Camera at base_link + offset
    var camera_tf = Transform3D(Basis.IDENTITY, Vector3(0.05, 0.15, 0))
    broadcaster.send_transform("base_link", "front_camera", camera_tf)
```

---

## Multi-Sensor Fusion

Combine sensors for better state estimation:

```gdscript
class_name SensorFusion

var _lidar: LidarSensor
var _imu: ImuSensor
var _kf: KalmanFilter  # Placeholder

func update():
    # Get measurements
    var lidar_ranges = _lidar.get_ranges()
    var imu_data = _imu.get_angular_velocity()

    # Update filter
    var observation = combine_observations(lidar_ranges, imu_data)
    var state = _kf.update(observation)

    return state
```

---

## Performance Considerations

- LIDAR resolution affects raycast count (360 rays at 1° vs 360° at 0.5°)
- Camera rendering is expensive; consider lower resolution or periodic capture
- IMU updates don't require physics queries; can run at high rate
- Consider GPU raycasting for batch LIDAR operations

---

## See Also

- [Noise Models](noise-models.md) — Detailed sensor noise modeling
- [Control](../robots/control.md) — Using sensor feedback in control loops
- [Physics Backends](../physics/backends.md) — Physics simulation options
- [ROS 2 Bridge](../ros2/bridge.md) — Publishing sensor data to ROS 2