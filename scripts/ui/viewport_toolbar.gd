# viewport_toolbar.gd
# Reusable overlay toolbar for any SubViewportContainer.
# Attach as child of a SubViewportContainer and wire signals.

class_name ViewportToolbar
extends HBoxContainer

signal wireframe_toggled(enabled: bool)
signal grid_toggled(enabled: bool)
signal lighting_preset_changed(preset: String)
signal snap_toggled(enabled: bool)
signal reset_view()

var _wireframe_on: bool = false
var _grid_on: bool = true
var _snap_on: bool = false
var _lighting_index: int = 0
var _lighting_presets: Array[String] = ["Studio", "Outdoor", "Dark"]
var _buttons: Dictionary = {}
var _fps_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_setup_style()
	_build_buttons()


func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.7)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("normal", style)


func _build_buttons() -> void:
	_add_toggle("wireframe", "Wire", _on_toggle_wireframe)
	_add_cycle("lighting", "Studio", _on_cycle_lighting)
	_add_toggle("grid", "Grid", _on_toggle_grid)
	_add_toggle("snap", "Snap", _on_toggle_snap)
	_add_action("reset", "Reset", _on_reset_view)

	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	_fps_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_fps_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(_fps_label)

	_update_button_states()


func _add_toggle(id: String, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	btn.pressed.connect(callback)
	add_child(btn)
	_buttons[id] = btn


func _add_cycle(id: String, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	btn.pressed.connect(callback)
	add_child(btn)
	_buttons[id] = btn


func _add_action(id: String, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	btn.pressed.connect(callback)
	add_child(btn)
	_buttons[id] = btn


func _on_toggle_wireframe() -> void:
	_wireframe_on = not _wireframe_on
	wireframe_toggled.emit(_wireframe_on)
	_update_button_states()


func _on_toggle_grid() -> void:
	_grid_on = not _grid_on
	grid_toggled.emit(_grid_on)
	_update_button_states()


func _on_toggle_snap() -> void:
	_snap_on = not _snap_on
	snap_toggled.emit(_snap_on)
	_update_button_states()


func _on_cycle_lighting() -> void:
	_lighting_index = (_lighting_index + 1) % _lighting_presets.size()
	var preset = _lighting_presets[_lighting_index]
	_buttons["lighting"].text = preset
	lighting_preset_changed.emit(preset)


func _on_reset_view() -> void:
	reset_view.emit()


func _update_button_states() -> void:
	if _buttons.has("wireframe"):
		_set_btn_color(_buttons["wireframe"], _wireframe_on)
	if _buttons.has("grid"):
		_set_btn_color(_buttons["grid"], _grid_on)
	if _buttons.has("snap"):
		_set_btn_color(_buttons["snap"], _snap_on)


func _set_btn_color(btn: Button, active: bool) -> void:
	btn.add_theme_color_override("font_color", CopernicusTheme.ACCENT if active else CopernicusTheme.TEXT_DISABLED)


func set_fps(fps: int) -> void:
	_fps_label.text = "FPS: %d" % fps
