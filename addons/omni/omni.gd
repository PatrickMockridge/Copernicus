# omni.gd
# Omniverse integration plugin for Copernicus
# Provides USD pipeline and Omniverse digital twin connectivity

@tool
extends EditorPlugin

const USDImporter = preload("res://addons/omni/core/usd_importer.gd")
const USDExporter = preload("res://addons/omni/core/usd_exporter.gd")
const USDTypes = preload("res://addons/omni/core/usd_types.gd")
const OmniConnector = preload("res://addons/omni/connectors/omni_connector.gd")
const OmniKitConnector = preload("res://addons/omni/connectors/omni_kit_connector.gd")


func _enter_tree() -> void:
	print("Omniverse Integration plugin loaded")
	print("  USD Pipeline: available")
	if OmniKitConnector.is_available():
		print("  Omniverse Kit: available")
	else:
		print("  Omniverse Kit: requires NVIDIA GPU + Omniverse installation")


func _exit_tree() -> void:
	print("Omniverse Integration plugin unloaded")


## ===== USD Pipeline =====

## Import a USD file into Godot scene
static func import_usd(file_path: String) -> Node3D:
	var importer = USDImporter.new()
	return importer.import_file(file_path)


## Export a Godot scene to USD
static func export_usd(scene: Node3D, output_path: String) -> bool:
	var exporter = USDExporter.new()
	return exporter.export_scene(scene, output_path)


## Check if USD file is valid
static func validate_usd(file_path: String) -> Dictionary:
	var importer = USDImporter.new()
	return importer.validate_file(file_path)


## ===== Omniverse Connector =====

## Create an Omniverse connector
static func create_connector(connector_type: String) -> OmniConnector:
	match connector_type:
		"OmniKit":
			return OmniKitConnector.new()
		_:
			push_warning("Omniverse plugin: unknown connector type ", connector_type)
			return OmniConnector.new()


## Check if Omniverse Kit is available
static func is_kit_available() -> bool:
	return OmniKitConnector.is_available()


## ===== USD Types =====

## Get USD stage info
static func get_stage_info(file_path: String) -> Dictionary:
	return USDTypes.get_stage_info(file_path)


## List prims in USD stage
static func list_prims(file_path: String, prim_path: String = "/") -> Array:
	return USDTypes.list_prims(file_path, prim_path)


## Get prim properties
static func get_prim_props(file_path: String, prim_path: String) -> Dictionary:
	return USDTypes.get_prim_props(file_path, prim_path)


## ===== Import Dialog Integration =====

func _handles(object: Object) -> bool:
	if object is Resource:
		var path: String = object.resource_path
		return path.ends_with(".usd") or path.ends_with(".usda") or path.ends_with(".usdc")
	return false


func _import(source_file: String, save_path: String, options: Dictionary) -> Error:
	var scene = import_usd(source_file)
	if scene:
		return OK
	return FAILED