class_name RChainMarketplace
extends MarketplaceCore
## Thin shim: maps marketplace operations onto RChain coordination primitives.
## create_listing -> issue_capability + register_robot; purchase_listing -> transfer_capability.
## Asset blobs still upload to Arweave; only the TX id + metadata + authority live on RChain.

var _coordination: CoordinationCore = null


func initialize(config: Dictionary) -> bool:
	_coordination = config.get("coordination", null)
	return _coordination != null


static func _static_init():
	ModuleRegistry.register("marketplace", "RChainMarketplace", preload("res://scripts/marketplace/backends/rchain_marketplace.gd"))


static func get_module_name() -> String:
	return "RChain Marketplace"


static func get_module_description() -> String:
	return "Marketplace backed by RChain coordination (capability transfers)."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "A running RNode and an RChainCoordination backend."


static func get_module_category() -> String:
	return "marketplace"


func is_marketplace_connected() -> bool:
	return _coordination != null and _coordination.is_coordination_connected()


func get_my_address() -> String:
	return _coordination.get_my_address() if _coordination else ""


func create_listing(config: Dictionary) -> Listing:
	loading_started.emit()
	var name: String = config.get("name", "Unnamed")
	var record := _config_to_record(config)

	var issued := _coordination.issue_capability(name)
	if issued.is_err():
		error_occurred.emit(issued.get_error())
		loading_finished.emit()
		return null

	var registered := _coordination.register_robot(record)
	if registered.is_err():
		error_occurred.emit(registered.get_error())
		loading_finished.emit()
		return null

	var listing := _record_to_listing(name, record)
	loading_finished.emit()
	listing_created.emit(listing)
	return listing


func update_listing(listing_id: String, config: Dictionary) -> bool:
	# v1: re-register with the same name (upsert in registry.rho).
	var r := _coordination.register_robot(_config_to_record(config))
	return r.is_ok()


func cancel_listing(listing_id: String) -> bool:
	var r := _coordination.revoke_capability(listing_id)
	return r.is_ok()


func purchase_listing(listing_id: String) -> bool:
	loading_started.emit()
	var r := _coordination.transfer_capability(listing_id, get_my_address())
	if r.is_err():
		purchase_failed.emit(null, r.get_error())
		loading_finished.emit()
		return false
	loading_finished.emit()
	var listing := get_listing(listing_id)
	listing_purchased.emit(listing, get_my_address())
	return true


func load_listings(filter: Dictionary = {}) -> Array:
	loading_started.emit()
	var r := _coordination.list_robots()
	if r.is_err():
		error_occurred.emit(r.get_error())
		loading_finished.emit()
		return []
	var results: Array = []
	for record in r.get_data():
		var listing := _record_to_listing(str(record.get("name", "")), record)
		if _matches_filter(listing, filter):
			results.append(listing)
	loading_finished.emit()
	listings_loaded.emit(results)
	return results


func search_listings(query: String, filters: Dictionary = {}) -> Array:
	var all := load_listings(filters)
	var results: Array = []
	for listing in all:
		if listing.matches_search(query):
			results.append(listing)
	search_completed.emit(results)
	return results


func get_listings_by_owner(owner: String) -> Array:
	var results: Array = []
	for listing in load_listings():
		if listing.get_owner() == owner:
			results.append(listing)
	return results


func get_purchases_by_buyer(_buyer: String) -> Array:
	# v1: purchases are not tracked on-chain yet.
	return []


func get_listing(listing_id: String) -> Listing:
	var r := _coordination.get_robot(listing_id)
	if r.is_err():
		return null
	return _record_to_listing(listing_id, r.get_data())


func _config_to_record(config: Dictionary) -> Dictionary:
	return {
		"name": config.get("name", "Unnamed"),
		"asset_tx_id": config.get("asset_tx_id", ""),
		"metadata": {
			"description": config.get("description", ""),
			"asset_type": config.get("asset_type", "ROBOT"),
			"price": config.get("price", 0),
		},
		"creator": get_my_address(),
	}


func _record_to_listing(name: String, record: Dictionary) -> Listing:
	var listing := Listing.new()
	listing._id = name
	listing._name = name
	var meta: Dictionary = record.get("metadata", {})
	listing._description = str(meta.get("description", ""))
	listing._asset_type = MarketplaceCore.asset_type_from_string(str(meta.get("asset_type", "ROBOT")))
	listing._price = int(meta.get("price", 0))
	listing._creator = str(record.get("creator", ""))
	listing._owner = str(record.get("creator", ""))
	listing._created = 0
	listing._files = []
	listing._file_count = 0
	return listing


func _matches_filter(listing: Listing, filter: Dictionary) -> bool:
	if filter.has("asset_type"):
		if listing._asset_type != MarketplaceCore.asset_type_from_string(filter.get("asset_type")):
			return false
	if filter.has("min_price") and listing._price < filter.get("min_price"):
		return false
	if filter.has("max_price") and listing._price > filter.get("max_price"):
		return false
	return true
