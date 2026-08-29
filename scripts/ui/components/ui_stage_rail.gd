# ui_stage_rail.gd
# The six Workbench Loop stages, with a highlight for the current one.

class_name UiStageRail
extends PanelContainer

signal stage_clicked(stage: String)

const STAGES := ["Acquire", "Inspect", "Configure", "Test", "Validate", "Publish"]

var _buttons: Dictionary = {}


func setup() -> UiStageRail:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.space("xs"))
	add_child(h)
	for s in STAGES:
		var btn := UiButton.new().setup(s, UiButton.Variant.GHOST)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_clicked.bind(s))
		h.add_child(btn)
		_buttons[s] = btn
	return self


func _on_clicked(stage: String) -> void:
	stage_clicked.emit(stage)


func set_active(stage: String) -> void:
	for key in _buttons:
		var btn: UiButton = _buttons[key]
		btn.add_theme_color_override("font_color", UiTheme.color("accent") if key == stage else UiTheme.color("text_muted"))
