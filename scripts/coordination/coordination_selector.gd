class_name CoordinationSelector
extends BaseSelector
## UI for selecting which coordination backend to use.

signal backend_selected(backend_class: String)


func _get_title() -> String:
	return "Select Coordination Backend"


func _get_info_text() -> String:
	return "Mock Coordination is offline. RChain Coordination requires a running RNode."


func _get_button_group_name() -> String:
	return "coordination_backend"


func _get_apply_text() -> String:
	return "Use Backend"


func _get_category() -> String:
	return "coordination"


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary = {}) -> CoordinationCore:
	return ModuleRegistry.create("coordination", backend_id, config)
