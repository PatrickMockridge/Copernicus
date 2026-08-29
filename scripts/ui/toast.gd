# toast.gd
# Non-blocking toast notification that slides in from the bottom (click to dismiss).

class_name Toast
extends Control

enum Level { INFO, SUCCESS, WARNING, ERROR }

const ICONS := {
	Level.INFO: "i",
	Level.SUCCESS: "+",
	Level.WARNING: "!",
	Level.ERROR: "x",
}

var _tween: Tween
var _duration: float = 4.0


static func show_toast(parent: Node, message: String, level: Level = Level.INFO, duration: float = 4.0):
	var toast = load("res://scripts/ui/toast.gd").new()
	toast._duration = duration
	toast._build(message, level)
	parent.add_child(toast)
	toast._animate_in()
	return toast


func _border_color(level: Level) -> Color:
	match level:
		Level.SUCCESS:
			return UiTheme.color("success")
		Level.WARNING:
			return UiTheme.color("warning")
		Level.ERROR:
			return UiTheme.color("error")
		_:
			return UiTheme.color("accent")


func _bg_color(level: Level) -> Color:
	match level:
		Level.SUCCESS:
			return UiTheme.color("toast_success")
		Level.WARNING:
			return UiTheme.color("toast_warning")
		Level.ERROR:
			return UiTheme.color("toast_error")
		_:
			return UiTheme.color("toast_info")


func _build(message: String, level: Level) -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_bottom = 0
	offset_top = -60
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_click)

	var style = StyleBoxFlat.new()
	style.bg_color = _bg_color(level)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = _border_color(level)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Icon indicator
	var icon = Label.new()
	icon.text = ICONS[level]
	icon.add_theme_font_size_override("font_size", 16)
	icon.add_theme_color_override("font_color", _border_color(level))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.custom_minimum_size.x = 28
	hbox.add_child(icon)

	# Message
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	label.add_theme_color_override("font_color", UiTheme.color("text"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)


func _animate_in() -> void:
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "offset_top", -72, 0.25)
	_tween.tween_interval(_duration)
	_tween.tween_callback(queue_free)


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismiss()


func dismiss() -> void:
	if _tween:
		_tween.kill()
	queue_free()
