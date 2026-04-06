# thruster.gd
# Thruster actuator

class_name Thruster
extends Actuator

enum ThrusterType { FIXED_PITCH, VARIABLE_PITCH }
enum ThrustModel { SIMPLE, KKT, MUNK }

var _type: ThrusterType = ThrusterType.FIXED_PITCH
var _model: ThrustModel = ThrustModel.SIMPLE
var _max_thrust: float = 100.0
var _current_thrust: float = 0.0
var _direction: Vector3 = Vector3.UP


func _init(name: String) -> void:
	super(name)


func set_max_thrust(max_t: float) -> void:
	_max_thrust = max_t


func set_direction(dir: Vector3) -> void:
	_direction = dir.normalized()


func set_thrust_level(level: float) -> void:
	_current_thrust = clamp(level, -1.0, 1.0) * _max_thrust


func get_thrust_vector() -> Vector3:
	return _direction * _current_thrust