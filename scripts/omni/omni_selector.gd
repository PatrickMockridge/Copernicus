# omni_selector.gd
# UI for selecting Omniverse integration options

class_name OmniSelector
extends BaseSelector


func _get_title() -> String:
	return "Omniverse Integration"


func _get_info_text() -> String:
	return "USD Importer/Exporter work without GPU. Omniverse Kit sync requires NVIDIA GPU."


func _get_button_group_name() -> String:
	return "omni_option"


func _get_apply_text() -> String:
	return "Apply"


func _get_category() -> String:
	return "omni"


func _populate_options(container: VBoxContainer) -> void:
	_add_option("import_usd", "Import USD", "Load USD/USDZ files into Godot scene tree. Requires pxr Python module.", true, container)
	_add_option("export_usd", "Export to USD", "Export Godot scene to USD format for Omniverse/Isaac Sim.", true, container)
	_add_option("omni_kit", "Omniverse Kit Sync", "Live sync with Omniverse Kit via WebSocket. Requires NVIDIA GPU + Omniverse.", false, container)
	_add_option("validate_usd", "Validate USD File", "Check USD file validity and contents without importing.", true, container)
	super._populate_options(container)
