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
	overlay.color = UiTheme.color("backdrop")
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Centered dialog, sized to content (not a fixed box).
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var dialog = PanelContainer.new()
	dialog.custom_minimum_size = Vector2(360, 0)
	dialog.add_theme_stylebox_override("panel", UiTheme.style("panel"))
	center.add_child(dialog)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", UiTheme.space("m"))
	dialog.add_child(content)

	# Title + message
	content.add_child(UiLabel.new().setup(_title, UiLabel.Kind.HEADING, UiLabel.Tone.PRIMARY))
	var msg := UiLabel.new().setup(_message, UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size.x = 320
	content.add_child(msg)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", UiTheme.space("s"))
	content.add_child(btn_hbox)

	var cancel_btn = Button.new()
	cancel_btn.text = _cancel_text
	cancel_btn.pressed.connect(_on_cancel)
	btn_hbox.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = _confirm_text
	confirm_btn.pressed.connect(_on_confirm)
	btn_hbox.add_child(confirm_btn)
	confirm_btn.call_deferred("grab_focus")

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
	# Esc dismisses; Enter is handled by the focused confirm button (not globally).
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
