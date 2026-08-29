# modal_layer.gd
# Base for modal overlays: a full-rect dimmed backdrop + centered content host.
# Subclass and add your surface to content().

class_name ModalLayer
extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.62)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_name("Content")
	add_child(center)


func content() -> CenterContainer:
	return get_node("Content") as CenterContainer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_escape()
		get_viewport().set_input_as_handled()


## Override to customize Esc behavior.
func _on_escape() -> void:
	queue_free()
