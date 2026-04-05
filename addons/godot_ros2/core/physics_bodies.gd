# physics_bodies.gd
# Physics body components

class_name RobotLink

var _name: String
var _node: Node3D
var _mass: float = 1.0
var _inertia: Vector3 = Vector3.ONE
var _parent_joint: String = ""
var _is_root: bool = false
var _visual_mesh: Node3D
var _collision_shape: Shape3D


func _init(name: String) -> void:
	_name = name
	_node = Node3D.new()
	_node.set_name(name)


func _to_string() -> String:
	return "RobotLink:%s" % _name


func get_name() -> String:
	return _name


func get_node() -> Node3D:
	return _node


func set_mass(m: float) -> void:
	_mass = m


func get_mass() -> float:
	return _mass


func set_inertia(i: Vector3) -> void:
	_inertia = i


func get_inertia() -> Vector3:
	return _inertia


func set_parent_joint(joint_name: String) -> void:
	_parent_joint = joint_name


func get_parent_joint() -> String:
	return _parent_joint


func set_root(is_root: bool) -> void:
	_is_root = is_root


func is_root() -> bool:
	return _is_root


func set_visual_mesh(mesh: Node3D) -> void:
	if _visual_mesh and _node.has_child(_visual_mesh):
		_node.remove_child(_visual_mesh)
	_visual_mesh = mesh
	if _visual_mesh:
		_node.add_child(_visual_mesh)


func get_visual_mesh() -> Node3D:
	return _visual_mesh


func set_collision_shape(shape: Shape3D) -> void:
	_collision_shape = shape


func get_collision_shape() -> Shape3D:
	return _collision_shape


# ===== RobotJoint =====

class RobotJoint

enum JointType { REVOLUTE, CONTINUOUS, PRISMATIC, FIXED, PLANAR, FLOATING }

var _name: String
var _node: Node3D
var _type: JointType = JointType.REVOLUTE
var _parent_link: String = ""
var _child_link: String = ""
var _axis: Vector3 = Vector3(1, 0, 0)
var _limit_lower: float = -INF
var _limit_upper: float = INF
var _effort_limit: float = INF
var _velocity_limit: float = INF
var _position: float = 0.0
var _velocity: float = 0.0
var _effort: float = 0.0


func _init(name: String) -> void:
	_name = name
	_node = Node3D.new()
	_node.set_name(name)


func _to_string() -> String:
	return "RobotJoint:%s" % _name


func get_name() -> String:
	return _name


func get_node() -> Node3D:
	return _node


func set_type(type: JointType) -> void:
	_type = type


func get_type() -> JointType:
	return _type


func set_parent_link(link: String) -> void:
	_parent_link = link


func get_parent_link() -> String:
	return _parent_link


func get_child_link() -> String:
	return _child_link


func set_child_link(link: String) -> void:
	_child_link = link


func set_axis(axis: Vector3) -> void:
	_axis = axis


func get_axis() -> Vector3:
	return _axis


func set_limits(lower: float, upper: float) -> void:
	_limit_lower = lower
	_limit_upper = upper


func get_limits() -> Dictionary:
	return {"lower": _limit_lower, "upper": _limit_upper}


func set_position(pos: float) -> void:
	_position = pos


func get_position() -> float:
	return _position


func set_velocity(vel: float) -> void:
	_velocity = vel


func get_velocity() -> float:
	return _velocity


func set_effort(eff: float) -> void:
	_effort = eff


func get_effort() -> float:
	return _effort


func physics_update(dt: float) -> void:
	# Apply physics
	pass


# ===== JointController =====

class JointController

var _joint: RobotJoint
var _target_position: float = 0.0
var _target_velocity: float = 0.0
var _target_effort: float = 0.0
var _Kp: float = 1.0
var _Ki: float = 0.0
var _Kd: float = 0.0
var _integral: float = 0.0
var _last_error: float = 0.0


func _init(name: String = "") -> void:
	pass


func set_joint(joint: RobotJoint) -> void:
	_joint = joint


func set_target_position(pos: float) -> void:
	_target_position = pos


func set_target_velocity(vel: float) -> void:
	_target_velocity = vel


func set_target_effort(eff: float) -> void:
	_target_effort = eff


func set_gains(kp: float, ki: float, kd: float) -> void:
	_Kp = kp
	_Ki = ki
	_Kd = kd


func update(dt: float) -> void:
	if not _joint:
		return

	var error = _target_position - _joint.get_position()
	_integral += error * dt
	var derivative = (error - _last_error) / dt if dt > 0 else 0.0
	_last_error = error

	var effort = _Kp * error + _Ki * _integral + _Kd * derivative
	_joint.set_effort(min(effort, _joint._effort_limit))


# ===== ContactManager =====

class ContactManager

var _contacts: Array = []


func _init() -> void:
	pass


func reset() -> void:
	_contacts.clear()


func add_contact(body1: String, body2: String, position: Vector3, normal: Vector3) -> void:
	_contacts.append({
		"body1": body1,
		"body2": body2,
		"position": position,
		"normal": normal
	})


func get_contacts() -> Array:
	return _contacts


func get_contacts_for_body(body: String) -> Array:
	var result: Array = []
	for c in _contacts:
		if c["body1"] == body or c["body2"] == body:
			result.append(c)
	return result


# ===== DifferentialDrive =====

class DifferentialDrive

var _wheel_separation: float = 0.5
var _wheel_radius: float = 0.1
var _left_wheel_vel: float = 0.0
var _right_wheel_vel: float = 0.0
var _robot: Node3D


func _init(name: String = "") -> void:
	pass


func set_robot(robot: Node3D) -> void:
	_robot = robot


func set_wheel_separation(separation: float) -> void:
	_wheel_separation = separation


func set_wheel_radius(radius: float) -> void:
	_wheel_radius = radius


func set_velocities(left: float, right: float) -> void:
	_left_wheel_vel = left
	_right_wheel_vel = right


func update(dt: float) -> void:
	if not _robot:
		return

	# Compute linear and angular velocities
	var v = (_right_wheel_vel + _left_wheel_vel) * 0.5 * _wheel_radius
	var omega = (_right_wheel_vel - _left_wheel_vel) * _wheel_radius / _wheel_separation

	# Apply transform
	var t = _robot.get_transform()
	var rotation = Basis()
	rotation = rotation.rotated(Vector3.UP, omega * dt)
	t.basis = t.basis * rotation
	t.origin += t.basis * Vector3(v * dt, 0, 0)
	_robot.set_transform(t)


# ===== GroundTruth =====

class GroundTruth

var _robot_name: String
var _publisher: Publisher


func _init(robot_name: String) -> void:
	_robot_name = robot_name


func setup_publisher(ros2_node: ROS2Node) -> void:
	_publisher = ros2_node.create_publisher("/%s/odom" % _robot_name, "nav_msgs/Odometry")


func update(robot: RobotModel) -> void:
	if _publisher:
		var pose = robot.get_pose()
		var msg = NavMsgs.create_odometry_from_gd(
			StdMsgs.create_header_now("map"),
			_robot_name,
			pose["position"],
			pose["orientation"],
			Vector3.ZERO,  # linear velocity
			Vector3.ZERO   # angular velocity
		)
		_publisher.publish(msg)
