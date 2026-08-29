# ui_activity_bar.gd
# The left icon rail. entries = [{id, glyph, title}].

class_name UiActivityBar
extends PanelContainer

signal activity_selected(id: String)

var _buttons: Dictionary = {}


func setup(entries: Array) -> UiActivityBar:
	custom_minimum_size.x = 48
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("panel")
	sb.border_width_right = 1
	sb.border_color = UiTheme.color("border")
	add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.space("xs"))
	add_child(v)

	for e in entries:
		var id: String = e["id"]
		var glyph: String = e["glyph"]
		var title: String = e["title"]
		var btn := UiButton.new().setup(glyph, UiButton.Variant.ICON)
		btn.tooltip_text = title
		btn.custom_minimum_size = Vector2(40, 40)
		btn.pressed.connect(_on_pressed.bind(id))
		v.add_child(btn)
		_buttons[id] = btn

	var spacer := UiSpacer.new().setup(false, true)
	v.add_child(spacer)
	return self


func _on_pressed(id: String) -> void:
	activity_selected.emit(id)


func set_active(id: String) -> void:
	for key in _buttons:
		var btn: UiButton = _buttons[key]
		btn.add_theme_color_override("font_color", UiTheme.color("accent") if key == id else UiTheme.color("text"))
