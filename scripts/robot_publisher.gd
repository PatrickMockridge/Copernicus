# robot_publisher.gd
# Publish flow: upload robot files to Arweave (plain storage), then register the
# robot on RChain (rholang) as the source of truth. No AO process is spawned.

class_name RobotPublisher
extends Node

signal publish_progress(stage: String, percent: float)
signal publish_complete(result: Dictionary)
signal publish_failed(error: String)

const Result = preload("res://addons/primitives/result.gd")
const Manifest = preload("res://addons/hyperobject/sdk/manifest.gd")
const Storage = preload("res://addons/hyperobject/sdk/storage.gd")
# Preload coordination backends so RChainCoordination registers with ModuleRegistry.
const MockCoordination = preload("res://scripts/coordination/mock_coordination.gd")
const RChainCoordination = preload("res://scripts/coordination/rchain_coordination.gd")

var _storage: Storage

# Publish configuration
var _config: Dictionary = {}


func _init() -> void:
	pass


func configure(config: Dictionary) -> void:
	_config = config


## ===== Main Publish Flow =====

## Publish a robot with given configuration
## config = {
##   "name": String,
##   "description": String,
##   "price": float,
##   "files": Array of file paths,
##   "robot_type": RobotHyperobject.RobotType (optional)
## }
func publish(config: Dictionary) -> Result:
	_config = config

	_emit_progress("Validating...", 0.0)
	var validation = _validate_config(config)
	if validation.is_err():
		publish_failed.emit(validation.get_error())
		return validation

	_emit_progress("Collecting files...", 15.0)
	var files = _collect_robot_files(config.get("files", []))
	if files.is_empty():
		publish_failed.emit("No robot files found to publish")
		return Result.err("No robot files found")

	_emit_progress("Uploading to Arweave...", 30.0)
	var manifest_tx_id = _create_bundle(files)
	if manifest_tx_id.is_empty():
		publish_failed.emit("Failed to upload files to Arweave")
		return Result.err("Failed to upload files")

	_emit_progress("Registering on RChain...", 70.0)
	var coordination = ModuleRegistry.create("coordination", "RChainCoordination", {})
	if coordination == null:
		publish_failed.emit("RChain coordination unavailable")
		return Result.err("RChain coordination unavailable")

	var record := {
		"name": config.get("name", "UnnamedRobot"),
		"asset_tx_id": manifest_tx_id,
		"metadata": {
			"description": config.get("description", ""),
			"asset_type": config.get("asset_type", "ROBOT"),
			"price": config.get("price", 0),
		},
	}
	var reg = coordination.register_robot(record)
	if reg.is_err():
		# Don't hard-fail: the Arweave upload already succeeded.
		_emit_progress("Registered (offline): " + reg.get_error(), 95.0)
	else:
		_emit_progress("Registered on RChain", 95.0)

	_emit_progress("Complete!", 100.0)
	var result := {"repo_id": manifest_tx_id, "address": coordination.get_my_address()}
	publish_complete.emit(result)

	return Result.ok(result)


## ===== File Collection =====

## Collect all robot-related files from common locations
func discover_robot_files() -> Array:
	var files: Array = []

	# Common robot file locations
	var search_paths = [
		"res://scripts/",
		"res://scenes/",
		"res://meshes/",
		"res://urdf/",
		"res://addons/"
	]

	# File extensions to include
	var extensions = ["gd", "tscn", "tres", "urdf", "glb", "gltf", "obj", "stl", "vrm"]

	for search_path in search_paths:
		files.append_array(FileUtils.scan_directory(search_path, extensions))

	return files


## ===== Private Helpers =====

func _validate_config(config: Dictionary) -> Result:
	if not config.has("name") or config.get("name", "").is_empty():
		return Result.err("Robot name is required")

	if not config.has("files") or config.get("files", []).is_empty():
		return Result.err("No files specified for publish")

	return Result.ok({})


func _get_storage() -> Storage:
	if _storage == null:
		_storage = Storage.new(_config.get("arweave_gateway", "https://arweave.net"))
	return _storage


func _collect_robot_files(file_paths: Array) -> Array:
	var files: Array = []

	for path in file_paths:
		if path.begins_with("res://") and FileAccess.file_exists(path):
			files.append(path)
		elif path.begins_with("user://") and FileAccess.file_exists(path):
			files.append(path)
		elif path.begins_with("/"):
			var godot_path = ProjectSettings.globalize_path(path)
			if godot_path.begins_with("res://"):
				files.append(godot_path)

	return files


func _create_bundle(files: Array) -> String:
	var storage := _get_storage()
	var manifest = Manifest.new()

	for file_path in files:
		if not FileAccess.file_exists(file_path):
			continue

		var file_data = FileAccess.get_file_as_bytes(file_path)
		if file_data.is_empty():
			continue

		var ext = file_path.get_extension().to_lower()
		var content_type = FileUtils.get_content_type(ext)

		var upload_result = storage.upload_file(file_path, {"Content-Type": content_type})
		if upload_result.is_ok():
			var info = upload_result.get_data()
			var tx_id = info.get("tx_id", "")
			if not tx_id.is_empty():
				manifest.add_path(_get_relative_path(file_path), tx_id, content_type)

	var manifest_data = JSON.stringify(manifest.to_manifest()).to_utf8_buffer()
	var manifest_result = storage.upload_data(manifest_data, {"Content-Type": "application/x.arweave-manifest+json"})

	if manifest_result.is_ok():
		return manifest_result.get_data().get("tx_id", "")

	return ""


func _get_relative_path(file_path: String) -> String:
	# Convert res:// path to relative
	if file_path.begins_with("res://"):
		return file_path.substr(6)

	# Handle absolute paths
	var res_prefix = ProjectSettings.globalize_path("res://")
	if file_path.begins_with(res_prefix):
		return file_path.substr(res_prefix.length())

	return file_path.get_file()
func _emit_progress(stage: String, percent: float) -> void:
	publish_progress.emit(stage, percent)


## ===== Static Helpers =====

## Estimate cost for uploading files (rough estimate)
static func estimate_cost(files: Array) -> float:
	var total_bytes = 0
	for path in files:
		if FileAccess.file_exists(path):
			var f = FileAccess.get_file_as_bytes(path)
			if f:
				total_bytes += f.size()

	# Arweave: ~$0.10 per MB (very rough estimate)
	# ArDrive free tier: <100kB free
	var price_per_mb = 0.10
	var free_bytes = 100 * 1024  # 100kB free

	if total_bytes <= free_bytes:
		return 0.0

	var billable_mb = float(total_bytes - free_bytes) / (1024.0 * 1024.0)
	return max(0.0, billable_mb * price_per_mb)


## Get file info (size, type) for a path
static func get_file_info(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "size": 0, "type": "unknown"}

	var f = FileAccess.get_file_as_bytes(path)
	if not f:
		return {"exists": false, "size": 0, "type": "unknown"}

	var ext = path.get_extension().to_lower()
	return {
		"exists": true,
		"size": f.size(),
		"type": ext,
		"name": path.get_file()
	}
