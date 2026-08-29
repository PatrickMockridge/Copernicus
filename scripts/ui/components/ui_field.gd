# ui_field.gd
# A labeled single-line input (label above a LineEdit).

class_name UiField
extends VBoxContainer

signal changed(text: String)

var _input: LineEdit


func setup(label: String, value: String = "", placeholder: String = "", secret: bool = false) -> UiField:
	add_theme_constant_override("separation", UiTheme.space("xs"))
	if not label.is_empty():
		add_child(UiLabel.new().setup(label, UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))
	_input = LineEdit.new()
	_input.text = value
	_input.placeholder_text = placeholder
	_input.secret = secret
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_stylebox_override("normal", UiTheme.style("input"))
	_input.add_theme_stylebox_override("focus", UiTheme.style("input"))
	_input.add_theme_color_override("font_color", UiTheme.color("text"))
	_input.text_changed.connect(func(t: String) -> void: changed.emit(t))
	add_child(_input)
	return self


func get_input() -> LineEdit:
	return _input


func value() -> String:
	return _input.text if _input else ""
