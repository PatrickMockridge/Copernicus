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
	""" % [", ".join(parts), first]


# ===== ANS-104 =====

static func create_data_item(owner: String, data: PackedByteArray, tags: Dictionary) -> Dictionary:
	"""Create a properly formatted ANS-104 data item."""
	return {
		"format": 1,
		"owner": _base64_encode(owner),
		"target": "",
		"anchor": "",
		"tags": _format_tags(tags),
		"data": data
	}


static func _base64_encode(data: Variant) -> PackedByteArray:
	"""Encode data to base64."""
	if data is PackedByteArray:
		return data
	elif data is String:
		return data.to_utf8_buffer()
	return PackedByteArray()


static func _format_tags(tags: Dictionary) -> Array:
	"""Format tags for ANS-104 data item."""
	var formatted: Array = []
	for k in tags:
		var name_bytes = k.to_utf8_buffer()
		var value_bytes = str(tags[k]).to_utf8_buffer()
		formatted.append({"name": name_bytes, "value": value_bytes})
	return formatted


static func encode_tags_for_ans104(tags: Dictionary) -> Array:
	"""Encode tags as ANS-104 compatible format."""
	var result: Array = []
	for k in tags:
		result.append({
			"name": k.to_utf8_buffer(),
			"value": str(tags[k]).to_utf8_buffer()
		})
	return result


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


static func is_valid_tx_id(tx_id: String) -> bool:
	"""Check if string is a valid Arweave transaction ID."""
	if tx_id.length() != 43:
		return false
	for c in tx_id:
		if not (c >= 'A' and c <= 'Z') and not (c >= 'a' and c <= 'z') and not (c >= '0' and c <= '9'):
			return false
	return true


static func is_valid_process_id(process_id: String) -> bool:
	"""Check if string is a valid AO process ID."""
	# AO process IDs are similar to Arweave TX IDs (base64url)
	return is_valid_tx_id(process_id)


# ===== URL Building =====

static func build_gateway_url(tx_id: String, gateway: String = "https://arweave.net") -> String:
	"""Build full gateway URL for a transaction."""
	return "%s/%s" % [gateway.rstrip("/"), tx_id]


static func build_arweave_url(tx_id: String) -> String:
	"""Build Arweave.net gateway URL."""
	return build_gateway_url(tx_id, "https://arweave.net")
