# viewport_toolbar.gd
# Overlay toolbar for the 3D viewport. A PanelContainer (real translucent
# backdrop) with an inner HBox of compact buttons.

class_name ViewportToolbar
extends PanelContainer

signal wireframe_toggled(enabled: bool)
signal grid_toggled(enabled: bool)
signal reset_view()

var _wireframe_on: bool = false
var _grid_on: bool = true
var _buttons: Dictionary = {}
var _fps_label: UiLabel


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_setup_style()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.space("xs"))
	add_child(h)
	_build_buttons(h)


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.color("viewport_overlay")
	style.content_margin_left = UiTheme.space("s")
	style.content_margin_right = UiTheme.space("s")
	style.content_margin_top = UiTheme.space("xs")
	style.content_margin_bottom = UiTheme.space("xs")
	add_theme_stylebox_override("panel", style)


func _build_buttons(h: HBoxContainer) -> void:
	_add_button(h, "wireframe", "Wire", _on_toggle_wireframe)
	_add_button(h, "grid", "Grid", _on_toggle_grid)
	_add_button(h, "reset", "Reset", _on_reset_view)

	_fps_label = UiLabel.new().setup("", UiLabel.Kind.SMALL, UiLabel.Tone.FAINT)
	_fps_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(_fps_label)

	_update_button_states()


func _add_button(h: HBoxContainer, id: String, text: String, callback: Callable) -> void:
	var btn := UiButton.new().setup(text, UiButton.Variant.GHOST)
	btn.pressed.connect(callback)
	h.add_child(btn)
	_buttons[id] = btn


func _on_toggle_wireframe() -> void:
	_wireframe_on = not _wireframe_on
	wireframe_toggled.emit(_wireframe_on)
	_update_button_states()


func _on_toggle_grid() -> void:
	_grid_on = not _grid_on
	grid_toggled.emit(_grid_on)
	_update_button_states()


func _on_reset_view() -> void:
	reset_view.emit()


func _update_button_states() -> void:
	if _buttons.has("wireframe"):
		_set_btn_color(_buttons["wireframe"], _wireframe_on)
	if _buttons.has("grid"):
		_set_btn_color(_buttons["grid"], _grid_on)


func _set_btn_color(btn: Button, active: bool) -> void:
	btn.add_theme_color_override("font_color", UiTheme.color("accent") if active else UiTheme.color("text_faint"))


func set_fps(fps: int) -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % fps
