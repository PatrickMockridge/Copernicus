# ui_console.gd
# The terminal panel: a read-only output + a "> command" input.

class_name UiConsole
extends UiPanel

signal command_submitted(text: String)

var _output: TextEdit
var _input: LineEdit


func configure(title: String = "Terminal") -> UiConsole:
	setup(title)
	_output = TextEdit.new()
	_output.editable = false
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if UiTheme.font("mono"):
		_output.add_theme_font_override("font", UiTheme.font("mono"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	_output.add_theme_stylebox_override("normal", sb)
	_output.add_theme_stylebox_override("focus", sb)
	body().add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = "> command"
	if UiTheme.font("mono"):
		_input.add_theme_font_override("font", UiTheme.font("mono"))
	_input.add_theme_stylebox_override("normal", UiTheme.style("input"))
	_input.add_theme_stylebox_override("focus", UiTheme.style("input"))
	_input.text_submitted.connect(func(t: String) -> void: command_submitted.emit(t))
	body().add_child(_input)
	return self


func echo(line: String) -> void:
	if not _output:
		return
	_output.text += line + "\n"
	var sb := _output.get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value


func clear() -> void:
	if _output:
		_output.text = ""
