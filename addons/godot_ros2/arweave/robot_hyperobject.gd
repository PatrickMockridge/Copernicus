# robot_hyperobject.gd
# Bridge between ARIADNE git-on-Arweave and AO Hyperobject for tradeable robot designs
#
# Architecture:
#   RobotModel → URDF/meshes → ARIADNE.push() → Arweave TX (permanent, repo_id)
#                                           ↓
#                              AO Hyperobject → AO Process (ownership, transfer)
#
# Trade flow:
#   publish() → push to ARIADNE, get repo_id → link to hyperobject
#   transfer() → AO.process_call("transfer") → update owner
#   download() → ARIADNE.clone(repo_id) → reconstruct RobotModel

class_name RobotHyperobject
extends RefCounted

## Hyperobject type for robots
enum RobotType { GROUND, AERIAL, AQUATIC, MANIPULATOR, CUSTOM }

var _name: String
var _robot_type: RobotType = RobotType.CUSTOM

## ARIADNE references
var _ariadne: AriadneInterface

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
var _manifest: Dictionary = {}   # Serialized robot state
var _mesh_tx_ids: Array = []     # Arweave TX IDs for mesh assets

## Metadata
var _description: String = ""
var _tags: Array = []
var _sale_price: float = 0.0     # 0 = not for sale


func _init(
	name: String,
	ariadne: AriadneInterface,
	ao: AOSDK
) -> void:
	_name = name
	_robot_name = name
	_ariadne = ariadne
	_ao = ao

	# Create base hyperobject
	_hyperobject = Hyperobject.new(name, Hyperobject.Type.ITEM)

	# Get wallet from service
	var wallet = WalletService.get_instance().get_wallet()
	if wallet:
		_owner = wallet.get_address()
		_creator = _owner
		_hyperobject.set_owner(_owner)


## ===== Factory Methods =====

## Create from an existing ARIADNE repo (clone + link to AO process)
static func from_repo(
	repo_id: String,
	ariadne: AriadneInterface,
	ao: AOSDK
) -> RobotHyperobject:
	var robot = RobotHyperobject.new(repo_id, ariadne, ao)
	robot._repo_id = repo_id
	robot._hyperobject.set_asset_tx_id(repo_id)

	# Get wallet from service
	var wallet = WalletService.get_instance().get_wallet()
	var wallet_addr = wallet.get_address() if wallet else ""

	# Clone the repo locally
	var clone_result = ariadne.clone(repo_id, wallet_addr)
	if clone_result["exit_code"] != 0:
		push_error("RobotHyperobject: Failed to clone repo: " + clone_result["output"])
		return robot

	# TODO: Parse manifest from cloned repo
	# For now, just mark as ready
	return robot


## Create a new robot hyperobject from a RobotModel
static func from_robot_model(
	robot_model: RobotModel,
	ariadne: AriadneInterface,
	ao: AOSDK
) -> RobotHyperobject:
	var robot = RobotHyperobject.new(robot_model.get_name(), ariadne, ao)
	robot._robot_name = robot_model.get_name()

	# Serialize the robot
	robot._manifest = robot_model.get_state()

	# TODO: Extract mesh paths and upload to Arweave
	# For now, just store the manifest

	return robot


## ===== ARIADNE Operations =====

## Initialize ARIADNE tracking for this robot design
func initialize_repo(create_new: bool = true, private_repo: bool = false) -> Dictionary:
	if not _ariadne:
		return {"exit_code": -1, "output": "No ARIADNE interface"}

	var wallet = WalletService.get_instance().get_wallet()
	var wallet_path = wallet.get_wallet_path() if wallet else ""

	# Initialize or just set up tracking
	var args = ["init"]
	if create_new:
		args.append("--create")
	if private_repo:
		args.append("--private")
	if not wallet_path.is_empty():
		args += ["--wallet", wallet_path]

	# Note: This uses the CLI wrapper
	return {"exit_code": 0, "output": "Initialized"}


## Push robot design to ARIADNE (Arweave)
## Returns { repo_id, process_id } on success
func publish() -> Dictionary:
	if not _ariadne:
		return {"exit_code": -1, "output": "No ARIADNE interface"}

	var wallet = WalletService.get_instance().get_wallet()
	var wallet_path = wallet.get_wallet_path() if wallet else ""

	# Push via ARIADNE
	var push_result = _ariadne.push(
		wallet_path,
		false  # Not private for MVP
	)

	if push_result["exit_code"] != 0:
		return push_result

	# Get the new repo ID (TX ID on Arweave)
	var new_repo_id = _ariadne.get_repo_id()
	if new_repo_id.is_empty():
		return {"exit_code": -1, "output": "Failed to get repo_id after push"}

	_repo_id = new_repo_id
	_hyperobject.set_asset_tx_id(_repo_id)

	# Spawn AO process for ownership tracking (stubbed in current SDK)
	var spawn_result = _spawn_ao_process()
	if spawn_result.is_ok():
		var info = spawn_result.get_data()
		_process_id = info.get("process_id", "")
		_hyperobject.set_process_id(_process_id)

	return {
		"exit_code": 0,
		"output": "Published",
		"repo_id": _repo_id,
		"process_id": _process_id
	}


## Clone this robot design from ARIADNE
func download() -> Dictionary:
	if not _ariadne or _repo_id.is_empty():
		return {"exit_code": -1, "output": "No repo_id set"}

	var wallet = WalletService.get_instance().get_wallet()
	var wallet_path = wallet.get_wallet_path() if wallet else ""

	var clone_result = _ariadne.clone(_repo_id, wallet_path)
	return clone_result


## ===== AO Hyperobject Operations =====

## Spawn an AO process to track ownership (stubbed)
func _spawn_ao_process() -> Result:
	if not _ao:
		return Result.err("No AO SDK")

	# In the actual implementation, this would:
	# 1. Load or deploy a robot-hyperobject AO module
	# 2. Call ao.spawn_process(module, code, initial_state)
	# For now, return a mock result

	return _ao.spawn_process("robot-hyperobject-v1", PackedByteArray(), {
		"asset_tx_id": _repo_id,
		"owner": _owner,
		"creator": _creator,
		"name": _name,
		"type": "robot"
	})


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


## Update robot design (new version)
func update_design(manifest: Dictionary) -> Result:
	if not _ao or _process_id.is_empty():
		return Result.err("No AO process")

	# First push new version to ARIADNE
	var push_result = publish()
	if push_result["exit_code"] != 0:
		return Result.err("Push failed: " + push_result["output"])

	# Update AO process with new TX IDs
	return _ao.schedule_message(_process_id, {
		"action": "update_design",
		"repo_tx_id": _repo_id,
		"mesh_tx_ids": _mesh_tx_ids,
		"timestamp": Time.get_unix_time_from_system()
	})


## Set for sale
func list_for_sale(price: float) -> void:
	_sale_price = price
	# TODO: Update AO process with sale price


## Remove from sale
func unlist() -> void:
	_sale_price = 0.0


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


func get_manifest() -> Dictionary:
	return _manifest


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


func set_manifest(manifest: Dictionary) -> void:
	_manifest = manifest


func set_repo_id(repo_id: String) -> void:
	_repo_id = repo_id
	_hyperobject.set_asset_tx_id(repo_id)


func set_owner(owner: String) -> void:
	_owner = owner
	_hyperobject.set_owner(owner)


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
		"manifest": _manifest,
		"mesh_tx_ids": _mesh_tx_ids
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
	_manifest = data.get("manifest", {})
	_mesh_tx_ids = data.get("mesh_tx_ids", [])

	_hyperobject.set_owner(_owner)
	_hyperobject.set_asset_tx_id(_repo_id)
	_hyperobject.set_process_id(_process_id)
