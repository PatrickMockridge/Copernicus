# omni_selector.gd
# UI for selecting Omniverse integration options

class_name OmniSelector
extends Control

signal option_selected(option: String)
signal cancelled()

const USDImporter = preload("res://addons/omni/core/usd_importer.gd")
const USDExporter = preload("res://addons/omni/core/usd_exporter.gd")
const OmniKitConnector = preload("res://addons/omni/connectors/omni_kit_connector.gd")

# UI elements
var _panel: PanelContainer
var _title: Label
var _option_list: VBoxContainer
var _options: Array = []

var _selected_option: String = "import_usd"
var _cancel_btn: Button
var _apply_btn: Button


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.25, 0.3, 1)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)

	var content = VBoxContainer.new()
	_panel.add_child(content)

	# Title
	_title = Label.new()
	_title.text = "Omniverse Integration"
	_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_title)

	var sep = HSeparator.new()
	content.add_child(sep)

	# Options list
	_option_list = VBoxContainer.new()
	_option_list.custom_minimum_size.y = 200
	content.add_child(_option_list)

	# Add options
	_add_option("import_usd", "Import USD",
		"Load USD/USDZ files into Godot scene tree. Requires pxr Python module.",
		true)

	_add_option("export_usd", "Export to USD",
		"Export Godot scene to USD format for Omniverse/Isaac Sim.",
		true)

	_add_option("omni_kit", "Omniverse Kit Sync",
		"Live sync with Omniverse Kit via WebSocket. Requires NVIDIA GPU + Omniverse.",
		OmniKitConnector.is_available())

	_add_option("validate_usd", "Validate USD File",
		"Check USD file validity and contents without importing.",
		true)

	# Separator
	var sep2 = HSeparator.new()
	content.add_child(sep2)

	# Info label
	var info = Label.new()
	info.text = "USD Importer/Exporter work without GPU. Omniverse Kit sync requires NVIDIA GPU."
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = Box.ALIGNMENT_END
	content.add_child(btn_hbox)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_hbox.add_child(_cancel_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10
	btn_hbox.add_child(spacer)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply"
	_apply_btn.pressed.connect(_on_apply_pressed)
	btn_hbox.add_child(_apply_btn)


func _add_option(option_id: String, title: String, description: String, available: bool) -> void:
	var option_container = PanelContainer.new()

	var option_style = StyleBoxFlat.new()
	option_style.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	option_style.set_corner_radius_all(4)
	option_style.set_border_width_all(1)
	option_style.border_color = Color(0.3, 0.3, 0.35, 1)
	option_container.add_theme_stylebox_override("panel", option_style)

	var hbox = HBoxContainer.new()
	option_container.add_child(hbox)

	# Radio button
	var radio = CheckBox.new()
	radio.button_group = "omni_option"
	radio.text = ""
	radio.toggled.connect(_on_option_toggled.bind(option_id))
	if not available:
		radio.disabled = true
	hbox.add_child(radio)

	# Text
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title + (" (Unavailable)" if not available else "")
	if not available:
		title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(desc_label)

	_option_list.add_child(option_container)
	_options.append({
		"id": option_id,
		"radio": radio,
		"available": available
	})

	# Select first available by default
	if available and _selected_option == "import_usd":
		radio.set_pressed_no_signal(true)
		_selected_option = option_id


func _on_option_toggled(toggled: bool, option_id: String) -> void:
	if toggled:
		_selected_option = option_id


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_apply_pressed() -> void:
	option_selected.emit(_selected_option)
	queue_free()


## ===== Static Helpers =====

static func get_option_description(option_id: String) -> String:
	match option_id:
		"import_usd":
			return "Import USD files into Godot using pxr.Usd"
		"export_usd":
			return "Export Godot scenes to USD format"
		"omni_kit":
			return "Live sync with Omniverse Kit"
		"validate_usd":
			return "Validate USD file structure"
		_:
			return ""


static func create_importer() -> USDImporter:
	return USDImporter.new()


static func create_exporter() -> USDExporter:
	return USDExporter.new()


static func create_kit_connector() -> OmniKitConnector:
	return OmniKitConnector.new()