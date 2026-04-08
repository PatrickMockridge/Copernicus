# publish_panel.gd
# UI panel for publishing robots to blockchain
# Provides a simple UI to configure and publish robot designs as AO Hyperobjects

class_name PublishPanel
extends Control

signal publish_requested(config: Dictionary)
signal cancelled()

const RobotPublisher = preload("res://scripts/robot_publisher.gd")

# UI Elements
var _panel: PanelContainer
var _title_bar: HBoxContainer
var _content: VBoxContainer
var _footer: HBoxContainer

var _name_edit: LineEdit
var _desc_edit: TextEdit
var _price_spin: SpinBox
var _file_list: VBoxContainer
var _progress_bar: ProgressBar
var _progress_label: Label
var _status_label: Label
var _publish_btn: Button
var _cancel_btn: Button

# State
var _publisher: RobotPublisher
var _selected_files: Array = []
var _all_files: Array = []
var _is_publishing: bool = false


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Main panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.3, 0.3, 0.35, 1)
	panel_style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", panel_style)

	# Content container
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_content)

	# Title bar
	_title_bar = HBoxContainer.new()
	_title_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content.add_child(_title_bar)

	var title = Label.new()
	title.text = "Publish Robot to Blockchain"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_bar.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_on_cancel_pressed)
	_title_bar.add_child(close_btn)

	# Separator
	var sep1 = HSeparator.new()
	_content.add_child(sep1)

	# Name field
	var name_hbox = HBoxContainer.new()
	_content.add_child(name_hbox)

	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 80
	name_hbox.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "MyRobot"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(_name_edit)

	# Description field
	var desc_label = Label.new()
	desc_label.text = "Description:"
	_content.add_child(desc_label)

	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size.y = 80
	_desc_edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_desc_edit)

	# Price field
	var price_hbox = HBoxContainer.new()
	_content.add_child(price_hbox)

	var price_label = Label.new()
	price_label.text = "Price (AR):"
	price_label.custom_minimum_size.x = 80
	price_hbox.add_child(price_label)

	_price_spin = SpinBox.new()
	_price_spin.min_value = 0.0
	_price_spin.max_value = 10000.0
	_price_spin.step = 0.1
	_price_spin.value = 0.0
	_price_spin.prefix = ""
	_price_spin.suffix = " AR"
	_price_spin.custom_minimum_size.x = 120
	price_hbox.add_child(_price_spin)

	var price_hint = Label.new()
	price_hint.text = " (0 = not for sale)"
	price_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	price_hbox.add_child(price_hint)
	price_hbox.add_child(Box.new())  # Spacer

	# Files section
	var files_header = HBoxContainer.new()
	_content.add_child(files_header)

	var files_label = Label.new()
	files_label.text = "Files to Publish:"
	files_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files_header.add_child(files_label)

	var select_all_btn = Button.new()
	select_all_btn.text = "Select All"
	select_all_btn.pressed.connect(_on_select_all_pressed)
	files_header.add_child(select_all_btn)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_on_refresh_pressed)
	files_header.add_child(refresh_btn)

	# File list scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	_file_list = VBoxContainer.new()
	_file_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_file_list)

	# Summary
	var summary_hbox = HBoxContainer.new()
	_content.add_child(summary_hbox)

	_status_label = Label.new()
	_status_label.text = "0 files selected"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	summary_hbox.add_child(_status_label)

	summary_hbox.add_child(Box.new())  # Spacer

	var cost_label = Label.new()
	cost_label.text = "Est. cost: ~0 AR"
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	summary_hbox.add_child(cost_label)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 20
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.visible = false
	_content.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.text = ""
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.visible = false
	_content.add_child(_progress_label)

	# Footer buttons
	_footer = HBoxContainer.new()
	_footer.alignment = Box.ALIGNMENT_END
	_footer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content.add_child(_footer)

	_footer.add_child(Box.new())  # Spacer

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_footer.add_child(_cancel_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10
	_footer.add_child(spacer)

	_publish_btn = Button.new()
	_publish_btn.text = "Publish"
	_publish_btn.pressed.connect(_on_publish_pressed)
	_footer.add_child(_publish_btn)


func _populate_file_list() -> void:
	# Clear existing
	for child in _file_list.get_children():
		child.queue_free()

	_all_files = _discover_robot_files()

	for file_path in _all_files:
		var check_box = CheckBox.new()
		check_box.text = _get_display_path(file_path)
		check_box.toggled.connect(_on_file_toggled.bind(file_path))

		var file_info = RobotPublisher.get_file_info(file_path)
		if file_info.get("exists"):
			var size_kb = file_info.get("size", 0) / 1024.0
			check_box.text += " (%.1f KB)" % size_kb

		# Default to selected
		check_box.set_pressed_no_signal(true)
		_selected_files.append(file_path)

		_file_list.add_child(check_box)

	_update_summary()


func _discover_robot_files() -> Array:
	var files: Array = []

	# Common robot file locations
	var search_paths = [
		"res://scripts/",
		"res://scenes/",
		"res://meshes/",
		"res://urdf/"
	]

	# File extensions to include
	var extensions = ["gd", "tscn", "tres", "urdf", "glb", "gltf", "obj", "stl", "vrm"]

	for search_path in search_paths:
		files.append_array(_scan_directory(search_path, extensions))

	return files


func _scan_directory(dir_path: String, extensions: Array) -> Array:
	var files: Array = []

	if not DirAccess.dir_exists_absolute(dir_path):
		return files

	var dir = DirAccess.open(dir_path)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while not file_name.is_empty():
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				files.append_array(_scan_directory(dir_path + "/" + file_name, extensions))
		else:
			var ext = file_name.get_extension().to_lower()
			if extensions.has(ext):
				files.append(dir_path + "/" + file_name)

		file_name = dir.get_next()

	dir.list_dir_end()
	return files


func _get_display_path(path: String) -> String:
	if path.begins_with("res://"):
		return path.substr(6)
	return path.get_file()


func _update_summary() -> void:
	var total_size = 0
	for path in _selected_files:
		var info = RobotPublisher.get_file_info(path)
		if info.get("exists"):
			total_size += info.get("size", 0)

	var size_str = "%.1f KB" % (total_size / 1024.0) if total_size < 1024 * 1024 else "%.1f MB" % (total_size / (1024.0 * 1024.0))
	_status_label.text = "%d files selected (%s)" % [_selected_files.size(), size_str]

	var est_cost = RobotPublisher.estimate_cost(_selected_files)
	# Update cost label if we can find it


func _on_file_toggled(toggled: bool, file_path: String) -> void:
	if toggled:
		if not _selected_files.has(file_path):
			_selected_files.append(file_path)
	else:
		_selected_files.erase(file_path)
	_update_summary()


func _on_select_all_pressed() -> void:
	for child in _file_list.get_children():
		if child is CheckBox:
			child.set_pressed_no_signal(true)
	_selected_files = _all_files.duplicate()
	_update_summary()


func _on_refresh_pressed() -> void:
	_selected_files.clear()
	_populate_file_list()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_publish_pressed() -> void:
	if _is_publishing:
		return

	if _selected_files.is_empty():
		_status_label.text = "Please select at least one file!"
		return

	if _name_edit.text.is_empty():
		_status_label.text = "Please enter a robot name!"
		return

	var config = {
		"name": _name_edit.text,
		"description": _desc_edit.text,
		"price": _price_spin.value,
		"files": _selected_files.duplicate()
	}

	_start_publish(config)


func _start_publish(config: Dictionary) -> void:
	_is_publishing = true
	_publish_btn.disabled = true
	_cancel_btn.disabled = true
	_progress_bar.visible = true
	_progress_label.visible = true
	_status_label.text = "Starting publish..."

	_publisher = RobotPublisher.new()
	_publisher.publish_progress.connect(_on_publish_progress)
	_publisher.publish_complete.connect(_on_publish_complete)
	_publisher.publish_failed.connect(_on_publish_failed)

	add_child(_publisher)
	_publisher.publish(config)


func _on_publish_progress(stage: String, percent: float) -> void:
	_progress_bar.value = percent
	_progress_label.text = stage
	_status_label.text = stage


func _on_publish_complete(hyperobject: RobotHyperobject) -> void:
	_is_publishing = false
	_progress_bar.value = 100.0
	_progress_label.text = "Complete!"

	var hyperobject_info = hyperobject.to_tradeable_dict()
	_status_label.text = "Published! Repo ID: %s" % hyperobject.get_repo_id()

	await get_tree().create_timer(2.0).timeout
	cancelled.emit()
	queue_free()


func _on_publish_failed(error: String) -> void:
	_is_publishing = false
	_publish_btn.disabled = false
	_cancel_btn.disabled = false
	_progress_bar.visible = false
	_progress_label.visible = false
	_status_label.text = "Failed: " + error


## ===== Static Helpers =====

static func show_for_robot(robot_name: String = "") -> PublishPanel:
	var panel = PublishPanel.new()
	panel._name_edit.text = robot_name
	panel._populate_file_list()

	var viewport = Engine.get_main_loop().root
	viewport.add_child(panel)

	return panel
