# ros_coder.gd
# ROS2 Python Coder - Minimalist IDE for ROS2 Python robotics coding

extends Control

const LoadingOverlayClass = preload("res://scripts/ui/loading_overlay.gd")
const ConfirmDialogClass = preload("res://scripts/ui/confirm_dialog.gd")

const CodeEditor = preload("res://addons/ROSCoder/ui/code_editor.gd")
const FileTree = preload("res://addons/ROSCoder/ui/file_tree.gd")
const AIPromptBar = preload("res://addons/ROSCoder/ui/ai_prompt_bar.gd")
const ConsoleOutput = preload("res://addons/ROSCoder/ui/console_output.gd")
const PythonCoder = preload("res://addons/ROSCoder/coders/python_coder.gd")

var _main_vbox: VBoxContainer
var _hsplit: HSplitContainer
var _vsplit: VSplitContainer
var _file_browser: FileTree
var _code_editor: CodeEditor
var _prompt_bar: AIPromptBar
var _console: ConsoleOutput
var _python_coder: PythonCoder
var _workspace_path: String = ""
var _loading_overlay = null
var _initial_content: String = ""


func _ready() -> void:
	_workspace_path = OS.get_environment("HOME") + "/.ros_workspace"
	_setup_ui()
	_connect_signals()
	# Set placeholder content so editor isn't empty on open
	_code_editor.set_content("#!/usr/bin/env python3\n# ROS2 Python Coder\n# Enter a prompt and click Generate, or open a file from the browser\n\nimport rclpy\nfrom rclpy.node import Node\n\n\ndef main(args=None):\n    rclpy.init(args=args)\n    node = Node('robot_node')\n    rclpy.spin(node)\n    node.destroy_node()\n    rclpy.shutdown()\n\n\nif __name__ == '__main__':\n    main()\n")
	_initial_content = _code_editor.get_content()


func _setup_ui() -> void:
	_main_vbox = VBoxContainer.new()
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_vbox)

	# Header
	var header = HBoxContainer.new()
	_main_vbox.add_child(header)

	var title = Label.new()
	title.text = "ROS2 Python Coder"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# Horizontal split: file browser | editor+console
	_hsplit = HSplitContainer.new()
	_main_vbox.add_child(_hsplit)

	# File browser (left panel)
	var file_panel = PanelContainer.new()
	file_panel.custom_minimum_size.x = 180
	_hsplit.add_child(file_panel)

	var file_scroll = ScrollContainer.new()
	file_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	file_panel.add_child(file_scroll)

	_file_browser = FileTree.new()
	_file_browser.set_name("FileTree")
	file_scroll.add_child(_file_browser)

	# Right side: vertical split editor + console
	var right_panel = VSplitContainer.new()
	_hsplit.add_child(right_panel)

	# Code editor
	_code_editor = CodeEditor.new()
	_code_editor.set_name("CodeEditor")
	right_panel.add_child(_code_editor)

	# Prompt bar
	_prompt_bar = AIPromptBar.new()
	_prompt_bar.set_name("PromptBar")
	_main_vbox.add_child(_prompt_bar)

	# Console output
	_console = ConsoleOutput.new()
	_console.set_name("Console")
	_main_vbox.add_child(_console)

	_vsplit = right_panel


func _connect_signals() -> void:
	_python_coder = PythonCoder.new()
	add_child(_python_coder)

	_file_browser.file_selected.connect(_on_file_selected)
	_prompt_bar.generate_requested.connect(_on_generate_requested)
	_prompt_bar.run_requested.connect(_on_run_requested)
	_prompt_bar.save_requested.connect(_on_save_requested)
	_prompt_bar.launch_generate_requested.connect(_on_launch_generate_requested)
	_prompt_bar.deploy_requested.connect(_on_deploy_requested)

	_python_coder.code_generated.connect(_on_code_generated)


func _on_file_selected(path: String) -> void:
	_code_editor.load_file(path)


func _on_generate_requested(prompt: String) -> void:
	_console.print_output("Generating code for: " + prompt, "info")
	_loading_overlay = LoadingOverlayClass.show_overlay(self, "Generating code...")
	var result = _python_coder.generate_code(prompt)
	if result.is_err():
		var err = result.err_value()
		var msg = err.get("message", str(err)) if err is Dictionary else str(err)
		_console.print_output("Error: " + msg, "error")
		_dismiss_loading()
		return

	var content = result.ok_value()
	var code: String
	if content is Dictionary:
		code = content.get("content", "")
	elif content is String:
		code = content
	else:
		code = str(content)

	_dismiss_loading()
	if not code.is_empty():
		_code_editor.set_content(code)
		_console.print_output("Code generated successfully", "success")
	else:
		_console.print_output("No code in AI response", "error")


func _on_code_generated(code: String) -> void:
	_dismiss_loading()
	_code_editor.set_content(code)
	_console.print_output("Code generated successfully", "success")


func _on_run_requested() -> void:
	var code = _code_editor.get_content()
	if code.is_empty():
		_console.print_output("No code to run", "error")
		return

	_console.print_output("Running code locally...", "info")
	var temp_file = "/tmp/ros2_test_node.py"
	var f = FileAccess.open(temp_file, FileAccess.WRITE)
	if f:
		f.store_string(code)
		f.close()

	var output = []
	var exit_code = OS.execute("python3", [temp_file], output, true)
	if exit_code == 0:
		_console.print_output(output[0] if output.size() > 0 else "Done", "success")
	else:
		_console.print_output(output[0] if output.size() > 0 else "Execution failed", "error")


func _on_save_requested() -> void:
	var current_file = _code_editor.get_current_file()
	if current_file.is_empty():
		_console.print_output("No file path set - use File Browser to select a location", "error")
		return

	if _code_editor.save_file():
		_console.print_output("Saved to " + current_file, "success")
	else:
		_console.print_output("Save failed", "error")


func _on_launch_generate_requested(node_name: String, package_name: String) -> void:
	_console.print_output("Generating launch file for: " + node_name, "info")
	var result = _python_coder.generate_launch_file(node_name, package_name)
	if result.is_err():
		var err = result.err_value()
		var msg = err.get("message", str(err)) if err is Dictionary else str(err)
		_console.print_output("Error: " + msg, "error")
		return

	var content = result.ok_value()
	var code: String
	if content is Dictionary:
		code = content.get("content", "")
	elif content is String:
		code = content
	else:
		code = str(content)

	if not code.is_empty():
		_code_editor.set_content(code)
		_console.print_output("Launch file generated successfully", "success")
	else:
		_console.print_output("No content in launch file", "error")


func _on_deploy_requested() -> void:
	var code = _code_editor.get_content()
	if code.is_empty():
		_console.print_output("No code to deploy", "error")
		return

	_loading_overlay = LoadingOverlayClass.show_overlay(self, "Deploying to robot...")
	var config_path = _workspace_path + "/config/robot_config.json"
	var config_file = FileAccess.open(config_path, FileAccess.READ)
	if not config_file:
		_console.print_output("No robot config at " + config_path, "error")
		_dismiss_loading()
		return

	var config = JSON.parse_string(config_file.get_as_text())
	if config == null or not config is Dictionary:
		_console.print_output("Invalid robot config", "error")
		_dismiss_loading()
		return

	var host = config.get("host", "")
	var port = config.get("port", 22)
	var username = config.get("username", "robot")
	var remote_path = config.get("remote_path", "/home/robot/catkin_ws/src/")

	if host.is_empty():
		_console.print_output("Robot host not configured", "error")
		_dismiss_loading()
		return

	_console.print_output("Deploying to " + username + "@" + host + "...", "info")
	_deploy_via_ssh(code, host, port, username, remote_path)


func _deploy_via_ssh(code: String, host: String, port: int, username: String, remote_path: String) -> void:
	var temp_file = "/tmp/ros2_deploy.py"
	var f = FileAccess.open(temp_file, FileAccess.WRITE)
	if f:
		f.store_string(code)
		f.close()

	var deploy_cmd = "ssh %s@%s -p %d 'cat > %s' < %s" % [username, host, port, remote_path, temp_file]
	var output = []
	var exit_code = OS.execute("bash", ["-c", deploy_cmd], output, true)
	if exit_code == 0:
		_dismiss_loading()
		_console.print_output("Deployed to " + remote_path, "success")
	else:
		_dismiss_loading()
		_console.print_output("Deploy failed: " + (output[0] if output.size() > 0 else "SSH error"), "error")


func _dismiss_loading() -> void:
	if _loading_overlay:
		_loading_overlay.dismiss()
		_loading_overlay = null


func _on_close() -> void:
	if _code_editor.is_dirty() and _code_editor.get_content() != _initial_content:
		var dialog = ConfirmDialogClass.ask(self, "Unsaved Changes", "You have unsaved changes. Discard them?", "Discard", "Keep Editing")
		dialog.confirmed.connect(queue_free)
	else:
		queue_free()
