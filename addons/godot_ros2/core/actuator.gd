# actuator.gd
# Base actuator class

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