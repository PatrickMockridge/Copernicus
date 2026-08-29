# ui_console.gd
# The terminal panel: a read-only output + a "> command" input with history.

class_name UiConsole
extends UiPanel

signal command_submitted(text: String)

var _output: TextEdit
var _input: LineEdit
var _history: Array = []
var _history_index: int = -1


func configure(title: String = "Terminal") -> UiConsole:
	setup(title)
	_output = TextEdit.new()
	_output.editable = false
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
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
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_gui)
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


func focus_input() -> void:
	if _input:
		_input.grab_focus()


## Pre-fill the prompt (e.g. from the command palette) and focus it.
func set_input(text: String) -> void:
	_input.text = text
	_input.caret_column = text.length()
	_input.grab_focus()


func _on_submit(t: String) -> void:
	_input.text = ""
	if not t.strip_edges().is_empty():
		_history.append(t)
	_history_index = _history.size()
	command_submitted.emit(t)


func _on_input_gui(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			_navigate_history(-1)
			accept_event()
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			accept_event()


func _navigate_history(delta: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + delta, 0, _history.size())
	if _history_index < _history.size():
		_input.text = _history[_history_index]
	else:
		_input.text = ""
	_input.caret_column = _input.text.length()
