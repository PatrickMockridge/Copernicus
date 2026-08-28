# main.gd
# Robot AI Assistant - Code Agent Panel for GodotROS2
# Like Claude in VS Code, but for robot design in Godot

extends Control

const ToastClass = preload("res://scripts/ui/toast.gd")
const LoadingOverlayClass = preload("res://scripts/ui/loading_overlay.gd")

# Preload AI classes instead of using autoloads
const GameAI = preload("res://addons/GameAI/core/ai.gd")
const ROSAI = preload("res://addons/GameAI/integrations/ros/ros_ai.gd")
const GameAIResult = preload("res://addons/GameAI/core/result.gd")

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
var _gameai: Node
var _rosai: Node
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
	_gameai = GameAI.new()
	_rosai = ROSAI.new()
	add_child(_gameai)
	add_child(_rosai)
	_rosai.set_ai(_gameai)

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

	var ros_coder_btn = Button.new()
	ros_coder_btn.text = "ROS Coder"
	ros_coder_btn.pressed.connect(_on_open_ros_coder)
	_header.add_child(ros_coder_btn)

	var turtle_demo_btn = Button.new()
	turtle_demo_btn.text = "Turtle Demo"
	turtle_demo_btn.pressed.connect(_on_open_turtle_demo)
	_header.add_child(turtle_demo_btn)

	var marketplace_btn = Button.new()
	marketplace_btn.text = "Marketplace"
	marketplace_btn.pressed.connect(_on_open_marketplace)
	_header.add_child(marketplace_btn)

	var raas_btn = Button.new()
	raas_btn.text = "RaaS Demos"
	raas_btn.pressed.connect(_on_open_raas)
	_header.add_child(raas_btn)

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
	_rosai.behavior_generated.connect(_on_behavior_generated)
	_rosai.topic_explained.connect(_on_topic_explained)
	_rosai.diagnosis_completed.connect(_on_diagnosis_completed)

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
		_code_output.text = "Error: Not connected to AI"
		return
	var behavior = BEHAVIOR_TYPES[_behavior_select.get_selected_id()]
	_code_output.text = "Generating " + behavior + " behavior..."
	var result = _rosai.generate_behavior(behavior)
	# Result comes via signal - _on_behavior_generated will be called

func _on_explain_topic() -> void:
	if not _api_configured:
		_code_output.text = "Error: Not connected to AI"
		return
	_code_output.text = "Explaining topic..."
	var task = _task_input.text if not _task_input.text.is_empty() else "Explain PID control math"
	_rosai.explain_ros_topic(task, "")

func _on_debug_issue() -> void:
	if not _api_configured:
		_code_output.text = "Error: Not connected to AI"
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
		_add_to_scene_btn.disabled = false
		_status_label.text = operation.capitalize() + " generated successfully"
		_dismiss_loading_overlay()
		ToastClass.show_toast(self, operation.capitalize() + " generated", ToastClass.Level.SUCCESS)
	else:
		var err = result.err_value()
		var msg = err.get("message", str(err)) if err is Dictionary else str(err)
		_code_output.text = "Error: " + msg
		_add_to_scene_btn.disabled = true
		_dismiss_loading_overlay()
		_status_label.text = "Error generating " + operation
		ToastClass.show_toast(self, "Failed to generate " + operation, ToastClass.Level.ERROR)

# ===== Action Buttons =====

func _on_copy_code() -> void:
	if _code_output.text.is_empty():
		return
	DisplayServer.clipboard_set(_code_output.text)
	_status_label.text = "Code copied to clipboard"

func _on_add_to_scene() -> void:
	_status_label.text = "Add to Scene: Feature not yet implemented"

func _on_open_ros_coder() -> void:
	var ros_coder_scene = preload("res://scenes/ros_coder.tscn")
	var instance = ros_coder_scene.instantiate()
	add_child(instance)

func _on_open_turtle_demo() -> void:
	get_tree().change_scene_to_file("res://scenes/turtle_demo.tscn")

func _on_open_marketplace() -> void:
	# Overlay (not change_scene) so closing the marketplace returns to main.
	var marketplace_scene = preload("res://scenes/marketplace/marketplace_panel.tscn")
	var instance = marketplace_scene.instantiate()
	add_child(instance)

func _on_open_raas() -> void:
	get_tree().change_scene_to_file("res://scenes/rchain/raas_launcher.tscn")

func _refresh_context() -> void:
	var lines = []
	lines.append("Robot: " + _get_robot_status())
	lines.append("Physics: " + _get_physics_status())
	lines.append("ROS2: " + _get_ros2_status())
	lines.append("AI: " + ("Connected" if _api_configured else "Not connected"))
	_context_label.text = " | ".join(lines)


func _get_robot_status() -> String:
	var viewer = get_node_or_null("RobotViewer")
	if viewer and viewer.has_method("get_robot_root") and viewer.get_robot_root():
		return viewer.get_robot_root().name
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


func _process(delta: float) -> void:
	pass
func _dismiss_loading_overlay() -> void:
	for child in get_tree().current_scene.get_children():
		if child.get_script() == LoadingOverlayClass:
			child.dismiss()
