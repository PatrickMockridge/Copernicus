# Actuators

Actuator classes for robot control. All actuators extend the base `Actuator` class.

## Base Actuator (actuator.gd)

```gdscript
class_name Actuator
```

### Methods

#### `get_name() -> String`
Returns the actuator name.

#### `get_robot() -> Node3D`
Get the parent robot.

#### `set_robot(robot: Node3D) -> void`
Set the parent robot.

#### `set_enabled(enabled: bool) -> void`
Enable or disable the actuator.

#### `is_enabled() -> bool`
Check if actuator is enabled.

#### `physics_update(delta: float) -> void`
Called each physics step. Override in subclasses.

---

## Motor (motor.gd)

DC motor actuator with velocity, position, and torque control.

```gdscript
class_name Motor
extends Actuator
```

### Enums

```gdscript
enum MotorType { BRUSHED, BRUSHLESS }
enum ControlMode { PWM, VELOCITY, POSITION, TORQUE }
```

### Configuration

```gdscript
var motor = Motor.new("wheel_motor")
motor.set_type(Motor.MotorType.BRUSHLESS)
motor.set_control_mode(Motor.ControlMode.VELOCITY)
motor.set_max_speed(1000.0)   # RPM
motor.set_max_torque(10.0)   # Nm
```

### Methods

#### `set_type(type: MotorType) -> void`
Set motor type.

#### `set_control_mode(mode: ControlMode) -> void`
Set control mode:
- `PWM` — Direct PWM control
- `VELOCITY` — Velocity control
- `POSITION` — Position control
- `TORQUE` — Torque control

#### `set_target(value: float) -> void`
Set the control target value.

#### `set_max_speed(max_s: float) -> void`
Set max speed (RPM).

#### `set_max_torque(max_t: float) -> void`
Set max torque (Nm).

#### `physics_update(delta: float) -> void`
Called each physics step to update motor state.

---

## Servo (servo.gd)

Servo motor actuator for angular position control.

```gdscript
class_name Servo
extends Actuator
```

### Configuration

```gdscript
var servo = Servo.new("gripper_servo")
servo.set_limits(-1.57, 1.57)    # +/- 90 degrees
servo.set_max_speed(3.14)        # 180 deg/s max
```

### Methods

#### `set_target_angle(angle: float) -> void`
Set target angle in radians.

#### `set_limits(min_angle: float, max_angle: float) -> void`
Set angle limits in radians.

---

## Thruster (thruster.gd)

Thruster actuator for propulsion (boats, underwater vehicles).

```gdscript
class_name Thruster
extends Actuator
```

### Enums

```gdscript
enum ThrusterType { FIXED_PITCH, VARIABLE_PITCH }
enum ThrustModel { SIMPLE, KKT, MUNK }
```

### Configuration

```gdscript
var thruster = Thruster.new("main_thrust")
thruster.set_max_thrust(100.0)           # Newtons
thruster.set_direction(Vector3.UP)       # Thrust direction
thruster.set_thrust_level(0.5)          # 50% thrust
```

### Methods

#### `set_max_thrust(max_t: float) -> void`
Set max thrust in Newtons.

#### `set_direction(dir: Vector3) -> void`
Set thrust direction vector (automatically normalized).

#### `set_thrust_level(level: float) -> void`
Set thrust level from -1.0 (reverse) to 1.0 (forward).

#### `get_thrust_vector() -> Vector3`
Get the current thrust as a vector.

---

## Propeller (propeller.gd)

Propeller actuator extending Thruster with RPM-based thrust model.

```gdscript
class_name Propeller
extends Thruster
```

### Configuration

```gdscript
var prop = Propeller.new("prop_0")
prop.set_diameter(0.3)        # meters
prop.set_pitch(0.2)          # pitch ratio
```

### Methods

#### `set_diameter(d: float) -> void`
Set propeller diameter (meters).

#### `set_pitch(p: float) -> void`
Set propeller pitch.

#### `get_torque() -> float`
Get torque based on RPM squared.

---

## Usage Example

```gdscript
extends Node3D

var sim: ROS2Simulator
var robot: RobotModel
var left_motor: Motor
var right_motor: Motor

func _ready() -> void:
    sim = ROS2Simulator.new()
    add_child(sim)

    robot = sim.create_simple_diff_robot("turtle", "", "", "", Transform3D.IDENTITY)

    # Create differential drive motors
    left_motor = Motor.new("left_wheel")
    left_motor.set_control_mode(Motor.ControlMode.VELOCITY)
    left_motor.set_max_speed(500.0)
    left_motor.set_max_torque(5.0)
    robot.add_child(left_motor)

    right_motor = Motor.new("right_wheel")
    right_motor.set_control_mode(Motor.ControlMode.VELOCITY)
    right_motor.set_max_speed(500.0)
    right_motor.set_max_torque(5.0)
    robot.add_child(right_motor)

func _physics_process(delta: float) -> void:
    # Example: drive forward
    left_motor.set_target(100.0)   # 100 RPM
    right_motor.set_target(100.0)
```

## Source Files

| Class | File |
|-------|------|
| `Actuator` | `core/actuator.gd` |
| `Motor` | `core/motor.gd` |
| `Servo` | `core/servo.gd` |
| `Thruster` | `core/thruster.gd` |
| `Propeller` | `core/propeller.gd` |
