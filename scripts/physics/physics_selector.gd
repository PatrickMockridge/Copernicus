# physics_selector.gd
# UI for selecting which physics backend to use

class_name PhysicsSelector
extends BaseSelector

signal backend_selected(backend_class: String)

# Preload backends so their _static_init registers them with ModuleRegistry.
const GodotPhysicsBackend = preload("res://scripts/physics/godot_physics_backend.gd")
const PyBulletBackend = preload("res://scripts/physics/pybullet_backend.gd")


func _get_title() -> String:
	return "Select Physics Backend"


func _get_info_text() -> String:
	return "Godot Native is fast but game-focused. PyBullet provides research-grade accuracy."


func _get_button_group_name() -> String:
	return "physics_backend"


func _get_category() -> String:
	return "physics"


func _populate_options(container: VBoxContainer) -> void:
	super._populate_options(container)


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary = {}) -> PhysicsBackend:
	return ModuleRegistry.create("physics", backend_id, config)
