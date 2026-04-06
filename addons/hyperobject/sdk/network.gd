# network.gd
# Network utilities for AO/Arweave

class_name Network

static func get_gateways() -> Array:
	"""Get known Arweave gateways."""
	return ["https://arweave.net", "https://arweave.run", "https://gateway.arweave.net"]


static func get_turbo_gateway() -> String:
	"""Get Turbo gateway URL for fast uploads."""
	return "https://turbo.ardrive.io/v1/turbo/upload"


# ===== GraphQL =====

static func query_transactions(tags: Array, owner: String = "", first: int = 100) -> String:
	var parts: Array = []
	if not owner.is_empty():
		parts.append("owners: [\"%s\"]" % owner)
	if not tags.is_empty():
		var tag_strs: Array = []
		for tag in tags:
			var name = tag.get("name", "")
			var value = tag.get("value", "")
			tag_strs.append("{name: \"%s\", values: [\"%s\"]}" % [name, value])
		parts.append("tags: [%s]" % ", ".join(tag_strs))
	return """
	query {
		transactions(
			%s
			first: %d
		) {
			edges {
				node {
					id
					tags { name value }
					block { timestamp height }
				}
			}
		}
	}
	""" % [parts.join(", "), first]


# ===== ANS-104 =====

static func create_data_item(owner: String, data: PackedByteArray, tags: Dictionary) -> Dictionary:
	return {
		"format": 1,
		"owner": owner,
		"target": "",
		"anchor": "",
		"tags": _format_tags(tags),
		"data": data
	}


static func _format_tags(tags: Dictionary) -> Array:
	var formatted: Array = []
	for k in tags:
		formatted.append({"name": k.to_utf8_buffer(), "value": str(tags[k]).to_utf8_buffer()})
	return formatted


# ===== HyperPATH =====

static func build_process_path(process_id: String, device: String, version: String, operation: String) -> String:
	return "/%s~%s@%s/%s" % [process_id, device, version, operation]


static func build_global_path(device: String, version: String, operation: String) -> String:
	return "/~%s@%s/%s" % [device, version, operation]


# ===== Validation =====

static func is_valid_address(address: String) -> bool:
	if address.length() < 40 or address.length() > 43:
		return false
	for c in address:
		if not (c >= 'A' and c <= 'Z') and not (c >= 'a' and c <= 'z') and not (c >= '0' and c <= '9') and c != '-' and c != '_':
			return false
	return true
