# ui_panel.gd
# The window frame: title bar + body slot + title-actions slot.

class_name UiPanel
extends PanelContainer

var _title_bar: UiTitleBar
var _actions: HBoxContainer
var _body: VBoxContainer


func setup(title: String, padding: bool = true) -> UiPanel:
	add_theme_stylebox_override("panel", UiTheme.style("panel"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	if not title.is_empty():
		_title_bar = UiTitleBar.new().setup(title)
		_actions = _title_bar.actions()
		v.add_child(_title_bar)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", UiTheme.space("s"))
	if padding:
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", UiTheme.space("m"))
		margin.add_theme_constant_override("margin_right", UiTheme.space("m"))
		margin.add_theme_constant_override("margin_top", UiTheme.space("m"))
		margin.add_theme_constant_override("margin_bottom", UiTheme.space("m"))
		margin.add_child(_body)
		v.add_child(margin)
	else:
		v.add_child(_body)
	return self


func body() -> VBoxContainer:
	return _body


func title_actions() -> HBoxContainer:
	return _actions


func set_title(t: String) -> void:
	if _title_bar:
		_title_bar.set_title(t)
