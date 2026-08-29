# robot_library.gd
# Autoload — the out-of-box robot library. A manifest of definitions pointing at
# procedural factories (and optionally URDF/MJCF source files).

extends Node

const CATEGORIES := {
	"mobile": "Mobile",
	"arm": "Arms",
	"legged": "Legged",
	"gripper": "Grippers",
	"aerial": "Aerial",
}

var _defs: Array = []


func _ready() -> void:
	_build()


func _build() -> void:
	_defs = [
		_def("turtlebot", "TurtleBot4", "mobile", "Differential-drive mobile base (2 drive wheels).", Color(0.2, 0.55, 0.3), "res://scripts/robots/factories/turtlebot_factory.gd"),
		_def("arm6", "Arm6", "arm", "6-DOF industrial arm with a two-finger gripper.", Color(0.6, 0.42, 0.25), "res://scripts/robots/factories/arm_factory.gd"),
		_def("quadruped", "Quadruped", "legged", "Four-legged walker (12 revolute joints).", Color(0.25, 0.45, 0.7), "res://scripts/robots/factories/quadruped_factory.gd"),
		_def("gripper", "Parallel Gripper", "gripper", "Two-finger parallel gripper on a wrist.", Color(0.5, 0.5, 0.55), "res://scripts/robots/factories/gripper_factory.gd"),
		_def("drone", "QuadDrone", "aerial", "Quadcopter with four spinning rotors.", Color(0.15, 0.2, 0.28), "res://scripts/robots/factories/drone_factory.gd"),
	]


func _def(id: String, name: String, category: String, description: String, color: Color, factory: String) -> Dictionary:
	return {"id": id, "name": name, "category": category, "description": description, "color": color, "factory": factory}


func get_definitions() -> Array:
	return _defs


func get_categories() -> Dictionary:
	return CATEGORIES


func get_by_id(id: String) -> Dictionary:
	for d in _defs:
		if d["id"] == id:
			return d
	return {}


func build(id: String) -> Node3D:
	var d := get_by_id(id)
	if d.is_empty() or not d.has("factory"):
		return null
	var script = load(d["factory"])
	if script:
		return script.build()
	return null
