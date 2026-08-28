# base_selector.gd
# Reusable selector UI for module backends.
# Domain selectors extend this and override the virtual getter methods.

class_name BaseSelector
extends Control

signal option_selected(id: String)
signal cancelled()

const ConfirmDialogClass = preload("res://scripts/ui/confirm_dialog.gd")

var _selected_id: String = ""
var _default_id: String = ""
var _option_list: VBoxContainer
var _option_widgets: Array = []
var _cancel_btn: Button
var _apply_btn: Button
var _button_group: ButtonGroup


func _get_title() -> String:
	return "Select Module"


func _get_info_text() -> String:
	return ""


func _get_button_group_name() -> String:
	return "module_selection"


func _get_apply_text() -> String:
	return "Apply"


func _get_category() -> String:
	return ""


func _on_option_selected(_id: String) -> void:
	pass


func _populate_options(container: VBoxContainer) -> void:
	var category = _get_category()
	if category.is_empty():
		return
	var modules = ModuleRegistry.get_available(category)
	for mod in modules:
		_add_option(mod["id"], mod["name"], mod["description"], mod["available"], container)


func _ready() -> void:
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = false
	_setup_ui()
	for opt in _option_widgets:
		if opt["available"]:
			opt["radio"].set_pressed_no_signal(true)
			_selected_id = opt["id"]
			_default_id = opt["id"]
			break


func _setup_ui() -> void:
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var content = VBoxContainer.new()
	panel.add_child(content)

	var title_label = CopernicusTheme.make_heading(_get_title())
	content.add_child(title_label)

	content.add_child(CopernicusTheme.make_separator())

	_option_list = VBoxContainer.new()
	_option_list.custom_minimum_size.y = 220
	content.add_child(_option_list)

	_populate_options(_option_list)

	content.add_child(CopernicusTheme.make_separator())

	var info_text = _get_info_text()
	if not info_text.is_empty():
		var info_label = CopernicusTheme.make_body(info_text)
		content.add_child(info_label)

	var btn_row = CopernicusTheme.make_button_row("Cancel", _get_apply_text())
	content.add_child(btn_row)

	var children = btn_row.get_children()
	_cancel_btn = children[1]  # after spacer
	_apply_btn = children[2]
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_apply_btn.pressed.connect(_on_apply_pressed)


func _add_option(id: String, name: String, description: String, available: bool, container: VBoxContainer) -> void:
	var widget = _create_option_widget(id, name, description, available)
	container.add_child(widget)


func _create_option_widget(id: String, name: String, description: String, available: bool) -> Control:
	var option_container = PanelContainer.new()
	CopernicusTheme.style_card(option_container)

	var hbox = HBoxContainer.new()
	option_container.add_child(hbox)

	var radio = CheckBox.new()
	radio.button_group = _button_group
	radio.text = ""
	radio.toggled.connect(func(toggled): if toggled: _on_option_toggled(id))
	if not available:
		radio.disabled = true
	hbox.add_child(radio)

	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)

	var title_label = Label.new()
	title_label.text = name + (" (Unavailable)" if not available else "")
	title_label.add_theme_color_override("font_color",
		CopernicusTheme.TEXT_DISABLED if not available else CopernicusTheme.TEXT_PRIMARY)
	vbox.add_child(title_label)

	var desc_label = CopernicusTheme.make_body(description)
	vbox.add_child(desc_label)

	_option_widgets.append({"id": id, "radio": radio, "available": available})
	return option_container


func _on_option_toggled(id: String) -> void:
	_selected_id = id
	_on_option_selected(id)


func _on_cancel_pressed() -> void:
	if _selected_id != _default_id and not _default_id.is_empty():
		var dialog = ConfirmDialogClass.ask(self, "Discard Changes?", "You changed your selection. Discard it?", "Discard", "Keep Editing")
		dialog.confirmed.connect(func():
			cancelled.emit()
			queue_free()
		)
	else:
		cancelled.emit()
		queue_free()


func _on_apply_pressed() -> void:
	option_selected.emit(_selected_id)
	queue_free()
