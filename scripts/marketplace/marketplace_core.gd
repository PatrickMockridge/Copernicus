# marketplace_core.gd
# Abstract marketplace interface
# All marketplace backends must implement this

class_name MarketplaceCore
extends RefCounted

## Signals

signal listing_created(listing: Listing)
signal listing_updated(listing: Listing)
signal listing_purchased(listing: Listing, buyer: String)
signal purchase_failed(listing: Listing, reason: String)
signal listings_loaded(listings: Array)
signal search_completed(results: Array)
signal error_occurred(message: String)
signal loading_started()
signal loading_finished()


## ===== Core Methods =====

## Create a new listing
## config = {
##   "name": String,
##   "asset_type": "ROBOT" | "PART" | "WORLD",
##   "description": String,
##   "price": int (winston),
##   "files": Array of {name, path, size},
##   "preview_path": String (optional)
## }
func create_listing(config: Dictionary) -> Listing:
	push_error("MarketplaceCore.create_listing() must be implemented by subclass")
	return null


## Update an existing listing (owner only)
func update_listing(listing_id: String, config: Dictionary) -> bool:
	push_error("MarketplaceCore.update_listing() must be implemented by subclass")
	return false


## Cancel a listing (owner only)
func cancel_listing(listing_id: String) -> bool:
	push_error("MarketplaceCore.cancel_listing() must be implemented by subclass")
	return false


## Purchase a listing
## Returns true if purchase was initiated (check purchase_failed for errors)
func purchase_listing(listing_id: String) -> bool:
	push_error("MarketplaceCore.purchase_listing() must be implemented by subclass")
	return false


## Load all listings with optional filters
## filter = {
##   "asset_type": String (optional),
##   "min_price": int (optional),
##   "max_price": int (optional),
##   "state": String (optional)
## }
func load_listings(filter: Dictionary = {}) -> Array:
	push_error("MarketplaceCore.load_listings() must be implemented by subclass")
	return []


## Search listings by query
func search_listings(query: String, filters: Dictionary = {}) -> Array:
	push_error("MarketplaceCore.search_listings() must be implemented by subclass")
	return []


## Get listings by owner
func get_listings_by_owner(owner: String) -> Array:
	push_error("MarketplaceCore.get_listings_by_owner() must be implemented by subclass")
	return []


## Get listings purchased by address
func get_purchases_by_buyer(buyer: String) -> Array:
	push_error("MarketplaceCore.get_purchases_by_buyer() must be implemented by subclass")
	return []


## Get a single listing by ID
func get_listing(listing_id: String) -> Listing:
	push_error("MarketplaceCore.get_listing() must be implemented by subclass")
	return null


## Get the current user's wallet address
func get_my_address() -> String:
	push_error("MarketplaceCore.get_my_address() must be implemented by subclass")
	return ""


## Check if connected to marketplace backend
func is_connected() -> bool:
	return false


## ===== Configuration =====

func set_config(config: Dictionary) -> void:
	pass


func get_config() -> Dictionary:
	return {}


## ===== Static Helpers =====

static func get_marketplace_name() -> String:
	return "Unknown Marketplace"


static func get_marketplace_description() -> String:
	return ""


static func is_available() -> bool:
	return false


static func get_requirements() -> String:
	return ""


## ===== Price Formatting =====

static func format_price(winston: int) -> String:
	var ar = float(winston) / 1e12
	if ar < 0.001:
		return "%.0f winston" % winston
	elif ar < 1:
		return "%.3f AR" % ar
	else:
		return "%.2f AR" % ar


static func parse_price(ar_string: String) -> int:
	var ar = float(ar_string)
	return int(ar * 1e12)


## ===== Filter Helpers =====

static func create_filter(
	asset_type: String = "",
	min_price: int = 0,
	max_price: int = 0,
	state: String = ""
) -> Dictionary:
	var filter = {}
	if not asset_type.is_empty():
		filter["asset_type"] = asset_type
	if min_price > 0:
		filter["min_price"] = min_price
	if max_price > 0:
		filter["max_price"] = max_price
	if not state.is_empty():
		filter["state"] = state
	return filter


static func asset_type_from_string(type_str: String) -> int:
	match type_str.to_lower():
		"robot": return Listing.AssetType.ROBOT
		"part": return Listing.AssetType.PART
		"world": return Listing.AssetType.WORLD
	return Listing.AssetType.ROBOT


static func asset_type_to_string(asset_type: int) -> String:
	match asset_type:
		Listing.AssetType.ROBOT: return "Robot"
		Listing.AssetType.PART: return "Part"
		Listing.AssetType.WORLD: return "World"
	return "Unknown"
