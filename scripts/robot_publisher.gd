# robot_publisher.gd
# Orchestrates the full robot publish flow:
#   1. Collect robot files (scripts, scenes, meshes, URDF)
#   2. Create/update git repo for ARIADNE
#   3. Bundle files and create manifest
#   4. Publish to Arweave via AO SDK
#   5. Create AO Hyperobject
#   6. List on marketplace (optional)

class_name RobotPublisher
extends Node

signal publish_progress(stage: String, percent: float)
signal publish_complete(hyperobject: RobotHyperobject)
signal publish_failed(error: String)

const Result = preload("res://addons/primitives/result.gd")
const RobotHyperobject = preload("res://scripts/robot_hyperobject.gd")
const Bundler = preload("res://addons/hyperobject/sdk/bundler.gd")
const Manifest = preload("res://addons/hyperobject/sdk/manifest.gd")

var _ao: AOSDK
var _hyperobject: Hyperobject
var _wallet: Wallet

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

	# Stage 1: Validate wallet and config
	_emit_progress("Validating...", 0.0)
	var validation = _validate_config(config)
	if validation.is_err():
		publish_failed.emit(validation.get_error())
		return validation

	# Stage 2: Initialize AO SDK
	_emit_progress("Initializing...", 10.0)
	var init_result = _initialize_sdk()
	if init_result.is_err():
		publish_failed.emit(init_result.get_error())
		return init_result

	# Stage 3: Collect and bundle files
	_emit_progress("Collecting files...", 15.0)
	var files = _collect_robot_files(config.get("files", []))
	if files.is_empty():
		publish_failed.emit("No robot files found to publish")
		return Result.err("No robot files found")

	_emit_progress("Creating bundle...", 25.0)
	var manifest_tx_id = _create_bundle(files)
	if manifest_tx_id.is_empty():
		publish_failed.emit("Failed to upload files to Arweave")
		return Result.err("Failed to upload files")

	# Stage 4: Create RobotHyperobject
	_emit_progress("Creating Hyperobject...", 60.0)
	var robot_hyperobject = RobotHyperobject.from_files(
		config.get("name", "UnnamedRobot"),
		files,
		_ao
	)
	robot_hyperobject.set_description(config.get("description", ""))
	robot_hyperobject.set_repo_id(manifest_tx_id)
	robot_hyperobject.set_owner(_wallet.get_address() if _wallet else "")

	if config.has("robot_type"):
		robot_hyperobject.set_robot_type(config.get("robot_type"))

	# Stage 5: Spawn AO process
	_emit_progress("Spawning AO process...", 75.0)
	var spawn_result = robot_hyperobject.spawn_ao_process()
	if spawn_result.is_err():
		publish_failed.emit("Failed to spawn AO process: " + spawn_result.get_error())
		return spawn_result

	# Stage 6: List for sale (optional)
	var price = config.get("price", 0.0)
	if price > 0.0:
		_emit_progress("Listing on marketplace...", 90.0)
		var list_result = robot_hyperobject.list_for_sale(price)
		if list_result.is_err():
			print("Warning: Failed to list for sale: " + list_result.get_error())
			# Don't fail the whole publish for this

	# Stage 7: Complete
	_emit_progress("Complete!", 100.0)
	publish_complete.emit(robot_hyperobject)

	return Result.ok({
		"hyperobject": robot_hyperobject,
		"repo_id": manifest_tx_id,
		"process_id": robot_hyperobject.get_process_id(),
		"owner": robot_hyperobject.get_owner()
	})


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


func _initialize_sdk() -> Result:
	_ao = AOSDK.new()

	# Get wallet from Hyperobject singleton if available
	var hyperobject_node = get_node_or_null("/root/Hyperobject")
	if hyperobject_node and hyperobject_node.has_method("get_ao"):
		_ao = hyperobject_node.get_ao()
		_wallet = _ao.get_wallet()
	elif hyperobject_node and hyperobject_node.has_method("get_wallet"):
		_wallet = hyperobject_node.get_wallet()

	# Initialize AO SDK
	var hyperbeam_url = _config.get("hyperbeam_url", "https://mu.ardrive.io/v1")
	var arweave_gateway = _config.get("arweave_gateway", "https://arweave.net")

	return _ao.initialize(hyperbeam_url, arweave_gateway)


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
	if not _ao:
		return ""

	var manifest = Manifest.new()

	for file_path in files:
		if not FileAccess.file_exists(file_path):
			continue

		var file_data = FileAccess.get_file_as_bytes(file_path)
		if file_data.is_empty():
			continue

		var ext = file_path.get_extension().to_lower()
		var content_type = FileUtils.get_content_type(ext)

		# Upload directly to Arweave
		var upload_result = _ao.upload_asset(file_path, {"Content-Type": content_type})
		if upload_result.is_ok():
			var info = upload_result.get_data()
			var tx_id = info.get("tx_id", "")
			if not tx_id.is_empty():
				# Extract relative path
				var rel_path = _get_relative_path(file_path)
				manifest.add_path(rel_path, tx_id, content_type)

	# Upload manifest
	var manifest_data = JSON.stringify(manifest.to_manifest()).to_utf8_buffer()
	var manifest_result = _ao.upload_data(manifest_data, {"Content-Type": "application/x.arweave-manifest+json"})

	if manifest_result.is_ok():
		var info = manifest_result.get_data()
		return info.get("tx_id", "")

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
