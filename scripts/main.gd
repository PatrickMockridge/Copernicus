# main.gd
# Robot Design POC - AI-powered robot creation with GameAI + GodotROS2

extends Control

# UI References
@onready var api_key_input: LineEdit
@onready var connect_btn: Button
@onready var status_label: Label
@onready var robot_type_input: OptionButton
@onready var sensors_input: TextEdit
@onready var generate_btn: Button
@onready var generated_code: TextEdit
@onready var code_output: TextEdit
@onready var behavior_type: OptionButton

var _connected: bool = false


func _ready() -> void:
	_setup_ui()
	_update_status("Disconnected - Enter API key to begin")


func _setup_ui() -> void:
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Robot Design AI - Proof of Concept"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# API Key Section
	var api_frame = _create_section("1. Connect to AI")
	vbox.add_child(api_frame)

	var api_hbox = HBoxContainer.new()
	api_frame.add_child(api_hbox)

	var api_label = Label.new()
	api_label.text = "Anthropic API Key:"
	api_hbox.add_child(api_label)

	var api_key = LineEdit.new()
	api_key.placeholder_text = "sk-ant-..."
	api_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_key.secret = true
	api_hbox.add_child(api_key)
	api_key_input = api_key

	var connect = Button.new()
	connect.text = "Connect"
	connect.pressed.connect(_on_connect_pressed)
	api_hbox.add_child(connect)
	connect_btn = connect

	_status_label = Label.new()
	_status_label.text = "Status: Not connected"
	vbox.add_child(_status_label)

	# Robot Configuration Section
	var config_frame = _create_section("2. Configure Robot")
	vbox.add_child(config_frame)

	var config_grid = GridContainer.new()
	config_grid.columns = 2
	config_frame.add_child(config_grid)

	# Robot Type
	var type_label = Label.new()
	type_label.text = "Robot Type:"
	config_grid.add_child(type_label)

	var type_dropdown = OptionButton.new()
	type_dropdown.add_item("Differential Drive", 0)
	type_dropdown.add_item("Quadruped", 1)
	type_dropdown.add_item("Arm Manipulator", 2)
	type_dropdown.add_item("Hovercraft", 3)
	type_dropdown.add_item("Custom", 4)
	config_grid.add_child(type_dropdown)
	robot_type_input = type_dropdown

	# Sensors
	var sensors_label = Label.new()
	sensors_label.text = "Sensors (comma-separated):"
	config_grid.add_child(sensors_label)

	var sensors_text = TextEdit.new()
	sensors_text.custom_minimum_size.y = 60
	config_grid.add_child(sensors_text)
	sensors_input = sensors_text

	# Behavior Type
	var behavior_label = Label.new()
	behavior_label.text = "Desired Behavior:"
	config_grid.add_child(behavior_label)

	var behavior_dropdown = OptionButton.new()
	behavior_dropdown.add_item("Obstacle Avoidance", 0)
	behavior_dropdown.add_item("Wall Following", 1)
	behavior_dropdown.add_item("Line Following", 2)
	behavior_dropdown.add_item("Patrol Waypoints", 3)
	behavior_dropdown.add_item("Chase Target", 4)
	behavior_dropdown.add_item("Flee from Threat", 5)
	config_grid.add_child(behavior_dropdown)
	behavior_type = behavior_dropdown

	# Generate Button
	generate_btn = Button.new()
	generate_btn.text = "Generate Robot Behavior with AI"
	generate_btn.pressed.connect(_on_generate_pressed)
	generate_btn.disabled = true
	vbox.add_child(generate_btn)

	# Code Output Section
	var code_frame = _create_section("3. Generated Code")
	vbox.add_child(code_frame)

	code_output = TextEdit.new()
	code_output.custom_minimum_size.y = 200
	code_output.editable = false
	code_output.scroll_following = true
	code_frame.add_child(code_output)

	# Action Buttons
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(action_hbox)

	var apply_btn = Button.new()
	apply_btn.text = "Apply to Robot"
	apply_btn.disabled = true
	action_hbox.add_child(apply_btn)

	var copy_btn = Button.new()
	copy_btn.text = "Copy Code"
	copy_btn.pressed.connect(_on_copy_pressed)
	action_hbox.add_child(copy_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	action_hbox.add_child(clear_btn)

	# Info Label
	var info = Label.new()
	info.text = "This POC demonstrates AI-generated robot behaviors using GameAI + GodotROS2"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(info)


var _status_label: Label

func _create_section(title: String) -> VBoxContainer:
	var frame = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)

	var header = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	frame.add_child(header)

	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 2
	frame.add_child(sep)

	return frame


func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = "Status: " + text


func _on_connect_pressed() -> void:
	var api_key = api_key_input.text.strip_edges()
	if api_key == "":
		_update_status("Error: Please enter API key")
		return

	_update_status("Connecting to Anthropic...")
	GameAI.configure({
		"anthropic": {"api_key": api_key},
		"default": "anthropic"
	})

	# Test connection
	var test_result = await GameAI.chat([
		{"role": "user", "content": "Hello, respond with just 'Connected' if you receive this."}
	])

	if test_result.is_ok():
		_connected = true
		generate_btn.disabled = false
		_update_status("Connected to Claude!")
	else:
		_connected = false
		_update_status("Connection failed: " + str(test_result.err_value()))


func _on_generate_pressed() -> void:
	if not _connected:
		_update_status("Error: Not connected to AI")
		return

	generate_btn.disabled = true
	generate_btn.text = "Generating..."
	code_output.text = "# Generating robot behavior...\n"

	var robot_types = ["Differential Drive", "Quadruped", "Arm Manipulator", "Hovercraft", "Custom"]
	var behaviors = ["obstacle_avoid", "wall_follow", "line_follow", "patrol", "chase", "flee"]

	var robot_type = robot_types[robot_type_input.selected]
	var behavior = behaviors[behavior_type.selected]
	var sensors_text = sensors_input.text.strip_edges()
	var sensors = sensors_text.split(",") if sensors_text else []

	_update_status("Generating %s behavior for %s..." % [behavior, robot_type])

	# Configure ROSAI
	ROSAI.set_ai(GameAI)

	# Generate behavior code
	var result = await ROSAI.generate_behavior(behavior, {
		"robot_type": robot_type,
		"sensors": sensors,
		"ros2_workspace": "/root/ros2_ws"
	})

	if result.is_ok():
		code_output.text = result.ok_value().content
		_update_status("Generation complete!")
	else:
		code_output.text = "# Error: " + str(result.err_value())
		_update_status("Generation failed")

	generate_btn.disabled = false
	generate_btn.text = "Generate Robot Behavior with AI"


func _on_copy_pressed() -> void:
	if code_output.text:
		DisplayServer.clipboard_set(code_output.text)
		_update_status("Code copied to clipboard!")


func _on_clear_pressed() -> void:
	code_output.text = ""
	_update_status("Cleared")
