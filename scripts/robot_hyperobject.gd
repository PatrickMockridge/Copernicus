# robot_hyperobject.gd
# Bridge between ARIADNE git-on-Arweave and AO Hyperobject for tradeable robot designs
#
# Architecture:
#   Robot Files (URDF, scenes, meshes) → ARIADNE.push() → Arweave TX (permanent, repo_id)
#                                                           ↓
#                                              AO Hyperobject → AO Process (ownership, transfer)
#
# Trade flow:
#   publish() → push to ARIADNE, get repo_id → link to hyperobject
#   transfer() → AO.process_call("transfer") → update owner
#   download() → ARIADNE.clone(repo_id) → reconstruct robot files

class_name RobotHyperobject
extends RefCounted

## Hyperobject type for robots
enum RobotType { GROUND, AERIAL, AQUATIC, MANIPULATOR, CUSTOM }

var _name: String
var _robot_type: RobotType = RobotType.CUSTOM

## AO Hyperobject references
var _ao: AOSDK
var _hyperobject: Hyperobject

## Core IDs
var _repo_id: String = ""        # ARIADNE repo TX ID (becomes asset_tx_id)
var _process_id: String = ""     # AO process ID
var _owner: String = ""          # Wallet address
var _creator: String = ""

## Robot design data
var _robot_name: String
var _description: String = ""
var _robot_files: Array = []      # List of file paths included in this robot
var _mesh_tx_ids: Array = []     # Arweave TX IDs for mesh assets

## Metadata
var _tags: Array = []
var _sale_price: float = 0.0     # 0 = not for sale

## Arweave gateway for uploads
var _arweave_gateway: String = "https://arweave.net"


func _init(name: String, ao: AOSDK) -> void:
	_name = name
	_robot_name = name
	_ao = ao

	# Create base hyperobject
	_hyperobject = Hyperobject.new(name, Hyperobject.Type.ITEM)

	# Get wallet from AO SDK
	if _ao and _ao.get_wallet():
		_owner = _ao.get_wallet().get_address()
		_creator = _owner
		_hyperobject.set_owner(_owner)


## ===== Factory Methods =====

## Create from an existing ARIADNE repo (clone + link to AO process)
static func from_repo(
	repo_id: String,
	ao: AOSDK
) -> RobotHyperobject:
	var robot = RobotHyperobject.new(repo_id, ao)
	robot._repo_id = repo_id
	robot._hyperobject.set_asset_tx_id(repo_id)
	return robot


## Create a new robot hyperobject from files
static func from_files(
	robot_name: String,
	files: Array,
	ao: AOSDK
) -> RobotHyperobject:
	var robot = RobotHyperobject.new(robot_name, ao)
	robot._robot_name = robot_name
	robot._robot_files = files
	return robot


## ===== File Operations =====

## Add a file to be published with this robot
func add_file(file_path: String) -> void:
	if not _robot_files.has(file_path):
		_robot_files.append(file_path)


## Remove a file from the bundle
func remove_file(file_path: String) -> void:
	_robot_files.erase(file_path)


## Get all files in this robot bundle
func get_files() -> Array:
	return _robot_files.duplicate()


## Get total size of all files
func get_total_size() -> int:
	var total = 0
	for path in _robot_files:
		if FileAccess.file_exists(path):
			var f = FileAccess.get_file_as_bytes(path)
			if f:
				total += f.size()
	return total


## ===== Arweave Upload =====

## Upload all robot files to Arweave
## Returns { success: bool, manifest_tx_id: String, mesh_tx_ids: Array }
func upload_files() -> Result:
	if not _ao:
		return Result.err("No AO SDK")

	var manifest_tx_id = ""
	var mesh_ids: Array = []

	# Upload each file
	for file_path in _robot_files:
		if not FileAccess.file_exists(file_path):
			continue

		var file_data = FileAccess.get_file_as_bytes(file_path)
		if file_data.is_empty():
			continue

		# Determine content type
		var ext = file_path.get_extension().to_lower()
		var content_type = _get_content_type(ext)

		# Build tags
		var tags = {
			"Content-Type": content_type,
			"Robot-Name": _robot_name,
			"File-Path": file_path
		}

		# Upload to Arweave
		var upload_result = _ao.upload_data(file_data, tags)
		if upload_result.is_ok():
			var info = upload_result.get_data()
			var tx_id = info.get("tx_id", "")
			if tx_id:
				mesh_ids.append({"path": file_path, "tx_id": tx_id})
				# First file is considered the manifest
				if manifest_tx_id.is_empty():
					manifest_tx_id = tx_id
		else:
			print("Failed to upload %s: %s" % [file_path, upload_result.get_error()])

	_mesh_tx_ids = mesh_ids

	if manifest_tx_id.is_empty():
		return Result.err("No files uploaded successfully")

	_repo_id = manifest_tx_id
	_hyperobject.set_asset_tx_id(manifest_tx_id)

	return Result.ok({
		"manifest_tx_id": manifest_tx_id,
		"mesh_tx_ids": mesh_ids
	})


## ===== AO Hyperobject Operations =====

## Spawn an AO process to track ownership
func spawn_ao_process() -> Result:
	if not _ao:
		return Result.err("No AO SDK")

	# Upload files first
	var upload_result = upload_files()
	if upload_result.is_err():
		return upload_result

	var upload_info = upload_result.get_data()

	# Create initial state for the robot hyperobject process
	var initial_state = {
		"asset_tx_id": _repo_id,
		"owner": _owner,
		"creator": _creator,
		"name": _robot_name,
		"type": "robot",
		"robot_type": _robot_type,
		"description": _description,
		"files": _robot_files,
		"mesh_tx_ids": upload_info.get("mesh_tx_ids", []),
		"tags": _tags,
		"sale_price": _sale_price
	}

	# Spawn the process
	var spawn_result = _ao.spawn_process("robot-hyperobject-v1", PackedByteArray(), initial_state)
	if spawn_result.is_ok():
		var info = spawn_result.get_data()
		_process_id = info.get("process_id", "")
		_hyperobject.set_process_id(_process_id)

	return spawn_result


## Transfer ownership to a new wallet
func transfer(new_owner: String) -> Result:
	if not _ao or _process_id.is_empty():
		return Result.err("No AO process")

	# Schedule transfer message to AO process
	var result = _ao.schedule_message(_process_id, {
		"action": "transfer",
		"from": _owner,
		"to": new_owner,
		"timestamp": Time.get_unix_time_from_system()
	})

	if result.is_ok():
		_owner = new_owner
		_hyperobject.set_owner(new_owner)

	return result


## Set for sale
func list_for_sale(price: float) -> Result:
	_sale_price = price

	if not _ao or _process_id.is_empty():
		return Result.err("No AO process")

	# Update the process with new sale price
	return _ao.schedule_message(_process_id, {
		"action": "set_price",
		"price": price,
		"timestamp": Time.get_unix_time_from_system()
	})


## Remove from sale
func unlist() -> Result:
	_sale_price = 0.0

	if not _ao or _process_id.is_empty():
		return Result.err("No AO process")

	return _ao.schedule_message(_process_id, {
		"action": "unlist",
		"timestamp": Time.get_unix_time_from_system()
	})


## ===== Getters =====

func get_name() -> String:
	return _name


func get_repo_id() -> String:
	return _repo_id


func get_process_id() -> String:
	return _process_id


func get_owner() -> String:
	return _owner


func get_creator() -> String:
	return _creator


func get_hyperobject() -> Hyperobject:
	return _hyperobject


func get_description() -> String:
	return _description


func get_mesh_tx_ids() -> Array:
	return _mesh_tx_ids


func get_sale_price() -> float:
	return _sale_price


func is_for_sale() -> bool:
	return _sale_price > 0.0


## ===== Setters =====

func set_name(name: String) -> void:
	_name = name


func set_description(description: String) -> void:
	_description = description


func set_tags(tags: Array) -> void:
	_tags = tags


func set_robot_type(robot_type: RobotType) -> void:
	_robot_type = robot_type


func set_repo_id(repo_id: String) -> void:
	_repo_id = repo_id
	_hyperobject.set_asset_tx_id(repo_id)


func set_owner(owner: String) -> void:
	_owner = owner
	_hyperobject.set_owner(owner)


func set_process_id(process_id: String) -> void:
	_process_id = process_id
	_hyperobject.set_process_id(process_id)


## ===== Serialization =====

func to_dictionary() -> Dictionary:
	return {
		"name": _name,
		"robot_type": _robot_type,
		"repo_id": _repo_id,
		"process_id": _process_id,
		"owner": _owner,
		"creator": _creator,
		"description": _description,
		"tags": _tags,
		"sale_price": _sale_price,
		"robot_files": _robot_files,
		"mesh_tx_ids": _mesh_tx_ids
	}


func to_tradeable_dict() -> Dictionary:
	"""Format for AO marketplace listing."""
	return {
		"id": _repo_id,
		"name": _robot_name,
		"type": "robot",
		"robot_type": RobotType.keys()[_robot_type].to_lower(),
		"owner": _owner,
		"creator": _creator,
		"description": _description,
		"tags": _tags,
		"sale_price": _sale_price,
		"files": _robot_files.size(),
		"total_size": get_total_size()
	}


func from_dictionary(data: Dictionary) -> void:
	_name = data.get("name", "")
	_robot_type = data.get("robot_type", RobotType.CUSTOM)
	_repo_id = data.get("repo_id", "")
	_process_id = data.get("process_id", "")
	_owner = data.get("owner", "")
	_creator = data.get("creator", "")
	_description = data.get("description", "")
	_tags = data.get("tags", [])
	_sale_price = data.get("sale_price", 0.0)
	_robot_files = data.get("robot_files", [])
	_mesh_tx_ids = data.get("mesh_tx_ids", [])

	_hyperobject.set_owner(_owner)
	_hyperobject.set_asset_tx_id(_repo_id)
	_hyperobject.set_process_id(_process_id)


## ===== Helper Methods =====

func _get_content_type(extension: String) -> String:
	match extension:
		"gd": return "text/x-gdscript"
		"tscn": return "text/plain"
		"tres": return "text/plain"
		"urdf": return "application/xml"
		"glb": return "model/gltf-binary"
		"gltf": return "model/gltf+json"
		"obj": return "model/obj"
		"stl": return "model/stl"
		"vrm": return "model/vrm"
		"png": return "image/png"
		"jpg", "jpeg": return "image/jpeg"
		"json": return "application/json"
		"md": return "text/markdown"
		_: return "application/octet-stream"
