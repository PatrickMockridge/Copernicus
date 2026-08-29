# ui_title_bar.gd
# A window title bar: title (left, expand) + right-aligned action slot.

class_name UiTitleBar
extends PanelContainer

var _label: UiLabel
var _actions: HBoxContainer


func setup(title: String) -> UiTitleBar:
	add_theme_stylebox_override("panel", UiTheme.style("title_bar"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.space("s"))
	add_child(h)
	_label = UiLabel.new().setup(title.to_upper(), UiLabel.Kind.SMALL, UiLabel.Tone.ACCENT)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_label)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", UiTheme.space("xs"))
	h.add_child(_actions)
	return self


func actions() -> HBoxContainer:
	return _actions


func label() -> Label:
	return _label


func set_title(t: String) -> void:
	_label.text = t.to_upper()
