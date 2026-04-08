# ai_prompt_bar.gd
# Prompt input + action buttons for code generation

class_name AIPromptBar
extends Control

signal generate_requested(prompt: String)
signal run_requested()
signal deploy_requested()

var _prompt_input: LineEdit
var _generate_btn: Button
var _run_btn: Button
var _deploy_btn: Button


func _init() -> void:
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	var prompt_label = Label.new()
	prompt_label.text = "Prompt:"
	hbox.add_child(prompt_label)

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

	_deploy_btn = Button.new()
	_deploy_btn.text = "Deploy"
	_deploy_btn.pressed.connect(_on_deploy)
	hbox.add_child(_deploy_btn)


func _on_generate() -> void:
	var prompt = _prompt_input.text.strip_edges()
	if not prompt.is_empty():
		generate_requested.emit(prompt)


func _on_run() -> void:
	run_requested.emit()


func _on_deploy() -> void:
	deploy_requested.emit()
