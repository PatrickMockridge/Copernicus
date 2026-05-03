# copernicus_theme.gd
# Shared theme autoload — provides consistent StyleBoxes and colors

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

var _theme: Theme


func _ready() -> void:
	_theme = load("res://resources/themes/copernicus_theme.tres")


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
	hbox.add_theme_constant_override("separation", 8)
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
