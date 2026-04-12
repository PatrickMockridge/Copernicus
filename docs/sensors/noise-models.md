# Sensor Noise Models

Real sensors have noise. Copernicus provides realistic noise models for accurate simulation.

---

## Why Sensor Noise?

Simulated sensors without noise lead to:
- Over-confident state estimation
- Broken feedback loops (perfect sensors don't need filtering)
- Algorithms that work in sim but fail in reality

Adding realistic noise forces you to:
- Use Kalman filters or particle filters
- Handle measurement ambiguity
- Build robust controllers

---

## Base Noise Functions

### Gaussian Noise

```gdscript
static func gaussian_noise(value: float, mean: float, stddev: float) -> float:
    return value + randfn(mean, stddev)
```

Adds normally distributed noise: `N(μ, σ²)`

### Distance-Dependent Noise

```gdscript
# Noise that increases with distance (common for range sensors)
func range_dependent_noise(range: float, base_stddev: float, factor: float) -> float:
    var distance_noise = range * range * factor
    return gaussian_noise(range, 0, base_stddev + distance_noise)
```

---

## LIDAR Noise Models

### Range Noise

LIDAR range noise typically:
- Has a minimum floor (sensor resolution)
- Increases with distance² (due to beam divergence)

```gdscript
static func lidar_range_noise(range: float, params: Dictionary) -> float:
    var stddev = params.get("range_stddev", 0.01)
    var distance_factor = range * range * 0.001
    return gaussian_noise(range, 0, stddev + distance_factor)
```

### Beam Divergence

Real LIDAR beams have angular spread:

```gdscript
func apply_beam_divergence(angle: float, divergence: float) -> float:
    # Beam divergence adds angular uncertainty
    var noise = randfn(0, divergence * 0.5)
    return angle + noise
```

### Complete LIDAR Noise

```gdscript
func lidar_measurement(range: float, angle: float, params: Dictionary) -> Dictionary:
    return {
        "range": lidar_range_noise(range, params),
        "angle": apply_beam_divergence(angle, params.get("beam_divergence", 0.018)),
        "intensity": gaussian_noise(1.0, 0, params.get("intensity_stddev", 0.1))
    }
```

### Typical LIDAR Parameters

| Parameter | Typical Value | Description |
|-----------|---------------|-------------|
| range_stddev | 0.01 m | Base range noise |
| beam_divergence | 0.018 rad (~1°) | Angular beam spread |
| intensity_stddev | 0.1 | Return intensity noise |
| min_range | 0.1 m | Sensor minimum |
| max_range | 30.0 m | Sensor maximum |

---

## Camera Noise Models

### Gaussian Noise

For image sensor readout noise:

```gdscript
static func camera_gaussian_noise(value: float, stddev: float) -> float:
    return clamp(value + randfn(0, stddev), 0, 255)
```

### Salt-and-Pepper Noise

For dead pixels, hot pixels, or transmission errors:

```gdscript
static func camera_salt_pepper_noise(value: float, prob: float) -> float:
    if randf() < prob:
        return 0.0
    elif randf() < prob:
        return 255.0
    return value
```

### Combined Camera Noise

```gdscript
func apply_camera_noise(pixel: float, params: Dictionary) -> float:
    # Gaussian read noise
    pixel = camera_gaussian_noise(pixel, params.get("read_noise_stddev", 2.0))

    # Salt and pepper
    pixel = camera_salt_pepper_noise(pixel, params.get("salt_pepper_prob", 0.01))

    return pixel
```

### Typical Camera Parameters

| Parameter | Typical Value | Description |
|-----------|---------------|-------------|
| read_noise_stddev | 2.0 (8-bit) | Read noise sigma |
| salt_pepper_prob | 0.01 | Probability of dead/hot pixel |
| dark_current | 0.5 e-/s | Thermal noise |
| quantum_efficiency | 0.6 | Photon to electron conversion |

---

## IMU Noise Models

### Gyroscope Noise

```gdscript
# Random walk bias drift
func gyro_bias_drift(bias: float, drift_rate: float, dt: float) -> float:
    return bias + randfn(0, drift_rate * sqrt(dt))

# Complete gyroscope noise
func gyroscope_noise(omega: float, params: Dictionary, dt: float) -> float:
    var bias_drift = gyro_bias_drift(0, params.get("gyro_drift_rate", 0.0001), dt)
    var white_noise = randfn(0, params.get("gyro_white_noise", 0.001))
    return omega + bias_drift + white_noise
```

### Accelerometer Noise

```gdscript
# Scale factor error
func accel_scale_error(accel: float, scale_error: float) -> float:
    return accel * (1.0 + scale_error * randfn(0, 1))

# Complete accelerometer noise
func accelerometer_noise(accel: float, params: Dictionary, dt: float) -> float:
    var bias_drift = gyro_bias_drift(0, params.get("accel_drift_rate", 0.0005), dt)
    var white_noise = randfn(0, params.get("accel_white_noise", 0.01))
    return accel * (1.0 + randfn(0, params.get("scale_factor_stddev", 0.001))) + bias_drift + white_noise
```

### Typical IMU Parameters

| Parameter | Typical Value | Description |
|-----------|---------------|-------------|
| gyro_white_noise | 0.001 rad/s | White noise amplitude |
| gyro_drift_rate | 0.0001 rad/s/√s | Bias instability |
| accel_white_noise | 0.01 m/s² | White noise amplitude |
| accel_drift_rate | 0.0005 m/s²/√s | Bias instability |
| scale_factor_stddev | 0.001 | Scale factor error |

---

## GPS Noise Models

### Position Noise

```gdscript
func gps_position_noise(lat: float, lon: float, params: Dictionary) -> Dictionary:
    return {
        "latitude": gaussian_noise(lat, 0, params.get("lat_stddev", 1.5)),
        "longitude": gaussian_noise(lon, 0, params.get("lon_stddev", 1.5)),
        "altitude": gaussian_noise(altitude, 0, params.get("alt_stddev", 5.0))
    }
```

### Availability and Precision

GPS noise varies by environment:
- **Open sky**: ~1-2m CEP
- **Urban canyon**: ~5-10m CEP
- **Indoor**: Unavailable

```gdscript
func gps_availabilityindoor() -> bool:
    return false

func gps_availability(outdoor: bool, sky_visibility: float) -> bool:
    if not outdoor:
        return false
    if sky_visibility < 0.3:  # Less than 30% sky visibility
        return false
    return true
```

---

## Contact Sensor Noise

### Force/Torque Noise

```gdscript
func contact_force_noise(force: Vector3, params: Dictionary) -> Vector3:
    var noise_stddev = params.get("force_stddev", 0.5)
    return Vector3(
        gaussian_noise(force.x, 0, noise_stddev),
        gaussian_noise(force.y, 0, noise_stddev),
        gaussian_noise(force.z, 0, noise_stddev)
    )
```

---

## Noise Parameter Configuration

### Via Sensor Configuration

```gdscript
var lidar = LidarSensor.new("lidar")
lidar.configure({
    "beam_divergence": 0.018,  # ~1 degree
    "range_noise": 0.01,
    "noise": {
        "range_stddev": 0.01,
        "intensity_stddev": 0.1
    }
})

var camera = CameraSensor.new("camera")
camera.configure({
    "noise_stddev": 2.0,
    "salt_pepper_prob": 0.01,
    "lens_distortion": {
        "k1": 0.1,
        "k2": 0.01
    }
})
```

### Via Sensor Class

```gdscript
# Directly set noise parameters
lidar.set_range_noise(0.01)
lidar.set_beam_divergence(0.018)
camera._noise_stddev = 2.0
camera._salt_pepper_prob = 0.01
```

---

## Testing Noise Models

### Visual Validation

```gdscript
func test_noise():
    var lidar = LidarSensor.new("test_lidar")
    lidar.set_range_limits(0.1, 10.0)
    lidar.set_beam_divergence(0.018)
    lidar.set_range_noise(0.01)

    # Print range measurements
    for i in range(10):
        var noisy = lidar._apply_range_noise(5.0)  # True range = 5m
        print("Measurement %d: %.3f (true: 5.000)" % [i, noisy])
```

### Statistical Validation

Check that noise follows expected distribution:

```gdscript
func validate_gaussian_noise(samples: Array, expected_stddev: float) -> bool:
    var mean = samples.reduce(func(a, b): return a + b) / float(samples.size())
    var variance = samples.map(func(x): return pow(x - mean, 2)).reduce(func(a, b): return a + b) / float(samples.size())
    var measured_stddev = sqrt(variance)

    # Check within 10% of expected
    return abs(measured_stddev - expected_stddev) / expected_stddev < 0.1
```

---

## See Also

- [Sensors Overview](overview.md) — Sensor introduction
- [Control](../robots/control.md) — Using noisy sensors in control
- [ROS 2 Bridge](../ros2/bridge.md) — Publishing sensor data