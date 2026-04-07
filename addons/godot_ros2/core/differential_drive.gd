# differential_drive.gd
# Differential drive kinematics

class_name DifferentialDrive

var _wheel_separation: float = 0.5
var _wheel_radius: float = 0.1
var _left_wheel_vel: float = 0.0
var _right_wheel_vel: float = 0.0
var _robot: Node3D
var _ros2_node: ROS2Node = null
var _cmd_vel_sub: Subscription = null
var _cmd_vel_linear: float = 0.0
var _cmd_vel_angular: float = 0.0


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


func set_ros2_node(node: ROS2Node) -> void:
	# Enable cmd_vel subscription for real robot control.
	# Creates a subscription to geometry_msgs/Twist on /robot/cmd_vel
	# and uses that to drive the robot instead of set_velocities().
	_ros2_node = node
	if _ros2_node != null:
		_cmd_vel_sub = _ros2_node.create_subscription(
			"cmd_vel", "geometry_msgs/Twist", Callable(self, "_on_cmd_vel")
		)
		print("DifferentialDrive: cmd_vel subscription enabled")


func _on_cmd_vel(msg: Dictionary) -> void:
	# Parse geometry_msgs/Twist: { linear: {x, y, z}, angular: {x, y, z} }
	var linear = msg.get("linear", {})
	var angular = msg.get("angular", {})
	_cmd_vel_linear = linear.get("x", 0.0)
	_cmd_vel_angular = angular.get("z", 0.0)


func update(dt: float) -> void:
	_update_physics(dt)


func physics_update(dt: float) -> void:
	_update_physics(dt)


func _update_physics(dt: float) -> void:
	if not _robot:
		return

	# Determine wheel velocities: from cmd_vel subscription or direct set_velocities()
	var left_vel: float
	var right_vel: float
	if _cmd_vel_sub != null:
		# Use velocities computed from cmd_vel subscription
		# differential drive inverse kinematics:
		# v_left = v_linear - omega * wheel_separation / 2
		# v_right = v_linear + omega * wheel_separation / 2
		# where v_linear = linear.x and omega = angular.z
		var half_sep = _wheel_separation / 2.0
		left_vel = (_cmd_vel_linear - _cmd_vel_angular * half_sep) / _wheel_radius
		right_vel = (_cmd_vel_linear + _cmd_vel_angular * half_sep) / _wheel_radius
		# Also check for new messages
		if _cmd_vel_sub.has_new_message():
			var twist = _cmd_vel_sub.get_next_message()
			if twist.has("linear"):
				var lin = twist["linear"]
				var ang = twist.get("angular", {})
				_cmd_vel_linear = lin.get("x", 0.0)
				_cmd_vel_angular = ang.get("z", 0.0)
			_cmd_vel_sub.trigger_callback(twist)
	else:
		left_vel = _left_wheel_vel
		right_vel = _right_wheel_vel

	# Compute linear and angular velocities
	var v = (right_vel + left_vel) * 0.5 * _wheel_radius
	var omega = (right_vel - left_vel) * _wheel_radius / _wheel_separation

	# Apply transform
	var t = _robot.get_transform()
	var rotation = Basis()
	rotation = rotation.rotated(Vector3.UP, omega * dt)
	t.basis = t.basis * rotation
	t.origin += t.basis * Vector3(v * dt, 0, 0)
	_robot.set_transform(t)