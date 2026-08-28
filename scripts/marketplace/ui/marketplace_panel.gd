# marketplace_panel.gd
# Main marketplace UI panel
# Browse, search, and manage asset listings

class_name MarketplacePanel
extends Control

signal listing_viewed(listing: Listing)
signal purchase_initiated(listing: Listing)
signal create_listing_requested()
signal closed()

const Listing = preload("res://scripts/marketplace/listing.gd")
const MarketplaceCore = preload("res://scripts/marketplace/marketplace_core.gd")
const MockMarketplace = preload("res://scripts/marketplace/backends/mock_marketplace.gd")

## Marketplace backend
var _marketplace: MarketplaceCore

## UI elements
var _tab_bar: HBoxContainer
var _search_bar: LineEdit
var _type_filter: OptionButton
var _sort_order: OptionButton
var _listings_container: GridContainer
var _status_label: Label
var _detail_panel: Control
var _create_panel: Control
var _scroll: ScrollContainer
var _loading_overlay: LoadingOverlay = null

## State
var _current_tab: int = 0
var _all_listings: Array = []
var _selected_listing: Listing = null

## Constants
const COLUMNS: int = 3


func _ready() -> void:
	_setup_marketplace()
	_setup_ui()


func _setup_marketplace() -> void:
	# Default to mock; the header "Backend" button opens the selector to switch.
	set_backend(MockMarketplace.new())


func set_backend(backend: MarketplaceCore) -> void:
	_marketplace = backend
	_marketplace.listings_loaded.connect(_on_listings_loaded)
	_marketplace.search_completed.connect(_on_search_completed)
	_marketplace.listing_purchased.connect(_on_listing_purchased)
	_marketplace.purchase_failed.connect(_on_purchase_failed)
	_marketplace.listing_created.connect(_on_listing_created)
	_marketplace.error_occurred.connect(_on_error)
	_marketplace.loading_started.connect(_on_loading_started)
	_marketplace.loading_finished.connect(_on_loading_finished)


func _setup_ui() -> void:
	# Main panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)

	# Header with title and close button
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(header)

	var title = Label.new()
	title.text = "Copernicus Marketplace"
	title.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var backend_btn = Button.new()
	backend_btn.text = "Backend"
	backend_btn.tooltip_text = "Select marketplace backend"
	backend_btn.pressed.connect(_on_backend_pressed)
	header.add_child(backend_btn)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Tab bar
	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(_tab_bar)

	var tabs = ["Browse", "My Listings", "Create", "Purchases"]
	for i in range(tabs.size()):
		var btn = Button.new()
		btn.text = tabs[i]
		btn.custom_minimum_size.x = 100
		btn.pressed.connect(_on_tab_selected.bind(i))
		_tab_bar.add_child(btn)

	# Search and filter bar
	var filter_bar = HBoxContainer.new()
	main_vbox.add_child(filter_bar)

	_search_bar = LineEdit.new()
	_search_bar.placeholder_text = "Search assets..."
	_search_bar.custom_minimum_size.x = 200
	_search_bar.text_submitted.connect(_on_search_submitted)
	filter_bar.add_child(_search_bar)

	var filter_lbl = Label.new()
	filter_lbl.text = "Type:"
	filter_bar.add_child(filter_lbl)

	_type_filter = OptionButton.new()
	_type_filter.add_item("All")
	_type_filter.add_item("Robots")
	_type_filter.add_item("Parts")
	_type_filter.add_item("Worlds")
	_type_filter.item_selected.connect(_on_filter_changed)
	filter_bar.add_child(_type_filter)

	var sort_lbl = Label.new()
	sort_lbl.text = "Sort:"
	filter_bar.add_child(sort_lbl)

	_sort_order = OptionButton.new()
	_sort_order.add_item("Newest")
	_sort_order.add_item("Cheapest")
	_sort_order.add_item("Most Expensive")
	_sort_order.add_item("Name A-Z")
	_sort_order.item_selected.connect(_on_filter_changed)
	filter_bar.add_child(_sort_order)

	var search_btn = Button.new()
	search_btn.text = "Search"
	search_btn.pressed.connect(_on_search_submitted.bind(""))
	filter_bar.add_child(search_btn)

	# Listings grid (scrollable)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 300
	_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	main_vbox.add_child(_scroll)

	_listings_container = GridContainer.new()
	_listings_container.custom_minimum_size.y = 300
	var columns = COLUMNS
	_listings_container.columns = columns
	_scroll.add_child(_listings_container)

	# Create panel (shown only on the Create tab)
	_create_panel = PanelContainer.new()
	_create_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_create_panel.visible = false
	CopernicusTheme.style_card(_create_panel)
	main_vbox.add_child(_create_panel)

	# Status label
	_status_label = Label.new()
	_status_label.text = "Loading..."
	_status_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	main_vbox.add_child(_status_label)

	# Load initial listings
	_refresh_listings()


func _refresh_listings() -> void:
	_set_status("Loading...", CopernicusTheme.TEXT_SECONDARY)
	var filter = _get_current_filter()
	_all_listings = _marketplace.load_listings(filter)


func _get_current_filter() -> Dictionary:
	var filter = {}

	# Type filter
	var type_idx = _type_filter.get_selected_id()
	if type_idx == 1:
		filter["asset_type"] = "ROBOT"
	elif type_idx == 2:
		filter["asset_type"] = "PART"
	elif type_idx == 3:
		filter["asset_type"] = "WORLD"

	return filter


func _on_tab_selected(tab_index: int) -> void:
	_current_tab = tab_index
	_clear_listings()
	_scroll.visible = true
	_create_panel.visible = false

	match tab_index:
		0:  # Browse
			_refresh_listings()
		1:  # My Listings
			var my_listings = _marketplace.get_my_listings()
			_display_listings(my_listings)
		2:  # Create
			_show_create_panel()
		3:  # Purchases
			var purchases = _marketplace.get_purchases_by_buyer(_marketplace.get_my_address())
			_display_listings(purchases)


func _on_search_submitted(text: String) -> void:
	var query = _search_bar.text.strip_edges()
	var filter = _get_current_filter()
	if query.is_empty():
		_all_listings = _marketplace.load_listings(filter)
	else:
		_all_listings = _marketplace.search_listings(query, filter)


func _on_filter_changed(index: int) -> void:
	_refresh_listings()


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _on_listings_loaded(listings: Array) -> void:
	_display_listings(_apply_sort(listings))
	_set_status("%d listings found" % listings.size(), CopernicusTheme.TEXT_SECONDARY)


func _on_search_completed(results: Array) -> void:
	_display_listings(_apply_sort(results))
	_set_status("%d results found" % results.size(), CopernicusTheme.TEXT_SECONDARY)


func _apply_sort(listings: Array) -> Array:
	var sorted := listings.duplicate()
	match _sort_order.get_selected_id():
		0:  # Newest
			sorted.sort_custom(func(a, b): return a._created > b._created)
		1:  # Cheapest
			sorted.sort_custom(func(a, b): return a._price < b._price)
		2:  # Most Expensive
			sorted.sort_custom(func(a, b): return a._price > b._price)
		3:  # Name A-Z
			sorted.sort_custom(func(a, b): return a._name.to_lower() < b._name.to_lower())
	return sorted


func _on_listing_purchased(listing: Listing, buyer: String) -> void:
	_set_status("Purchased: " + listing.get_name(), CopernicusTheme.SUCCESS)
	_refresh_listings()


func _on_purchase_failed(listing: Listing, reason: String) -> void:
	_set_status("Purchase failed: " + reason, CopernicusTheme.ERROR)


func _on_listing_created(listing: Listing) -> void:
	_set_status("Created listing: " + listing.get_name(), CopernicusTheme.SUCCESS)
	_refresh_listings()


func _on_error(message: String) -> void:
	_set_status("Error: " + message, CopernicusTheme.ERROR)


func _display_listings(listings: Array) -> void:
	_clear_listings()

	if listings.is_empty():
		_listings_container.add_child(CopernicusTheme.make_empty_state("No listings", "Try adjusting your search or filters."))
		return

	for listing in listings:
		var card = _create_listing_card(listing)
		_listings_container.add_child(card)


func _clear_listings() -> void:
	for child in _listings_container.get_children():
		child.queue_free()


func _create_listing_card(listing: Listing) -> Control:
	var container = PanelContainer.new()
	CopernicusTheme.style_card(container)

	var vbox = VBoxContainer.new()
	container.add_child(vbox)

	# Asset type indicator
	var preview = PanelContainer.new()
	preview.custom_minimum_size.y = 80
	var preview_style = StyleBoxFlat.new()
	var type_str = listing.get_asset_type_string()
	var type_colors = {
		"Robot": Color(0.15, 0.35, 0.6, 1),
		"Part": Color(0.2, 0.5, 0.2, 1),
		"World": Color(0.5, 0.3, 0.15, 1),
	}
	preview_style.bg_color = type_colors.get(type_str, CopernicusTheme.BG_CARD)
	preview_style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", preview_style)
	vbox.add_child(preview)
	
	var preview_lbl = Label.new()
	preview_lbl.text = type_str
	preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_lbl.add_theme_font_size_override("font_size", 18)
	preview_lbl.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	preview.add_child(preview_lbl)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = listing.get_name()
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	# Creator
	var creator_lbl = Label.new()
	creator_lbl.text = "by " + listing.get_creator()
	creator_lbl.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	creator_lbl.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	vbox.add_child(creator_lbl)

	# Price
	var price_lbl = Label.new()
	price_lbl.text = MarketplaceCore.format_price(listing.get_price())
	price_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	price_lbl.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	vbox.add_child(price_lbl)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	vbox.add_child(btn_hbox)

	var view_btn = Button.new()
	view_btn.text = "View"
	view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_btn.pressed.connect(_on_view_pressed.bind(listing))
	btn_hbox.add_child(view_btn)

	var buy_btn = Button.new()
	buy_btn.text = "Buy"
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.pressed.connect(_on_buy_pressed.bind(listing))
	if not listing.is_for_sale() or listing.get_owner() == _marketplace.get_my_address():
		buy_btn.disabled = true
		buy_btn.tooltip_text = "You own this" if listing.get_owner() == _marketplace.get_my_address() else "Not for sale"
	btn_hbox.add_child(buy_btn)

	container.set_meta("listing", listing)
	return container


func _on_view_pressed(listing: Listing) -> void:
	_selected_listing = listing
	_show_detail_panel(listing)


func _on_buy_pressed(listing: Listing) -> void:
	purchase_initiated.emit(listing)
	var dialog = ConfirmDialog.ask(self, "Confirm Purchase", "Buy \"" + listing.get_name() + "\" for " + MarketplaceCore.format_price(listing.get_price()) + "?", "Buy", "Cancel")
	dialog.confirmed.connect(func() -> void: _marketplace.purchase_listing(listing.get_id()))


func _show_detail_panel(listing: Listing) -> void:
	if _detail_panel:
		_detail_panel.queue_free()

	_detail_panel = Control.new()
	_detail_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_detail_panel)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	_detail_panel.add_child(panel)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(380, 10)
	close_btn.pressed.connect(_detail_panel.queue_free)
	panel.add_child(close_btn)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = listing.get_name()
	title_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_lbl)

	var type_lbl = Label.new()
	type_lbl.text = listing.get_asset_type_string()
	type_lbl.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	vbox.add_child(type_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = listing.get_description()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var price_lbl = Label.new()
	price_lbl.text = "Price: " + MarketplaceCore.format_price(listing.get_price())
	price_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(price_lbl)

	var buy_btn = Button.new()
	buy_btn.text = "Purchase"
	buy_btn.pressed.connect(_on_buy_pressed.bind(listing))
	buy_btn.disabled = not listing.is_for_sale()
	vbox.add_child(buy_btn)


func _show_create_panel() -> void:
	_scroll.visible = false
	_create_panel.visible = true

	for child in _create_panel.get_children():
		child.queue_free()

	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	_create_panel.add_child(form)

	var title = Label.new()
	title.text = "Create New Listing"
	title.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_HEADING)
	title.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	form.add_child(title)

	# Name field
	var name_label = Label.new()
	name_label.text = "Asset Name"
	name_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	form.add_child(name_label)
	var name_input = LineEdit.new()
	name_input.placeholder_text = "e.g., Robot Arm v2"
	form.add_child(name_input)

	# Description
	var desc_label = Label.new()
	desc_label.text = "Description"
	desc_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	form.add_child(desc_label)
	var desc_input = TextEdit.new()
	desc_input.custom_minimum_size.y = 80
	desc_input.placeholder_text = "Describe your asset..."
	form.add_child(desc_input)

	# Price
	var price_label = Label.new()
	price_label.text = "Price (AR)"
	price_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	form.add_child(price_label)
	var price_input = SpinBox.new()
	price_input.min_value = 0.0
	price_input.max_value = 1000000.0
	price_input.step = 0.1
	form.add_child(price_input)

	var publish_btn = Button.new()
	publish_btn.text = "Publish Listing"
	publish_btn.pressed.connect(func():
		var asset_name = name_input.text.strip_edges()
		if asset_name.is_empty():
			Toast.show_toast(self, "Please enter an asset name", Toast.Level.WARNING)
			return
		var config = {
			"name": asset_name,
			"asset_type": "ROBOT",
			"description": desc_input.text,
			"price": int(price_input.value * 1e12),
			"files": []
		}
		var listing = _marketplace.create_listing(config)
		if listing:
			Toast.show_toast(self, "Listing created", Toast.Level.SUCCESS)
		_on_tab_selected(0)
	)
	form.add_child(publish_btn)


func _on_loading_started() -> void:
	if _loading_overlay == null:
		_loading_overlay = LoadingOverlay.show_overlay(self, "Loading...")


func _on_loading_finished() -> void:
	if _loading_overlay:
		_loading_overlay.dismiss()
		_loading_overlay = null


func _on_close_pressed() -> void:
	closed.emit()
	hide()


func _on_backend_pressed() -> void:
	var selector = preload("res://scenes/marketplace/marketplace_selector.tscn").instantiate()
	selector.backend_selected.connect(_on_backend_selected)
	add_child(selector)


func _on_backend_selected(backend_id: String) -> void:
	var backend = MarketplaceSelector.create_backend(backend_id, {})
	if backend:
		set_backend(backend)
		_refresh_listings()
