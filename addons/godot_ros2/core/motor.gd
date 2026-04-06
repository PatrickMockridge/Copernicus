# motor.gd
# Motor actuator

class_name Motor
extends Actuator

enum MotorType { BRUSHED, BRUSHLESS }
enum ControlMode { PWM, VELOCITY, POSITION, TORQUE }

var _type: MotorType = MotorType.BRUSHLESS
var _control_mode: ControlMode = ControlMode.VELOCITY
var _max_speed: float = 1000.0
var _max_torque: float = 10.0
var _target: float = 0.0
var _current: float = 0.0
var _speed: float = 0.0


func _init(name: String) -> void:
	super(name)


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