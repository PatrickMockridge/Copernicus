# main.gd
# Robot AI Assistant - Code Agent Panel for GodotROS2
# Like Claude in VS Code, but for robot design in Godot

class_name AiAssistantPanel
extends Control

const GameAIResult = preload("res://addons/GameAI/core/result.gd")

# ===== UI References =====
var _main_vbox: VBoxContainer
var _work_area: VBoxContainer
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
var _explain_btn: Button
var _debug_btn: Button

# ===== AI Instances =====
var _gameai: Node
var _rosai: Node
var _viewer: Node = null
var _api_configured: bool = false

# ===== Constants =====
const BEHAVIOR_TYPES = ["obstacle_avoid", "wall_follow", "line_follow", "patrol", "chase", "flee"]

func _ready() -> void:
	_init_ai_instances()
	_setup_ui()
	_connect_signals()
	_update_ai_status(false, "Not connected")
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_refresh_context)
	add_child(timer)
	timer.start()

func _init_ai_instances() -> void:
	_gameai = get_node("/root/GameAI")
	_rosai = get_node("/root/ROSAI")
	_rosai.set_ai(_gameai)

func _setup_ui() -> void:
	var win = UiPanel.new().setup("Robot AI Assistant")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)

	_main_vbox = win.body()

	# ---- Header ----
	_header = HBoxContainer.new()
	_main_vbox.add_child(_header)

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

	var ros_coder_btn = Button.new()
	ros_coder_btn.text = "ROS Coder"
	ros_coder_btn.pressed.connect(_on_open_ros_coder)
	_header.add_child(ros_coder_btn)

	_work_area = VBoxContainer.new()
	_work_area.visible = false
	_main_vbox.add_child(_work_area)

	# ---- Context Panel ----
	_context_panel = PanelContainer.new()
	_context_panel.custom_minimum_size.y = 60
	_work_area.add_child(_context_panel)

	var context_scroll = ScrollContainer.new()
	context_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	_context_panel.add_child(context_scroll)

	_context_label = Label.new()
	_context_label.text = "Context: No robot selected. Add a robot to the scene to enable AI context."
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_context_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_scroll.add_child(_context_label)

	# ---- Task Input ----
	var task_label = Label.new()
	task_label.text = "Task:"
	_work_area.add_child(task_label)

	_task_input = TextEdit.new()
	_task_input.custom_minimum_size.y = 80
	_task_input.placeholder_text = "e.g., 'Generate obstacle avoidance behavior' or 'Debug: robot drifts left' or 'Explain PID control math'"
	_work_area.add_child(_task_input)

	# ---- Generate Controls ----
	var generate_hbox = HBoxContainer.new()
	_work_area.add_child(generate_hbox)

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

	_explain_btn = Button.new()
	_explain_btn.text = "Explain Topic"
	_explain_btn.pressed.connect(_on_explain_topic)
	generate_hbox.add_child(_explain_btn)

	_debug_btn = Button.new()
	_debug_btn.text = "Debug Issue"
	_debug_btn.pressed.connect(_on_debug_issue)
	generate_hbox.add_child(_debug_btn)

	# ---- Code Output ----
	_output_label = Label.new()
	_output_label.text = "Generated Code:"
	_work_area.add_child(_output_label)

	_code_output = TextEdit.new()
	_code_output.custom_minimum_size.y = 200
	_code_output.editable = false
	if UiTheme.font("mono"):
		_code_output.add_theme_font_override("font", UiTheme.font("mono"))
	_work_area.add_child(_code_output)

	# ---- Action Buttons ----
	var action_hbox = HBoxContainer.new()
	_work_area.add_child(action_hbox)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy Code"
	_copy_btn.pressed.connect(_on_copy_code)
	action_hbox.add_child(_copy_btn)

func _connect_signals() -> void:
	_rosai.behavior_generated.connect(_on_behavior_generated)
	_rosai.topic_explained.connect(_on_topic_explained)
	_rosai.diagnosis_completed.connect(_on_diagnosis_completed)

func _update_ai_status(configured: bool, message: String) -> void:
	_api_configured = configured
	if _work_area:
		_work_area.visible = configured
	_status_label.text = message
	_generate_btn.disabled = not configured
	_explain_btn.disabled = not configured
	_debug_btn.disabled = not configured
	if configured:
		_connect_ai_btn.text = "Connected"
		_connect_ai_btn.disabled = true
		_api_key_input.editable = false

# ===== AI Connection =====

func _on_connect_ai() -> void:
	# First try to get key from .env file (EnvService singleton), then fall back to UI input
	var api_key = EnvService.get_minimax_key()
	if api_key.is_empty():
		api_key = _api_key_input.text.strip_edges()

	if api_key.is_empty():
		_update_ai_status(false, "Error: API key required (use .env or enter manually)")
		return

	# Configure AI with the API key - default to minimax since that's what user provided
	_gameai.configure({"minimax": {"api_key": api_key}, "default": "minimax"})
	_update_ai_status(true, "Connected to Minimax")

# ===== AI Generation =====

func _on_generate_behavior() -> void:
	if not _api_configured:
		Toast.show_toast(self, "Not connected to AI", Toast.Level.WARNING)
		return
	var behavior = BEHAVIOR_TYPES[_behavior_select.get_selected_id()]
	_code_output.text = "Generating " + behavior + " behavior..."
	var result = _rosai.generate_behavior(behavior)
	# Result comes via signal - _on_behavior_generated will be called

func _on_explain_topic() -> void:
	if not _api_configured:
		Toast.show_toast(self, "Not connected to AI", Toast.Level.WARNING)
		return
	_code_output.text = "Explaining topic..."
	var task = _task_input.text if not _task_input.text.is_empty() else "Explain PID control math"
	_rosai.explain_ros_topic(task, "")

func _on_debug_issue() -> void:
	if not _api_configured:
		Toast.show_toast(self, "Not connected to AI", Toast.Level.WARNING)
		return
	_code_output.text = "Diagnosing issue..."
	var issue = _task_input.text if not _task_input.text.is_empty() else "robot drifts left"
	_rosai.diagnose_behavior_issue([issue])

# ===== Signal Handlers (AI Responses) =====

func _on_behavior_generated(result: GameAIResult) -> void:
	_display_result(result, "behavior")

func _on_sensor_processor_generated(result: GameAIResult) -> void:
	_display_result(result, "sensor processor")

func _on_controller_generated(result: GameAIResult) -> void:
	_display_result(result, "controller")

func _on_topic_explained(result: GameAIResult) -> void:
	_display_result(result, "topic explanation")

func _on_diagnosis_completed(result: GameAIResult) -> void:
	_display_result(result, "diagnosis")

func _on_state_machine_generated(result: GameAIResult) -> void:
	_display_result(result, "state machine")

func _on_vision_pipeline_generated(result: GameAIResult) -> void:
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
		_status_label.text = operation.capitalize() + " generated successfully"
		Toast.show_toast(self, operation.capitalize() + " generated", Toast.Level.SUCCESS)
	else:
		var err = result.err_value()
		var msg = err.get("message", str(err)) if err is Dictionary else str(err)
		_code_output.text = "Error: " + msg
		_status_label.text = "Error generating " + operation
		Toast.show_toast(self, "Failed to generate " + operation, Toast.Level.ERROR)

# ===== Action Buttons =====

func _on_copy_code() -> void:
	if _code_output.text.is_empty():
		return
	DisplayServer.clipboard_set(_code_output.text)
	_status_label.text = "Code copied to clipboard"

func _on_open_ros_coder() -> void:
	var ros_coder_scene = preload("res://scenes/ros_coder.tscn")
	var instance = ros_coder_scene.instantiate()
	add_child(instance)

func _refresh_context() -> void:
	var lines = []
	lines.append("Robot: " + _get_robot_status())
	lines.append("Physics: " + _get_physics_status())
	lines.append("ROS2: " + _get_ros2_status())
	lines.append("AI: " + ("Connected" if _api_configured else "Not connected"))
	_context_label.text = " | ".join(lines)


func set_viewer(viewer: Node) -> void:
	_viewer = viewer


func _get_robot_status() -> String:
	if _viewer and _viewer.has_method("get_robot_root") and _viewer.get_robot_root():
		return _viewer.get_robot_root().name
	return "None loaded"


func _get_physics_status() -> String:
	var reg = get_node_or_null("/root/ModuleRegistry")
	if reg and reg.has_module("physics", "GodotPhysicsBackend"):
		return "Godot Native"
	return "None active"


func _get_ros2_status() -> String:
	var bridge = get_node_or_null("/root/GodotROS2")
	if bridge and bridge.has_method("is_bridge_connected") and bridge.is_bridge_connected():
		return "Connected"
	return "Disconnected"


