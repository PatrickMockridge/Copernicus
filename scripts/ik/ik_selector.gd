# ik_selector.gd
# UI for selecting which IK solver to use

class_name IKSelector
extends Control

const ConfirmDialogClass = preload("res://scripts/ui/confirm_dialog.gd")

signal solver_selected(solver_class: String)
signal cancelled()

const IKSolver = preload("res://scripts/ik/ik_solver.gd")
const AnalyticalIKSolver = preload("res://scripts/ik/analytical_ik_solver.gd")
const MoveItIKBridge = preload("res://scripts/ik/moveit_ik_bridge.gd")

# UI elements
var _panel: PanelContainer
var _title: Label
var _solver_list: VBoxContainer
var _solver_options: Array = []

var _selected_solver: String = "AnalyticalIKSolver"
var _default_solver: String = "AnalyticalIKSolver"
var _cancel_btn: Button
var _apply_btn: Button


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Main panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.25, 0.3, 1)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)

	var content = VBoxContainer.new()
	_panel.add_child(content)

	# Title
	_title = Label.new()
	_title.text = "Select IK Solver"
	_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_title)

	var sep = HSeparator.new()
	content.add_child(sep)

	# Solver list
	_solver_list = VBoxContainer.new()
	_solver_list.custom_minimum_size.y = 220
	content.add_child(_solver_list)

	# Add solver options
	_add_solver_option("AnalyticalIKSolver", "Analytical IK",
		"Pure GDScript IK solvers (CCD, FABRIK). No external dependencies. Good for simple chains.",
		AnalyticalIKSolver.is_available())

	_add_solver_option("MoveItIKBridge", "MoveIt (ROS2)",
		"Industry-grade IK via ROS2/MoveIt. Requires ROS2 + MoveIt configured.",
		MoveItIKBridge.is_available())

	# Separator
	var sep2 = HSeparator.new()
	content.add_child(sep2)

	# Info label
	var info = Label.new()
	info.text = "Analytical IK works for simple chains. MoveIt provides industry-grade accuracy for complex robots."
	info.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(btn_hbox)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_hbox.add_child(_cancel_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10
	btn_hbox.add_child(spacer)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply"
	_apply_btn.pressed.connect(_on_apply_pressed)
	_apply_btn.disabled = false
	btn_hbox.add_child(_apply_btn)


func _add_solver_option(solver_id: String, title: String, description: String, available: bool) -> void:
	var option_container = PanelContainer.new()

	var option_style = StyleBoxFlat.new()
	option_style.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	option_style.set_corner_radius_all(4)
	option_style.set_border_width_all(1)
	option_style.border_color = Color(0.3, 0.3, 0.35, 1)
	option_container.add_theme_stylebox_override("panel", option_style)

	var hbox = HBoxContainer.new()
	option_container.add_child(hbox)

	# Radio button
	var radio = CheckBox.new()
	radio.button_group = "ik_solver"
	radio.text = ""
	radio.toggled.connect(_on_solver_toggled.bind(solver_id))
	if not available:
		radio.disabled = true
	hbox.add_child(radio)

	# Text
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title + (" (Unavailable)" if not available else "")
	if not available:
		title_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_DISABLED)
	else:
		title_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	vbox.add_child(desc_label)

	_solver_list.add_child(option_container)
	_solver_options.append({
		"id": solver_id,
		"radio": radio,
		"available": available
	})

	# Select first available by default
	if available and _selected_solver == "AnalyticalIKSolver":
		radio.set_pressed_no_signal(true)
		_selected_solver = solver_id


func _on_solver_toggled(toggled: bool, solver_id: String) -> void:
	if toggled:
		_selected_solver = solver_id


func _on_cancel_pressed() -> void:
	if _selected_solver != _default_solver:
		var dialog = ConfirmDialogClass.ask(self, "Discard Changes?", "You changed your selection. Discard it?", "Discard", "Keep Editing")
		dialog.confirmed.connect(func():
			cancelled.emit()
			queue_free()
		)
	else:
		cancelled.emit()
		queue_free()


func _on_apply_pressed() -> void:
	solver_selected.emit(_selected_solver)
	queue_free()


## ===== Static Helpers =====

## Get the solver class by name
static func get_solver_class(solver_id: String) -> IKSolver:
	match solver_id:
		"AnalyticalIKSolver":
			return AnalyticalIKSolver.new()
		"MoveItIKBridge":
			return MoveItIKBridge.new()
		_:
			return AnalyticalIKSolver.new()


## Check which solvers are available
static func get_available_solvers() -> Array:
	var available = []
	if AnalyticalIKSolver.is_available():
		available.append("AnalyticalIKSolver")
	if MoveItIKBridge.is_available():
		available.append("MoveItIKBridge")
	return available


## Create a configured solver
static func create_solver(solver_id: String, config: Dictionary = {}) -> IKSolver:
	var solver = get_solver_class(solver_id)
	solver.initialize(config)
	return solver
