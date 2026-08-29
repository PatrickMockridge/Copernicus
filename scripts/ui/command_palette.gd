# command_palette.gd
# The Ctrl+Shift+P command palette — a modal search over CommandRegistry.

class_name CommandPalette
extends ModalLayer

var _input: LineEdit
var _list: VBoxContainer
var _scroll: ScrollContainer
var _results: Array = []
var _rows: Array = []


func _ready() -> void:
	super._ready()
	_build()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 400)
	CopernicusTheme.style_panel(panel)
	content().add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)

	v.add_child(CopernicusTheme.make_title_bar("Command Palette"))

	_input = LineEdit.new()
	_input.placeholder_text = "Type a command…"
	_input.text_changed.connect(_on_text_changed)
	_input.text_submitted.connect(_on_submitted)
	v.add_child(_input)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 300
	v.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_refresh("")
	_input.grab_focus()


func _on_text_changed(text: String) -> void:
	_refresh(text)


func _refresh(text: String) -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_results = CommandRegistry.query(text)

	var groups := CommandRegistry.group_by_category(_results)
	var idx := 0
	for cat in groups:
		_list.add_child(CopernicusTheme.make_section(cat))
		for cmd in groups[cat]:
			_list.add_child(_make_row(cmd, idx))
			idx += 1
	if _results.is_empty():
		_list.add_child(CopernicusTheme.make_empty_state("No commands", "No matching command."))


func _make_row(cmd: Dictionary, index: int) -> Button:
	var btn := Button.new()
	btn.text = str(cmd.get("label", ""))
	btn.tooltip_text = str(cmd.get("description", ""))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_row_pressed.bind(index))
	_rows.append(btn)
	return btn


func _on_row_pressed(index: int) -> void:
	_run(index)


func _on_submitted(_text: String) -> void:
	if not _results.is_empty():
		_run(0)


func _run(index: int) -> void:
	if index < 0 or index >= _results.size():
		return
	var cmd: Dictionary = _results[index]
	CommandRegistry.run(cmd.get("id", ""))
	queue_free()


func _on_escape() -> void:
	queue_free()
