# joint_panel.gd
# Interactive joint control panel
# Displays sliders for each joint in the robot model

class_name JointPanel
extends Control

signal joint_value_changed(joint_name: String, value: float)

var _viewer_path: NodePath
var _viewer: Node
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _layout: VBoxContainer
var _title: Label


func _ready() -> void:
	_layout = VBoxContainer.new()
	_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layout)

	_title = Label.new()
	_title.text = "Joint Control"
	_title.add_theme_font_size_override("font_size", 16)
	_layout.add_child(_title)

	var separator = HSeparator.new()
	_layout.add_child(separator)

	# Try to find robot viewer in scene
	var viewer = find_viewer()
	if viewer:
		set_viewer(viewer)


func find_viewer() -> Node:
	# Look for RobotViewer in parent or siblings
	var parent = get_parent()
	if parent:
		var viewer = parent.find_child("RobotViewer", false, false)
		if viewer:
			return viewer
		# Check parent's children
		for child in parent.get_children():
			if child.has_method("get_joint_count"):
				return child
	return null


func set_viewer(viewer: Node) -> void:
	_viewer = viewer
	if viewer and viewer.has_signal("robot_loaded"):
		viewer.robot_loaded.connect(_on_robot_loaded)
		# If robot already loaded, populate
		if viewer.has_method("get_robot_root") and viewer.get_robot_root():
			_populate_from_viewer()


func _on_robot_loaded(robot_node: Node) -> void:
	_clear_sliders()
	_populate_from_viewer()


func _populate_from_viewer() -> void:
	if not _viewer or not _layout:
		return

	if _viewer.has_method("get_joint_count"):
		var count = _viewer.get_joint_count()
		for i in range(count):
			var name = _viewer.get_joint_name(i)
			if not name.is_empty():
				_add_joint_slider(name, i)


func _add_joint_slider(joint_name: String, joint_index: int) -> void:
	var container = HBoxContainer.new()

	var label = Label.new()
	label.text = joint_name
	label.custom_minimum_size.x = 100
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	container.add_child(label)
	_labels[joint_name] = label

	var slider = HSlider.new()
	slider.custom_minimum_size.x = 150

	# Read joint limits from the viewer if available, URDF limits are in radians
	var limits = {"lower": -180.0, "upper": 180.0}
	var use_radians = false
	if _viewer and _viewer.has_method("get_joint_limits"):
		limits = _viewer.get_joint_limits(joint_index)
	if _viewer and _viewer.has_method("get_robot_root") and _viewer.get_robot_root():
		var root = _viewer.get_robot_root()
		if root and root.has_meta("urdf_loaded"):
			use_radians = true
	if use_radians:
		limits["lower"] = rad_to_deg(limits["lower"])
		limits["upper"] = rad_to_deg(limits["upper"])
	slider.min_value = limits["lower"]
	slider.max_value = limits["upper"]
	slider.step = 1.0
	slider.value = 0.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(joint_index, joint_name))
	container.add_child(slider)
	_sliders[joint_name] = slider

	var value_label = Label.new()
	value_label.text = "0°"
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(value_label)
	_labels[joint_name + "_value"] = value_label

	_layout.add_child(container)


func _on_slider_changed(value: float, joint_index: int, joint_name: String) -> void:
	_labels[joint_name + "_value"].text = "%.0f°" % value
	joint_value_changed.emit(joint_name, value)

	if _viewer and _viewer.has_method("set_joint_rotation"):
		_viewer.set_joint_rotation(joint_index, value)


func _clear_sliders() -> void:
	for slider in _sliders.values():
		if is_instance_valid(slider) and slider.get_parent():
			slider.get_parent().queue_free()
	_sliders.clear()
	_labels.clear()

	# Remove all children from layout except the title and separator
	for child in _layout.get_children():
		if child != _title and child.get_index() > 1:
			child.queue_free()
