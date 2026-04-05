# simulation_world.gd
# Simulation world with physics

class_name SimulationWorld

extends Node3D

var _gravity: Vector3 = Vector3(0, -9.81, 0)
var _step_size: float = 0.001
var _debug_enabled: bool = false
var _contact_manager: ContactManager


func _init() -> void:
	_contact_manager = ContactManager.new()


# ===== Gravity =====

func set_gravity(g: Vector3) -> void:
	_gravity = g


func get_gravity() -> Vector3:
	return _gravity


# ===== Step Size =====

func set_step_size(dt: float) -> void:
	_step_size = dt


func get_step_size() -> float:
	return _step_size


# ===== Physics Step =====

func step(dt: float) -> void:
	_contact_manager.reset()
	# Process physics for all children
	_process_physics(dt)


func _process_physics(dt: float) -> void:
	# Recursively process physics bodies
	for child in get_children():
		if child.has_method("physics_update"):
			child.physics_update(dt)


func reset() -> void:
	_contact_manager.reset()


# ===== Debug =====

func enable_debug() -> void:
	_debug_enabled = true


func disable_debug() -> void:
	_debug_enabled = false


func is_debug_enabled() -> bool:
	return _debug_enabled


# ===== Contact Manager =====

func get_contact_manager() -> ContactManager:
	return _contact_manager


func add_contact(body1: String, body2: String, position: Vector3, normal: Vector3) -> void:
	_contact_manager.add_contact(body1, body2, position, normal)


# ===== Scene =====

func load_scene(scene_path: String) -> bool:
	if FileAccess.file_exists(scene_path):
		var scene = load(scene_path)
		if scene:
			var instance = scene.instantiate()
			add_child(instance)
			return true
	return false


func clear() -> void:
	# Remove all children
	for child in get_children():
		remove_child(child)
		child.queue_free()
