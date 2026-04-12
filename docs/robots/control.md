# Robot Control

This guide covers controlling robot joints and implementing closed-loop control systems.

---

## Joint Control Basics

### Reading Joint State

```gdscript
func get_joint_state(joint: Node3D) -> Dictionary:
    var state = {
        "position": joint.position,
        "rotation": joint.rotation_degrees,
        "velocity": Vector3.ZERO  # Would need tracking over time
    }

    if joint is PinJoint3D:
        state["angle"] = joint.rotation
        state["angular_velocity"] = 0.0  # Would need tracking

    return state
```

### Writing Joint Commands

```gdscript
func set_joint_target(joint: Node3D, target: float) -> void:
    if joint is PinJoint3D:
        # Use physics to drive joint to target
        joint.set_param(Joint3D.PARAM_BIAS, target)
```

---

## Differential Drive Kinematics

For wheeled robots with two independently driven wheels:

### Theory

Given robot linear velocity `v` and angular velocity `ω`:

```
v_left = v - ω * wheel_base / 2
v_right = v + ω * wheel_base / 2
```

### Implementation

```gdscript
class_name DifferentialDrive

var _wheel_base: float = 0.3  # Distance between wheels (meters)
var _wheel_radius: float = 0.05  # Wheel radius (meters)

var _linear_vel: float = 0.0
var _angular_vel: float = 0.0

var _front_left_wheel: VehicleWheel3D
var _front_right_wheel: VehicleWheel3D


func apply_cmd_vel(linear: float, angular: float) -> void:
    _linear_vel = linear
    _angular_vel = angular

    # Compute wheel velocities
    var half_wheel_base = _wheel_base / 2.0
    var v_left = _linear_vel - _angular_vel * half_wheel_base
    var v_right = _linear_vel + _angular_vel * half_wheel_base

    # Convert to wheel RPM
    var left_rpm = (v_left / (2.0 * PI * _wheel_radius)) * 60.0
    var right_rpm = (v_right / (2.0 * PI * _wheel_radius)) * 60.0

    # Apply to wheels
    _front_left_wheel.engine_force = left_rpm * 0.1
    _front_right_wheel.engine_force = right_rpm * 0.1
    # ... apply to rear wheels as well


func _physics_process(delta: float) -> void:
    apply_cmd_vel(_linear_vel, _angular_vel)
```

---

## PID Control

PID (Proportional-Integral-Derivative) is the workhorse of closed-loop control.

### The PID Formula

```
output = Kp * error + Ki * integral(error) + Kd * derivative(error)
```

Where:
- **P** (Proportional): Responds to current error
- **I** (Integral): Responds to accumulated error
- **D** (Derivative): Responds to rate of error change

### Using PIDController

```gdscript
var pid = PIDController.new(10.0, 0.5, 1.0)  # Kp, Ki, Kd

func _physics_process(delta: float) -> void:
    # Get current position
    var current = joint.get_param(Joint3D.PARAM_BIAS)

    # Compute error
    var error = target_position - current

    # Get PID output
    var output = pid.compute_output(error, delta)

    # Apply to joint
    joint.set_param(Joint3D.PARAM_BIAS, output)
```

### Anti-Windup

Integral term can grow unbounded, causing overshoot. Use anti-windup:

```gdscript
var pid = PIDController.new(10.0, 0.5, 1.0)
pid.set_anti_windup(100.0)  # Limit integral to ±100
```

### Derivative Filtering

High-frequency noise can cause jitter in derivative term. Filter it:

```gdscript
var pid = PIDController.new(10.0, 0.5, 1.0)
pid.set_derivative_filter(0.8)  # 0.8 = heavy smoothing, 0.0 = no filter
```

---

## Position Control Loop

A complete position control loop for a single joint:

```gdscript
class_name JointPositionController

var _joint: Node3D
var _pid: PIDController
var _target: float = 0.0
var _current: float = 0.0

func _init(joint: Node3D, kp: float = 10.0, ki: float = 0.5, kd: float = 1.0):
    _joint = joint
    _pid = PIDController.new(kp, ki, kd)
    _pid.set_anti_windup(50.0)


func set_target(angle: float) -> void:
    _target = angle


func _physics_process(delta: float) -> void:
    # Read current position
    if _joint is PinJoint3D:
        _current = _joint.rotation
    else:
        _current = _joint.position.x  # Prismatic

    # Compute error
    var error = _target - _current

    # Compute PID output
    var output = _pid.compute_output(error, delta)

    # Apply
    if _joint is PinJoint3D:
        _joint.set_param(Joint3D.PARAM_BIAS, output)
    elif _joint is SliderJoint3D:
        _joint.set_param(Joint3D.PARAM_BIAS, output)
```

---

## Velocity Control Loop

For velocity control, the loop runs at a fixed rate:

```gdscript
class_name JointVelocityController

var _joint: Node3D
var _pid: PIDController
var _target_velocity: float = 0.0
var _current_velocity: float = 0.0
var _prev_position: float = 0.0


func _init(joint: Node3D):
    _joint = joint
    _pid = PIDController.new(5.0, 0.1, 0.5)  # Lower Kp for velocity


func set_target_velocity(rpm: float) -> void:
    _target_velocity = rpm


func _physics_process(delta: float) -> void:
    # Estimate velocity from position change
    var current_position = _joint is PinJoint3D ? _joint.rotation : _joint.position.x
    _current_velocity = (current_position - _prev_position) / delta
    _prev_position = current_position

    # Error in RPM
    var error = _target_velocity - _current_velocity

    # PID output
    var output = _pid.compute_output(error, delta)

    # Apply as force/torque
    _joint.set_param(Joint3D.PARAM_BIAS, output)
```

---

## Trajectory Execution

Move through a series of waypoints with time parametrization:

```gdscript
class_name TrajectoryExecutor

var _waypoints: Array = []  # Array of {position, time}
var _current_waypoint: int = 0
var _pid: PIDController
var _duration: float = 0.0


func load_trajectory(waypoints: Array, duration: float) -> void:
    _waypoints = waypoints
    _duration = duration
    _current_waypoint = 0


func _physics_process(delta: float) -> void:
    if _waypoints.is_empty() or _current_waypoint >= _waypoints.size():
        return

    var wp = _waypoints[_current_waypoint]
    var next_wp = _waypoints[_current_waypoint + 1] if _current_waypoint + 1 < _waypoints.size() else wp

    # Interpolate position
    var t = _duration / float(_waypoints.size())
    var current_time = Time.get_ticks_msec() / 1000.0
    var alpha = clamp(current_time / t, 0.0, 1.0)

    var target_pos = wp.position.lerp(next_wp.position, alpha)

    # Use PID to drive to target
    var error = target_pos - _joint.position
    var output = _pid.compute_output(error, delta)
    _joint.apply_force(output * Vector3.RIGHT)

    # Check if waypoint reached
    if error.length() < 0.01:
        _current_waypoint += 1
```

---

## Joint Limits

Protect joints from exceeding their physical limits:

```gdscript
func clamp_joint(joint: Node3D, min_val: float, max_val: float) -> void:
    if joint is PinJoint3D:
        var angle = joint.rotation
        joint.rotation = clamp(angle, min_val, max_val)
    elif joint is SliderJoint3D:
        var pos = joint.position.x
        joint.position.x = clamp(pos, min_val, max_val)
```

---

## Impedance Control

For compliant robot behavior (useful in contact tasks):

```gdscript
class_name ImpedanceController

var _kp: float = 50.0  # Position gain
var _kd: float = 5.0   # Damping gain


func compute_torque(current_pos: Vector3, target_pos: Vector3,
                     current_vel: Vector3, target_vel: Vector3) -> Vector3:
    # Impedance: F = Kp * (xd - x) + Kd * (xd_dot - x_dot)
    var pos_error = target_pos - current_pos
    var vel_error = target_vel - current_vel

    return _kp * pos_error + _kd * vel_error
```

---

## See Also

- [URDF Import](urdf-import.md) — Loading robot models
- [Sensors Overview](../sensors/overview.md) — Sensor feedback for control
- [IK Solvers](../navigation/ik-solvers.md) — Computing inverse kinematics
- [Physics Backends](../physics/backends.md) — Physics simulation options