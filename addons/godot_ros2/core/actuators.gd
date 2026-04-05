# actuators.gd
# Actuator implementations

class_name Actuator

var _name: String
var _robot: Node3D
var _enabled: bool = true


func _init(name: String) -> void:
	_name = name


func get_name() -> String:
	return _name


func get_robot() -> Node3D:
	return _robot


func set_robot(robot: Node3D) -> void:
	_robot = robot


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


func physics_update(delta: float) -> void:
	pass


# ===== Motor =====

class Motor extends Actuator

enum MotorType { BRUSHED, BRUSHLESS }
enum ControlMode { PWM, VELOCITY, POSITION, TORQUE }

var _type: MotorType = MotorType.BRUSHLESS
var _control_mode: ControlMode = ControlMode.VELOCITY
var _max_speed: float = 1000.0
var _max_torque: float = 10.0
var _target: float = 0.0
var _current: float = 0.0
var _speed: float = 0.0


func _init(name: String).super(name) -> void:
	pass


func set_type(type: MotorType) -> void:
	_type = type


func set_control_mode(mode: ControlMode) -> void:
	_control_mode = mode


func set_target(value: float) -> void:
	_target = value


func set_max_speed(max_s: float) -> void:
	_max_speed = max_s


func set_max_torque(max_t: float) -> void:
	_max_torque = max_t


func physics_update(delta: float) -> void:
	if not _enabled:
		return

	match _control_mode:
		ControlMode.PWM:
			_current = _target
		ControlMode.VELOCITY:
			_speed = _target
			_current = (_target / _max_speed) * _max_torque
		ControlMode.POSITION:
			_current = (_target - _speed) * 10.0
		ControlMode.TORQUE:
			_current = _target

	_current = clamp(_current, -_max_torque, _max_torque)


# ===== Servo =====

class Servo extends Actuator

var _angle: float = 0.0
var _target_angle: float = 0.0
var _min_angle: float = -1.57  # -90 degrees
var _max_angle: float = 1.57   # 90 degrees
var _max_speed: float = 3.14    # rad/s


func _init(name: String).super(name) -> void:
	pass


func set_target_angle(angle: float) -> void:
	_target_angle = clamp(angle, _min_angle, _max_angle)


func set_limits(min_a: float, max_a: float) -> void:
	_min_angle = min_a
	_max_angle = max_a


func physics_update(delta: float) -> void:
	if not _enabled:
		return

	var diff = _target_angle - _angle
	var max_step = _max_speed * delta
	_angle += clamp(diff, -max_step, max_step)


func get_angle() -> float:
	return _angle


# ===== Thruster =====

class Thruster extends Actuator

enum ThrusterType { FIXED_PITCH, VARIABLE_PITCH }
enum ThrustModel { SIMPLE, KKT, MUNK }

var _type: ThrusterType = ThrusterType.FIXED_PITCH
var _model: ThrustModel = ThrustModel.SIMPLE
var _max_thrust: float = 100.0
var _current_thrust: float = 0.0
var _direction: Vector3 = Vector3.UP


func _init(name: String).super(name) -> void:
	pass


func set_max_thrust(max_t: float) -> void:
	_max_thrust = max_t


func set_direction(dir: Vector3) -> void:
	_direction = dir.normalized()


func set_thrust_level(level: float) -> void:
	# level from -1.0 to 1.0
	_current_thrust = clamp(level, -1.0, 1.0) * _max_thrust


func get_thrust_vector() -> Vector3:
	return _direction * _current_thrust


# ===== Propeller =====

class Propeller extends Thruster

var _prop_diameter: float = 0.3
var _prop_pitch: float = 0.2
var _thrust_coefficient: float = 0.0001
var _torque_coefficient: float = 0.00001
var _rpm: float = 0.0


func _init(name: String).super(name) -> void:
	pass


func set_diameter(d: float) -> void:
	_prop_diameter = d


func set_pitch(p: float) -> void:
	_prop_pitch = p


func physics_update(delta: float) -> void:
	# Simple thrust model: T = Kt * rho * n^2 * D^4
	# where n is revs per second, D is diameter
	match _model:
		ThrustModel.SIMPLE:
			var thrust = _thrust_coefficient * _current_thrust * _current_thrust * _prop_diameter * _prop_diameter
			_current_thrust = sign(_current_thrust) * thrust
		ThrustModel.KKT:
			# Kutta-Joukowski theorem based
			pass
		ThrustModel.MUNK:
			# Munk's momentum theory
			pass


func get_torque() -> float:
	return _torque_coefficient * _rpm * _rpm
