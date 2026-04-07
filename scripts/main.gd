# main.gd
# Robot AI Assistant - Code Agent Panel for GodotROS2
# Like Claude in VS Code, but for robot design in Godot

extends Control

# Preload AI classes instead of using autoloads
# GameAI temporarily disabled - requires Godot 4.4 fixes
# const GameAI = preload("res://addons/GameAI/core/ai.gd")
# const ROSAI = preload("res://addons/GameAI/integrations/ros/ros_ai.gd")
# const Result = preload("res://addons/GameAI/core/result.gd")

# ===== UI References =====
var _main_vbox: VBoxContainer
var _header: HBoxContainer
var _api_key_input: LineEdit
var _connect_ai_btn: Button
var _status_label: Label

var _context_panel: PanelContainer
var _context_label: Label
var _task_input: TextEdit
var _generate_btn: Button
var _behavior_select: OptionButton

var _output_label: Label
var _code_output: TextEdit
var _copy_btn: Button
var _add_to_scene_btn: Button

# ===== AI Instances =====
# var _gameai: Node  # GameAI disabled
# var _rosai: Node   # GameAI disabled
var _api_configured: bool = false

# ===== Constants =====
const BEHAVIOR_TYPES = ["obstacle_avoid", "wall_follow", "line_follow", "patrol", "chase", "flee"]

func _ready() -> void:
	_init_ai_instances()
	_setup_ui()
	_connect_signals()
	_update_ai_status(false, "Not connected")

func _init_ai_instances() -> void:
	# GameAI temporarily disabled - needs Godot 4.4 fixes
	# _gameai = GameAI.new()
	# _rosai = ROSAI.new()
	# add_child(_gameai)
	# add_child(_rosai)
	# _rosai.set_ai(_gameai)
	pass

func _setup_ui() -> void:
	_main_vbox = VBoxContainer.new()
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_vbox)

	# ---- Header ----
	_header = HBoxContainer.new()
	_main_vbox.add_child(_header)

	var title = Label.new()
	title.text = "Robot AI Assistant"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title)

	var api_key_label = Label.new()
	api_key_label.text = "API Key:"
	_header.add_child(api_key_label)

	_api_key_input = LineEdit.new()
	_api_key_input.placeholder_text = "sk-ant-..."
	_api_key_input.secret = true
	_api_key_input.custom_minimum_size.x = 200
	_api_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_api_key_input)

	_connect_ai_btn = Button.new()
	_connect_ai_btn.text = "Connect AI"
	_connect_ai_btn.pressed.connect(_on_connect_ai)
	_header.add_child(_connect_ai_btn)

	_status_label = Label.new()
	_status_label.text = "Not connected"
	_header.add_child(_status_label)

	# ---- Context Panel ----
	_context_panel = PanelContainer.new()
	_context_panel.custom_minimum_size.y = 60
	_main_vbox.add_child(_context_panel)

	var context_scroll = ScrollContainer.new()
	context_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	_context_panel.add_child(context_scroll)

	_context_label = Label.new()
	_context_label.text = "Context: No robot selected. Add a robot to the scene to enable AI context."
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	context_scroll.add_child(_context_label)

	# ---- Task Input ----
	var task_label = Label.new()
	task_label.text = "Task:"
	_main_vbox.add_child(task_label)

	_task_input = TextEdit.new()
	_task_input.custom_minimum_size.y = 80
	_task_input.placeholder_text = "e.g., 'Generate obstacle avoidance behavior' or 'Debug: robot drifts left' or 'Explain PID control math'"
	_main_vbox.add_child(_task_input)

	# ---- Generate Controls ----
	var generate_hbox = HBoxContainer.new()
	_main_vbox.add_child(generate_hbox)

	_behavior_select = OptionButton.new()
	_behavior_select.custom_minimum_size.x = 150
	for behavior in BEHAVIOR_TYPES:
		_behavior_select.add_item(behavior)
	generate_hbox.add_child(_behavior_select)

	_generate_btn = Button.new()
	_generate_btn.text = "Generate Behavior"
	_generate_btn.pressed.connect(_on_generate_behavior)
	_generate_btn.disabled = true
	generate_hbox.add_child(_generate_btn)

	var explain_btn = Button.new()
	explain_btn.text = "Explain Topic"
	explain_btn.pressed.connect(_on_explain_topic)
	generate_hbox.add_child(explain_btn)

	var debug_btn = Button.new()
	debug_btn.text = "Debug Issue"
	debug_btn.pressed.connect(_on_debug_issue)
	generate_hbox.add_child(debug_btn)

	# ---- Code Output ----
	_output_label = Label.new()
	_output_label.text = "Generated Code:"
	_main_vbox.add_child(_output_label)

	_code_output = TextEdit.new()
	_code_output.custom_minimum_size.y = 200
	_code_output.editable = false
	_main_vbox.add_child(_code_output)

	# ---- Action Buttons ----
	var action_hbox = HBoxContainer.new()
	_main_vbox.add_child(action_hbox)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy Code"
	_copy_btn.pressed.connect(_on_copy_code)
	action_hbox.add_child(_copy_btn)

	_add_to_scene_btn = Button.new()
	_add_to_scene_btn.text = "Add to Scene"
	_add_to_scene_btn.pressed.connect(_on_add_to_scene)
	_add_to_scene_btn.disabled = true
	action_hbox.add_child(_add_to_scene_btn)

func _connect_signals() -> void:
	# GameAI signals temporarily disabled
	# _rosai.behavior_generated.connect(_on_behavior_generated)
	# etc.
	pass

func _update_ai_status(configured: bool, message: String) -> void:
	_api_configured = configured
	_status_label.text = message
	_generate_btn.disabled = not configured
	if configured:
		_connect_ai_btn.text = "Connected"
		_connect_ai_btn.disabled = true
		_api_key_input.editable = false

# ===== AI Connection =====

func _on_connect_ai() -> void:
	_update_ai_status(false, "GameAI disabled - needs Godot 4.4 fixes")
	# var api_key = _api_key_input.text.strip_edges()
	# if api_key.is_empty():
	# 	_update_ai_status(false, "Error: API key required")
	# 	return
	# etc.

# ===== AI Generation =====

func _on_generate_behavior() -> void:
	_code_output.text = "GameAI disabled - needs Godot 4.4 fixes"
	_update_ai_status(false, "GameAI disabled")

func _on_explain_topic() -> void:
	_code_output.text = "GameAI disabled - needs Godot 4.4 fixes"
	_update_ai_status(false, "GameAI disabled")

func _on_debug_issue() -> void:
	_code_output.text = "GameAI disabled - needs Godot 4.4 fixes"
	_update_ai_status(false, "GameAI disabled")

# ===== Signal Handlers (AI Responses) =====

func _on_behavior_generated(result) -> void:
	_display_result(result, "behavior")

func _on_sensor_processor_generated(result) -> void:
	_display_result(result, "sensor processor")

func _on_controller_generated(result) -> void:
	_display_result(result, "controller")

func _on_topic_explained(result) -> void:
	_display_result(result, "topic explanation")

func _on_diagnosis_completed(result) -> void:
	_display_result(result, "diagnosis")

func _on_state_machine_generated(result) -> void:
	_display_result(result, "state machine")

func _on_vision_pipeline_generated(result) -> void:
	_display_result(result, "vision pipeline")

func _on_waypoint_controller_generated(result) -> void:
	_display_result(result, "waypoint controller")

func _on_multi_robot_logic_generated(result) -> void:
	_display_result(result, "multi-robot logic")

func _on_robot_brain_generated(result) -> void:
	_display_result(result, "robot brain")

func _display_result(result, operation: String) -> void:
	if result.is_ok():
		var content = result.ok_value()
		if content is Dictionary:
			content = content.get("content", str(content))
		_code_output.text = str(content)
		_add_to_scene_btn.disabled = false
		_status_label.text = operation.capitalize() + " generated successfully"
	else:
		var err = result.err_value()
		var msg = err.get("message", str(err)) if err is Dictionary else str(err)
		_code_output.text = "Error: " + msg
		_add_to_scene_btn.disabled = true
		_status_label.text = "Error generating " + operation

# ===== Action Buttons =====

func _on_copy_code() -> void:
	if _code_output.text.is_empty():
		return
	DisplayServer.clipboard_set(_code_output.text)
	_status_label.text = "Code copied to clipboard"

func _on_add_to_scene() -> void:
	_status_label.text = "Add to Scene: Feature not yet implemented"

func _process(delta: float) -> void:
	pass