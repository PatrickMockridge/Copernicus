# ui_status_item.gd
# A status-bar readout: a colored dot + "name: value".

class_name UiStatusItem
extends HBoxContainer

enum State { OFF, OK }

var _name: String = ""
var _dot: UiLabel
var _text: UiLabel


func setup(name: String, value: String = "—", state: State = State.OFF) -> UiStatusItem:
	_name = name
	add_theme_constant_override("separation", UiTheme.space("xs"))
	_dot = UiLabel.new().setup("●", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
	add_child(_dot)
	_text = UiLabel.new().setup("", UiLabel.Kind.SMALL, UiLabel.Tone.PRIMARY)
	add_child(_text)
	_update(state, value)
	return self


func set_state(state: State, value: String) -> void:
	_update(state, value)


func _update(state: State, value: String) -> void:
	_dot.setup("●", UiLabel.Kind.SMALL, UiLabel.Tone.SUCCESS if state == State.OK else UiLabel.Tone.MUTED)
	_text.text = "%s: %s" % [_name, value]
