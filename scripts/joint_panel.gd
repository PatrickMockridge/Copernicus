# joint_panel.gd
# Interactive joint control panel — grouped per-joint sliders with limits.

class_name JointPanel
extends Control

signal joint_value_changed(joint_name: String, value: float)

var _viewer: Node
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _layout: VBoxContainer
var _slider_scroll: ScrollContainer
var _slider_list: VBoxContainer
var _empty_state: Control


func _ready() -> void:
	_layout = VBoxContainer.new()
	_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", CopernicusTheme.SPACE_S)
	add_child(_layout)

	var header := HBoxContainer.new()
	_layout.add_child(header)
	var title := CopernicusTheme.make_heading("Joint Control")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var zero_all := CopernicusTheme.make_secondary_button("Zero All")
	zero_all.pressed.connect(_on_zero_all)
	header.add_child(zero_all)

	_layout.add_child(CopernicusTheme.make_separator())

	_slider_scroll = ScrollContainer.new()
	_slider_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slider_scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	_layout.add_child(_slider_scroll)

	_slider_list = VBoxContainer.new()
	_slider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_list.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	_slider_scroll.add_child(_slider_list)

	_empty_state = CopernicusTheme.make_empty_state("No robot loaded", "Load a robot to control its joints.")
	_slider_list.add_child(_empty_state)

	var viewer = find_viewer()
	if viewer:
		set_viewer(viewer)


func find_viewer() -> Node:
	var parent = get_parent()
	if parent:
		var viewer = parent.find_child("RobotViewer", false, false)
		if viewer:
			return viewer
		for child in parent.get_children():
			if child.has_method("get_joint_count"):
				return child
	return null


func set_viewer(viewer: Node) -> void:
	_viewer = viewer
	if viewer and viewer.has_signal("robot_loaded"):
		viewer.robot_loaded.connect(_on_robot_loaded)
		if viewer.has_method("get_robot_root") and viewer.get_robot_root():
			_populate_from_viewer()


func _on_robot_loaded(_robot_node: Node) -> void:
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
	_empty_state.visible = _sliders.is_empty()


func _add_joint_slider(joint_name: String, joint_index: int) -> void:
	var card := PanelContainer.new()
	CopernicusTheme.style_card(card)
	_slider_list.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	card.add_child(v)

	# Header: name + type + zero.
	var header := HBoxContainer.new()
	v.add_child(header)
	var name_label := Label.new()
	name_label.text = joint_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	header.add_child(name_label)

	var type: String = _viewer.get_joint_type(joint_index) if _viewer.has_method("get_joint_type") else "revolute"
	var type_label := Label.new()
	type_label.text = type
	type_label.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	type_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_DISABLED)
	header.add_child(type_label)

	var zero := Button.new()
	zero.text = "0"
	zero.flat = true
	zero.tooltip_text = "Zero this joint"
	zero.pressed.connect(func() -> void: _set_joint(joint_index, 0.0))
	header.add_child(zero)

	# Slider row: min / slider / value.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	v.add_child(row)

	var limits := {"lower": -180.0, "upper": 180.0}
	if _viewer and _viewer.has_method("get_joint_limits"):
		limits = _viewer.get_joint_limits(joint_index)
	var lower: float = limits["lower"]
	var upper: float = limits["upper"]

	var min_label := Label.new()
	min_label.text = _fmt(lower)
	min_label.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	min_label.add_theme_color_override("font_color", CopernicusTheme.TEXT_DISABLED)
	row.add_child(min_label)

	var slider := HSlider.new()
	slider.min_value = lower
	slider.max_value = upper
	slider.step = _derive_step(lower, upper)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var initial_value := 0.0
	if _viewer and _viewer.has_method("get_joint_rotation"):
		initial_value = _viewer.get_joint_rotation(joint_index)
	slider.value = initial_value
	slider.value_changed.connect(_on_slider_changed.bind(joint_index, joint_name))
	row.add_child(slider)
	_sliders[joint_name] = slider

	var value_label := Label.new()
	value_label.text = _fmt(initial_value)
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", CopernicusTheme.ACCENT)
	row.add_child(value_label)
	_value_labels[joint_name] = value_label


func _derive_step(lower: float, upper: float) -> float:
	var span := upper - lower
	if span <= 0.0:
		return 0.1
	return maxf(0.01, span / 200.0)


func _fmt(value: float) -> String:
	if absf(value) >= 100.0:
		return "%.0f°" % value
	return "%.1f°" % value


func _set_joint(joint_index: int, value: float) -> void:
	if _viewer and _viewer.has_method("set_joint_rotation"):
		_viewer.set_joint_rotation(joint_index, value)
		var name: String = _viewer.get_joint_name(joint_index)
		if _sliders.has(name):
			_sliders[name].set_value_no_signal(value)
		if _value_labels.has(name):
			_value_labels[name].text = _fmt(value)


func _on_zero_all() -> void:
	for name in _sliders:
		var idx := -1
		for i in range(_viewer.get_joint_count()):
			if _viewer.get_joint_name(i) == name:
				idx = i
				break
		if idx >= 0:
			_set_joint(idx, 0.0)


func _on_slider_changed(value: float, joint_index: int, joint_name: String) -> void:
	if _value_labels.has(joint_name):
		_value_labels[joint_name].text = _fmt(value)
	joint_value_changed.emit(joint_name, value)
	if _viewer and _viewer.has_method("set_joint_rotation"):
		_viewer.set_joint_rotation(joint_index, value)


func _clear_sliders() -> void:
	for child in _slider_list.get_children():
		if child != _empty_state:
			child.queue_free()
	_sliders.clear()
	_value_labels.clear()
	_empty_state.visible = true
