# propeller.gd
# Propeller actuator

extends Thruster

var _prop_diameter: float = 0.3
var _prop_pitch: float = 0.2
var _thrust_coefficient: float = 0.0001
var _torque_coefficient: float = 0.00001
var _rpm: float = 0.0


func _init(name: String) -> void:
	super(name)


func set_diameter(d: float) -> void:
	_prop_diameter = d


func set_pitch(p: float) -> void:
	_prop_pitch = p


func physics_update(delta: float) -> void:
	match _model:
		ThrustModel.SIMPLE:
			var thrust = _thrust_coefficient * _current_thrust * _current_thrust * _prop_diameter * _prop_diameter
			_current_thrust = sign(_current_thrust) * thrust
		ThrustModel.KKT:
			pass
		ThrustModel.MUNK:
			pass


func get_torque() -> float:
	return _torque_coefficient * _rpm * _rpm