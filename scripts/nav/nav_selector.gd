# nav_selector.gd
# UI for selecting which navigation planner to use

class_name NavSelector
extends Control

signal planner_selected(planner_class: String)
signal cancelled()

const NavPlanner = preload("res://scripts/nav/nav_planner.gd")
const AStarGridPlanner = preload("res://scripts/nav/astar_grid_planner.gd")
const Nav2Bridge = preload("res://scripts/nav/nav2_bridge.gd")

# UI elements
var _panel: PanelContainer
var _title: Label
var _planner_list: VBoxContainer
var _planner_options: Array = []

var _selected_planner: String = "AStarGridPlanner"
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
	_title.text = "Select Navigation Planner"
	_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_title)

	var sep = HSeparator.new()
	content.add_child(sep)

	# Planner list
	_planner_list = VBoxContainer.new()
	_planner_list.custom_minimum_size.y = 200
	content.add_child(_planner_list)

	# Add planner options
	_add_planner_option("AStarGridPlanner", "A* Grid Planner",
		"Pure GDScript A* path planner. Works on occupancy grids. No external dependencies.",
		AStarGridPlanner.is_available())

	_add_planner_option("Nav2Bridge", "Nav2 (ROS2)",
		"Industry-standard navigation via ROS2 Nav2. Provides SLAM, global planning, and localization.",
		Nav2Bridge.is_available())

	# Separator
	var sep2 = HSeparator.new()
	content.add_child(sep2)

	# Info label
	var info = Label.new()
	info.text = "A* Grid Planner works for simple indoor navigation. Nav2 provides industry-grade SLAM and path planning."
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = Box.ALIGNMENT_END
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


func _add_planner_option(planner_id: String, title: String, description: String, available: bool) -> void:
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
	radio.button_group = "nav_planner"
	radio.text = ""
	radio.toggled.connect(_on_planner_toggled.bind(planner_id))
	if not available:
		radio.disabled = true
	hbox.add_child(radio)

	# Text
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title + (" (Unavailable)" if not available else "")
	if not available:
		title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(desc_label)

	_planner_list.add_child(option_container)
	_planner_options.append({
		"id": planner_id,
		"radio": radio,
		"available": available
	})

	# Select first available by default
	if available and _selected_planner == "AStarGridPlanner":
		radio.set_pressed_no_signal(true)
		_selected_planner = planner_id


func _on_planner_toggled(toggled: bool, planner_id: String) -> void:
	if toggled:
		_selected_planner = planner_id


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_apply_pressed() -> void:
	planner_selected.emit(_selected_planner)
	queue_free()


## ===== Static Helpers =====

## Get the planner class by name
static func get_planner_class(planner_id: String) -> NavPlanner:
	match planner_id:
		"AStarGridPlanner":
			return AStarGridPlanner.new()
		"Nav2Bridge":
			return Nav2Bridge.new()
		_:
			return AStarGridPlanner.new()


## Check which planners are available
static func get_available_planners() -> Array:
	var available = []
	if AStarGridPlanner.is_available():
		available.append("AStarGridPlanner")
	if Nav2Bridge.is_available():
		available.append("Nav2Bridge")
	return available


## Create a configured planner
static func create_planner(planner_id: String, config: Dictionary = {}) -> NavPlanner:
	var planner = get_planner_class(planner_id)
	planner.initialize(config)
	return planner
