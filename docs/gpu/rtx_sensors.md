# GPU Sensors

GPU-accelerated sensor simulation using NVIDIA RTX ray tracing and CUDA for realistic LIDAR and camera simulation.

---

## Overview

GPU Sensors provides hardware-accelerated sensor simulation:

| Sensor | Technology | Description |
|--------|------------|-------------|
| `RTXLidar` | RTX ray tracing | GPU-accelerated LIDAR with realistic beam modeling |
| `RTXCamera` | Path tracing | GPU path tracing for camera with global illumination |
| `SensorFusion` | Multi-sensor | Combines sensors for unified perception |

**Requirements:**
- NVIDIA GPU with CUDA support
- PyTorch with CUDA (for RTX LIDAR)

---

## RTXLidar

GPU ray tracing LIDAR sensor using PyTorch CUDA for realistic LIDAR simulation.

### Available Models

```gdscript
var lidar = RTXLidar.new()

# Configure model
lidar.configure_laser("Velodyne VLP-16")
lidar.configure_laser("Velodyne HDL-32E")
lidar.configure_laser("Velodyne HDL-64E")
lidar.configure_laser("Ouster OS1-64")
lidar.configure_laser("Robosense RS-LiDAR-16")
lidar.configure_laser("Hesai Pandar XT32")
```

### Supported Models

| Model | Rings | Vertical FOV | Max Range |
|-------|-------|--------------|-----------|
| Velodyne VLP-16 | 16 | 30° | 100m |
| Velodyne HDL-32E | 32 | 41.33° | 70m |
| Velodyne HDL-64E | 64 | 26.8° | 120m |
| Ouster OS1-64 | 64 | 45° | 240m |

### Initialization

```gdscript
var lidar = RTXLidar.new()

var config = {
    "model": "Velodyne VLP-16",
    "max_range": 100.0,
    "min_range": 0.5,
    "noise_model": "gaussian",
    "noise_scale": 0.02
}

lidar.initialize(config)
add_child(lidar)
lidar.global_position = Vector3(0, 1.5, 0)
```

### Scanning

```gdscript
# Full 360° scan
var point_cloud = lidar.scan()

# Continuous scanning
func _process(delta):
    var points = lidar.scan_continuous(delta)
    # Update visualization
```

### Configuration

```gdscript
# Set rotation rate (Hz)
lidar.set_rotation_rate(10.0)

# Noise parameters
lidar.set_noise_parameters(0.02, 0.0, 0.02)

# Noise models: "gaussian", "uniform", "none"
lidar.set_noise_model("gaussian")
```

### Point Cloud Access

```gdscript
# Get raw point cloud
var points = lidar.get_point_cloud()
# Each point: [x, y, z, intensity]

# Get as Godot vertices for visualization
var vertices = lidar.get_points_as_vertices()

# Get range image (360xN)
var range_img = lidar.get_range_image()
```

---

## RTXCamera

GPU path tracing camera sensor with global illumination and realistic noise.

### Available Models

```gdscript
var camera = RTXCamera.new()

# Configure model
camera.configure_camera("Intel RealSense D455")
camera.configure_camera("Azure Kinect DK")
camera.configure_camera("ZED 2i")
```

### Supported Models

| Model | Resolution | FOV | Depth |
|-------|-------------|-----|-------|
| Intel RealSense D455 | 640x480 | 87° | Yes |
| Azure Kinect DK | 640x576 | 120° | Yes |
| ZED 2i | 1280x720 | 110° | Yes |

### Initialization

```gdscript
var camera = RTXCamera.new()

var config = {
    "model": "Intel RealSense D455",
    "color_enabled": true,
    "depth_enabled": true
}

camera.initialize(config)
add_child(camera)
camera.global_position = Vector3(0, 1.5, 0)
camera.look_at(Vector3(1, 1.5, 1))
```

### Capturing

```gdscript
# Capture both color and depth
var result = camera.capture()
var color = result["color"]
var depth = result["depth"]
var timestamp = result["timestamp"]

# Or capture individually
var color = camera.capture_color()
var depth = camera.capture_depth()
```

### Intrinsics

```gdscript
# Get camera intrinsics
var intrinsics = camera.get_intrinsics()
# { fx, fy, cx, cy, k1, k2, p1, p2, width, height }

# Custom intrinsics
camera.set_intrinsics(554.0, 554.0, 320.0, 240.0)

# Distortion coefficients
camera.set_distortion(0.0, 0.0, 0.0, 0.0)
```

### Noise

```gdscript
# Color noise (stddev in RGB space)
camera.set_color_noise(10.0)

# Depth noise (model: "spatial", "temporal", "gaussian")
camera.set_depth_noise("spatial", 0.02)
```

### Signal

```gdscript
camera.frame_captured.connect(func(color, depth):
    process_frame(color, depth)
)
```

---

## SensorFusion

Multi-sensor fusion combining LIDAR, camera, IMU, and GPS for unified perception.

### Initialization

```gdscript
var fusion = SensorFusion.new()

var config = {
    "fusion_mode": "kalman",  # kalman, extended_kalman, particle
    "update_rate": 100.0  # Hz
}

fusion.initialize(config)
add_child(fusion)
```

### Sensor Registration

```gdscript
# Register sensors
fusion.set_lidar(lidar)
fusion.set_camera(camera)
fusion.set_imu(imu_node)
fusion.set_gps(gps_node)
```

### State Estimation

```gdscript
# Perform fusion
var state = fusion.fuse_sensors()
var position = state["position"]
var velocity = state["velocity"]
var orientation = state["orientation"]

# Direct access
var pos = fusion.get_position()
var vel = fusion.get_velocity()
var ori = fusion.get_orientation()
```

### Odometry

```gdscript
func _process(delta):
    var odom = fusion.compute_odometry(delta)
    var pos = odom["position"]
    var vel = odom["velocity"]
    var acc = odom["acceleration"]
```

### SLAM Integration

```gdscript
# Get map data for SLAM
var map_data = fusion.get_map_data()
var point_cloud = map_data["point_cloud"]
var occupancy_grid = map_data["occupancy_grid"]
```

### History

```gdscript
# Get position/velocity history
var pos_history = fusion.get_position_history()
var vel_history = fusion.get_velocity_history()
```

---

## GPU Backend Selector

Run the GPU backend selector scene to choose sensor configurations:

```bash
godot scenes/gpu/gpu_backend_selector.tscn
```

This provides a UI for:
- Selecting LIDAR model and parameters
- Choosing camera model and resolution
- Configuring sensor fusion mode

---

## Requirements

- NVIDIA GPU with CUDA support
- PyTorch with CUDA (for RTX LIDAR path tracing)

```bash
# Check CUDA availability
nvidia-smi

# Check PyTorch CUDA
python3 -c "import torch; print(torch.cuda.is_available())"
```

---

## See Also

- [Sensor Overview](../sensors/overview.md) - LIDAR, camera, IMU simulation
- [Sensor Noise Models](../sensors/noise-models.md) - Realistic noise modeling
- [GPU Raycasting](../rl/overview.md) - Deep reinforcement learning
- [Isaac Gym](../rl/isaac-gym.md) - GPU training with synthetic sensors
