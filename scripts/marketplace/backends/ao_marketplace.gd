# ao_marketplace.gd
# AO Hyperobject marketplace backend
# Real decentralized marketplace using AO processes and Arweave storage

class_name AOMarketplace
extends MarketplaceCore

## AO SDK
var _ao: AOSDK

## Cached listings
var _listings_cache: Array = []
var _cache_loaded: bool = false

## Wallet
var _wallet = null

## Process tag for marketplace listings
const LISTING_PROCESS_TAG = "marketplace-listing-v1"


func _init():
	pass


func initialize(config: Dictionary) -> bool:
	# Get AO SDK from autoload or config
	_ao = config.get("ao", null)

	# Get wallet
	_wallet = config.get("wallet", null)
	if _ao and not _wallet:
		_wallet = _ao.get_wallet()

	return _ao != null


static func get_module_name() -> String:
	return "AO Marketplace"


static func get_module_description() -> String:
	return "Decentralized marketplace via AO Hyperobjects and Arweave"


static func is_available() -> bool:
	# Check if AO SDK is available
	var output = []; var result = OS.execute("node", ["--version"], output, true)
	return result == 0


static func get_requirements() -> String:
	return "AO SDK, Arweave wallet with AR tokens, Node.js for CLI bridge"


static func get_module_category() -> String:
	return "marketplace"

static func _static_init():
	ModuleRegistry.register("marketplace", "AOMarketplace", preload("res://scripts/marketplace/backends/ao_marketplace.gd"))

func is_marketplace_connected() -> bool:
	return _ao != null and _wallet != null


func get_my_address() -> String:
	if _wallet:
		return _wallet.get_address()
	return ""


## ===== Core Methods =====

func create_listing(config: Dictionary) -> Listing:
	if not is_marketplace_connected():
		error_occurred.emit("Not connected to AO network")
		return null

	loading_started.emit()

	var name = config.get("name", "Unnamed")
	var asset_type_str = config.get("asset_type", "Robot")
	var description = config.get("description", "")
	var price = config.get("price", 0)  # in winston
	var files = config.get("files", [])
	var preview_data = config.get("preview_data", PackedByteArray())

	# Upload files to Arweave
	var upload_result = _upload_listing_files(files)
	if upload_result.is_err():
		loading_finished.emit()
		error_occurred.emit("Failed to upload files: " + str(upload_result.get_err()))
		return null

	var upload_info = upload_result.get_data()

	# Upload preview image
	var preview_tx_id = ""
	if not preview_data.is_empty():
		var preview_result = _ao.upload_data(preview_data, {"Content-Type": "image/png"})
		if preview_result.is_ok():
			preview_tx_id = preview_result.get_data().get("tx_id", "")

	# Create AO process for the listing
	var initial_state = {
		"type": "LISTING",
		"asset_type": asset_type_str,
		"name": name,
		"description": description,
		"price": price,
		"owner": get_my_address(),
		"creator": get_my_address(),
		"files": upload_info.get("files", []),
		"manifest_tx_id": upload_info.get("manifest_tx_id", ""),
		"preview_tx_id": preview_tx_id,
		"created": Time.get_unix_time_from_system(),
		"state": "ACTIVE"
	}

	var spawn_result = _ao.spawn_process(LISTING_PROCESS_TAG, PackedByteArray(), initial_state)
	if spawn_result.is_err():
		loading_finished.emit()
		error_occurred.emit("Failed to create listing: " + str(spawn_result.get_err()))
		return null

	var process_info = spawn_result.get_data()
	var listing_id = process_info.get("process_id", "")

	# Create listing object
	var listing = Listing.new()
	listing._id = listing_id
	listing._name = name
	listing._asset_type = MarketplaceCore.asset_type_from_string(asset_type_str)
	listing._description = description
	listing._price = price
	listing._owner = get_my_address()
	listing._creator = get_my_address()
	listing._files = upload_info.get("files", [])
	listing._file_count = listing._files.size()
	listing._preview_tx_id = preview_tx_id
	listing._manifest_tx_id = upload_info.get("manifest_tx_id", "")
	listing._created = Time.get_unix_time_from_system()

	loading_finished.emit()
	listing_created.emit(listing)
	return listing


func _upload_listing_files(files: Array) -> Result:
	if files.is_empty():
		return Result.ok({"files": [], "manifest_tx_id": ""})

	var uploaded_files: Array = []
	var manifest_tx_id = ""

	for file_info in files:
		var file_path = file_info if file_info is String else file_info.get("path", "")
		var file_name = file_path.get_file() if not file_path.is_empty() else "unknown"

		if not FileAccess.file_exists(file_path):
			continue

		var file_data = FileAccess.get_file_as_bytes(file_path)
		if file_data.is_empty():
			continue

		# Determine content type
		var ext = file_path.get_extension().to_lower()
		var content_type = FileUtils.get_content_type(ext)

		# Upload to Arweave
		var tags = {
			"Content-Type": content_type,
			"File-Name": file_name,
			"File-Path": file_path,
			"App-Name": "Copernicus-Marketplace"
		}

		var upload_result = _ao.upload_data(file_data, tags)
		if upload_result.is_ok():
			var info = upload_result.get_data()
			var tx_id = info.get("tx_id", "")
			uploaded_files.append({"name": file_name, "path": file_path, "tx_id": tx_id})

			if manifest_tx_id.is_empty():
				manifest_tx_id = tx_id

	if uploaded_files.is_empty():
		return Result.err("No files uploaded successfully")

	return Result.ok({
		"files": uploaded_files,
		"manifest_tx_id": manifest_tx_id
	})
func update_listing(listing_id: String, config: Dictionary) -> bool:
	if not is_marketplace_connected():
		return false

	var listing = get_listing(listing_id)
	if not listing or listing._owner != get_my_address():
		return false

	# Build update message
	var update_data = {}
	if config.has("name"):
		update_data["name"] = config.get("name")
	if config.has("description"):
		update_data["description"] = config.get("description")
	if config.has("price"):
		update_data["price"] = config.get("price")
	update_data["action"] = "update"
	update_data["timestamp"] = Time.get_unix_time_from_system()

	var result = _ao.schedule_message(listing_id, update_data)
	if result.is_ok():
		listing_updated.emit(listing)
		return true

	return false


func cancel_listing(listing_id: String) -> bool:
	if not is_marketplace_connected():
		return false

	var listing = get_listing(listing_id)
	if not listing or listing._owner != get_my_address():
		return false

	var update_data = {
		"action": "cancel",
		"timestamp": Time.get_unix_time_from_system()
	}

	var result = _ao.schedule_message(listing_id, update_data)
	if result.is_ok():
		listing._state = Listing.State.CANCELLED
		listing_updated.emit(listing)
		return true

	return false


func purchase_listing(listing_id: String) -> bool:
	if not is_marketplace_connected():
		purchase_failed.emit(null, "Not connected")
		return false

	loading_started.emit()

	var listing = get_listing(listing_id)
	if not listing:
		loading_finished.emit()
		purchase_failed.emit(null, "Listing not found")
		return false

	if not listing.is_for_sale():
		loading_finished.emit()
		purchase_failed.emit(listing, "Listing not for sale")
		return false

	if listing._owner == get_my_address():
		loading_finished.emit()
		purchase_failed.emit(listing, "Cannot purchase your own listing")
		return false

	# Check balance
	var balance_result = _check_balance()
	if balance_result.is_err():
		loading_finished.emit()
		purchase_failed.emit(listing, "Failed to check balance: " + str(balance_result.get_err()))
		return false

	var balance = balance_result.get_data()
	if balance < listing._price:
		loading_finished.emit()
		purchase_failed.emit(listing, "Insufficient balance")
		return false

	# Send purchase message
	var purchase_data = {
		"action": "purchase",
		"buyer": get_my_address(),
		"price": listing._price,
		"timestamp": Time.get_unix_time_from_system()
	}

	var result = _ao.schedule_message(listing_id, purchase_data)
	if result.is_ok():
		# Update local listing state
		listing._owner = get_my_address()
		listing._purchased_by = get_my_address()
		listing._purchased_at = Time.get_unix_time_from_system()
		listing._state = Listing.State.SOLD

		loading_finished.emit()
		listing_purchased.emit(listing, get_my_address())
		return true

	loading_finished.emit()
	purchase_failed.emit(listing, "Purchase failed")
	return false


func _check_balance() -> Result:
	# In a real implementation, this would query the wallet or an indexer
	# For now, return a mock success
	return Result.ok(10000000000000)  # 10000 AR in winston


func load_listings(filter: Dictionary = {}) -> Array:
	if not is_marketplace_connected():
		error_occurred.emit("Not connected to AO network")
		return []

	loading_started.emit()
	_cache_loaded = false
	_listings_cache.clear()

	# In a full implementation, we would:
	# 1. Query AO for all processes with the marketplace tag
	# 2. Filter by state = ACTIVE
	# 3. Apply additional filters

	# For now, emit empty (would need GraphQL query to MU)
	var empty: Array = []
	loading_finished.emit()
	listings_loaded.emit(empty)
	return empty


func search_listings(query: String, filters: Dictionary = {}) -> Array:
	if not is_marketplace_connected():
		return []

	loading_started.emit()

	# Load all and filter locally (not efficient but works for MVP)
	var all_listings = load_listings(filters)
	var results: Array = []

	for listing in all_listings:
		if listing.matches_search(query):
			results.append(listing)

	loading_finished.emit()
	search_completed.emit(results)
	return results


func get_listings_by_owner(owner: String) -> Array:
	# Query for listings by owner (would use GraphQL in full impl)
	return []


func get_purchases_by_buyer(buyer: String) -> Array:
	# Query for purchases by buyer (would use GraphQL in full impl)
	return []


func get_listing(listing_id: String) -> Listing:
	if not is_marketplace_connected():
		return null

	# Query AO process for listing state
	var result = _ao.get_process_state(listing_id)
	if result.is_err():
		return null

	var state = result.get_data()
	if not state.has("type") or state.get("type") != "LISTING":
		return null

	var listing = Listing.new()
	listing._id = listing_id
	listing._name = state.get("name", "Unknown")
	listing._description = state.get("description", "")
	listing._price = state.get("price", 0)
	listing._owner = state.get("owner", "")
	listing._creator = state.get("creator", "")
	listing._asset_type = MarketplaceCore.asset_type_from_string(state.get("asset_type", "Robot"))
	listing._files = state.get("files", [])
	listing._file_count = listing._files.size()
	listing._preview_tx_id = state.get("preview_tx_id", "")
	listing._manifest_tx_id = state.get("manifest_tx_id", "")
	listing._created = state.get("created", 0)

	var state_str = state.get("state", "ACTIVE")
	if state_str == "SOLD":
		listing._state = Listing.State.SOLD
	elif state_str == "CANCELLED":
		listing._state = Listing.State.CANCELLED
	else:
		listing._state = Listing.State.ACTIVE

	return listing


func get_my_listings() -> Array:
	return get_listings_by_owner(get_my_address())
