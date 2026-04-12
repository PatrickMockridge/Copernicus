# Core Concepts

This document explains the fundamental concepts behind Copernicus's design.

---

## 1. What is a Robot?

In Copernicus, a robot is a hierarchical scene tree:

```
RobotRoot (Node3D)
├── BaseLink (MeshInstance3D + CollisionShape3D)
│   └── Joint (PinJoint3D)
│       └── MidLink (MeshInstance3D + CollisionShape3D)
│           └── Joint (SliderJoint3D)
│               └── EndEffector (MeshInstance3D + CollisionShape3D)
```

Each link has:
- **Visual**: `MeshInstance3D` for rendering
- **Collision**: `CollisionShape3D` for physics

Each joint has:
- **Type**: Pin (rotation), Slider (translation), Fixed
- **Axis**: Rotation/translation direction
- **Limits**: Min/max positions

---

## 2. Physics Simulation

### Godot Native (VehicleBody3D)

Best for: Fast iteration, game-like physics

```gdscript
var vehicle = VehicleBody3D.new()
vehicle.mass = 5.0
# Godot handles collision detection and response
```

**Pros:** Fast, native integration, built-in vehicle physics
**Cons:** Not research-grade accuracy

### PyBullet (Research Grade)

Best for: Manipulation, locomotion research

```gdscript
var physics = PyBulletBackend.new()
physics.initialize({"gravity": Vector3(0, -9.81, 0)})
physics.step_simulation(delta)
```

**Pros:** Accurate joint constraints, contact modeling
**Cons:** Requires Python, slower than native

### PyBullet CUDA (GPU)

Best for: High-fidelity simulation with GPU acceleration

```gdscript
var physics = CUDAPhysics.new()
physics.initialize({"use_cuda": true})
```

---

## 3. Sensors

### LIDAR (Laser Scanning)

Simulates 2D laser range finder:

```gdscript
var lidar = LidarSensor.new("front_lidar")
lidar.set_angle_range(-PI/2, PI/2)  # 180° scan
lidar.set_range_limits(0.1, 30.0)  # 10cm to 30m
```

**Noise models:**
- Range noise (increases with distance²)
- Beam divergence (~1° typical)
- Ambient light interference

### Camera

Renders viewport with lens distortion:

```gdscript
var camera = CameraSensor.new("front_camera")
camera.set_fov(1.047)  # ~60 degrees
camera.configure({
    "lens_distortion": {"k1": 0.1, "k2": 0.01}
})
```

**Noise models:**
- Gaussian noise
- Salt-and-pepper noise
- Brown-Conrady lens distortion

### IMU (Inertial Measurement Unit)

Measures acceleration and angular velocity:

```gdscript
var imu = ImuSensor.new("imu")
imu.set_update_rate(100.0)  # 100 Hz
```

**Noise models:**
- Bias drift (random walk)
- Scale factor error
- Temperature dependence

---

## 4. Control Systems

### Open-Loop Control

Sends commands without feedback:

```gdscript
# Move joint to position 0.5 radians
joint.set_param(PhysicsServer3D.JOINT_PARAM_BIAS, 0.5)
```

### Closed-Loop Control (PID)

Uses feedback to correct errors:

```gdscript
var pid = PIDController.new(10.0, 0.5, 1.0)  # Kp, Ki, Kd
pid.set_anti_windup(100.0)

var error = target_position - current_position
var output = pid.compute_output(error, delta)
apply_force(output)
```

### Differential Drive

Kinematic model for wheeled robots:

```gdscript
# Left and right wheel velocities
var v_left = linear_vel - angular_vel * wheel_base / 2
var v_right = linear_vel + angular_vel * wheel_base / 2

# Apply to wheels
front_left_wheel.engine_force = v_left
front_right_wheel.engine_force = v_right
```

---

## 5. Reinforcement Learning

### The RL Loop

```
Agent (Robot)
    │
    ▼ observes state
Environment (Copernicus)
    │
    ▼ takes action
    │
    ▼ gets reward
    │
    ▼ learns
    │
    ▼ repeats
```

### State-Action-Reward

```gdscript
# Observation (state)
var state = [robot_position.x, robot_position.z, lidar_ranges[0], ...]

# Action (discrete)
var action = learner.get_action(state)  # Returns 0-3

# Reward
var reward = 1.0 if close_to_goal else -0.1

# Training step
learner.train_step([state], [action], [reward])
```

### Algorithm Comparison

| Algorithm | Action Space | Exploration | Sample Efficiency |
|-----------|-------------|-------------|-------------------|
| DQN | Discrete | ε-greedy | Medium |
| PPO | Continuous | On-policy | Low |
| SAC | Continuous | Entropy | High |

---

## 6. Navigation

### A* Grid Planner (Pure GDScript)

Finds shortest path on 2D occupancy grid:

```gdscript
var planner = AStarGridPlanner.new()
planner.set_grid_size(100, 100)
planner.set_start([0, 0])
planner.set_goal([50, 50])
var path = planner.plan()  # Returns array of [x, y] points
```

**Pros:** No ROS 2 required, fast
**Cons:** Grid-based, not continuous

### Nav2 (ROS 2)

Industry-standard navigation stack:

```gdscript
var nav = Nav2Bridge.new()
nav.initialize({"group_name": "manipulator"})
nav.set_pose_goal(target_pose)
```

**Pros:** SLAM, global planning, recovery behaviors
**Cons:** Requires ROS 2

---

## 7. Inverse Kinematics (IK)

### CCD (Cyclic Coordinate Descent)

Iterative joint-by-joint solver:

```gdscript
var ik = AnalyticalIKSolver.new()
ik.set_algorithm(ik.CCD)
ik.solve(chain, target_position)
```

**Pros:** Fast, simple
**Cons:** May not converge for long chains

### FABRIK (Forward And Backward Reaching IK)

Natural chain-based solver:

```gdscript
ik.set_algorithm(ik.FABRIK)
ik.set_max_iterations(20)
ik.solve(chain, target_position)
```

**Pros:** Natural motion, faster convergence
**Cons:** Requires full chain visibility

### MoveIt (ROS 2)

Industry-grade IK via ROS 2:

```gdscript
var moveit = MoveItIKBridge.new()
moveit.initialize({"group_name": "manipulator"})
moveit.solve(chain, target_position)
```

---

## 8. ROS 2 Integration

### Sensor Data Flow

```
Copernicus (TCP/UDP) → ROS 2
    │
    ├── /robot/scan (LaserScan)
    ├── /robot/odom (Odometry)
    ├── /robot/image_raw (Image)
    └── /robot/imu (Imu)
```

### Control Data Flow

```
ROS 2 → Copernicus (TCP/UDP)
    │
    └── /robot/cmd_vel (Twist)
```

### Bridge Protocol

```json
// Sensor data (UDP)
{"topic": "/robot/scan", "data": [...], "stamp": 1234567890}

// Control command (TCP)
{"topic": "/robot/cmd_vel", "linear": [0.5, 0, 0], "angular": [0, 0, 0.2]}
```

---

## Key Takeaways

1. **Robot = Scene tree** — Links are nodes, joints are connections
2. **Physics = Swappable** — Use Godot for speed, PyBullet for accuracy
3. **Sensors = Models** — Real sensors have noise; simulate it
4. **Control = PID** — For closed-loop, use PID with anti-windup
5. **RL = State-Action-Reward** — DQN for discrete, PPO/SAC for continuous
6. **Navigation = A* or Nav2** — Grid-based or industry-standard
7. **IK = CCD or FABRIK** — Analytical solvers, or MoveIt for ROS 2
8. **ROS 2 = TCP/UDP bridge** — Copernicus speaks ROS 2 via JSON over sockets