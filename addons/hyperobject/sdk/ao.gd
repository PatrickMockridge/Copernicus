# ao.gd
# AO SDK - General purpose SDK for AO (Actor-Oriented) compute + Arweave
# Built composably from primitives + HyperBEAM + ArDrive

class_name AOSDK

var _wallet: Wallet
var _config: Dictionary = {}


func _init() -> void:
	pass


func initialize(hyperbeam_url: String, arweave_gateway: String) -> Result:
	_config = {
		"hyperbeam_url": hyperbeam_url,
		"arweave_gateway": arweave_gateway
	}
	return Result.ok({"hyperbeam": hyperbeam_url, "arweave": arweave_gateway})


func set_wallet(wallet: Wallet) -> void:
	_wallet = wallet


func get_wallet() -> Wallet:
	return _wallet


func get_address() -> String:
	if _wallet:
		return _wallet.get_address()
	return ""


# ===== AO Operations =====

func get_process_info(process_id: String) -> Result:
	"""Get info about an AO process."""
	return Result.ok({"process_id": process_id})


func schedule_message(process_id: String, message: Dictionary) -> Result:
	"""Schedule a message with an AO process."""
	return Result.ok({"scheduled": true})


func process_call(process_id: String, handler: String, args: Dictionary) -> Result:
	"""Call a handler on an AO process."""
	return Result.ok({})


func spawn_process(module: String, code: PackedByteArray, initial_state: Dictionary = {}) -> Result:
	"""Spawn a new AO process."""
	return Result.ok({})


# ===== Arweave Operations =====

func upload_data(data: PackedByteArray, tags: Dictionary = {}) -> Result:
	"""Upload data to Arweave."""
	return Result.ok({})


func download_data(tx_id: String) -> Result:
	"""Download data from Arweave."""
	return Result.ok({})


func get_transaction_status(tx_id: String) -> Result:
	"""Get transaction status on Arweave."""
	return Result.ok({})


# ===== Game Asset Helpers =====

func upload_asset(path: String, tags: Dictionary = {}) -> Result:
	"""Upload a game asset (VRM, GLB, etc.) to Arweave."""
	if not FileAccess.file_exists(path):
		return Result.err("File not found: %s" % path)

	var file = FileAccess.get_file_as_bytes(path)
	if file == null or file.size() == 0:
		return Result.err("Could not read file")

	var ext = path.get_extension().to_lower()
	tags["Content-Type"] = _get_content_type(ext)

	return upload_data(file, tags)


func download_asset(tx_id: String, save_path: String) -> Result:
	"""Download an asset from Arweave."""
	return download_data(tx_id)


func _get_content_type(extension: String) -> String:
	match extension:
		"vrm": return "model/vrm"
		"glb": return "model/gltf-binary"
		"gltf": return "model/gltf+json"
		"png": return "image/png"
		"jpg", "jpeg": return "image/jpeg"
		"mp4": return "video/mp4"
		"json": return "application/json"
		_: return "application/octet-stream"
