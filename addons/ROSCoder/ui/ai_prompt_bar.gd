# ai_prompt_bar.gd
# Prompt input + action buttons for code generation

class_name AIPromptBar
extends Control

signal generate_requested(prompt: String)
signal run_requested()
signal deploy_requested()
signal save_requested()
signal launch_generate_requested(node_name: String, package_name: String)

const PRESETS = {
	"Obstacle Avoidance": "Generate an obstacle avoidance node for TurtleBot4 using rclpy. Use laser scan data to detect obstacles and cmd_vel to navigate around them.",
	"Wall Following": "Generate a wall following node for TurtleBot4 using rclpy. Use laser scan to detect wall distance and maintain a following distance while navigating.",
	"Line Following": "Generate a line following node for TurtleBot4 using rclpy. Use camera or sensor data to follow a line on the ground.",
	"Patrol": "Generate a patrol node for TurtleBot4 using rclpy. Navigate between multiple waypoints in sequence and repeat.",
	"Person Following": "Generate a person following node for TurtleBot4 using rclpy. Detect and track a person using camera/depth sensor and follow them.",
	"Navigation": "Generate a navigation node for TurtleBot4 using rclpy. Use Nav2 or simple go-to-goal behavior with obstacle avoidance.",
	"Custom": ""
}

var _prompt_input: LineEdit
var _preset_selector: OptionButton
var _generate_btn: Button
var _run_btn: Button
var _save_btn: Button
var _launch_btn: Button
var _deploy_btn: Button


func _init() -> void:
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	var preset_label = Label.new()
	preset_label.text = "Preset:"
	hbox.add_child(preset_label)

	_preset_selector = OptionButton.new()
	_preset_selector.add_item("Custom")
	for key in PRESETS.keys():
		if key != "Custom":
			_preset_selector.add_item(key)
	_preset_selector.item_selected.connect(_on_preset_selected)
	hbox.add_child(_preset_selector)

	_prompt_input = LineEdit.new()
	_prompt_input.placeholder_text = "e.g., Generate obstacle avoidance node for TurtleBot4"
	_prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_input.custom_minimum_size.x = 300
	hbox.add_child(_prompt_input)

	_generate_btn = Button.new()
	_generate_btn.text = "Generate"
	_generate_btn.pressed.connect(_on_generate)
	hbox.add_child(_generate_btn)

	_run_btn = Button.new()
	_run_btn.text = "Run"
	_run_btn.pressed.connect(_on_run)
	hbox.add_child(_run_btn)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.pressed.connect(_on_save)
	hbox.add_child(_save_btn)

	_launch_btn = Button.new()
	_launch_btn.text = "Launch"
	_launch_btn.pressed.connect(_on_launch)
	hbox.add_child(_launch_btn)

	_deploy_btn = Button.new()
	_deploy_btn.text = "Deploy"
	_deploy_btn.pressed.connect(_on_deploy)
	hbox.add_child(_deploy_btn)


func _on_generate() -> void:
	var selected_idx = _preset_selector.get_selected_id()
	var selected_text = _preset_selector.get_item_text(selected_idx)

	var prompt: String
	if selected_text == "Custom" or not PRESETS.has(selected_text):
		prompt = _prompt_input.text.strip_edges()
	else:
		prompt = PRESETS[selected_text]
		if not _prompt_input.text.strip_edges().is_empty():
			prompt += " " + _prompt_input.text.strip_edges()

	if not prompt.is_empty():
		generate_requested.emit(prompt)


func _on_preset_selected(index: int) -> void:
	var selected_text = _preset_selector.get_item_text(index)
	if selected_text != "Custom" and PRESETS.has(selected_text):
		_prompt_input.text = ""
		_prompt_input.placeholder_text = PRESETS[selected_text].split(".")[0] + "..."
	else:
		_prompt_input.placeholder_text = "e.g., Generate obstacle avoidance node for TurtleBot4"


func _on_run() -> void:
	run_requested.emit()


func _on_save() -> void:
	save_requested.emit()


func _on_launch() -> void:
	launch_generate_requested.emit("robot_node", "robot_bringup")


func _on_deploy() -> void:
	deploy_requested.emit()
