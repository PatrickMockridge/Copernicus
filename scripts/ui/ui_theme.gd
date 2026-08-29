# ui_theme.gd
# The token table. Single source of truth for colors, fonts, spacing, radii, and
# styleboxes. Components read tokens here — no literal colors/font-sizes outside
# this file and the components. No `make_*` node factories.

extends Node

const COLOR := {
	"bg": Color(0.0392, 0.0392, 0.0471),        # #0a0a0c
	"panel": Color(0.0549, 0.0549, 0.0706),      # #0e0e12
	"raised": Color(0.0902, 0.0902, 0.1137),     # #17171d
	"border": Color(0.1647, 0.1647, 0.1804),     # #2a2a2e
	"text": Color(0.7843, 0.7843, 0.7843),       # #c8c8c8
	"text_muted": Color(0.6627, 0.6627, 0.6980), # #a9a9b2
	"text_faint": Color(0.4196, 0.4196, 0.4706), # #6b6b78
	"accent": Color(0.4667, 0.8, 0.9333),        # #7ce
	"success": Color(0.3843, 0.9098, 0.5176),    # #62e884
	"warning": Color(0.9412, 0.7765, 0.4549),    # #f0c674
	"error": Color(1.0, 0.4824, 0.4471),         # #ff7b72
	"backdrop": Color(0.0, 0.0, 0.0, 0.62),
	"viewport_overlay": Color(0.08, 0.08, 0.1, 0.7),
	"toast_info": Color(0.15, 0.15, 0.2, 0.95),
	"toast_success": Color(0.1, 0.25, 0.1, 0.95),
	"toast_warning": Color(0.3, 0.2, 0.05, 0.95),
	"toast_error": Color(0.3, 0.08, 0.08, 0.95),
	"asset_robot": Color(0.15, 0.35, 0.6, 1),
	"asset_part": Color(0.2, 0.5, 0.2, 1),
	"asset_world": Color(0.5, 0.3, 0.15, 1),
	"price": Color(0.9, 0.7, 0.3),
	"c64_bg": Color(0.0, 0.0, 0.6667),            # #0000aa
	"c64_text": Color(0.4235, 0.4235, 1.0),       # #6c6cff
}

const FONT_SIZE := {
	"title": 20,
	"heading": 15,
	"body": 14,
	"small": 12,
	"icon": 18,
}

const SPACE := {
	"xxs": 2,
	"xs": 4,
	"s": 8,
	"m": 12,
	"l": 20,
	"xl": 28,
}

const RADIUS := {
	"sm": 0,
	"md": 0,
}

var _fonts: Dictionary = {}
var _theme: Theme
var _style_cache: Dictionary = {}


func _ready() -> void:
	_fonts["ui"] = load("res://assets/fonts/Inter.ttf")
	_fonts["display"] = load("res://assets/fonts/SpaceGrotesk.ttf")
	_fonts["mono"] = load("res://assets/fonts/JetBrainsMono.ttf")
	_theme = load("res://resources/themes/copernicus_theme.tres")
	if _theme == null:
		_theme = Theme.new()
	if _fonts["ui"]:
		_theme.default_font = _fonts["ui"]
	_build_control_styles()


func _build_control_styles() -> void:
	# Dark control styles so raw Godot controls (HSlider, LineEdit, OptionButton,
	# TabBar, SpinBox, ProgressBar) don't render with the stock light theme.
	_theme.set_stylebox("normal", "Button", style("button_secondary"))
	_theme.set_stylebox("hover", "Button", style("button_secondary"))
	_theme.set_stylebox("pressed", "Button", style("button_secondary"))
	_theme.set_stylebox("focus", "Button", style("button_secondary"))
	_theme.set_color("font_color", "Button", color("text"))
	_theme.set_color("font_disabled_color", "Button", color("text_faint"))
	_theme.set_color("font_color", "Label", color("text"))
	_theme.set_stylebox("normal", "LineEdit", style("input"))
	_theme.set_stylebox("focus", "LineEdit", style("input"))
	_theme.set_color("font_color", "LineEdit", color("text"))
	_theme.set_stylebox("normal", "TextEdit", style("input"))
	_theme.set_stylebox("focus", "TextEdit", style("input"))
	_theme.set_color("font_color", "TextEdit", color("text"))
	_theme.set_stylebox("on", "CheckBox", style("button_primary"))
	_theme.set_stylebox("off", "CheckBox", style("button_secondary"))
	_theme.set_color("font_color", "CheckBox", color("text"))
	_theme.set_stylebox("separator", "HSeparator", _flat(color("border"), Color(0, 0, 0, 0)))
	_theme.set_stylebox("slider", "HSlider", _flat(color("border"), Color(0, 0, 0, 0)))
	_theme.set_stylebox("grabber_area", "HSlider", _flat(color("border"), Color(0, 0, 0, 0)))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(color("accent"), Color(0, 0, 0, 0)))
	_theme.set_stylebox("normal", "OptionButton", style("button_secondary"))
	_theme.set_stylebox("hover", "OptionButton", style("button_secondary"))
	_theme.set_color("font_color", "OptionButton", color("text"))
	_theme.set_stylebox("tab_unselected", "TabBar", style("tab_unselected"))
	_theme.set_stylebox("tab_selected", "TabBar", style("tab_selected"))
	_theme.set_stylebox("tab_hovered", "TabBar", style("tab_unselected"))
	_theme.set_color("font_selected_color", "TabBar", color("text"))
	_theme.set_color("font_unselected_color", "TabBar", color("text_muted"))
	_theme.set_stylebox("panel", "Panel", style("panel"))
	_theme.set_stylebox("panel", "ScrollContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	_theme.set_stylebox("panel", "TabContainer", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	_theme.set_stylebox("updown", "SpinBox", style("button_secondary"))
	_theme.set_color("font_color", "SpinBox", color("text"))
	_theme.set_stylebox("background", "ProgressBar", style("input"))
	_theme.set_stylebox("fill", "ProgressBar", style("button_primary"))


func color(name: String) -> Color:
	if not COLOR.has(name):
		push_error("UiTheme: unknown color token '%s'" % name)
		return Color.MAGENTA
	return COLOR[name]


func space(name: String) -> int:
	return SPACE.get(name, 0)


func font_size(name: String) -> int:
	return FONT_SIZE.get(name, 14)


func font(name: String) -> Font:
	return _fonts.get(name)


func radius(name: String) -> int:
	return RADIUS.get(name, 0)


## Memoized styleboxes.
func style(name: String) -> StyleBoxFlat:
	if _style_cache.has(name):
		return _style_cache[name]
	var sb := _make_style(name)
	_style_cache[name] = sb
	return sb


func _make_style(name: String) -> StyleBoxFlat:
	match name:
		"panel":
			return _box("panel", "border", 1, 0)
		"card":
			return _box("raised", "border", 1, 0)
		"title_bar":
			return _bar("panel", "border", "border_bottom")
		"status_bar":
			return _bar("panel", "border", "border_top")
		"button_primary":
			return _button("accent", "accent")
		"button_secondary":
			return _button("panel", "border")
		"button_ghost":
			return _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		"input":
			return _box("bg", "border", 1, 0)
		"tab_selected":
			return _tab_selected()
		"tab_unselected":
			return _flat(color("bg"), Color(0, 0, 0, 0))
	return _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0))


func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border.a > 0.0:
		sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(radius("sm"))
	return sb


func _box(bg_name: String, border_name: String, width: int, radius_name: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(bg_name)
	sb.set_border_width_all(width)
	sb.border_color = color(border_name)
	sb.set_corner_radius_all(radius_name)
	return sb


func _bar(bg_name: String, border_name: String, side: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(bg_name)
	sb.border_color = color(border_name)
	match side:
		"border_top": sb.border_width_top = 1
		"border_bottom": sb.border_width_bottom = 1
		"border_left": sb.border_width_left = 1
		"border_right": sb.border_width_right = 1
	sb.content_margin_left = space("m")
	sb.content_margin_right = space("m")
	sb.content_margin_top = space("xxs")
	sb.content_margin_bottom = space("xxs")
	return sb


func _button(bg_name: String, border_name: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(bg_name)
	sb.set_border_width_all(1)
	sb.border_color = color(border_name)
	sb.set_corner_radius_all(radius("sm"))
	sb.content_margin_left = space("s")
	sb.content_margin_right = space("s")
	sb.content_margin_top = space("xs")
	sb.content_margin_bottom = space("xs")
	return sb


func _tab_selected() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color("panel")
	sb.border_width_top = 2
	sb.border_color = color("accent")
	return sb
