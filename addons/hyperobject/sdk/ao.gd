# ao.gd
# AO SDK - General purpose SDK for AO (Actor-Oriented) compute + Arweave
# Built composably from primitives + HyperBEAM + ArDrive

class_name AOSDK

var _wallet: Wallet
var _config: Dictionary = {}
var _http_client: HttpClient
var _storage: Storage

# HyperBEAM endpoints (Messenger Unit / Compute Unit)
var _mu_url: String = "https://mu.ardrive.io/v1"
var _cu_url: String = "https://cu.ardrive.io/v1"
var _su_url: String = "https://su.ardrive.io/v1"


func _init() -> void:
	_http_client = HttpClient.new()
	_storage = Storage.new()


func initialize(hyperbeam_url: String, arweave_gateway: String) -> Result:
	_config = {
		"hyperbeam_url": hyperbeam_url,
		"arweave_gateway": arweave_gateway
	}
	# Update endpoints if custom hyperbeam_url provided
	if not hyperbeam_url.is_empty():
		_mu_url = hyperbeam_url + "/mu/v1"
		_cu_url = hyperbeam_url + "/cu/v1"
		_su_url = hyperbeam_url + "/su/v1"
	return Result.ok({"hyperbeam": hyperbeam_url, "arweave": arweave_gateway})


func set_wallet(wallet: Wallet) -> void:
	_wallet = wallet


func get_wallet() -> Wallet:
	return _wallet


func get_address() -> String:
	if _wallet:
		return _wallet.get_address()
	return ""


func get_storage() -> Storage:
	return _storage


# ===== AO Operations =====

func get_process_info(process_id: String) -> Result:
	"""Get info about an AO process from Compute Unit."""
	var url = "%s/processes/%s" % [_cu_url, process_id]

	var result = _http_client.get(url, _get_auth_headers())
	if result.is_err():
		return result

	var response = result.get_data()
	var body = response.get("body_string", "")

	if body.is_empty():
		return Result.err("Empty response")

	var parsed = JSON.parse_string(body)
	if not parsed:
		return Result.err("Failed to parse response")

	return Result.ok({
		"process_id": process_id,
		"owner": parsed.get("owner", ""),
		"state": parsed.get("state", {}),
		"tags": parsed.get("tags", []),
		"timestamp": parsed.get("timestamp", 0)
	})


func schedule_message(process_id: String, message: Dictionary) -> Result:
	"""Schedule a message with an AO process via Messenger Unit."""
	var url = "%s/messages" % _mu_url

	# Encode message as base64
	var message_json = JSON.stringify(message)
	var message_data = message_json.to_utf8_buffer()

	var payload = {
		"processId": process_id,
		"data": _base64_encode_string(message_json),
		"tags": _message_tags(message)
	}

	var result = _http_client.post(url, payload, _get_auth_headers())
	if result.is_err():
		return result

	var response = result.get_data()
	var body = response.get("body_string", "")
	var parsed = JSON.parse_string(body) if not body.is_empty() else {}

	return Result.ok({
		"scheduled": true,
		"message_id": parsed.get("id", ""),
		"process_id": process_id
	})


func process_call(process_id: String, handler: String, args: Dictionary) -> Result:
	"""Call a handler on an AO process (read-only evaluation)."""
	var url = "%s/processes/%s/evaluate" % [_cu_url, process_id]

	var payload = {
		"handler": handler,
		"args": args
	}

	var result = _http_client.post(url, payload, _get_auth_headers())
	if result.is_err():
		return result

	var response = result.get_data()
	var body = response.get("body_string", "")

	if body.is_empty():
		return Result.err("Empty response")

	var parsed = JSON.parse_string(body)
	return Result.ok({
		"output": parsed.get("output", null),
		"state": parsed.get("state", null),
		"error": parsed.get("error", null)
	})


func spawn_process(module: String, code: PackedByteArray, initial_state: Dictionary = {}) -> Result:
	"""Spawn a new AO process."""
	var url = "%s/processes" % _cu_url

	# Build tags for the process
	var tags: Array = []
	tags.append({"name": "Module", "value": module})
	tags.append({"name": "Type", "value": "hyperobject"})
	if _wallet:
		tags.append({"name": "Owner", "value": _wallet.get_address()})

	var payload = {
		"module": module,
		"code": _base64_encode(code),
		"initialState": initial_state,
		"tags": tags
	}

	var result = _http_client.post(url, payload, _get_auth_headers())
	if result.is_err():
		return result

	var response = result.get_data()
	var body = response.get("body_string", "")

	if body.is_empty():
		return Result.err("Empty response")

	var parsed = JSON.parse_string(body)
	if not parsed:
		return Result.err("Failed to parse spawn response")

	var process_id = parsed.get("processId", parsed.get("id", ""))
	if process_id.is_empty():
		return Result.err("No process ID in response")

	return Result.ok({
		"process_id": process_id,
		"tx_id": parsed.get("txid", ""),
		"module": module
	})


func get_messages(process_id: String) -> Result:
	"""Get message history for a process from Scheduler Unit."""
	var url = "%s/processes/%s/messages" % [_su_url, process_id]

	var result = _http_client.get(url, _get_auth_headers())
	if result.is_err():
		return result

	var response = result.get_data()
	var body = response.get("body_string", "")

	if body.is_empty():
		return Result.ok({"messages": []})

	var parsed = JSON.parse_string(body)
	var messages = parsed.get("messages", []) if parsed else []

	return Result.ok({"messages": messages, "count": messages.size()})


# ===== Arweave Operations =====

func upload_data(data: PackedByteArray, tags: Dictionary = {}) -> Result:
	"""Upload data to Arweave."""
	return _storage.upload_data(data, tags)


func download_data(tx_id: String) -> Result:
	"""Download data from Arweave."""
	return _storage.download_data(tx_id)


func get_transaction_status(tx_id: String) -> Result:
	"""Get transaction status on Arweave."""
	var url = "https://arweave.net/%s" % tx_id

	var result = _http_client.get(url)
	if result.is_err():
		return result

	return Result.ok({
		"tx_id": tx_id,
		"status": "confirmed"
	})


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
	return _storage.download_file(tx_id, save_path)


# ===== Helper Methods =====

func _get_auth_headers() -> Dictionary:
	var headers: Dictionary = {
		"Content-Type": "application/json"
	}
	# Wallet-based auth would go here
	# For now, we're using open endpoints
	return headers


func _base64_encode(data: PackedByteArray) -> String:
	"""Encode bytes to base64 string."""
	if data.is_empty():
		return ""
	return Marshalls.raw_to_base64(data)


func _base64_encode_string(text: String) -> String:
	"""Encode string to base64."""
	if text.is_empty():
		return ""
	return Marshalls.raw_to_base64(text.to_utf8_buffer())


func _message_tags(message: Dictionary) -> Array:
	"""Build tags from message content."""
	var tags: Array = []
	var action = message.get("action", "")
	if not action.is_empty():
		tags.append({"name": "Action", "value": action})
	return tags


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
