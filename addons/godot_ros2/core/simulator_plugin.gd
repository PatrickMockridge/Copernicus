# simulator_plugin.gd
# Base plugin class for simulator extensions

class_name SimulatorPlugin

var _name: String
var _enabled: bool = true
var _simulator: ROS2Simulator


func _init(name: String) -> void:
	_name = name


func get_name() -> String:
	return _name


func is_enabled() -> bool:
	return _enabled


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func on_load(simulator: ROS2Simulator) -> void:
	_simulator = simulator


func on_unload() -> void:
	pass


func on_simulation_step(delta: float) -> void:
	pass


func on_physics_step(delta: float) -> void:
	pass