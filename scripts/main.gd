# main.gd
# Robot Design POC - Main UI Controller
# Temporarily simplified to break circular dependency on GodotROS2 types

extends Control

# ===== UI References =====
var _status_label: Label
var _generate_btn: Button
var _code_output: TextEdit


func _ready() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_status_label = Label.new()
	_status_label.text = "Project loading..."
	vbox.add_child(_status_label)

	_code_output = TextEdit.new()
	_code_output.custom_minimum_size.y = 200
	_code_output.editable = false
	vbox.add_child(_code_output)

	_generate_btn = Button.new()
	_generate_btn.text = "Test Button"
	_generate_btn.pressed.connect(_on_test_pressed)
	vbox.add_child(_generate_btn)


func _on_test_pressed() -> void:
	_status_label.text = "Test button works!"


func _process(delta: float) -> void:
	pass