# base_selector.gd
# Reusable selector UI for module backends.
# Domain selectors extend this and override the virtual getter methods.

class_name BaseSelector
extends ModalLayer

signal option_selected(id: String)
signal cancelled()

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
	super._ready()
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
	panel.custom_minimum_size = Vector2(560, 460)
	panel.add_theme_stylebox_override("panel", UiTheme.style("panel"))
	content().add_child(panel)

	var content = VBoxContainer.new()
	panel.add_child(content)

	var title_label = UiLabel.new().setup(_get_title(), UiLabel.Kind.HEADING, UiLabel.Tone.PRIMARY)
	content.add_child(title_label)

	content.add_child(UiSeparator.new())

	var option_scroll = ScrollContainer.new()
	option_scroll.custom_minimum_size.y = 220
	option_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	content.add_child(option_scroll)

	_option_list = VBoxContainer.new()
	_option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_scroll.add_child(_option_list)

	_populate_options(_option_list)

	if _option_widgets.is_empty():
		option_scroll.add_child(UiLabel.new().setup("No modules available — No backends are registered for this category.", UiLabel.Kind.BODY, UiLabel.Tone.MUTED))

	content.add_child(UiSeparator.new())

	var info_text = _get_info_text()
	if not info_text.is_empty():
		var info_label = UiLabel.new().setup(info_text, UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
		content.add_child(info_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", UiTheme.space("s"))
	btn_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_row.add_child(UiSpacer.new().setup(true, false))
	_cancel_btn = UiButton.new().setup("Cancel", UiButton.Variant.SECONDARY)
	btn_row.add_child(_cancel_btn)
	_apply_btn = UiButton.new().setup(_get_apply_text(), UiButton.Variant.PRIMARY)
	btn_row.add_child(_apply_btn)
	content.add_child(btn_row)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_apply_btn.pressed.connect(_on_apply_pressed)

	if _option_widgets.is_empty():
		_apply_btn.disabled = true


func _add_option(id: String, name: String, description: String, available: bool, container: VBoxContainer) -> void:
	var widget = _create_option_widget(id, name, description, available)
	container.add_child(widget)


func _create_option_widget(id: String, name: String, description: String, available: bool) -> Control:
	var option_container = PanelContainer.new()
	option_container.add_theme_stylebox_override("panel", UiTheme.style("card"))

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
		UiTheme.color("text_faint") if not available else UiTheme.color("text"))
	vbox.add_child(title_label)

	var desc_label = UiLabel.new().setup(description, UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	vbox.add_child(desc_label)

	_option_widgets.append({"id": id, "radio": radio, "available": available})
	return option_container


func _on_option_toggled(id: String) -> void:
	_selected_id = id
	_on_option_selected(id)


func _on_cancel_pressed() -> void:
	if _selected_id != _default_id and not _default_id.is_empty():
		var dialog = ConfirmDialog.ask(self, "Discard Changes?", "You changed your selection. Discard it?", "Discard", "Keep Editing")
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


func _on_escape() -> void:
	_on_cancel_pressed()
