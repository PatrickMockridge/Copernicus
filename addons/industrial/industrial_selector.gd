# industrial_selector.gd
# UI for selecting which industrial robot backend to use

class_name IndustrialSelector
extends BaseSelector

signal backend_selected(backend_class: String)


func _get_title() -> String:
	return "Select Industrial Robot"


func _get_info_text() -> String:
	return "Mock Industrial is for testing. Real industrial connections require ROS 2 industrial packages."


func _get_button_group_name() -> String:
	return "industrial_backend"


func _get_category() -> String:
	return "industrial"


func _populate_options(container: VBoxContainer) -> void:
	super._populate_options(container)
	_add_option("ABB", "ABB (EtherNet/IP)", "ABB industrial robots via EtherNet/IP. Requires: ABB robot controller.", false)
	_add_option("UR", "Universal Robots", "Universal Robots (UR3/UR5/UR10) via RTDB. Requires: ur_robot_driver.", false)
	_add_option("FANUC", "FANUC (KAREL)", "FANUC industrial robots via KAREL. Requires: FANUC robot controller.", false)


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary) -> IndustrialBackend:
	return ModuleRegistry.create("industrial", backend_id, config)
