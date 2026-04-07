# manifest.gd
# Arweave Manifest helper

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
