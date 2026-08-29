# nav_selector.gd
# UI for selecting which navigation planner to use

class_name NavSelector
extends BaseSelector

signal planner_selected(planner_class: String)

# Preload backends so their _static_init registers them with ModuleRegistry.
const AStarGridPlanner = preload("res://scripts/nav/astar_grid_planner.gd")
const Nav2Bridge = preload("res://scripts/nav/nav2_bridge.gd")


func _get_title() -> String:
	return "Select Navigation Planner"


func _get_info_text() -> String:
	return "A* Grid Planner works for simple indoor navigation. Nav2 provides industry-grade SLAM and path planning."


func _get_button_group_name() -> String:
	return "nav_planner"


func _get_category() -> String:
	return "nav"


func _on_apply_pressed() -> void:
	planner_selected.emit(_selected_id)
	queue_free()


static func create_planner(planner_id: String, config: Dictionary = {}) -> NavPlanner:
	return ModuleRegistry.create("nav", planner_id, config)
