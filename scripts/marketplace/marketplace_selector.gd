# marketplace_selector.gd
# UI for selecting which marketplace backend to use

class_name MarketplaceSelector
extends BaseSelector

signal backend_selected(backend_class: String)

# Preload backends so their _static_init registers them with ModuleRegistry.
const MockMarketplace = preload("res://scripts/marketplace/backends/mock_marketplace.gd")
const RChainMarketplace = preload("res://scripts/marketplace/backends/rchain_marketplace.gd")


func _get_title() -> String:
	return "Select Marketplace"


func _get_info_text() -> String:
	return "RChain and Mock price in REV. The legacy AO backend uses AR."


func _get_button_group_name() -> String:
	return "marketplace_backend"


func _get_apply_text() -> String:
	return "Open Marketplace"


func _get_category() -> String:
	return "marketplace"


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary = {}) -> MarketplaceCore:
	return ModuleRegistry.create("marketplace", backend_id, config)
