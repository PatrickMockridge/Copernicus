# differential_drive.gd
# Differential drive kinematics

class_name DifferentialDrive

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