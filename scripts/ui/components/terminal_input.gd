# terminal_input.gd
# Single-line input with a C64-style blinking block cursor. Enter submits;
# up/down navigate history (emitted to the owner, UiConsole).

class_name TerminalInput
extends TextEdit

signal submitted(text: String)
signal history_nav(delta: int)


func _init() -> void:
	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	caret_type = TextEdit.CARET_TYPE_BLOCK
	caret_blink = true
	caret_blink_interval = 0.6


func _ready() -> void:
	var vsb := get_v_scroll_bar()
	if vsb:
		vsb.visible = false
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			submitted.emit(text.strip_edges())
			text = ""
		elif event.keycode == KEY_UP:
			history_nav.emit(-1)
		elif event.keycode == KEY_DOWN:
			history_nav.emit(1)
