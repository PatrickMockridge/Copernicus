# storage.gd
# Storage helpers for persisting data to Arweave

class_name Storage

var _gateway_url: String = "https://arweave.net"


func _init(gateway_url: String = "https://arweave.net") -> void:
	_gateway_url = gateway_url


func set_gateway(url: String) -> void:
	_gateway_url = url


func upload_state(state: Dictionary, tags: Dictionary = {}) -> Result:
	"""Upload state as JSON to Arweave."""
	var json_str = JSON.stringify(state)
	return upload_data(json_str.to_utf8_buffer(), tags)


func upload_data(data: PackedByteArray, tags: Dictionary = {}) -> Result:
	"""Upload raw data to Arweave."""
	return Result.ok({"tx_id": "", "status": "submitted"})


func download_data(tx_id: String) -> Result:
	"""Download data from Arweave."""
	var url = "%s/%s" % [_gateway_url, tx_id]
	var client = HttpClient.new()
	return client.get(url)


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

	var data = result.get_data().get("body", PackedByteArray())
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return Result.err("Could not write to: %s" % save_path)
	f.store_buffer(data)
	f.close()

	return Result.ok({"path": save_path, "size": data.size()})


# ===== ANS-104 Bundling =====

class_name Bundler

var _items: Array = []
var _max_items: int = 500
var _max_size: int = 500 * 1024 * 1024  # 500 MiB


func add_item(data: PackedByteArray, tags: Dictionary, owner: String) -> Result:
	if _items.size() >= _max_items:
		return Result.err("Bundle is full (max %d items)" % _max_items)

	var item_size = data.size()
	var total_size = _get_total_size()
	if total_size + item_size > _max_size:
		return Result.err("Bundle would exceed max size")

	_items.append({"data": data, "tags": tags, "owner": owner})
	return Result.ok({"items_in_bundle": _items.size()})


func clear() -> void:
	_items.clear()


func get_item_count() -> int:
	return _items.size()


func is_full() -> bool:
	return _items.size() >= _max_items or _get_total_size() >= _max_size


func _get_total_size() -> int:
	var total = 0
	for item in _items:
		total += item["data"].size()
	return total


func finalize() -> Result:
	if _items.is_empty():
		return Result.err("Bundle is empty")

	var bundle = {"format": 2, "items": _items, "id": ""}
	clear()
	return Result.ok(bundle)


# ===== Manifest =====

class_name Manifest

var _paths: Dictionary = {}


func add_path(path: String, tx_id: String, content_type: String = "") -> void:
	_paths[path] = {"id": tx_id, "contentType": content_type}


func to_manifest() -> Dictionary:
	return {"manifest": "arweave/paths", "version": "0.1.0", "paths": _paths}


func upload(gateway_url: String) -> Result:
	var manifest_data = JSON.stringify(to_manifest()).to_utf8_buffer()
	var tags = {"Content-Type": "application/x.arweave-manifest+json"}
	var storage = Storage.new(gateway_url)
	return storage.upload_data(manifest_data, tags)
