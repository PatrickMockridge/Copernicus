# storage.gd
# Storage helpers for persisting data to Arweave

class_name Storage

var _gateway_url: String = "https://arweave.net"
var _turbo_url: String = "https://turbo.ardrive.io/v1/turbo/upload"
var _http_client: HyperHttpClient


func _init(gateway_url: String = "https://arweave.net") -> void:
	_gateway_url = gateway_url
	_http_client = HyperHttpClient.new()


func set_gateway(url: String) -> void:
	_gateway_url = url


func set_turbo_url(url: String) -> void:
	_turbo_url = url


func upload_state(state: Dictionary, tags: Dictionary = {}) -> Result:
	"""Upload state as JSON to Arweave."""
	var json_str = JSON.stringify(state)
	return upload_data(json_str.to_utf8_buffer(), tags)


func upload_data(data: PackedByteArray, tags: Dictionary = {}) -> Result:
	"""Upload raw data to Arweave via gateway."""
	var url = _gateway_url + "/upload"

	# Build headers
	var headers: Dictionary = {}
	if tags.has("Content-Type"):
		headers["Content-Type"] = tags["Content-Type"]
	else:
		headers["Content-Type"] = "application/octet-stream"

	# Add tags as headers
	var tag_headers: Array = []
	for k in tags:
		if k != "Content-Type":
			tag_headers.append({"name": k, "value": str(tags[k])})

	# Simple upload to arweave.net gateway
	var result = _http_client.post(url, data, headers)

	if result.is_err():
		# Try turbo as fallback
		return _upload_via_turbo(data, tags)

	var response = result.get_data()
	var tx_id = _extract_tx_id_from_response(response)
	return Result.ok({"tx_id": tx_id, "status": "submitted"})


func _extract_tx_id_from_response(response: Dictionary) -> String:
	# Try to parse TX ID from response
	var body = response.get("body_string", "")
	if body.is_empty():
		return ""
	# Parse JSON response for txid field
	var parsed = JSON.parse_string(body)
	if parsed and parsed is Dictionary:
		return parsed.get("id", parsed.get("txid", ""))
	return ""


func _upload_via_turbo(data: PackedByteArray, tags: Dictionary) -> Result:
	"""Upload via Turbo API for fast confirmation."""
	var url = _turbo_url

	# Turbo uses Bearer token auth - placeholder for now
	var headers: Dictionary = {
		"Content-Type": "application/octet-stream"
	}

	var result = _http_client.post(url, data, headers)

	if result.is_err():
		return result

	var response = result.get_data()
	var tx_id = _extract_tx_id_from_response(response)

	return Result.ok({"tx_id": tx_id, "status": "turbo", "data_size": data.size()})


func download_data(tx_id: String) -> Result:
	"""Download data from Arweave."""
	var url = "%s/%s" % [_gateway_url, tx_id]

	var result = _http_client.fetch(url)
	if result.is_err():
		return result

	var response = result.get_data()
	var body = response.get("body", PackedByteArray())
	var content_type = response.get("headers", {}).get("Content-Type", "application/octet-stream")

	return Result.ok({"body": body, "content_type": content_type, "tx_id": tx_id})


func upload_file(local_path: String, tags: Dictionary = {}) -> Result:
	"""Upload a file to Arweave."""
	if not FileAccess.file_exists(local_path):
		return Result.err("File not found")

	var data = FileAccess.get_file_as_bytes(local_path)
	if data == null or data.size() == 0:
		return Result.err("Could not read file")

	return upload_data(data, tags)


func download_file(tx_id: String, save_path: String) -> Result:
	"""Download and save a file from Arweave."""
	var result = download_data(tx_id)
	if result.is_err():
		return result

	var response = result.get_data()
	var data = response.get("body", PackedByteArray())
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return Result.err("Could not write to: %s" % save_path)
	f.store_buffer(data)
	f.close()

	return Result.ok({"path": save_path, "size": data.size()})
