# confirm_dialog.gd
# Modal confirmation dialog with title, message, and Confirm/Cancel buttons

class_name ConfirmDialog
extends CanvasLayer

signal confirmed()
signal dismissed()

var _title: String
var _message: String
var _confirm_text: String
var _cancel_text: String


static func ask(parent: Node, title: String, message: String,
		confirm_text: String = "Confirm", cancel_text: String = "Cancel"):
	var dialog = load("res://scripts/ui/confirm_dialog.gd").new()
	dialog._title = title
	dialog._message = message
	dialog._confirm_text = confirm_text
	dialog._cancel_text = cancel_text
	dialog._build()
	parent.add_child(dialog)
	return dialog


func _build() -> void:
	# Dimming overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Dialog box
	var dialog = PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.offset_left = -200
	dialog.offset_top = -80
	dialog.offset_right = 200
	dialog.offset_bottom = 80

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.98)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.25, 0.3, 1)
	style.set_content_margin_all(20)
	dialog.add_theme_stylebox_override("panel", style)
	add_child(dialog)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	dialog.add_child(content)

	# Title
	var title_label = Label.new()
	title_label.text = _title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	content.add_child(title_label)

	# Message
	var msg_label = Label.new()
	msg_label.text = _message
	msg_label.add_theme_font_size_override("font_size", 14)
	msg_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(msg_label)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 8)
	content.add_child(btn_hbox)

	var cancel_btn = Button.new()
	cancel_btn.text = _cancel_text
	cancel_btn.pressed.connect(_on_cancel)
	btn_hbox.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = _confirm_text
	confirm_btn.pressed.connect(_on_confirm)
	btn_hbox.add_child(confirm_btn)

	# Input handling
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)


func _on_confirm() -> void:
	confirmed.emit()
	queue_free()


func _on_cancel() -> void:
	dismissed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
	elif event.is_action_pressed("ui_accept"):
		_on_confirm()
