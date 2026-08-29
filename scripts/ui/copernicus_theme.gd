# copernicus_theme.gd
# Shared theme autoload — single source of truth for StyleBoxes, colors, spacing and fonts.
#
# Stark-terminal palette (hex → Color), Zachtronics / IDE-influenced:
#   BG      #0a0a0c   Card    #0e0e12   Border  #2a2a2e
#   Text    #c8c8c8   Text2   #7a7a82   Text3   #4a4a52
#   Accent  #7ce      Success #62e884   Warning #f0c674   Error #ff7b72

extends Node

const BG_DARK := Color(0.0392, 0.0392, 0.0471)        # #0a0a0c
const BG_CARD := Color(0.0549, 0.0549, 0.0706)        # #0e0e12
const BORDER_DIM := Color(0.1647, 0.1647, 0.1804)      # #2a2a2e
const BORDER_CARD := Color(0.1647, 0.1647, 0.1804)     # #2a2a2e

const TEXT_PRIMARY := Color(0.7843, 0.7843, 0.7843)    # #c8c8c8
const TEXT_SECONDARY := Color(0.4784, 0.4784, 0.5098)  # #7a7a82
const TEXT_DISABLED := Color(0.2902, 0.2902, 0.3216)   # #4a4a52

const ACCENT := Color(0.4667, 0.8, 0.9333)             # #7ce
const SUCCESS := Color(0.3843, 0.9098, 0.5176)         # #62e884
const WARNING := Color(0.9412, 0.7765, 0.4549)         # #f0c674
const ERROR := Color(1.0, 0.4824, 0.4471)              # #ff7b72

const FONT_SIZE_TITLE := 20
const FONT_SIZE_HEADING := 15
const FONT_SIZE_BODY := 13
const FONT_SIZE_SMALL := 11

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 20
const SPACE_XL := 28

const RADIUS_SM := 0
const RADIUS_MD := 0

var _theme: Theme
var _display_font: Font = null
var _mono_font: Font = null


func _ready() -> void:
	_theme = load("res://resources/themes/copernicus_theme.tres")
	_load_fonts()
	_build_control_styles()


func _load_fonts() -> void:
	# Monospace-first: JetBrains Mono is the default body font.
	_mono_font = load("res://assets/fonts/JetBrainsMono.ttf") as Font
	if _mono_font:
		_theme.default_font = _mono_font
	_display_font = load("res://assets/fonts/SpaceGrotesk.ttf") as Font


func display_font() -> Font:
	return _display_font


func mono_font() -> Font:
	return _mono_font


## Extend the .tres with the terminal control styles, so controls stop
## rendering with Godot's stock light theme on the dark panels.
func _build_control_styles() -> void:
	# Button
	_theme.set_stylebox("normal", "Button", _button_style(BG_CARD, BORDER_DIM))
	_theme.set_stylebox("hover", "Button", _button_style(Color(0.10, 0.10, 0.14), BORDER_CARD))
	_theme.set_stylebox("pressed", "Button", _button_style(BG_DARK, BORDER_DIM))
	_theme.set_stylebox("disabled", "Button", _button_style(Color(0.05, 0.05, 0.07, 0.6), BORDER_DIM))
	_theme.set_stylebox("focus", "Button", _button_style(BG_CARD, ACCENT))
	_theme.set_color("font_color", "Button", TEXT_PRIMARY)
	_theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	# Label
	_theme.set_color("font_color", "Label", TEXT_PRIMARY)

	# LineEdit / TextEdit
	_theme.set_stylebox("normal", "LineEdit", _flat(Color(0.05, 0.05, 0.06), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("focus", "LineEdit", _flat(Color(0.05, 0.05, 0.06), ACCENT, RADIUS_SM))
	_theme.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	_theme.set_stylebox("normal", "TextEdit", _flat(Color(0.05, 0.05, 0.06), BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("focus", "TextEdit", _flat(Color(0.05, 0.05, 0.06), ACCENT, RADIUS_SM))
	_theme.set_color("font_color", "TextEdit", TEXT_PRIMARY)

	# CheckBox (radio)
	_theme.set_stylebox("on", "CheckBox", _flat(ACCENT, ACCENT, RADIUS_SM))
	_theme.set_stylebox("off", "CheckBox", _flat(BG_CARD, BORDER_DIM, RADIUS_SM))
	_theme.set_color("font_color", "CheckBox", TEXT_PRIMARY)

	# HSeparator
	_theme.set_stylebox("separator", "HSeparator", _flat(BORDER_DIM, Color(0, 0, 0, 0), 0))

	# HSlider
	_theme.set_stylebox("slider", "HSlider", _flat(BORDER_DIM, Color(0, 0, 0, 0), 0))
	_theme.set_stylebox("grabber_area", "HSlider", _flat(BORDER_DIM, Color(0, 0, 0, 0), 0))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT, Color(0, 0, 0, 0), 0))

	# OptionButton
	_theme.set_stylebox("normal", "OptionButton", _button_style(BG_CARD, BORDER_DIM))
	_theme.set_stylebox("hover", "OptionButton", _button_style(Color(0.10, 0.10, 0.14), BORDER_CARD))
	_theme.set_stylebox("pressed", "OptionButton", _button_style(BG_DARK, BORDER_DIM))
	_theme.set_color("font_color", "OptionButton", TEXT_PRIMARY)

	# TabContainer
	_theme.set_stylebox("tab_unselected", "TabContainer", _flat(BG_DARK, BORDER_DIM, RADIUS_SM))
	_theme.set_stylebox("tab_selected", "TabContainer", _flat(BG_CARD, ACCENT, RADIUS_SM))
	_theme.set_color("font_selected_color", "TabContainer", TEXT_PRIMARY)
	_theme.set_color("font_unselected_color", "TabContainer", TEXT_SECONDARY)

	# Panel default — so un-styled PanelContainers match the dark theme.
	_theme.set_stylebox("panel", "Panel", _theme.get_stylebox("panel_background", "Panel"))

	# ScrollContainer / TabContainer content areas — transparent so the parent bg shows through.
	_theme.set_stylebox("panel", "ScrollContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	_theme.set_stylebox("panel", "TabContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))

	# SpinBox
	_theme.set_stylebox("updown", "SpinBox", _flat(BG_CARD, BORDER_DIM, RADIUS_SM))
	_theme.set_color("font_color", "SpinBox", TEXT_PRIMARY)

	# ProgressBar
	_theme.set_stylebox("background", "ProgressBar", _flat(Color(0.05, 0.05, 0.06), BORDER_DIM, RADIUS_SM))
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
	if _mono_font:
		label.add_theme_font_override("font", _mono_font)
	return label


func make_body(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func make_console_line(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	if _mono_font:
		label.add_theme_font_override("font", _mono_font)
	return label


## A small uppercase section label (IDE-style section header).
func make_section(text: String) -> Label:
	var label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", TEXT_DISABLED)
	return label


## A bordered title bar for a window/panel (bottom border only).
func make_title_bar(text: String) -> PanelContainer:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_CARD
	sb.border_width_bottom = 1
	sb.border_color = BORDER_DIM
	sb.content_margin_left = SPACE_S
	sb.content_margin_right = SPACE_S
	sb.content_margin_top = SPACE_XS
	sb.content_margin_bottom = SPACE_XS
	bar.add_theme_stylebox_override("panel", sb)
	var label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", ACCENT)
	if _mono_font:
		label.add_theme_font_override("font", _mono_font)
	bar.add_child(label)
	return bar


## A bordered window frame with a title bar. Returns {window, body} where `body`
## is the VBoxContainer to add content into.
func make_window(title: String) -> Dictionary:
	var win := PanelContainer.new()
	var sb := _flat(BG_CARD, BORDER_DIM, RADIUS_SM)
	sb.set_content_margin_all(0)
	win.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	win.add_child(v)

	if not title.is_empty():
		v.add_child(make_title_bar(title))

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", SPACE_S)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SPACE_M)
	margin.add_theme_constant_override("margin_right", SPACE_M)
	margin.add_theme_constant_override("margin_top", SPACE_M)
	margin.add_theme_constant_override("margin_bottom", SPACE_M)
	margin.add_child(body)
	v.add_child(margin)

	return {"window": win, "body": body}


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
