# marketplace_selector.gd
# UI for selecting which marketplace backend to use

class_name MarketplaceSelector
extends Control

const ConfirmDialogClass = preload("res://scripts/ui/confirm_dialog.gd")

signal backend_selected(backend_class: String)
signal cancelled()

const MarketplaceCore = preload("res://scripts/marketplace/marketplace_core.gd")
const MockMarketplace = preload("res://scripts/marketplace/backends/mock_marketplace.gd")
const AOMarketplace = preload("res://scripts/marketplace/backends/ao_marketplace.gd")

# UI elements
var _panel: PanelContainer
var _title: Label
var _marketplace_list: VBoxContainer
var _backend_options: Array = []

var _selected_backend: String = "MockMarketplace"
var _default_backend: String = "MockMarketplace"
var _cancel_btn: Button
var _apply_btn: Button


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Main panel
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
	_title.text = "Select Marketplace"
	_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_title)

	var sep = HSeparator.new()
	content.add_child(sep)

	# Marketplace list
	_marketplace_list = VBoxContainer.new()
	_marketplace_list.custom_minimum_size.y = 220
	content.add_child(_marketplace_list)

	# Add marketplace options
	_add_marketplace_option("MockMarketplace", "Mock Marketplace",
		"Testing marketplace with sample data. No real transactions.",
		MockMarketplace.is_available())

	_add_marketplace_option("AOMarketplace", "AO Marketplace",
		"Real decentralized marketplace via AO Hyperobjects and Arweave.",
		AOMarketplace.is_available())

	# Separator
	var sep2 = HSeparator.new()
	content.add_child(sep2)

	# Info label
	var info = Label.new()
	info.text = "Mock marketplace is great for testing. AO Marketplace requires a wallet with AR tokens."
	info.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(btn_hbox)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_hbox.add_child(_cancel_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10
	btn_hbox.add_child(spacer)

	_apply_btn = Button.new()
	_apply_btn.text = "Open Marketplace"
	_apply_btn.pressed.connect(_on_apply_pressed)
	_apply_btn.disabled = false
	btn_hbox.add_child(_apply_btn)


func _add_marketplace_option(backend_id: String, title: String, description: String, available: bool) -> void:
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
	radio.button_group = "marketplace_backend"
	radio.text = ""
	radio.toggled.connect(_on_backend_toggled.bind(backend_id))
	if not available:
		radio.disabled = true
	hbox.add_child(radio)

	# Text
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title + (" (Unavailable)" if not available else "")
	if not available:
		title_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_DISABLED)
	else:
		title_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	vbox.add_child(desc_label)

	_marketplace_list.add_child(option_container)
	_backend_options.append({
		"id": backend_id,
		"radio": radio,
		"available": available
	})

	# Select first available by default
	if available and _selected_backend == "MockMarketplace":
		radio.set_pressed_no_signal(true)
		_selected_backend = backend_id


func _on_backend_toggled(toggled: bool, backend_id: String) -> void:
	if toggled:
		_selected_backend = backend_id


func _on_cancel_pressed() -> void:
	if _selected_backend != _default_backend:
		var dialog = ConfirmDialogClass.ask(self, "Discard Changes?", "You changed your selection. Discard it?", "Discard", "Keep Editing")
		dialog.confirmed.connect(func():
			cancelled.emit()
			queue_free()
		)
	else:
		cancelled.emit()
		queue_free()


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_backend)
	queue_free()


## ===== Static Helpers =====

static func get_backend_class(backend_id: String) -> MarketplaceCore:
	match backend_id:
		"MockMarketplace": return MockMarketplace.new()
		"AOMarketplace": return AOMarketplace.new()
		_:
			return MockMarketplace.new()


static func get_available_backends() -> Array:
	var available = []
	if MockMarketplace.is_available():
		available.append("MockMarketplace")
	if AOMarketplace.is_available():
		available.append("AOMarketplace")
	return available


static func create_backend(backend_id: String, config: Dictionary = {}) -> MarketplaceCore:
	var backend = get_backend_class(backend_id)
	backend.set_config(config)
	return backend
