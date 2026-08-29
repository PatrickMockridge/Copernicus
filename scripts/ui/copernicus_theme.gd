# copernicus_theme.gd
# Shared theme autoload — single source of truth for StyleBoxes, colors, spacing and fonts.
#
# Modern minimal dark palette (hex → Color):
#   BG      #0f0f13   Card    #17171d   Border  #26262e
#   Text    #f2f2f4   Text2   #9b9ba6   Text3   #565662
#   Accent  #7c8cff   Success #3dd68c   Warning #f5b83d   Error #f26d6d

extends Node

const BG_DARK := Color(0.0588, 0.0588, 0.0745)        # #0f0f13
const BG_CARD := Color(0.0902, 0.0902, 0.1137)        # #17171d
const BORDER_DIM := Color(0.149, 0.149, 0.1804)       # #26262e
const BORDER_CARD := Color(0.149, 0.149, 0.1804)      # #26262e

const TEXT_PRIMARY := Color(0.949, 0.949, 0.9569)     # #f2f2f4
const TEXT_SECONDARY := Color(0.6078, 0.6078, 0.651)  # #9b9ba6
const TEXT_DISABLED := Color(0.3373, 0.3373, 0.3843)  # #565662

const ACCENT := Color(0.4863, 0.549, 1.0)             # #7c8cff
const SUCCESS := Color(0.2392, 0.8392, 0.549)         # #3dd68c
const WARNING := Color(0.9608, 0.7216, 0.2392)        # #f5b83d
const ERROR := Color(0.949, 0.4275, 0.4275)           # #f26d6d

const FONT_SIZE_TITLE := 24
const FONT_SIZE_HEADING := 18
const FONT_SIZE_BODY := 14
const FONT_SIZE_SMALL := 12

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 20
const SPACE_XL := 28

const RADIUS_SM := 6
const RADIUS_MD := 10

var _theme: Theme
var _display_font: Font = null
var _mono_font: Font = null


func _ready() -> void:
	_theme = load("res://resources/themes/copernicus_theme.tres")
	_load_fonts()
	_build_control_styles()


func _load_fonts() -> void:
	var body := load("res://assets/fonts/Inter.ttf") as Font
	if body:
		_theme.default_font = body
	_display_font = load("res://assets/fonts/SpaceGrotesk.ttf") as Font
	_mono_font = load("res://assets/fonts/JetBrainsMono.ttf") as Font


func display_font() -> Font:
	return _display_font


func mono_font() -> Font:
	return _mono_font


## Extend the .tres (Panels only) with the dark control styles, so controls stop
## rendering with Godot's stock light theme on the dark panels.
func _build_control_styles() -> void:
	# Button
	_theme.set_stylebox("normal", "Button", _button_style(Color(0.13, 0.13, 0.16), BORDER_DIM))
	_theme.set_stylebox("hover", "Button", _button_style(Color(0.17, 0.17, 0.21), BORDER_CARD))
	_theme.set_stylebox("pressed", "Button", _button_style(Color(0.10, 0.10, 0.13), BORDER_DIM))
	_theme.set_stylebox("disabled", "Button", _button_style(Color(0.11, 0.11, 0.14, 0.5), BORDER_DIM))
	_theme.set_stylebox("focus", "Button", _button_style(Color(0.13, 0.13, 0.16), ACCENT))
	_theme.set_color("font_color", "Button", TEXT_PRIMARY)
	_theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	# Label
	_theme.set_color("font_color", "Label", TEXT_PRIMARY)

	# LineEdit / TextEdit
	_theme.set_stylebox("normal", "LineEdit", _flat(Color(0.08, 0.08, 0.10), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("focus", "LineEdit", _flat(Color(0.08, 0.08, 0.10), ACCENT, RADIUS_SM))
	_theme.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	_theme.set_stylebox("normal", "TextEdit", _flat(Color(0.08, 0.08, 0.10), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("focus", "TextEdit", _flat(Color(0.08, 0.08, 0.10), ACCENT, RADIUS_SM))
	_theme.set_color("font_color", "TextEdit", TEXT_PRIMARY)

	# CheckBox (radio)
	_theme.set_stylebox("on", "CheckBox", _flat(ACCENT, ACCENT, RADIUS_SM))
	_theme.set_stylebox("off", "CheckBox", _flat(Color(0.13, 0.13, 0.16), BORDER_DIM, RADIUS_SM))
	_theme.set_color("font_color", "CheckBox", TEXT_PRIMARY)

	# HSeparator
	_theme.set_stylebox("separator", "HSeparator", _flat(BORDER_DIM, Color(0, 0, 0, 0), 0))

	# HSlider
	_theme.set_stylebox("slider", "HSlider", _flat(BORDER_DIM, Color(0, 0, 0, 0), 2))
	_theme.set_stylebox("grabber_area", "HSlider", _flat(BORDER_DIM, Color(0, 0, 0, 0), 2))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT, Color(0, 0, 0, 0), 2))

	# OptionButton
	_theme.set_stylebox("normal", "OptionButton", _button_style(Color(0.13, 0.13, 0.16), BORDER_DIM))
	_theme.set_stylebox("hover", "OptionButton", _button_style(Color(0.17, 0.17, 0.21), BORDER_CARD))
	_theme.set_stylebox("pressed", "OptionButton", _button_style(Color(0.10, 0.10, 0.13), BORDER_DIM))
	_theme.set_color("font_color", "OptionButton", TEXT_PRIMARY)

	# TabContainer
	_theme.set_stylebox("tab_unselected", "TabContainer", _flat(Color(0.11, 0.11, 0.14), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("tab_selected", "TabContainer", _flat(Color(0.16, 0.16, 0.20), ACCENT, RADIUS_SM))
	_theme.set_color("font_selected_color", "TabContainer", TEXT_PRIMARY)
	_theme.set_color("font_unselected_color", "TabContainer", TEXT_SECONDARY)

	# Panel default — so un-styled PanelContainers match the dark theme.
	_theme.set_stylebox("panel", "Panel", _theme.get_stylebox("panel_background", "Panel"))

	# ScrollContainer / TabContainer content areas — transparent so the parent bg shows through.
	_theme.set_stylebox("panel", "ScrollContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	_theme.set_stylebox("panel", "TabContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))

	# SpinBox
	_theme.set_stylebox("updown", "SpinBox", _flat(Color(0.13, 0.13, 0.16), BORDER_DIM, RADIUS_SM))
	_theme.set_color("font_color", "SpinBox", TEXT_PRIMARY)

	# ProgressBar
	_theme.set_stylebox("background", "ProgressBar", _flat(Color(0.08, 0.08, 0.10), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("fill", "ProgressBar", _flat(ACCENT, ACCENT, RADIUS_SM))


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
	if _display_font:
		label.add_theme_font_override("font", _display_font)
	return label


func make_heading(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_HEADING)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	if _display_font:
		label.add_theme_font_override("font", _display_font)
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


func make_primary_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", _button_style(ACCENT, ACCENT))
	btn.add_theme_stylebox_override("hover", _button_style(ACCENT.lightened(0.08), ACCENT))
	btn.add_theme_stylebox_override("pressed", _button_style(ACCENT.darkened(0.08), ACCENT))
	btn.add_theme_stylebox_override("focus", _button_style(ACCENT, TEXT_PRIMARY))
	btn.add_theme_color_override("font_color", BG_DARK)
	btn.add_theme_color_override("font_hover_color", BG_DARK)
	btn.add_theme_color_override("font_pressed_color", BG_DARK)
	btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	return btn


func make_secondary_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", _button_style(BG_CARD, BORDER_DIM))
	btn.add_theme_stylebox_override("hover", _button_style(BG_CARD.lightened(0.05), BORDER_CARD))
	btn.add_theme_stylebox_override("pressed", _button_style(BG_CARD.darkened(0.05), BORDER_DIM))
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	return btn


func make_nav_item(text: String, id: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.set_meta("nav_id", id)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	return btn


func set_nav_active(btn: Button, active: bool) -> void:
	var c := ACCENT if active else TEXT_PRIMARY
	btn.add_theme_color_override("font_color", c)
	btn.add_theme_color_override("font_hover_color", c)
	btn.add_theme_color_override("font_pressed_color", c)


func make_empty_state(title: String, body: String = "") -> Control:
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACE_S)

	var t = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", FONT_SIZE_HEADING)
	t.add_theme_color_override("font_color", TEXT_SECONDARY)
	vbox.add_child(t)

	if not body.is_empty():
		var b = Label.new()
		b.text = body
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		b.add_theme_color_override("font_color", TEXT_DISABLED)
		vbox.add_child(b)

	return vbox


func make_button_row(cancel_text: String = "Cancel", confirm_text: String = "Apply") -> Dictionary:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACE_S)
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_END

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var cancel = make_secondary_button(cancel_text)
	hbox.add_child(cancel)

	var confirm = make_primary_button(confirm_text)
	hbox.add_child(confirm)

	return {"row": hbox, "cancel": cancel, "confirm": confirm}
