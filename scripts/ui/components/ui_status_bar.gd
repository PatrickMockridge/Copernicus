# ui_status_bar.gd
# The bottom status bar: left items (expand) + right items.

class_name UiStatusBar
extends PanelContainer

var _left: HBoxContainer
var _right: HBoxContainer


func setup() -> UiStatusBar:
	custom_minimum_size.y = 28
	add_theme_stylebox_override("panel", UiTheme.style("status_bar"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.space("m"))
	add_child(h)
	_left = HBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", UiTheme.space("m"))
	h.add_child(_left)
	_right = HBoxContainer.new()
	_right.add_theme_constant_override("separation", UiTheme.space("m"))
	h.add_child(_right)
	return self


func left() -> HBoxContainer:
	return _left


func right() -> HBoxContainer:
	return _right
