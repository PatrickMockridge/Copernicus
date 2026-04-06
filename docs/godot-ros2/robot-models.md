# Robot Models

Robot model classes for creating and managing robot structures.

## RobotModel (robot_model.gd)

Main robot model class containing links, joints, and control systems.

```gdscript
class_name RobotModel
```

### Enums

```gdscript
enum Mode { SIMPLE, ADVANCED }
enum ControlMode { POSITION, VELOCITY, EFFORT }
```

### Configuration

```gdscript
var robot = RobotModel.new("my_robot")
robot.set_mode(RobotModel.Mode.SIMPLE)
robot.set_control_mode(RobotModel.ControlMode.VELOCITY)
```

### Methods

#### `get_name() -> String`
Returns the robot name.

#### `set_mode(mode: Mode) -> void`
Set operating mode: `SIMPLE` or `ADVANCED`.

#### `get_mode() -> Mode`
Get current operating mode.

#### `get_node() -> Node3D`
Get the root 3D node of the robot.

#### `set_control_mode(mode: ControlMode) -> void`
Set joint control mode: `POSITION`, `VELOCITY`, or `EFFORT`.

#### `get_control_mode() -> ControlMode`
Get current control mode.

### Links

#### `add_link(link: RobotLink) -> void`
Add a link to the robot.

#### `get_link(name: String) -> RobotLink`
Get a link by name.

#### `get_links() -> Array`
Get all links.

#### `get_root_link() -> RobotLink`
Get the root link.

### Joints

#### `add_joint(joint: RobotJoint) -> void`
Add a joint to the robot.

#### `get_joint(name: String) -> RobotJoint`
Get a joint by name.

#### `get_joints() -> Array`
Get all joints.

---

## RobotLink (robot_link.gd)

Individual link (rigid body) of a robot.

```gdscript
class_name RobotLink
```

### Methods

#### `get_name() -> String`
Returns the link name.

#### `get_node() -> Node3D`
Get the 3D node of this link.

#### `set_mass(mass: float) -> void`
Set the link mass (kg).

#### `get_mass() -> float`
Get the link mass.

#### `set_inertia(moment: Vector3) -> void`
Set the inertia tensor (kg⋅m²).

#### `set_visual_mesh(mesh: Mesh) -> void`
Set the visual mesh.

#### `set_collision_shape(shape: CollisionShape3D) -> void`
Set the collision shape.

#### `is_root() -> bool`
Check if this is the root link.

---

## RobotJoint (robot_joint.gd)

Joint connecting two links.

```gdscript
class_name RobotJoint
```

### Enums

```gdscript
enum JointType { REVOLUTE, CONTINUOUS, PRISMATIC, FIXED, PLANAR, FLOATING }
```

### Methods

#### `get_name() -> String`
Returns the joint name.

#### `get_node() -> Node3D`
Get the 3D node of this joint.

#### `set_type(type: JointType) -> void`
Set joint type.

#### `get_type() -> JointType`
Get joint type.

#### `set_parent_link(link: String) -> void`
Set the parent link name.

#### `get_parent_link() -> String`
Get the parent link name.

#### `set_child_link(link: String) -> void`
Set the child link name.

#### `get_child_link() -> String`
Get the child link name.

#### `set_axis(axis: Vector3) -> void`
Set the joint axis vector.

#### `get_axis() -> Vector3`
Get the joint axis vector.

#### `set_limits(lower: float, upper: float) -> void`
Set position limits.

#### `set_velocity_limit(limit: float) -> void`
Set velocity limit.

#### `set_effort_limit(limit: float) -> void`
Set effort limit.

---

## JointController (joint_controller.gd)

PID controller for joint position/velocity/effort control.

```gdscript
class_name JointController
```

### Methods

#### `set_target_position(position: float) -> void`
Set target position (radians or meters).

#### `set_target_velocity(velocity: float) -> void`
Set target velocity (rad/s or m/s).

#### `set_target_effort(effort: float) -> void`
Set target effort (Nm or N).

#### `set_gains(kp: float, ki: float, kd: float) -> void`
Set PID gains.

#### `get_output() -> float`
Get the controller output.

---

## DifferentialDrive (differential_drive.gd)

Differential drive system for two-wheeled robots.

```gdscript
class_name DifferentialDrive
```

### Methods

#### `set_wheel_base(base: float) -> void`
Set distance between wheels (meters).

#### `set_wheel_radius(radius: float) -> void`
Set wheel radius (meters).

#### `set_limits(max_linear: float, max_angular: float) -> void`
Set velocity limits.

#### `compute_velocities(linear: float, angular: float) -> Dictionary`
Compute wheel velocities from base velocities.

---

## Usage Example

```gdscript
extends Node3D

var sim: ROS2Simulator
var robot: RobotModel
var left_joint: RobotJoint
var right_joint: RobotJoint

func _ready() -> void:
    sim = ROS2Simulator.new()
    add_child(sim)

    # Create robot
    robot = RobotModel.new("diff_robot")
    robot.set_mode(RobotModel.Mode.SIMPLE)
    add_child(robot.get_node())

    # Add joints
    left_joint = RobotJoint.new("left_wheel_joint")
    left_joint.set_type(RobotJoint.JointType.REVOLUTE)
    left_joint.set_parent_link("base_link")
    left_joint.set_child_link("left_wheel")
    left_joint.set_axis(Vector3(0, 1, 0))
    robot.add_joint(left_joint)

    right_joint = RobotJoint.new("right_wheel_joint")
    right_joint.set_type(RobotJoint.JointType.REVOLUTE)
    right_joint.set_parent_link("base_link")
    right_joint.set_child_link("right_wheel")
    right_joint.set_axis(Vector3(0, 1, 0))
    robot.add_joint(right_joint)

    # Add controllers
    var left_ctrl = JointController.new()
    left_ctrl.set_gains(10.0, 0.1, 1.0)
    robot.add_joint_controller("left_wheel_joint", left_ctrl)
```

## Source Files

| Class | File |
|-------|------|
| `RobotModel` | `core/robot_model.gd` |
| `RobotLink` | `core/robot_link.gd` |
| `RobotJoint` | `core/robot_joint.gd` |
| `JointController` | `core/joint_controller.gd` |
| `DifferentialDrive` | `core/differential_drive.gd` |
| `ContactManager` | `core/contact_manager.gd` |
| `GroundTruth` | `core/ground_truth.gd` |
