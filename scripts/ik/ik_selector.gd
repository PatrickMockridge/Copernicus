# ik_selector.gd
# UI for selecting which IK solver to use

class_name IKSelector
extends BaseSelector

signal solver_selected(solver_class: String)


func _get_title() -> String:
	return "Select IK Solver"


func _get_info_text() -> String:
	return "Analytical IK works for simple chains. MoveIt provides industry-grade accuracy for complex robots."


func _get_button_group_name() -> String:
	return "ik_solver"


func _get_category() -> String:
	return "ik"


func _on_apply_pressed() -> void:
	solver_selected.emit(_selected_id)
	queue_free()


static func create_solver(solver_id: String, config: Dictionary = {}) -> IKSolver:
	return ModuleRegistry.create("ik", solver_id, config)
