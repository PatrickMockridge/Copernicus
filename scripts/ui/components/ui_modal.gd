# ui_modal.gd
# The single modal: a dimmed backdrop + a centered content slot. Esc closes.

class_name UiModal
extends Control

signal closed()

var _center: CenterContainer


func setup() -> UiModal:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = UiTheme.color("backdrop")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	return self


func content() -> CenterContainer:
	return _center


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
