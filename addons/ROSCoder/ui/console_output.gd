# console_output.gd
# Terminal-style output display

class_name ConsoleOutput
extends Control

enum OutputType { INFO, SUCCESS, ERROR }

var _console: TextEdit
var _scroll: ScrollContainer


func _init() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	add_child(_scroll)

	_console = TextEdit.new()
	_console.set_name("Console")
	_console.editable = false
	_console.custom_minimum_size.y = 120
	_console.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_console)


func print_output(text: String, type: String = "info") -> void:
	var color: Color
	match type:
		"success":
			color = Color(0.2, 1.0, 0.4)
		"error":
			color = Color(1.0, 0.3, 0.3)
		_:
			color = Color(0.9, 0.9, 0.9)

	var timestamp = Time.get_time_string_from_system()
	var line = "[%s] %s" % [timestamp, text]

	var prev_text = _console.text
	if not prev_text.is_empty():
		_console.text = prev_text + "\n" + line
	else:
		_console.text = line

	_console.set_caret_line(_console.get_line_count() - 1)
	_console.ensure_cursor_is_visible()


func clear() -> void:
	_console.text = ""
