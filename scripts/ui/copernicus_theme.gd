# copernicus_theme.gd
# Shared theme autoload — single source of truth for StyleBoxes, colors, spacing and fonts.

extends Node

const BG_DARK := Color(0.12, 0.12, 0.15, 0.95)
const BG_CARD := Color(0.18, 0.18, 0.22, 0.8)
const BORDER_DIM := Color(0.25, 0.25, 0.3, 1.0)
const BORDER_CARD := Color(0.3, 0.3, 0.35, 1.0)

const TEXT_PRIMARY := Color(0.9, 0.9, 0.9, 1.0)
const TEXT_SECONDARY := Color(0.6, 0.6, 0.65, 1.0)
const TEXT_DISABLED := Color(0.4, 0.4, 0.4, 1.0)

const ACCENT := Color(0.3, 0.6, 1.0, 1.0)
const SUCCESS := Color(0.2, 0.8, 0.3, 1.0)
const WARNING := Color(1.0, 0.7, 0.1, 1.0)
const ERROR := Color(0.9, 0.2, 0.2, 1.0)

const FONT_SIZE_TITLE := 22
const FONT_SIZE_HEADING := 18
const FONT_SIZE_BODY := 14
const FONT_SIZE_SMALL := 12

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 16
const SPACE_XL := 20

const RADIUS_SM := 4
const RADIUS_MD := 8

var _theme: Theme


func _ready() -> void:
	_theme = load("res://resources/themes/copernicus_theme.tres")
	_build_control_styles()


## Extend the .tres (Panels only) with the dark control styles, so controls stop
## rendering with Godot's stock light theme on the dark panels.
func _build_control_styles() -> void:
	# Button
	_theme.set_stylebox("normal", "Button", _button_style(Color(0.22, 0.22, 0.28), BORDER_DIM))
	_theme.set_stylebox("hover", "Button", _button_style(Color(0.27, 0.27, 0.34), BORDER_CARD))
	_theme.set_stylebox("pressed", "Button", _button_style(Color(0.15, 0.15, 0.2), BORDER_DIM))
	_theme.set_stylebox("disabled", "Button", _button_style(Color(0.16, 0.16, 0.2, 0.5), BORDER_DIM))
	_theme.set_stylebox("focus", "Button", _button_style(Color(0.22, 0.22, 0.28), ACCENT))
	_theme.set_color("font_color", "Button", TEXT_PRIMARY)
	_theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	# Label
	_theme.set_color("font_color", "Label", TEXT_PRIMARY)

	# LineEdit / TextEdit
	_theme.set_stylebox("normal", "LineEdit", _flat(Color(0.1, 0.1, 0.13), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("focus", "LineEdit", _flat(Color(0.1, 0.1, 0.13), ACCENT, RADIUS_SM))
	_theme.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	_theme.set_stylebox("normal", "TextEdit", _flat(Color(0.1, 0.1, 0.13), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("focus", "TextEdit", _flat(Color(0.1, 0.1, 0.13), ACCENT, RADIUS_SM))
	_theme.set_color("font_color", "TextEdit", TEXT_PRIMARY)

	# CheckBox (radio)
	_theme.set_stylebox("on", "CheckBox", _flat(ACCENT, ACCENT, RADIUS_SM))
	_theme.set_stylebox("off", "CheckBox", _flat(Color(0.16, 0.16, 0.2), BORDER_DIM, RADIUS_SM))
	_theme.set_color("font_color", "CheckBox", TEXT_PRIMARY)

	# HSeparator
	_theme.set_stylebox("separator", "HSeparator", _flat(BORDER_DIM, Color(0, 0, 0, 0), 0))

	# HSlider
	_theme.set_stylebox("slider", "HSlider", _flat(Color(0.4, 0.4, 0.45), Color(0, 0, 0, 0), 2))
	_theme.set_stylebox("grabber_area", "HSlider", _flat(Color(0.4, 0.4, 0.45), Color(0, 0, 0, 0), 2))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT, Color(0, 0, 0, 0), 2))

	# OptionButton
	_theme.set_stylebox("normal", "OptionButton", _button_style(Color(0.22, 0.22, 0.28), BORDER_DIM))
	_theme.set_stylebox("hover", "OptionButton", _button_style(Color(0.27, 0.27, 0.34), BORDER_CARD))
	_theme.set_stylebox("pressed", "OptionButton", _button_style(Color(0.15, 0.15, 0.2), BORDER_DIM))
	_theme.set_color("font_color", "OptionButton", TEXT_PRIMARY)

	# TabContainer
	_theme.set_stylebox("tab_unselected", "TabContainer", _flat(Color(0.16, 0.16, 0.2), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("tab_selected", "TabContainer", _flat(Color(0.24, 0.24, 0.3), ACCENT, RADIUS_SM))
	_theme.set_color("font_selected_color", "TabContainer", TEXT_PRIMARY)
	_theme.set_color("font_unselected_color", "TabContainer", TEXT_SECONDARY)


func _flat(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border.a > 0.0:
		sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	return sb


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := _flat(bg, border, RADIUS_SM)
	sb.set_content_margin_all(SPACE_S)
	return sb


func get_theme() -> Theme:
	return _theme


func panel_background() -> StyleBox:
	return _theme.get_stylebox("panel_background", "Panel")


func card_background() -> StyleBox:
	return _theme.get_stylebox("card_background", "Panel")


func style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", panel_background())


func style_card(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", card_background())


func make_title(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	return label


func make_heading(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_HEADING)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	return label


func make_body(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func make_separator() -> HSeparator:
	return HSeparator.new()


func make_button_row(cancel_text: String = "Cancel", confirm_text: String = "Apply") -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACE_S)
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_END

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var cancel = Button.new()
	cancel.text = cancel_text
	hbox.add_child(cancel)

	var confirm = Button.new()
	confirm.text = confirm_text
	hbox.add_child(confirm)

	return hbox
