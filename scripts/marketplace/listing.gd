# listing.gd
# Marketplace listing data structure
# Represents an asset listed for sale

class_name Listing
extends RefCounted

## Asset types
enum AssetType {
	ROBOT,
	PART,
	WORLD
}

## Listing state
enum State {
	ACTIVE,
	SOLD,
	CANCELLED
}

## Core fields
var _id: String = ""
var _asset_type: AssetType = AssetType.ROBOT
var _state: State = State.ACTIVE

## Metadata
var _name: String = ""
var _description: String = ""
var _creator: String = ""
var _owner: String = ""

## Pricing (in winston, 1 AR = 1e12 winston)
var _price: int = 0  # winston
var _sale_price: int = 0  # for secondary sales

## Files
var _files: Array = []  # [{name, tx_id, size}]
var _file_count: int = 0
var _total_size: int = 0

## Arweave
var _preview_tx_id: String = ""
var _manifest_tx_id: String = ""

## Timestamps
var _created: int = 0
var _updated: int = 0
var _purchased_at: int = 0

## Buyer (set when purchased)
var _purchased_by: String = ""


## ===== Factory =====

static func create_robot(name: String, creator: String, price: int, files: Array) -> Listing:
	var listing = Listing.new()
	listing._id = _generate_id()
	listing._asset_type = AssetType.ROBOT
	listing._name = name
	listing._creator = creator
	listing._owner = creator
	listing._price = price
	listing._files = files
	listing._file_count = files.size()
	listing._total_size = listing._compute_total_size()
	listing._created = Time.get_unix_time_from_system()
	return listing


static func create_part(name: String, creator: String, price: int, files: Array) -> Listing:
	var listing = Listing.new()
	listing._id = _generate_id()
	listing._asset_type = AssetType.PART
	listing._name = name
	listing._creator = creator
	listing._owner = creator
	listing._price = price
	listing._files = files
	listing._file_count = files.size()
	listing._total_size = listing._compute_total_size()
	listing._created = Time.get_unix_time_from_system()
	return listing


static func create_world(name: String, creator: String, price: int, files: Array) -> Listing:
	var listing = Listing.new()
	listing._id = _generate_id()
	listing._asset_type = AssetType.WORLD
	listing._name = name
	listing._creator = creator
	listing._owner = creator
	listing._price = price
	listing._files = files
	listing._file_count = files.size()
	listing._total_size = listing._compute_total_size()
	listing._created = Time.get_unix_time_from_system()
	return listing


static func _generate_id() -> String:
	# Generate a pseudo-random ID based on timestamp + random
	var timestamp = Time.get_unix_time_from_system()
	var random = randi()
	return "listing_%d_%d" % [timestamp, random]


## ===== Getters =====

func get_id() -> String:
	return _id


func get_asset_type() -> AssetType:
	return _asset_type


func get_asset_type_string() -> String:
	match _asset_type:
		AssetType.ROBOT: return "Robot"
		AssetType.PART: return "Part"
		AssetType.WORLD: return "World"
	return "Unknown"


func get_state() -> State:
	return _state


func get_state_string() -> String:
	match _state:
		State.ACTIVE: return "Active"
		State.SOLD: return "Sold"
		State.CANCELLED: return "Cancelled"
	return "Unknown"


func get_name() -> String:
	return _name


func get_description() -> String:
	return _description


func get_creator() -> String:
	return _creator


func get_owner() -> String:
	return _owner


func get_price() -> int:
	return _price


func get_price_ar() -> float:
	return float(_price) / 1e12


func get_sale_price() -> int:
	return _sale_price


func get_files() -> Array:
	return _files


func get_file_count() -> int:
	return _file_count


func _compute_total_size() -> int:
	var total := 0
	for file in _files:
		if file is Dictionary:
			total += int(file.get("size", 0))
	return total


func get_total_size() -> int:
	return _total_size


func get_preview_tx_id() -> String:
	return _preview_tx_id


func get_manifest_tx_id() -> String:
	return _manifest_tx_id


func get_created() -> int:
	return _created


func get_updated() -> int:
	return _updated


func get_purchased_at() -> int:
	return _purchased_at


func get_purchased_by() -> String:
	return _purchased_by


func is_for_sale() -> bool:
	return _state == State.ACTIVE and _price > 0


func is_owned_by(address: String) -> bool:
	return _owner == address


## ===== Setters =====

func set_description(desc: String) -> void:
	_description = desc
	_updated = Time.get_unix_time_from_system()


func set_price(price_winston: int) -> void:
	_price = price_winston
	_updated = Time.get_unix_time_from_system()


func set_preview_tx_id(tx_id: String) -> void:
	_preview_tx_id = tx_id


func set_manifest_tx_id(tx_id: String) -> void:
	_manifest_tx_id = tx_id


func set_state(state: State) -> void:
	_state = state
	_updated = Time.get_unix_time_from_system()


func set_owner(owner: String) -> void:
	_owner = owner
	_updated = Time.get_unix_time_from_system()


func set_purchased_by(buyer: String) -> void:
	_purchased_by = buyer
	_purchased_at = Time.get_unix_time_from_system()
	_state = State.SOLD


## ===== Serialization =====

func to_dictionary() -> Dictionary:
	return {
		"id": _id,
		"asset_type": get_asset_type_string(),
		"state": get_state_string(),
		"name": _name,
		"description": _description,
		"creator": _creator,
		"owner": _owner,
		"price": _price,
		"price_ar": get_price_ar(),
		"sale_price": _sale_price,
		"files": _files,
		"file_count": _file_count,
		"total_size": _total_size,
		"preview_tx_id": _preview_tx_id,
		"manifest_tx_id": _manifest_tx_id,
		"created": _created,
		"updated": _updated,
		"purchased_at": _purchased_at,
		"purchased_by": _purchased_by
	}


func to_tradeable_dict() -> Dictionary:
	return {
		"id": _id,
		"type": get_asset_type_string(),
		"name": _name,
		"description": _description,
		"owner": _owner,
		"creator": _creator,
		"price": _price,
		"is_for_sale": is_for_sale(),
		"file_count": _file_count,
		"total_size": _total_size,
		"preview_tx_id": _preview_tx_id
	}


static func from_dictionary(data: Dictionary) -> Listing:
	var listing = Listing.new()
	listing._id = data.get("id", "")
	listing._name = data.get("name", "")
	listing._description = data.get("description", "")
	listing._creator = data.get("creator", "")
	listing._owner = data.get("owner", "")
	listing._price = data.get("price", 0)
	listing._sale_price = data.get("sale_price", 0)
	listing._files = data.get("files", [])
	listing._file_count = data.get("file_count", 0)
	listing._total_size = data.get("total_size", 0)
	if listing._total_size == 0 and not listing._files.is_empty():
		listing._total_size = listing._compute_total_size()
	listing._preview_tx_id = data.get("preview_tx_id", "")
	listing._manifest_tx_id = data.get("manifest_tx_id", "")
	listing._created = data.get("created", 0)
	listing._updated = data.get("updated", 0)
	listing._purchased_at = data.get("purchased_at", 0)
	listing._purchased_by = data.get("purchased_by", "")

	var asset_type_str = data.get("asset_type", "Robot")
	match asset_type_str:
		"Robot": listing._asset_type = AssetType.ROBOT
		"Part": listing._asset_type = AssetType.PART
		"World": listing._asset_type = AssetType.WORLD

	var state_str = data.get("state", "Active")
	match state_str:
		"Active": listing._state = State.ACTIVE
		"Sold": listing._state = State.SOLD
		"Cancelled": listing._state = State.CANCELLED

	return listing


## ===== Queries =====

func matches_search(query: String) -> bool:
	if query.is_empty():
		return true
	var q = query.to_lower()
	return _name.to_lower().contains(q) or _description.to_lower().contains(q)


func price_in_range(min_price: int, max_price: int) -> bool:
	if min_price > 0 and _price < min_price:
		return false
	if max_price > 0 and _price > max_price:
		return false
	return true
