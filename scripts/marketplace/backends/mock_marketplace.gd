# mock_marketplace.gd
# Mock marketplace backend for testing
# Simulates marketplace operations without real blockchain

class_name MockMarketplace
extends MarketplaceCore

## Mock data storage
var _listings: Array = []
var _purchases: Dictionary = {}  # buyer -> [listing_ids]
var _my_address: String = "mock_wallet_abc123"
var _next_id: int = 1


func _init():
	_create_sample_listings()


func _create_sample_listings():
	# Create some sample listings for testing
	var samples = [
		{
			"name": "TurtleBot Classic",
			"asset_type": "ROBOT",
			"description": "Classic differential drive robot with LIDAR. Perfect for indoor navigation research.",
			"price": 500000000000,  # 0.5 AR
			"creator": "copernicus_team",
			"preview_url": ""
		},
		{
			"name": "Robotic Arm 6-DOF",
			"asset_type": "ROBOT",
			"description": "6 degrees of freedom robotic arm. Great for pick-and-place tasks.",
			"price": 1200000000000,  # 1.2 AR
			"creator": "robotics_lab",
			"preview_url": ""
		},
		{
			"name": "AGV Wheel Module",
			"asset_type": "PART",
			"description": "Omni-directional wheel module. 75mm diameter, compatible with standard servos.",
			"price": 150000000000,  # 0.15 AR
			"creator": "parts_guild",
			"preview_url": ""
		},
		{
			"name": "RGB-D Camera Rig",
			"asset_type": "PART",
			"description": "Intel RealSense D435i camera mount. Includes calibration target.",
			"price": 80000000000,  # 0.08 AR
			"creator": "sensor_world",
			"preview_url": ""
		},
		{
			"name": "Warehouse Environment",
			"asset_type": "WORLD",
			"description": "Complete warehouse scene with shelving, pallets, and path networks. 20m x 15m.",
			"price": 2000000000000,  # 2 AR
			"creator": "env_studio",
			"preview_url": ""
		},
		{
			"name": "Lab Environment",
			"asset_type": "WORLD",
			"description": "Research lab environment with workbenches, storage, and robot charging stations.",
			"price": 1500000000000,  # 1.5 AR
			"creator": "env_studio",
			"preview_url": ""
		},
		{
			"name": " quadruped Robot",
			"asset_type": "ROBOT",
			"description": "4-legged robot with compliant joints. Uses inverse kinematics for natural movement.",
			"price": 3000000000000,  # 3 AR
			"creator": "quad_legged",
			"preview_url": ""
		},
		{
			"name": "Gripper Attachment",
			"asset_type": "PART",
			"description": "2-finger parallel gripper. 50mm stroke, self-centering. URDF included.",
			"price": 100000000000,  # 0.1 AR
			"creator": "end_effector_co",
			"preview_url": ""
		}
	]

	for sample in samples:
		var listing = _create_mock_listing(sample)
		_listings.append(listing)


func _create_mock_listing(data: Dictionary) -> Listing:
	var listing = Listing.new()
	listing._id = "mock_listing_%d" % _next_id
	_next_id += 1
	listing._name = data.get("name", "Unnamed")
	listing._asset_type = MarketplaceCore.asset_type_from_string(data.get("asset_type", "Robot"))
	listing._description = data.get("description", "")
	listing._price = data.get("price", 0)
	listing._creator = data.get("creator", "")
	listing._owner = listing._creator
	listing._created = Time.get_unix_time_from_system() - randi() % 86400 * 7  # Within last week
	listing._files = []
	listing._file_count = 0
	return listing


func get_marketplace_name() -> String:
	return "Mock Marketplace"


func get_marketplace_description() -> String:
	return "Testing marketplace with sample data. No real transactions."


func is_available() -> bool:
	return true


func get_requirements() -> String:
	return "None - mock marketplace for testing"


func is_connected() -> bool:
	return true


func get_my_address() -> String:
	return _my_address


## ===== Core Methods =====

func create_listing(config: Dictionary) -> Listing:
	loading_started.emit()

	var asset_type_str = config.get("asset_type", "Robot")
	var name = config.get("name", "Unnamed Listing")
	var price = config.get("price", 0)

	var listing = Listing.new()
	listing._id = "mock_listing_%d" % _next_id
	_next_id += 1
	listing._asset_type = MarketplaceCore.asset_type_from_string(asset_type_str)
	listing._name = name
	listing._description = config.get("description", "")
	listing._price = price
	listing._creator = _my_address
	listing._owner = _my_address
	listing._created = Time.get_unix_time_from_system()
	listing._files = config.get("files", [])
	listing._file_count = listing._files.size()

	_listings.append(listing)

	loading_finished.emit()
	listing_created.emit(listing)
	return listing


func update_listing(listing_id: String, config: Dictionary) -> bool:
	for listing in _listings:
		if listing._id == listing_id and listing._owner == _my_address:
			if config.has("name"):
				listing._name = config.get("name")
			if config.has("description"):
				listing._description = config.get("description")
			if config.has("price"):
				listing._price = config.get("price")
			listing._updated = Time.get_unix_time_from_system()
			listing_updated.emit(listing)
			return true
	return false


func cancel_listing(listing_id: String) -> bool:
	for listing in _listings:
		if listing._id == listing_id and listing._owner == _my_address:
			listing._state = Listing.State.CANCELLED
			listing._updated = Time.get_unix_time_from_system()
			listing_updated.emit(listing)
			return true
	return false


func purchase_listing(listing_id: String) -> bool:
	loading_started.emit()

	for listing in _listings:
		if listing._id == listing_id and listing.is_for_sale():
			if listing._owner == _my_address:
				loading_finished.emit()
				purchase_failed.emit(listing, "Cannot purchase your own listing")
				return false

			# Simulate purchase
			var old_owner = listing._owner
			listing._owner = _my_address
			listing._purchased_by = _my_address
			listing._purchased_at = Time.get_unix_time_from_system()
			listing._state = Listing.State.SOLD

			# Track purchase
			if not _purchases.has(_my_address):
				_purchases[_my_address] = []
			_purchases[_my_address].append(listing_id)

			loading_finished.emit()
			listing_purchased.emit(listing, _my_address)
			return true

	loading_finished.emit()
	purchase_failed.emit(null, "Listing not found or not for sale")
	return false


func load_listings(filter: Dictionary = {}) -> Array:
	loading_started.emit()

	var results: Array = []
	for listing in _listings:
		if listing._state == Listing.State.CANCELLED:
			continue

		# Apply filters
		if filter.has("asset_type"):
			var filter_type = MarketplaceCore.asset_type_from_string(filter.get("asset_type"))
			if listing._asset_type != filter_type:
				continue

		if filter.has("state"):
			var state_str = filter.get("state")
			if state_str == "Active" and listing._state != Listing.State.ACTIVE:
				continue
			if state_str == "Sold" and listing._state != Listing.State.SOLD:
				continue

		if filter.has("min_price") and listing._price < filter.get("min_price"):
			continue
		if filter.has("max_price") and listing._price > filter.get("max_price"):
			continue

		results.append(listing)

	loading_finished.emit()
	listings_loaded.emit(results)
	return results


func search_listings(query: String, filters: Dictionary = {}) -> Array:
	loading_started.emit()

	var results: Array = []
	for listing in _listings:
		if not listing.matches_search(query):
			continue

		# Apply filters
		if filters.has("asset_type"):
			var filter_type = MarketplaceCore.asset_type_from_string(filters.get("asset_type"))
			if listing._asset_type != filter_type:
				continue

		if filters.has("min_price") and listing._price < filters.get("min_price"):
			continue
		if filters.has("max_price") and listing._price > filters.get("max_price"):
			continue

		results.append(listing)

	loading_finished.emit()
	search_completed.emit(results)
	return results


func get_listings_by_owner(owner: String) -> Array:
	var results: Array = []
	for listing in _listings:
		if listing._owner == owner:
			results.append(listing)
	return results


func get_purchases_by_buyer(buyer: String) -> Array:
	var listing_ids = _purchases.get(buyer, [])
	var results: Array = []
	for lid in listing_ids:
		for listing in _listings:
			if listing._id == lid:
				results.append(listing)
				break
	return results


func get_listing(listing_id: String) -> Listing:
	for listing in _listings:
		if listing._id == listing_id:
			return listing
	return null


func get_my_listings() -> Array:
	return get_listings_by_owner(_my_address)
