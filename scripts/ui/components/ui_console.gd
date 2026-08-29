# ui_console.gd
# The terminal: a flat Commodore-64-style screen — blue background, light-blue
# border frame, uppercase output, and a blinking block cursor input.

class_name UiConsole
extends PanelContainer

signal command_submitted(text: String)

var _output: TextEdit
var _input: TerminalInput
var _history: Array = []
var _history_index: int = -1


func configure(title: String = "Terminal") -> UiConsole:
	var frame := StyleBoxFlat.new()
	frame.bg_color = UiTheme.color("c64_bg")
	frame.set_border_width_all(2)
	frame.border_color = UiTheme.color("c64_text")
	add_theme_stylebox_override("panel", frame)

	var clear_sb := StyleBoxFlat.new()
	clear_sb.bg_color = Color(0, 0, 0, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	_output = TextEdit.new()
	_output.editable = false
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_output.add_theme_stylebox_override("normal", clear_sb)
	_output.add_theme_stylebox_override("focus", clear_sb)
	_output.add_theme_color_override("font_color", UiTheme.color("c64_text"))
	if UiTheme.font("mono"):
		_output.add_theme_font_override("font", UiTheme.font("mono"))
	v.add_child(_output)

	_input = TerminalInput.new()
	_input.custom_minimum_size.y = 28
	_input.add_theme_stylebox_override("normal", clear_sb)
	_input.add_theme_stylebox_override("focus", clear_sb)
	_input.add_theme_color_override("font_color", UiTheme.color("c64_text"))
	_input.add_theme_color_override("caret_color", UiTheme.color("c64_text"))
	if UiTheme.font("mono"):
		_input.add_theme_font_override("font", UiTheme.font("mono"))
	_input.submitted.connect(_on_submit)
	_input.history_nav.connect(_on_history_nav)
	v.add_child(_input)
	return self


func echo(line: String) -> void:
	if not _output:
		return
	_output.text += line.to_upper() + "\n"
	var sb := _output.get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value


func clear() -> void:
	if _output:
		_output.text = ""


func focus_input() -> void:
	if _input:
		_input.grab_focus()


## Pre-fill the prompt (e.g. from the command palette) and focus it.
func set_input(text: String) -> void:
	_input.text = text
	_input.caret_column = _input.text.length()
	_input.grab_focus()


func _on_submit(t: String) -> void:
	if not t.strip_edges().is_empty():
		_history.append(t)
	_history_index = _history.size()
	command_submitted.emit(t)


func _on_history_nav(delta: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + delta, 0, _history.size())
	if _history_index < _history.size():
		_input.text = _history[_history_index]
	else:
		_input.text = ""
	_input.caret_column = _input.text.length()
